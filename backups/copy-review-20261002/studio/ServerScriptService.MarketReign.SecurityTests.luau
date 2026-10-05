-- Reply queue and empty-book pricing regressions. Disposable engines only.
local Tests={}
local C=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local L=require(game.ReplicatedStorage.MarketReign.ProgressionConfig)
local E=require(script.Parent.MarketEngine)
local F=require(script.Parent.FundedAccounts)
local Settings=require(script.Parent.WorldConfig)
local ReplyBuffer=require(script.Parent.ReplyBuffer)
local function clone(v) if type(v)~="table" then return v end local r={} for k,x in pairs(v) do r[k]=clone(x) end return r end
local function equal(a,b,label) assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b)) end
local function exchange(l,uid,options)
 local c=clone(C);c.WarmupSeconds=0
 local e=E.new(c,4821);local f=F.new(e,l or L,c,options)
 if uid then assert(f:Start(uid)) end
 return e,f
end

function Tests.Run()
 local report={}
 local function test(name,fn)local ok,value=pcall(fn);table.insert(report,{Name=name,Passed=ok,Detail=ok and (value or "Passed") or tostring(value)})end
 ------------------------------------------------------------------------------------------ F3 replies
 test("F3: reply queues stay bounded by count and age for clients that never subscribe",function()
  local buffer=ReplyBuffer.new(Settings.MaxQueuedReplies,Settings.ReplyMaxAgeSeconds)
  local state={Replies={},ReplyTimes={}};local now=0
  for i=1,10000 do
   now+=1/6 -- the remote limiter's sustained rate
   local kind=i%3==0 and {RequestId=i,Ok=false,Message="Exchange busy. Please retry."} or i%3==1 and {RequestId=i,Ok=true,Message="Saved.",Kind="Start"} or {RequestId=i,Ok=false,Message="Rejected"}
   buffer:Push(state,kind,now)
   assert(#state.Replies<=Settings.MaxQueuedReplies and #state.ReplyTimes==#state.Replies,"reply queue exceeded its bound")
  end
  equal(#state.Replies,Settings.MaxQueuedReplies);assert(state.Full and state.DroppedReplies==10000-Settings.MaxQueuedReplies)
  equal(state.Replies[#state.Replies].RequestId,10000,"newest reply kept");equal(state.Replies[1].RequestId,10000-Settings.MaxQueuedReplies+1)
  local queued,dropped=buffer:Take(state);equal(#queued,Settings.MaxQueuedReplies);equal(dropped,10000-Settings.MaxQueuedReplies)
  equal(#state.Replies,0);equal(state.DroppedReplies,nil)
  -- Age bound: idle connections release everything after ReplyMaxAgeSeconds.
  state.Full=false
  for i=1,5 do buffer:Push(state,{RequestId=i,Ok=true},now) end
  buffer:Prune(state,now+Settings.ReplyMaxAgeSeconds);equal(#state.Replies,5,"not yet expired")
  buffer:Prune(state,now+Settings.ReplyMaxAgeSeconds+0.01);equal(#state.Replies,0);assert(state.Full,"expiry forces a full resync")
  local _,expired=buffer:Take(state);equal(expired,5)
  -- A normally subscribed client (flushed every broadcast) never loses a reply.
  local live={Replies={},ReplyTimes={}}
  for i=1,200 do buffer:Push(live,{RequestId=i},i*0.1);if i%1==0 then local got,lost=buffer:Take(live);equal(#got,1);equal(lost,nil) end end
 end)

 ------------------------------------------------------------------------------------------ S1 pricing
 test("S1: empty-side fallback quotes never cross; long and short round trips cannot profit",function()
  local function book() local e,f=exchange(nil,"q1");e:AddAccount("maker",1000000,500,.8,false);return e,f,e.Books.BX end
  -- Long: asks empty, a participant bid one tick above the last trade.
  local e,f,b=book();local id=f:Owner("q1");local tick=b.Spec.Tick
  local last=(b.Last or b.Reference)
  assert(e:Submit("maker",{Contract="BX",Direction=1,Quantity=10,Type="Limit",Price=(last+1)*tick}))
  assert(#b.Asks==0 and b.Bids[1].Price>last)
  local start=e.Accounts[id].Balance
  for _=1,10 do
   local ok,fill=F.Perform(e,id,{Action="Place",Contract="BX",Direction=1,Quantity=5,Type="Market"});assert(ok and fill.Filled==5)
   assert(fill.Average>=b.Bids[1].Price*tick,"buy filled below the best bid")
   assert(F.Perform(e,id,{Action="Close",Contract="BX"}))
  end
  assert(e.Accounts[id].Balance<=start+1e-9,"long round trips profited: "..(e.Accounts[id].Balance-start))
  assert(f:Profile("q1").WalletCents==nil,"Wallet returned")
  -- A marketable buy limit below the clamped fallback no longer fills at the lower last trade.
  local ok,rest=F.Perform(e,id,{Action="Place",Contract="BX",Direction=1,Quantity=1,Type="Limit",Price=last*tick})
  assert(ok and rest.Filled==0 and rest.Remaining==1,"limit filled through the bid");e:Cancel(id,rest.Id)
  e:Audit()
  -- Short: bids empty, a participant ask one tick below the last trade.
  local e2,f2,b2=book();local id2=f2:Owner("q1");local last2=(b2.Last or b2.Reference)
  assert(e2:Submit("maker",{Contract="BX",Direction=-1,Quantity=10,Type="Limit",Price=(last2-1)*tick}))
  assert(#b2.Bids==0 and b2.Asks[1].Price<last2)
  local start2=e2.Accounts[id2].Balance
  for _=1,10 do
   local okShort,fill=F.Perform(e2,id2,{Action="Place",Contract="BX",Direction=-1,Quantity=5,Type="Market"});assert(okShort and fill.Filled==5)
   assert(fill.Average<=b2.Asks[1].Price*tick,"sell filled above the best ask")
   assert(F.Perform(e2,id2,{Action="Close",Contract="BX"}))
  end
  assert(e2.Accounts[id2].Balance<=start2+1e-9,"short round trips profited: "..(e2.Accounts[id2].Balance-start2))
  e2:Audit()
  -- No liquidity at all: closes and depletion liquidation still fill at the last trade.
  local e3,f3=exchange(nil,"q3");local id3=f3:Owner("q3");local b3=e3.Books.BX;b3.Bids={};b3.Asks={};b3.Last=24000
  assert(F.Perform(e3,id3,{Action="Place",Contract="BX",Direction=1,Quantity=3,Type="Market"}))
  b3.Last=24000-5000/50/b3.Spec.Tick;e3:AdvanceClock(.25)
  assert(e3.Accounts[id3].Locked and not e3.Accounts[id3].Positions.BX,"liquidation stuck without liquidity")
  e3:Audit()
  -- Two-sided book: normal fills are unchanged (buy at the ask, sell at the bid).
  local e4,f4,b4=book();local id4=f4:Owner("q1");local l4=b4.Last or b4.Reference
  assert(e4:Submit("maker",{Contract="BX",Direction=1,Quantity=5,Type="Limit",Price=(l4-2)*tick}))
  e4:AddAccount("maker2",1000000,500,.8,false)
  assert(e4:Submit("maker2",{Contract="BX",Direction=-1,Quantity=5,Type="Limit",Price=(l4+2)*tick}))
  local _,buy=F.Perform(e4,id4,{Action="Place",Contract="BX",Direction=1,Quantity=1,Type="Market"});equal(buy.Average,(l4+2)*tick,"buy at ask")
  local _,sell=F.Perform(e4,id4,{Action="Close",Contract="BX"});equal(sell.Average,(l4-2)*tick,"sell at bid")
  e4:Audit()
 end)
 return report
end
return Tests
