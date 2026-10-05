-- In-memory regression tests only: no DataStore, real player, or live exchange access.
local E=require(script.Parent.MarketEngine)
local F=require(script.Parent.FundedAccounts)
local P=require(script.Parent.Participants)
local Checkpoint=require(script.Parent.WorldCheckpoint)
local Config=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local Ladder=table.clone(require(game.ReplicatedStorage.MarketReign.ProgressionConfig))
-- One account limit; the remaining suite covers exchange sizing and protection boundaries.
Ladder.Tiers={{Id="Single",Size=Ladder.StartingBalance,MaxContracts=Ladder.MaxContracts,Short="Trading account"}}
local T={}
local function clone(v)if type(v)~="table"then return v end local r={}for k,x in pairs(v)do r[k]=clone(x)end return r end
local function fresh(tier)
 local e=E.new(Config,4527)
 e:AddAccount("maker",1e9,10000,.99,false)
 local a=e:AddAccount("test",tier.Size,tier.MaxContracts,Ladder.MarginUse,true)
 return e,a
end
local function request(side,qty,price,key)
 return {Action="Place",Contract=key or "BT",Direction=side,Quantity=qty,Type=price and "Limit"or"Market",Price=price,StopTicks=40,TargetTicks=120}
end
local function submit(e,id,r)local ok,v=e:Submit(id,r);assert(ok,tostring(v));return v end
local function quote(e,side,qty,price,key)
 local r=request(side,qty,price or Config.Contracts[key or "BT"].Last,key);r.StopTicks=nil;r.TargetTicks=nil
 return submit(e,"maker",r)
end
-- One participant-to-participant execution at `price`: the only way the market price moves.
local function trade(e,price,key)
 e:AddAccount("t:seller",1e9,10000,.99,false);e:AddAccount("t:buyer",1e9,10000,.99,false);e:CancelAll("maker")
 submit(e,"t:seller",{Contract=key or "BT",Direction=-1,Quantity=1,Type="Limit",Price=price})
 local r=submit(e,"t:buyer",{Contract=key or "BT",Direction=1,Quantity=1,Type="Limit",Price=price})
 assert(r.Filled==1,"Market trade did not print at "..price)
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
   test(tier.Short..(side==1 and " long "or" short ")..tier.MaxContracts.." BT with default protection",function()
    assert(tier.MaxContracts==({5,10,25,50,100})[i])
    local e,a=fresh(tier)
    rejected(e,a,request(side,tier.MaxContracts+1),tier.MaxContracts,"limit")
    quote(e,-side,tier.MaxContracts)
    local r=submit(e,a.Id,request(side,tier.MaxContracts))
    assert(r.Filled==tier.MaxContracts and a.Positions.BT.Quantity==tier.MaxContracts)
    local p=a.Positions.BT;assert(p.Direction==side and p.Stop and p.Target)
    assert(math.abs(p.Entry-p.Stop)==40*.25 and math.abs(p.Entry-p.Target)==120*.25)
    assert(Config.Contracts.BT.Multiplier==20 and Config.Contracts.BT.Tick==.25)
    rejected(e,a,request(side,1),0,"limit")
    e:AdvanceClock(.25);assert(a.Positions.BT and not a.Liquidating)
    e:Audit()
   end)
  end
 end
 test("Existing exposure, mixed instruments, pending orders and cancellation reserve total capacity",function()
  local e,a=fresh(Ladder.Tiers[1]);quote(e,-1,2);submit(e,a.Id,request(1,2))
  local pending=submit(e,a.Id,request(1,1,20480))
  rejected(e,a,request(1,3),2,"limit")
  submit(e,a.Id,request(1,1,5800,"BX"))
  rejected(e,a,request(1,2),1,"limit") -- 2 held + 1 pending BT + 1 pending BX = 4; the account total is 5
  assert(e:Cancel(a.Id,pending.Id));assert(e:OrderCapacity(a,"BT",1,40)==2) -- 5 total minus the BX entry minus 2 held
  e:CancelAll(a.Id);assert(e:OrderCapacity(a,"BT",1,40)==3)
 end)
 test("Both directions reserve worst-case entries; reduce-only exits do not reserve new exposure",function()
  local e,a=fresh(Ladder.Tiers[1]);submit(e,a.Id,request(1,5,20480));submit(e,a.Id,request(-1,5,20490))
  rejected(e,a,request(1,1),0);rejected(e,a,request(-1,1),0)
  e:CancelAll(a.Id);quote(e,-1,5);submit(e,a.Id,request(1,5))
  local close=request(-1,5,20490);close.ReduceOnly=true;submit(e,a.Id,close)
  assert(e:OrderCapacity(a,"BT",-1,40)==10)
  rejected(e,a,request(1,1),0)
 end)
 test("Balance, equity and margin never reduce the contract limit; only $0 equity stops new entries",function()
  local e,a=fresh(Ladder.Tiers[1]);a.Balance=1000;a.Realized=1000-a.Base -- a starter account reduced to $1,000
  for _,key in ipairs(Config.ContractOrder)do
   assert(e:OrderCapacity(a,key,1)==5 and e:OrderCapacity(a,key,-1)==5,"Low equity reduced "..key.." capacity")
   local snap=e:Snapshot(a.Id,key,"1m",false);assert(snap.Capacity[key].Buy==5 and snap.Capacity[key].Sell==5,"UI capacity")
  end
  rejected(e,a,request(1,6),5,"limit")
  local r=request(1,5);r.StopTicks=1000;quote(e,-1,5)
  assert(submit(e,a.Id,r).Filled==5 and a.Positions.BT.Quantity==5,"5 BT rejected on a $1,000 balance")
  rejected(e,a,request(1,1),0,"limit")
  assert(F.Perform(e,a.Id,{Action="Close",Contract="BT"}));assert(not a.Positions.BT)
  a.Balance=0;a.Realized=-a.Base;rejected(e,a,request(-1,1),0,"$0")
  e:AdvanceClock(.25);assert(a.Locked);rejected(e,a,request(-1,1),0,"depleted")
  a.Balance=a.Base;a.Realized=0
 end)
 for _,key in ipairs(Config.ContractOrder)do
  for _,side in ipairs({1,-1})do
   test(key.." wide stops allow entry and dragging; depletion still liquidates "..side,function()
    local e,a=fresh(Ladder.Tiers[1]);local spec=Config.Contracts[key];local qty=2
    e:AddAccount("taker",1e9,10000,.99,false)
    local function tickPrice(price)return math.round(price/spec.Tick)*spec.Tick end
    local function mark(price)
     e:CancelAll("maker") -- player fills never consume quotes; clear them so the next print sets the price
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
    assert(e:OrderCapacity(a,key,side)==2,"Low equity must not reduce the contract limit (2 held + 1 working of 5)")
    -- Alternate exact-zero and negative-equity boundaries across long/short cases.
    local beyond=side==1 and 0 or 250
    local exit=tickPrice(p.Entry-side*(a.Base+beyond)/(qty*spec.Multiplier))
    mark(exit)
    assert(a.Locked and p.Triggered=="Account depleted" and not p.Stop and not p.Target,"Depletion did not latch")
    local lastTick,volume=e.Books[key].Last,e.Books[key].Volume
    e:AdvanceClock(.25)
    -- Liquidation cancels entries and closes at the market price in one step, off-book.
    assert(not e.Orders[pending.Id] and not a.Positions[key] and a.Locked,"Liquidation must cancel entries and close at the market")
    assert(e.Books[key].Last==lastTick and e.Books[key].Volume==volume,"Liquidation moved the market price")
    rejected(e,a,request(side,1,nil,key),0,"depleted")
    -- The exit is tick-rounded, so on a 0.1-tick market (BG) the loss can differ from Base+beyond by under a tick per contract.
    local loss=(p.Entry-exit)*side*qty*spec.Multiplier
    assert(loss>=a.Base and math.abs(loss-(a.Base+beyond))<=qty*spec.Tick*spec.Multiplier and #a.History==1)
    assert(math.abs(a.Realized+loss)<1e-5 and math.abs(a.Balance-(a.Base-loss))<1e-5)
    e:Audit()
   end)
  end
 end
 -- Consistent 5-contract maximum on the $10K for every market (equal $750 simulated margin).
 for _,key in ipairs(Config.ContractOrder)do
  for _,side in ipairs({1,-1})do
   test("$10K "..key..(side==1 and " long"or" short").." reaches exactly 5 contracts; the 6th is rejected",function()
    assert(Config.Contracts[key].Margin==750,"Unequal market margin")
    local e,a=fresh(Ladder.Tiers[1]);local last=Config.Contracts[key].Last
    assert(e:OrderCapacity(a,key,side)==5,"Fresh $10K capacity for "..key.." is "..e:OrderCapacity(a,key,side))
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
  local e,a=fresh(Ladder.Tiers[1]);local last=Config.Contracts.BX.Last
  local function stop(side,qty,price)local r=request(side,qty,price,"BX");r.Type="Stop";return r end
  assert(not e:Submit(a.Id,stop(1,1,last-1)),"Stop buy below market accepted")
  assert(not e:Submit(a.Id,stop(-1,1,last+1)),"Stop sell above market accepted")
  assert(not e:Submit(a.Id,stop(1,1,last)),"Stop buy at market accepted")
  assert(not e:Submit(a.Id,stop(1,1,last+0.1)),"Off-tick stop accepted")
  assert(not e:Submit(a.Id,stop(1,1,last*1.2)),"Stop outside the price band accepted")
  local reduce=stop(-1,1,last-5);reduce.ReduceOnly=true;assert(not e:Submit(a.Id,reduce),"Reduce-only stop accepted")
  local r=submit(e,a.Id,stop(1,3,last+5))
  assert(r.Status=="Stop armed" and r.Filled==0 and e.Orders[r.Id].Type=="Stop" and #e.Books.BX.Bids==0 and #e.Books.BX.Asks==0,"Stop rested in the book")
  rejected(e,a,request(1,3,nil,"BX"),2,"limit") -- 3 armed + 3 would exceed 5
  local sell=submit(e,a.Id,stop(-1,5,last-5)) -- opposite side is independently worst-case
  rejected(e,a,request(-1,1,last+50,"BX"),0,"limit")
  local snap=e:Snapshot(a.Id,"BX","1m",false)
  local kinds={} for _,o in ipairs(snap.Orders)do kinds[o.Kind]=o.Status end
  assert(kinds["Stop Buy"]=="Armed" and kinds["Stop Sell"]=="Armed","Orders tab labels")
  assert(e:Cancel(a.Id,sell.Id) and e:Cancel(a.Id,r.Id) and e:OrderCapacity(a,"BX",1)==5,"Cancel released capacity")
  e:Audit()
 end)
 test("A stop triggers on the trade that reaches it, fills at market with SL/TP, and reports once",function()
  local e,a=fresh(Ladder.Tiers[1]);e:AddAccount("taker",1e9,10000,.99,false);local last=Config.Contracts.BX.Last
  local r=request(1,2,last+2,"BX");r.Type="Stop";local armed=submit(e,a.Id,r)
  quote(e,-1,1,last+1,"BX");submit(e,"taker",{Contract="BX",Direction=1,Quantity=1,Type="Market"});e:ProcessStops()
  assert(e.Orders[armed.Id] and not a.Positions.BX,"Triggered before the stop price")
  quote(e,-1,1,last+2,"BX");quote(e,-1,5,last+3,"BX");submit(e,"taker",{Contract="BX",Direction=1,Quantity=1,Type="Market"})
  assert(e.Orders[armed.Id].Triggered,"Did not latch on the reaching trade")
  e:ProcessStops()
  assert(not e.Orders[armed.Id] and a.Positions.BX and a.Positions.BX.Quantity==2 and a.Positions.BX.Stop and a.Positions.BX.Target,"Stop did not become a protected market entry")
  assert(a.Triggers[1].Id==armed.Id and a.Triggers[1].Ok and a.Triggers[1].Filled==2 and #a.Triggers==1,"Trigger report")
  e:ProcessStops();assert(#a.Triggers==1,"Reported twice")
  local s=request(-1,1,a.Positions.BX.Entry-20,"BX");s.Type="Stop";submit(e,a.Id,s)
  e:Audit()
 end)
 test("A triggered stop fills in full at the market price even when the book is empty, without moving it",function()
  local e,a=fresh(Ladder.Tiers[1]);e:AddAccount("taker",1e9,10000,.99,false);local last=Config.Contracts.BX.Last
  local r=request(1,2,last+2,"BX");r.Type="Stop";local armed=submit(e,a.Id,r)
  quote(e,-1,1,last+2,"BX");submit(e,"taker",{Contract="BX",Direction=1,Quantity=1,Type="Market"}) -- reaches the stop, empties the book
  local lastTick,trades=e.Books.BX.Last,#e.Trades
  e:ProcessStops()
  assert(not e.Orders[armed.Id] and a.Positions.BX and a.Positions.BX.Quantity==2 and a.Positions.BX.Entry==last+2,"Stop did not fill at the last trade")
  assert(a.Triggers[1].Ok and a.Triggers[1].Filled==2 and #e.Books.BX.Asks==0,"Trigger report / book")
  assert(e.Books.BX.Last==lastTick and #e.Trades==trades,"The stop fill printed a trade or moved the price")
  e:Audit()
 end)
 test("Triggered stops re-validate: they cannot fill past the 5-contract cap or current buying power",function()
  local e,a=fresh(Ladder.Tiers[1]);e:AddAccount("taker",1e9,10000,.99,false);local last=Config.Contracts.BX.Last
  local r=request(1,5,last+2,"BX");r.Type="Stop";local armed=submit(e,a.Id,r)
  -- The account's limit tightens while the stop waits (e.g. new policy); the fill must respect it.
  a.Limit=3
  quote(e,-1,10,last+2,"BX");submit(e,"taker",{Contract="BX",Direction=1,Quantity=1,Type="Market"});e:ProcessStops()
  assert(not e.Orders[armed.Id] and not a.Positions.BX,"Stop filled past the contract limit")
  assert(a.Triggers[1].Ok==false and tostring(a.Triggers[1].Message):find("Maximum currently available: 3 BX",1,true),"Rejection not reported: "..tostring(a.Triggers[1].Message))
  e:CancelAll("maker");a.Limit=5;local r2=request(1,4,last+4,"BX");r2.Type="Stop";local second=submit(e,a.Id,r2)
  a.Balance=1000;a.Realized=-4000 -- losses elsewhere never reduce the contract limit
  quote(e,-1,10,last+4,"BX");submit(e,"taker",{Contract="BX",Direction=1,Quantity=1,Type="Market"});e:ProcessStops()
  assert(not e.Orders[second.Id] and a.Positions.BX and a.Positions.BX.Quantity==4 and a.Triggers[1].Ok,"Low balance blocked a stop within the limit")
  a.Balance=a.Base;a.Realized=0;e:Audit()
 end)
 test("Armed stops survive a checkpoint round trip off-book and still trigger",function()
  local e=E.new(Config,3131);local population=P.new(e);for _=1,120 do population:Step() end
  local f=F.new(e,Ladder,Config);f:Start("stops");local id=f:Owner("stops")
  local last=e.Books.BX.Last*e.Books.BX.Spec.Tick
  local r=request(1,2,last+50,"BX");r.Type="Stop";local armed=submit(e,id,r)
  local snapshot=Checkpoint.Capture(e,population);assert(snapshot.Version==Checkpoint.Version)
  local restored,rp=Checkpoint.Restore(Checkpoint.Decode(Checkpoint.Encode(snapshot)),Config)
  local o=restored.Orders[armed.Id];assert(o and o.Type=="Stop" and restored.Accounts[id].OpenOrders[armed.Id],"Stop lost on restore")
  for _,side in ipairs({"Bids","Asks"})do for _,l in ipairs(restored.Books.BX[side])do for _,x in ipairs(l.Orders)do assert(x.Id~=armed.Id,"Stop rested in the book")end end end
  restored:AddAccount("t:maker",1e9,10000,.99,false);restored:AddAccount("t:taker",1e9,10000,.99,false)
  for _,aid in ipairs(restored.AccountOrder)do if not restored.Accounts[aid].Player then restored:CancelAll(aid)end end
  restored:ProcessStops() -- flush any participant exits carried in the checkpoint
  local top=o.Price*restored.Books.BX.Spec.Tick
  submit(restored,"t:maker",{Contract="BX",Direction=-1,Quantity=1000,Type="Limit",Price=top})
  submit(restored,"t:taker",{Contract="BX",Direction=1,Quantity=1,Type="Market"});restored:ProcessStops()
  assert(not restored.Orders[armed.Id] and restored.Accounts[id].Positions.BX and restored.Accounts[id].Positions.BX.Quantity==2,"Restored stop did not trigger")
  restored:Audit()
 end)
 test("Waiting entries fill at their price regardless of balance, but re-check the contract limit",function()
  local e,a=fresh(Ladder.Tiers[1]);local r=submit(e,a.Id,request(1,5,20480))
  a.Balance=1000;a.Realized=-4000;quote(e,-1,5,20480) -- a quote at the limit is not a trade
  assert(not a.Positions.BT and e.Orders[r.Id],"A resting quote filled the player without a trade")
  trade(e,20480.25);assert(not a.Positions.BT,"Filled before the market reached the limit")
  e:CancelAll("maker");trade(e,20480)
  assert(a.Positions.BT and a.Positions.BT.Quantity==5 and a.Positions.BT.Entry==20480 and not e.Orders[r.Id],"Low balance blocked a waiting entry")
  assert(F.Perform(e,a.Id,{Action="Close",Contract="BT"}))
  local second=submit(e,a.Id,request(1,4,20470));a.Limit=3 -- the limit tightens while it waits
  trade(e,20470);assert(not a.Positions.BT and not e.Orders[second.Id],"Waiting entry filled past the contract limit")
  a.Limit=5;a.Balance=a.Base;a.Realized=0;e:Audit()
 end)
 test("A marketable limit fills in full at the touch; nothing is taken from the book or printed",function()
  local e,a=fresh(Ladder.Tiers[1]);quote(e,-1,2,20485.5)
  local r=submit(e,a.Id,request(1,5,20486));assert(r.Filled==5 and r.Remaining==0 and r.Average==20485.5,"Marketable limit fill")
  assert(e.Books.BT.Asks[1].Quantity==2 and #e.Trades==0 and e.Books.BT.Last==nil,"Player fill consumed liquidity or printed a trade")
  rejected(e,a,request(1,1),0);e:Audit()
 end)
 test("Invalid, fractional, infinite and oversized remote quantities are rejected",function()
  local e,a=fresh(Ladder.Tiers[1])
  for _,n in ipairs({0,-1,1.5,math.huge,0/0})do assert(not e:Submit(a.Id,request(1,n)))end
  rejected(e,a,request(1,101),5);rejected(e,a,request(-1,1000),5)
 end)
 test("Saved old margins/caps adopt current policy without changing player progress or exposure",function()
  local old=clone(Config);old.Contracts.BT.Margin=2000;old.MaxPlayerInventory=40;old.MaxPlayerQuantity=20
  local e=E.new(old,592);local population=P.new(e);local f=F.new(e,Ladder,old);f:Start("migration")
  local profile=e.Profiles.migration
  local id=f:Owner("migration")
  local a=e.Accounts[id];a.Limit=40
  e:AddAccount("maker",1e9,10000,.99,false);quote(e,-1,1);submit(e,id,request(1,1))
  submit(e,id,request(1,1,20480))
  local snapshot=Checkpoint.Capture(e,population)
  local restored=Checkpoint.Restore(snapshot,Config);F.new(restored,Ladder,Config)
  local after=restored.Accounts[id]
  assert(after.Balance==a.Balance and after.Realized==a.Realized and #after.History==#a.History)
  assert(after.Positions.BT.Entry==a.Positions.BT.Entry and after.Positions.BT.Quantity==1)
  assert(after.Positions.BT.Stop==a.Positions.BT.Stop and next(after.OpenOrders))
  assert(after.Limit==5 and restored.Config.MaxPlayerQuantity==100 and restored.Books.BT.Spec.Margin==750)
  assert(restored.Profiles.migration.ProgressCredit==profile.ProgressCredit)
  assert(snapshot.Config.Contracts.BT.Margin==2000 and a.Limit==40,"Restore mutated source checkpoint")
 end)
 return results
end
return T
