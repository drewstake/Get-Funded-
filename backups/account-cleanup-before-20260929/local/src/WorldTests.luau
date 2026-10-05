local Default=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local Engine=require(script.Parent.MarketEngine)
local Participants=require(script.Parent.Participants)
local Checkpoint=require(script.Parent.WorldCheckpoint)
local Lease=require(script.Parent.WorldLease)
local World=require(script.Parent.WorldService)
local Settings=require(script.Parent.WorldConfig)
local Tests={}
local function clone(v)
 if type(v)~="table"then return v end
 local r={}for k,x in pairs(v)do r[k]=clone(x)end return r
end
local function equal(a,b,path)
 path=path or "state"
 assert(type(a)==type(b),path.." type differs")
 if type(a)~="table"then assert(a==b,path.." differs: "..tostring(a).." / "..tostring(b))return end
 for k,v in pairs(a)do equal(v,b[k],path.."."..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path.." added key "..tostring(k))end
end
local function store()
 local s={}
 function s:UpdateAsync(_,callback)
  if self.Fail then error("Injected storage outage")end
  local value=callback(clone(self.Value))
  if value==nil then return nil end
  self.Value=clone(value)return clone(value)
 end
 function s:GetAsync()if self.Fail then error("Injected storage outage")end return clone(self.Value)end
 return s
end
function Tests.Run()
 local report={} local function test(name,fn)
  local ok,result=pcall(fn)table.insert(report,{Name=name,Passed=ok,Detail=ok and result or tostring(result)})
 end
 test("Compressed checkpoint resumes the identical future with identical actions",function()
  local e=Engine.new(Default,92041)local p=Participants.new(e)
  e:AddAccount("player:test:50000",50000,40,0.8,true)
  for _=1,500 do p:Step()end
  assert(e:Submit("player:test:50000",{Contract="ES",Direction=1,Quantity=2,Type="Market",StopTicks=80,TargetTicks=100}))
  local before=Checkpoint.Capture(e,p)local encoded=Checkpoint.Encode(before)
  local http=game:GetService("HttpService")encoded=http:JSONDecode(http:JSONEncode(encoded))
  local restored,agents=Checkpoint.Restore(Checkpoint.Decode(encoded),Default)
  equal(before,Checkpoint.Capture(restored,agents))
  for i=1,700 do
   if i==200 or i==480 then
    local request={Contract="NQ",Direction=i==200 and -1 or 1,Quantity=1,Type="Market"}
    local ok1,r1=e:Submit("player:test:50000",request)local ok2,r2=restored:Submit("player:test:50000",request)
    equal({ok1,r1},{ok2,r2})
   end
   p:Step()agents:Step()
  end
  equal(Checkpoint.Capture(e,p),Checkpoint.Capture(restored,agents)) e:Audit()restored:Audit()
  return {Step=e.Step,Trades=e.NextTrade,Hash=e.TradeHash,CompressedBytes=#encoded.Payload,RawBytes=encoded.RawBytes}
 end)
 test("Restored book retains FIFO, partial fills, cancellations, account funds and protection",function()
  local e=Engine.new(Default,19)
  -- Book FIFO belongs to participants; player orders never rest in the book (checked below).
  for _,id in ipairs({"a","b","c"})do e:AddAccount(id,1000000,500,0.8,false)end
  local player=e:AddAccount("player:w:5000",5000,5,0.8,true)
  local function order(who,side,qty,price)
   local ok,r=e:Submit(who,{Contract="ES",Direction=side,Quantity=qty,Type=price and "Limit"or"Market",Price=price,StopTicks=8,TargetTicks=12})
   assert(ok,tostring(r))return r
  end
  local first=order("a",-1,4,5825)local second=order("b",-1,3,5825)
  order("c",1,2)
  local waiting=e:Submit(player.Id,{Contract="ES",Direction=1,Quantity=2,Type="Limit",Price=5800}) assert(waiting)
  local p=setmetatable({Engine=e,Config=Default,Random=Participants.RNG.new(19),Agents={}},Participants)
  local r=Checkpoint.Restore(Checkpoint.Decode(Checkpoint.Encode(Checkpoint.Capture(e,p))),Default)
  assert(r.Orders[first.Id].Remaining==2 and r.Orders[second.Id].Remaining==3)
  assert(r.Books.ES.Asks[1].Orders[1]==r.Orders[first.Id],"Restored order references are detached")
  local account=r.Accounts.c local originalBase=account.Balance
  assert(r:AddAccount("c",50000,40,0.8,true)==account and account.Balance==originalBase,"Rejoin reset funds")
  assert(account.Positions.ES.Stop and account.Positions.ES.Target)
  local ok,fill=r:Submit("c",{Contract="ES",Direction=1,Quantity=3,Type="Market"})
  assert(ok and fill.Filled==3 and r.Trades[1].Seller=="a"and r.Trades[2].Seller=="b")
  assert(not r.Orders[first.Id]and r.Orders[second.Id].Remaining==2)
  assert(r:Cancel("b",second.Id))assert(#r.Books.ES.Asks==0)
  local saved for id,o in pairs(r.Orders)do if o.Owner==player.Id then saved=o end end
  assert(saved and saved.Remaining==2 and #r.Books.ES.Bids==0 and r:_restingIndex().ES[saved.Id],"Player limit restored into the book")
  r:Audit()return "FIFO object identity, partial residual, cancellation, persistent account and SL/TP passed"
 end)
 test("Ownership is exclusive; takeover fences stale writes and preserves the checkpoint",function()
  local s=store()local now=100 local function clock()return now end
  local function owner(id)return Lease.new(s,Settings,{Token=id,WorldId=id,JobId=id,PlaceId=1},clock)end
  local a,b=owner("a"),owner("b")assert(a:Claim())assert(not b:Claim())
  a:Commit({Marker="saved"},18,false)now=191
  assert(not a:Valid())assert(b:Claim())assert(b.Record.Checkpoint.Marker=="saved")
  assert(not pcall(function()a:Commit({Marker="stale"},999,false)end))
  assert(s.Value.Owner=="b"and s.Value.SavedStep==18 and s.Value.Checkpoint.Marker=="saved")
  b:Commit({Marker="new"},22,true)local c=owner("c")assert(c:Claim())
  assert(c.Record.SavedStep==22 and c.Record.Checkpoint.Marker=="new")
  assert(not pcall(function()c:Commit({Marker="backwards"},21,false)end))
  return "Single writer, expired lease, stale generation, release and monotonic checkpoint verified"
 end)
 test("World service restart restores live accounts, candles and next random draw without a new auction",function()
  local c=table.clone(Default)c.WarmupSeconds=12
  local s=store()local now=1000
  local function make(job)return World.new(c,{Studio=false,PlaceId=123,JobId=job,Store=s,Now=function()return now end,CanOwn=true})end
  local a=make("first")a:Open()assert(a:CanRun(),a.LastError)
  a.Engine:AddAccount("player:7:50000",50000,40,0.8,true)
  a.Engine:Submit("player:7:50000",{Contract="ES",Direction=1,Quantity=1,Type="Market",StopTicks=50,TargetTicks=100})
  for _=1,40 do a.Population:Step()end
  local expected=Checkpoint.Capture(a.Engine,a.Population)
  assert(a:Close())local b=make("second")b:Open()assert(b:CanRun(),b.LastError)
  equal(expected,Checkpoint.Capture(b.Engine,b.Population))
  local follower=make("third")follower:Open()
  assert(follower.Mode=="Following"and not follower.Engine and not follower:CanRun())
  assert(follower.Owner.JobId=="second")
  return {RestoredStep=b.Engine.Step,RestoredTrades=b.Engine.NextTrade,Mode=b.Mode,Follower=follower.Mode}
 end)
 test("Storage outage pauses orders and never creates a replacement market",function()
  local c=table.clone(Default)c.WarmupSeconds=1
  local s=store()local now=2000 local opts={Studio=false,PlaceId=123,JobId="outage",Store=s,Now=function()return now end,CanOwn=true}
  s.Fail=true local unavailable=World.new(c,opts)unavailable:Open()
  assert(unavailable.Mode=="Unavailable"and not unavailable.Engine and not unavailable:CanRun())
  s.Fail=false local w=World.new(c,opts)w:Open()assert(w:CanRun())
  local step=w.Engine.Step s.Fail=true assert(not w:Save(false))assert(not w:CanRun())
  assert(w.Engine.Step==step and s.Value.SavedStep==step)
  s.Fail=false now+=Settings.RetrySeconds w:Maintain()assert(w:CanRun())
  now=w.Lease.Record.LeaseUntil+1 assert(not w:CanRun())
  return "Initial failure fails closed; save failure pauses; retry recovers; expired owner cannot trade"
 end)
 test("Corrupt or incompatible checkpoints are rejected instead of reseeded",function()
  local e=Engine.new(Default,202)local p=Participants.new(e)
  local snapshot=Checkpoint.Capture(e,p)local encoded=Checkpoint.Encode(snapshot)
  encoded.Digest="bad"assert(not pcall(Checkpoint.Decode,encoded))
  snapshot.Config.Contracts.ES.Tick=1
  assert(not pcall(Checkpoint.Restore,snapshot,Default))
  return "Checksum and instrument-schema validation passed"
 end)
 return report
end
return Tests
