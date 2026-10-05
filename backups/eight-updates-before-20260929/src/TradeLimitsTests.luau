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
  rejected(e,a,request(1,2),1,"limit") -- 2 held + 1 pending NQ + 1 pending ES = 4; the account total is 5
  assert(e:Cancel(a.Id,pending.Id));assert(e:OrderCapacity(a,"NQ",1,40)==2) -- 5 total minus the ES entry minus 2 held
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
 -- Consistent 5-contract maximum on the $5K for every E-mini (equal $750 simulated margin).
 for _,key in ipairs(Config.ContractOrder)do
  for _,side in ipairs({1,-1})do
   test("$5K "..key..(side==1 and " long"or" short").." reaches exactly 5 contracts; the 6th is rejected",function()
    assert(Config.Contracts[key].Margin==750,"Unequal E-mini margin")
    local e,a=fresh(Ladder.Tiers[1]);local last=Config.Contracts[key].Last
    assert(e:OrderCapacity(a,key,side)==5,"Fresh $5K capacity for "..key.." is "..e:OrderCapacity(a,key,side))
    rejected(e,a,request(side,6,nil,key),5,"limit")
    quote(e,-side,5,last,key);local r=submit(e,a.Id,request(side,5,nil,key))
    assert(r.Filled==5 and a.Positions[key].Quantity==5)
    rejected(e,a,request(side,1,nil,key),0,"limit")
    local snap=e:Snapshot(a.Id,key,"1m",false)
    assert(snap.Capacity[key][side==1 and "Buy" or "Sell"]==0 and snap.Capacity[key][side==1 and "Sell" or "Buy"]==10 and snap.Limit==5,"Snapshot capacity for the UI")
    e:Audit()
   end)
  end
 end
 test("Stop entries validate side, tick, band and account; they arm off-book and reserve the cap",function()
  local e,a=fresh(Ladder.Tiers[1]);local last=Config.Contracts.ES.Last
  local function stop(side,qty,price)local r=request(side,qty,price,"ES");r.Type="Stop";return r end
  assert(not e:Submit(a.Id,stop(1,1,last-1)),"Stop buy below market accepted")
  assert(not e:Submit(a.Id,stop(-1,1,last+1)),"Stop sell above market accepted")
  assert(not e:Submit(a.Id,stop(1,1,last)),"Stop buy at market accepted")
  assert(not e:Submit(a.Id,stop(1,1,last+0.1)),"Off-tick stop accepted")
  assert(not e:Submit(a.Id,stop(1,1,last*1.2)),"Stop outside the price band accepted")
  local reduce=stop(-1,1,last-5);reduce.ReduceOnly=true;assert(not e:Submit(a.Id,reduce),"Reduce-only stop accepted")
  local r=submit(e,a.Id,stop(1,3,last+5))
  assert(r.Status=="Stop armed" and r.Filled==0 and e.Orders[r.Id].Type=="Stop" and #e.Books.ES.Bids==0 and #e.Books.ES.Asks==0,"Stop rested in the book")
  rejected(e,a,request(1,3,nil,"ES"),2,"limit") -- 3 armed + 3 would exceed 5
  local sell=submit(e,a.Id,stop(-1,5,last-5)) -- opposite side is independently worst-case
  rejected(e,a,request(-1,1,last+50,"ES"),0,"limit")
  local snap=e:Snapshot(a.Id,"ES","1m",false)
  local kinds={} for _,o in ipairs(snap.Orders)do kinds[o.Kind]=o.Status end
  assert(kinds["Buy stop"]=="Armed" and kinds["Sell stop"]=="Armed","Orders tab labels")
  assert(e:Cancel(a.Id,sell.Id) and e:Cancel(a.Id,r.Id) and e:OrderCapacity(a,"ES",1)==5,"Cancel released capacity")
  e:Audit()
 end)
 test("A stop triggers on the trade that reaches it, fills at market with SL/TP, and reports once",function()
  local e,a=fresh(Ladder.Tiers[1]);e:AddAccount("taker",1e9,10000,.99,false);local last=Config.Contracts.ES.Last
  local r=request(1,2,last+2,"ES");r.Type="Stop";local armed=submit(e,a.Id,r)
  quote(e,-1,1,last+1,"ES");submit(e,"taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"});e:ProcessStops()
  assert(e.Orders[armed.Id] and not a.Positions.ES,"Triggered before the stop price")
  quote(e,-1,1,last+2,"ES");quote(e,-1,5,last+3,"ES");submit(e,"taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"})
  assert(e.Orders[armed.Id].Triggered,"Did not latch on the reaching trade")
  e:ProcessStops()
  assert(not e.Orders[armed.Id] and a.Positions.ES and a.Positions.ES.Quantity==2 and a.Positions.ES.Stop and a.Positions.ES.Target,"Stop did not become a protected market entry")
  assert(a.Triggers[1].Id==armed.Id and a.Triggers[1].Ok and a.Triggers[1].Filled==2 and #a.Triggers==1,"Trigger report")
  e:ProcessStops();assert(#a.Triggers==1,"Reported twice")
  local s=request(-1,1,a.Positions.ES.Entry-20,"ES");s.Type="Stop";submit(e,a.Id,s)
  e:Audit()
 end)
 test("A triggered stop in an empty book waits briefly for liquidity, then fills or is cancelled",function()
  local e,a=fresh(Ladder.Tiers[1]);e:AddAccount("taker",1e9,10000,.99,false);local last=Config.Contracts.ES.Last
  local r=request(1,2,last+2,"ES");r.Type="Stop";local armed=submit(e,a.Id,r)
  quote(e,-1,1,last+2,"ES");submit(e,"taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"}) -- reaches the stop, empties the book
  e:ProcessStops()
  local o=e.Orders[armed.Id];assert(o and o.Triggered and a.OpenOrders[armed.Id] and not a.Positions.ES,"Stop dropped instead of waiting")
  assert(e:Snapshot(a.Id,"ES","1m",false).Orders[1].Status=="Triggered" and e:OrderCapacity(a,"ES",1)==3,"Waiting stop must stay visible and reserved")
  quote(e,-1,1,last+3,"ES");e:AdvanceClock(.25) -- 1 of 2 available
  assert(a.Positions.ES and a.Positions.ES.Quantity==1 and e.Orders[armed.Id] and e.Orders[armed.Id].Remaining==1,"Partial liquidity not taken")
  quote(e,-1,1,last+4,"ES");e:AdvanceClock(.25)
  assert(a.Positions.ES.Quantity==2 and not e.Orders[armed.Id] and a.Triggers[1].Ok and a.Triggers[1].Filled==2,"Stop did not complete")
  local r2=request(1,1,last+10,"ES");r2.Type="Stop";local second=submit(e,a.Id,r2)
  quote(e,-1,1,last+10,"ES");submit(e,"taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"})
  for _=1,24 do e:AdvanceClock(.25) end
  assert(not e.Orders[second.Id] and a.Triggers[1].Id==second.Id and a.Triggers[1].Ok==false and a.Positions.ES.Quantity==2,"Stale stop not cancelled")
  e:Audit()
 end)
 test("Triggered stops re-validate: they cannot fill past the 5-contract cap or current buying power",function()
  local e,a=fresh(Ladder.Tiers[1]);e:AddAccount("taker",1e9,10000,.99,false);local last=Config.Contracts.ES.Last
  local r=request(1,5,last+2,"ES");r.Type="Stop";local armed=submit(e,a.Id,r)
  -- The account's limit tightens while the stop waits (e.g. new policy); the fill must respect it.
  a.Limit=3
  quote(e,-1,10,last+2,"ES");submit(e,"taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"});e:ProcessStops()
  assert(not e.Orders[armed.Id] and not a.Positions.ES,"Stop filled past the contract limit")
  assert(a.Triggers[1].Ok==false and tostring(a.Triggers[1].Message):find("Maximum currently available: 3 ES",1,true),"Rejection not reported: "..tostring(a.Triggers[1].Message))
  e:CancelAll("maker");a.Limit=5;local r2=request(1,4,last+4,"ES");r2.Type="Stop";local second=submit(e,a.Id,r2)
  a.Balance=2000 -- losses elsewhere: $1,600 buying power = 2 contracts
  quote(e,-1,10,last+4,"ES");submit(e,"taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"});e:ProcessStops()
  assert(not e.Orders[second.Id] and not a.Positions.ES and a.Triggers[1].Ok==false,"Stop filled past buying power")
  a.Balance=5000;e:Audit()
 end)
 test("Armed stops survive a checkpoint round trip off-book and still trigger",function()
  local e=E.new(Config,3131);local population=P.new(e);for _=1,120 do population:Step() end
  local f=F.new(e,Ladder,Config);f:Start("stops");local id=f:Owner("stops")
  local last=e.Books.ES.Last*e.Books.ES.Spec.Tick
  local r=request(1,2,last+50,"ES");r.Type="Stop";local armed=submit(e,id,r)
  local snapshot=Checkpoint.Capture(e,population);assert(snapshot.Version==4)
  local restored,rp=Checkpoint.Restore(Checkpoint.Decode(Checkpoint.Encode(snapshot)),Config)
  local o=restored.Orders[armed.Id];assert(o and o.Type=="Stop" and restored.Accounts[id].OpenOrders[armed.Id],"Stop lost on restore")
  for _,side in ipairs({"Bids","Asks"})do for _,l in ipairs(restored.Books.ES[side])do for _,x in ipairs(l.Orders)do assert(x.Id~=armed.Id,"Stop rested in the book")end end end
  restored:AddAccount("t:maker",1e9,10000,.99,false);restored:AddAccount("t:taker",1e9,10000,.99,false)
  for _,aid in ipairs(restored.AccountOrder)do if not restored.Accounts[aid].Player then restored:CancelAll(aid)end end
  restored:ProcessStops() -- flush any participant exits carried in the checkpoint
  local top=o.Price*restored.Books.ES.Spec.Tick
  submit(restored,"t:maker",{Contract="ES",Direction=-1,Quantity=1000,Type="Limit",Price=top})
  submit(restored,"t:taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"});restored:ProcessStops()
  assert(not restored.Orders[armed.Id] and restored.Accounts[id].Positions.ES and restored.Accounts[id].Positions.ES.Quantity==2,"Restored stop did not trigger")
  restored:Audit()
 end)
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
