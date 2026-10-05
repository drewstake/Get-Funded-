local fs=require("@lune/fs")
local luau=require("@lune/luau")
for _,file in ipairs({"src/TerminalUI.luau","tools/ValidatePlayerCopyFlow.luau","tools/ValidatePlayerCopy.luau"}) do
 luau.compile(fs.readFile(file));print("Compiled "..file)
end
