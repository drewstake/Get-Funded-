-- Lossless execution state, including FIFO identity and the participants' next random draw.
local Engine=require(script.Parent.MarketEngine)
local Participants=require(script.Parent.Participants)
local Http=game:GetService("HttpService")
local Encoding=game:GetService("EncodingService")
-- Version 2 adds funded-account profiles (onboarding, ladder, copy settings). Version 1 checkpoints
-- still restore; their players are migrated from the restored practice accounts on join.
-- Older servers cannot read version 2, so they fail closed instead of saving without profiles.
local Checkpoint={Version=2,Readable={[1]=true,[2]=true}}
local function digest(raw)
 local bytes=Encoding:ComputeStringHash(raw,Enum.HashAlgorithm.Sha256)
 return (bytes:gsub(".",function(c)return string.format("%02x",string.byte(c))end))
end
local function clone(value)
 if type(value)~="table"then return value end
 local result={} for key,v in pairs(value)do result[key]=clone(v)end return result
end
local function compatible(saved,current)
 assert(saved.StepSeconds==current.StepSeconds,"Saved market step size differs from configuration")
 assert(#saved.ContractOrder==#current.ContractOrder,"Saved instruments differ from configuration")
 for index,key in ipairs(current.ContractOrder)do
  local a,b=saved.Contracts[key],current.Contracts[key]
  assert(saved.ContractOrder[index]==key and a and a.Tick==b.Tick and a.Multiplier==b.Multiplier and a.Margin==b.Margin,"Saved contract specification changed: "..key)
 end
 assert(#saved.Timeframes==#current.Timeframes,"Saved timeframes differ")
 for i,tf in ipairs(current.Timeframes)do assert(saved.Timeframes[i][1]==tf[1]and saved.Timeframes[i][2]==tf[2],"Saved timeframe changed")end
end
function Checkpoint.Capture(engine,population)
 local e={Accounts={},Books={},Orders={},Profiles=clone(engine.Profiles or {})}
 for _,key in ipairs({"Seed","Time","Step","NextOrder","NextTrade","TotalVolume","TradeHash","PendingStops"})do e[key]=clone(engine[key])end
 for _,id in ipairs(engine.AccountOrder)do
  local a=clone(engine.Accounts[id]);a.OpenOrders=nil
  -- Bot histories are display-only; balances, cash ledger and inventory are retained exactly.
  if not a.Player then a.History={} a.Fills={}end
  table.insert(e.Accounts,a)
 end
 for _,key in ipairs(engine.Config.ContractOrder)do
  local book={}
  for field,value in pairs(engine.Books[key])do if field~="Bids"and field~="Asks"and field~="Spec"then book[field]=clone(value)end end
  e.Books[key]=book
 end
 local ids={}for id in pairs(engine.Orders)do table.insert(ids,id)end table.sort(ids)
 for _,id in ipairs(ids)do table.insert(e.Orders,clone(engine.Orders[id]))end
 local p={RandomState=population.Random.State}
 for key,value in pairs(population)do if key~="Engine"and key~="Config"and key~="Random"then p[key]=clone(value)end end
 return {Version=Checkpoint.Version,Config=clone(engine.Config),Engine=e,Population=p}
end
function Checkpoint.Restore(snapshot,currentConfig)
 assert(type(snapshot)=="table"and Checkpoint.Readable[snapshot.Version],"Unsupported saved market format")
 compatible(snapshot.Config,currentConfig)
 -- Preserve the saved simulation configuration for exact continuation; presentation cadence may change.
 local config=clone(snapshot.Config)
 for _,key in ipairs({"BroadcastSeconds","SimulationSpeed","MaxCatchupSteps"})do config[key]=currentConfig[key]end
 local data=snapshot.Engine local engine=Engine.new(config,data.Seed)
 for _,key in ipairs({"Time","Step","NextOrder","NextTrade","TotalVolume","TradeHash","PendingStops"})do engine[key]=clone(data[key])end
 for _,a in ipairs(data.Accounts)do
  local account=clone(a);account.OpenOrders={}
  assert(not engine.Accounts[a.Id],"Duplicate saved account")
  engine.Accounts[a.Id]=account table.insert(engine.AccountOrder,a.Id)
 end
 for key,fields in pairs(data.Books)do for name,value in pairs(fields)do engine.Books[key][name]=clone(value)end end
 engine.Profiles=clone(data.Profiles or {})
 for uid,profile in pairs(engine.Profiles)do
  assert(type(uid)=="string"and type(profile)=="table"and type(profile.Tiers)=="table"and type(profile.Ledger)=="table","Invalid saved funded profile")
  for _,id in ipairs(profile.Ledger)do assert(engine.Accounts[id],"Saved funded account missing")end
 end
 local prior=0
 for _,order in ipairs(data.Orders)do
  local o=clone(order)
  assert(o.Id>prior and o.Remaining>0 and engine.Accounts[o.Owner]and engine.Books[o.Contract],"Invalid saved resting order")
  prior=o.Id engine.Orders[o.Id]=o engine.Accounts[o.Owner].OpenOrders[o.Id]=true engine:_rest(engine.Books[o.Contract],o)
 end
 local population=setmetatable({Engine=engine,Config=config},Participants)
 for key,value in pairs(snapshot.Population)do if key~="RandomState"then population[key]=clone(value)end end
 population.Random=Participants.RNG.new(1);population.Random.State=snapshot.Population.RandomState
 assert(type(population.Random.State)=="number"and population.Random.State>0 and population.Random.State<2147483647,"Invalid saved random state")
 for _,agent in ipairs(population.Agents)do assert(engine.Accounts[agent.Id],"Saved participant account missing")end
 engine:Audit()
 return engine,population
end
function Checkpoint.Encode(snapshot)
 local raw=Http:JSONEncode(snapshot)
 local compressed=Encoding:CompressBuffer(buffer.fromstring(raw),Enum.CompressionAlgorithm.Zstd,3)
 return {Version=Checkpoint.Version,Codec="zstd-base64",RawBytes=#raw,
  Digest=digest(raw),
  Payload=buffer.tostring(Encoding:Base64Encode(compressed))}
end
function Checkpoint.Decode(record)
 assert(Checkpoint.Readable[record.Version] and record.Codec=="zstd-base64","Invalid checkpoint encoding")
 local compressed=Encoding:Base64Decode(buffer.fromstring(record.Payload))
 local bytes=Encoding:GetDecompressedBufferSize(compressed,Enum.CompressionAlgorithm.Zstd)
 assert(bytes and bytes==record.RawBytes and bytes<=32000000,"Invalid checkpoint length")
 local raw=buffer.tostring(Encoding:DecompressBuffer(compressed,Enum.CompressionAlgorithm.Zstd))
 assert(digest(raw)==record.Digest,"Checkpoint checksum failed")
 return Http:JSONDecode(raw)
end
return Checkpoint
