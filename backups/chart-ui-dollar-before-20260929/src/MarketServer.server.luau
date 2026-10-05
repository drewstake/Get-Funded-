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
Funded.Validate(Progression) -- A malformed ladder must stop the server, not corrupt saved profiles.
local function remote(name)
 local old=root:FindFirstChild(name) if old then old:Destroy() end
 local r=Instance.new("RemoteEvent") r.Name=name r.Parent=root return r
end
local requestRemote=remote("OrderRequest") local updateRemote=remote("MarketUpdate")
local world=World.new(Config)
local leaderboard=Leaderboards.new({Studio=world.Studio})
world.CaptureProjection=function(engine)return Ranking.Capture(Funded.new(engine,Progression,Config))end
local oldLeaderboard=root:FindFirstChild("LeaderboardRequest") if oldLeaderboard then oldLeaderboard:Destroy() end
local leaderboardRemote=Instance.new("RemoteFunction") leaderboardRemote.Name="LeaderboardRequest" leaderboardRemote.Parent=root
local market,population,funded local epoch=-1
root:SetAttribute("SessionSeed",nil) root:SetAttribute("Ready",false)
local clients={} local queue={} local sequence=0 local actionLog={}
-- The trading account comes from the player's saved funded profile. New players have no account until
-- they press Start, so joining never creates a starter (or duplicate) account.
local function resolve(player,state)
 if not funded then return end
 funded:Join(state.Uid) funded:Evaluate(state.Uid)
 local p=funded:Profile(state.Uid)
 if p then p.PlayerName=player.Name;p.DisplayName=player.DisplayName end
 state.Owner=funded:Owner(state.Uid) state.Full=true state.PortfolioRevision=nil
end
local function add(player)
 if clients[player] then return end
 clients[player]={Uid=Funded.Key(player.UserId),Contract="ES",Timeframe="1m",Full=true,Tokens=20,TokenTime=os.clock(),
  Seen={},SeenOrder={},Replies={},Subscribed=false,PortfolioAt=0}
 resolve(player,clients[player])
end
Players.PlayerAdded:Connect(add) for _,p in ipairs(Players:GetPlayers()) do add(p) end
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
-- Portfolio view: on change, on full refresh and once per second for dashboard balances.
local function attachPortfolio(state,packet)
 if not funded then return end
 packet.Events=funded:TakeEvents(state.Uid)
 local profile=funded:Profile(state.Uid)
 local revision=profile and profile.Revision or 0 local now=os.clock()
 if state.Full or state.PortfolioRevision~=revision or now-state.PortfolioAt>=1 then
  packet.Portfolio=funded:View(state.Uid) state.PortfolioRevision=revision state.PortfolioAt=now
 end
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
 local unavailable=not market or world.Mode=="Unavailable" or world.Mode=="Following" or world.Mode=="Loading"
 if unavailable or not state.Owner or not market.Accounts[state.Owner] then
  -- No trading account yet (first join) or the exchange is not ready: send status and portfolio only.
  local packet={StatusOnly=true,CanTrade=not unavailable and world:CanRun(),ConnectionStatus=world:Label(),Replies=state.Replies,NoAccount=not unavailable or nil}
  if not unavailable then attachPortfolio(state,packet) state.Full=false end
  updateRemote:FireClient(player,packet)
  state.Replies={} return
 end
 local packet=market:Snapshot(state.Owner,state.Contract,state.Timeframe,state.Full)
 packet.Seed=nil -- The server's future random stream is private.
 packet.CanTrade=world:CanRun() packet.ConnectionStatus=world:Label() packet.PersistenceMode=world.Mode
 -- Quotes/candles/P&L are frequent; unchanged order and trade histories are not resent.
 local orderParts={}
 for _,order in ipairs(packet.Orders)do
  table.insert(orderParts,table.concat({order.Id,order.Contract,order.Protection or "",order.Quantity,order.Price,order.Status},":"))
 end
 local orderSignature=table.concat(orderParts,"|")
 if not state.Full and state.SentRevision==packet.Revision and state.SentOwner==state.Owner then
  packet.History=nil packet.Fills=nil
 end
 -- OCO/trigger status can change before a closing execution changes the account revision.
 if not state.Full and state.SentOwner==state.Owner and state.SentOrders==orderSignature then
  packet.Orders=nil
 end
 for symbol,quote in pairs(packet.Quotes)do if symbol~=state.Contract then quote.Depth=nil end end
 state.SentRevision=packet.Revision state.SentOwner=state.Owner state.SentOrders=orderSignature
 packet.Regime=population.Regime.Name packet.News=market.Time<population.NewsUntil and population.News or nil
 packet.Speed=Config.SimulationSpeed packet.Replies=state.Replies
 packet.AccountKey=(funded:Profile(state.Uid) or {}).Active
 attachPortfolio(state,packet)
 updateRemote:FireClient(player,packet) state.Full=false state.Replies={}
end
local function reply(state,id,ok,message,result,extra)
 local r={RequestId=id,Ok=ok,Message=message,Result=result}
 for k,v in pairs(extra or {})do r[k]=v end
 table.insert(state.Replies,r)
end
local allowed={Place=true,Cancel=true,Close=true,Subscribe=true,Account=true,AmendProtection=true,
 Start=true,Activate=true,Restart=true,Copy=true,Flag=true,Stats=true}
local fields={"Contract","Timeframe","Direction","Quantity","Type","Price","StopTicks","TargetTicks","OrderId","Protection","ExpectedPrice",
 "Key","Tier","Enabled","Leader","Followers","Sizing","Stage"}
requestRemote.OnServerEvent:Connect(function(player,request)
 local state=clients[player]
 if not state or type(request)~="table" then return end
 local now=os.clock() state.Tokens=math.min(20,state.Tokens+(now-state.TokenTime)*6) state.TokenTime=now
 if state.Tokens<1 then return end state.Tokens-=1
 if type(request.Id)~="number" or request.Id%1~=0 or request.Id<1 or request.Id>1e9 or state.Seen[request.Id] then return end
 if not allowed[request.Action] then return end
 -- Whitelist scalar fields; do not accept account identities, execution prices, timestamps or copy links.
 local clean={Id=request.Id,Action=request.Action}
 for _,field in ipairs(fields) do
  local value=request[field]
  if value~=nil then
   if type(value)~="number" and type(value)~="string" then return end
   if type(value)=="number" and (value~=value or math.abs(value)>1e9) then return end
   if type(value)=="string" and #value>(field=="Followers" and 64 or 32) then return end
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
   emit(player,state)
  end
  return
 end
 if not world:CanRun()then reply(state,clean.Id,false,world:Label())emit(player,state)return end
 sequence+=1 table.insert(queue,{Player=player,Request=clean,Sequence=sequence,Epoch=epoch})
end)
local function process(item)
 local state=clients[item.Player] if not state then return end
 if item.Epoch~=epoch then reply(state,item.Request.Id,false,"Exchange reconnected. Please submit your order again.")return end
 local req=item.Request local uid=state.Uid
 -- Account lifecycle. Each is idempotent and validated against the saved profile.
 if req.Action=="Start" then
  local ok,message,created=funded:Start(uid)
  local profile=funded:Profile(uid);if profile then profile.PlayerName=item.Player.Name;profile.DisplayName=item.Player.DisplayName end
  state.Owner=funded:Owner(uid) state.Full=true
  reply(state,req.Id,ok,message,nil,{Kind="Start",Created=created}) return
 elseif req.Action=="Activate" then
  local ok,message=funded:Activate(uid,req.Tier)
  reply(state,req.Id,ok,message,nil,{Kind="Activate",Tier=req.Tier}) return
 elseif req.Action=="Account" then
  local ok,message=funded:Select(uid,req.Key)
  if ok then state.Owner=funded:Owner(uid) state.Full=true end
  reply(state,req.Id,ok,message,nil,{Kind="Account",Key=req.Key}) return
 elseif req.Action=="Restart" then
  local ok,message=funded:Restart(uid,req.Tier)
  if ok then state.Owner=funded:Owner(uid) state.Full=true end
  reply(state,req.Id,ok,message,nil,{Kind="Restart",Tier=req.Tier}) return
 elseif req.Action=="Copy" then
  local ok,message=funded:SetCopy(uid,req)
  reply(state,req.Id,ok,message,nil,{Kind="Copy"}) return
 elseif req.Action=="Flag" then
  local ok,message=funded:Flag(uid,req.Stage)
  reply(state,req.Id,ok,message,nil,{Kind="Flag",Stage=req.Stage}) return
 end
 -- Trading. The lead order executes first; copies then run through the same engine calls.
 local owner=state.Owner
 if not owner or not market.Accounts[owner] then reply(state,req.Id,false,"Start a funded account to trade.") return end
 if req.Action=="Place" and not Progression.LegacyTradable and funded:IsLegacyOwner(uid,owner) then
  reply(state,req.Id,false,"Legacy practice accounts are close-only. Trade a funded account instead.") return
 end
 local plan=funded:Plan(uid,owner)
 local context=plan and funded:Context(owner,req)
 local ok,result=Funded.Perform(market,owner,req)
 local copies=plan and funded:Mirror(plan,req,ok,result,context)
 market:ProcessStops()
 funded:Evaluate(uid)
 local message=type(result)=="table" and Funded.Describe(result) or result or "Request rejected."
 if copies and ok then message..=string.format(" · copied %d/%d",copies.Copied,copies.Total) end
 reply(state,req.Id,ok,message,type(result)=="table" and result or nil,{Kind=req.Action,Copies=copies})
end
Players.PlayerRemoving:Connect(function(player)
 -- Accounts, resting orders and protection belong to the exchange, not the GUI connection.
 -- Leaving keeps risk and fills active; returning retrieves the same account.
 clients[player]=nil
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
task.spawn(function()world:Open()end)
game:BindToClose(function()
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
  funded=market and Funded.new(market,Progression,Config) or nil
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
  population:Step()
 end
 if not active and #queue>0 then
  for _,item in ipairs(queue)do local state=clients[item.Player]if state then reply(state,item.Request.Id,false,world:Label())end end
  queue={}
 end
 if maintenance>=1 then
  maintenance=0 task.spawn(function()world:Maintain()end)
  -- Resting orders and SL/TP can realize profit while a player is away; unlocks are still earned once.
  if active and funded then for uid in pairs(market.Profiles)do funded:Evaluate(uid)end end
  if world.Mode=="Following"then for player,state in pairs(clients)do route(player,state)end end
 end
 -- Do not skip simulation steps under load; catch up over subsequent frames.
 if broadcast>=Config.BroadcastSeconds then
  broadcast=broadcast%Config.BroadcastSeconds
  for player,state in pairs(clients) do if state.Subscribed then emit(player,state) end end
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
  if command=="FundedTests"then return require(script.Parent.FundedTests).Run()end
  if command=="ProgressionTests"then return require(script.Parent.ProgressionTests).Run()end
  if command=="DepletionTests"then return require(script.Parent.DepletionTests).Run()end
  if command=="LeaderboardTests"then return require(script.Parent.LeaderboardTests).Run()end
  if command=="StatsTests"then return require(script.Parent.StatsTests).Run()end
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
  if command=="SetUnlock"then
   -- Studio-only playtest aid: lower a tier's requirement for this server session. Never saved.
   for _,t in ipairs(Progression.Tiers)do if t.Id==a and type(b)=="number" and t.Unlock>0 then t.Unlock=b return true end end
   return false
  end
  local books={}
  for _,key in ipairs(Config.ContractOrder) do
   local book=market.Books[key]
   books[key]={Last=book.Last and book.Last*book.Spec.Tick,Volume=book.Volume,Up=book.Up,Down=book.Down,Bids=#book.Bids,Asks=#book.Asks,Candles=#book.Candles["1m"]}
  end
  local accounts={}
  for _,id in ipairs(market.AccountOrder) do local account=market.Accounts[id] if account.Player then accounts[id]=market:Snapshot(id,"ES","1m",false) end end
  return {Seed=market.Seed,Mode=world.Mode,Status=world:Label(),Step=market.Step,Time=market.Time,Audit=market:Audit(),Books=books,Accounts=accounts,Participants=#population.Agents,Regime=population.Regime.Name}
 end
end
