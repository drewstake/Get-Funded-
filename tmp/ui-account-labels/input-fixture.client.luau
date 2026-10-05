local shared=game.ReplicatedStorage:WaitForChild("AccountLabelInputShared")
local data=game.HttpService:JSONDecode(shared.Fixture.Value)
local player=game.Players.LocalPlayer
local gui=Instance.new("ScreenGui");gui.Name="AccountLabelInput";gui.IgnoreGuiInset=true;gui.Parent=player:WaitForChild("PlayerGui")
local main=gui.Parent:FindFirstChild("MarketReign");if main then main.Enabled=false end
local M=require(shared.MarketClient);local original=M.New
M.New=function()
 local s=original(nil,true,data.Snapshot)
 s.Preview=false;s.Ready=true;s.CanTrade=true;s.AccountKey=data.Portfolio.Active;s.AccountToken="UI fixture"
 s.Portfolio=data.Portfolio;s.Stats=data.Stats;s.SummaryData=data.Summary;s.StatsAt=1
 function s:Send(action,req)
  gui:SetAttribute("Sends",(gui:GetAttribute("Sends")or 0)+1)
  gui:SetAttribute("LastAction",action);gui:SetAttribute("LastRequest",game.HttpService:JSONEncode(req))
  return true,"Sent","Orders",gui:GetAttribute("Sends")
 end
 return s
end
local host=Instance.new("Frame");host.Name="Host";host.Size=UDim2.fromOffset(1440,900);host.Parent=gui
local ctl=require(shared.TerminalUI).Mount(host)
task.wait();ctl.State.Screen="Trade";ctl.State.Nav="Trade";ctl.State.Overlay="Copy";ctl.State.Toast=nil
ctl.Root.UIDiagnostics:Invoke("Render")
_G.AccountLabelInput=ctl
gui:SetAttribute("Ready",true)
