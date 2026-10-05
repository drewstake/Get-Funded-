-- Isolated experiment: reads current source; never accesses Studio or saved worlds.
local fs=require("@lune/fs")
local R=require("../security-fix-verification-2026-09-30/lune-harness/roblox")
for _,name in ipairs({"MarketEngine","Participants","TradeStats"}) do R.module(R.Server,name,"src/"..name..".luau") end
for _,name in ipairs({"MarketConfig","TradeProtection","ContractLimits","ProgressionConfig"}) do R.module(R.Shared,name,"src/"..name..".luau") end
local Engine=R.require(R.Server.MarketEngine)
local Participants=R.require(R.Server.Participants)
local Default=R.require(R.Shared.MarketConfig)
local variants={
 {Name="Baseline",Traders=36,Makers=5,Whales=3},
 {Name="Double ordinary traders",Traders=72,Makers=5,Whales=3},
 {Name="Triple ordinary traders",Traders=108,Makers=5,Whales=3},
 {Name="Double makers",Traders=36,Makers=10,Whales=3},
 {Name="Triple makers",Traders=36,Makers=15,Whales=3},
 {Name="Double all participants",Traders=72,Makers=10,Whales=6},
}
local report={WarmupSeconds=1800,MeasuredSeconds=3600,Seeds={73521,90210,42617},Results={}}
for _,v in ipairs(variants) do
 local totals={Name=v.Name,Traders=v.Traders,Makers=v.Makers,Whales=v.Whales,Boundaries=0,GapTicks=0,NonzeroGaps=0,LargeGaps=0,MissingMinutes=0,Trades=0,LockedMakers=0,MakersTotal=0,Seconds=0,Runs={}}
 for _,seed in ipairs(report.Seeds) do
  local c=table.clone(Default)
  c.ParticipantsPerInstrument=v.Traders c.MakersPerInstrument=v.Makers c.WhalesPerInstrument=v.Whales
  local started=os.clock()
  local e=Engine.new(c,seed) local bots=Participants.new(e)
  for _=1,report.WarmupSeconds/c.StepSeconds do bots:Step() end
  local firstTrade=e.NextTrade
  for _=1,report.MeasuredSeconds/c.StepSeconds do bots:Step() end
  local row={Seed=seed,Boundaries=0,GapTicks=0,NonzeroGaps=0,LargeGaps=0,MissingMinutes=0,Trades=e.NextTrade-firstTrade,LockedMakers=0,MakersTotal=0,Seconds=os.clock()-started}
  for _,key in ipairs(c.ContractOrder) do
   local series=e.Books[key].Candles["1m"] local seen={}
   for i,bar in ipairs(series) do
    if bar.Time>=report.WarmupSeconds and bar.Time<report.WarmupSeconds+report.MeasuredSeconds then
     seen[bar.Time]=true
     local previous=series[i-1]
     if previous then
      local ticks=math.round(math.abs(bar.Open-previous.Close)/c.Contracts[key].Tick)
      row.Boundaries+=1 row.GapTicks+=ticks
      if ticks>0 then row.NonzeroGaps+=1 end
      if ticks>=4 then row.LargeGaps+=1 end
     end
    end
   end
   for time=report.WarmupSeconds,report.WarmupSeconds+report.MeasuredSeconds-60,60 do if not seen[time] then row.MissingMinutes+=1 end end
  end
  for _,a in ipairs(bots.Agents) do if a.Kind=="Maker" then row.MakersTotal+=1 if e.Accounts[a.Id].Locked then row.LockedMakers+=1 end end end
  e:Audit()
  table.insert(totals.Runs,row)
  for field,value in pairs(row) do if field~="Seed" then totals[field]+=value end end
  print(v.Name.." seed "..seed..": "..string.format("%.2fs, gap %.2f ticks, missing minutes %d",row.Seconds,row.GapTicks/row.Boundaries,row.MissingMinutes))
 end
 totals.MeanGapTicks=totals.GapTicks/totals.Boundaries
 totals.NonzeroGapPercent=100*totals.NonzeroGaps/totals.Boundaries
 totals.LargeGapPercent=100*totals.LargeGaps/totals.Boundaries
 table.insert(report.Results,totals)
 fs.writeFile("output/liquidity-study-20261002/results.json",R.JSONEncode(report))
end
print("Done: output/liquidity-study-20261002/results.json")
