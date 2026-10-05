local Players=game:GetService("Players")
local StarterGui=game:GetService("StarterGui")
local player=Players.LocalPlayer
local screen=script.Parent
local ui=require(game:GetService("ReplicatedStorage"):WaitForChild("MarketReign"):WaitForChild("TerminalUI"))
local controller=ui.Mount(screen)
-- Private replies for the server-owned /reset command. This remote has no server event handler.
local noticeConnection
task.spawn(function()
 local remote=game:GetService("ReplicatedStorage").MarketReign:WaitForChild("OwnerNotice")
 noticeConnection=remote.OnClientEvent:Connect(function(message)
  if type(message)~="string"then return end
  local channels=game:GetService("TextChatService"):FindFirstChild("TextChannels")
  local channel=channels and (channels:FindFirstChild("RBXSystem")or channels:FindFirstChild("RBXGeneral"))
  if channel then
   local safe=message:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
   channel:DisplaySystemMessage("[Get Funded!] "..safe)
  end
 end)
end)
-- Keep the Roblox system menu, but prevent avatar controls covering the trading workspace.
pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)end)
pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health,false)end)
pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)end)
task.spawn(function()
 local module=player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule",10)
 if module then pcall(function()require(module):GetControls():Disable()end)end
end)
screen.Destroying:Connect(function()if noticeConnection then noticeConnection:Disconnect()end;controller:Destroy()end)
print("[Get Funded!] Native trading workspace ready. Server-authoritative order book.")
