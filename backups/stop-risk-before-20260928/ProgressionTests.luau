-- Isolated regression scenarios for the E-mini / progression / equity migration.
local E=require(script.Parent.MarketEngine)
local F=require(script.Parent.FundedAccounts)
local P=require(script.Parent.Participants)
local C=require(script.Parent.WorldCheckpoint)
local Config=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local Ladder=require(game.ReplicatedStorage.MarketReign.ProgressionConfig)
local T={}
local function clone(v) if type(v)~="table" then return v end local r={} for k,x in pairs(v) do r[k]=clone(x) end return r end
local function near(a,b) assert(math.abs(a-b)<1e-5,tostring(a).." ~= "..tostring(b)) end
local function submit(e,who,key,side,qty,price,extra)
 local r={Contract=key,Direction=side,Quantity=qty,Type=price and "Limit" or "Market",Price=price}
 for k,v in pairs(extra or {}) do r[k]=v end
 local ok,result=e:Submit(who,r) assert(ok,tostring(result)) return result
end
local function fresh()
 local e=E.new(Config,987) local f=F.new(e,Ladder,Config)
 e:AddAccount("maker",1e9,10000,.99,false) e:AddAccount("taker",1e9,10000,.99,false)
 f:Start("test") return e,f,e.Accounts[f:Owner("test")]
end
function T.LegacyWorld()
 local config=clone(Config) config.Contracts={} config.ContractOrder=clone(Config.LegacyOrder) config.DailyLossLimit=1000
 for _,key in ipairs(config.ContractOrder) do config.Contracts[key]=clone(Config.LegacyContracts[key]);config.Contracts[key].CloseOnly=nil end
 local e=E.new(config,7239) local p=P.new(e)
 for _=1,200 do p:Step() end
 local f=F.new(e,Ladder,config) f:Start("old") local a=e.Accounts[f:Owner("old")]
 e:AddAccount("fixture-maker",1e9,10000,.99,false)
 for _,id in ipairs(e.AccountOrder) do e:CancelAll(id) end
 submit(e,"fixture-maker","MES",-1,2,5825)
 submit(e,a.Id,"MES",1,2,nil,{StopTicks=400,TargetTicks=800})
 submit(e,a.Id,"M2K",1,1,2200)
 a.LossLimit=500 a.Locked=true -- old positive-equity loss lock must be lifted
 a.History={{Contract="MES",Pnl=12.5,Quantity=1,Entry=5822.5,Exit=5825,Time="00:01:00"}}
 local profile=f:Profile("old") profile.V=1 profile.ProgressCredit=nil
 profile.Tiers.F10K={State="Unlocked",Announced=true}
 local snapshot=C.Capture(e,p);snapshot.Version=2
 return snapshot,a.Id
end
function T.Run()
 local results={}
 local function test(name,fn) local ok,detail=pcall(fn);table.insert(results,{Name=name,Passed=ok,Detail=ok and detail or tostring(detail)}) end
 test("Every progression boundary, current-stage reset and top-tier completion",function()
  local e,f,a=fresh()
  local thresholds={3000,8000,18000,38000,78000}
  local goals={3000,5000,10000,20000,40000}
  for i,value in ipairs(thresholds) do
   a.Realized=value-.01;a.Balance=a.Base+a.Realized;f:Evaluate("test")
   local v=f:View("test");assert(v.Next and v.Next.Goal==goals[i]);near(v.Next.Remaining,.01)
   a.Realized=value;a.Balance=a.Base+value;f:Evaluate("test")
   v=f:View("test")
   if i<5 then assert(v.Next.Goal==goals[i+1]);near(v.Next.Progress,0)
   else assert(v.Completed and not v.Next) end
  end
  local events=f:TakeEvents("test");assert(events[#events].Kind=="Completed")
  f:Evaluate("test");assert(not f:TakeEvents("test"))
  a.Realized=70000;a.Balance=75000;f:Evaluate("test");assert(f:View("test").Completed)
 end)
 test("Closed losses reduce progress; activation, capital and switching never add profit",function()
  local e,f,a=fresh();a.Realized=3500;a.Balance=8500;f:Evaluate("test");f:Activate("test","F10K")
  local v=f:View("test");near(v.Next.Progress,500);near(v.Earned,3500)
  f:Select("test","F10K");local ten=e.Accounts[f:Owner("test")]
  ten.Realized=-250;ten.Balance=9750;f:Evaluate("test");near(f:View("test").Next.Progress,250)
  for _=1,5 do f:Select("test","F5K");f:Select("test","F10K");f:Evaluate("test") end
  near(f:View("test").Earned,3250)
  ten.Realized=-600;ten.Balance=9400;f:Evaluate("test")
  assert(f:Profile("test").Tiers.F10K);near(f:View("test").Next.Progress,-100)
 end)
 test("Grandfathered stages retain surplus/losses and migrate exactly once",function()
  for index=2,5 do
   local e,f,a=fresh();local profile=f:Profile("test")
   for i=2,index do profile.Tiers[Ladder.Tiers[i].Id]={State="Unlocked",Announced=true} end
   local id=Ladder.Tiers[index].Id local old=Ladder.LegacyUnlocks[id]
   a.Realized=old+100;a.Balance=5000+a.Realized;profile.V=1;profile.ProgressCredit=nil
   f=F.new(e,Ladder,Config);local v=f:View("test")
   near(v.Earned,old+100);near(v.Next.Progress,100);near(v.ProgressCredit,Ladder.Tiers[index].Unlock-old)
   local credit=v.ProgressCredit;f=F.new(e,Ladder,Config);near(f:View("test").ProgressCredit,credit)
   a.Realized-=250;a.Balance-=250;f:Evaluate("test");near(f:View("test").Next.Progress,-150)
  end
 end)
 test("E-mini tick economics, both directions, partial closing and stop estimates",function()
  local expected={ES={50,.25,12.5},NQ={20,.25,5},RTY={50,.1,5},YM={5,1,5}}
  for key,spec in pairs(expected) do
   near(Config.Contracts[key].Multiplier,spec[1]);near(Config.Contracts[key].Tick,spec[2])
   for _,side in ipairs({1,-1}) do
    local e,f,a=fresh();local price=Config.Contracts[key].Last
    submit(e,"maker",key,-side,2,price);submit(e,a.Id,key,side,2,nil,{StopTicks=4,TargetTicks=12})
    local p=a.Positions[key];near((p.Entry-p.Stop)*p.Direction*p.Quantity*spec[1],8*spec[3])
    submit(e,"maker",key,side,1,price+side*spec[2]);submit(e,a.Id,key,-side,1,nil,{ReduceOnly=true})
    near(a.Realized,spec[3]);near(e:Summary(a).Unrealized,spec[3]);assert(p.Quantity==1)
    e:Audit()
   end
  end
 end)
 test("A fresh $5K can trade ES or NQ; excess margin and risk remain rejected",function()
  for _,key in ipairs({"ES","NQ"}) do
   local e,f,a=fresh();local price=Config.Contracts[key].Last
   submit(e,"maker",key,-1,1,price);assert(submit(e,a.Id,key,1,1).Filled==1)
   assert(not e:Submit(a.Id,{Contract=key,Direction=1,Quantity=5,Type="Market"}))
   assert(not e:Submit(a.Id,{Contract=key,Direction=1,Quantity=1,Type="Market",StopTicks=10000}))
  end
 end)
 test("Margin liquidation with positive equity does not fail or allow a free restart",function()
  local e,f,a=fresh();submit(e,"maker","ES",-1,3,5825);submit(e,a.Id,"ES",1,3)
  submit(e,"maker","ES",1,4,5813);submit(e,"taker","ES",-1,1)
  e:AdvanceClock(.25)
  assert(not a.Positions.ES and not a.Locked);near(a.Balance,3200);assert(not f:Restart("test","F5K"))
  submit(e,"maker","ES",-1,1,5813);e:AdvanceClock(.25);assert(submit(e,a.Id,"ES",1,1).Filled==1)
  e:Audit()
 end)
 test("Only depletion fails; intrastep depletion latches and restart retains closed losses/history",function()
  local e,f,a=fresh();submit(e,"maker","ES",-1,1,5825);submit(e,a.Id,"ES",1,1)
  submit(e,"maker","ES",1,2,5725);submit(e,"taker","ES",-1,1)
  assert(a.Locked,"Depletion must latch immediately at execution")
  e:ProcessStops();assert(not a.Positions.ES);near(a.Balance,0);near(a.Realized,-5000)
  local history=#a.History;assert(f:Restart("test","F5K"));assert(a.Retired and #a.History==history)
  near(f:View("test").Earned,-5000);near(f:View("test").Next.Remaining,8000)
  e:Audit()
 end)
 test("Positive equity survives losses larger than the former daily/trailing allowance",function()
  local e,f,a=fresh();submit(e,"maker","ES",-1,1,5825);submit(e,a.Id,"ES",1,1)
  submit(e,"maker","ES",1,2,5800);submit(e,"taker","ES",-1,1);e:AdvanceClock(.25)
  assert(not a.Locked and a.Positions.ES);near(e:Summary(a).Equity,3750);near(e:Summary(a).Allowance,3750)
 end)
 test("Micro checkpoint migration preserves exposure, history, prices, candles and pending protection",function()
  local saved,id=T.LegacyWorld();local before=clone(saved)
  local e,p=C.Restore(C.Decode(C.Encode(saved)),Config);local a=e.Accounts[id]
  assert(a.Balance==5000 and a.Realized==0 and a.LossLimit==5000 and not a.Locked)
  assert(a.Positions.MES.Quantity==2 and a.Positions.MES.Entry==5825 and a.Positions.MES.Stop==5725)
  assert(a.History[1].Contract=="MES" and a.History[1].Pnl==12.5 and not next(a.OpenOrders))
  assert(e.Books.MES.Last==before.Engine.Books.MES.Last and #e.Books.MES.Candles["1m"]==#before.Engine.Books.MES.Candles["1m"])
  assert(e.Config.SimulationSpeed==18 and e.Books.ES.Spec.Multiplier==50 and e.Books.MES.Spec.Multiplier==5)
  assert(not e:Submit(id,{Contract="MES",Direction=1,Quantity=1,Type="Market"}))
  for _,owner in ipairs(e.AccountOrder) do e:CancelAll(owner) end
  submit(e,"fixture-maker","MES",1,2,5826);assert(F.Perform(e,id,{Action="Close",Contract="MES"}))
  near(a.Realized,10);near(a.Balance,5010);assert(a.History[1].Pnl==10 and a.History[2].Pnl==12.5)
  local f=F.new(e,Ladder,Config);local credit=f:View("old").ProgressCredit
  local nextSnapshot=C.Capture(e,p);local r,q=C.Restore(C.Decode(C.Encode(nextSnapshot)),Config)
  local g=F.new(r,Ladder,Config);near(g:View("old").ProgressCredit,credit);near(r.Accounts[id].Balance,5010)
  assert(#q.Agents==#p.Agents and #r.Config.ContractOrder==8,"Restore duplicated markets")
  e:Audit();r:Audit()
  return {LegacyRealized=10,HistoryPreserved=true,CancelledPending=true,Participants=#p.Agents}
 end)
 test("Speed 18 executes all 72 scheduler steps/sec and intrastep OCO crossings latch",function()
  local e,f,a=fresh();submit(e,"maker","ES",-1,1,5825);submit(e,a.Id,"ES",1,1,nil,{StopTicks=4,TargetTicks=8})
  submit(e,"maker","ES",1,1,5824);submit(e,"taker","ES",-1,1)
  submit(e,"maker","ES",-1,1,5827);submit(e,"taker","ES",1,1)
  assert(a.Positions.ES.Triggered=="Stop loss" and not a.Positions.ES.Target)
  submit(e,"maker","ES",1,1,5826);e:ProcessStops();assert(not a.Positions.ES)
  local accumulator=0 local steps=0
  for _=1,200 do accumulator+=(1/60)*Config.SimulationSpeed
   local frameSteps=0 while accumulator+1e-9>=Config.StepSeconds and frameSteps<Config.MaxCatchupSteps do
    accumulator-=Config.StepSeconds;steps+=1;frameSteps+=1;e:AdvanceClock(Config.StepSeconds)
   end
  end
  assert(steps==240);near(e.Time,60);assert(Config.BroadcastSeconds==.1 and Config.Volatility==1)
 end)
 return results
end
return T
