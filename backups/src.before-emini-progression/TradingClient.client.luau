local Players=game:GetService("Players")
local StarterGui=game:GetService("StarterGui")
local player=Players.LocalPlayer
local screen=script.Parent
local ui=require(game:GetService("ReplicatedStorage"):WaitForChild("MarketReign"):WaitForChild("TerminalUI"))
local controller=ui.Mount(screen)
-- Keep the Roblox system menu, but prevent avatar controls covering the trading workspace.
pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)end)
pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health,false)end)
pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)end)
task.spawn(function()
 local module=player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule",10)
 if module then pcall(function()require(module):GetControls():Disable()end)end
end)
screen.Destroying:Connect(function()controller:Destroy()end)
print("[Get Funded!] Native trading workspace ready. Server-authoritative simulated order book. Virtual funds only.")
