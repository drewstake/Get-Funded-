-- Isolated Edit-mode UI/trading fixture. No DataStore, player profile or live remote.
local shared=game.ReplicatedStorage.MarketReign:Clone();shared.Name="SingleAccountQA";shared.Parent=game.ReplicatedStorage
local server=game.ServerScriptService.MarketReign:Clone();server.Name="SingleAccountQA";server.MarketServer.Enabled=false;server.Parent=game.ServerScriptService
for _,folder in ipairs({shared,server}) do for _,m in ipairs(folder:GetDescendants()) do
 if m:IsA('LuaSourceContainer') then m.Source=m.Source:gsub('game%.ReplicatedStorage%.MarketReign','game.ReplicatedStorage.SingleAccountQA'):gsub('game%.ServerScriptService%.MarketReign','game.ServerScriptService.SingleAccountQA') end
end end
local gui=Instance.new('ScreenGui');gui.Name='SingleAccountQA';gui.IgnoreGuiInset=true;gui.DisplayOrder=100;gui.Parent=game.StarterGui
local ctl
local ok,result=xpcall(function()
 local M=require(shared.MarketClient);local UI=require(shared.TerminalUI)
 local E=require(server.MarketEngine);local F=require(server.FundedAccounts)
 local config=require(shared.MarketConfig);local ladder=require(shared.ProgressionConfig)
 local e=E.new(config,916);local f=F.new(e,ladder,config);f:Join('isolated-ui')
 local original=M.New;local session
 M.New=function()
  local data={Quotes={},CandlesBySeries={},Time=3600,Step=1}
  for _,key in ipairs(config.ContractOrder) do
   local spec=config.Contracts[key];data.Quotes[key]={Last=spec.Last,Open=spec.Last,Bid=spec.Last-spec.Tick,Ask=spec.Last+spec.Tick}
   for _,tf in ipairs(config.Timeframes) do
    local list={};for i=1,60 do local price=spec.Last+math.sin(i*.7)*8*spec.Tick
     list[i]={Time=(i-1)*tf[2],Open=price,Close=price+spec.Tick,High=price+3*spec.Tick,Low=price-2*spec.Tick,Volume=10}
    end;data.CandlesBySeries[key..':'..tf[1]]=list
   end
  end
  session=original(nil,true,data);session.Preview=false;session.Ready=true;session.CanTrade=true;session.ConnectionStatus='ISOLATED TEST · NOT SAVED'
  local function update()
   local a=e.Accounts[f:Owner('isolated-ui')];local snap=e:Snapshot(a.Id,'BX','1m',true)
   session.Portfolio=f:View('isolated-ui');session.AccountKey=a.Id;session.AccountToken=a.Id
   session.SummaryData=snap.Summary;session.Positions=snap.Positions;session.Orders=snap.Orders;session.History=snap.History;session.Fills=snap.Fills
   session.Limit=snap.Limit;session.Capacity=snap.Capacity;session.Stats=f:Stats('isolated-ui')
  end
  session.Send=function(_,action,req)
   if action=='Subscribe' or action=='Stats' then return true,'Fixture','Orders',0 end
   session.NextId+=1;local requestId=session.NextId;req=req or {};req.Action=action
   local accepted,value
   if action=='Restart' then accepted,value=f:Restart('isolated-ui',session.AccountToken)
   elseif action=='Flag' then accepted,value=f:Flag('isolated-ui',req.Stage)
   else accepted,value=F.Perform(e,f:Owner('isolated-ui'),req) end
   e:ProcessStops();f:Evaluate('isolated-ui');update()
   task.defer(function()
    session.Replies:Fire({Ok=accepted,Message=type(value)=='table' and F.Describe(value) or value,Kind=action,RequestId=requestId,Result=type(value)=='table' and value or nil})
    for _,event in ipairs(f:TakeEvents('isolated-ui') or {}) do session:_event(event) end
    session.Changed:Fire()
   end)
   return true,'Fixture','Orders',requestId
  end
  update();return session
 end

 local controllers={}
 for i,mode in ipairs({'Trade','Coach','Progress','Help'}) do
  local host=Instance.new('Frame');host.Name=mode;host.Size=UDim2.fromOffset(390,844);host.Position=UDim2.fromOffset((i-1)*402+8,12);host.Parent=gui
  local c=UI.Mount(host);table.insert(controllers,c);c.State.CoachDismissed=true;c.State.Coach=mode=='Coach' and 1 or nil;c.State.Screen=mode=='Progress' and 'Progress' or 'Trade';c.State.Overlay=mode=='Help' and 'Help' or nil;c.Root.UIDiagnostics:Invoke('Render')
 end
 local hook=Instance.new('BindableFunction');hook.Name='Cleanup';hook.Parent=gui;hook.OnInvoke=function()for _,c in ipairs(controllers)do c:Destroy()end;shared:Destroy();server:Destroy();gui:Destroy()end
 return 'Four isolated previews mounted'
end,debug.traceback)
if not ok then if ctl then ctl:Destroy()end;gui:Destroy();shared:Destroy();server:Destroy();error(result)end
return result
