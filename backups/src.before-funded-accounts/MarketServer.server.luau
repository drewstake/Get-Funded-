local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TeleportService=game:GetService("TeleportService")
local root=ReplicatedStorage:WaitForChild("MarketReign")
local Config=require(root.MarketConfig)
local World=require(script.Parent.WorldService)
local function remote(name)
 local old=root:FindFirstChild(name) if old then old:Destroy() end
 local r=Instance.new("RemoteEvent") r.Name=name r.Parent=root return r
end
local requestRemote=remote("OrderRequest") local updateRemote=remote("MarketUpdate")
local world=World.new(Config)
local market,population local epoch=-1
root:SetAttribute("SessionSeed",nil) root:SetAttribute("Ready",false)
local clients={} local queue={} local sequence=0 local actionLog={}
local function accountId(player,base) return "player:"..player.UserId..":"..base end
local function add(player)
 if clients[player] then return end
 local id=accountId(player,50000)
 if market then market:AddAccount(id,50000,Config.MaxPlayerInventory,0.8,true)end
 clients[player]={Owner=id,Base=50000,Contract="MES",Timeframe="1m",Full=true,Tokens=20,TokenTime=os.clock(),Seen={},SeenOrder={},Replies={},Subscribed=false}
end
Players.PlayerAdded:Connect(add) for _,p in ipairs(Players:GetPlayers()) do add(p) end
local function emit(player,state)
 if not market or not market.Accounts[state.Owner]or world.Mode=="Unavailable"or world.Mode=="Following"or world.Mode=="Loading"then
  updateRemote:FireClient(player,{StatusOnly=true,CanTrade=false,ConnectionStatus=world:Label(),Replies=state.Replies})
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
 if not state.Full and state.SentRevision==packet.Revision and state.SentBase==packet.Base then
  packet.History=nil packet.Fills=nil
 end
 -- OCO/trigger status can change before a closing execution changes the account revision.
 if not state.Full and state.SentBase==packet.Base and state.SentOrders==orderSignature then
  packet.Orders=nil
 end
 for symbol,quote in pairs(packet.Quotes)do if symbol~=state.Contract then quote.Depth=nil end end
 state.SentRevision=packet.Revision state.SentBase=packet.Base state.SentOrders=orderSignature
 packet.Regime=population.Regime.Name packet.News=market.Time<population.NewsUntil and population.News or nil
 packet.Speed=Config.SimulationSpeed packet.Replies=state.Replies
 updateRemote:FireClient(player,packet) state.Full=false state.Replies={}
end
local function reply(state,id,ok,message,result)
 table.insert(state.Replies,{RequestId=id,Ok=ok,Message=message,Result=result})
end
requestRemote.OnServerEvent:Connect(function(player,request)
 local state=clients[player]
 if not state or type(request)~="table" then return end
 local now=os.clock() state.Tokens=math.min(20,state.Tokens+(now-state.TokenTime)*6) state.TokenTime=now
 if state.Tokens<1 then return end state.Tokens-=1
 if type(request.Id)~="number" or request.Id%1~=0 or request.Id<1 or request.Id>1e9 or state.Seen[request.Id] then return end
 local allowed={Place=true,Cancel=true,Close=true,Subscribe=true,Account=true,AmendProtection=true}
 if not allowed[request.Action] then return end
 -- Whitelist scalar fields; do not accept account identities, execution prices or timestamps.
 local clean={Id=request.Id,Action=request.Action}
 for _,field in ipairs({"Contract","Timeframe","Direction","Quantity","Type","Price","StopTicks","TargetTicks","OrderId","Protection","Base","ExpectedPrice"}) do
  local value=request[field]
  if value~=nil then
   if type(value)~="number" and type(value)~="string" then return end
   if type(value)=="number" and (value~=value or math.abs(value)>1e9) then return end
   if type(value)=="string" and #value>32 then return end
   clean[field]=value
  end
 end
 if #queue>=256 then reply(state,clean.Id,false,"Exchange busy. Please retry.") return end
 state.Seen[clean.Id]=true table.insert(state.SeenOrder,clean.Id)
 if #state.SeenOrder>256 then state.Seen[table.remove(state.SeenOrder,1)]=nil end
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
 local req=item.Request local a=market.Accounts[state.Owner] local ok,result
 if req.Action=="Subscribe" then
  if not Config.Contracts[req.Contract] or not market.Books[req.Contract].Candles[req.Timeframe] then return end
  state.Contract=req.Contract state.Timeframe=req.Timeframe state.Full=true state.Subscribed=true return
 elseif req.Action=="Account" then
  if req.Base~=50000 and req.Base~=100000 then return end
  state.Base=req.Base state.Owner=accountId(item.Player,req.Base)
  market:AddAccount(state.Owner,req.Base,Config.MaxPlayerInventory,0.8,true) state.Full=true
  reply(state,req.Id,true,"Simulated account selected.") return
 elseif req.Action=="Place" then
  ok,result=market:Submit(state.Owner,req)
 elseif req.Action=="AmendProtection" then
  ok,result=market:AmendProtection(state.Owner,req)
 elseif req.Action=="Cancel" then
  if type(req.OrderId)~="number" then return end
  if req.Protection then ok,result=market:CancelProtection(state.Owner,req.OrderId,req.Protection)
  else ok,result=market:Cancel(state.Owner,req.OrderId) end
 elseif req.Action=="Close" then
  local p=a.Positions[req.Contract]
  if p then
   market:CancelAll(state.Owner,req.Contract)
   -- Latched close survives a partial fill/empty book and cannot reverse the position.
   p.Triggered="Player close"
   p.Stop=nil p.Target=nil
   ok,result=market:Submit(state.Owner,{Contract=req.Contract,Direction=-p.Direction,Quantity=math.min(p.Quantity,Config.MaxPlayerQuantity),Type="Market",ReduceOnly=true})
  else ok=false result="No open position." end
 end
 market:ProcessStops()
 if type(result)=="table" then
  local message=result.Filled>0 and string.format("Filled %d @ %.2f · slippage %+.2f pts",result.Filled,result.Average,result.Slippage) or result.Status
  if result.Remaining>0 then message..=" · "..result.Remaining.." working" end
  if result.Cancelled>0 then message..=" · "..result.Cancelled.." unfilled" end
  reply(state,req.Id,ok,message,result)
 else reply(state,req.Id,ok,result or "Request rejected.") end
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
game:BindToClose(function()world:Close()end)
local elapsed,broadcast,maintenance=0,0,0
RunService.Heartbeat:Connect(function(dt)
 if epoch~=world.Epoch then
  epoch=world.Epoch market=world.Engine population=world.Population elapsed=0
  for player,state in pairs(clients)do
   if market then market:AddAccount(state.Owner,state.Base,Config.MaxPlayerInventory,0.8,true)end
   state.Full=true
  end
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
  if world.Mode=="Following"then for player,state in pairs(clients)do route(player,state)end end
 end
 -- Do not skip simulation steps under load; catch up over subsequent frames.
 if broadcast>=Config.BroadcastSeconds then
  broadcast=broadcast%Config.BroadcastSeconds
  for player,state in pairs(clients) do if state.Subscribed then emit(player,state) end end
 end
end)
-- Read-only diagnostic access in Studio; never replicated to game clients.
if RunService:IsStudio() then
 local diagnostic=Instance.new("BindableFunction") diagnostic.Name="StudioDiagnostics" diagnostic.Parent=script.Parent
 diagnostic.OnInvoke=function(command)
  if command=="Tests" then return require(script.Parent.MarketTests).Run() end
  if command=="ContinuityTests"then return require(script.Parent.WorldTests).Run()end
  if command=="Actions" then return actionLog end
  if not market then return {Mode=world.Mode,Status=world:Label(),Error=world.LastError}end
  local books={}
  for _,key in ipairs(Config.ContractOrder) do
   local b=market.Books[key]
   books[key]={Last=b.Last and b.Last*b.Spec.Tick,Volume=b.Volume,Up=b.Up,Down=b.Down,Bids=#b.Bids,Asks=#b.Asks,Candles=#b.Candles["1m"]}
  end
  local accounts={}
  for _,id in ipairs(market.AccountOrder) do local a=market.Accounts[id] if a.Player then accounts[id]=market:Snapshot(id,"MES","1m",false) end end
  return {Seed=market.Seed,Mode=world.Mode,Status=world:Label(),Step=market.Step,Time=market.Time,Audit=market:Audit(),Books=books,Accounts=accounts,Participants=#population.Agents,Regime=population.Regime.Name}
 end
end
