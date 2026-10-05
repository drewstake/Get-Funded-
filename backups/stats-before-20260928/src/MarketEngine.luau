-- Deterministic, server-only price/time priority exchange. Prices are integer ticks internally.
local Engine = {}
Engine.__index = Engine
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<1e12 end
local function integer(n) return finite(n) and n%1==0 end
local function sortedKeys(t)
 local keys={} for k in pairs(t) do table.insert(keys,k) end table.sort(keys) return keys
end
local function copy(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
function Engine.new(config, seed)
 local self=setmetatable({Config=config,Seed=seed,Time=0,Step=0,Books={},Accounts={},AccountOrder={},Orders={},OrderArchive={},
  NextOrder=0,NextTrade=0,Trades={},PendingStops={},TotalVolume=0,TradeHash=0},Engine)
 for _,key in ipairs(config.ContractOrder) do
  local c=config.Contracts[key]
  local candles={} for _,tf in ipairs(config.Timeframes) do candles[tf[1]]={} end
  self.Books[key]={Key=key,Spec=c,Bids={},Asks={},Last=nil,Open=nil,Reference=math.round(c.Last/c.Tick),Volume=0,
   Candles=candles,CandleVolume={},Recent={},Up=0,Down=0,Volatility=1}
 end
 return self
end
function Engine:AddAccount(id,base,limit,risk,isPlayer)
 if self.Accounts[id] then return self.Accounts[id] end
 local a={Id=id,Base=base,Balance=base,Realized=0,CashFlow=0,Positions={},OpenOrders={},History={},Fills={},
  Limit=limit,Risk=risk,Player=isPlayer==true,Revision=0,Locked=false,LossLimit=base}
 self.Accounts[id]=a table.insert(self.AccountOrder,id) return a
end
function Engine:Summary(a)
 local unrealized,count,margin=0,0,0
 for _,key in ipairs(self.Config.ContractOrder) do
  local b=self.Books[key] local p=a.Positions[key]
  if p then
   unrealized+=((b.Last or b.Reference)*b.Spec.Tick-p.Entry)*p.Quantity*p.Direction*b.Spec.Multiplier
   count+=1 margin+=p.Quantity*b.Spec.Margin
  end
 end
 -- Funded accounts liquidate on equity depletion; margin limits apply to new exposure.
 return {Balance=a.Balance,Equity=a.Balance+unrealized,Unrealized=unrealized,Session=a.Balance+unrealized-a.Base,
  Allowance=math.max(0,a.Balance+unrealized),Count=count,Margin=margin}
end
function Engine:Exposure(a,key,side,qty)
 local used,total=0,0
 for _,symbol in ipairs(self.Config.ContractOrder) do
  local p=a.Positions[symbol] local net=p and p.Quantity*p.Direction or 0
  local buy,sell=0,0
  for _,id in ipairs(sortedKeys(a.OpenOrders)) do
   local o=self.Orders[id]
   if o and not o.ReduceOnly and o.Contract==symbol then if o.Direction==1 then buy+=o.Remaining else sell+=o.Remaining end end
  end
  if symbol==key then if side==1 then buy+=qty else sell+=qty end end
  local worst=math.max(math.abs(net+buy),math.abs(net-sell))
  if worst>a.Limit then return false end
  total+=worst
  used+=worst*self.Books[symbol].Spec.Margin
 end
 return (not a.Player or total<=math.min(a.Limit,self.Config.MaxPlayerInventory)) and used<=math.max(0,self:Summary(a).Equity)*a.Risk
end
-- Maximum additional order in this direction, reserving worst-case independent entry fills.
-- Reduce-only exits cannot create exposure and do not consume entry capacity.
function Engine:OrderCapacity(a,key,side,stopTicks,excludeOrder)
 local equity=math.max(0,self:Summary(a).Equity)
 local otherMargin,otherCount,net,same,opposite=0,0,0,0,0
 for _,symbol in ipairs(self.Config.ContractOrder) do
  local p=a.Positions[symbol] local position=p and p.Quantity*p.Direction or 0
  local buy,sell=0,0
  for id in pairs(a.OpenOrders) do
   local o=self.Orders[id]
   if id~=excludeOrder and o and not o.ReduceOnly and o.Contract==symbol then
    if o.Direction==1 then buy+=o.Remaining else sell+=o.Remaining end
   end
  end
  if symbol==key then net=position;same=side==1 and buy or sell;opposite=side==1 and sell or buy
  else
   local worst=math.max(math.abs(position+buy),math.abs(position-sell))
   otherCount+=worst;otherMargin+=worst*self.Books[symbol].Spec.Margin
  end
 end
 local spec=self.Books[key].Spec
 local inventory=math.min(a.Limit,self.Config.MaxPlayerInventory)-otherCount
 local margin=math.floor((equity*a.Risk-otherMargin)/spec.Margin+1e-9)
 local allowed=math.min(inventory,margin)
 local reason=margin<inventory and "Insufficient simulated margin after existing positions and working orders." or ("Account contract limit ("..math.min(a.Limit,self.Config.MaxPlayerInventory).." total), including working orders.")
 if math.abs(net-side*opposite)>allowed then return 0,reason end
 local maximum=math.max(0,math.floor(allowed-side*net-same))
 if maximum>self.Config.MaxPlayerQuantity then maximum=self.Config.MaxPlayerQuantity;reason="Per-order quantity limit." end
 -- Stop distance describes the exit, not buying power. Equity depletion liquidates
 -- a funded account even when its selected stop is farther away.
 return maximum,reason
end
function Engine:CapacityMessage(a,key,side,stopTicks)
 local maximum,reason=self:OrderCapacity(a,key,side,stopTicks)
 return reason.." Maximum currently available: "..maximum.." "..key.."."
end
function Engine:_retire(o,status)
 o.Status=status self.Accounts[o.Owner].OpenOrders[o.Id]=nil
 self.Orders[o.Id]=nil
 table.insert(self.OrderArchive,o)
 if #self.OrderArchive>self.Config.MaxOrderHistory then table.remove(self.OrderArchive,1) end
end
function Engine:Cancel(owner,id)
 local o=self.Orders[id]
 if not o or o.Owner~=owner then return false,"Order is no longer working." end
 o.Cancelled+=o.Remaining o.Remaining=0 self:_retire(o,"Cancelled")
 self.Accounts[owner].Revision+=1
 self:_cleanBook(self.Books[o.Contract])
 return true,"Simulated order cancelled."
end
function Engine:CancelAll(owner,key)
 local a=self.Accounts[owner]
 for _,id in ipairs(sortedKeys(a.OpenOrders)) do
  local o=self.Orders[id] if o and (not key or o.Contract==key) then self:Cancel(owner,id) end
 end
end
function Engine:_cleanBook(b)
 for _,side in ipairs({b.Bids,b.Asks}) do
  for i=#side,1,-1 do
   local level=side[i] local quantity=0
   for j=#level.Orders,1,-1 do
    local o=level.Orders[j]
    if o.Remaining<=0 then table.remove(level.Orders,j) else quantity+=o.Remaining end
   end
   level.Quantity=quantity if quantity==0 then table.remove(side,i) end
  end
 end
end
function Engine:_rest(b,o)
 local levels=o.Direction==1 and b.Bids or b.Asks
 local at=#levels+1
 for i,l in ipairs(levels) do
  if l.Price==o.Price then table.insert(l.Orders,o) l.Quantity+=o.Remaining return end
  if (o.Price-l.Price)*o.Direction>0 then at=i break end
 end
 table.insert(levels,at,{Price=o.Price,Quantity=o.Remaining,Orders={o}})
end
function Engine:_fillAccount(o,price,qty,tradeId)
 local a=self.Accounts[o.Owner] local b=self.Books[o.Contract] local p=a.Positions[o.Contract]
 local side=o.Direction local oldNet=p and p.Quantity*p.Direction or 0 local delta=side*qty
 a.CashFlow-=price*delta*b.Spec.Multiplier -- double-entry notional audit ledger; not spendable futures cash
 local realized=0
 if p and oldNet*delta<0 then
  local closed=math.min(math.abs(oldNet),qty)
  realized=(price-p.Entry)*closed*p.Direction*b.Spec.Multiplier
  a.Balance+=realized a.Realized+=realized
  -- Persist eligibility independently of the bounded display history, including break-even closes.
  a.CompletedTrades=(a.CompletedTrades or #a.History)+1
  table.insert(a.History,1,{Contract=o.Contract,Direction=p.Direction,Quantity=closed,Entry=p.Entry,Exit=price,Pnl=realized,
   Time=string.format("%02d:%02d:%02d",math.floor(self.Time/3600)%24,math.floor(self.Time/60)%60,math.floor(self.Time)%60),TradeId=tradeId})
  if #a.History>self.Config.MaxAccountHistory then table.remove(a.History) end
 end
 local net=oldNet+delta
 if net==0 then a.Positions[o.Contract]=nil
 elseif not p or oldNet*net<0 then
  p={Id=o.Id,Contract=o.Contract,Direction=net>0 and 1 or -1,Quantity=math.abs(net),Entry=price}
  a.Positions[o.Contract]=p
 else
  if oldNet*delta>0 then p.Entry=(p.Entry*math.abs(oldNet)+price*qty)/math.abs(net) end
  p.Quantity=math.abs(net)
 end
 p=a.Positions[o.Contract]
 if p and not o.ReduceOnly and p.Direction==side then
  if o.StopTicks then p.Stop=math.round((p.Entry-side*o.StopTicks*b.Spec.Tick)/b.Spec.Tick)*b.Spec.Tick end
  if o.TargetTicks then p.Target=math.round((p.Entry+side*o.TargetTicks*b.Spec.Tick)/b.Spec.Tick)*b.Spec.Tick end
 end
 o.Remaining-=qty o.Filled+=qty o.Notional+=price*qty
 a.Revision+=1
 if a.Player then
  table.insert(a.Fills,1,{TradeId=tradeId,OrderId=o.Id,Contract=o.Contract,Direction=side,Quantity=qty,Price=price,
   Slippage=(price-o.Reference*b.Spec.Tick)*side,Time=self.Time})
  if #a.Fills>40 then table.remove(a.Fills) end
 end
end
function Engine:_trade(b,incoming,resting,qty)
 local tick=resting.Price local price=tick*b.Spec.Tick
 self.NextTrade+=1
 local trade={Id=self.NextTrade,Time=self.Time,Step=self.Step,Contract=b.Key,Price=price,Ticks=tick,Quantity=qty,
  Buyer=incoming.Direction==1 and incoming.Owner or resting.Owner,Seller=incoming.Direction==-1 and incoming.Owner or resting.Owner}
 self:_fillAccount(incoming,price,qty,trade.Id) self:_fillAccount(resting,price,qty,trade.Id)
 local prior=b.Last
 if prior then
  if tick>prior then b.Up+=1 elseif tick<prior then b.Down+=1 end
  b.Volatility=b.Volatility*0.96+math.abs(tick-prior)*0.04
 end
 -- Sole writer of last price. Quotes, regimes and news never set this field.
 b.Last=tick b.Open=b.Open or tick b.Volume+=qty self.TotalVolume+=qty
 table.insert(b.Recent,tick) if #b.Recent>64 then table.remove(b.Recent,1) end
 table.insert(self.Trades,trade) if #self.Trades>self.Config.MaxTradeHistory then table.remove(self.Trades,1) end
 self.TradeHash=(self.TradeHash*31+tick*7+qty*13+trade.Id+self.Step)%2147483647
 for _,tf in ipairs(self.Config.Timeframes) do
  local series=b.Candles[tf[1]] local bucket=math.floor(self.Time/tf[2])*tf[2] local candle=series[#series]
  if not candle or candle.Time~=bucket then
   candle={Time=bucket,Open=price,High=price,Low=price,Close=price,Volume=0}
   table.insert(series,candle) if #series>self.Config.MaxCandles then table.remove(series,1) end
  end
  candle.High=math.max(candle.High,price) candle.Low=math.min(candle.Low,price) candle.Close=price candle.Volume+=qty
  b.CandleVolume[tf[1]]=(b.CandleVolume[tf[1]] or 0)+qty
 end
 -- Latch on each execution so an intrastep crossing cannot be missed.
 for _,id in ipairs(self.AccountOrder) do
  local account=self.Accounts[id]
  if account.Player and not account.Locked and self:Summary(account).Equity<=0 then
   account.Locked=true account.Liquidating=true account.Revision+=1
   for symbol,position in pairs(account.Positions) do
    position.Triggered="Account depleted" position.Stop=nil position.Target=nil
    table.insert(self.PendingStops,{Owner=id,Contract=symbol,Position=position.Id})
   end
  end
  local p=account.Positions[b.Key]
  if p and not p.Triggered then
   local reason
   if p.Stop and (price-p.Stop)*p.Direction<=0 then reason="Stop loss"
   elseif p.Target and (price-p.Target)*p.Direction>=0 then reason="Take profit" end
   if reason then
    p.Triggered=reason
    if reason=="Stop loss" then p.Target=nil else p.Stop=nil end
    table.insert(self.PendingStops,{Owner=id,Contract=b.Key,Position=p.Id})
   end
  end
 end
end
function Engine:Submit(owner,request)
 local a=self.Accounts[owner]
 if not a or type(request)~="table" then return false,"Unknown account." end
 local b=self.Books[request.Contract]
 local side,qty,kind=request.Direction,request.Quantity,request.Type
 if not b or (side~=1 and side~=-1) or not integer(qty) or qty<1 then return false,"Invalid instrument, side or quantity. Use a positive whole number." end
 if not a.Player and qty>10000 then return false,"Invalid quantity." end
 if kind~="Market" and kind~="Limit" then return false,"Use Market or Limit." end
 local p=a.Positions[b.Key]
 local reducing=request.ReduceOnly==true
 if reducing and (not p or p.Direction==side or qty>p.Quantity) then return false,"No matching position to reduce." end
 if a.Locked and not reducing then return false,"Account depleted. Maximum currently available: 0 "..b.Key..". Close positions only." end
 if a.Player and b.Spec.CloseOnly and not reducing then return false,"Legacy micro contract is close-only. Choose an E-mini for new trades." end
 if a.Liquidating and not reducing then return false,"Account liquidation in progress. Maximum currently available: 0 "..b.Key..". Wait for positions to close." end
 local price=request.Price
 if kind=="Limit" then
  if not finite(price) or price<=0 or math.abs(price/b.Spec.Tick-math.round(price/b.Spec.Tick))>0.00001 then return false,"Limit price must use the instrument tick size." end
  price=math.round(price/b.Spec.Tick)
  if math.abs(price-(b.Last or b.Reference))>(b.Last or b.Reference)*self.Config.PriceBandFraction then return false,"Limit is outside the simulated price band." end
 end
 for _,field in ipairs({"StopTicks","TargetTicks"}) do
  local v=request[field] if v~=nil and (not integer(v) or v<1 or v>10000) then return false,"Protection must use 1–10,000 whole ticks." end
 end
 if a.Player and qty>self.Config.MaxPlayerQuantity then return false,self:CapacityMessage(a,b.Key,side,request.StopTicks) end
 if a.Player then
  local n=0 for _ in pairs(a.OpenOrders) do n+=1 end
  if n>=self.Config.MaxPlayerOrders and not reducing then return false,"Too many working orders. Maximum currently available: 0 "..b.Key..". Cancel an order first." end
  if not reducing then
   local maximum=self:OrderCapacity(a,b.Key,side,request.StopTicks)
   if qty>maximum then return false,self:CapacityMessage(a,b.Key,side,request.StopTicks) end
  end
 end
 if not a.Player and not reducing and not self:Exposure(a,b.Key,side,qty) then return false,"Insufficient simulated margin or inventory capacity." end
 self:_cleanBook(b)
 local opposing=side==1 and b.Asks or b.Bids
 self.NextOrder+=1
 local o={Id=self.NextOrder,Owner=owner,Contract=b.Key,Direction=side,Original=qty,Remaining=qty,Filled=0,Cancelled=0,Notional=0,
  Price=price,Type=kind,Status="Working",Time=self.Time,Reference=opposing[1] and opposing[1].Price or b.Last or b.Reference,
  StopTicks=request.StopTicks,TargetTicks=request.TargetTicks,ReduceOnly=reducing,Expires=request.Expires,
  Link=integer(request.Link) and request.Link or nil} -- server-set lead order id for copied orders
 self.Orders[o.Id]=o a.OpenOrders[o.Id]=true
 for _,level in ipairs(opposing) do
  if o.Remaining<=0 or (a.Locked and not reducing) then break end
  if kind=="Limit" and (level.Price-price)*side>0 then break end
  for _,resting in ipairs(level.Orders) do
   if o.Remaining<=0 or (a.Locked and not reducing) then break end
   if resting.Remaining>0 then
    local restingAccount=self.Accounts[resting.Owner]
    if resting.Owner==owner or (a.Group~=nil and restingAccount.Group==a.Group) then
     -- Cancel the older self quote. A self-trade must never manufacture volume, including between
     -- two accounts owned by the same player.
     resting.Cancelled+=resting.Remaining resting.Remaining=0 self:_retire(resting,"Self-trade prevented")
     if resting.Owner~=owner then restingAccount.Revision+=1 end
    else
     local rp=restingAccount.Positions[b.Key]
     local available=resting.Remaining
     if restingAccount.Locked and not resting.ReduceOnly then available=0 end
     if resting.ReduceOnly then available=(rp and rp.Direction~=resting.Direction) and math.min(available,rp.Quantity) or 0 end
     if restingAccount.Player and not resting.ReduceOnly then
      -- Buying power can fall while a limit waits. Recheck against other reservations at fill time.
      local capacity=self:OrderCapacity(restingAccount,b.Key,resting.Direction,resting.StopTicks,resting.Id)
      if capacity<resting.Remaining then available=0 end
     end
     if a.Player and not reducing then
      local capacity=self:OrderCapacity(a,b.Key,side,o.StopTicks,o.Id)
      if capacity<o.Remaining then
       o.Cancelled+=o.Remaining;o.Remaining=0;self:_retire(o,"Buying power changed")
       break
      end
     end
     if available<=0 then resting.Cancelled+=resting.Remaining resting.Remaining=0 self:_retire(resting,"Cancelled")
     else
      self:_trade(b,o,resting,math.min(o.Remaining,available))
      if resting.Remaining==0 then self:_retire(resting,"Filled") end
     end
    end
   end
  end
 end
 if o.Remaining==0 then if self.Orders[o.Id] then self:_retire(o,"Filled")end
 elseif kind=="Market" or (a.Locked and not reducing) then o.Cancelled+=o.Remaining o.Remaining=0 self:_retire(o,o.Filled>0 and "Partial / IOC" or "No liquidity")
 else self:_rest(b,o) end
 self:_cleanBook(b) a.Revision+=1
 local average=o.Filled>0 and o.Notional/o.Filled or nil
 return true,{Id=o.Id,Filled=o.Filled,Remaining=o.Remaining,Cancelled=o.Cancelled,Average=average,Status=o.Status,
  Slippage=average and (average-o.Reference*b.Spec.Tick)*side or 0}
end
function Engine:ProcessStops()
 -- Bounded queue also handles cascades; deferred tails continue next scheduler step.
 local processed=0
 while #self.PendingStops>0 and processed<200 do
  local item=table.remove(self.PendingStops,1) local a=self.Accounts[item.Owner] local p=a.Positions[item.Contract]
  processed+=1
  if p and p.Id==item.Position and p.Triggered then
   self:CancelAll(a.Id,item.Contract)
   self:Submit(a.Id,{Contract=item.Contract,Direction=-p.Direction,Quantity=math.min(p.Quantity,a.Player and self.Config.MaxPlayerQuantity or 10000),Type="Market",ReduceOnly=true})
  end
 end
end
function Engine:AdvanceClock(dt)
 self.Time+=dt self.Step+=1
 for _,id in ipairs(sortedKeys(self.Orders)) do
  local o=self.Orders[id] if o.Expires and o.Expires<=self.Time then self:Cancel(o.Owner,id) end
 end
 for _,id in ipairs(self.AccountOrder) do
  local a=self.Accounts[id] local summary=self:Summary(a)
  if not next(a.Positions) then a.Liquidating=nil end
  if summary.Equity<=0 or (not a.Player and summary.Margin>math.max(0,summary.Equity)*1.05) then
   if summary.Equity<=0 then a.Locked=true end
   a.Liquidating=true self:CancelAll(id)
   for _,key in ipairs(self.Config.ContractOrder) do local p=a.Positions[key] if p then p.Triggered=a.Locked and "Account depleted" or "Margin liquidation" p.Stop=nil p.Target=nil end end
  end
  for _,key in ipairs(self.Config.ContractOrder) do
   local p=a.Positions[key] if p and p.Triggered then table.insert(self.PendingStops,{Owner=id,Contract=key,Position=p.Id}) end
  end
 end
 self:ProcessStops()
end
function Engine:AmendProtection(owner,request)
 local a=self.Accounts[owner]
 if not a or type(request)~="table" then return false,"Unknown account." end
 local field=request.Protection
 if field~="Stop" and field~="Target" then return false,"Invalid protection." end
 local b=self.Books[request.Contract] local p=a.Positions[request.Contract]
 if not b or not p or p.Id~=request.OrderId or p.Triggered or not p[field] or a.Locked then
  return false,"Protection already triggered, cancelled or position closed."
 end
 if not finite(request.ExpectedPrice) or math.abs(request.ExpectedPrice-p[field])>b.Spec.Tick*0.00001 then
  return false,"Protection changed while dragging. Please try again."
 end
 local price=request.Price local tick=b.Spec.Tick
 if not finite(price) or price<=0 or math.abs(price/tick-math.round(price/tick))>0.00001 then
  return false,"Protection price must use the instrument tick size."
 end
 price=math.round(price/tick)*tick
 local last=(b.Last or b.Reference)*tick
 if math.abs(price-last)>last*self.Config.PriceBandFraction then return false,"Protection is outside the simulated price band." end
 local distance=(price-last)*p.Direction
 if (field=="Stop" and distance>=0) or (field=="Target" and distance<=0) then
  return false,field=="Stop" and "Keep SL beyond the current price on the loss side." or "Keep TP beyond the current price on the profit side."
 end
 -- A valid stop may sit beyond the account's equity. Depletion is enforced from
 -- actual execution prices, independently of the configured protection level.
 p[field]=price a.Revision+=1
 return true,string.format("Simulated %s moved to %.2f.",field=="Stop" and "SL" or "TP",price)
end
function Engine:CancelProtection(owner,id,field)
 if field~="Stop" and field~="Target" then return false,"Invalid protection." end
 for _,key in ipairs(self.Config.ContractOrder) do
  local p=self.Accounts[owner].Positions[key]
  if p and p.Id==id and not p.Triggered then p[field]=nil self.Accounts[owner].Revision+=1 return true,"Protection cancelled." end
 end
 return false,"Protection already triggered or position closed."
end
function Engine:Snapshot(owner,key,timeframe,full)
 local a=self.Accounts[owner] local positions,orders={},{}
 for _,symbol in ipairs(self.Config.ContractOrder) do
  local p=a.Positions[symbol]
  if p then
   positions[symbol]=copy(p)
   positions[symbol].Unrealized=((self.Books[symbol].Last or self.Books[symbol].Reference)*self.Books[symbol].Spec.Tick-p.Entry)*p.Quantity*p.Direction*self.Books[symbol].Spec.Multiplier
   for _,field in ipairs({"Stop","Target"}) do if p[field] then table.insert(orders,{Id=p.Id,Contract=symbol,Quantity=p.Quantity,
    Kind=field=="Stop" and "Stop loss" or "Take profit",Price=p[field],Protection=field,Status=p.Triggered or "Armed"}) end end
  end
 end
 for _,id in ipairs(sortedKeys(a.OpenOrders)) do
  local o=self.Orders[id] if o then table.insert(orders,{Id=id,Contract=o.Contract,Quantity=o.Remaining,Original=o.Original,Filled=o.Filled,
   Kind=o.Direction==1 and "Buy limit" or "Sell limit",Price=o.Price*self.Books[o.Contract].Spec.Tick,Status=o.Filled>0 and "Partial" or "Working"}) end
 end
 local quotes={}
 for _,symbol in ipairs(self.Config.ContractOrder) do
  local b=self.Books[symbol] local tick=b.Spec.Tick
  if b.Spec.CloseOnly and not a.Positions[symbol] then continue end
  local bid=b.Bids[1] and b.Bids[1].Price*tick local ask=b.Asks[1] and b.Asks[1].Price*tick
  quotes[symbol]={Last=b.Last and b.Last*tick,Open=b.Open and b.Open*tick,Bid=bid,Ask=ask,Spread=bid and ask and ask-bid,
   Volume=b.Volume,TradeCount=b.Up+b.Down,Recent={},Depth={Bids={},Asks={}}}
  for i=math.max(1,#b.Recent-15),#b.Recent do table.insert(quotes[symbol].Recent,b.Recent[i]*tick) end
  for _,side in ipairs({"Bids","Asks"}) do for i=1,math.min(5,#b[side]) do local l=b[side][i] table.insert(quotes[symbol].Depth[side],{Price=l.Price*tick,Quantity=l.Quantity}) end end
 end
 local series=self.Books[key].Candles[timeframe] local candles={}
 for i=full and 1 or math.max(1,#series-1),#series do table.insert(candles,copy(series[i])) end
 return {Seed=self.Seed,Time=self.Time,Step=self.Step,Quotes=quotes,Positions=positions,Orders=orders,History=a.History,Fills=a.Fills,
  Base=a.Base,Summary=self:Summary(a),Contract=key,Timeframe=timeframe,Candles=candles,Full=full,Revision=a.Revision,Locked=a.Locked}
end
function Engine:Audit()
 local cash,equity,inventory,volume=0,0,{},0
 for _,key in ipairs(self.Config.ContractOrder) do inventory[key]=0 end
 for _,id in ipairs(self.AccountOrder) do
  local a=self.Accounts[id] cash+=a.CashFlow equity+=self:Summary(a).Equity-a.Base
  assert(math.abs(a.Balance-a.Base-a.Realized)<0.001,"Balance / realized reconciliation")
  for key,p in pairs(a.Positions) do inventory[key]+=p.Quantity*p.Direction end
 end
 assert(math.abs(cash)<0.01,"Notional cash is not conserved") assert(math.abs(equity)<0.01,"Total marked P&L is not zero")
 for _,key in ipairs(self.Config.ContractOrder) do
  assert(inventory[key]==0,"Inventory is not conserved") local b=self.Books[key] volume+=b.Volume
  for _,tf in ipairs(self.Config.Timeframes) do assert((b.CandleVolume[tf[1]] or 0)==b.Volume,"Candle volume mismatch") end
  for _,side in ipairs({b.Bids,b.Asks}) do
   for _,l in ipairs(side) do local total=0 local arrival=0 for _,o in ipairs(l.Orders) do
    assert(o.Remaining>0 and self.Orders[o.Id]==o,"Stale resting order") assert(o.Id>arrival,"FIFO violated") arrival=o.Id total+=o.Remaining
   end assert(total==l.Quantity,"Level quantity mismatch") end
  end
  assert(not b.Bids[1] or not b.Asks[1] or b.Bids[1].Price<b.Asks[1].Price,"Crossed resting book")
 end
 for _,list in ipairs({self.Orders,self.OrderArchive}) do for _,o in pairs(list) do assert(o.Original==o.Filled+o.Remaining+o.Cancelled,"Order quantity mismatch") end end
 assert(volume==self.TotalVolume,"Total volume mismatch")
 return {CashError=cash,EquityError=equity,Inventory=inventory,Volume=volume,Trades=self.NextTrade,Hash=self.TradeHash}
end
return Engine
