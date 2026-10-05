-- A single shared exchange. Follower servers route players to its owner instead of creating another tape.
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Checkpoint=require(script.Parent.WorldCheckpoint)
local Lease=require(script.Parent.WorldLease)
local Engine=require(script.Parent.MarketEngine)
local Participants=require(script.Parent.Participants)
local Settings=require(script.Parent.WorldConfig)
local World={} World.__index=World
function World.new(config,options)
 options=options or {}
 local studio=options.Studio if studio==nil then studio=RunService:IsStudio()end
 local self=setmetatable({Config=config,Settings=options.Settings or Settings,Studio=studio,
  PlaceId=options.PlaceId or game.PlaceId,JobId=options.JobId or game.JobId,Now=options.Now or os.time,
  Mode="Connecting",Status="Connecting to the shared exchange",Busy=false,Closing=false,
  Healthy=false,NextSave=0,NextAttempt=0,Epoch=0,Store=options.Store},World)
 self.Identity={Token=Http:GenerateGUID(false),WorldId=Http:GenerateGUID(false),JobId=self.JobId,PlaceId=self.PlaceId}
 -- Private servers cannot be public teleport destinations. They only act as entry lobbies.
 self.CanOwn=options.CanOwn if self.CanOwn==nil then self.CanOwn=studio or game.PrivateServerId==""end
 return self
end
function World:_fresh()
 local seed=self.Studio and self.Settings.StudioReplaySeed or 0
 seed=seed or 0
 if seed==0 then seed=tonumber(Http:GenerateGUID(false):sub(1,8),16)%2147483646+1 end
 local engine=Engine.new(self.Config,seed) local population=Participants.new(engine)
 for i=1,math.floor(self.Config.WarmupSeconds/self.Config.StepSeconds)do
  population:Step() if i%200==0 then task.wait()end
 end
 return engine,population
end
function World:_encode()
 local projection
 if self.CaptureProjection then
  -- Optional read model failures must never prevent an exchange save or trading.
  local ok,result=pcall(self.CaptureProjection,self.Engine)
  if ok then projection=result else warn("[Get Funded!] Leaderboard projection unavailable: "..tostring(result)) end
 end
 local record=Checkpoint.Encode(Checkpoint.Capture(self.Engine,self.Population))
 assert(#Http:JSONEncode(record)<self.Settings.MaxEncodedBytes,"Exchange checkpoint is too large; trading paused to protect saved state")
 return record,self.Engine.Step,projection
end
function World:_committed(rows)
 if not rows then return end
 local r=self.Lease.Record
 self.DurableProjection={Rows=rows,WorldId=r.WorldId,Sequence=r.SaveSequence,SavedAt=r.SavedAt}
end
function World:_sandbox(reason)
 self.Engine,self.Population=self:_fresh()
 self.Mode="Local" self.Status="LOCAL · NOT SAVED" self.Healthy=true self.Epoch+=1
 warn("[Get Funded!] Unsaved Studio sandbox: "..reason.." Publish a test experience and enable Studio API access for restart continuity.")
end
function World:Open()
 if self.Closing or self.Busy then return end
 self.Busy=true
 local ok,err=pcall(function()
  if not self.Settings.Enabled or self.PlaceId==0 then
   assert(self.Studio and self.Settings.AllowUnsavedStudio,"Persistent storage is required for the live exchange")
   self:_sandbox(self.PlaceId==0 and "This place is unpublished." or "Persistence is disabled.") return
  end
  if not self.Store then
   self.Store=game:GetService("DataStoreService"):GetDataStore(self.Settings.StoreName,self.Studio and "Studio" or "Live")
  end
  self.Lease=self.Lease or Lease.new(self.Store,self.Settings,self.Identity,self.Now)
  local owned,record
  if self.CanOwn then owned,record=self.Lease:Claim()
  else owned=false record=self.Store:GetAsync(self.Settings.WorldKey)end
  if not owned then
   self.Owner=record self.Mode="Following" self.Healthy=false
   self.Status=self.Studio and "Shared Studio exchange is active in another test; stop it before restarting here" or "Joining the shared exchange"
   return
  end
  self.Mode="Loading" self.Status="Restoring the saved exchange"
  if record.Checkpoint then
   self.Engine,self.Population=Checkpoint.Restore(Checkpoint.Decode(record.Checkpoint),self.Config)
   assert(self.Engine.Step==record.SavedStep,"Checkpoint step does not match ownership record")
  else
   assert(record.SavedStep==0,"Saved exchange checkpoint is missing")
   self.Engine,self.Population=self:_fresh()
  end
  -- No client trades until the initial/loaded state has a confirmed durable checkpoint.
  local encoded,step,projection=self:_encode()
  self.Lease:Commit(encoded,step,false)
  self:_committed(projection)
  self.Mode="Shared" self.Status="SHARED · SAVED" self.Healthy=true self.Epoch+=1
  self.NextSave=self.Now()+self.Settings.SaveSeconds
 end)
 self.Busy=false self.NextAttempt=self.Now()+self.Settings.RetrySeconds
 if not ok then
  -- Transient storage failures or corrupt checkpoints must never silently reset an existing market.
  self.Healthy=false self.Mode="Unavailable" self.Status="Saved exchange unavailable · retrying safely"
  self.LastError=tostring(err) warn("[Get Funded!] "..self.LastError)
 end
end
function World:CanRun()
 if self.Closing or self.TransactionBusy or not self.Healthy or not self.Engine then return false end
 return self.Mode=="Local" or (self.Mode=="Shared" and self.Lease:Valid())
end
function World:Label()
 if self.TransactionBusy then return "Saving account purchase…" end
 if self.Mode=="Shared" and not self:CanRun()then return "PAUSED · WAITING FOR SAVED EXCHANGE"end
 return self.Status
end
function World:Save(release)
 if self.Busy or not self.Engine or self.Mode~="Shared" then return false end
 self.Busy=true
 local ok,err=pcall(function()
  local encoded,step,projection=self:_encode()
  self.Lease:Commit(encoded,step,release)
  self:_committed(projection)
 end)
 self.Busy=false self.NextSave=self.Now()+(ok and self.Settings.SaveSeconds or self.Settings.RetrySeconds)
 self.Healthy=ok and not release
 if ok and self.PendingPurchase then
  local pending=self.PendingPurchase;self.PendingPurchase=nil;self.TransactionBusy=false
  pending.Complete(true,pending.Message,pending.Receipt)
 end
 if not ok then self.LastError=tostring(err) warn("[Get Funded!] Save failed; exchange paused: "..self.LastError)end
 return ok
end
-- Freeze the exchange around a purchase and acknowledge only after its account, debit and receipt
-- have committed in the same fenced UpdateAsync. On ambiguous storage failure keep the transaction
-- frozen for retry; never refund a possibly committed purchase or generate a different receipt.
function World:Purchase(funded,uid,tier,sequence,complete)
 if self.Busy or not self:CanRun() then return false,"The exchange is saving. Please try again shortly." end
 if self.Mode~="Shared" then return false,"The Shop is waiting for saved exchange storage." end
 self.TransactionBusy=true
 local ok,message,receipt=funded:Purchase(uid,tier,sequence)
 if not ok then self.TransactionBusy=false;return false,message end
 self.PendingPurchase={Message=message,Receipt=receipt,Complete=complete}
 task.defer(function() if self.PendingPurchase and not self.Busy then self:Save(false) end end)
 return true
end
function World:Maintain()
 if self.Closing or self.Busy or self.Mode=="Local"then return end
 local now=self.Now()
 if self.Mode=="Shared"then
  if not self.Lease.Owned or now>=self.Lease.Record.LeaseUntil then
   -- Discard unsaved state after loss of authority. Reacquire and restore the durable record.
   self.Healthy=false self.Mode="Unavailable" self.Status="Reconnecting to the saved exchange"
   if self.PendingPurchase then
    local pending=self.PendingPurchase;self.PendingPurchase=nil;self.TransactionBusy=false
    pending.Complete(false,"Exchange reconnecting. Check your accounts before confirming another purchase.",nil)
   end
   self.Engine=nil self.Population=nil self.Epoch+=1 self.NextAttempt=now
  elseif now>=self.NextSave then self:Save(false) return end
 end
 if self.Mode~="Shared" and now>=self.NextAttempt then self:Open()end
end
function World:Close()
 self.Closing=true
 -- A save already in flight finishes before the final frozen checkpoint and lease release.
 local deadline=os.clock()+24
 while self.Busy and os.clock()<deadline do task.wait(0.05)end
 if not self.Busy and self.Mode=="Shared" and self.Lease.Owned then
  repeat
   if self:Save(true)then return true end
   if not self.Lease.Owned or self.Now()>=self.Lease.Record.LeaseUntil then break end
   task.wait(1)
  until os.clock()>=deadline
 end
 return self.Mode=="Local"
end
return World
