local fs=require('@lune/fs')
local r=require('@lune/roblox')
local g=r.deserializePlace(fs.readFile('Get Funded!.rbxl'))
for _,v in ipairs(g.StarterGui:GetChildren())do
 print(v.Name,v.ClassName)
 for _,x in ipairs(v:GetChildren())do print(' ',x.Name,x.ClassName)end
end
print('Total',#g:GetDescendants())
