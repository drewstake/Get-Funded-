-- Deterministic, server-only price/time priority exchange. Prices are integer ticks internally.
local Engine = {}
Engine.__index = Engine
local TradeStats=require(script.Parent.TradeStats)
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
 -- Player accounts carry lifetime trading statistics from their first execution.
 if a.Player then a.Stats=TradeStats.New("Live") end
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
-- Player sizing is the account's contract limit only (the tier's MaxContracts, 5 on $5K), counted across
-- positions and working entries in every instrument. Balance, equity and simulated margin never reduce
-- it: a $5K account that has lost $4,000 can still trade 5 contracts while it is active. A depleted
-- (locked) account cannot open anything; Submit and Snapshot enforce that separately.
function Engine:OrderCapacity(a,key,side,stopTicks,excludeOrder)
 if self:Summary(a).Equity<=0 then return 0,"Account equity reached $0." end -- failure rule: depletes on the next step
 local otherCount,net,same,opposite=0,0,0,0
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
  else otherCount+=math.max(math.abs(position+buy),math.abs(position-sell)) end
 end
 local limit=math.min(a.Limit,self.Config.MaxPlayerInventory)
 local allowed=limit-otherCount
 local reason="Account contract limit ("..limit.." total), including working orders."
 if math.abs(net-side*opposite)>allowed then return 0,reason end
 local maximum=math.max(0,math.floor(allowed-side*net-same))
 if maximum>self.Config.MaxPlayerQuantity then maximum=self.Config.MaxPlayerQuantity;reason="Per-order quantity limit." end
 return maximum,reason
end
function Engine:CapacityMessage(a,key,side,stopTicks)
 local maximum,reason=self:OrderCapacity(a,key,side,stopTicks)
 return reason.." Maximum currently available: "..maximum.." "..key.."."
end
-- Armed stop entries by contract. Derived from Orders (never saved), so a restored world rebuilds it.
function Engine:_stopIndex()
 if not self.Stops then
  self.Stops={}
  for id,o in pairs(self.Orders) do
   if o.Type=="Stop" then self.Stops[o.Contract]=self.Stops[o.Contract] or {} self.Stops[o.Contract][id]=true end
  end
 end
 return self.Stops
end
function Engine:_retire(o,status)
 if o.Type=="Stop" and self.Stops and self.Stops[o.Contract] then self.Stops[o.Contract][o.Id]=nil end
 if self.Resting and self.Resting[o.Contract] then self.Resting[o.Contract][o.Id]=nil end
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
  -- A saved account from before lifetime stats is migrated before this execution changes its ledger.
  if a.Player and (type(a.Stats)~="table" or a.Stats.V~=TradeStats.Version) then TradeStats.Reconcile(self,a,os.time()) end
  realized=(price-p.Entry)*closed*p.Direction*b.Spec.Multiplier
  a.Balance+=realized a.Realized+=realized
  -- Persist eligibility independently of the bounded display history, including break-even closes.
  a.CompletedTrades=(a.CompletedTrades or #a.History)+1
  table.insert(a.History,1,{Contract=o.Contract,Direction=p.Direction,Quantity=closed,Entry=p.Entry,Exit=price,Pnl=realized,
   Time=string.format("%02d:%02d:%02d",math.floor(self.Time/3600)%24,math.floor(self.Time/60)%60,math.floor(self.Time)%60),TradeId=tradeId})
  -- Lifetime counters update on the same execution; trimming the display history below never changes them.
  if a.Player then TradeStats.Add(a.Stats,a.History[1]) end
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
-------------------------------------------------------------------------------------------------
-- Player execution is off-book. The simulated market (every price, candle and volume bar) comes only
-- from participant orders matched in the book. A player's order never enters that book, never consumes
-- its liquidity and never prints a trade, so placing, changing, cancelling or filling it cannot move the
-- market price or create a candle. Fills are taken against the independent price feed:
--  * market orders (including SL, closes, liquidation and triggered stop entries) fill at the current
--    touch: best ask to buy, best bid to sell, or the last trade when that side of the book is empty;
--  * a marketable limit fills at the touch (its price or better); otherwise it waits off-book and fills
--    at its own limit price once a market trade reaches it (buy: trade at or below the limit;
--    sell: trade at or above it);
--  * a take profit fills at its target price once a trade reaches the target.
-- The house account is the counterparty of every player fill, so the double-entry cash ledger,
-- inventory and total P&L still reconcile exactly in Audit.
Engine.HouseId="house:player-fills"
function Engine:_house()
 local h=self.Accounts[Engine.HouseId]
 if not h then h=self:AddAccount(Engine.HouseId,0,1e9,1,false) h.House=true end
 return h
end
function Engine:_touch(b,side)
 local level=(side==1 and b.Asks or b.Bids)[1]
 return level and level.Price or b.Last or b.Reference
end
-- Working player limits by contract. Derived from Orders (never saved), so a restored world rebuilds it,
-- including limits saved by an older build that still rested player orders in the book.
function Engine:_restingIndex()
 if not self.Resting then
  self.Resting={}
  for id,o in pairs(self.Orders) do
   local a=self.Accounts[o.Owner]
   if o.Type=="Limit" and a and a.Player then self.Resting[o.Contract]=self.Resting[o.Contract] or {} self.Resting[o.Contract][id]=true end
  end
 end
 return self.Resting
end
function Engine:_playerFill(o,ticks,qty)
 local b=self.Books[o.Contract]
 self.NextTrade+=1 -- fill ids share the trade sequence so history/stats ids stay monotonic; no tape entry
 local price=ticks*b.Spec.Tick
 local house=self:_house()
 local mirror={Id=o.Id,Owner=house.Id,Contract=o.Contract,Direction=-o.Direction,Remaining=qty,Filled=0,Notional=0,Reference=o.Reference}
 self:_fillAccount(o,price,qty,self.NextTrade)
 self:_fillAccount(mirror,price,qty,self.NextTrade)
 self.PlayerFills=(self.PlayerFills or 0)+1
end
-- A market trade at `tick` fills every waiting player limit it reaches, in order-id sequence, at the
-- limit price. The contract cap is re-checked at fill time, so a waiting order can never fill past it.
function Engine:_fillResting(b,tick)
 local list=self:_restingIndex()[b.Key]
 if not list or not next(list) then return end
 local ready={}
 for id in pairs(list) do local o=self.Orders[id] if o and (o.Price-tick)*o.Direction>=0 then table.insert(ready,id) end end
 if #ready==0 then return end
 table.sort(ready)
 for _,id in ipairs(ready) do
  local o=self.Orders[id]
  if o and o.Remaining>0 then
   local a=self.Accounts[o.Owner] local p=a.Positions[o.Contract]
   local qty,status=o.Remaining,nil
   if o.ReduceOnly then qty=(p and p.Direction~=o.Direction) and math.min(qty,p.Quantity) or 0
   elseif a.Locked or a.Liquidating then qty=0 status="Account depleted"
   elseif self:OrderCapacity(a,o.Contract,o.Direction,o.StopTicks,o.Id)<o.Remaining then qty=0 status="Contract limit reached" end
   if qty>0 then self:_playerFill(o,o.Price,qty) end
   if o.Remaining==0 then self:_retire(o,"Filled")
   elseif qty==0 or o.ReduceOnly then o.Cancelled+=o.Remaining o.Remaining=0 self:_retire(o,status or "Cancelled") end
   a.Revision+=1
  end
 end
end
function Engine:_playerOrder(a,b,o,internal)
 local side=o.Direction local p=a.Positions[b.Key]
 local available=o.Remaining
 if o.ReduceOnly then available=(p and p.Direction~=side) and math.min(available,p.Quantity) or 0 end
 local touch=internal and internal.FillTicks or self:_touch(b,side)
 local marketable=o.Type=="Market" or (o.Price-touch)*side>=0
 if marketable and available>0 then self:_playerFill(o,touch,available) end
 if o.Remaining==0 then self:_retire(o,"Filled")
 elseif o.Type=="Market" or (o.ReduceOnly and marketable) then
  o.Cancelled+=o.Remaining o.Remaining=0 self:_retire(o,o.Filled>0 and "Partial / IOC" or "Nothing to close")
 else
  local index=self:_restingIndex() index[b.Key]=index[b.Key] or {} index[b.Key][o.Id]=true
 end
 a.Revision+=1
 local average=o.Filled>0 and o.Notional/o.Filled or nil
 return true,{Id=o.Id,Filled=o.Filled,Remaining=o.Remaining,Cancelled=o.Cancelled,Average=average,Status=o.Status,
  Slippage=average and (average-o.Reference*b.Spec.Tick)*side or 0}
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
 -- Stop entries latch on the execution that reaches them; ProcessStops submits them at market.
 local armed=self:_stopIndex()[b.Key]
 if armed and next(armed) then
  for id in pairs(armed) do
   local o=self.Orders[id]
   if o and not o.Triggered and (tick-o.Price)*o.Direction>=0 then o.Triggered=self.Time end
  end
 end
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
 -- Waiting player limits fill at their own price once the market trades through them.
 self:_fillResting(b,tick)
 -- Latch on each execution so an intrastep crossing cannot be missed.
 for _,id in ipairs(self.AccountOrder) do
  local account=self.Accounts[id]
  if account.Player and not account.Locked and self:Summary(account).Equity<=0 then
   account.Locked=true account.Liquidating=true account.Revision+=1
   -- One depletion per attempt: the marker is saved with the account and never re-counted.
   account.Depleted=true account.DepletedAt=account.DepletedAt or self.Time
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
-- `internal` is engine-only (never from a client request): FillTicks sets a take-profit fill price.
function Engine:Submit(owner,request,internal)
 local a=self.Accounts[owner]
 if not a or type(request)~="table" then return false,"Unknown account." end
 local b=self.Books[request.Contract]
 local side,qty,kind=request.Direction,request.Quantity,request.Type
 if not b or (side~=1 and side~=-1) or not integer(qty) or qty<1 then return false,"Invalid instrument, side or quantity. Use a positive whole number." end
 if not a.Player and qty>10000 then return false,"Invalid quantity." end
 if kind~="Market" and kind~="Limit" and kind~="Stop" then return false,"Use Market, Limit or Stop." end
 local p=a.Positions[b.Key]
 local reducing=request.ReduceOnly==true
 if reducing and (not p or p.Direction==side or qty>p.Quantity) then return false,"No matching position to reduce." end
 if a.Locked and not reducing then return false,"Account depleted. Maximum currently available: 0 "..b.Key..". Close positions only." end
 if a.Player and b.Spec.CloseOnly and not reducing then return false,"Legacy micro contract is close-only. Choose an E-mini for new trades." end
 if a.Liquidating and not reducing then return false,"Account liquidation in progress. Maximum currently available: 0 "..b.Key..". Wait for positions to close." end
 local price=request.Price
 if kind=="Limit" or kind=="Stop" then
  if not finite(price) or price<=0 or math.abs(price/b.Spec.Tick-math.round(price/b.Spec.Tick))>0.00001 then return false,kind.." price must use the instrument tick size." end
  price=math.round(price/b.Spec.Tick)
  if math.abs(price-(b.Last or b.Reference))>(b.Last or b.Reference)*self.Config.PriceBandFraction then return false,kind.." is outside the simulated price band." end
 end
 -- Stop entries wait off-book and become market orders when a trade reaches the stop price.
 -- A buy stop sits above the last trade and a sell stop below it; exits use SL/TP instead.
 if kind=="Stop" then
  if reducing or not a.Player then return false,"Stop orders are entry orders for player accounts. Use SL/TP to protect a position." end
  local last=b.Last or b.Reference
  if (price-last)*side<=0 then return false,side==1 and "Stop buy must be above the current price." or "Stop sell must be below the current price." end
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
 if kind=="Stop" then
  -- Armed, not matched: the order reserves capacity like a working limit until it triggers.
  o.Status="Armed" local index=self:_stopIndex() index[b.Key]=index[b.Key] or {} index[b.Key][o.Id]=true
  a.Revision+=1
  return true,{Id=o.Id,Filled=0,Remaining=o.Remaining,Cancelled=0,Average=nil,Status="Stop armed",Slippage=0}
 end
 if a.Player then return self:_playerOrder(a,b,o,internal) end
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
   -- A player's take profit is a limit at the target: it fills at the target once a trade reaches it.
   local internal
   if a.Player and p.Triggered=="Take profit" and p.Target then internal={FillTicks=math.round(p.Target/self.Books[item.Contract].Spec.Tick)} end
   self:Submit(a.Id,{Contract=item.Contract,Direction=-p.Direction,Quantity=math.min(p.Quantity,a.Player and self.Config.MaxPlayerQuantity or 10000),Type="Market",ReduceOnly=true},internal)
  end
 end
 self:_triggerStops()
end
-- Triggered stop entries become ordinary market orders, in order-id sequence. While its market order is
-- checked the stop stops reserving capacity, so Submit applies every current rule once (contract cap, buying
-- power, depletion, order limits): a stop can never fill past the cap. A rejection ends the stop. If the
-- book is momentarily empty, the unfilled rest stays triggered (and reserved) and retries for a few
-- simulated seconds, like a resting stop-market order, before it is cancelled for lack of liquidity.
Engine.StopRetrySeconds=5
function Engine:_triggerStops()
 local ready={}
 for _,ids in pairs(self:_stopIndex()) do for id in pairs(ids) do local o=self.Orders[id] if o and o.Triggered then table.insert(ready,id) end end end
 if #ready==0 then return end
 table.sort(ready)
 for _,id in ipairs(ready) do
  local o=self.Orders[id]
  if o then
   local a=self.Accounts[o.Owner] local b=self.Books[o.Contract]
   a.OpenOrders[o.Id]=nil
   local ok,result=self:Submit(o.Owner,{Contract=o.Contract,Direction=o.Direction,Quantity=o.Remaining,Type="Market",
    StopTicks=o.StopTicks,TargetTicks=o.TargetTicks,Link=o.Link})
   local filled=ok and result.Filled or 0
   if filled>0 then
    o.Remaining-=filled o.Cancelled+=filled -- converted into the child market order that holds the fill
    o.Converted=(o.Converted or 0)+filled o.ConvertedNotional=(o.ConvertedNotional or 0)+result.Average*filled
   end
   local waiting=ok and o.Remaining>0 and self.Time-o.Triggered<Engine.StopRetrySeconds and not a.Locked
   if waiting then a.OpenOrders[o.Id]=true
   else
    local status=not ok and "Rejected" or o.Remaining>0 and (filled>0 or o.Converted) and "Partial / IOC" or o.Remaining>0 and "No liquidity" or "Triggered"
    local unfilled=o.Remaining o.Cancelled+=unfilled o.Remaining=0
    a.OpenOrders[o.Id]=true self:_retire(o,status)
    local done=o.Converted or 0
    a.Triggers=a.Triggers or {}
    table.insert(a.Triggers,1,{Id=o.Id,Contract=o.Contract,Direction=o.Direction,Quantity=o.Original,Price=o.Price*b.Spec.Tick,Ok=done>0,
     Filled=done,Average=done>0 and o.ConvertedNotional/done or nil,Message=not ok and result or unfilled>0 and ("No liquidity for "..unfilled) or nil,Time=self.Time})
    if #a.Triggers>8 then table.remove(a.Triggers) end
   end
   a.Revision+=1
  end
 end
end
function Engine:AdvanceClock(dt)
 self.Time+=dt self.Step+=1
 for _,id in ipairs(sortedKeys(self.Orders)) do
  local o=self.Orders[id] if o.Expires and o.Expires<=self.Time then self:Cancel(o.Owner,id) end
 end
 for _,id in ipairs(self.AccountOrder) do
  local a=self.Accounts[id]
  if a.House then continue end -- counterparty of player fills; it has no risk limits and never trades
  local summary=self:Summary(a)
  if not next(a.Positions) then a.Liquidating=nil end
  if summary.Equity<=0 or (not a.Player and summary.Margin>math.max(0,summary.Equity)*1.05) then
   if summary.Equity<=0 then a.Locked=true if a.Player and not a.Depleted then a.Depleted=true a.DepletedAt=self.Time end end
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
   Kind=(o.Direction==1 and "Buy " or "Sell ")..(o.Type=="Stop" and "stop" or "limit"),Type=o.Type,Direction=o.Direction,
   Price=o.Price*self.Books[o.Contract].Spec.Tick,Status=o.Type=="Stop" and (o.Triggered and "Triggered" or "Armed") or o.Filled>0 and "Partial" or "Working"}) end
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
 -- Current maximum new order per instrument and side (the same rule Submit enforces), for the ticket and chart menu.
 local capacity
 if a.Player then
  capacity={}
  for _,symbol in ipairs(self.Config.ContractOrder) do
   if not self.Books[symbol].Spec.CloseOnly then
    local buy=a.Locked and 0 or (self:OrderCapacity(a,symbol,1)) local sell=a.Locked and 0 or (self:OrderCapacity(a,symbol,-1))
    capacity[symbol]={Buy=buy,Sell=sell}
   end
  end
 end
 return {Seed=self.Seed,Time=self.Time,Step=self.Step,Quotes=quotes,Positions=positions,Orders=orders,History=a.History,Fills=a.Fills,
  Base=a.Base,Summary=self:Summary(a),Contract=key,Timeframe=timeframe,Candles=candles,Full=full,Revision=a.Revision,Locked=a.Locked,
  Capacity=capacity,Limit=a.Player and math.min(a.Limit,self.Config.MaxPlayerInventory) or nil,Triggers=a.Triggers}
end
function Engine:Audit()
 local cash,equity,inventory,volume=0,0,{},0
 for _,key in ipairs(self.Config.ContractOrder) do inventory[key]=0 end
 for _,id in ipairs(self.AccountOrder) do
  local a=self.Accounts[id] cash+=a.CashFlow equity+=self:Summary(a).Equity-a.Base
  assert(math.abs(a.Balance-a.Base-a.Realized)<0.001,"Balance / realized reconciliation")
  local st=a.Stats
  if a.Player and type(st)=="table" then
   assert(math.abs(a.Realized-(st.Gains-st.Loss+st.UntrackedNet))<0.01,"Lifetime stats / realized reconciliation")
   assert(st.Trades==st.Wins+st.Losses+st.Even,"Lifetime stats trade classification")
  end
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
