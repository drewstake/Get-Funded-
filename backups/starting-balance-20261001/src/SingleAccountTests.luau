-- Disposable engines and fake stores only. No production profile or DataStore is accessed.
local C=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local L=require(game.ReplicatedStorage.MarketReign.ProgressionConfig)
local E=require(script.Parent.MarketEngine)
local F=require(script.Parent.FundedAccounts)
local P=require(script.Parent.Participants)
local CP=require(script.Parent.WorldCheckpoint)
local W=require(script.Parent.WorldService)
local TS=require(script.Parent.TradeStats)
local Ranking=require(script.Parent.LeaderboardRanking)
local Replies=require(script.Parent.ReplyBuffer)
local Tests={}
local function clone(v) if type(v)~="table" then return v end local r={} for k,x in pairs(v) do r[k]=clone(x) end return r end
local function same(a,b)
 assert(type(a)==type(b),"Type differs")
 if type(a)~="table" then assert(a==b,tostring(a).." differs from "..tostring(b));return end
 for k,v in pairs(a) do same(v,b[k]) end;for k in pairs(b) do assert(a[k]~=nil,"Missing "..tostring(k)) end
end
local function fresh(uid)
 local c=clone(C);c.WarmupSeconds=0
 local e=E.new(c,712);local f=F.new(e,L,c);if uid then f:Join(uid) end;return e,f
end
local function pop(e)return setmetatable({Engine=e,Config=e.Config,Random=P.RNG.new(712),Agents={}},P)end
local function result(e,id,amount)
 local b=e.Books.BX;b.Last=24000;b.Reference=24000;b.Bids={};b.Asks={}
 assert(e:Submit(id,{Contract="BX",Direction=1,Quantity=1,Type="Market"}))
 b.Last+=amount/(b.Spec.Multiplier*b.Spec.Tick)
 assert(e:Submit(id,{Contract="BX",Direction=-1,Quantity=1,Type="Market",ReduceOnly=true}))
 e:AdvanceClock(C.StepSeconds);e:Audit()
end
local function restore(e)
 local r,p=CP.Restore(CP.Decode(CP.Encode(CP.Capture(e,pop(e)))),e.Config)
 return r,F.new(r,L,r.Config),p
end
function Tests.Run()
 local rows={};local function test(name,fn)local ok,detail=pcall(fn);table.insert(rows,{Name=name,Passed=ok,Detail=ok and (detail or "Passed") or tostring(detail)})end
 test("Join and Start idempotently give one $5000 account; no wallet or purchases",function()
  local e,f=fresh("101");local id=f:Owner("101");f:Join("101");f:Start("101")
  assert(#f:Profile("101").Ledger==1 and e.Accounts[id].Balance==5000)
  local v=f:View("101");assert(v.Next.Key=="FirstTrade" and not v.Wallet and not v.Copy and #v.Accounts==1)
  assert(F.Purchase==nil and F.Select==nil and F.Mirror==nil and F.Activate==nil)
 end)
 test("Open profit changes equity only; closing banks result and grants early titles",function()
  local e,f=fresh("101");local id=f:Owner("101");local b=e.Books.BX;b.Last=24000
  assert(e:Submit(id,{Contract="BX",Direction=1,Quantity=1,Type="Market"}));b.Last+=40
  local sum=e:Summary(e.Accounts[id]);assert(sum.Balance==5000 and sum.Unrealized==500 and sum.Equity==5500)
  assert(not next(f:Profile("101").Awards))
  assert(F.Perform(e,id,{Action="Close",Contract="BX"}));assert(e.Accounts[id].Balance==5500)
  local p=f:Profile("101");assert(p.Awards.FirstTrade and p.Awards.FirstWin and p.Awards.Profit500)
  assert(f:View("101").Next.Key=="Balance10K")
  local events=f:TakeEvents("101");local closing=events[#events]
  assert(closing.Kind=="TradeClosed" and closing.Balance==5500 and #closing.Rewards==3 and closing.Next.Key=="Balance10K");e:Audit()
 end)
 test("Break-even first close earns first-trade milestone",function()
  local e,f=fresh("101");result(e,f:Owner("101"),0)
  assert(f:Profile("101").Awards.FirstTrade and not f:Profile("101").Awards.FirstWin)
 end)
 test("Recovering lost profit never awards the same title again",function()
  local e,f=fresh("101");local id=f:Owner("101");result(e,id,500);local awards=clone(f:Profile("101").Awards)
  f:TakeEvents("101");result(e,id,-500);result(e,id,500);same(awards,f:Profile("101").Awards)
  for _,ev in ipairs(f:TakeEvents("101")) do assert(ev.Kind~="Milestone") end
 end)
 test("Long-term balance milestone requires lifetime net profit and persists",function()
  local e,f=fresh("101");local id=f:Owner("101");result(e,id,5000)
  assert(f:Profile("101").Awards.Balance10K);result(e,id,-1000)
  assert(f:Profile("101").Awards.Balance10K and f:View("101").Rank=="Skilled Trader")
 end)
 test("Healthy reset and forged restart token cannot mint funds",function()
  local e,f=fresh("101");local id=f:Owner("101")
  assert(not f:Restart("101",id));assert(not f:Restart("101","player:other:single:1"));assert(e.Accounts[id].Balance==5000)
 end)
 test("Equity zero cancels orders, liquidates and offers free restart",function()
  local e,f=fresh("101");local id=f:Owner("101");local b=e.Books.BX;b.Last=24000
  assert(e:Submit(id,{Contract="BX",Direction=1,Quantity=1,Type="Market",StopTicks=800,TargetTicks=100}))
  assert(e:Submit(id,{Contract="BT",Direction=1,Quantity=1,Type="Limit",Price=C.Contracts.BT.Last-100}))
  b.Last-=400;e:AdvanceClock(C.StepSeconds);f:Evaluate("101")
  local a=e.Accounts[id];assert(a.Depleted and not next(a.Positions) and not next(a.OpenOrders));assert(f:View("101").CanRestart)
  assert(f:Restart("101",id));local nextId=f:Owner("101");assert(nextId~=id and e.Accounts[nextId].Balance==5000)
  assert(not f:Restart("101",id) and not e.Accounts[id]);e:Audit()
 end)
 test("Restart preserves titles, lifetime losses, history and separates current run",function()
  local e,f=fresh("101");local id=f:Owner("101");result(e,id,500);result(e,id,-5500)
  local awards=clone(f:Profile("101").Awards);assert(f:Restart("101",id))
  same(awards,f:Profile("101").Awards)
  local scope=f:Stats("101").Scopes[1];assert(scope.Life.Net==-5000 and scope.Life.AllTrades==2 and scope.Current.Net==0 and scope.Current.AllTrades==0)
  result(e,f:Owner("101"),5000);assert(not f:Profile("101").Awards.Balance10K,"Restart grant qualified as profit")
  e:Audit()
 end)
 test("Repeated restart budgets survive rejoin and storage; archive stays bounded",function()
  local e,f=fresh("101")
  for _=1,5 do local id=f:Owner("101");result(e,id,-5000);assert(f:Restart("101",id));f:Join("101") end
  local id=f:Owner("101");result(e,id,-5000);assert(not f:Restart("101",id))
  e,f=restore(e);assert(not f:Restart("101",id));assert(#f:Profile("101").Ledger==2)
  e.Time+=L.ResetLimits.RefillSeconds*C.SimulationSpeed;assert(f:Restart("101",id));e:Audit()
 end)
 test("Position size, stop loss, take profit and all current markets work",function()
  for _,market in ipairs(C.ContractOrder) do
   local e,f=fresh("101");local id=f:Owner("101");local b=e.Books[market]
   assert(not e:Submit(id,{Contract=market,Direction=1,Quantity=6,Type="Market"}))
   assert(e:Submit(id,{Contract=market,Direction=1,Quantity=1,Type="Market",StopTicks=4,TargetTicks=8}))
   local p=e.Accounts[id].Positions[market];assert(p.Stop and p.Target)
   p.Triggered="Take profit";table.insert(e.PendingStops,{Owner=id,Contract=market,Position=p.Id});e:ProcessStops()
   assert(not e.Accounts[id].Positions[market]);assert(e.Accounts[id].Realized>0);e:Audit()
  end
 end)
 test("Current positions, orders, rewards and tutorial survive codec restore exactly",function()
  local e,f=fresh("101");result(e,f:Owner("101"),500);f:Flag("101","TutorialDone")
  assert(e:Submit(f:Owner("101"),{Contract="BX",Direction=1,Quantity=1,Type="Market",StopTicks=10,TargetTicks=30}))
  assert(e:Submit(f:Owner("101"),{Contract="BT",Direction=-1,Quantity=1,Type="Limit",Price=C.Contracts.BT.Last+100}))
  local before=CP.Capture(e,pop(e));local r,g=restore(e);same(before,CP.Capture(r,pop(r)))
  assert(g:Owner("101")==f:Owner("101"));same(g:View("101"),f:View("101"));r:Audit()
 end)
 test("Legacy migration closes all exposure and carries only selected net profit",function()
  local e=fresh();local first=e:AddAccount("player:101:F5K:1",5000,5,.8,true);first.Tier="F5K"
  local second=e:AddAccount("player:101:F100K:1",100000,100,.8,true);second.Tier="F100K"
  result(e,first.Id,500);result(e,second.Id,2000)
  assert(e:Submit(second.Id,{Contract="BX",Direction=1,Quantity=1,Type="Market"}));e.Books.BX.Last+=40
  assert(e:Submit(first.Id,{Contract="BT",Direction=1,Quantity=1,Type="Limit",Price=C.Contracts.BT.Last-100}))
  e.Profiles={['101']={V=3,Ledger={first.Id,second.Id},Active="F100K:1",Instances={['F100K:1']={Account=second.Id}},
   Tiers={F5K={},F100K={}},Completion={At=1},WalletCents=123456,Purchases={{Sequence=1}},Copy={Enabled=true,Followers={"F5K:1"}}}}
  local before=CP.Capture(e,pop(e));before.Version=7
  local r=CP.Restore(before,C);local f=F.new(r,L,C);local p=f:Profile("101");local a=r.Accounts[p.Account]
  assert(a.Balance==7500 and a.Realized==0 and f:Earned(p)==3000)
  assert(not next(a.Positions) and not next(a.OpenOrders) and p.LegacyProfile.WalletCents==123456)
  assert(p.LegacyProfile.Purchases[1].Sequence==1 and p.Migration.Accounts[first.Id].Orders[1])
  assert(table.find(p.Titles,"Legacy 100K Trader") and table.find(p.Titles,"Legacy Top Tier Complete"));assert(not p.WalletCents and not p.Copy)
  for _,id in ipairs({first.Id,second.Id}) do assert(r.Accounts[id].MigrationArchived and not next(r.Accounts[id].Positions));assert(not r:Submit(id,{Contract="BX",Direction=1,Quantity=1,Type="Market"})) end
  local after=CP.Capture(r,pop(r));local rr=CP.Restore(after,C);same(after,CP.Capture(rr,pop(rr)));r:Audit();rr:Audit()
 end)
 test("Migration loss, orphan accounts, and all-failed legacy profiles are safe",function()
  local e=fresh();local a=e:AddAccount("player:101:F10K:1",10000,10,.8,true);a.Tier="F10K";result(e,a.Id,-6000)
  local f=F.new(e,L,C);assert(e.Accounts[f:Owner("101")].Balance==-1000 and f:View("101").Failed)
  assert(f:Restart("101",f:Owner("101")));assert(f:Earned(f:Profile("101"))==-6000);e:Audit()
  local e2=fresh();local b=e2:AddAccount("player:102:F5K:1",5000,5,.8,true);result(e2,b.Id,-5000)
  local g=F.new(e2,L,C);assert(g:View("102").Failed and g:View("102").CanRestart)
 end)
 test("Migration rejects future profile versions and missing ledgers",function()
  local e,f=fresh("101");local snap=CP.Capture(e,pop(e));snap.Engine.Profiles['101'].V=99
  assert(not pcall(CP.Restore,snap,C));snap=CP.Capture(e,pop(e));table.insert(snap.Engine.Profiles['101'].Ledger,"missing")
  assert(not pcall(CP.Restore,snap,C));snap.Version=999;assert(not pcall(CP.Restore,snap,C))
 end)
 test("Leaderboard counts net lifetime closed profit including failed runs",function()
  local e,f=fresh("101");assert(not Ranking.Row(f,"101").Eligible)
  result(e,f:Owner("101"),500);local row=Ranking.Row(f,"101");assert(row.Eligible and row.Cents==50000 and row.Tier=="Rising Trader")
  result(e,f:Owner("101"),-5500);assert(f:Restart("101",f:Owner("101")));assert(Ranking.Row(f,"101").Cents==-500000)
 end)
 test("Checkpoint size and corruption fail closed",function()
  local e=fresh("101");local snap=CP.Capture(e,pop(e));assert(not pcall(CP.Encode,snap,100))
  local record=CP.Encode(snap);record.Digest="bad";assert(not pcall(CP.Decode,record))
 end)
 test("Capacity rejects starts and restarts without partial grants",function()
  local e=fresh();local f=F.new(e,L,C,{Capacity=function()return false end});assert(not f:Start("101") and not f:Profile("101"))
  f.Capacity=nil;f:Start("101");local id=f:Owner("101");result(e,id,-5000);f.Capacity=function()return false end
  assert(not f:Restart("101",id) and f:Owner("101")==id);e:Audit()
 end)
 test("Stale order ownership and invalid payloads are rejected by engine",function()
  local e,f=fresh("101");f:Join("102");local id=f:Owner("101")
  local ok,o=e:Submit(id,{Contract="BX",Direction=1,Quantity=1,Type="Limit",Price=C.Contracts.BX.Last-100});assert(ok)
  assert(not e:Cancel(f:Owner("102"),o.Id))
  for _,q in ipairs({0,-1,0.5,math.huge,0/0,1e10}) do assert(not e:Submit(id,{Contract="BX",Direction=1,Quantity=q,Type="Market"})) end
 end)
 test("Tutorial replay flags do not grant funds or rewards",function()
  local e,f=fresh("101");for _=1,3 do f:Flag("101","TutorialDone");f:Flag("101","TutorialSkipped") end
  assert(e.Accounts[f:Owner("101")].Balance==5000 and not next(f:Profile("101").Awards));assert(not f:Flag("101","CopyIntro"))
 end)
 return rows
end
return Tests
