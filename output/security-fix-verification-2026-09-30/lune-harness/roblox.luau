-- Minimal Roblox API shim for running the Get Funded! server modules under Lune.
-- Isolated: no network, no DataStores, no Roblox services. Test-only.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local lunetask=require("@lune/task")

local M={}

---------------------------------------------------------------- JSON (Roblox-like, strict)
local function encodeString(s)
 return '"'..s:gsub('[%c"\\]',function(c)
  if c=='"' then return '\\"' elseif c=="\\" then return "\\\\" elseif c=="\n" then return "\\n"
  elseif c=="\r" then return "\\r" elseif c=="\t" then return "\\t" end
  return string.format("\\u%04x",string.byte(c))
 end)..'"'
end
local function encodeValue(v,out)
 local t=type(v)
 if t=="nil" then table.insert(out,"null")
 elseif t=="boolean" then table.insert(out,v and "true" or "false")
 elseif t=="number" then
  if v~=v or v==math.huge or v==-math.huge then error("JSONEncode: non-finite number") end
  if v%1==0 and math.abs(v)<2^53 then table.insert(out,string.format("%d",v))
  else table.insert(out,string.format("%.17g",v)) end
 elseif t=="string" then table.insert(out,encodeString(v))
 elseif t=="table" then
  local n=#v local count=0 for _ in pairs(v) do count+=1 end
  if count==0 then table.insert(out,"[]") return end
  if n>0 then
   if count~=n then error("JSONEncode: mixed or sparse table (would lose data)") end
   table.insert(out,"[")
   for i=1,n do if i>1 then table.insert(out,",") end encodeValue(v[i],out) end
   table.insert(out,"]")
  else
   table.insert(out,"{") local first=true
   local keys={} for k in pairs(v) do
    if type(k)~="string" then error("JSONEncode: non-string dictionary key "..tostring(k)) end
    table.insert(keys,k)
   end
   table.sort(keys)
   for _,k in ipairs(keys) do
    if not first then table.insert(out,",") end first=false
    table.insert(out,encodeString(k)) table.insert(out,":") encodeValue(v[k],out)
   end
   table.insert(out,"}")
  end
 else error("JSONEncode: unsupported type "..t) end
end
function M.JSONEncode(v) local out={} encodeValue(v,out) return table.concat(out) end
-- Exact decoder: tonumber() on each literal so doubles round-trip bit-for-bit (serde_json does not).
local escapes={['"']='"',["\\"]="\\",["/"]="/",b="\b",f="\f",n="\n",r="\r",t="\t"}
function M.JSONDecode(s)
 local pos=1
 local function ws() pos=string.find(s,"[^ \t\r\n]",pos) or #s+1 end
 local value
 local function str()
  local parts={} pos+=1
  while true do
   local i=string.find(s,'["\\]',pos)
   assert(i,"JSONDecode: unterminated string")
   table.insert(parts,string.sub(s,pos,i-1))
   if string.sub(s,i,i)=='"' then pos=i+1 break end
   local c=string.sub(s,i+1,i+1)
   if c=="u" then
    local code=tonumber(string.sub(s,i+2,i+5),16) table.insert(parts,utf8.char(code)) pos=i+6
   else table.insert(parts,assert(escapes[c],"JSONDecode: bad escape")) pos=i+2 end
  end
  return table.concat(parts)
 end
 function value()
  ws()
  local c=string.sub(s,pos,pos)
  if c=="{" then
   local t={} pos+=1 ws()
   if string.sub(s,pos,pos)=="}" then pos+=1 return t end
   while true do
    ws() assert(string.sub(s,pos,pos)=='"',"JSONDecode: expected key") local k=str()
    ws() assert(string.sub(s,pos,pos)==":","JSONDecode: expected colon") pos+=1
    t[k]=value() ws()
    local d=string.sub(s,pos,pos) pos+=1
    if d=="}" then return t end
    assert(d==",","JSONDecode: expected comma")
   end
  elseif c=="[" then
   local t={} pos+=1 ws()
   if string.sub(s,pos,pos)=="]" then pos+=1 return t end
   local n=0
   while true do
    n+=1 t[n]=value() ws()
    local d=string.sub(s,pos,pos) pos+=1
    if d=="]" then return t end
    assert(d==",","JSONDecode: expected comma")
   end
  elseif c=='"' then return str()
  elseif c=="t" then pos+=4 return true
  elseif c=="f" then pos+=5 return false
  elseif c=="n" then pos+=4 return nil
  else
   local a,b=string.find(s,"^-?%d+%.?%d*[eE]?[-+]?%d*",pos)
   assert(a,"JSONDecode: unexpected character at "..pos)
   pos=b+1 return (assert(tonumber(string.sub(s,a,b)),"JSONDecode: bad number"))
  end
 end
 local result=value() ws()
 assert(pos>#s,"JSONDecode: trailing data")
 return result
end

---------------------------------------------------------------- base64 over buffers
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local enc,dec={},{}
for i=1,64 do enc[i-1]=string.byte(alphabet,i) dec[string.byte(alphabet,i)]=i-1 end
local function b64encode(b)
 local n=buffer.len(b) local out=buffer.create(math.ceil(n/3)*4) local o=0
 for i=0,n-1,3 do
  local a=buffer.readu8(b,i) local c1=i+1<n and buffer.readu8(b,i+1) or 0 local c2=i+2<n and buffer.readu8(b,i+2) or 0
  local x=a*65536+c1*256+c2
  buffer.writeu8(out,o,enc[bit32.rshift(x,18)]) buffer.writeu8(out,o+1,enc[bit32.band(bit32.rshift(x,12),63)])
  buffer.writeu8(out,o+2,i+1<n and enc[bit32.band(bit32.rshift(x,6),63)] or 61)
  buffer.writeu8(out,o+3,i+2<n and enc[bit32.band(x,63)] or 61)
  o+=4
 end
 return out
end
local function b64decode(b)
 local n=buffer.len(b) assert(n%4==0,"Invalid base64")
 local pad=0 if n>0 and buffer.readu8(b,n-1)==61 then pad+=1 end if n>1 and buffer.readu8(b,n-2)==61 then pad+=1 end
 local out=buffer.create(n/4*3-pad) local o=0
 for i=0,n-1,4 do
  local v={} for j=0,3 do local c=buffer.readu8(b,i+j) v[j]=c==61 and 0 or assert(dec[c],"Invalid base64") end
  local x=v[0]*262144+v[1]*4096+v[2]*64+v[3]
  if o<buffer.len(out) then buffer.writeu8(out,o,bit32.rshift(x,16)) end
  if o+1<buffer.len(out) then buffer.writeu8(out,o+1,bit32.band(bit32.rshift(x,8),255)) end
  if o+2<buffer.len(out) then buffer.writeu8(out,o+2,bit32.band(x,255)) end
  o+=3
 end
 return out
end

---------------------------------------------------------------- services
local function anything(path)
 return setmetatable({__path=path},{__index=function(t,k) local v=anything(path.."."..tostring(k)) rawset(t,k,v) return v end,
  __call=function() return anything(path.."()") end})
end
local Enum=anything("Enum")
Enum.HashAlgorithm={Sha256="Sha256"} Enum.CompressionAlgorithm={Zstd="Zstd"}
M.Enum=Enum
local guid=0
local Http={}
function Http:JSONEncode(v) return M.JSONEncode(v) end
function Http:JSONDecode(s) return M.JSONDecode(s) end
function Http:GenerateGUID(wrap) guid+=1 local s=string.format("%08x-0000-4000-8000-%012x",math.random(0,0x7fffffff),guid) return wrap and "{"..s.."}" or s end
local Encoding={}
function Encoding:ComputeStringHash(s,alg)
 assert(alg==Enum.HashAlgorithm.Sha256)
 local hex=serde.hash("sha256",s)
 return (hex:gsub("%x%x",function(h) return string.char(tonumber(h,16)) end))
end
function Encoding:CompressBuffer(b,alg,level)
 assert(alg==Enum.CompressionAlgorithm.Zstd)
 return buffer.fromstring(serde.compress("zstd",buffer.tostring(b),level))
end
function Encoding:DecompressBuffer(b,alg)
 assert(alg==Enum.CompressionAlgorithm.Zstd)
 return buffer.fromstring(serde.decompress("zstd",buffer.tostring(b)))
end
function Encoding:GetDecompressedBufferSize(b,alg)
 -- Test shim: the real API reads the zstd frame header; here the frame is decoded to measure it.
 local ok,raw=pcall(serde.decompress,"zstd",buffer.tostring(b))
 return ok and #raw or nil
end
function Encoding:Base64Encode(b) return b64encode(b) end
function Encoding:Base64Decode(b) return b64decode(b) end
M.Studio=true
local Run={}
function Run:IsStudio() return M.Studio end
local function inert(name)
 return setmetatable({Name=name},{__index=function(t,k) return function() return nil end end})
end

---------------------------------------------------------------- module tree
local Ref={} Ref.__index=function(self,k)
 local kids=rawget(self,"__children")
 if kids and kids[k] then return kids[k] end
 return Ref[k]
end
function Ref:WaitForChild(name) return self.__children[name] end
function Ref:FindFirstChild(name) return self.__children[name] end
function Ref:GetFullName() return self.__path end
local function folder(name,parent)
 local f=setmetatable({Name=name,Parent=parent,__children={},__path=(parent and parent.__path.."." or "")..name},Ref)
 if parent then parent.__children[name]=f end
 return f
end
local cache={} local loading={}
local game=folder("game",nil)
M.game=game
local services={HttpService=Http,EncodingService=Encoding,RunService=Run}
function game:GetService(name)
 if services[name] then return services[name] end
 if game.__children[name] then return game.__children[name] end
 services[name]=inert(name) return services[name]
end
game.PlaceId=0 game.JobId="lune-test-job" game.PrivateServerId=""
local rs=folder("ReplicatedStorage",game) local sss=folder("ServerScriptService",game)
M.Shared=folder("MarketReign",rs) M.Server=folder("MarketReign",sss)
local function robloxRequire(ref)
 if type(ref)=="string" then return require(ref) end
 assert(type(ref)=="table" and rawget(ref,"__file"),"require: not a ModuleScript reference "..tostring(ref and rawget(ref,"__path")))
 if cache[ref] ~= nil then return cache[ref] end
 assert(not loading[ref],"Recursive require "..ref.__path)
 loading[ref]=true
 local source=fs.readFile(ref.__file)
 local env={script=ref,game=game,require=robloxRequire,Enum=Enum,task=lunetask,warn=M.warn,
  Instance={new=function(class) return inert(class) end},debug=debug,typeof=M.typeof,
  Color3=anything("Color3"),UDim2=anything("UDim2"),UDim=anything("UDim"),Vector2=anything("Vector2"),ColorSequence=anything("ColorSequence"),
  NumberSequence=anything("NumberSequence"),TweenInfo=anything("TweenInfo"),Rect=anything("Rect")}
 local ok,result=pcall(function() return luau.load(source,{debugName=ref.__path,environment=env})() end)
 loading[ref]=nil
 if not ok then error(result,0) end
 cache[ref]=result
 return result
end
M.require=robloxRequire
function M.typeof(v) if type(v)=="table" and getmetatable(v)==Ref then return "Instance" end return typeof(v) end
function M.module(parent,name,file)
 local m=setmetatable({Name=name,Parent=parent,__file=file,__path=parent.__path.."."..name,__children={}},Ref)
 parent.__children[name]=m
 return m
end
M.warnings={}
function M.warn(...) local parts={} for i=1,select("#",...) do table.insert(parts,tostring(select(i,...))) end table.insert(M.warnings,table.concat(parts," ")) end
function M.reset() cache={} loading={} end
return M
