local fs=require('@lune/fs')
local luau=require('@lune/luau')
local failed=0
for _,file in ipairs(fs.readDir('src')) do
 if file:match('%.luau$') then
  local ok,err=pcall(luau.compile,fs.readFile('src/'..file))
  if not ok then failed+=1;print(file..': '..tostring(err)) end
 end
end
assert(failed==0,tostring(failed)..' sources failed compilation')
print('All sources compile')
