-- Run in Studio CLIENT context during Play. Isolated UI interaction fixture; no remote orders.
-- Call PlayerGui.AfterHoursUITest.Diagnostics:Invoke("Cleanup") before finishing.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient(),"Studio client only")
local playerGui=game.Players.LocalPlayer.PlayerGui
assert(not playerGui:FindFirstChild("AfterHoursUITest"),"Clean up the previous fixture first")
local live=playerGui.MarketReign
local shared=game.ReplicatedStorage.MarketReign:Clone()
shared.Name="AfterHoursUITestShared";shared.Parent=game.ReplicatedStorage
local mock=[==[
local originalNew=Market.New
function Market.New(base)
 local fixture={Quotes={},CandlesBySeries={},Time=2400,Step=1}
 for _,key in ipairs(Config.ContractOrder)do
  local c=Config.Contracts[key]
  fixture.Quotes[key]={Last=c.Last,Open=c.Last-4*c.Tick,Bid=c.Last-c.Tick,Ask=c.Last+c.Tick,Spread=2*c.Tick,Volume=200}
  for _,tf in ipairs(Config.Timeframes)do
   local candles={}
   for i=1,40 do
    local price=c.Last+math.floor(math.sin(i*.5)*8)*c.Tick
    candles[i]={Time=(i-1)*tf[2],Open=price,Close=price+(i%2==0 and 2 or -2)*c.Tick,High=price+4*c.Tick,Low=price-4*c.Tick,Volume=10+i}
   end
   fixture.CandlesBySeries[key..":"..tf[1]]=candles
  end
 end
 local self=originalNew(base,true,fixture)
 self.Preview=false;self.Ready=true;self.CanTrade=true;self.PersistenceMode="Test";self.ConnectionStatus="ISOLATED UI TEST"
 self.TestLog={};self.Regime="UI fixture"
 function self:Send(action,req)
  self.NextId+=1;req=req or{};req.Action=action
  table.insert(self.TestLog,table.clone(req))
  if action=="Place"then
   local c=Config.Contracts[req.Contract]
   if req.Type=="Limit"then
    table.insert(self.Orders,{Id=self.NextId,Contract=req.Contract,Kind="Limit",Quantity=req.Quantity,Price=req.Price,Status="Working"})
   else
    self.Positions[req.Contract]={Id=self.NextId,Contract=req.Contract,Direction=req.Direction,Quantity=req.Quantity,Entry=c.Last,Unrealized=25,
     Stop=req.StopTicks and c.Last-req.Direction*req.StopTicks*c.Tick,Target=req.TargetTicks and c.Last+req.Direction*req.TargetTicks*c.Tick}
   end
  elseif action=="Close"then self.Positions[req.Contract]=nil
  elseif action=="Cancel"then
   for i,o in ipairs(self.Orders)do if o.Id==req.OrderId then table.remove(self.Orders,i);break end end
  elseif action=="AmendProtection"then self.Positions[req.Contract][req.Protection]=req.Price
  end
  local count=0 for _ in pairs(self.Positions)do count+=1 end
  self.SummaryData.Count=count;self.SummaryData.Unrealized=count*25;self.SummaryData.Equity=self.SummaryData.Balance+count*25
  task.defer(function()self.Changed:Fire()end)
  return true,"Isolated UI test · "..action,"Positions",self.NextId
 end
 Market.TestSession=self
 return self
end
]==]
shared.MarketClient.Source=shared.MarketClient.Source:gsub("return Market%s*$",function()return mock.."\nreturn Market"end)
local gui=Instance.new("ScreenGui");gui.Name="AfterHoursUITest";gui.DisplayOrder=100;gui.ResetOnSpawn=false;gui.Parent=playerGui
local controller=require(shared.TerminalUI).Mount(gui)
controller.Root.Size=UDim2.fromOffset(1440,900)
local market=require(shared.MarketClient)
local diagnostic=Instance.new("BindableFunction");diagnostic.Name="Diagnostics";diagnostic.Parent=gui
diagnostic.OnInvoke=function(command,a,b)
 if command=="Resize"then controller.Root.Size=UDim2.fromOffset(a,b);return true end
 if command=="Cleanup"then controller:Destroy();gui:Destroy();shared:Destroy();live.Enabled=true;return true end
 if command=="State"then
  return {UI=controller.State,Attributes=controller.Root:GetAttributes(),Requests=market.TestSession.TestLog,
   Positions=market.TestSession.Positions,Orders=market.TestSession.Orders,Summary=market.TestSession:Summary()}
 end
 if command=="Connectivity"then market.TestSession.CanTrade=a;market.TestSession.Changed:Fire();return true end
 error("Unknown fixture command")
end
live.Enabled=false
return {Gui=gui:GetFullName(),Diagnostics=diagnostic:GetFullName(),Notice="Isolated fixture. No remote requests or saved-account mutations."}
