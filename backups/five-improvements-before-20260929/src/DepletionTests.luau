-- Account-blown (depletion) notice, status and restart regression suite (server only).
-- Studio: StudioDiagnostics:Invoke("DepletionTests"). Uses isolated engines; never touches the live exchange.
local Engine=require(script.Parent.MarketEngine)
local Funded=require(script.Parent.FundedAccounts)
local Shared=game.ReplicatedStorage.MarketReign
local Default=require(Shared.MarketConfig)
local Ladder=require(Shared.ProgressionConfig)
local Tests={}
local function deep(v) if type(v)~="table" then return v end local r={} for k,x in pairs(v) do r[k]=deep(x) end return r end
local function exchange()
 local c=table.clone(Default) c.MaxTradeHistory=100000 c.MaxOrderHistory=100000
 local e=Engine.new(c,91)
 e:AddAccount("maker",1e9,100000,0.99,false) e:AddAccount("taker",1e9,100000,0.99,false)
 return e,Funded.new(e,deep(Ladder),c)
end
local function quote(e,side,price,qty,key)
 local ok,r=e:Submit("maker",{Contract=key or "ES",Direction=side,Quantity=qty,Type="Limit",Price=price}) assert(ok,tostring(r)) return r
end
local function mark(e,price,key)
 quote(e,-1,price,1,key) local ok,r=e:Submit("taker",{Contract=key or "ES",Direction=1,Quantity=1,Type="Market"}) assert(ok and r.Filled==1,"mark failed")
end
local function place(e,id,side,qty,key,extra)
 local r={Action="Place",Contract=key or "ES",Direction=side,Quantity=qty,Type="Market"}
 for k,v in pairs(extra or {}) do r[k]=v end
 local ok,res=Funded.Perform(e,id,r) assert(ok,tostring(res)) return res,r
end
local function tier(view,id) for _,row in ipairs(view.Accounts) do if row.Key==id then return row end end end
local function near(a,b,msg) assert(math.abs(a-b)<1e-6,(msg or "value").." expected "..b.." got "..a) end
local function depletions(events)
 local list={} for _,ev in ipairs(events or {}) do if ev.Kind=="Depleted" then table.insert(list,ev) end end return list
end
local function playerAccounts(e,uid)
 local n=0 for id in pairs(e.Accounts) do if id:sub(1,#("player:"..uid..":"))=="player:"..uid..":" then n+=1 end end return n
end

function Tests.Run()
 local report={} local function test(name,fn)
  local ok,result=pcall(fn) table.insert(report,{Name=name,Passed=ok,Detail=ok and result or tostring(result)})
 end
 test("Exactly $0 equity blows the account and announces it once",function()
  local e,f=exchange() f:Start("1") local id=f:Owner("1")
  quote(e,-1,5825,1) place(e,id,1,1) mark(e,5725)
  local a=e.Accounts[id] near(e:Summary(a).Equity,0,"equity") assert(a.Locked,"Zero equity did not deplete")
  local list=depletions(f:TakeEvents("1")) assert(#list==1,"Expected one depletion notice")
  local ev=list[1] assert(ev.Tier=="F5K" and ev.Name=="$5K Funded" and ev.Event=="F5K:1" and ev.Attempt==1 and ev.Size==5000)
  near(ev.Equity,0,"event equity") assert(ev.Closing and not ev.CanRestart,"No liquidity yet: notice must report closing")
  quote(e,1,5725,1) e:AdvanceClock(.25)
  assert(not a.Positions.ES) near(a.Realized,-5000,"realized")
  local row=tier(f:View("1"),"F5K") assert(row.Depleted and row.Breached and not row.Closing and row.CanRestart and row.DepletionEvent=="F5K:1")
  assert(#depletions(f:TakeEvents("1"))==0,"Depletion announced twice")
  e:Audit()
  return "Equity $0.00 → notice F5K:1 (closing), then liquidated −$5,000, restart available, no repeat"
 end)
 test("Negative equity blows the account",function()
  local e,f=exchange() f:Start("2") local id=f:Owner("2")
  quote(e,-1,5825,1) place(e,id,1,1) mark(e,5700)
  local a=e.Accounts[id] near(e:Summary(a).Equity,-1250,"equity") assert(a.Locked)
  local ev=depletions(f:TakeEvents("2"))[1] assert(ev) near(ev.Equity,-1250,"event equity")
  quote(e,1,5700,1) e:AdvanceClock(.25) near(a.Realized,-6250,"realized") near(a.Balance,-1250,"balance")
  return "Equity −$1,250 → blown; liquidated at −$6,250 realized"
 end)
 test("Negative open P&L with positive equity is not blown",function()
  local e,f=exchange() f:Start("3") local id=f:Owner("3")
  quote(e,-1,5825,1) place(e,id,1,1) mark(e,5760) e:AdvanceClock(.25)
  local a=e.Accounts[id] near(e:Summary(a).Unrealized,-3250,"open P&L") near(e:Summary(a).Equity,1750,"equity")
  assert(not a.Locked and a.Positions.ES,"Positive equity liquidated")
  local row=tier(f:View("3"),"F5K") assert(not row.Depleted and not row.Breached and row.CanRestart==nil and row.Closing==nil)
  assert(#depletions(f:TakeEvents("3"))==0,"Notice raised for open loss")
  assert(not f:Restart("3","F5K"),"Restarted an account in good standing")
  return "Open P&L −$3,250 / equity $1,750: no notice, no restart"
 end)
 test("Delayed and partial liquidation report accurate closing status",function()
  local e,f=exchange() f:Start("4") local id=f:Owner("4") local a=e.Accounts[id]
  quote(e,-1,5825,3) place(e,id,1,3) mark(e,5790) e:AdvanceClock(.25) e:AdvanceClock(.25)
  assert(a.Locked and a.Positions.ES.Quantity==3,"Empty book should leave the position closing")
  local row=tier(f:View("4"),"F5K") assert(row.Depleted and row.Closing and not row.CanRestart and row.Positions==1 and row.OpenContracts==3)
  local ok,msg=f:Restart("4","F5K") assert(not ok and msg:find("Closing remaining positions"),"Restart allowed while closing")
  assert(#depletions(f:TakeEvents("4"))==1)
  quote(e,1,5790,1) e:AdvanceClock(.25)
  assert(a.Positions.ES and a.Positions.ES.Quantity==2,"Partial liquidation lost exposure")
  row=tier(f:View("4"),"F5K") assert(row.Closing and not row.CanRestart and row.OpenContracts==2,"Partial liquidation reported as finished")
  quote(e,1,5790,2) e:AdvanceClock(.25)
  row=tier(f:View("4"),"F5K") assert(not a.Positions.ES and not row.Closing and row.CanRestart and row.OpenContracts==0)
  assert(#depletions(f:TakeEvents("4"))==0,"Status changes re-announced the depletion")
  near(a.Realized,-5250,"realized")
  return "3 open (empty book) → 2 open (partial) → flat; restart only when flat; one notice"
 end)
 test("Restart succeeds once, restores capital and keeps losses/history",function()
  local e,f=exchange() f:Start("5") local id=f:Owner("5") local a=e.Accounts[id]
  quote(e,-1,5825,3) place(e,id,1,3) mark(e,5790) quote(e,1,5790,3) e:AdvanceClock(.25)
  assert(a.Locked and not a.Positions.ES) f:TakeEvents("5")
  local history=#a.History
  local ok1=f:Restart("5","F5K") local ok2,duplicate=f:Restart("5","F5K")
  assert(ok1 and not ok2 and duplicate:find("already restarted") and playerAccounts(e,"5")==2,"Duplicate restart created another attempt")
  e:AdvanceClock(.25) assert(not f:Restart("5","F5K"),"Fresh attempt restarted again")
  local fresh=e.Accounts[f:Owner("5")] assert(fresh.Id~=id and fresh.Balance==5000 and fresh.Base==5000 and not fresh.Locked)
  assert(a.Retired and #a.History==history and a.Locked,"Earlier attempt was altered")
  local view=f:View("5") local row=tier(view,"F5K")
  assert(row.Attempt==2 and row.Balance==5000 and not row.Depleted and row.CanRestart==nil)
  near(row.PriorRealized,-5250,"prior realized") near(view.Earned,-5250,"net realized")
  near(view.Next.Remaining,8250,"unlock remaining")
  quote(e,-1,5790,1) place(e,fresh.Id,1,1) mark(e,5690)
  local ev=depletions(f:TakeEvents("5"))[1] assert(ev and ev.Event=="F5K:2" and ev.Attempt==2,"New attempt's depletion not announced")
  return "Attempt 2 at $5,000; duplicate restart rejected; −$5,250 and history kept; attempt 2 has its own notice"
 end)
 test("Copy follower blown: lead and other accounts keep positions; copies skip until restart",function()
  local e,f=exchange() f:Start("6")
  local p=f:Profile("6") p.Tiers.F10K={State="Unlocked",UnlockedAt=e.Time,Earned=0,Announced=true}
  assert(f:Activate("6","F10K")) assert(f:SetCopy("6",{Enabled=1,Leader="F10K",Followers="F5K",Sizing="Same"}))
  f:Start("7") local other=f:Owner("7") quote(e,-1,20500,1,"NQ") place(e,other,1,1,"NQ")
  local lead=p.Tiers.F10K.Account local follower=p.Tiers.F5K.Account
  local function leadOrder(side,qty)
   local req={Action="Place",Contract="ES",Direction=side,Quantity=qty,Type="Market",StopTicks=side>0 and 2000 or nil}
   local plan=f:Plan("6",lead) local ok,res=Funded.Perform(e,lead,req) return ok,res,f:Mirror(plan,req,ok,res,f:Context(lead,req))
  end
  quote(e,-1,5825,2) local ok,_,copies=leadOrder(1,1) assert(ok and copies.Copied==1)
  local stop=e.Accounts[lead].Positions.ES.Stop
  mark(e,5715) quote(e,1,5715,1) e:AdvanceClock(.25)
  local L,F=e.Accounts[lead],e.Accounts[follower]
  assert(F.Locked and not F.Positions.ES,"Follower was not liquidated")
  assert(not L.Locked and L.Positions.ES and L.Positions.ES.Quantity==1 and L.Positions.ES.Stop==stop,"Lead position changed")
  assert(e.Accounts[other].Positions.NQ and not e.Accounts[other].Locked,"Another player's account changed")
  local ev=depletions(f:TakeEvents("6")) assert(#ev==1 and ev[1].Tier=="F5K" and ev[1].Role=="Follow" and ev[1].Leader=="$10K")
  local view=f:View("6") assert(tier(view,"F5K").Depleted and tier(view,"F5K").Role=="Follow" and not tier(view,"F10K").Depleted)
  quote(e,1,5715,1) ok,_,copies=leadOrder(-1,1)
  assert(ok and copies.Skipped==1 and copies.Items[1].Message:find("Account blown"),"Blown follower was not skipped clearly")
  assert(not L.Positions.ES and not F.Positions.ES,"Lead close was not independent")
  assert(f:Restart("6","F5K")) view=f:View("6")
  assert(view.Copy.Enabled and view.Copy.Leader=="F10K" and table.find(view.Copy.Followers,"F5K"),"Restart changed copy settings")
  quote(e,-1,5715,2) ok,_,copies=leadOrder(1,1) assert(ok and copies.Copied==1,"Restarted follower did not resume copying")
  local renewed=e.Accounts[p.Tiers.F5K.Account] assert(renewed~=F and renewed.Positions.ES.Quantity==1 and renewed.Balance==5000)
  assert(tier(view,"F10K").State=="Active" and p.Tiers.F10K.Account==lead,"Unlocked account was affected")
  e:Audit()
  return "Follower $5K blown (−$5,500 move); $10K lead kept its ES position and stop; NQ player unchanged; copy skipped then resumed after restart"
 end)
 if typeof(game)=="Instance" then
  test("Notice marker survives a checkpoint round trip; older saves announce an existing depletion once",function()
   local Checkpoint=require(script.Parent.WorldCheckpoint) local Participants=require(script.Parent.Participants)
   local http=game:GetService("HttpService")
   local e=Engine.new(Default,4343) local population=Participants.new(e) for _=1,300 do population:Step() end
   e:AddAccount("t:maker",1e9,100000,0.99,false) e:AddAccount("t:taker",1e9,100000,0.99,false)
   local f=Funded.new(e,deep(Ladder),Default) f:Start("9") local id=f:Owner("9")
   assert(select(1,e:Submit(id,{Contract="ES",Direction=1,Quantity=1,Type="Market"})))
   local last=e.Books.ES.Last*e.Books.ES.Spec.Tick
   assert(e:Submit("t:maker",{Contract="ES",Direction=-1,Quantity=10000,Type="Limit",Price=last-150}))
   assert(e:Submit("t:taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"}))
   for _=1,40 do population:Step() end
   assert(e.Accounts[id].Locked,"Crash did not deplete")
   assert(#depletions(f:TakeEvents("9"))==1)
   local encoded=http:JSONDecode(http:JSONEncode(Checkpoint.Encode(Checkpoint.Capture(e,population))))
   local restored=Checkpoint.Restore(Checkpoint.Decode(encoded),Default)
   local g=Funded.new(restored,deep(Ladder),Default)
   assert(#depletions(g:TakeEvents("9"))==0,"Restored depletion announced again")
   assert(tier(g:View("9"),"F5K").Depleted,"Depleted status lost on restore")
   g:Profile("9").Tiers.F5K.DepletionNotice=nil -- a profile saved before this update
   assert(#depletions(g:TakeEvents("9"))==1 and #depletions(g:TakeEvents("9"))==0)
   restored:Audit()
   return {Restored=true,Event=tier(g:View("9"),"F5K").DepletionEvent}
  end)
 end
 return report
end
return Tests
