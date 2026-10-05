-- In-memory regression tests only: no DataStore, real player, or live exchange access.
local E=require(script.Parent.MarketEngine)
local F=require(script.Parent.FundedAccounts)
local P=require(script.Parent.Participants)
local Checkpoint=require(script.Parent.WorldCheckpoint)
local Config=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local Ladder=require(game.ReplicatedStorage.MarketReign.ProgressionConfig)
local T={}
local function clone(v)if type(v)~="table"then return v end local r={}for k,x in pairs(v)do r[k]=clone(x)end return r end
local function fresh(tier)
 local e=E.new(Config,4527)
 e:AddAccount("maker",1e9,10000,.99,false)
 local a=e:AddAccount("test",tier.Size,tier.MaxContracts,Ladder.MarginUse,true)
 return e,a
end
local function request(side,qty,price,key)
 return {Action="Place",Contract=key or "NQ",Direction=side,Quantity=qty,Type=price and "Limit"or"Market",Price=price,StopTicks=40,TargetTicks=120}
end
local function submit(e,id,r)local ok,v=e:Submit(id,r);assert(ok,tostring(v));return v end
local function quote(e,side,qty,price,key)
 local r=request(side,qty,price or Config.Contracts[key or "NQ"].Last,key);r.StopTicks=nil;r.TargetTicks=nil
 return submit(e,"maker",r)
end
local function rejected(e,a,r,max,reason)
 local ok,msg=e:Submit(a.Id,r)
 assert(not ok,"Excess order accepted")
 assert(msg:find("Maximum currently available: "..max.." "..r.Contract,1,true),msg)
 if reason then assert(msg:lower():find(reason,1,true),msg)end
end
function T.Run()
 local results={}
 local function test(name,fn)local ok,msg=pcall(fn);table.insert(results,{Name=name,Passed=ok,Detail=ok and (msg or "Passed")or tostring(msg)})end
 for i,tier in ipairs(Ladder.Tiers)do
  for _,side in ipairs({1,-1})do
   test(tier.Short..(side==1 and " long "or" short ")..tier.MaxContracts.." NQ with default protection",function()
    assert(tier.MaxContracts==({5,10,25,50,100})[i])
    local e,a=fresh(tier)
    rejected(e,a,request(side,tier.MaxContracts+1),tier.MaxContracts,"limit")
    quote(e,-side,tier.MaxContracts)
    local r=submit(e,a.Id,request(side,tier.MaxContracts))
    assert(r.Filled==tier.MaxContracts and a.Positions.NQ.Quantity==tier.MaxContracts)
    local p=a.Positions.NQ;assert(p.Direction==side and p.Stop and p.Target)
    assert(math.abs(p.Entry-p.Stop)==40*.25 and math.abs(p.Entry-p.Target)==120*.25)
    assert(Config.Contracts.NQ.Multiplier==20 and Config.Contracts.NQ.Tick==.25)
    rejected(e,a,request(side,1),0,"limit")
    e:AdvanceClock(.25);assert(a.Positions.NQ and not a.Liquidating)
    e:Audit()
   end)
  end
 end
 test("Existing exposure, mixed instruments, pending orders and cancellation reserve total capacity",function()
  local e,a=fresh(Ladder.Tiers[1]);quote(e,-1,2);submit(e,a.Id,request(1,2))
  local pending=submit(e,a.Id,request(1,1,20480))
  rejected(e,a,request(1,3),2,"limit")
  submit(e,a.Id,request(1,1,5800,"ES"))
  rejected(e,a,request(1,1),0)
  assert(e:Cancel(a.Id,pending.Id));assert(e:OrderCapacity(a,"NQ",1,40)==1) -- ES margin leaves $2,800 buying power
  e:CancelAll(a.Id);assert(e:OrderCapacity(a,"NQ",1,40)==3)
 end)
 test("Both directions reserve worst-case entries; reduce-only exits do not reserve new exposure",function()
  local e,a=fresh(Ladder.Tiers[1]);submit(e,a.Id,request(1,5,20480));submit(e,a.Id,request(-1,5,20490))
  rejected(e,a,request(1,1),0);rejected(e,a,request(-1,1),0)
  e:CancelAll(a.Id);quote(e,-1,5);submit(e,a.Id,request(1,5))
  local close=request(-1,5,20490);close.ReduceOnly=true;submit(e,a.Id,close)
  assert(e:OrderCapacity(a,"NQ",-1,40)==10)
  rejected(e,a,request(1,1),0)
 end)
 test("Reduced equity controls buying power independently of stop distance",function()
  local e,a=fresh(Ladder.Tiers[1]);a.Balance=3000
  rejected(e,a,request(1,4),3,"margin");rejected(e,a,request(-1,4),3,"margin")
  a.Balance=5000;local r=request(1,6);r.StopTicks=1000
  rejected(e,a,r,5,"limit")
 a.Balance=0;rejected(e,a,request(-1,1),0)
 end)
 for _,key in ipairs(Config.ContractOrder)do
  for _,side in ipairs({1,-1})do
   test(key.." wide stops allow entry and dragging; depletion still liquidates "..side,function()
    local e,a=fresh(Ladder.Tiers[1]);local spec=Config.Contracts[key];local qty=2
    e:AddAccount("taker",1e9,10000,.99,false)
    local function tickPrice(price)return math.round(price/spec.Tick)*spec.Tick end
    local function mark(price)
     quote(e,side,1,price,key)
     local r=request(-side,1,nil,key);r.StopTicks=nil;r.TargetTicks=nil
     submit(e,"taker",r)
    end
    quote(e,-side,qty,spec.Last,key)
    local entry=request(side,qty,nil,key)
    entry.StopTicks=math.ceil(a.Base*1.5/(qty*spec.Multiplier*spec.Tick))
    assert(submit(e,a.Id,entry).Filled==qty,"Wide initial stop rejected")
    local p=a.Positions[key];local target=p.Target;local initial=p.Stop
    local wide=tickPrice(p.Entry-side*a.Base*2/(qty*spec.Multiplier))
    assert(e:AmendProtection(a.Id,{Contract=key,OrderId=p.Id,Protection="Stop",Price=wide,ExpectedPrice=initial}))
    assert(p.Stop==wide and p.Target==target and math.abs(p.Entry-wide)*qty*spec.Multiplier>a.Base)
    assert(not e:AmendProtection(a.Id,{Contract=key,OrderId=p.Id,Protection="Stop",Price=wide,ExpectedPrice=initial}),"Stale drag accepted")
    local pending=submit(e,a.Id,request(side,1,wide,key))
    mark(tickPrice(p.Entry-side*(a.Base-250)/(qty*spec.Multiplier)))
    assert(e:Summary(a).Equity>0 and e:Summary(a).Equity<e:Summary(a).Margin)
    e:AdvanceClock(.25)
    assert(a.Positions[key]==p and not p.Triggered and not a.Locked and not a.Liquidating,"Positive equity liquidated")
    rejected(e,a,request(side,1,nil,key),0,"margin")
    -- Alternate exact-zero and negative-equity boundaries across long/short cases.
    local beyond=side==1 and 0 or 250
    local exit=tickPrice(p.Entry-side*(a.Base+beyond)/(qty*spec.Multiplier))
    mark(exit)
    assert(a.Locked and p.Triggered=="Account depleted" and not p.Stop and not p.Target,"Depletion did not latch")
    e:AdvanceClock(.25)
    assert(not e.Orders[pending.Id] and a.Positions[key]==p,"Empty-book liquidation must cancel entries and keep retrying")
    rejected(e,a,request(side,1,nil,key),0,"depleted")
    quote(e,side,1,exit,key);e:AdvanceClock(.25)
    assert(a.Positions[key].Quantity==1 and a.Locked,"Partial liquidation lost remaining exposure")
    quote(e,side,1,exit,key);e:AdvanceClock(.25)
    assert(not a.Positions[key] and a.Locked and math.abs(a.Balance+beyond)<1e-5)
    assert(#a.History==2 and math.abs(a.Realized+a.Base+beyond)<1e-5)
    e:Audit()
   end)
  end
 end
 test("Waiting entries recheck buying power before execution",function()
  local e,a=fresh(Ladder.Tiers[1]);local r=submit(e,a.Id,request(1,5,20480))
  a.Balance=3000;quote(e,-1,5,20480)
  assert(not a.Positions.NQ and not e.Orders[r.Id],"Underfunded resting entry filled")
 end)
 test("Partial fills plus the unfilled remainder reserve capacity exactly once",function()
  local e,a=fresh(Ladder.Tiers[1]);quote(e,-1,2,20485.5)
  local r=submit(e,a.Id,request(1,5,20485.5));assert(r.Filled==2 and r.Remaining==3)
  rejected(e,a,request(1,1),0);quote(e,-1,3,20485.5)
  assert(a.Positions.NQ.Quantity==5 and not e.Orders[r.Id]);e:Audit()
 end)
 test("Invalid, fractional, infinite and oversized remote quantities are rejected",function()
  local e,a=fresh(Ladder.Tiers[5])
  for _,n in ipairs({0,-1,1.5,math.huge,0/0})do assert(not e:Submit(a.Id,request(1,n)))end
  rejected(e,a,request(1,101),100);rejected(e,a,request(-1,1000),100)
 end)
 for _,side in ipairs({1,-1})do
  test("Copy trading validates each follower "..side,function()
   local e,lead=fresh(Ladder.Tiers[1]);local large=e:AddAccount("large",100000,100,.8,true)
   local f=F.new(e,Ladder,Config)
   local plan={Leader=Ladder.Tiers[1],Followers={{Key="F100K",Id=large.Id,Tier=Ladder.Tiers[5]}},Sizing="Proportional"}
   quote(e,-side,105);local req=request(side,5);req.StopTicks=1000;local res=submit(e,lead.Id,req)
   local copied=f:Mirror(plan,req,true,res,{})
   assert(copied.Copied==1 and large.Positions.NQ.Quantity==100)
   local p=lead.Positions.NQ;local wide=p.Entry-side*300
   local amend={Action="AmendProtection",Contract="NQ",OrderId=p.Id,Protection="Stop",Price=wide,ExpectedPrice=p.Stop}
   local context=f:Context(lead.Id,amend);local ok,msg=F.Perform(e,lead.Id,amend);assert(ok,msg)
   copied=f:Mirror(plan,amend,ok,msg,context)
   assert(copied.Copied==1 and p.Stop==wide and large.Positions.NQ.Stop==wide,"Wide stop drag did not copy")
   local small=e:AddAccount("small",5000,5,.8,true)
   local down={Leader=Ladder.Tiers[5],Followers={{Key="F5K",Id=small.Id,Tier=Ladder.Tiers[1]}},Sizing="Same"}
   local rejectedCopy=f:Mirror(down,request(side,100),true,res,{})
   assert(rejectedCopy.Rejected==1 and rejectedCopy.Items[1].Message:find("Maximum currently available: 5 NQ",1,true))
   submit(e,small.Id,request(side,3,side==1 and 20480 or 20490))
   down.Sizing="Proportional"
   rejectedCopy=f:Mirror(down,request(side,100),true,res,{})
   assert(rejectedCopy.Rejected==1 and rejectedCopy.Items[1].Message:find("Maximum currently available: 2 NQ",1,true))
   e:CancelAll(small.Id);small.Balance=1000
   rejectedCopy=f:Mirror(down,request(side,100),true,res,{})
   assert(rejectedCopy.Rejected==1 and rejectedCopy.Items[1].Message:find("Maximum currently available: 1 NQ",1,true))
  end)
 end
 test("Saved old margins/caps adopt current policy without changing player progress or exposure",function()
  local old=clone(Config);old.Contracts.NQ.Margin=2000;old.MaxPlayerInventory=40;old.MaxPlayerQuantity=20
  local e=E.new(old,592);local population=P.new(e);local f=F.new(e,Ladder,old);f:Start("migration")
  local profile=e.Profiles.migration
  local id=f:_open("migration",profile,"F100K",1)
  profile.Tiers.F100K={State="Active",Account=id,Attempt=1};profile.Active="F100K"
  local a=e.Accounts[id];a.Limit=40
  e:AddAccount("maker",1e9,10000,.99,false);quote(e,-1,1);submit(e,id,request(1,1))
  submit(e,id,request(1,1,20480))
  local snapshot=Checkpoint.Capture(e,population)
  local restored=Checkpoint.Restore(snapshot,Config);F.new(restored,Ladder,Config)
  local after=restored.Accounts[id]
  assert(after.Balance==a.Balance and after.Realized==a.Realized and #after.History==#a.History)
  assert(after.Positions.NQ.Entry==a.Positions.NQ.Entry and after.Positions.NQ.Quantity==1)
  assert(after.Positions.NQ.Stop==a.Positions.NQ.Stop and next(after.OpenOrders))
  assert(after.Limit==100 and restored.Config.MaxPlayerQuantity==100 and restored.Books.NQ.Spec.Margin==750)
  assert(restored.Profiles.migration.ProgressCredit==profile.ProgressCredit)
  assert(snapshot.Config.Contracts.NQ.Margin==2000 and a.Limit==40,"Restore mutated source checkpoint")
 end)
 return results
end
return T
