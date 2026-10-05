from pathlib import Path
root=Path(__file__).resolve().parents[1]
def read(n): return (root/'src'/n).read_text(encoding='utf-8-sig')
def write(n,s): (root/'src'/n).write_text(s,encoding='utf-8',newline='\n')
def replace(s,a,b):
 assert a in s, a[:120]
 return s.replace(a,b)

s=read('ChartViewport.luau')
s=replace(s,'Viewport.MaxBars=2000','Viewport.MaxBars=240')
s=replace(s,'Viewport.PixelsPerBar=1      -- zoomed fully out, each candle gets one pixel column (a 1 px wick/body)','Viewport.PixelsPerBar=7      -- readable 3+ px bodies, distinct wicks and space between candles')
write('ChartViewport.luau',s)
s=read('ChartTools.luau')
s=replace(s,'-- Every rectangle has an "Extend" dot','-- The selected rectangle has an "Extend" dot')
s=replace(s,'if d.Kind=="Rect" then\n   local ex,ey=Tools.ExtendPoint','if d.Kind=="Rect" and d.Id==selectedId then\n   local ex,ey=Tools.ExtendPoint')
write('ChartTools.luau',s)

s=read('MarketClient.luau')
s=replace(s,'local Progression=require(root.ProgressionConfig)','local Progression=require(root.ProgressionConfig)\nlocal Protection=require(root.TradeProtection)')
s=replace(s,'local Session={} Session.__index=Session','Market.Protection=Protection.Resolve\nlocal Session={} Session.__index=Session')
s=replace(s,'function Session:Close(key)', '''function Session:AmendOrder(key,id,price,expectedPrice,expectedQuantity)
 return self:Send("AmendOrder",{Contract=key,OrderId=id,Price=price,ExpectedPrice=expectedPrice,ExpectedQuantity=expectedQuantity})
end
function Session:Close(key)''')
s=replace(s,'price,stopTicks,targetTicks)','price,stopDollars,targetDollars)')
s=replace(s,'StopTicks=stopTicks,TargetTicks=targetTicks','StopDollars=stopDollars,TargetDollars=targetDollars')
write('MarketClient.luau',s)
s=read('MarketServer.server.luau')
s=replace(s,'AmendProtection=true,','AmendProtection=true,AmendOrder=true,')
s=replace(s,'"StopTicks","TargetTicks","OrderId"','"StopTicks","TargetTicks","StopDollars","TargetDollars","ExpectedQuantity","OrderId"')
write('MarketServer.server.luau',s)
s=read('MarketEngine.luau')
s=replace(s,'local TradeStats=require(script.Parent.TradeStats)','local TradeStats=require(script.Parent.TradeStats)\nlocal Protection=require(game.ReplicatedStorage.MarketReign.TradeProtection)')
s=replace(s,' for _,field in ipairs({"StopTicks","TargetTicks"}) do', ''' -- Normalize once on the server; callers cannot smuggle conflicting distances.
 request=copy(request)
 for _,field in ipairs({"Stop","Target"}) do
  if request[field.."Dollars"]~=nil then
   if request[field.."Ticks"]~=nil then return false,"Use dollars or ticks, not both." end
   local resolved,err=Protection.Resolve(b.Spec,qty,request[field.."Dollars"])
   if not resolved then return false,err end
   request[field.."Ticks"]=resolved.Ticks
  end
 end
 for _,field in ipairs({"StopTicks","TargetTicks"}) do''')
s=replace(s,'function Engine:AmendProtection(owner,request)', '''-- Atomic amendment: validate before touching the working order. Preserve its identity, quantity,
-- attached protection and copy links. A newly marketable price follows normal player-limit fills.
function Engine:AmendOrder(owner,request)
 local a=self.Accounts[owner]
 local o=type(request)=="table" and self.Orders[request.OrderId]
 if not a or not a.Player or not o or o.Owner~=owner or o.Contract~=request.Contract or o.Type~="Limit" or o.Remaining<=0 then
  return false,"Limit order is no longer working."
 end
 if a.Locked or a.Liquidating then return false,"Account depleted. Limit order cannot be changed." end
 local b=self.Books[o.Contract] local tick=b.Spec.Tick
 if not finite(request.ExpectedPrice) or math.abs(request.ExpectedPrice-o.Price*tick)>tick*.00001 or request.ExpectedQuantity~=o.Remaining then
  return false,"Limit order changed while dragging. Please try again."
 end
 local price=request.Price
 if not finite(price) or price<=0 or math.abs(price/tick-math.round(price/tick))>.00001 then return false,"Limit price must use the instrument tick size." end
 local ticks=math.round(price/tick) local last=b.Last or b.Reference
 if math.abs(ticks-last)>last*self.Config.PriceBandFraction then return false,"Limit is outside the simulated price band." end
 if not o.ReduceOnly and self:OrderCapacity(a,o.Contract,o.Direction,o.StopTicks,o.Id)<o.Remaining then return false,"Account contract limit changed. Cancel another order first." end
 o.Price=ticks o.Time=self.Time
 self:_playerOrder(a,b,o)
 return true,string.format("Limit %s moved to %.2f%s",o.Direction==1 and "Buy" or "Sell",price,o.Remaining==0 and " · filled" or "")
end
function Engine:AmendProtection(owner,request)''')
write('MarketEngine.luau',s)
s=read('FundedAccounts.luau')
s=replace(s,'elseif req.Action=="AmendProtection" then return engine:AmendProtection(owner,req)','elseif req.Action=="AmendProtection" then return engine:AmendProtection(owner,req)\n elseif req.Action=="AmendOrder" then return engine:AmendOrder(owner,req)')
s=replace(s,'action=="Place" or action=="AmendProtection"','action=="Place" or action=="AmendProtection" or action=="AmendOrder"')
# Copies retain the lead tick distance, so proportional quantities scale risk with account size.
s=replace(s,'StopTicks=req.StopTicks,TargetTicks=req.TargetTicks,Link=', '''StopTicks=req.StopDollars and require(game.ReplicatedStorage.MarketReign.TradeProtection).Resolve(e.Books[req.Contract].Spec,req.Quantity,req.StopDollars).Ticks or req.StopTicks,
     TargetTicks=req.TargetDollars and require(game.ReplicatedStorage.MarketReign.TradeProtection).Resolve(e.Books[req.Contract].Spec,req.Quantity,req.TargetDollars).Ticks or req.TargetTicks,Link=''')
s=replace(s,'  elseif action=="Cancel" and not req.Protection then', '''  elseif action=="AmendOrder" then
   local found=false
   for _,id in ipairs(sortedKeys(account.OpenOrders)) do
    local o=e.Orders[id]
    if o and o.Link==req.OrderId and o.Type=="Limit" then
     found=true
     local copied,message=e:AmendOrder(f.Id,{Contract=o.Contract,OrderId=id,Price=req.Price,ExpectedPrice=o.Price*e.Books[o.Contract].Spec.Tick,ExpectedQuantity=o.Remaining})
     add(f,copied and "Copied" or "Rejected",message)
    end
   end
   if not found then add(f,"Skipped","No linked limit order still working.") end
  elseif action=="Cancel" and not req.Protection then''')
write('FundedAccounts.luau',s)

s=read('ChartView.luau')
s=replace(s,'   if not preview then\n    -- Right-edge','   if selected and not preview then\n    -- Right-edge')
start=s.index(' local vh=compact and')
end=s.index(' local chartH=',start)
s=s[:start]+' local bottom=ph-29 -- the price plot now uses the former volume space\n'+s[end:]
start=s.index(' local volH=');end=s.index(' local function place(o,',start);s=s[:start]+s[end:]
s=replace(s,' local maxVol=1 for _,d in ipairs(data)do maxVol=math.max(maxVol,d.Volume)end\n','')
start=s.index('  if volStrip then');end=s.index(' -- Position levels',start);s=s[:start]+' end\n'+s[end:]
s=replace(s,'%+.2f%%  V %d','%+.2f%%')
s=replace(s,'v,change,recent.Volume)','v,change)')
# Freeze price geometry throughout a pending-order gesture/ack just like a protection gesture.
s=replace(s,' if adjustment then\n  -- Hold', ''' local orderAdjustment=drag and drag.Kind=="Order" and drag or self.OrderPending
 if orderAdjustment and(orderAdjustment.Key~=viewKey or orderAdjustment.Base~=session.AccountKey or not self:WorkingOrder(orderAdjustment.Id))then orderAdjustment=nil end
 local frozenAdjustment=adjustment or orderAdjustment
 if frozenAdjustment then
  -- Hold''')
s=replace(s,'table.clone(adjustment.View)','table.clone(frozenAdjustment.View)')
s=replace(s,'  local th=mobile and 20 or 24 local size=mobile and 11 or 13','  local th=mobile and 32 or 28 local size=mobile and 14 or 15\n  local cancelW=mobile and 32 or 28')
s=replace(s,'   local label=(buy and"Buy "or"Sell ")..(o.Type=="Stop"and"Stop "or"Limit ")..o.Quantity.." @ "..Market.Number(o.Price)', '''   local moving=orderAdjustment and orderAdjustment.Id==o.Id
   local orderPrice=moving and orderAdjustment.Price or o.Price
   local label=(o.Type=="Stop"and"Stop "or"Limit ")..(buy and"Buy "or"Sell ")..o.Quantity''')
s=replace(s,'local py=top+Y(o.Price) local inside','local py=top+Y(orderPrice) local inside')
s=replace(s,'   local text2=inside and label or((py<top and"↑ "or"↓ ")..label)','   local text2=label..(moving and(orderAdjustment.RequestId and" …"or" *")or"")')
s=replace(s,'Vector2.new(600,60)).X)+18','Vector2.new(600,60)).X)+18+cancelW')
s=replace(s,'   tag:SetAttribute("OrderId",o.Id);tag:SetAttribute("Price",o.Price);tag:SetAttribute("Text",text2)','   tag:SetAttribute("OrderId",o.Id);tag:SetAttribute("Price",orderPrice);tag:SetAttribute("Text",text2)')
s=replace(s,'text(tag,"Label",text2,4,0,tw-8,th,size','text(tag,"Label",text2,4,0,tw-cancelW-8,th,size')
s=replace(s,'   if inside then\n    local tag2=frame(plot,"OrderPriceTag"', '''   -- Separate X hit region on the stable chart input surface (pooled visual objects never own input).
   local cancel=frame(tag,"Cancel",tw-cancelW,0,cancelW,th,C.Raised,5);round(cancel,5)
   text(cancel,"Label","X",0,0,cancelW,th,size,color,ctx.B,CENTER,6)
   local tx=math.max(0,pw-tw-6)
   table.insert(markers,{Id=o.Id,Price=orderPrice,ConfirmedPrice=o.Price,Quantity=o.Quantity,Type=o.Type,Label=label,Visible=inside,
    Y=inside and py-top or nil,X=tx,Top=ty-top,W=tw,H=th,CancelX=tx+tw-cancelW})
   if inside then
    local tag2=frame(plot,"OrderPriceTag"''')
s=replace(s,'text(tag2,"Price",Market.Number(o.Price)','text(tag2,"Price",Market.Number(orderPrice)')
s=replace(s,'   table.insert(markers,{Id=o.Id,Price=o.Price,Label=label,Visible=inside,Y=inside and py-top or nil})\n','')
s=replace(s,'d.Kind=="Scale"or d.Kind=="Protection"','d.Kind=="Scale"or d.Kind=="Protection"or d.Kind=="Order"')
s=replace(s,'    icon=prot and CURSOR.NS', '''    local order,part=self:OrderHit(x,y,false)
    icon=order and(part=="Cancel"and CURSOR.Point or CURSOR.NS)or prot and CURSOR.NS''')
anchor='function View:Began(ev)'
s=replace(s,anchor,'''function View:WorkingOrder(id)
 for _,o in ipairs(self.Ctx.Session.Orders or {})do if o.Id==id and not o.Protection then return o end end
end
function View:OrderHit(x,y,touch)
 -- Buttons win over lines, including when two orders share a price.
 for _,m in ipairs(self.OrderMarkers or {})do
  if x>=m.X and x<=m.X+m.W and y>=m.Top and y<=m.Top+m.H then return m,x>=m.CancelX and "Cancel"or"Drag" end
 end
 for _,m in ipairs(self.OrderMarkers or {})do
  if m.Type=="Limit" and m.Y and math.abs(y-m.Y)<=(touch and 12 or 5)then return m,"Drag" end
 end
end
'''+anchor)
s=replace(s,' -- Stop and target labels keep priority over every tool.', ''' -- X consumes the gesture and only cancels its order; it can never become a chart drag.
 if kind~=MB3 then
  local marker,part=self:OrderHit(x,y,kind==TOUCH)
  if marker then
   if self.OrderPending or self.Pending then return end
   if part=="Cancel"then
    start("CancelOrder",{Id=marker.Id,Base=session.AccountKey});return
   elseif marker.Type=="Limit"then
    start("Order",{Id=marker.Id,Key=g.Key,Contract=s.Contract,Base=session.AccountKey,Original=marker.ConfirmedPrice,Price=marker.ConfirmedPrice,Quantity=marker.Quantity});return
   end
  end
 end
 -- Stop and target labels keep priority over drawing tools.''')
s=replace(s,' if self.Pending then return end',' if self.Pending or self.OrderPending then return end')
s=replace(s,' elseif d.Kind=="Protection"then\n  local Market=', ' elseif d.Kind=="Protection"or d.Kind=="Order"then\n  local Market=')
s=replace(s,' elseif d.Kind=="Protection"then\n  if commit', ''' elseif d.Kind=="CancelOrder"then
  if commit and not d.Moved and d.Base==self.Ctx.Session.AccountKey then
   local ok,message=self.Ctx.Session:Cancel(d.Id)
   if not ok then self.Ctx.toast(message,"error")end
  end
 elseif d.Kind=="Order"then
  if commit and d.Moved and d.Price~=d.Original then
   local ok,message,_,requestId=self.Ctx.Session:AmendOrder(d.Contract,d.Id,d.Price,d.Original,d.Quantity)
   if ok then
    d.RequestId=requestId;self.OrderPending=d
    task.delay(10,function()
     if self.OrderPending==d then self.OrderPending=nil;self.Dirty=true;self.Ctx.toast("Limit update not confirmed. Restored the last server price.","error")end
    end)
   else self.Ctx.toast(message,"error")end
  end
 elseif d.Kind=="Protection"then
  if commit''')
s=replace(s,'self.Drag or self.Pending or self:Blocked()','self.Drag or self.Pending or self.OrderPending or self:Blocked()')
s=replace(s,'self.Drag and self.Drag.Kind=="Protection")','self.Drag and(self.Drag.Kind=="Protection"or self.Drag.Kind=="Order"))')
s=replace(s,' local pending=self.Pending\n', ''' if d and d.Kind=="Order"then
  local o=self:WorkingOrder(d.Id)
  if session.AccountKey~=d.Base or not o or o.Price~=d.Original or o.Quantity~=d.Quantity then
   self:Finish(false);message="Limit order changed or filled. Drag cancelled."
  end
 end
 if self.OrderPending then
  local p=self.OrderPending
  if p.Base~=session.AccountKey or not self:WorkingOrder(p.Id)then self.OrderPending=nil end
 end
 local pending=self.Pending
''')
s=replace(s,'function View:OnReply(reply)\n','function View:OnReply(reply)\n if self.OrderPending and reply.RequestId==self.OrderPending.RequestId then self.OrderPending=nil;self.Dirty=true end\n')
s=replace(s,' root:SetAttribute("ChartOrderMarkers",#markers)',' root:SetAttribute("ChartOrderMarkers",#markers)\n root:SetAttribute("OrderAmendPending",self.OrderPending~=nil)')
write('ChartView.luau',s)
