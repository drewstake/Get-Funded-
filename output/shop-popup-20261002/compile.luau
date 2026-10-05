local fs=require("@lune/fs")
local luau=require("@lune/luau")
for _,path in ipairs({"src/TerminalUI.luau","src/ShopView.luau"})do
 luau.compile(fs.readFile(path));print("Compiled "..path)
end
