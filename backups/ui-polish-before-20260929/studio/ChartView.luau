-- Candlestick chart: painting, navigation and drawing tools. Presentation only: it reads candles,
-- quotes and positions from the session and never changes prices or account state, except that a
-- stop/target drag sends the same AmendProtection request the order ticket uses, and the right-click
-- order menu submits through the terminal's shared order path (same checks and server validation).
local Viewport=require(script.Parent.ChartViewport)
local PaintPool=require(script.Parent.ChartPaintPool)
local Tools=require(script.Parent.ChartTools)
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local TextService=game:GetService("TextService")
local View={} View.__index=View
local MB1,MB2,MB3,TOUCH,MOVE=Enum.UserInputType.MouseButton1,Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3,Enum.UserInputType.Touch,Enum.UserInputType.MouseMovement
local RIGHT,CENTER=Enum.TextXAlignment.Right,Enum.TextXAlignment.Center
local DRAW={Line=true,Trend=true,Rect=true}
-- Reused native materials: bevels disappear at dense zoom levels without adding image assets.
local CANDLE_LIGHT=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
 ColorSequenceKeypoint.new(.35,Color3.fromRGB(232,255,247)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(137,175,192)),
})
local CANDLE_INK=Color3.fromRGB(1,14,40)
local CANDLE_GLEAM=Color3.fromRGB(220,255,247)
local CURSOR={Hand="rbxasset://SystemCursors/OpenHand",Grab="rbxasset://SystemCursors/ClosedHand",Cross="rbxasset://SystemCursors/Cross",
 NS="rbxasset://SystemCursors/SizeNS",Move="rbxasset://SystemCursors/SizeAll",NWSE="rbxasset://SystemCursors/SizeNWSE",
 NESW="rbxasset://SystemCursors/SizeNESW",Point="rbxasset://SystemCursors/PointingHand",EW="rbxasset://SystemCursors/SizeEW"}
local function count(t) local n=0 for _ in pairs(t)do n+=1 end return n end
local TOOL_NAMES={Pan="Select & pan",Crosshair="Crosshair",Trend="Trend line",Line="Horizontal line",Rect="Rectangle"}
View.ToolNames=TOOL_NAMES

function View.new(ctx)
 local self=setmetatable({Ctx=ctx,S=ctx.State,Views={},History=Tools.History(100),Touches={},Ctrl=false,
  Seen={},Mutations=0,ColorMismatches=0,PaintCount=0,PaintTotal=0,PaintMax=0,Cursor=""},View)
 self.S.Drawings=self.S.Drawings or {}
 for _,d in ipairs(self.S.Drawings)do Tools.Normalize(d)end
 self.S.Magnet=self.S.Magnet==true
 self.S.Tool=self.S.Tool or "Pan"
 if RunService:IsStudio()and ctx.Root then self:Diagnostics(ctx.Root)end
 return self
end
-- Studio-only test hook: read drawing/candle state and trigger the focus-loss and menu paths.
function View:Diagnostics(root)
 local f=root:FindFirstChild("ChartDiagnostics") or Instance.new("BindableFunction")
 f.Name="ChartDiagnostics" f.Parent=root
 f.OnInvoke=function(command)
  if command=="Drawings"then return Tools.CopyList(self.S.Drawings)
  elseif command=="Visible"then
   local g=self.Geometry if not g then return {} end
   local list={} for i,d in ipairs(g.Data)do list[i]={Time=d.Time,Open=d.Open,High=d.High,Low=d.Low,Close=d.Close,X=g.X(d.Time)}end return list
  elseif command=="FocusLost"then self:FocusLost() return true
  elseif command=="MenuOpened"then self:Cancel() return true
  elseif command=="OrderMenu"then
   local m=self.Menu if not m then return nil end
   return {Contract=m.Contract,Price=m.Price,Market=m.Market,Side=m.Side,Options=m.Labels,Quantity=self.S.Qty}
  elseif command=="OrderMarkers"then return self.OrderMarkers or {}
  elseif command=="State"then
   return {Ctrl=self.Ctrl,Magnet=self:MagnetOn(),Drag=self.Drag and self.Drag.Kind,Placement=self.Placement and self.Placement.Kind,Touches=count(self.Touches),Tool=self.S.Tool,Selected=self.Selected}
  end
  return nil
 end
end
function View:Busy() return self.Drag~=nil end
function View:Reset() self.Geometry=nil self.Pool=nil self.OverlayPool=nil self.HoverDirty=false self.Base=nil self.Chrome=nil end
function View:Palette(key) local C=self.Ctx.C return C[key] or C.Blue end
function View:Current() -- drawings on the chart being viewed
 local s=self.S local list={}
 for _,d in ipairs(s.Drawings)do if d.Contract==s.Contract and d.Timeframe==s.Timeframe then table.insert(list,d)end end
 return list
end
function View:Find(id) for _,d in ipairs(self.S.Drawings)do if d.Id==id then return d end end end
function View:SelectedDrawing()
 local d=self.Selected and self:Find(self.Selected)
 if d and d.Contract==self.S.Contract and d.Timeframe==self.S.Timeframe then return d end
end
function View:CtrlDown()
 if self.Ctrl and not(UIS:IsKeyDown(Enum.KeyCode.LeftControl)or UIS:IsKeyDown(Enum.KeyCode.RightControl))then self.Ctrl=false end
 return self.Ctrl
end
function View:MagnetOn() return self.S.Magnet or self:CtrlDown() end
function View:MarkDirty() self.Dirty=true end

-- Screen position -> plot-local pixels (origin at the price area's top-left).
function View:Local(pos)
 local g=self.Geometry
 return pos.X-g.Plot.AbsolutePosition.X-g.Left,pos.Y-g.Plot.AbsolutePosition.Y-g.Top
end
function View:PointAt(x,y,snap,touch)
 local g=self.Geometry local v=g.View
 if snap and self:MagnetOn() then
  local hit=Tools.Snap(g.Data,g.X,g.Y,x,y,touch and Tools.SnapRadius.Touch or Tools.SnapRadius.Mouse)
  if hit then return {Time=hit.Time,Price=hit.Price,Snap=hit} end
 end
 return {Time=v.Left+x/g.Pxs,Price=self.Ctx.Market.Snap(v.High-y/g.Ppp,self.S.Contract)}
end
function View:Hit(x,y,touch)
 local g=self.Geometry
 return Tools.HitTest(self:Current(),g.X,g.Y,x,y,touch and Tools.HitTolerance.Touch or Tools.HitTolerance.Mouse,
  touch and Tools.HandleRadius.Touch or Tools.HandleRadius.Mouse,self.Selected,g.Width)
end

-------------------------------------------------------------------------------------------------
-- Chrome: header, toolbar, view controls and the selected drawing's style bar. Built on full renders.
function View:BuildChrome(p,w,h,mobile,headH,toolsH)
 local ctx=self.Ctx local C,s,Market=ctx.C,self.S,ctx.Market
 local frame,text,button,line,stroke,round=ctx.frame,ctx.text,ctx.button,ctx.line,ctx.stroke,ctx.round
 local F,M,B,N=ctx.F,ctx.M,ctx.B,ctx.N
 local c=Market.Contracts[s.Contract]
 local hd=frame(p,"Header",0,0,w,headH,Color3.new(1,1,1));round(hd,14);ctx.tint(hd,Color3.fromRGB(5,60,166),Color3.fromRGB(3,37,102));ctx.stars(hd)
 ctx.selector(hd,s.Contract,8,7,mobile and 88 or 105,headH-14,function(b)if ctx.openContracts then ctx.openContracts(b)else s.Overlay="Contracts";ctx.refresh()end end,mobile and 14 or 18)
 if mobile then
  ctx.heading(text(hd,"LastPrice","",100,1,w-162,26,18,C.Text,B,RIGHT))
  text(hd,"PriceChange","",100,26,w-162,18,10,C.Green,M,RIGHT)
  local tools=ctx.gloss(button(hd,"ChartTools","···",w-50,6,42,headH-12,function()s.Overlay="Tools";ctx.refresh()end,C.Raised,C.Text,18),"Navy")
  tools.Border.Color=C.Cyan
 else
  ctx.caption(hd,"ContractName",c.Short,122,0,math.max(60,w-406),headH,14,C.Muted).TextTruncate=Enum.TextTruncate.AtEnd
  ctx.heading(text(hd,"LastPrice","",w-270,0,146,headH,27,C.Text,B,RIGHT))
  text(hd,"PriceChange","",w-117,0,104,headH,14,C.Green,M,RIGHT)
 end
 ctx.rule(hd,0,headH-1,w)
 local tb=frame(p,"Toolbar",0,headH,w,toolsH,C.Chart);tb.BackgroundTransparency=1
 local tx=8
 for _,tf in ipairs({"1m","5m","15m","1h","1D"})do
  local bw=mobile and(w-24)/5 or(w>=850 and 48 or 40)
  ctx.control(button(tb,"Time"..tf,tf,tx,4,bw-5,toolsH-9,function()s.Timeframe=tf;self:CancelPlacement();ctx.refresh()end,C.Panel,C.Text,12),tf==s.Timeframe);tx+=bw
 end
 if not mobile then
  tx+=12
  local items={"Pan","Crosshair","Trend","Line","Rect","|","Magnet","Clear"}
  local room=w-tx-(w>700 and 90 or 8)
  local bw=math.clamp(math.floor((room-12)/7),28,40)
  for _,name in ipairs(items)do
   if name=="|" then
    local divider=frame(tb,"ToolDivider",tx+4,10,1,toolsH-20,C.Cyan);divider.BackgroundTransparency=.6;tx+=12
   else
    local active=s.Tool==name or name=="Magnet"and s.Magnet
    local fg=active and C.Text or Color3.fromRGB(174,210,250)
    local b=button(tb,"Tool"..name,"",tx,4,bw-5,toolsH-8,function()self:Command(name)end,C.Panel,fg,14)
    ctx.control(b,active);b.Corners.CornerRadius=UDim.new(0,8)
    b.Border.Color=active and Color3.fromRGB(192,144,255)or Color3.fromRGB(26,88,166)
    b.Border.Thickness=active and 2 or 1
    b:SetAttribute("Tooltip",name=="Magnet"and"Magnet (hold Ctrl)"or name=="Clear"and"Clear drawings on this chart"or TOOL_NAMES[name])
    b:SetAttribute("Active",active==true)
    local cx,cy=(bw-5)/2,(toolsH-8)/2
    local ink=frame(b,"ToolIcon",cx-9,cy-9,18,18,C.Panel,b.ZIndex+2);ink.BackgroundTransparency=1
    local function path(x1,y1,x2,y2)line(ink,"Ink",x1,y1,x2,y2,fg,2,ink.ZIndex)end
    local function dot(x,y)
     local d=frame(ink,"Ink",x-2,y-2,4,4,fg,ink.ZIndex);round(d,2)
    end
    if name=="Pan"then
     path(4,2,4,15);path(4,2,14,11);path(4,15,8,11);path(8,11,14,11);path(9,12,12,17)
    elseif name=="Crosshair"then
     path(9,0,9,5);path(9,13,9,18);path(0,9,5,9);path(13,9,18,9);dot(9,9)
    elseif name=="Trend"then path(3,15,15,3);dot(3,15);dot(15,3)
    elseif name=="Line"then path(1,9,17,9);dot(9,9)
    elseif name=="Rect"then path(2,3,16,3);path(16,3,16,15);path(16,15,2,15);path(2,15,2,3)
    elseif name=="Magnet"then
     path(3,2,3,11);path(3,11,6,15);path(6,15,12,15);path(12,15,15,11);path(15,11,15,2)
     path(2,5,4,5);path(14,5,16,5)
    elseif name=="Clear"then
     path(3,5,15,5);path(6,2,12,2);path(5,6,6,16);path(6,16,12,16);path(12,16,13,6);path(9,8,9,13)
    end
    b.MouseEnter:Connect(function()
     b.Border.Color=active and Color3.fromRGB(219,188,255)or C.Cyan
     for _,part in ipairs(ink:GetChildren())do if part:IsA("Frame")then part.BackgroundColor3=C.Text end end
    end)
    b.MouseLeave:Connect(function()
     b.Border.Color=active and Color3.fromRGB(192,144,255)or Color3.fromRGB(26,88,166)
     for _,part in ipairs(ink:GetChildren())do if part:IsA("Frame")then part.BackgroundColor3=fg end end
    end)
    tx+=bw
   end
  end
  if w>700 then text(tb,"DemoData",ctx.Options.Preview and "PREVIEW"or"SIMULATED",w-86,0,74,toolsH,10,C.Muted,M,RIGHT)end
  ctx.rule(tb,0,toolsH-1,w)
 end
 self.Chrome={Header=hd,Toolbar=tb}
end
-- Floating controls inside the plot. Their highlight follows the view state on every paint.
function View:BuildControls(p,w,headH,toolsH,top,right,left,mobile)
 local ctx=self.Ctx local C=ctx.C local button=ctx.button
 local bh=mobile and 30 or 30 local bw=mobile and 58 or 60
 local x=w-right-3*(bw+4)-4 local y=headH+toolsH+(mobile and 28 or 4)
 local group={}
 for i,item in ipairs({{"ResetView","Reset",function()self:ResetView()end},{"AutoFit","Auto",function()self:AutoFit()end},{"GoLive","Live",function()self:GoLive()end}})do
  local b=button(p,item[1],item[2],x+(i-1)*(bw+4),y,bw,bh,item[3],C.Raised,C.Muted,11,9)
  b:SetAttribute("Tooltip",item[1]=="ResetView"and"Reset zoom, scale and position"or item[1]=="AutoFit"and"Fit price scale to visible candles (double-click the price axis)"or"Go to live price")
  group[item[1]]=b
 end
 self.Controls=group
end
function View:UpdateControls(view,defaultBars)
 local C=self.Ctx.C
 if not self.Controls then return end
 local function set(b,active,available)
  if not b or not b.Parent then return end
  self.Ctx.control(b,active)
  local color=(available or active)and C.Text or C.Muted
  if b.TextColor3~=color then b.TextColor3=color end
  b.ControlLabel.TextColor3=color
  local border=b:FindFirstChild("Border") if border then border.Color=active and C.Blue or C.Border end
  b:SetAttribute("Active",active)
 end
 local changed=not view.Follow or not view.AutoY or math.abs(view.Bars-defaultBars)>0.5
 set(self.Controls.ResetView,false,changed)
 set(self.Controls.AutoFit,view.AutoY,not view.AutoY)
 set(self.Controls.GoLive,view.Follow,not view.Follow)
end
function View:BuildStyleBar(p,x,y,mobile)
 local ctx=self.Ctx local C=ctx.C local d=self:SelectedDrawing()
 if not d or ctx.Options.Preview then return end
 local frame,text,button,stroke,round=ctx.frame,ctx.text,ctx.button,ctx.stroke,ctx.round
 local sw=mobile and 30 or 22 local gap=4 local rect=d.Kind=="Rect"
 if mobile then sw=30 end
 local rows=1
 local rowH=sw+8
 local groupW=4*(sw+gap)
 local bar=frame(p,"DrawingStyle",x,y,100,rows*rowH,Color3.new(1,1,1),10);round(bar,12);stroke(bar,C.Cyan).Thickness=2
 ctx.tint(bar,Color3.fromRGB(8,56,150),Color3.fromRGB(3,26,76))
 local maxX=0
 local function swatches(label,field,cx,cy,transparent)
  text(bar,label.."Label",label,cx,cy,32,sw,10,C.Muted,ctx.M)
  cx+=34
  for _,key in ipairs(Tools.Colors)do
   local b=button(bar,field..key,"",cx,cy,sw,sw,function()self:SetStyle(field,key)end,C.Chart,d[field]==key and C.Text or C.Border,10,11)
   local chip=frame(b,"Chip",4,4,sw-8,sw-8,self:Palette(key),12);round(chip,3)
   if transparent then chip.BackgroundTransparency=0.45 end
   if d[field]==key then b:SetAttribute("Active",true);local st=b:FindFirstChild("Border");if st then st.Color=C.Text;st.Thickness=2 end end
   cx+=sw+gap
  end
  return cx
 end
 local cx=swatches("Line","Border",8,4)
 if rect then
  local fy=4 cx+=6
  if mobile then
   -- One chip that cycles the fill colour keeps the row inside a phone-width chart.
   local b=button(bar,"FillCycle","",cx,fy,sw,sw,function()self:CycleFill()end,C.Chart,C.Border,10,11)
   local chip=frame(b,"Chip",4,4,sw-8,sw-8,self:Palette(d.Fill or "Blue"),12);round(chip,3);chip.BackgroundTransparency=0.45
   cx+=sw+gap
  else cx=swatches("Fill","Fill",cx,fy,true)end
  local pct=math.round((d.Opacity or 0.15)*100)
  ctx.gloss(button(bar,"FillOpacity",pct.."%",cx,fy,46,sw,function()self:CycleOpacity()end,C.Raised,C.Text,12,11),"Navy")
  maxX=math.max(maxX,cx+46)
  if rows==1 then cx+=52 end
 end
 local dx=rows==2 and(8+34+groupW+2)or cx+4
 ctx.gloss(button(bar,"DeleteDrawing","Delete",dx,4,56,sw,function()self:DeleteSelected()end,C.Raised,C.Text,12,11),"Pink")
 maxX=math.max(maxX,dx+56)
 bar.Size=UDim2.fromOffset(maxX+8,rows*rowH)
end

-------------------------------------------------------------------------------------------------
-- Painting
local function odd(n) n=math.floor(n) if n%2==0 then n-=1 end return n end
function View:Paint(x,y,w,h,mobile,compact,updating)
 -- Pointer movement only changes overlays. Keep candle geometry and axis work off this path.
 if updating and not self.Dirty and self.HoverDirty and self.Geometry and self.OverlayPool then
  self:PaintOverlay(self.Geometry);self:UpdateCursor();self.HoverDirty=false
  return
 end
 self.Dirty=false;self.HoverDirty=false
 local ctx=self.Ctx local C,s,session,Market=ctx.C,self.S,ctx.Session,ctx.Market
 local frame,text,dash,line,stroke,round,rule=ctx.frame,ctx.text,ctx.dash,ctx.line,ctx.stroke,ctx.round,ctx.rule
 local N,M=ctx.N,ctx.M
 local paintStart=os.clock()
 w=math.floor(w) h=math.floor(h)
 local c=Market.Contracts[s.Contract];local last=session.Prices[s.Contract];local held=session.Positions[s.Contract]
 local canvas=ctx.Canvas
 local p=updating and canvas:FindFirstChild("Chart") or frame(canvas,"Chart",x,y,w,h,C.Chart)
 if not p then return end
 self.Mobile=mobile
 local short=h<260
 local headH=mobile and 48 or short and 44 or 56;local toolsH=mobile and 42 or short and 34 or 40;local footH=(mobile or short)and 0 or 26
 if not updating then ctx.panel(p);p.ClipsDescendants=true;self:BuildChrome(p,w,h,mobile,headH,toolsH)end
 local price=p.Header:FindFirstChild("LastPrice");if price then price.Text=Market.Number(last)end
 local change=p.Header:FindFirstChild("PriceChange")
 if change then local open=(session.Quotes[s.Contract]or{}).Open or c.Last;local diff=last-open;change.Text=string.format("%s %.2f%%",diff>=0 and"↑"or"↓",math.abs(diff/open*100));change.TextColor3=diff>=0 and C.Green or C.Red end
 local ph=math.max(80,h-headH-toolsH-footH)
 local plot=p:FindFirstChild("CandlestickPlot")or frame(p,"CandlestickPlot",0,headH+toolsH,w,ph,C.Chart);plot.ClipsDescendants=true
 local allData=session:Candles(s.Contract,s.Timeframe)
 if #allData==0 then
  local message=ctx.Options.Preview and "Studio edit preview · Press Play to start the market"or session.Ready and "Loading executed trades · simulated"or session.ConnectionStatus or "Connecting to the simulated exchange"
  local waiting=plot:FindFirstChild("Waiting")
  if waiting then waiting.Text=message else
   waiting=text(plot,"Waiting",message,12,math.max(20,ph/2-30),w-24,40,mobile and 15 or 18,C.Text,ctx.B,CENTER)
   ctx.heading(waiting);waiting.TextWrapped=true
   local sub=text(plot,"WaitingNote",mobile and "Waiting for executed trades." or "Candles appear as soon as the exchange sends executed trades.",12,math.max(20,ph/2-30)+42,w-24,20,11,C.Muted,M,CENTER)
   sub.TextWrapped=true
  end
  self.Geometry=nil;return
 end
 local waiting=plot:FindFirstChild("Waiting");if waiting then waiting:Destroy()end
 local waitingNote=plot:FindFirstChild("WaitingNote");if waitingNote then waitingNote:Destroy()end
 local right=mobile and 65 or 82;local left=14;local top=26 -- single OHLC row
 local bottom=ph-29 -- the price plot now uses the former volume space
 local chartH=bottom-top local pw=w-right-left
 local levels={last}
 if held and s.Levels then for _,key in ipairs({"Entry","Stop","Target"})do local n=held[key];if n then table.insert(levels,n)end end end
 -- Working limit and stop entries for this instrument, straight from the server's order list (the
 -- session keeps the last server copy). Filled or cancelled orders disappear with the next packet.
 local pendingOrders={}
 for _,o in ipairs(session.Orders or {})do
  if o.Contract==s.Contract and not o.Protection and(o.Type=="Limit"or o.Type=="Stop")and(o.Quantity or 0)>0 and o.Price then table.insert(pendingOrders,o)end
 end
 table.sort(pendingOrders,function(a,b)if a.Price~=b.Price then return a.Price>b.Price end return a.Id<b.Id end)
 local viewKey=s.Contract..":"..s.Timeframe
 local state=self.Views[viewKey];if not state then state={};self.Views[viewKey]=state end
 local view=Viewport.Resolve(state,allData,s.Timeframe,c.Tick,mobile,levels,pw)
 local drag=self.Drag
 local adjustment=drag and drag.Kind=="Protection" and drag or self.Pending
 if adjustment and(adjustment.Key~=viewKey or adjustment.Base~=session.AccountKey or not held or held.Id~=adjustment.Id or held.Triggered or not held[adjustment.Field])then adjustment=nil end
 local orderAdjustment=drag and drag.Kind=="Order" and drag or self.OrderPending
 if orderAdjustment and(orderAdjustment.Key~=viewKey or orderAdjustment.Base~=session.AccountKey or not self:WorkingOrder(orderAdjustment.Id))then orderAdjustment=nil end
 local frozenAdjustment=adjustment or orderAdjustment or(drag and drag.Kind=="Edit"and drag)
 if frozenAdjustment then
  -- Hold the scale under the pointer while quotes arrive and until the server acknowledges.
  local frozen=table.clone(frozenAdjustment.View)
  local first=Viewport.LowerBound(allData,frozen.Left-frozen.Interval) local lastIndex=Viewport.LowerBound(allData,frozen.Right+frozen.Interval)-1
  frozen.Data=table.move(allData,first,math.max(first-1,lastIndex),1,{})
  view=frozen
 end
 local data=view.Data
 if not self.Pool or self.Pool.Root~=plot or self.PoolKey~=viewKey then self.Pool=PaintPool.new(plot);self.PoolKey=viewKey;self.Base=nil end
 local pool=self.Pool local entries=pool.Entries
 pool:Begin(false);ctx.setPainting(pool)
 local priceLayer=frame(plot,"PriceLayer",left,top,pw,chartH,C.Chart,2);priceLayer.BackgroundTransparency=1;priceLayer.ClipsDescendants=true
 -- One transform for candles, labels, levels, drawings and the crosshair. Coordinates are rounded
 -- once, relative to a base that only changes when the scale changes, so a pan moves every mark rigidly.
 local pxs=pw/(view.Right-view.Left) local ppp=chartH/(view.High-view.Low)
 local base=self.Base
 if not base or math.abs(base.Pxs/pxs-1)>1e-9 or math.abs(base.Ppp/ppp-1)>1e-9 or base.W~=pw or base.H~=chartH then
  base={Pxs=pxs,Ppp=ppp,T=view.Left,P=view.High,W=pw,H=chartH};self.Base=base
 end
 local bpx,bpp,bt,bp=base.Pxs,base.Ppp,base.T,base.P
 local sx=math.floor((bt-view.Left)*bpx+0.5) local sy=math.floor((view.High-bp)*bpp+0.5)
 local function rx(t)return math.floor((t-bt)*bpx+0.5)end
 local function ry(n)return math.floor((bp-n)*bpp+0.5)end
 local function X(t)return sx+rx(t)end
 local function Y(n)return sy+ry(n)end
 -- Price and time axis labels stay anchored to the data without chart grid lines.
 local priceTicks=Viewport.PriceTicks(view.Low,view.High,c.Tick,compact and 3 or mobile and 5 or math.max(4,math.floor(chartH/45)))
 local levelY={} for _,n in ipairs(levels)do table.insert(levelY,top+Y(n))end
 for _,o in ipairs(pendingOrders)do table.insert(levelY,top+Y(o.Price))end
 for _,n in ipairs(priceTicks)do
  local py=top+Y(n)
  if py>=top and py<=bottom then
   local overlaps=false for _,ly in ipairs(levelY)do if math.abs(ly-py)<17 then overlaps=true end end
   if not overlaps and py>=top+6 and py<=bottom-6 then text(plot,"PriceAxis",Market.Number(n),w-right+3,py-9,right-10,18,11,C.Muted,N,RIGHT)end
  end
 end
 local timeTicks,timeStep=Viewport.TimeTicks(view.Left,view.Right,view.Interval,mobile and 3 or math.max(3,math.floor(pw/150)))
 for _,t in ipairs(timeTicks)do
  local px=left+X(t)
  if px>=left and px<=left+pw then
   local label=timeStep>=86400 and("DAY "..(math.floor(t/86400)+1))or string.format("%02d:%02d",math.floor(t/3600)%24,math.floor(t/60)%60)
   text(plot,"TimeAxis",label,math.clamp(px-24,4,w-right-52),ph-22,48,20,10,C.Muted,N,CENTER)
  end
 end
 text(plot,"Watermark","GET FUNDED!",0,math.floor(ph*.41),w-right,48,mobile and 28 or 43,Color3.fromRGB(31,87,178),ctx.B,CENTER).TextTransparency=.6
 -- Candles. Each candle's objects are keyed by its time; colour comes only from its own open/close.
 local sp=view.Interval*bpx
 local bw=sp>=5 and math.clamp(odd(sp*0.7),3,29) or sp>=3 and 2 or 1
 local half=bw>=3 and(bw-1)//2 or 0
 local strip=frame(priceLayer,"CandleStrip",sx,sy,1,1,C.Chart,1);strip.BackgroundTransparency=1
 local function place(o,px,py,pw2,ph2)
  local e=entries[o]
  if e.X~=px or e.Y~=py then e.X=px e.Y=py o.Position=UDim2.fromOffset(px,py)end
  if e.W~=pw2 or e.H~=ph2 then e.W=pw2 e.H=ph2 o.Size=UDim2.fromOffset(pw2,ph2)end
 end
 local function paint(o,color,z,transparency)
  local e=entries[o]
  if e.C~=color then e.C=color o.BackgroundColor3=color end
  if not e.Init then e.Init=true o.BorderSizePixel=0 o.ZIndex=z o.BackgroundTransparency=transparency or 0 end
 end
 local function finish(o,radius,lit)
  pool:Props(pool:Get("UICorner","CandleCorners",o),{CornerRadius=UDim.new(0,radius)})
  pool:Props(pool:Get("UIGradient","CandleLight",o),{Color=CANDLE_LIGHT,Rotation=90,Enabled=lit})
 end
 local tick=c.Tick
 for _,d in ipairs(data)do
  local dir=Tools.Direction(d,tick)
  local color=dir>0 and C.Green or dir<0 and C.Red or C.Muted
  local cx=rx(d.Time)
  local yH,yL,yO,yC=ry(d.High),ry(d.Low),ry(d.Open),ry(d.Close)
  local bodyTop=math.min(yO,yC) local bodyH=dir==0 and 1 or math.max(1,math.abs(yO-yC))
  local detailed=bw>=7 and bodyH>=5 and dir~=0
  local wickW=bw>=7 and 2 or 1
  local wickX=cx-(wickW-1)//2
  local wick=pool:Get("Frame","Wick",strip,d.Time);paint(wick,color,1);place(wick,wickX,yH,wickW,math.max(1,yL-yH))
  if detailed then
   -- The silhouette stays within the exact open/close vertical range.
   local edge=pool:Get("Frame","CandleEdge",strip,d.Time);paint(edge,CANDLE_INK,1);place(edge,cx-half-1,bodyTop,bw+2,bodyH)
   finish(edge,3,false)
  end
  local body=pool:Get("Frame","Candle",strip,d.Time);paint(body,color,2);place(body,cx-half,bodyTop,bw,bodyH)
  finish(body,detailed and 2 or 0,detailed)
  local be=entries[body] if not be.Tagged then be.Tagged=true body:SetAttribute("Time",d.Time)end
  if detailed then
   local highlight=pool:Get("Frame","CandleHighlight",body);paint(highlight,CANDLE_GLEAM,4,.35)
   place(highlight,2,0,bw-4,1)
   if bw>=11 and bodyH>=9 then
    local reflection=pool:Get("Frame","CandleReflection",body);paint(reflection,CANDLE_GLEAM,3,.68)
    place(reflection,1,2,1,bodyH-4)
   end
  end
 end
 -- Position levels and live price.
 local protectionHits={}
 local placedTags={} -- left-side tag rectangles, so a later tag can step aside instead of overlapping
 local function level(n,value,color,width,field,opts)
  local py=top+Y(n);if py<top or py>bottom then return end;dash(plot,left,py,pw,color,5,3)
  if field then table.insert(protectionHits,{Field=field,Y=py-top,Width=width})end
  local th=opts and opts.Height or 20
  local ty=math.clamp(py-th/2,top,bottom-th) local tx=left
  if opts then
   for _,r in ipairs(placedTags)do if ty<r.Y+r.H+2 and ty+th>r.Y-2 then tx=math.max(tx,r.X+r.W+6)end end
  end
  table.insert(placedTags,{X=tx,Y=ty,W=width,H=th})
  local tag=frame(plot,field and field.."Handle"or opts and opts.Name or"LevelTag",tx,ty,width,th,C.Panel,4);round(tag,opts and 7 or 2);stroke(tag,color).Thickness=opts and 2 or 1
  tag:SetAttribute("Price",n)
  local label=text(tag,"Label",value,opts and 6 or 5,0,width-(opts and 12 or 10),th,opts and opts.Size or 10,color,opts and opts.Font or M,opts and CENTER or nil,5)
  if opts then tag:SetAttribute("Text",value);label.TextStrokeTransparency=1 end
  local tag2=frame(plot,"PriceTag",w-right,py-10,right,20,C.Raised,4)
  text(tag2,"Price",Market.Number(n),3,0,right-9,20,11,color,N,RIGHT,5)
 end
 if held and s.Levels then
  for _,field in ipairs({"Target","Stop"})do
   local n=adjustment and adjustment.Field==field and adjustment.Price or held[field]
   if n then
    local editable=not ctx.Options.Preview and not held.Triggered
    local moving=adjustment and adjustment.Field==field
    local title=field=="Stop"and(mobile and"SL "or"STOP LOSS ")or(mobile and"TP "or"TAKE PROFIT ")
    local suffix=moving and(adjustment.RequestId and" ..."or" *")or""
    level(n,(editable and"↕ "or"")..title..Market.Signed((n-held.Entry)*held.Quantity*c.Multiplier*held.Direction)..suffix,
     field=="Stop"and C.Red or C.Green,mobile and 116 or 198,editable and field or nil)
   end
  end
  -- Direction and contract count only ("Long 5" / "Short 5"), sized to its text so it never clips.
  local label=(held.Direction>0 and"Long "or"Short ")..held.Quantity
  local size=mobile and 14 or 17
  local tw=TextService:GetTextSize(label,size,ctx.B,Vector2.new(400,60)).X
  level(held.Entry,label,held.Direction>0 and C.Green or C.Red,math.ceil(tw)+20,nil,{Name="EntryTag",Size=size,Height=mobile and 26 or 30,Font=ctx.B})
 end
 -- Pending orders: a dashed line at the order price with a side/quantity/price tag at the right of the
 -- plot and an axis tag. Orders beyond the visible range are pinned to the top or bottom edge.
 local markers={}
 do
  local th=mobile and 32 or 28 local size=mobile and 14 or 15
  local cancelW=mobile and 32 or 28
  local rightTags={}
  local function place(ty)
   for _=1,#rightTags+1 do
    local moved=false
    for _,r in ipairs(rightTags)do if ty<r+th+2 and ty+th>r-2 then ty=r+th+3 moved=true end end
    if not moved then break end
   end
   table.insert(rightTags,ty) return ty
  end
  for _,o in ipairs(pendingOrders)do
   local buy=o.Direction==1
   local color=buy and C.Green or C.Red
   local moving=orderAdjustment and orderAdjustment.Id==o.Id
   local orderPrice=moving and orderAdjustment.Price or o.Price
   local label=(o.Type=="Stop"and"Stop "or"Limit ")..(buy and"Buy "or"Sell ")..o.Quantity
   if o.Status=="Triggered"then label..=" · triggered" end
   local py=top+Y(orderPrice) local inside=py>=top and py<=bottom
   local text2=label..(moving and(orderAdjustment.RequestId and" …"or" *")or"")
   local tw=math.ceil(TextService:GetTextSize(text2,size,ctx.B,Vector2.new(600,60)).X)+18+cancelW
   -- Tags sit at the right of the plot, so they stay below the Reset/Auto/Live controls there.
   local tagTop=math.max(top,math.min(mobile and 62 or 38,bottom-th))
   local ty=place(inside and math.clamp(py-th/2,tagTop,bottom-th)or(py<top and tagTop or bottom-th-2))
   if inside then dash(plot,left,py,pw,color,9,3,2) end
   local tag=frame(plot,"OrderTag",math.max(left,left+pw-tw-6),ty,tw,th,C.Panel,4);round(tag,6);local st=stroke(tag,color);st.Thickness=2
   if not inside then tag.BackgroundTransparency=.15;st.Transparency=.35 end
   tag:SetAttribute("OrderId",o.Id);tag:SetAttribute("Price",orderPrice);tag:SetAttribute("Text",text2)
   local t=text(tag,"Label",text2,4,0,tw-cancelW-8,th,size,color,ctx.B,CENTER,5);t.TextStrokeTransparency=1
   -- Separate X hit region on the stable chart input surface (pooled visual objects never own input).
   local cancel=frame(tag,"Cancel",tw-cancelW,0,cancelW,th,C.Raised,5);round(cancel,5)
   text(cancel,"Label","X",0,0,cancelW,th,size,color,ctx.B,CENTER,6)
   local tx=math.max(0,pw-tw-6)
   table.insert(markers,{Id=o.Id,Price=orderPrice,ConfirmedPrice=o.Price,Quantity=o.Quantity,Type=o.Type,Label=label,Visible=inside,
    Y=inside and py-top or nil,X=tx,Top=ty-top,W=tw,H=th,CancelX=tx+tw-cancelW})
   if inside then
    local tag2=frame(plot,"OrderPriceTag",w-right,py-10,right,20,C.Panel,4);stroke(tag2,color)
    text(tag2,"Price",Market.Number(orderPrice),3,0,right-9,20,11,color,N,RIGHT,5)
   end
  end
 end
 self.OrderMarkers=markers
 local ly=top+Y(last);if ly>=top and ly<=bottom then dash(plot,left,ly,pw,C.Cyan,4,2)end;ly=math.clamp(ly,top+10,bottom-10)
 local badge=frame(plot,"LastPrice",w-right,ly-10,right,20,C.Cyan,5);round(badge,5)
 text(badge,"Price",Market.Number(last),2,0,right-8,20,11,C.Bg,N,RIGHT,6)
 -- Geometry is published before drawings so hit-testing and snapping use exactly what is on screen.
 local g={Key=viewKey,State=state,View=view,Plot=plot,Left=left,Top=top,Width=pw,Height=chartH,RightW=right,PlotH=ph,W=w,
  X=X,Y=Y,Pxs=pxs,Ppp=ppp,Data=data,All=allData,ProtectionHits=protectionHits,Mobile=mobile}
 self.Geometry=g
 ctx.setPainting(nil);pool:Finish()
 self:PaintOverlay(g)
 -- Input surface and view controls (created once per full render).
 local inputSurface=p:FindFirstChild("ChartInput")
 if not inputSurface then
  inputSurface=frame(p,"ChartInput",left,headH+toolsH+top,pw+right,chartH,C.Chart,8);inputSurface.BackgroundTransparency=1;inputSurface.Active=true
  inputSurface.InputBegan:Connect(function(ev)self:Began(ev)end)
  inputSurface.InputChanged:Connect(function(ev)
   if ev.UserInputType==Enum.UserInputType.MouseWheel then self:Wheel(ev)
   elseif ev.UserInputType==MOVE then self.Hover=Vector2.new(ev.Position.X,ev.Position.Y);self.HoverDirty=true end
  end)
  inputSurface.MouseLeave:Connect(function()if not self.Drag then self.Hover=nil;self.HoverDirty=true;self:SetCursor("")end end)
  self:BuildControls(p,w,headH,toolsH,top,right,left,mobile)
  -- Phones: one row over the timeframe bar so the small plot and view controls stay visible.
  self:BuildStyleBar(p,mobile and 4 or left+6,mobile and headH+3 or headH+toolsH+top+6,mobile)
 end
 self:UpdateControls(view,mobile and Viewport.DefaultBars.Mobile or Viewport.DefaultBars.Desktop)
 self:UpdateCursor()
 local root=ctx.Root
 root:SetAttribute("ChartFollowingLive",view.Live);root:SetAttribute("ChartFollowing",view.Follow);root:SetAttribute("ChartAutoFit",view.AutoY)
 root:SetAttribute("ChartRightTime",view.Right);root:SetAttribute("ChartLeftTime",view.Left)
 root:SetAttribute("ChartLow",view.Low);root:SetAttribute("ChartHigh",view.High);root:SetAttribute("ChartBars",view.Bars)
 root:SetAttribute("ChartMaxBars",view.MaxBars);root:SetAttribute("ChartHistory",#allData);root:SetAttribute("ChartBodyWidth",bw)
 root:SetAttribute("VisibleCandles",#data);root:SetAttribute("DrawingCount",#s.Drawings)
 root:SetAttribute("ChartTool",s.Tool);root:SetAttribute("ChartMagnet",s.Magnet);root:SetAttribute("ChartMagnetActive",self:MagnetOn())
 root:SetAttribute("SelectedDrawing",self.Selected);root:SetAttribute("CanUndo",self.History:CanUndo());root:SetAttribute("CanRedo",self.History:CanRedo())
 root:SetAttribute("StopPrice",held and held.Stop);root:SetAttribute("TargetPrice",held and held.Target)
 root:SetAttribute("ProtectionPreviewPrice",adjustment and adjustment.Price)
 root:SetAttribute("ProtectionPending",self.Pending~=nil)
 root:SetAttribute("ChartDragging",self.Drag~=nil);root:SetAttribute("ChartDragKind",self.Drag and self.Drag.Kind)
 root:SetAttribute("ChartOrderMarkers",#markers)
 root:SetAttribute("OrderAmendPending",self.OrderPending~=nil)
 root:SetAttribute("EntryLabel",held and s.Levels and((held.Direction>0 and"Long "or"Short ")..held.Quantity)or nil)
 if not mobile and footH>0 then
  local foot=p:FindFirstChild("Footer")
  if not foot then
   foot=frame(p,"Footer",0,h-footH,w,footH,C.Chart);foot.BackgroundTransparency=1;rule(foot,0,0,w)
   text(foot,"Date","Green ↑ Up     Red ↓ Down     — Doji",12,1,math.min(360,w-160),footH-1,10,C.Muted,ctx.F)
   text(foot,"Time","",w-151,1,139,footH-1,9,C.Muted,N,RIGHT)
  end
  foot.Time.Text=string.format("%02d:%02d:%02d · %dx",math.floor(session.Time/3600)%24,math.floor(session.Time/60)%60,math.floor(session.Time)%60,session.Speed)
 end
 if RunService:IsStudio()then self:Audit(viewKey,allData,data,tick,C)end
 self.PaintCount+=1;local cost=(os.clock()-paintStart)*1000;self.PaintTotal+=cost;self.PaintMax=math.max(self.PaintMax,cost);self.LastCost=cost
end
-- Studio-only integrity checks: completed candles never change, and every candle object's colour
-- matches its own OHLC direction.
function View:Audit(viewKey,allData,data,tick,C)
 if self.PaintCount%10~=0 then return end
 local seen=self.Seen[viewKey] if not seen then seen={} self.Seen[viewKey]=seen end
 for i=math.max(1,#allData-300),#allData-1 do
  local d=allData[i] local sig=d.Open..":"..d.High..":"..d.Low..":"..d.Close..":"..d.Volume
  local prior=seen[d.Time]
  if prior and prior~=sig then self.Mutations+=1 end
  seen[d.Time]=sig
 end
 local pool=self.Pool local strip=self.Geometry and self.Geometry.Plot:FindFirstChild("PriceLayer")
 strip=strip and strip:FindFirstChild("CandleStrip")
 if strip then
  local byTime={} for _,d in ipairs(data)do byTime[d.Time]=d end
  for _,o in ipairs(strip:GetChildren())do
   if o.Name=="Candle" and o.Visible then
    local d=byTime[o:GetAttribute("Time")]
    local dir=d and Tools.Direction(d,tick)
    local expected=dir and(dir>0 and C.Green or dir<0 and C.Red or C.Muted)
    if not expected or o.BackgroundColor3~=expected then self.ColorMismatches+=1 end
   end
  end
 end
 self.Ctx.Root:SetAttribute("CompletedCandleMutations",self.Mutations)
 self.Ctx.Root:SetAttribute("CandleColorMismatches",self.ColorMismatches)
end

function View:PaintDrawings(layerParent,g)
 local ctx=self.Ctx local C=ctx.C local frame,dash,line,stroke,round=ctx.frame,ctx.dash,ctx.line,ctx.stroke,ctx.round
 local layer=frame(layerParent,"DrawingLayer",0,0,g.Width,g.Height,C.Chart,6);layer.BackgroundTransparency=1
 local X,Y=g.X,g.Y local mobile=g.Mobile
 local hr=mobile and 6 or 4
 local function handle(hx,hy)
  local hnd=frame(layer,"Handle",hx-hr,hy-hr,hr*2+1,hr*2+1,C.Bg,9);stroke(hnd,C.Blue)
 end
 local function shape(d,selected,preview)
  local border=self:Palette(d.Border or "Blue")
  if d.Kind=="Rect" then
   local x1,x2=math.min(X(d.T1),X(d.T2)),math.max(X(d.T1),X(d.T2))
   local y1,y2=math.min(Y(d.P1),Y(d.P2)),math.max(Y(d.P1),Y(d.P2))
   local r=frame(layer,"Rect",x1,y1,math.max(1,x2-x1),math.max(1,y2-y1),self:Palette(d.Fill or "Blue"),6)
   r.BackgroundTransparency=1-(d.Opacity or 0.15)
   local st=stroke(r,border);st.Thickness=selected and 2 or 1;st.Transparency=preview and 0.35 or 0
   if selected then for _,pt in ipairs(Tools.Points(d))do handle(X(pt.Time),Y(pt.Price))end end
   if selected and not preview then
    -- Right-edge midpoint dot: drag it to extend the rectangle horizontally (left edge and prices fixed).
    local ex,ey=Tools.ExtendPoint(d,X,Y) local dr=mobile and 7 or 5
    local active=self.Drag and self.Drag.Kind=="Edit"and self.Drag.Part=="Extend"and self.Drag.Target==d
    local dot=frame(layer,"ExtendHandle",math.floor(ex-dr+0.5),math.floor(ey-dr+0.5),dr*2+1,dr*2+1,active and C.Text or border,9);round(dot,dr+1)
    local ds=stroke(dot,active and border or C.Text);ds.Thickness=2
   end
  elseif d.Kind=="Trend" then
   local ax,ay,bx,by=Tools.ClipSegment(X(d.T1),Y(d.P1),X(d.T2),Y(d.P2),g.Width,g.Height)
   if ax then line(layer,"UserTrend",ax,ay,bx,by,border,selected and 3 or 2,7).BackgroundTransparency=preview and 0.35 or 0 end
   if selected then handle(X(d.T1),Y(d.P1));handle(X(d.T2),Y(d.P2))end
  elseif d.Kind=="Line" then
   local py=Y(d.P1)
   if py>=0 and py<=g.Height then
    dash(layer,0,py,g.Width,border,4,7)
    if selected then frame(layer,"LineSelected",0,py,g.Width,1,border,7).BackgroundTransparency=0.55;handle(math.min(28,g.Width/2),py)end
   end
  end
 end
 for _,d in ipairs(self:Current())do shape(d,d.Id==self.Selected,false)end
 -- Placement preview and magnet indicator.
 local hoverPoint
 local drawingContext=DRAW[self.S.Tool] or self.Drag and(self.Drag.Kind=="Edit"or self.Drag.Kind=="Place"or self.Drag.Kind=="PlaceLine")
 if self.Hover and drawingContext and not self:Blocked() then
  local hx,hy=self:Local(self.Hover)
  if hx>=0 and hx<=g.Width and hy>=0 and hy<=g.Height then hoverPoint=self:PointAt(hx,hy,true,self.LastTouch)end
 end
 local placement=self.Placement
 if placement then
  local b=placement.Waiting and hoverPoint or placement.B
  if b then shape(Tools.Normalize({Kind=placement.Kind,T1=placement.A.Time,P1=placement.A.Price,T2=b.Time,P2=b.Price}),false,true)end
 elseif self.Drag and self.Drag.Kind=="PlaceLine" then
  shape(Tools.Normalize({Kind="Line",P1=self.Drag.Point.Price,T1=self.Drag.Point.Time}),false,true)
 elseif self.S.Tool=="Line" and hoverPoint and not self.Drag then
  local py=Y(hoverPoint.Price);dash(layer,0,py,g.Width,C.Muted,4,7)
 end
 -- Use the exact click conversion, including tick rounding and OHLC magnet snapping.
 local ready=self.S.Tool=="Trend" and hoverPoint and not self.LastTouch and not self.Pending and not self.OrderPending
 if ready and self.Drag and self.Drag.Kind~="Place" then ready=false end
 if ready then
  local dx,dy=X(hoverPoint.Time),Y(hoverPoint.Price)
  local dot=frame(layer,"TrendReadyDot",dx-3,dy-3,6,6,C.Text,10);round(dot,3)
  stroke(dot,C.Blue).Thickness=2
  ctx.Root:SetAttribute("TrendReadyTime",hoverPoint.Time);ctx.Root:SetAttribute("TrendReadyPrice",hoverPoint.Price)
 else ctx.Root:SetAttribute("TrendReadyTime",nil);ctx.Root:SetAttribute("TrendReadyPrice",nil) end
 local snap=hoverPoint and hoverPoint.Snap
 if snap then
  local ring=frame(layer,"SnapTarget",X(snap.Time)-5,Y(snap.Price)-5,11,11,C.Bg,9);ring.BackgroundTransparency=1
  round(ring,6);local st=stroke(ring,C.Text);st.Transparency=0.25
 end
 self.SnapShown=snap and snap.Field or nil
 ctx.Root:SetAttribute("SnapTarget",snap and(snap.Field..":"..snap.Price)or nil)
end
-- A separate pool lets hover, drawing previews and crosshair labels update without touching candles.
-- Full paints also refresh it, so incoming quotes and changed transforms are always reflected.
function View:PaintOverlay(g)
 local ctx=self.Ctx local start=os.clock()
 if not self.OverlayPool or self.OverlayPool.Root~=g.Plot then self.OverlayPool=PaintPool.new(g.Plot)end
 local pool=self.OverlayPool
 pool:Begin(false);ctx.setPainting(pool)
 self:PaintDrawings(g.Plot.PriceLayer,g)
 self:PaintCrosshair(g.Plot,g)
 ctx.setPainting(nil);pool:Finish()
 self.OverlayPaintCount=(self.OverlayPaintCount or 0)+1
 self.OverlayPaintTotal=(self.OverlayPaintTotal or 0)+(os.clock()-start)*1000
end
function View:PaintCrosshair(plot,g)
 local ctx=self.Ctx local C,Market=ctx.C,ctx.Market local frame,text=ctx.frame,ctx.text
 local readout
 local hover=self.Hover
 local inspecting=hover and(not self.LastTouch or self.Drag and(self.Drag.Kind=="Inspect"or self.Drag.Kind=="Place"or self.Drag.Kind=="Edit"))
 local candle
 if inspecting then
  local x,y=self:Local(hover)
  if x>=0 and x<=g.Width and y>=0 and y<=g.Height then
   local v=g.View local t=v.Left+x/g.Pxs
   local magnet=self:MagnetOn()
   local best,bd=nil,math.huge
   local i=Viewport.LowerBound(g.Data,t)
   for j=math.max(1,i-1),math.min(#g.Data,i)do local d=math.abs(g.Data[j].Time-t);if d<bd then best,bd=g.Data[j],d end end
   if best and not magnet and bd>v.Interval*0.6 then best=nil end
   candle=best
   -- The lines follow the pointer. With the magnet (toolbar toggle or Ctrl held) the vertical line snaps
   -- to the nearest candle's centre and the horizontal line to that candle's nearest O/H/L/C in range.
   local cx=math.floor(x+0.5) local cy=math.floor(y+0.5) local n=v.High-y/g.Ppp
   local snapped
   if magnet and best then
    cx=g.X(best.Time)
    local radius=self.LastTouch and Tools.SnapRadius.Touch or Tools.SnapRadius.Mouse
    for _,field in ipairs({"Open","High","Low","Close"})do
     local fy=g.Y(best[field]) local dy=math.abs(fy-y)
     if dy<=radius then radius=dy;snapped=best[field];cy=fy end
    end
    if snapped then n=snapped end
   end
   local lineColor=C.Muted
   local vline=frame(plot,"CrossV",g.Left+cx,g.Top,1,g.Height,lineColor,6);vline.BackgroundTransparency=0.45
   local hline=frame(plot,"CrossH",g.Left,g.Top+cy,g.Width,1,lineColor,6);hline.BackgroundTransparency=0.45
   ctx.Root:SetAttribute("CrosshairX",cx);ctx.Root:SetAttribute("CrosshairSnapped",magnet and best~=nil)
   local tag=frame(plot,"CrossPrice",g.W-g.RightW,g.Top+cy-10,g.RightW,20,C.Raised,7)
   text(tag,"Price",Market.Number(Market.Snap(n,self.S.Contract)),3,0,g.RightW-9,20,11,C.Text,ctx.N,RIGHT,8)
   local stamp=(magnet and best)and best.Time or t
   local label=self.S.Timeframe=="1D"and("DAY "..(math.floor(stamp/86400)+1))or string.format("%02d:%02d",math.floor(stamp/3600)%24,math.floor(stamp/60)%60)
   local tt=frame(plot,"CrossTime",math.clamp(g.Left+cx-28,0,g.W-g.RightW-56),g.PlotH-23,56,20,C.Raised,7)
   text(tt,"Time",label,0,0,56,20,10,C.Text,ctx.N,CENTER,8)
  end
 end
 local recent=candle or g.All[#g.All]
 local dir=Tools.Direction(recent,Market.Contracts[self.S.Contract].Tick)
 local color=dir>0 and C.Green or dir<0 and C.Red or C.Muted
 local function hex(c3)return string.format("#%02X%02X%02X",math.round(c3.R*255),math.round(c3.G*255),math.round(c3.B*255))end
 local v=hex(color) local m=hex(C.Muted)
 local change=recent.Open~=0 and(recent.Close-recent.Open)/recent.Open*100 or 0
 local body=string.format('<font color="%s">O</font> <font color="%s">%s</font>  <font color="%s">H</font> <font color="%s">%s</font>  <font color="%s">L</font> <font color="%s">%s</font>  <font color="%s">C</font> <font color="%s">%s</font>  <font color="%s">%+.2f%%</font>',
  m,v,Market.Number(recent.Open),m,v,Market.Number(recent.High),m,v,Market.Number(recent.Low),m,v,Market.Number(recent.Close),v,change)
 readout=text(plot,"OHLC",body,12,5,g.W-24-(g.Mobile and 0 or 190),19,g.Mobile and 9 or 11,C.Muted,ctx.N,nil,7)
 readout.RichText=true;readout.TextTruncate=Enum.TextTruncate.AtEnd
 readout.Visible=not g.Mobile or candle~=nil
 ctx.Root:SetAttribute("CrosshairTime",candle and candle.Time or nil)
 -- Holding Ctrl turns the magnet on temporarily; say so while it is held.
 if self:CtrlDown()and not self.S.Magnet and not g.Mobile then
  local round,stroke=ctx.round,ctx.stroke
  -- Bottom-left of the price area, clear of the OHLC readout and the drawing style bar.
  local badge=frame(plot,"MagnetBadge",g.Left+6,g.Top+g.Height-28,112,22,C.Raised,7);round(badge,11);stroke(badge,C.Cyan)
  text(badge,"Label","Magnet · Ctrl",0,0,112,22,12,C.Text,ctx.B,CENTER,8).TextStrokeTransparency=1
 end
end

-------------------------------------------------------------------------------------------------
-- Cursor feedback (desktop)
function View:SetCursor(icon)
 if self.Cursor~=icon then self.Cursor=icon;pcall(function()UIS.MouseIcon=icon end)end
end
function View:UpdateCursor()
 if self.LastTouch or not UIS.MouseEnabled then return end
 local d=self.Drag local icon=""
 if d then
  icon=d.Kind=="Pan"and(d.Moved and CURSOR.Grab or CURSOR.Hand)or(d.Kind=="Scale"or d.Kind=="Protection"or d.Kind=="Order")and CURSOR.NS
   or d.Kind=="Edit"and((d.Part=="Slide"or d.Part=="Extend")and CURSOR.EW or d.Part=="Move"and CURSOR.Move or(d.Part=="Corner1"or d.Part=="Corner3")and CURSOR.NWSE or CURSOR.NESW)
   or CURSOR.Cross
  if d.Kind=="Edit"and d.Target.Kind=="Rect"and(d.Part=="Corner1"or d.Part=="Corner3")then
   -- Corner orientation depends on which way the rectangle is stored.
   local up=(d.Target.P1>d.Target.P2)==(d.Target.T1<d.Target.T2) icon=up and CURSOR.NWSE or CURSOR.NESW
  elseif d.Kind=="Edit"and d.Target.Kind=="Rect"and(d.Part=="Corner2"or d.Part=="Corner4")then
   local up=(d.Target.P1>d.Target.P2)==(d.Target.T1<d.Target.T2) icon=up and CURSOR.NESW or CURSOR.NWSE
  elseif d.Kind=="Edit"and d.Part~="Move"and d.Part~="Slide"and d.Part~="Extend"then icon=CURSOR.Move end
 elseif self.Hover and self.Geometry then
  local x,y=self:Local(self.Hover) local g=self.Geometry
  if y>=0 and y<=g.Height and x>=0 then
   if x>g.Width then icon=CURSOR.NS
   elseif DRAW[self.S.Tool]then icon=CURSOR.Cross
   else
    local hit=self:Hit(x,y,false)
    local prot=false
    for _,ph in ipairs(g.ProtectionHits)do if math.abs(y-ph.Y)<=6 then prot=true end end
    local grab=hit and(not hit.Interior or hit.Part=="Slide")
    local order,part=self:OrderHit(x,y,false)
    icon=order and(part=="Cancel"and CURSOR.Point or CURSOR.NS)or prot and CURSOR.NS or grab and((hit.Part=="Slide"or hit.Part=="Extend")and CURSOR.EW or hit.Part=="Move"and CURSOR.Move or CURSOR.Point)
     or self.S.Tool=="Crosshair"and CURSOR.Cross or CURSOR.Hand
   end
  end
 end
 self:SetCursor(icon)
end

-------------------------------------------------------------------------------------------------
-- Input
function View:Blocked()
 local s=self.S return not self.Geometry or s.Overlay or s.Sheet or self.Ctx.Options.Preview
end
function View:WorkingOrder(id)
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
function View:Began(ev)
 local kind=ev.UserInputType
 -- Right-click cancels an in-progress drawing or edit (Esc is reserved for the Roblox menu in-game).
 -- Otherwise it opens the order menu at the clicked price.
 if kind==MB2 then
  if self.Drag or self.Placement or DRAW[self.S.Tool] then self:Cancel();self.Ctx.refresh() else self:OpenOrderMenu(Vector2.new(ev.Position.X,ev.Position.Y))end
  return
 end
 if kind~=MB1 and kind~=MB3 and kind~=TOUCH then return end
 if self:Blocked()then return end
 local g=self.Geometry local s=self.S local session=self.Ctx.Session
 local pos=Vector2.new(ev.Position.X,ev.Position.Y)
 self.LastTouch=kind==TOUCH
 if kind==TOUCH then
  self.Touches[ev]=pos
  if count(self.Touches)>=2 then
   local d=self.Drag
   if not d or d.Kind=="Pan"or d.Kind=="Inspect"then self:StartPinch()end
   return
  end
 end
 if self.Drag then return end
 local x,y=self:Local(pos)
 if y<0 or y>g.Height or x<0 then return end
 local base={Input=ev,Type=kind,Start=pos,View=g.View,State=g.State,Width=g.Width,Height=g.Height,Moved=false}
 local function start(kindName,extra) local d=table.clone(base) d.Kind=kindName for k,v in pairs(extra or {})do d[k]=v end self.Drag=d self.Dirty=true return d end
 -- X consumes the gesture and only cancels its order; it can never become a chart drag.
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
 -- Stop and target labels keep priority over drawing tools.
 local held=session.Positions[s.Contract]
 if kind~=MB3 and held and not held.Triggered and not self.Pending then
  local chosen,distance=nil,math.huge
  for _,hit in ipairs(g.ProtectionHits)do
   local label=x<=hit.Width or x>=g.Width
   local tolerance=kind==TOUCH and(label and 22 or 14)or(label and 10 or 6)
   local d=math.abs(y-hit.Y)
   if d<=tolerance and d<distance then chosen=hit.Field;distance=d end
  end
  if chosen then
   start("Protection",{Field=chosen,Key=g.Key,Contract=s.Contract,Base=session.AccountKey,Id=held.Id,Original=held[chosen],Price=held[chosen]})
   self.Ctx.Root:SetAttribute("DraggingProtection",chosen);return
  end
 end
 if x>g.Width then
  -- Price axis: drag to scale, double-click/double-tap to restore auto-fit.
  local now=os.clock() local lastTap=self.LastAxisTap
  if lastTap and now-lastTap.Time<0.4 and(lastTap.Pos-pos).Magnitude<16 then self.LastAxisTap=nil;self:AutoFit();return end
  self.LastAxisTap={Time=now,Pos=pos}
  start("Scale");return
 end
 if self.Pending or self.OrderPending then return end
 if kind==MB3 then start("Pan");return end
 local tool=s.Tool
 if DRAW[tool]then
  local pt=self:PointAt(x,y,true,kind==TOUCH)
  if tool=="Line"then start("PlaceLine",{Point=pt});return end
  if self.Placement and self.Placement.Waiting then
   self.Placement.B=pt;self:CommitPlacement();self.Ctx.onIdle(true);return
  end
  self.Placement={Kind=tool,A=pt,B=pt};start("Place");return
 end
 if tool=="Crosshair"and kind==TOUCH then self.Hover=pos;start("Inspect");return end
 local hit=self:Hit(x,y,kind==TOUCH)
 -- With a mouse, pressing anywhere on a rectangle grabs it (selects it and slides it horizontally), so
 -- a drag on a rectangle never pans the chart. On touch an unselected interior still pans; tap to select.
 if hit and(not hit.Interior or(kind~=TOUCH and hit.Part=="Slide"))then
  local d=hit.Drawing
  start("Edit",{Part=hit.Part,Target=d,Original=Tools.Copy(d),Before=Tools.CopyList(s.Drawings),StartPoint=self:PointAt(x,y,false),SelectChanged=self.Selected~=d.Id})
  self.Selected=d.Id;return
 end
 start("Pan",{Click=hit and hit.Drawing.Id or false})
end
function View:StartPinch()
 local g=self.Geometry if not g then return end
 local a,b local list={} for input,pos in pairs(self.Touches)do table.insert(list,{input,pos})end
 a,b=list[1],list[2]
 if self.Drag and self.Drag.Kind=="Pan"then self.Drag=nil end
 local mid=(a[2]+b[2])/2
 local x=(mid.X-g.Plot.AbsolutePosition.X-g.Left)/g.Width
 self.Drag={Kind="Pinch",A=a[1],B=b[1],StartDistance=math.max(20,(a[2]-b[2]).Magnitude),StartFraction=x,StartMid=mid,View=g.View,State=g.State,
  Width=g.Width,Height=g.Height,Moved=true,Type=TOUCH}
 self.Hover=nil self.Dirty=true
end
function View:UpdatePinch()
 local d=self.Drag local pa,pb=self.Touches[d.A],self.Touches[d.B]
 if not pa or not pb then return end
 local g=self.Geometry
 local mid=(pa+pb)/2 local dist=math.max(20,(pa-pb).Magnitude)
 local fraction=(mid.X-g.Plot.AbsolutePosition.X-g.Left)/d.Width
 Viewport.Pinch(d.State,d.View,d.StartFraction,fraction,d.StartDistance/dist,mid.Y-d.StartMid.Y,d.Height)
 self.Dirty=true
end
function View:Changed(ev)
 local kind=ev.UserInputType
 if kind==TOUCH and self.Touches[ev]then self.Touches[ev]=Vector2.new(ev.Position.X,ev.Position.Y)end
 if kind==MOVE then self.LastTouch=false end
 local d=self.Drag
 if not d then return end
 if d.Kind=="Pinch"then if kind==TOUCH then self:UpdatePinch()end return end
 if d.Type==TOUCH then if ev~=d.Input then return end elseif kind~=MOVE then return end
 local pos=Vector2.new(ev.Position.X,ev.Position.Y)
 local delta=pos-d.Start
 if not d.Moved and delta.Magnitude<(d.Type==TOUCH and 8 or 4)then return end
 d.Moved=true
 self.Hover=pos
 if d.Kind=="Pan"then Viewport.Pan(d.State,d.View,delta.X,delta.Y,d.Width,d.Height)
 elseif d.Kind=="Scale"then Viewport.ScalePrice(d.State,d.View,delta.Y,d.Height)
 elseif d.Kind=="Protection"or d.Kind=="Order"then
  local Market=self.Ctx.Market local tick=Market.Contracts[d.Contract].Tick
  d.Price=math.max(tick,Market.Snap(d.Original-delta.Y/d.Height*(d.View.High-d.View.Low),d.Contract))
 elseif self.Geometry then
  local x,y=self:Local(pos)
  if d.Kind=="Edit"then
   -- A slide keeps the rectangle's own geometry, so it ignores the magnet.
   local pt=self:PointAt(x,y,d.Part~="Slide",d.Type==TOUCH)
   if d.Part=="Extend"and self:MagnetOn()then
    -- The extension only moves in time, so the magnet puts the edge on the nearest candle's centre.
    local data=self.Geometry.Data local i=Viewport.LowerBound(data,pt.Time) local best,bd=nil,math.huge
    for j=math.max(1,i-1),math.min(#data,i)do local dt=math.abs(data[j].Time-pt.Time) if dt<bd then best,bd=data[j],dt end end
    if best then pt={Time=best.Time,Price=pt.Price,Snap=pt.Snap} end
   end
   local Market=self.Ctx.Market
   Tools.Edit(d.Target,d.Original,d.Part,pt,{Time=pt.Time-d.StartPoint.Time,Price=pt.Snap and pt.Price-d.StartPoint.Price or Market.Snap(pt.Price-d.StartPoint.Price,self.S.Contract),
    MinWidth=self.Geometry.View.Interval})
  elseif d.Kind=="Place"then self.Placement.B=self:PointAt(x,y,true,d.Type==TOUCH)
  elseif d.Kind=="PlaceLine"then d.Point=self:PointAt(x,y,true,d.Type==TOUCH)
  end
 end
 self.Dirty=true
end
function View:Ended(ev)
 local kind=ev.UserInputType
 if kind==TOUCH then self.Touches[ev]=nil end
 local d=self.Drag if not d then return end
 if d.Kind=="Pinch"then
  if kind~=TOUCH then return end
  local remaining,pos=next(self.Touches)
  if remaining and self.Geometry then
   -- Lifting one finger continues as a one-finger pan from where it is.
   local g=self.Geometry
   self.Drag={Kind="Pan",Input=remaining,Type=TOUCH,Start=pos,View=g.View,State=g.State,Width=g.Width,Height=g.Height,Moved=true}
  else self:Finish(true)end
  return
 end
 if d.Type==TOUCH then if ev~=d.Input then return end elseif kind~=d.Type then return end
 self:Finish(ev.UserInputState~=Enum.UserInputState.Cancel)
end
function View:Finish(commit)
 local d=self.Drag if not d then return end
 self.Drag=nil
 local s=self.S local chrome=false
 self.Ctx.Root:SetAttribute("DraggingProtection",nil)
 if d.Kind=="Pan"then
  if not d.Moved and commit then
   local chosen=d.Click or nil
   if chosen~=self.Selected then self.Selected=chosen;chrome=true end
  end
  if d.Type==TOUCH then self.Hover=nil end
 elseif d.Kind=="Edit"then
  if not commit then for k in pairs(d.Target)do d.Target[k]=nil end for k,v in pairs(d.Original)do d.Target[k]=v end
  elseif d.Moved then self.History:Push(d.Before);chrome=true end
  if d.SelectChanged then chrome=true end
  if d.Type==TOUCH then self.Hover=nil end
 elseif d.Kind=="Place"then
  if not commit or not self.Placement then self.Placement=nil
  elseif d.Moved then self:CommitPlacement();chrome=true
  else self.Placement.Waiting=true end
 elseif d.Kind=="PlaceLine"then
  if commit then
   local before=Tools.CopyList(s.Drawings)
   local line=Tools.New("Line",d.Point,nil,s.Contract,s.Timeframe)
   table.insert(s.Drawings,line);self.History:Push(before);self.Selected=line.Id;s.Tool="Pan";chrome=true
  end
 elseif d.Kind=="CancelOrder"then
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
  if commit and d.Moved and d.Price~=d.Original then
   local ok,message,_,requestId=self.Ctx.Session:AmendProtection(d.Contract,d.Id,d.Field,d.Price,d.Original)
   if ok then
    d.RequestId=requestId;self.Pending=d
    task.delay(10,function()
     if self.Pending==d then self.Pending=nil;self.Dirty=true;self.Ctx.toast("Update not yet confirmed. Showing the last server price.")end
    end)
   else self.Ctx.toast(message)end
  end
 elseif d.Kind=="Inspect"then self.Hover=nil
 end
 self.Dirty=true
 self.Ctx.onIdle(chrome)
end
function View:CommitPlacement()
 local p=self.Placement self.Placement=nil
 local s=self.S local g=self.Geometry
 if not p or not p.B or not g then return end
 -- Ignore a zero-size shape (a click without a second point).
 local w=math.abs(g.X(p.A.Time)-g.X(p.B.Time)) local h=math.abs(g.Y(p.A.Price)-g.Y(p.B.Price))
 if(p.Kind=="Rect"and(w<3 or h<3))or(p.Kind=="Trend"and w+h<4)then return end
 local before=Tools.CopyList(s.Drawings)
 local d=Tools.New(p.Kind,p.A,p.B,s.Contract,s.Timeframe)
 table.insert(s.Drawings,d);self.History:Push(before);self.Selected=d.Id;s.Tool="Pan"
end
function View:Wheel(ev)
 local g=self.Geometry
 if not g or self.Drag or self.Pending or self.OrderPending or self:Blocked()then return end
 local x=(ev.Position.X-g.Plot.AbsolutePosition.X-g.Left)/g.Width
 Viewport.Zoom(g.State,g.View,ev.Position.Z>0 and 0.85 or 1/0.85,x);self.Dirty=true
end
-- Returns true when the key was used by the chart.
function View:KeyBegan(ev)
 local key=ev.KeyCode
 if key==Enum.KeyCode.LeftControl or key==Enum.KeyCode.RightControl then self.Ctrl=true;self.Dirty=true;return false end
 if UIS:GetFocusedTextBox()then return false end
 local ctrl=UIS:IsKeyDown(Enum.KeyCode.LeftControl)or UIS:IsKeyDown(Enum.KeyCode.RightControl)
 local shift=UIS:IsKeyDown(Enum.KeyCode.LeftShift)or UIS:IsKeyDown(Enum.KeyCode.RightShift)
 if key==Enum.KeyCode.Escape then
  if self.Menu then self:CloseOrderMenu();return true end
  if self.Drag or self.Placement then self:Cancel();self.Ctx.refresh();return true end
  if DRAW[self.S.Tool]then self.S.Tool="Pan";self.Ctx.refresh();return true end
  if self.Selected then self.Selected=nil;self.Ctx.refresh();return true end
  return false
 elseif(key==Enum.KeyCode.Delete or key==Enum.KeyCode.Backspace)and self:SelectedDrawing()and not self.Drag then
  self:DeleteSelected();return true
 elseif ctrl and key==Enum.KeyCode.Z and not self.Drag then if shift then self:Redo()else self:Undo()end return true
 elseif ctrl and key==Enum.KeyCode.Y and not self.Drag then self:Redo();return true
 end
 return false
end
function View:KeyEnded(ev)
 if ev.KeyCode==Enum.KeyCode.LeftControl or ev.KeyCode==Enum.KeyCode.RightControl then
  self.Ctrl=UIS:IsKeyDown(Enum.KeyCode.LeftControl)or UIS:IsKeyDown(Enum.KeyCode.RightControl);self.Dirty=true
 end
end
-- Cancels the current gesture: an edit restores the drawing, a placement is discarded.
function View:Cancel()
 if self.Drag then self:Finish(false)end
 self.Placement=nil self.Hover=nil self.Dirty=true
 if DRAW[self.S.Tool] then self.S.Tool="Pan" end
end
-- Window focus lost (or the Roblox menu opened): cancel any gesture and clear modifier state.
function View:FocusLost()
 self:CloseOrderMenu()
 self.Ctrl=false table.clear(self.Touches)
 self:Cancel()
 self.Hover=nil self.Dirty=true self:SetCursor("")
end
function View:Step(dt)
 local g=self.Geometry
 if g and Viewport.Ease(g.State,dt,self.Drag and(self.Drag.Kind=="Protection"or self.Drag.Kind=="Order"))then self.Dirty=true end
end
function View:OnMarketUpdate()
 self:UpdateOrderMenu()
 local session=self.Ctx.Session local d=self.Drag
 local message
 if d and d.Kind=="Protection"then
  local held=session.Positions[d.Contract]
  if session.AccountKey~=d.Base or not held or held.Id~=d.Id or held.Triggered or held[d.Field]~=d.Original then
   self:Finish(false);message="Position or protection changed. Drag cancelled."
  end
 end
 if d and d.Kind=="Order"then
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
 if pending then
  local held=session.Positions[pending.Contract]
  if session.AccountKey~=pending.Base or not held or held.Id~=pending.Id or held.Triggered or not held[pending.Field]then self.Pending=nil end
 end
 self.Dirty=true
 return message
end
function View:OnReply(reply)
 if self.OrderPending and reply.RequestId==self.OrderPending.RequestId then self.OrderPending=nil;self.Dirty=true end
 if self.Pending and reply.RequestId==self.Pending.RequestId then self.Pending=nil;self.Dirty=true end
end

-------------------------------------------------------------------------------------------------
-- Right-click order menu. The clicked price becomes the order price; the choices depend on where it
-- sits relative to the last traded price: above -> Limit Sell / Stop Buy, below -> Limit Buy / Stop Sell.
-- It shows only those two actions with their price. The quantity is the one selected in Place a Trade
-- (one shared state), and submission uses the terminal's shared order path (same client checks, SL/TP
-- settings, pending state and toasts); the server validates exactly as for the ticket.
local MENU_W,MENU_ROW,MENU_PAD=236,42,8
function View:MenuOptions(price,last)
 if price>last then
  return "Above",{{Dir=-1,Type="Limit",Title="Limit Sell",Gloss="Red"},{Dir=1,Type="Stop",Title="Stop Buy",Gloss="Green"}}
 elseif price<last then
  return "Below",{{Dir=1,Type="Limit",Title="Limit Buy",Gloss="Green"},{Dir=-1,Type="Stop",Title="Stop Sell",Gloss="Red"}}
 end
 return "At",{}
end
function View:OpenOrderMenu(pos)
 self:CloseOrderMenu()
 local ctx=self.Ctx
 if self:Blocked() or not ctx.submitOrder then return false end
 local g=self.Geometry local x,y=self:Local(pos)
 if x<0 or x>g.Width or y<0 or y>g.Height then return false end
 local s=self.S local Market=ctx.Market
 local price=Market.Snap(g.View.High-y/g.Ppp,s.Contract)
 local last=ctx.Session.Prices[s.Contract]
 -- Exactly at the last price there is no limit/stop choice; BUY and SELL place market orders.
 if price<=0 or not last or price==last then return false end
 self.Menu={Contract=s.Contract,Price=price,Pos=pos}
 self:BuildOrderMenu()
 return true
end
function View:CloseOrderMenu()
 local m=self.Menu if not m then return end
 self.Menu=nil
 for _,o in ipairs({m.Frame,m.Backdrop})do if o and o.Parent then o:Destroy()end end
 local root=self.Ctx.Root
 if root then root:SetAttribute("OrderMenuOpen",false);root:SetAttribute("OrderMenuPrice",nil);root:SetAttribute("OrderMenuOptions",nil)end
end
function View:BuildOrderMenu()
 local m=self.Menu if not m then return end
 local ctx=self.Ctx local C,Market,s,root=ctx.C,ctx.Market,self.S,ctx.Root
 local frame,button,stroke,round=ctx.frame,ctx.button,ctx.stroke,ctx.round
 for _,o in ipairs({m.Frame,m.Backdrop})do if o and o.Parent then o:Destroy()end end
 local key=m.Contract local last=ctx.Session.Prices[key] or m.Price
 local side,options=self:MenuOptions(m.Price,last)
 if #options==0 then self:CloseOrderMenu() return end
 m.Side=side m.Market=last m.Options=options
 local pxs=Market.Number(m.Price)
 -- Full-screen catcher: a left click anywhere closes; a right click moves the menu to that point.
 local backdrop=Instance.new("TextButton")
 backdrop.Name="OrderMenuBackdrop" backdrop.Text="" backdrop.BackgroundTransparency=1 backdrop.BorderSizePixel=0 backdrop.AutoButtonColor=false
 backdrop.Size=UDim2.fromScale(1,1) backdrop.ZIndex=94 backdrop.Parent=root
 -- Clicks on the menu's own background must not reach the catcher underneath.
 local function overMenu(p)
  local f=m.Frame if not f or not f.Parent then return false end
  local a,z=f.AbsolutePosition,f.AbsoluteSize
  return p.X>=a.X and p.X<=a.X+z.X and p.Y>=a.Y and p.Y<=a.Y+z.Y
 end
 backdrop.InputBegan:Connect(function(ev)
  local p=Vector2.new(ev.Position.X,ev.Position.Y)
  if overMenu(p) then return end
  if ev.UserInputType==MB2 then
   if not self:OpenOrderMenu(p) then self:CloseOrderMenu() end
  elseif ev.UserInputType==MB1 or ev.UserInputType==TOUCH then self:CloseOrderMenu() end
 end)
 m.Backdrop=backdrop
 local h=MENU_PAD*2+#options*MENU_ROW+(#options-1)*6
 local origin=root.AbsolutePosition
 local px=math.clamp(m.Pos.X-origin.X+6,8,math.max(8,root.AbsoluteSize.X-MENU_W-8))
 local py=math.clamp(m.Pos.Y-origin.Y+6,8,math.max(8,root.AbsoluteSize.Y-h-8))
 local menu=frame(root,"ChartOrderMenu",px,py,MENU_W,h,C.Panel,95);menu.Active=true
 round(menu,12);local edge=stroke(menu,C.Cyan);edge.Thickness=2
 m.Frame=menu
 m.Labels={} m.Buttons={}
 local y=MENU_PAD
 for i,o in ipairs(options)do
  local b=ctx.gloss(button(menu,"Order"..o.Type..(o.Dir>0 and"Buy"or"Sell"),"",MENU_PAD,y,MENU_W-MENU_PAD*2,MENU_ROW,function()
   local n=s.Qty
   local what=string.lower(o.Title).." "..n.." "..key.." @ "..pxs
   if ctx.submitOrder(o.Dir,o.Type,m.Price,n,what)then self:CloseOrderMenu();ctx.refresh()end
  end,C.Raised,C.Text,15,96),o.Gloss)
  b:SetAttribute("Sound","None");b:SetAttribute("Debounce",.4)
  m.Buttons[i]={Button=b,Option=o}
  table.insert(m.Labels,o.Title)
  y+=MENU_ROW+6
 end
 self:RefreshOrderMenu()
 root:SetAttribute("OrderMenuOpen",true);root:SetAttribute("OrderMenuPrice",m.Price);root:SetAttribute("OrderMenuOptions",table.concat(m.Labels,","))
end
-- Button labels ("Limit Sell at 5,850.00") and the over-limit flag for the shared quantity.
function View:RefreshOrderMenu()
 local m=self.Menu if not m or not m.Frame or not m.Frame.Parent or not m.Buttons then return end
 local ctx=self.Ctx local qty=self.S.Qty local pxs=ctx.Market.Number(m.Price)
 for _,item in ipairs(m.Buttons)do
  local o,b=item.Option,item.Button
  local label=b:FindFirstChild("ControlLabel") local value=o.Title.." at "..pxs
  if label then label.Text=value end b.Text=value
  local max=ctx.maxOrder and ctx.maxOrder(m.Contract,o.Dir)
  b:SetAttribute("OverLimit",max~=nil and qty>max)
 end
end
-- Keeps the menu honest while prices move: the choices are rebuilt if the market crosses the clicked
-- price (and it closes if the market sits exactly on it). Changing instrument or opening a popup closes it.
function View:UpdateOrderMenu()
 local m=self.Menu if not m then return end
 if m.Contract~=self.S.Contract or self:Blocked() then self:CloseOrderMenu() return end
 self:RefreshOrderMenu()
 local last=self.Ctx.Session.Prices[m.Contract]
 if not last or last==m.Market then return end
 local side=self:MenuOptions(m.Price,last)
 if side~=m.Side then self:BuildOrderMenu() return end
 m.Market=last
end

-------------------------------------------------------------------------------------------------
-- Commands (toolbar, mobile tools sheet, keyboard)
function View:Command(name)
 if name=="Magnet"then self:ToggleMagnet()
 elseif name=="Undo"then self:Undo()
 elseif name=="Redo"then self:Redo()
 elseif name=="Clear"then self:Clear()
 else self:SetTool(name)end
end
function View:SetTool(name)
 if self.Drag then self:Finish(false)end
 self.S.Tool=name self.Placement=nil self.Hover=nil
 if DRAW[name]then self.Selected=nil end
 self.Ctx.refresh()
end
function View:ToggleMagnet() self.S.Magnet=not self.S.Magnet self.Ctx.refresh() end
function View:CancelPlacement() self.Placement=nil self.Dirty=true end
function View:Undo()
 if self.History:Undo(self.S.Drawings)then if self.Selected and not self:Find(self.Selected)then self.Selected=nil end self.Ctx.refresh()end
end
function View:Redo()
 if self.History:Redo(self.S.Drawings)then if self.Selected and not self:Find(self.Selected)then self.Selected=nil end self.Ctx.refresh()end
end
function View:DeleteSelected()
 local d=self:SelectedDrawing() if not d then return end
 local before=Tools.CopyList(self.S.Drawings)
 for i,x in ipairs(self.S.Drawings)do if x==d then table.remove(self.S.Drawings,i)break end end
 self.History:Push(before) self.Selected=nil self.Ctx.refresh()
end
function View:Clear()
 local s=self.S local current=self:Current()
 if #current==0 then return end
 local before=Tools.CopyList(s.Drawings)
 for i=#s.Drawings,1,-1 do local d=s.Drawings[i] if d.Contract==s.Contract and d.Timeframe==s.Timeframe then table.remove(s.Drawings,i)end end
 self.History:Push(before) self.Selected=nil self.Placement=nil self.Ctx.refresh()
end
function View:SetStyle(field,value)
 local d=self:SelectedDrawing() if not d or d[field]==value then return end
 self.History:Record(self.S.Drawings) d[field]=value self.Ctx.refresh()
end
function View:CycleFill()
 local d=self:SelectedDrawing() if not d then return end
 local list=Tools.Colors local nextValue=list[1]
 for i,v in ipairs(list)do if v==d.Fill then nextValue=list[i%#list+1]end end
 self.History:Record(self.S.Drawings) d.Fill=nextValue self.Ctx.refresh()
end
function View:CycleOpacity()
 local d=self:SelectedDrawing() if not d then return end
 local list=Tools.Opacities local nextValue=list[1]
 for i,v in ipairs(list)do if math.abs(v-(d.Opacity or 0.15))<0.001 then nextValue=list[i%#list+1]end end
 self.History:Record(self.S.Drawings) d.Opacity=nextValue self.Ctx.refresh()
end
function View:ActiveState() local g=self.Geometry return g and g.State,g end
function View:ResetView() local state=self:ActiveState() if state then Viewport.Reset(state);self.Base=nil;self.Dirty=true end end
function View:AutoFit() local state=self:ActiveState() if state then Viewport.AutoFit(state);self.Dirty=true end end
function View:GoLive()
 local state=self:ActiveState()
 if state and not self.Drag then Viewport.GoLive(state,self.Ctx.Session.Prices[self.S.Contract]);self.Dirty=true end
end
function View:Destroy() self:CloseOrderMenu() self:SetCursor("") end
return View
