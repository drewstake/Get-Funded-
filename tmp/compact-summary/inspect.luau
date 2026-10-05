local fs=require('@lune/fs')
local r=require('@lune/roblox')
local g=r.deserializePlace(fs.readFile('Get Funded!.rbxl'))
local baseline=fs.readFile('backups/compact-summary-20261001/TerminalUI.luau')
local function clean(s)return(s:gsub('\r\n','\n'):gsub('%s+$',''))end
print('Stored source matches baseline',clean(g.ReplicatedStorage.MarketReign.TerminalUI.Source)==clean(baseline))
local c=g.StarterGui.MarketReign.Workspace.Canvas
for _,name in ipairs({'AccountSummary','Chart','OrderTicket','Activity'})do
 local v=c:FindFirstChild(name)
 print(name,v and tostring(v.Position),v and tostring(v.Size))
end
