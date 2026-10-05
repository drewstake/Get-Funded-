-- Isolated audit of the actual MarketServer source with mocked Roblox boundaries.
-- The real script below is executed lexically against fake Players/remotes/clock/tasks.
-- Only pure modules are required from Edit mode; all market/profile/store state is disposable.
local RealGame=game
local Shared=RealGame.ReplicatedStorage.MarketReign
local Server=RealGame.ServerScriptService.MarketReign
local function clone(x)if type(x)~="table"then return x end local r={}for k,v in pairs(x)do r[k]=clone(v)end return r end
local AuditConfig=clone(require(Shared.MarketConfig))
local AuditLadder=clone(require(Shared.ProgressionConfig))
local AuditEngine=require(Server.MarketEngine).new(AuditConfig,1729)
local AuditFunded=require(Server.FundedAccounts)
local AuditRanking=require(Server.LeaderboardRanking)
local now=100
local function signal()local s={}function s:Connect(fn)self.Callback=fn;return {Disconnect=function()end}end return s end
local auditPlayer={UserId=901,Name="AuditOne",DisplayName="Audit One"}
local otherPlayer={UserId=902,Name="AuditTwo",DisplayName="Audit Two"}
local fakePlayers={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function()return {auditPlayer,otherPlayer}end}
local fakeRun={Heartbeat=signal(),IsStudio=function()return false end}
local fakeTeleport={TeleportInitFailed=signal(),TeleportAsync=function()error("Network access forbidden in audit")end}
local remoteMap={}
local fakeRoot={SetAttribute=function()end,FindFirstChild=function(_,n)return remoteMap[n]end,MarketConfig="config",ProgressionConfig="ladder"}
local sends=0
local fakeInstance={}
function fakeInstance.new(class)
 local o={ClassName=class,OnServerEvent=signal(),Destroy=function()end}
 function o:FireClient(player,packet)sends+=1;self.LastPacket=packet end
 return setmetatable(o,{__newindex=function(t,k,v)rawset(t,k,v);if k=="Name"then remoteMap[v]=t end end})
end
local population={Regime={Name="Audit"},NewsUntil=0,Step=function()AuditEngine.Time+=AuditConfig.StepSeconds;AuditEngine.Step+=1 end}
local auditWorld={Studio=true,Engine=AuditEngine,Population=population,Epoch=1,Mode="Local",CanRun=function()return true end,Label=function()return "AUDIT"end,Maintain=function()end,HasCapacity=function()return true end}
local boardCalls=0
local fakeBoard={Server=function()boardCalls+=1;return {State="Ready"}end,Global=function()boardCalls+=1;return {State="Ready"}end}
local modules={ReplyBuffer=require(Server.ReplyBuffer),WorldConfig=require(Server.WorldConfig),config=AuditConfig,ladder=AuditLadder,WorldService={new=function()return auditWorld end},FundedAccounts=AuditFunded,LeaderboardRanking=AuditRanking,LeaderboardService={new=function()return fakeBoard end}}
local game={GetService=function(_,n)
 if n=="ReplicatedStorage"then return {WaitForChild=function()return fakeRoot end}
 elseif n=="Players"then return fakePlayers elseif n=="RunService"then return fakeRun elseif n=="TeleportService"then return fakeTeleport end
 error("Unexpected service: "..n)
end,BindToClose=function()end}
local script={Parent={ReplyBuffer="ReplyBuffer",WorldConfig="WorldConfig",WorldService="WorldService",FundedAccounts="FundedAccounts",LeaderboardService="LeaderboardService",LeaderboardRanking="LeaderboardRanking"}}
local require=function(k)assert(modules[k],"Unexpected module");return modules[k]end
local Instance=fakeInstance
local task={spawn=function()end}
local debug={profilebegin=function()end,profileend=function()end}
local os={clock=function()return now end,time=function()return 1000 end}

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
Funded.Validate(Progression) -- Fail closed on invalid progression configuration.
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
-- Acknowledgements are bounded per connection by count and age (see ReplyBuffer).
local replies=ReplyBuffer.new(WorldSettings.MaxQueuedReplies,WorldSettings.ReplyMaxAgeSeconds)
-- Joining idempotently creates one $5,000 account for a new player.
local function resolve(player,state)
 if not funded then return end
 funded:Join(state.Uid) funded:Evaluate(state.Uid)
 local p=funded:Profile(state.Uid)
 if p then p.PlayerName=player.Name;p.DisplayName=player.DisplayName end
 state.Owner=funded:Owner(state.Uid) state.Full=true state.PortfolioRevision=nil
end
local function add(player)
 if clients[player] then return end
 clients[player]={Uid=Funded.Key(player.UserId),Contract=Config.ContractOrder[1],Timeframe="1m",Full=true,Tokens=20,TokenTime=os.clock(),
  Seen={},SeenOrder={},Replies={},ReplyTimes={},Subscribed=false,PortfolioAt=0}
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
 if funded and world:CanRun() and not funded:Owner(state.Uid) and os.clock()>=(state.JoinRetryAt or 0) then
  state.JoinRetryAt=os.clock()+5;resolve(player,state)
 end
 if funded then
  local owner=funded:Owner(state.Uid)
  if state.Owner~=owner then state.Owner=owner;state.Full=true end
 end
 local unavailable=not market or world.Mode=="Unavailable" or world.Mode=="Following" or world.Mode=="Loading"
 if unavailable or not state.Owner or not market.Accounts[state.Owner] then
  -- No trading account yet (first join) or the exchange is not ready: send status and portfolio only.
  local queued,dropped=replies:Take(state)
  local packet={StatusOnly=true,CanTrade=not unavailable and world:CanRun(),ConnectionStatus=world:Label(),Replies=queued,RepliesDropped=dropped,NoAccount=not unavailable or nil}
  if not unavailable then attachPortfolio(state,packet) state.Full=false end
  updateRemote:FireClient(player,packet)
  return
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
 packet.Speed=Config.SimulationSpeed packet.Replies,packet.RepliesDropped=replies:Take(state)
 packet.AccountKey=(funded:Profile(state.Uid) or {}).Active
 packet.AccountToken=state.Owner -- identifies the exact attempt; checked, never used to choose an owner
 attachPortfolio(state,packet)
 updateRemote:FireClient(player,packet) state.Full=false
end
local function reply(state,id,ok,message,result,extra)
 local r={RequestId=id,Ok=ok,Message=message,Result=result}
 for k,v in pairs(extra or {})do r[k]=v end
 replies:Push(state,r,os.clock())
end
local allowed={Place=true,Cancel=true,Close=true,Subscribe=true,AmendProtection=true,AmendOrder=true,
 Start=true,Restart=true,Flag=true,Stats=true}
local fields={"ExpectedAccount","Contract","Timeframe","Direction","Quantity","Type","Price","StopTicks","TargetTicks","StopDollars","TargetDollars","ExpectedQuantity","OrderId","Protection","ExpectedPrice",
 "Stage"}
requestRemote.OnServerEvent:Connect(function(player,request)
 local state=clients[player]
 if not state or type(request)~="table" then return end
 local now=os.clock() state.Tokens=math.min(20,state.Tokens+(now-state.TokenTime)*6) state.TokenTime=now
 if state.Tokens<1 then return end state.Tokens-=1
 if type(request.Id)~="number" or request.Id%1~=0 or request.Id<1 or request.Id>1e9 or state.Seen[request.Id] then return end
 if not allowed[request.Action] then return end
 -- Whitelist scalar inputs. ExpectedAccount detects a stale view; it never selects an owner.
 -- Execution prices, timestamps and account ownership remain server-owned.
 local clean={Id=request.Id,Action=request.Action}
 for _,field in ipairs(fields) do
  local value=request[field]
  if value~=nil then
   if type(value)~="number" and type(value)~="string" then return end
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
   emit(player,state)
  end
  return
 end
 if not world:CanRun()then reply(state,clean.Id,false,world:Label())emit(player,state)return end
 sequence+=1 table.insert(queue,{Player=player,Request=clean,Sequence=sequence,Epoch=epoch,Owner=state.Owner})
end)
local function process(item)
 local state=clients[item.Player] if not state then return end
 if not world:CanRun() then reply(state,item.Request.Id,false,world:Label(),nil,{Kind=item.Request.Action}) return end
 if item.Epoch~=epoch then reply(state,item.Request.Id,false,"Exchange reconnected. Please submit your order again.")return end
 local req=item.Request local uid=state.Uid
 funded:Evaluate(uid)
 local owner=funded:Owner(uid)
 if state.Owner~=owner then
  state.Owner=owner;state.Full=true
  if req.Action=="Place" or req.Action=="Close" or req.Action=="Cancel" or req.Action=="AmendOrder" or req.Action=="AmendProtection" then
   reply(state,req.Id,false,"Your trading account changed after depletion. Review your current run and retry.") return
  end
 end
 -- Account lifecycle. Each is idempotent and validated against the saved profile.
 if req.Action=="Start" then
  local ok,message,created=funded:Start(uid)
  local profile=funded:Profile(uid);if profile then profile.PlayerName=item.Player.Name;profile.DisplayName=item.Player.DisplayName end
  state.Owner=funded:Owner(uid) state.Full=true
  reply(state,req.Id,ok,message,nil,{Kind="Start",Created=created}) return
 elseif req.Action=="Restart" then
  local ok,message=funded:Restart(uid,req.ExpectedAccount)
  if ok then state.Owner=funded:Owner(uid) state.Full=true end
  reply(state,req.Id,ok,message,nil,{Kind="Restart",Tier=req.Tier}) return
 elseif req.Action=="Flag" then
  local ok,message=funded:Flag(uid,req.Stage)
  reply(state,req.Id,ok,message,nil,{Kind="Flag",Stage=req.Stage}) return
 end
 -- Trading owner and current run token are resolved only on the server.
 local owner=state.Owner
 if item.Owner~=owner or req.ExpectedAccount~=owner then reply(state,req.Id,false,"Your trading account changed. Review your current run and retry.") return end
 if not owner or not market.Accounts[owner] then reply(state,req.Id,false,"Your trading account is loading.") return end
 local ok,result=Funded.Perform(market,owner,req)
 market:ProcessStops()
 funded:Evaluate(uid)
 local message=type(result)=="table" and Funded.Describe(result) or result or "Request rejected."
 reply(state,req.Id,ok,message,type(result)=="table" and result or nil,{Kind=req.Action})
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
  funded=market and Funded.new(market,Progression,Config,{Capacity=function(kind) return world:HasCapacity(kind) end}) or nil
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
  -- Resting orders and SL/TP can realize profit while a player is away; unlocks are still earned once.
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


local function frame(dt)fakeRun.Heartbeat.Callback(dt or AuditConfig.StepSeconds/AuditConfig.SimulationSpeed+.000001)end
frame()
local nextId=0
local function send(player,req)
 now+=1;nextId+=1;req.Id=nextId;remoteMap.OrderRequest.OnServerEvent.Callback(player,req);frame()
 local pending=clients[player].Replies
 local delivered=remoteMap.MarketUpdate.LastPacket and remoteMap.MarketUpdate.LastPacket.Replies or {}
 return pending[#pending] or delivered[#delivered]
end
local results={}
local function check(name,fn)local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Detail=ok and 'Passed' or tostring(err)})end
check('New players land with one account without a Start request',function()
 assert(clients[auditPlayer].Owner and clients[otherPlayer].Owner)
 assert(AuditEngine.Accounts[clients[auditPlayer].Owner].Balance==5000)
end)
check('Removed Account, Copy, Purchase and Activate actions never enter the queue',function()
 for _,action in ipairs({'Account','Copy','Purchase','Activate'}) do
  now+=1;nextId+=1;remoteMap.OrderRequest.OnServerEvent.Callback(auditPlayer,{Id=nextId,Action=action,Key=clients[otherPlayer].Owner})
  assert(not clients[auditPlayer].Seen[nextId] and #queue==0)
 end
end)
check('Owner, balance, fill price and reward fields cannot be forged',function()
 local id=clients[auditPlayer].Owner;local other=clients[otherPlayer].Owner
 local r=send(auditPlayer,{Action='Place',ExpectedAccount=id,Owner=other,Balance=999999,FillTicks=1,Awards={Balance100K=true},Contract='BX',Direction=1,Quantity=1,Type='Market'})
 assert(r.Ok and AuditEngine.Accounts[id].Positions.BX and not AuditEngine.Accounts[other].Positions.BX)
 assert(AuditEngine.Accounts[id].Balance==5000 and not next(funded:Profile('901').Awards))
 assert(send(auditPlayer,{Action='Close',ExpectedAccount=id,Contract='BX'}).Ok)
end)
check('Other-player tokens and foreign cancellation are rejected',function()
 local id=clients[auditPlayer].Owner;local other=clients[otherPlayer].Owner
 assert(not send(auditPlayer,{Action='Place',ExpectedAccount=other,Contract='BX',Direction=1,Quantity=1,Type='Market'}).Ok)
 local o=send(otherPlayer,{Action='Place',ExpectedAccount=other,Contract='BX',Direction=1,Quantity=1,Type='Limit',Price=AuditConfig.Contracts.BX.Last-100})
 assert(o.Ok);assert(not send(auditPlayer,{Action='Cancel',ExpectedAccount=id,OrderId=o.Result.Id}).Ok)
 assert(AuditEngine.Orders[o.Result.Id])
end)
check('Restart validates failed run, current token and queue owner; duplicate cannot grant twice',function()
 local id=clients[auditPlayer].Owner
 assert(not send(auditPlayer,{Action='Restart',ExpectedAccount=id}).Ok)
 local a=AuditEngine.Accounts[id];local b=AuditEngine.Books.BX;b.Last=24000;b.Bids={};b.Asks={}
 assert(AuditEngine:Submit(id,{Contract='BX',Direction=1,Quantity=1,Type='Market'}));b.Last-=400
 AuditEngine:AdvanceClock(.25);funded:Evaluate('901');assert(a.Depleted)
 assert(not send(auditPlayer,{Action='Restart',ExpectedAccount=clients[otherPlayer].Owner}).Ok)
 now+=1
 for _,req in ipairs({{Action='Restart'},{Action='Restart'},{Action='Place',Contract='BX',Direction=1,Quantity=1,Type='Market'}}) do
  nextId+=1;req.Id=nextId;req.ExpectedAccount=id;remoteMap.OrderRequest.OnServerEvent.Callback(auditPlayer,req)
 end
 frame();local current=clients[auditPlayer].Owner;assert(current~=id)
 assert(AuditEngine.Accounts[current].Balance==5000 and not next(AuditEngine.Accounts[current].Positions))
 assert(funded:Profile('901').Run==2 and funded:Earned(funded:Profile('901'))==-5000)
end)
check('New connection keeps account, run and restart budget',function()
 local p=funded:Profile('901');local id=p.Account;local tokens=p.Limits.Reset.Tokens
 clients[auditPlayer]=nil;fakePlayers.PlayerAdded.Callback(auditPlayer);frame()
 assert(clients[auditPlayer].Owner==id and funded:Profile('901').Run==2 and p.Limits.Reset.Tokens==tokens)
end)
check('Deduplicated requests and input validation preserve limits',function()
 local id=clients[auditPlayer].Owner;now+=1;nextId+=1
 local req={Id=nextId,Action='Place',ExpectedAccount=id,Contract='BX',Direction=1,Quantity=1,Type='Market'}
 remoteMap.OrderRequest.OnServerEvent.Callback(auditPlayer,req);remoteMap.OrderRequest.OnServerEvent.Callback(auditPlayer,req);frame()
 assert(AuditEngine.Accounts[id].Positions.BX.Quantity==1)
 for _,value in ipairs({math.huge,0/0,{},true}) do
  now+=1;nextId+=1;remoteMap.OrderRequest.OnServerEvent.Callback(auditPlayer,{Id=nextId,Action='Place',Quantity=value})
  assert(not clients[auditPlayer].Seen[nextId])
 end
end)
check('Paused exchange refuses restarts and trades',function()
 auditWorld.CanRun=function()return false end
 local id=clients[auditPlayer].Owner
 assert(not send(auditPlayer,{Action='Restart',ExpectedAccount=id}).Ok)
 assert(not send(auditPlayer,{Action='Place',ExpectedAccount=id,Contract='BX',Direction=1,Quantity=1,Type='Market'}).Ok)
 assert(clients[auditPlayer].Owner==id)
end)
AuditEngine:Audit()
return results
