-- Lossless execution state, including FIFO identity and the participants' next random draw.
local Engine=require(script.Parent.MarketEngine)
local Participants=require(script.Parent.Participants)
local TradeStats=require(script.Parent.TradeStats)
local Http=game:GetService("HttpService")
local Encoding=game:GetService("EncodingService")
-- Version 3 introduces E-minis, retained close-only micro books and equity-only failure.
-- Version 4 adds armed stop entry orders, which wait off the order book. An older build would
-- rest them as limits, so it must fail closed on V4. V1-V3 are read unchanged.
-- Version 5 executes player orders off the order book against a saved house counterparty account. An older
-- build would rest player limits in the book again and liquidate the house as a bot, so it fails closed on V5.
-- V1-V4 restore unchanged; player limits they saved in the book come back off-book (see Restore).
-- V6 permanently separates tier access, account instances and Shop receipts. Older writers must
-- refuse it, otherwise they could reset permanent entitlements or spend the wallet twice.
local Checkpoint={Version=6,Readable={[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true}}
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
 local legacy=saved.Contracts.MES~=nil and saved.Contracts.ES==nil
 assert(#saved.ContractOrder==(legacy and 4 or (#current.ContractOrder+(saved.Contracts.MES and 4 or 0))),"Saved instruments differ from configuration")
 local expected=clone(legacy and current.LegacyOrder or current.ContractOrder)
 if not legacy and saved.Contracts.MES then for _,key in ipairs(current.LegacyOrder) do table.insert(expected,key) end end
 for index,key in ipairs(saved.ContractOrder)do
  local a,b=saved.Contracts[key],current.Contracts[key] or current.LegacyContracts[key]
  assert(expected[index]==key and b and a and a.Tick==b.Tick and a.Multiplier==b.Multiplier,"Saved contract specification changed: "..key)
 end
 assert(#saved.Timeframes==#current.Timeframes,"Saved timeframes differ")
 for i,tf in ipairs(current.Timeframes)do assert(saved.Timeframes[i][1]==tf[1]and saved.Timeframes[i][2]==tf[2],"Saved timeframe changed")end
 return legacy
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
 local migrateMicros=compatible(snapshot.Config,currentConfig)
 -- Preserve the saved simulation configuration for exact continuation; presentation cadence may change.
 local config=clone(snapshot.Config)
 config.DailyLossLimit=nil
 config.LegacyOrder=clone(currentConfig.LegacyOrder) config.LegacyContracts=clone(currentConfig.LegacyContracts)
 config.LegacyToCurrent=clone(currentConfig.LegacyToCurrent)
 for _,key in ipairs(config.LegacyOrder) do if config.Contracts[key] then config.Contracts[key].CloseOnly=true end end
 if migrateMicros then
  config.ContractOrder=clone(currentConfig.ContractOrder)
  for _,key in ipairs(currentConfig.LegacyOrder) do table.insert(config.ContractOrder,key) end
  for _,key in ipairs(currentConfig.ContractOrder) do config.Contracts[key]=clone(currentConfig.Contracts[key]) end
  -- Start the new books near the saved market, without relabelling historical executions or volume.
  for old,key in pairs(currentConfig.LegacyToCurrent) do
   local b=snapshot.Engine.Books[old]
   config.Contracts[key].Last=(b.Last or b.Reference)*config.Contracts[old].Tick
  end
 end
 -- MaxCandles only bounds chart history (matching never reads candles), so a restored world adopts the current limit.
 for _,key in ipairs({"BroadcastSeconds","SimulationSpeed","MaxCatchupSteps","MaxCandles","MaxPlayerQuantity","MaxPlayerInventory","MaxPlayerOrders"})do config[key]=currentConfig[key]end
 -- Simulated margin is buying-power policy; contract economics and all saved ledgers stay intact.
 for key,spec in pairs(config.Contracts) do
  local current=currentConfig.Contracts[key] or currentConfig.LegacyContracts[key]
  if current then spec.Margin=current.Margin end
 end
 local data=snapshot.Engine local engine=Engine.new(config,data.Seed)
 for _,key in ipairs({"Time","Step","NextOrder","NextTrade","TotalVolume","TradeHash","PendingStops"})do engine[key]=clone(data[key])end
 for _,a in ipairs(data.Accounts)do
  local account=clone(a);account.OpenOrders={}
  account.LossLimit=account.Base
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
  prior=o.Id engine.Orders[o.Id]=o engine.Accounts[o.Owner].OpenOrders[o.Id]=true
  -- Armed stop entries and player limits are not book liquidity; the engine rebuilds both indexes from
  -- Orders. Only participant orders rest in the book, so saved player limits migrate off-book here.
  if o.Type~="Stop" and not engine.Accounts[o.Owner].Player then engine:_rest(engine.Books[o.Contract],o) end
 end
 local population=setmetatable({Engine=engine,Config=config},Participants)
 for key,value in pairs(snapshot.Population)do if key~="RandomState"then population[key]=clone(value)end end
 population.Random=Participants.RNG.new(1);population.Random.State=snapshot.Population.RandomState
 assert(type(population.Random.State)=="number"and population.Random.State>0 and population.Random.State<2147483647,"Invalid saved random state")
 for _,agent in ipairs(population.Agents)do assert(engine.Accounts[agent.Id],"Saved participant account missing")end
 if snapshot.Version<3 then
  local currentAccounts={}
  for _,profile in pairs(engine.Profiles) do for _,entry in pairs(profile.Tiers) do if entry.Account then currentAccounts[entry.Account]=true end end end
  for _,profile in pairs(engine.Profiles) do for _,id in ipairs(profile.Ledger) do if not currentAccounts[id] then engine.Accounts[id].Retired=true end end end
  for _,id in ipairs(engine.AccountOrder) do
   local a=engine.Accounts[id]
   if a.Player and not a.Retired and engine:Summary(a).Equity>0 then
    a.Locked=false a.Liquidating=nil
    for _,p in pairs(a.Positions) do if p.Triggered=="Risk liquidation" then p.Triggered=nil end end
   end
   if a.Player then
    for orderId in pairs(clone(a.OpenOrders)) do
     local o=engine.Orders[orderId]
     if config.Contracts[o.Contract].CloseOnly and not o.ReduceOnly then engine:Cancel(id,orderId) end
    end
   end
  end
 end
 if migrateMicros then for _,key in ipairs(currentConfig.ContractOrder) do population:AddMarket(key) end end
 -- Lifetime trading stats (no format change): rebuilt once from saved history for older accounts,
 -- reconciled against the ledger for all others. Idempotent across repeated restores.
 local now=os.time()
 for _,id in ipairs(engine.AccountOrder) do local a=engine.Accounts[id] if a.Player then TradeStats.Reconcile(engine,a,now) end end
 engine:Audit()
 return engine,population
end
-- The reader's decompressed-size bound. It is unchanged, so every checkpoint that opened before still opens.
-- Encode refuses anything larger before compressing, so the writer and the reader enforce one bound: every
-- checkpoint the writer accepts decodes, and every save that decodes today can be written again.
Checkpoint.MaxDecodedBytes=32000000
-- The reader's header rules, shared by Encode (before a commit) and Decode (on restore).
function Checkpoint.Check(record,maxDecodedBytes)
 assert(type(record)=="table" and Checkpoint.Readable[record.Version] and record.Codec=="zstd-base64" and type(record.Payload)=="string","Invalid checkpoint encoding")
 local compressed=Encoding:Base64Decode(buffer.fromstring(record.Payload))
 local bytes=Encoding:GetDecompressedBufferSize(compressed,Enum.CompressionAlgorithm.Zstd)
 assert(bytes and bytes==record.RawBytes and bytes<=math.min(maxDecodedBytes or Checkpoint.MaxDecodedBytes,Checkpoint.MaxDecodedBytes),"Invalid checkpoint length")
 return compressed,bytes
end
function Checkpoint.Encode(snapshot,maxRawBytes)
 local raw=Http:JSONEncode(snapshot)
 local limit=math.min(maxRawBytes or Checkpoint.MaxDecodedBytes,Checkpoint.MaxDecodedBytes)
 if #raw>limit then error(string.format("Exchange checkpoint is too large (%d raw bytes, limit %d); trading paused to protect saved state",#raw,limit),2) end
 local compressed=Encoding:CompressBuffer(buffer.fromstring(raw),Enum.CompressionAlgorithm.Zstd,3)
 local record={Version=Checkpoint.Version,Codec="zstd-base64",RawBytes=#raw,
  Digest=digest(raw),
  Payload=buffer.tostring(Encoding:Base64Encode(compressed))}
 Checkpoint.Check(record,limit)
 return record
end
function Checkpoint.Decode(record,maxDecodedBytes)
 local compressed=Checkpoint.Check(record,maxDecodedBytes)
 local raw=buffer.tostring(Encoding:DecompressBuffer(compressed,Enum.CompressionAlgorithm.Zstd))
 assert(digest(raw)==record.Digest,"Checkpoint checksum failed")
 return Http:JSONDecode(raw)
end
return Checkpoint
