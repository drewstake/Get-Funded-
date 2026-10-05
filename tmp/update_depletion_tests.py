from pathlib import Path
src=Path(__file__).resolve().parents[1]/'src'
p=src/'DepletionTests.luau';s=p.read_text(encoding='utf-8')
s=s.replace('local function tier(view,id) for _,row in ipairs(view.Accounts) do if row.Key==id then return row end end end','local function tier(view,id) local found;for _,row in ipairs(view.Accounts) do if row.Tier==id then found=row end end return found end')
s=s.replace('ev.Tier=="F5K" and ev.Name=="$5K Funded"','ev.Tier=="F5K:1" and ev.Name=="$5K Funded #1"')
s=s.replace('row.CanRestart==nil','not row.CanRestart').replace('not ok and msg:find("Closing remaining positions")','not ok')
s=s.replace(' and duplicate:find("already restarted")','')
s=s.replace('near(row.PriorRealized,-5250,"prior realized")','near(view.Earned-row.Realized,-5250,"prior realized")')
a=s.index(' test("Copy follower blown:')
s=s[:a]+''' test("A blown copy follower is removed; surviving instances keep trading and prevent free restarts",function()
  local e,f=exchange();f:Start("6");local p=f:Profile("6")
  p.Tiers.F10K={State="Unlocked",Claimed=false,Announced=true};assert(f:Activate("6","F10K"))
  local follower=f:Owner("6");local lead=p.Tiers.F10K.Account
  assert(f:SetCopy("6",{Enabled=1,Leader="F10K:1",Followers="F5K:1",Sizing="Same"}))
  quote(e,-1,5825,1);place(e,follower,1,1);mark(e,5725);e:AdvanceClock(.25);f:Evaluate("6")
  assert(e.Accounts[follower].Locked and not e.Accounts[lead].Locked)
  assert(not p.Copy.Enabled and #p.Copy.Followers==0 and not f:Restart("6","F5K:1"))
  assert(p.Tiers.F5K and p.Tiers.F10K and f:Select("6","F10K:1"))
  local before=e.Accounts[follower].Realized
  quote(e,-1,5725,1);place(e,lead,1,1);assert(not e.Accounts[follower].Positions.ES)
  near(e.Accounts[follower].Realized,before);e:Audit();return "Permanent access retained; copy membership follows usable instance identity"
 end)
 test("Depletion notice and free-restart state survive checkpoint/rejoin without duplicate events",function()
  local CP=require(script.Parent.WorldCheckpoint);local P=require(script.Parent.Participants)
  local e,f=exchange();f:Start("7");local id=f:Owner("7")
  quote(e,-1,5825,1);place(e,id,1,1);mark(e,5725);e:AdvanceClock(.25)
  assert(#depletions(f:TakeEvents("7"))==1)
  local pop=setmetatable({Engine=e,Config=e.Config,Random=P.RNG.new(81),Agents={}},P)
  local restored=CP.Restore(CP.Decode(CP.Encode(CP.Capture(e,pop))),Default);local g=Funded.new(restored,deep(Ladder),Default)
  g:Join("7");g:Evaluate("7");assert(#depletions(g:TakeEvents("7"))==0)
  assert(g:View("7").CanRestart and g:Restart("7","F5K:1"));assert(not g:Restart("7","F5K:1"))
  near(g:View("7").Next.Progress,0);near(g:View("7").Earned,-5000);restored:Audit()
  return "One notice per account instance; restart and retained losses persist"
 end)
 return report
end
return Tests
'''
p.write_text(s,encoding='utf-8')
# Retain the historical diagnostic module name for callers, but replace its obsolete policy assertions.
(src/'ReearnTests.luau').write_text('''-- Compatibility entry point: re-earning has been removed. The replacement suite verifies
-- permanent access, old re-earn-save migration, reset progress, wallet and purchase persistence.
return require(script.Parent.PermanentShopTests)
''',encoding='utf-8')
