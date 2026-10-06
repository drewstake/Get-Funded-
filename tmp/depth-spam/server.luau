assert(not game.ReplicatedStorage:FindFirstChild("DepthSpamShared"),"Depth test already staged")
assert(not game.ServerScriptService:FindFirstChild("DepthSpamServer"),"Depth test already staged")
local shared=game.ReplicatedStorage.MarketReign:Clone();shared.Name="DepthSpamShared";shared.Parent=game.ReplicatedStorage
local server=game.ServerScriptService.MarketReign:Clone();server.Name="DepthSpamServer"
for _,m in ipairs(server:GetDescendants())do if m:IsA("BaseScript")then m.Enabled=false end end
server.Parent=game.ServerScriptService
for _,f in ipairs({shared,server})do for _,m in ipairs(f:GetDescendants())do if m:IsA("LuaSourceContainer")then
 m.Source=m.Source:gsub("game%.ReplicatedStorage%.MarketReign","game.ReplicatedStorage.DepthSpamShared")
  :gsub("game%.ServerScriptService%.MarketReign","game.ServerScriptService.DepthSpamServer")
end end end
local ok,result=pcall(function()
-- Template: insert the current MarketServer source at the marker before running in Studio Edit.
-- All accounts, remotes, clocks, entitlement responses and persistence are isolated fixtures.
local RealGame=game
local Shared=RealGame.ReplicatedStorage.DepthSpamShared
local Server=RealGame.ServerScriptService.DepthSpamServer
local function clone(x)if type(x)~="table"then return x end local r={}for k,v in pairs(x)do r[k]=clone(v)end return r end
local AuditConfig=clone(require(Shared.MarketConfig))
AuditConfig.ParticipantsPerInstrument=0;AuditConfig.MakersPerInstrument=0;AuditConfig.ScalpersPerInstrument=0
AuditConfig.WhaleFrequency=0;AuditConfig.NewsFrequency=0
AuditConfig.Regimes={{Name="Fixed",Weight=1,Volatility=0,Liquidity=1,Activity=1,Trend=0}}
local AuditLadder=clone(require(Shared.ProgressionConfig));AuditLadder.StartingBalance=1000000000
local AuditEngine=require(Server.MarketEngine).new(AuditConfig,1729)
local AuditPopulation=require(Server.Participants).new(AuditEngine)
local now=100
local function signal()local s={}function s:Connect(fn)self.Callback=fn;return {Disconnect=function()end}end return s end
local auditPlayer={UserId=901,Name="AuditOne",DisplayName="Audit One"}
local otherPlayer={UserId=902,Name="AuditTwo",DisplayName="Audit Two"}
local fakePlayers={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function()return {auditPlayer,otherPlayer}end}
local fakeRun={Heartbeat=signal(),IsStudio=function()return false end}
local fakeTeleport={TeleportInitFailed=signal()}
local remoteMap,packets,counts={},{},{}
local fakeRoot={SetAttribute=function()end,FindFirstChild=function(_,n)return remoteMap[n]end,MarketConfig="config",ProgressionConfig="ladder"}
local fakeInstance={}
function fakeInstance.new(class)
 local o={ClassName=class,OnServerEvent=signal(),Triggered=signal(),Destroy=function()end}
 function o:FireClient(player,packet)
  counts[player]=(counts[player]or 0)+1;packets[player]=packet
 end
 return setmetatable(o,{__newindex=function(t,k,v)rawset(t,k,v);if k=="Name"then remoteMap[v]=t end end})
end
local auditWorld={Studio=true,Engine=AuditEngine,Population=AuditPopulation,Epoch=1,Mode="Local",
 CanRun=function()return true end,Label=function()return "AUDIT"end,Maintain=function()end,HasCapacity=function()return true end}
local modules={config=AuditConfig,ladder=AuditLadder,WorldService={new=function()return auditWorld end},
 FundedAccounts=require(Server.FundedAccounts),LeaderboardRanking=require(Server.LeaderboardRanking),
 ReplyBuffer=require(Server.ReplyBuffer),WorldConfig=require(Server.WorldConfig),OwnerResetCommand=require(Server.OwnerResetCommand),
 LeaderboardService={new=function()return {}end},MarketDepthAccess={new=function()return {
  Refresh=function()end,Forget=function()end,Apply=function(_,packet)packet.DepthAccess={Allowed=true,State="Owned"}end}end}}
local game={GetService=function(_,n)
 if n=="ReplicatedStorage"then return {WaitForChild=function()return fakeRoot end}
 elseif n=="Players"then return fakePlayers elseif n=="RunService"then return fakeRun elseif n=="TeleportService"then return fakeTeleport
 elseif n=="MarketplaceService"then return {PromptGamePassPurchaseFinished=signal()}
 elseif n=="TextChatService"then return {FindFirstChild=function()end}end
 error("Unexpected service: "..n)
end,BindToClose=function()end,CreatorType=Enum.CreatorType.User,CreatorId=0}
local script={Parent={}};for name in pairs(modules)do script.Parent[name]=name end
local require=function(k)assert(modules[k],"Unexpected module: "..tostring(k));return modules[k]end
local Instance=fakeInstance
local task={spawn=function()end}
local os={clock=function()return now end,time=function()return 1000 end}
local debug={profilebegin=function()end,profileend=function()end}
local warnings={};local warn=function(message)table.insert(warnings,message)end
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TeleportService=game:GetService("TeleportService")
local root=ReplicatedStorage:WaitForChild("MarketReign")
local Config=require(root.MarketConfig)
local Progression=require(root.ProgressionConfig)
local World=require(script.Parent.WorldService)
local Funded=require(script.Parent.FundedAccounts)
local Leaderboards=require(script.Parent.LeaderboardService)
local Ranking=require(script.Parent.LeaderboardRanking)
local ReplyBuffer=require(script.Parent.ReplyBuffer)
local WorldSettings=require(script.Parent.WorldConfig)
local OwnerResetCommand=require(script.Parent.OwnerResetCommand)
local DepthAccess=require(script.Parent.MarketDepthAccess)
local depthAccess=DepthAccess.new()
Funded.Validate(Progression) -- Fail closed on invalid progression configuration.
local function remote(name)
 local old=root:FindFirstChild(name) if old then old:Destroy() end
 local r=Instance.new("RemoteEvent") r.Name=name r.Parent=root return r
end
local requestRemote=remote("OrderRequest") local updateRemote=remote("MarketUpdate")
local ownerNotice=remote("OwnerNotice")
local world=World.new(Config)
local leaderboard=Leaderboards.new({Studio=world.Studio})
world.CaptureProjection=function(engine)return Ranking.Capture(Funded.new(engine,Progression,Config))end
local oldLeaderboard=root:FindFirstChild("LeaderboardRequest") if oldLeaderboard then oldLeaderboard:Destroy() end
local leaderboardRemote=Instance.new("RemoteFunction") leaderboardRemote.Name="LeaderboardRequest" leaderboardRemote.Parent=root
local market,population,funded local epoch=-1
root:SetAttribute("SessionSeed",nil) root:SetAttribute("Ready",false)
local clients={} local queue={} local sequence=0 local actionLog={}
local resettingUid
-- Acknowledgements are bounded per connection by count and age (see ReplyBuffer).
local replies=ReplyBuffer.new(WorldSettings.MaxQueuedReplies,WorldSettings.ReplyMaxAgeSeconds)
-- Joining idempotently creates one $10,000 account for a new player.
local function resolve(player,state)
 if not funded or not world:CanRun() or state.ResetPending then return end
 funded:Join(state.Uid) funded:Return(state.Uid) funded:Evaluate(state.Uid)
 local p=funded:Profile(state.Uid)
 if p then
  p.PlayerName=player.Name;p.DisplayName=player.DisplayName
  -- A join restores history without replaying sounds for old/offline executions.
  local events={};for _,event in ipairs(p.Events or {})do if event.Kind~="TradeClosed"then table.insert(events,event)end end;p.Events=events
 end
 state.Owner=funded:Owner(state.Uid) state.Full=true state.PortfolioRevision=nil
 if state.Owner then market:SetConnected(state.Owner,true)end
end
local function add(player)
 if clients[player] then return end
 clients[player]={Uid=Funded.Key(player.UserId),Contract=Config.ContractOrder[1],Timeframe="1m",Full=true,Tokens=20,TokenTime=os.clock(),
  Seen={},SeenOrder={},Replies={},ReplyTimes={},Subscribed=false,PortfolioAt=0,ResetPending=tostring(player.UserId)==resettingUid}
 depthAccess:Refresh(player)
 resolve(player,clients[player])
end
Players.PlayerAdded:Connect(add) for _,p in ipairs(Players:GetPlayers()) do add(p) end
-- The purchase event only triggers a fresh ownership query. Its boolean never grants access.
game:GetService("MarketplaceService").PromptGamePassPurchaseFinished:Connect(function(player,passId)
 if clients[player]and passId==depthAccess.PassId then depthAccess:Refresh(player,true)end
end)
leaderboardRemote.OnServerInvoke=function(player,tab)
 local state=clients[player]
 if not state or (tab~="Global" and tab~="Server") then return nil end
 -- Read-only endpoint; rate limits are independent of order traffic. No scores/ids accepted.
 local now=os.clock()
 if now<(state.LeaderboardAt or 0) then return {Tab=tab,State="Throttled"} end
 state.LeaderboardAt=now+2
 if not funded or not world:CanRun() then return {Tab=tab,State="Loading",Rows={},Studio=world.Studio} end
 if tab=="Server" then return leaderboard:Server(funded,Players:GetPlayers(),player) end
 local own=Ranking.Row(funded,state.Uid,player)
 return leaderboard:Global(own)
end
-- Portfolio + projection accompany each price batch. Closed and open amounts are one snapshot.
local function attachPortfolio(state,packet)
 if not funded then return end
 packet.Events=funded:TakeEvents(state.Uid)
 local profile=funded:Profile(state.Uid)
 local revision=profile and profile.Revision or 0 local now=os.clock()
 packet.Portfolio=funded:View(state.Uid) state.PortfolioRevision=revision state.PortfolioAt=now
 -- Lifetime stats: sent on join/refresh and whenever a counted value changes (a close, a depletion,
 -- a restart). A failure here is isolated from trading and reported to the Stats page.
 local key=funded:StatsKey(state.Uid)
 if state.Full or key~=state.StatsKey then
  local ok,stats=pcall(funded.Stats,funded,state.Uid)
  if not ok then warn("[Get Funded!] Stats unavailable: "..tostring(stats)) end
  packet.Stats=ok and stats or {Error="Stats are temporarily unavailable. Your trades and saved results are not affected."}
  state.StatsKey=key
 end
end
local function emit(player,state)
 depthAccess:Refresh(player)
 if funded and world:CanRun() and not funded:Owner(state.Uid) and os.clock()>=(state.JoinRetryAt or 0) then
  state.JoinRetryAt=os.clock()+5;resolve(player,state)
 end
 if funded then
  local owner=funded:Owner(state.Uid)
  if state.Owner~=owner then state.Owner=owner;state.Full=true;if owner then market:SetConnected(owner,true)end end
 end
 local unavailable=not market or world.Transaction or state.ResetPending or world.Mode=="Unavailable" or world.Mode=="Following" or world.Mode=="Loading"
 if unavailable or not state.Owner or not market.Accounts[state.Owner] then
  -- No trading account yet (first join) or the exchange is not ready: send status and portfolio only.
  local queued,dropped=replies:Take(state)
  local packet={StatusOnly=true,CanTrade=not unavailable and world:CanRun(),ConnectionStatus=world:Label(),Replies=queued,RepliesDropped=dropped,NoAccount=not unavailable or nil}
  if not unavailable then attachPortfolio(state,packet) state.Full=false end
  depthAccess:Apply(packet,player,state.Contract)
  updateRemote:FireClient(player,packet)
  return
 end
 local packet=market:Snapshot(state.Owner,state.Contract,state.Timeframe,state.Full)
 packet.Seed=nil -- The server's future random stream is private.
 packet.CanTrade=world:CanRun() packet.ConnectionStatus=world:Label() packet.PersistenceMode=world.Mode
 -- Quotes/candles/P&L are frequent; unchanged order and trade histories are not resent.
 local orderParts={}
 for _,order in ipairs(packet.Orders)do
  table.insert(orderParts,table.concat({order.Id,order.Contract,order.Protection or "",order.Quantity,order.Price or "Market",order.Status},":"))
 end
 local orderSignature=table.concat(orderParts,"|")
 if not state.Full and state.SentRevision==packet.Revision and state.SentOwner==state.Owner then
  packet.History=nil packet.Fills=nil
 end
 -- OCO/trigger status can change before a closing execution changes the account revision.
 if not state.Full and state.SentOwner==state.Owner and state.SentOrders==orderSignature then
  packet.Orders=nil
 end
 depthAccess:Apply(packet,player,state.Contract)
 state.SentRevision=packet.Revision state.SentOwner=state.Owner state.SentOrders=orderSignature
 packet.Regime=population.Regime.Name packet.News=market.Time<population.NewsUntil and population.News or nil
 packet.Speed=Config.SimulationSpeed packet.Replies,packet.RepliesDropped=replies:Take(state)
 packet.AccountKey=(funded:Profile(state.Uid) or {}).Active
 packet.AccountToken=state.Owner -- identifies the exact attempt; checked, never used to choose an owner
 attachPortfolio(state,packet)
 updateRemote:FireClient(player,packet) state.Full=false
end
-- A packet failure for one connection must not stop every other player's feed.
local function safeEmit(player,state)
 local ok,err=pcall(emit,player,state)
 if not ok then
  state.Full=true
  local now=os.clock()
  if now>=(state.EmitWarningAt or 0)then
   state.EmitWarningAt=now+5;warn("[Get Funded!] Market update failed; retrying: "..tostring(err))
  end
 end
end
local function reply(state,id,ok,message,result,extra)
 local r={RequestId=id,Ok=ok,Message=message,Result=result}
 for k,v in pairs(extra or {})do r[k]=v end
 replies:Push(state,r,os.clock())
end
local allowed={Place=true,Cancel=true,Close=true,Subscribe=true,AmendProtection=true,AmendOrder=true,
 Start=true,Restart=true,ResetAccount=true,AcknowledgeAway=true,Flag=true,Stats=true,ProtectionPreferences=true}
local fields={"ExpectedAccount","Contract","Timeframe","Direction","Quantity","Type","Price","StopTicks","TargetTicks","StopDollars","TargetDollars","ExpectedQuantity","OrderId","Protection","ExpectedPrice",
 "Stage","StopOn","TargetOn","Create","SummaryId"}
requestRemote.OnServerEvent:Connect(function(player,request)
 local state=clients[player]
 if not state or state.ResetPending or type(request)~="table" then return end
 local now=os.clock()
 -- Subscription recovery has its own allowance, so order spam cannot starve the feed.
 if request.Action=="Subscribe"or request.Action=="Stats"then
  state.ReadTokens=math.min(4,(state.ReadTokens or 4)+(now-(state.ReadTokenTime or now))*2);state.ReadTokenTime=now
  if state.ReadTokens<1 then return end;state.ReadTokens-=1
 else
  state.Tokens=math.min(20,state.Tokens+(now-state.TokenTime)*6);state.TokenTime=now
  if state.Tokens<1 then return end;state.Tokens-=1
 end
 if type(request.Id)~="number" or request.Id%1~=0 or request.Id<1 or request.Id>1e9 or state.Seen[request.Id] then return end
 if not allowed[request.Action] then return end
 -- Whitelist scalar inputs. ExpectedAccount detects a stale view; it never selects an owner.
 -- Execution prices, timestamps and account ownership remain server-owned.
 local clean={Id=request.Id,Action=request.Action}
 for _,field in ipairs(fields) do
  local value=request[field]
  if value~=nil then
   if field=="StopOn"or field=="TargetOn"or field=="Create"then
    if type(value)~="boolean"then return end
   elseif type(value)~="number" and type(value)~="string" then return end
   if type(value)=="number" and (value~=value or math.abs(value)>1e9) then return end
   if type(value)=="string" and #value>(field=="Followers" and 512 or field=="ExpectedAccount" and 64 or 32) then return end
   clean[field]=value
  end
 end
 if #queue>=256 then reply(state,clean.Id,false,"Exchange busy. Please retry.") return end
 state.Seen[clean.Id]=true table.insert(state.SeenOrder,clean.Id)
 if #state.SeenOrder>256 then state.Seen[table.remove(state.SeenOrder,1)]=nil end
 -- Read-only: resend the authoritative Stats packet with the next update (Stats page Retry).
 if clean.Action=="Stats"then state.StatsKey=nil return end
 if clean.Action=="Subscribe"then
  local valid=false for _,tf in ipairs(Config.Timeframes)do if tf[1]==clean.Timeframe then valid=true break end end
  if Config.Contracts[clean.Contract]and valid then
   state.Contract=clean.Contract state.Timeframe=clean.Timeframe state.Full=true state.Subscribed=true
   -- Coalesce rapid subscription changes into the next scheduled market packet.
  end
  return
 end
 if not world:CanRun()then reply(state,clean.Id,false,world:Label())return end
 sequence+=1 table.insert(queue,{Player=player,Request=clean,Sequence=sequence,Epoch=epoch,Owner=state.Owner})
end)
local function process(item)
 local state=clients[item.Player] if not state or state.ResetPending then return end
 if not world:CanRun() then reply(state,item.Request.Id,false,world:Label(),nil,{Kind=item.Request.Action}) return end
 if item.Epoch~=epoch then reply(state,item.Request.Id,false,"Exchange reconnected. Please submit your order again.")return end
 local req=item.Request local uid=state.Uid
 funded:Evaluate(uid)
 local owner=funded:Owner(uid)
 if state.Owner~=owner then
  state.Owner=owner;state.Full=true
  if owner then market:SetConnected(owner,true)end
  if req.Action=="Place" or req.Action=="Close" or req.Action=="Cancel" or req.Action=="AmendOrder" or req.Action=="AmendProtection" then
   reply(state,req.Id,false,"Your account has restarted. Check the current account and try again.") return
  end
 end
 -- Account lifecycle. Each is idempotent and validated against the saved profile.
 if req.Action=="Start" then
  local ok,message,created=funded:Start(uid)
  local profile=funded:Profile(uid);if profile then profile.PlayerName=item.Player.Name;profile.DisplayName=item.Player.DisplayName end
  state.Owner=funded:Owner(uid) state.Full=true;if state.Owner then market:SetConnected(state.Owner,true)end
  reply(state,req.Id,ok,message,nil,{Kind="Start",Created=created}) return
 elseif req.Action=="Restart" then
  local ok,message=funded:Restart(uid,req.ExpectedAccount)
  if ok then state.Owner=funded:Owner(uid) state.Full=true;market:SetConnected(state.Owner,true)end
  reply(state,req.Id,ok,message,nil,{Kind="Restart",Tier=req.Tier}) return
 elseif req.Action=="ResetAccount"then
  local ok,message=funded:ResetAccount(uid,req.ExpectedAccount)
  if ok then state.Owner=funded:Owner(uid);state.Full=true;market:SetConnected(state.Owner,true)end
  reply(state,req.Id,ok,message,nil,{Kind="ResetAccount"});return
 elseif req.Action=="AcknowledgeAway"then
  local ok,message=funded:AcknowledgeAway(uid,req.SummaryId)
  reply(state,req.Id,ok,message,nil,{Kind="AcknowledgeAway"});return
 elseif req.Action=="Flag" then
  local ok,message=funded:Flag(uid,req.Stage)
  reply(state,req.Id,ok,message,nil,{Kind="Flag",Stage=req.Stage}) return
 elseif req.Action=="ProtectionPreferences"then
  local ok,message=funded:SetProtectionPreferences(uid,req)
  reply(state,req.Id,ok,message,nil,{Kind="ProtectionPreferences"}) return
 end
 -- Trading owner and current run token are resolved only on the server.
 local owner=state.Owner
 if item.Owner~=owner or req.ExpectedAccount~=owner then reply(state,req.Id,false,"Your account has changed. Check it and try again.") return end
 if not owner or not market.Accounts[owner] then reply(state,req.Id,false,"Your trading account is loading.") return end
 local ok,result=Funded.Perform(market,owner,req)
 market:ProcessStops()
 funded:Evaluate(uid)
 local message=type(result)=="table" and Funded.Describe(result) or result or "Request rejected."
 reply(state,req.Id,ok,message,type(result)=="table" and result or nil,{Kind=req.Action})
end
Players.PlayerRemoving:Connect(function(player)
 depthAccess:Forget(player)
 -- Leaving cancels working orders. Positions and their protective triggers remain on the exchange.
 local departing=clients[player]
 if market and departing and departing.Owner then funded:Depart(departing.Uid);market:SetConnected(departing.Owner,false)end
 -- Accept already-received preference edits even if the player leaves before the next market step.
 local remaining={}
 for _,item in ipairs(queue)do
  if item.Player==player and item.Request.Action=="ProtectionPreferences"then process(item)
  elseif item.Player~=player then table.insert(remaining,item)end
 end
 queue=remaining;clients[player]=nil
end)
local routing={}
TeleportService.TeleportInitFailed:Connect(function(player)
 routing[player]=nil
 local state=clients[player]if state then state.NextRoute=os.clock()+10 end
end)
local function route(player,state)
 local owner=world.Owner
 if world.Studio or routing[player]or os.clock()<(state.NextRoute or 0)or not owner or
  owner.LeaseUntil<=os.time()or owner.JobId==""or owner.JobId==game.JobId then return end
 routing[player]=true state.NextRoute=os.clock()+15
 task.spawn(function()
  local ok,err=pcall(function()
   local options=Instance.new("TeleportOptions")options.ServerInstanceId=owner.JobId
   TeleportService:TeleportAsync(owner.PlaceId,{player},options)
  end)
  if not ok then routing[player]=nil warn("[Get Funded!] Exchange transfer will retry: "..tostring(err))end
 end)
end
Players.PlayerRemoving:Connect(function(player)routing[player]=nil end)
-- TextChatCommand intercepts the command; authorization and username resolution stay on the server.
-- The owner wipe remains separate from the player reset, which preserves lifetime progress.
local ownerCommand=OwnerResetCommand.new({
 CreatorType=game.CreatorType,CreatorId=game.CreatorId,
 GroupLookup=function(id)return game:GetService("GroupService"):GetGroupInfoAsync(id)end,
 Ready=function()return world.Mode=="Shared" and not world.Busy and world:CanRun()end,
 Notify=function(player,message)if player.Parent==Players then ownerNotice:FireClient(player,message)end end,
 Resolve=function(name)
  for _,player in ipairs(Players:GetPlayers())do
   if player.Name:lower()==name:lower()then return player.UserId,player.Name end
  end
  local uid=Players:GetUserIdFromNameAsync(name)
  return uid,Players:GetNameFromUserIdAsync(uid)
 end,
 Reset=function(userId,name)
  local uid=Funded.Key(userId)
  if not world.Engine or not world.Engine.Profiles[uid]then return false,"@"..name.." has no saved data to reset."end
  resettingUid=uid
  for _,state in pairs(clients)do if state.Uid==uid then state.ResetPending=true end end
  local ok=world:TransformSaved(function(engine)
   return Funded.new(engine,Progression,Config):ResetPlayer(uid)
  end)
  if not ok then
   resettingUid=nil
   for player,state in pairs(clients)do if state.Uid==uid then
    if not world.Engine then
     player:Kick("The exchange is checking saved data after an owner reset. Please rejoin shortly.")
    else state.ResetPending=nil;state.Full=true end
   end end
   return false,"Reset was not confirmed. Wait for the saved exchange to recover, then check @"..name.." before retrying."
  end
  -- Clear delayed actions and diagnostic copies belonging to the wiped profile.
  for i=#queue,1,-1 do if queue[i].Player.UserId==userId then table.remove(queue,i)end end
  for i=#actionLog,1,-1 do if actionLog[i].Player==userId then table.remove(actionLog,i)end end
  leaderboard:UseDurableProjection(world.DurableProjection)
  root:SetAttribute("LeaderboardRevision",(root:GetAttribute("LeaderboardRevision")or 0)+1)
  task.spawn(function()leaderboard.NextWrite=0;leaderboard:Flush()end)
  return true,"Reset saved for @"..name..". All trading history, ranks, titles and settings cleared. New $10,000 account ready."
 end,
 AfterReset=function(userId)
  -- Rejoining discards local drafts, tutorial state, preference retries and old request tokens.
  for _,player in ipairs(Players:GetPlayers())do
   if player.UserId==userId then player:Kick("The owner reset your Get Funded! data, including ranks, titles and trading history. Rejoin to start with $10,000 in-game money.")end
  end
  resettingUid=nil
 end,
})
local chat=game:GetService("TextChatService")
local oldCommand=chat:FindFirstChild("OwnerResetCommand");if oldCommand then oldCommand:Destroy()end
local resetCommand=Instance.new("TextChatCommand")
resetCommand.Name="OwnerResetCommand";resetCommand.PrimaryAlias="/reset";resetCommand.AutocompleteVisible=false
resetCommand.Triggered:Connect(function(source,text)
 local player=source and Players:GetPlayerByUserId(source.UserId)
 if player then ownerCommand:Handle(player,text)end
end)
resetCommand.Parent=chat
task.spawn(function()world:Open()end)
game:BindToClose(function()
 if funded then for _,state in pairs(clients)do funded:Depart(state.Uid)end end
 world:Close()
 leaderboard:Queue(world.DurableProjection)
 -- Exchange durability comes first. A missed publish is rebuilt from its save on the next owner.
 leaderboard.NextWrite=0;leaderboard:Flush()
end)
task.spawn(function()
 while not world.Closing do
  task.wait(5)
  leaderboard:Queue(world.DurableProjection)
  leaderboard:Flush()
 end
end)
local elapsed,broadcast,maintenance=0,0,0
local performance={Frames=0,Steps=0,TotalMs=0,MaxMs=0,Backlog=0}
RunService.Heartbeat:Connect(function(dt)
 local started=os.clock()
 debug.profilebegin("FundedMarketHeartbeat")
 if epoch~=world.Epoch then
  epoch=world.Epoch market=world.Engine population=world.Population elapsed=0
  funded=market and Funded.new(market,Progression,Config,{Capacity=function(kind) return world:HasCapacity(kind) end}) or nil
  if market and funded then
   local connected={}
   for _,state in pairs(clients)do local owner=funded:Owner(state.Uid);if owner then connected[owner]=true end end
   market:SetConnectedOwners(connected)
  end
  for player,state in pairs(clients)do state.Owner=nil resolve(player,state) end
 end
 local active=world:CanRun()
 root:SetAttribute("Ready",active)root:SetAttribute("PersistenceStatus",world:Label())
 if active then elapsed+=dt*Config.SimulationSpeed else elapsed=0 end
 broadcast+=dt maintenance+=dt local steps=0
 while active and elapsed>=Config.StepSeconds and steps<Config.MaxCatchupSteps do
  elapsed-=Config.StepSeconds steps+=1
  local pending=queue queue={}
  for _,item in ipairs(pending) do
   table.insert(actionLog,{Step=market.Step,Sequence=item.Sequence,Player=item.Player.UserId,Request=item.Request})
   if #actionLog>5000 then table.remove(actionLog,1) end
   process(item)
  end
  if world:CanRun() then population:Step() else break end
 end
 if not active and #queue>0 then
  for _,item in ipairs(queue)do local state=clients[item.Player]if state then reply(state,item.Request.Id,false,world:Label())end end
  queue={}
 end
 if maintenance>=1 then
  maintenance=0 task.spawn(function()world:Maintain()end)
  -- SL/TP can execute while a player is away; unlocks are still earned once.
  if active and funded then
   -- Progress from offline protective fills is evaluated on the same saved profile.
   
   for uid in pairs(market.Profiles)do funded:Evaluate(uid) end
  end
  -- Idle connections release expired acknowledgements even if they never send or subscribe again.
  local clock=os.clock() for _,state in pairs(clients)do replies:Prune(state,clock) end
  if world.Mode=="Following"then for player,state in pairs(clients)do route(player,state)end end
 end
 -- Do not skip simulation steps under load; catch up over subsequent frames.
 if broadcast>=Config.BroadcastSeconds then
  broadcast=broadcast%Config.BroadcastSeconds
  for player,state in pairs(clients) do if state.Subscribed then safeEmit(player,state) end end
 end
 local ms=(os.clock()-started)*1000
 performance.Frames+=1 performance.Steps+=steps performance.TotalMs+=ms
 performance.MaxMs=math.max(performance.MaxMs,ms) performance.Backlog=elapsed
 debug.profileend()
end)
-- Read-only diagnostic access in Studio; never replicated to game clients.
if RunService:IsStudio() then
 local diagnostic=Instance.new("BindableFunction") diagnostic.Name="StudioDiagnostics" diagnostic.Parent=script.Parent
 diagnostic.OnInvoke=function(command,a,b)
  if command=="Tests" then return require(script.Parent.MarketTests).Run() end
  if command=="ContinuityTests"then return require(script.Parent.WorldTests).Run()end
  if command=="SingleAccountTests"then return require(script.Parent.SingleAccountTests).Run()end
  if command=="SecurityTests"then return require(script.Parent.SecurityTests).Run()end
  if command=="LeaderboardStatus"then return {Cached=leaderboard.Cache,ReadError=leaderboard.ReadError,WriteError=leaderboard.WriteError,Pending=leaderboard.Pending,Scope=Leaderboards.Scope(world.Studio)}end
  if command=="Performance"then local result=table.clone(performance);result.MeanMs=result.TotalMs/math.max(1,result.Frames);return result end
  if command=="Actions" then return actionLog end
  if not market then return {Mode=world.Mode,Status=world:Label(),Error=world.LastError}end
  if command=="Profiles"then
   local views={} for uid in pairs(market.Profiles)do views[uid]={Saved=market.Profiles[uid],View=funded:View(uid)}end return views
  end
  if command=="Stats"then
   local views={} for uid in pairs(market.Profiles)do views[uid]=funded:Stats(uid)end return views
  end
  local books={}
  for _,key in ipairs(Config.ContractOrder) do
   local book=market.Books[key]
   books[key]={Last=book.Last and book.Last*book.Spec.Tick,Volume=book.Volume,Up=book.Up,Down=book.Down,Bids=#book.Bids,Asks=#book.Asks,Candles=#book.Candles["1m"]}
  end
  local accounts={}
  for _,id in ipairs(market.AccountOrder) do local account=market.Accounts[id] if account.Player then accounts[id]=market:Snapshot(id,Config.ContractOrder[1],"1m",false) end end
  return {Seed=market.Seed,Mode=world.Mode,Status=world:Label(),Step=market.Step,Time=market.Time,Audit=market:Audit(),Books=books,Accounts=accounts,Participants=#population.Agents,Regime=population.Regime.Name}
 end
end

local results={}
local function check(name,fn)local ok,r=pcall(fn);table.insert(results,{Name=name,Passed=ok,Detail=ok and(r or "Passed")or tostring(r)})end
local nextId=0
local function send(player,request)
 nextId+=1;request.Id=nextId;request.ExpectedAccount=request.ExpectedAccount or clients[player].Owner
 requestRemote.OnServerEvent.Callback(player,request)
end
local function frame(dt)dt=dt or .1;now+=dt;fakeRun.Heartbeat.Callback(dt)end
frame()
check("Queued market order serializes and keeps both subscribers live",function()
 send(auditPlayer,{Action="Subscribe",Contract="BX",Timeframe="1m"})
 send(otherPlayer,{Action="Subscribe",Contract="BX",Timeframe="1m"})
 send(auditPlayer,{Action="Place",Contract="BX",Direction=1,Quantity=1000000,Type="Market"})
 frame()
 local packet=packets[auditPlayer];assert(packet and not packet.StatusOnly and packet.CanTrade)
 local found=false;for _,order in ipairs(packet.Orders or {})do if order.Type=="Market"then
  assert(order.Price==nil and order.Queued and order.Quantity>0);found=true
 end end
 assert(found,"Queued market packet was not delivered");assert(packets[otherPlayer] and #warnings==0)
 assert(#packet.Quotes.BX.Depth.Asks>0 and #packet.Quotes.BX.Depth.Bids>0)
end)
check("1200 rapid submissions retain depth broadcasts and bounded server work",function()
 local before=counts[auditPlayer];local beforeOther=counts[otherPlayer];local start=sequence
 for _=1,120 do
  for _=1,10 do send(auditPlayer,{Action="Place",Contract="BX",Direction=1,Quantity=1,Type="Market"})end
  frame(1/60)
 end
 assert(sequence-start<=32,"Spam bypassed server allowance")
 assert(counts[auditPlayer]-before>=19 and counts[otherPlayer]-beforeOther>=19,"Depth stream stalled")
 assert(#queue==0 and #clients[auditPlayer].Replies<=64 and #warnings==0)
 return {Requests=1200,AcceptedForProcessing=sequence-start,DepthPackets=counts[auditPlayer]-before,OtherPlayerPackets=counts[otherPlayer]-beforeOther}
end)
check("Subscription recovery bypasses exhausted trade allowance and coalesces updates",function()
 clients[auditPlayer].Tokens=0;clients[auditPlayer].TokenTime=now
 local before=counts[auditPlayer]
 send(auditPlayer,{Action="Subscribe",Contract="BT",Timeframe="5m"})
 send(auditPlayer,{Action="Subscribe",Contract="BG",Timeframe="1m"})
 assert(counts[auditPlayer]==before,"Subscription caused an immediate packet burst")
 frame();assert(packets[auditPlayer].Contract=="BG"and packets[auditPlayer].Full)
 send(otherPlayer,{Action="Place",Contract="BX",Direction=1,Quantity=1,Type="Market"});frame()
 local found=false;for _,r in ipairs(packets[otherPlayer].Replies or{})do if r.Kind=="Place"then assert(r.Ok);found=true end end
 assert(found,"Spam blocked another player's trade")
end)
check("One failed subscriber does not interrupt another; next packet recovers fully",function()
 local original=market.Snapshot;local owner=clients[auditPlayer].Owner
 market.Snapshot=function(self,id,...)if id==owner then error("Injected packet failure")end return original(self,id,...)end
 local before=counts[otherPlayer];frame();assert(counts[otherPlayer]>before)
 local warned=#warnings;for _=1,4 do frame()end;assert(#warnings==warned,"Unbounded repeated error logging")
 market.Snapshot=original;frame();assert(packets[auditPlayer].Full and packets[auditPlayer].CanTrade)
end)
check("Cancellation clears the queued market order while depth keeps streaming",function()
 now+=4
 local a=market.Accounts[clients[auditPlayer].Owner];local id=next(a.OpenOrders);assert(id)
 send(auditPlayer,{Action="Cancel",OrderId=id});frame()
 assert(not market.Orders[id]);assert(packets[auditPlayer].Orders and #packets[auditPlayer].Orders==0)
 assert(packets[auditPlayer].Quotes.BG.Depth)
 market:Audit()
end)
return results

end)
shared:Destroy();server:Destroy()
if not ok then error(result)end
return result
