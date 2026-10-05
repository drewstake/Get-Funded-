-- Native Roblox GUI. All panels and chart marks are editable GuiObjects.
local Market = require(script.Parent.MarketClient)
local Viewport = require(script.Parent.ChartViewport)
local PaintPool = require(script.Parent.ChartPaintPool)
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UI = {}
local painting -- Chart painting is synchronous; input handlers live on a separate, stable surface.
local C = {
 -- 03 / After Hours. Opaque data surfaces; violet is reserved for interaction.
 Bg=Color3.fromRGB(16,16,24), Panel=Color3.fromRGB(28,27,42), Raised=Color3.fromRGB(40,38,57),
 Chart=Color3.fromRGB(13,15,23), Border=Color3.fromRGB(53,48,71), Grid=Color3.fromRGB(33,35,49),
 Text=Color3.fromRGB(243,241,255), Muted=Color3.fromRGB(174,180,207), Blue=Color3.fromRGB(174,152,243),
 Green=Color3.fromRGB(75,200,154), Red=Color3.fromRGB(239,135,153), Buy=Color3.fromRGB(0,160,113), Sell=Color3.fromRGB(207,76,104),
}
local F,M,B,N=Enum.Font.BuilderSans,Enum.Font.BuilderSansMedium,Enum.Font.BuilderSansBold,Enum.Font.RobotoMono
local function clean(value)
 return (value:gsub("⌄","v"):gsub("⌃","^"):gsub("⋮","..."):gsub("☑","[x]"):gsub("☐","[ ]"))
end
local function make(class,name,parent,props,identity)
 if painting then local o=painting:Get(class,name,parent);painting:Props(o,props or{},identity);return o end
 local o=Instance.new(class);o.Name=name
 for k,v in pairs(props or {})do o[k]=v end
 o.Parent=parent;return o
end
local function frame(p,name,x,y,w,h,color,z,identity)
 return make("Frame",name,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.Panel,BorderSizePixel=0,ZIndex=z or p.ZIndex or 1},identity)
end
local function text(p,name,value,x,y,w,h,size,color,font,align,z)
 return make("TextLabel",name,p,{Text=clean(value),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0,
  TextColor3=color or C.Text,TextSize=size or 13,Font=font or F,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=z or p.ZIndex})
end
local function stroke(p,color) return make("UIStroke","Border",p,{Color=color or C.Border,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})end
local function round(p,r)make("UICorner","Corners",p,{CornerRadius=UDim.new(0,r or 8)})end
local function tint(p,top,bottom)
 return make("UIGradient","SurfaceLight",p,{Color=ColorSequence.new(top or Color3.new(1,1,1),bottom or Color3.fromRGB(213,213,229)),Rotation=90})
end
local function panel(p,accent)
 round(p,14);stroke(p,accent or C.Border)
 if p.BackgroundColor3~=C.Chart then tint(p)end
end
local function button(p,name,value,x,y,w,h,fn,color,fg,size,z)
 local b=make("TextButton",name,p,{Text=clean(value),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.Raised,
  BackgroundTransparency=color==false and 1 or 0,BorderSizePixel=0,TextColor3=fg or C.Text,TextSize=size or 13,Font=M,AutoButtonColor=false,ZIndex=z or p.ZIndex})
 if color~=false then round(b);stroke(b,fg==C.Blue and C.Blue or C.Border)end
 b.Activated:Connect(fn)
 local base=b.BackgroundColor3;local resting=b.Position;local tween
 local function settle(hover,pressed)
  if tween then tween:Cancel()end
  tween=TweenService:Create(b,TweenInfo.new(.09,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
   BackgroundColor3=base:Lerp(pressed and Color3.new(0,0,0)or Color3.new(1,1,1),pressed and .18 or hover and .07 or 0),
   Position=resting+UDim2.fromOffset(0,pressed and 1 or 0)})
  tween:Play()
 end
 b.MouseEnter:Connect(function()settle(true,false)end)
 b.MouseLeave:Connect(function()settle(false,false)end)
 b.MouseButton1Down:Connect(function()settle(false,true)end)
 b.MouseButton1Up:Connect(function()settle(true,false)end)
 return b
end
local function rule(p,x,y,w,color,z)return frame(p,"Rule",x,y,w,1,color or C.Border,z)end
local function line(p,name,x1,y1,x2,y2,color,width,z)
 local l=frame(p,name,(x1+x2)/2,(y1+y2)/2,Vector2.new(x2-x1,y2-y1).Magnitude,width or 1,color,z)
 l.AnchorPoint=Vector2.new(.5,.5);l.Rotation=math.deg(math.atan2(y2-y1,x2-x1));return l
end
-- Small line icons are native GuiObjects, so no external image assets are required.
local function icon(p,kind,x,y,size,color)
 local box=frame(p,"Icon"..kind,x,y,size,size,C.Panel);box.BackgroundTransparency=1
 local function l(a,b,c,d)line(box,"Path",a*size,b*size,c*size,d*size,color or C.Blue,1.5)end
 if kind=="Trade"or kind=="Equity"then
  for i,hh in ipairs({.3,.55,.8})do
   local bar=frame(box,"Bar",(i-1)*size*.31,size*(1-hh),size*.17,size*hh,C.Panel);bar.BackgroundTransparency=1;stroke(bar,color or C.Blue)
  end
 elseif kind=="Positions"or kind=="Balance"then
  l(.08,.3,.92,.3);l(.92,.3,.92,.87);l(.92,.87,.08,.87);l(.08,.87,.08,.3)
  l(.31,.3,.31,.12);l(.31,.12,.67,.12);l(.67,.12,.67,.3);l(.08,.5,.92,.5)
 elseif kind=="Learn"then
  l(.5,.18,.5,.91);l(.08,.1,.5,.18);l(.5,.18,.92,.1);l(.08,.1,.08,.78);l(.92,.1,.92,.78);l(.08,.78,.5,.91);l(.5,.91,.92,.78)
 elseif kind=="Review"then
  l(.12,.15,.88,.15);l(.88,.15,.88,.9);l(.88,.9,.12,.9);l(.12,.9,.12,.15);l(.28,.38,.72,.38);l(.28,.57,.72,.57);l(.28,.76,.55,.76)
 else
  l(.5,.9,.5,.1);l(.5,.1,.18,.42);l(.5,.1,.82,.42)
 end
 return box
end
local function dash(p,x,y,w,color,d,z)
 if painting then return painting:Dash(p,x,y,w,color,d,z)end
 for off=0,w,d+5 do frame(p,"DashedLine",x+off,y,math.min(d,w-off),1,color,z)end
end
local RIGHT,CENTER=Enum.TextXAlignment.Right,Enum.TextXAlignment.Center
function UI.Mount(gui,options)
 options=options or {}
 local old=gui:FindFirstChild("Workspace");if old then old:Destroy()end
 local root=make("Frame","Workspace",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Bg,BorderSizePixel=0,ClipsDescendants=true})
 local canvas=frame(root,"Canvas",0,0,1440,900,C.Bg)
 local s={Contract="MES",Timeframe="1m",Type="Market",Qty=2,Limit=5820,Stop=5802.5,Target=5842.5,StopOn=true,TargetOn=true,
  Tab="Positions",Nav="Trade",Sheet=false,Advanced=false,StopTicks=40,TargetTicks=120,Overlay=nil,Guide=1,Tool="Pan",Drawings={},Levels=true,Account=50000}
 local session=Market.New(50000,options.Preview,options.PreviewData)
 local render,dirty,alive=nil,false,true
 local connections={}
 local lastW,lastH=0,0
 local firstPoint,toastId=nil,0
 local views={}
 local chartGeometry,drag,plotPool,repaintChart,beginChartInput,zoomChart,moveCrosshair,finishChartInput
 local pendingProtection
 local navigationDirty,fullRefreshPending,chartDirty=false,false,false
 local paintCount,paintTotal,paintMax=0,0,0
 local function refresh()
  if dirty or not alive then return end
  if drag then fullRefreshPending=true;return end
  local focused=UIS:GetFocusedTextBox();if focused and focused:IsDescendantOf(root)then return end
  dirty=true;task.defer(function()dirty=false;if alive and root.Parent then render()end end)
 end
 local function toast(message)
  toastId+=1;local id=toastId;s.Toast=message;refresh()
  task.delay(4,function()if alive and id==toastId then s.Toast=nil;refresh()end end)
 end
 local function selectContract(key)
  s.Contract=key;local c=Market.Contracts[key];local p=session.Positions[key]
  s.Limit=Market.Snap(session.Prices[key]-4*c.Scale,key)
  s.Stop=p and p.Stop or Market.Snap(session.Prices[key]-22.25*c.Scale,key)
  s.Target=p and p.Target or Market.Snap(session.Prices[key]+17.75*c.Scale,key)
  s.StopOn=true;s.TargetOn=true;s.Error=nil;s.Overlay=nil;firstPoint=nil;refresh()
 end
 local function close(key)s.CloseContract=key;s.Overlay="Close";refresh()end
 local function place(dir)
  if s.Qty<1 or s.Qty>20 or s.Qty%1~=0 then s.Error="Enter a whole quantity from 1 to 20.";toast(s.Error);return end
  if (s.StopOn and(s.StopTicks<1 or s.StopTicks%1~=0))or(s.TargetOn and(s.TargetTicks<1 or s.TargetTicks%1~=0))then
   s.Error="Protection distances must be positive whole ticks.";toast(s.Error);return
  end
  local ok,msg,tab=session:Place(s.Contract,dir,s.Qty,s.Type,s.Limit,s.StopOn and s.StopTicks or nil,s.TargetOn and s.TargetTicks or nil)
  if ok then s.Error=nil;s.Tab=tab;s.Sheet=false;toast(msg)else s.Error=msg;toast(msg)end
 end
 local function account(base)
  local _,message=session:Account(base);s.Overlay=nil;s.Error=nil;toast(message)
 end
 local function info(p,name,x,y,value)
  local b=button(p,name,"i",x,y,22,22,function()s.Overlay="Info";s.Info=value;refresh()end,false,C.Muted,12)
  b.MouseEnter:Connect(function()
   local oldTip=canvas:FindFirstChild("TermTooltip");if oldTip then oldTip:Destroy()end
   local width=math.min(292,root.AbsoluteSize.X-24)
   local pos=b.AbsolutePosition-root.AbsolutePosition
   local tip=frame(canvas,"TermTooltip",math.clamp(pos.X-width/2,12,root.AbsoluteSize.X-width-12),math.clamp(pos.Y+27,10,root.AbsoluteSize.Y-102),width,90,C.Raised,70)
   round(tip);stroke(tip,C.Blue)
   local t=text(tip,"Term",value,12,8,width-24,74,12,C.Text);t.TextWrapped=true
  end)
  b.MouseLeave:Connect(function()local tip=canvas:FindFirstChild("TermTooltip");if tip then tip:Destroy()end end)
  return b
 end
 local function input(p,name,value,x,y,w,h,fn,enabled)
  local o=make("TextBox",name,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=C.Bg,BorderSizePixel=0,
   Text=tostring(value),PlaceholderText="Price",TextColor3=enabled==false and C.Muted or C.Text,TextSize=15,Font=N,ClearTextOnFocus=false,
   TextEditable=enabled~=false,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=p.ZIndex})
  round(o);local edge=stroke(o);make("UIPadding","Padding",o,{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
  o.Focused:Connect(function()edge.Color=C.Blue end)
  o.FocusLost:Connect(function()
   if not alive or not o.Parent then return end
   edge.Color=C.Border
   local n=tonumber((o.Text:gsub("[, $]","")))
   if n and n==n and math.abs(n)<1e8 then fn(n);s.Error=nil else s.Error="Enter a valid finite number."end
   task.delay(.12,refresh)
  end)
  return o
 end
 local function navigate(value,mobile)
  s.Nav=value;s.Overlay=nil;s.Sheet=false
  if value=="Learn"then s.Overlay="Guide";s.Guide=1
  elseif value=="Review"then s.Tab="History";if mobile then s.Sheet="Activity"end
  elseif value=="Positions"then s.Tab="Positions";if mobile then s.Sheet="Activity"end
  else s.Tab="Positions"end
  refresh()
 end
 local function nav(p,x,y,w,h,mobile)
  for i,value in ipairs({"Trade","Positions","Review","Learn"})do
   local bx=mobile and x+(i-1)*w/4 or x
   local by=mobile and y or y+(i-1)*58
   local bw=mobile and w/4 or w
   local selected=s.Nav==value
   local b=button(p,"Nav"..value,"",bx,by,bw,h,function()navigate(value,mobile)end,selected and C.Panel or false)
   icon(b,value,mobile and(bw-18)/2 or 17,mobile and 8 or 16,mobile and 18 or 22,selected and C.Blue or C.Muted)
   text(b,"Label",value,mobile and 0 or 53,mobile and 30 or 0,mobile and bw or bw-58,mobile and 22 or h,mobile and 10 or 14,selected and C.Blue or C.Muted,M,mobile and CENTER or nil)
   if selected then
    if mobile then rule(b,10,h-2,bw-20,C.Blue)else frame(b,"Selected",0,8,2,h-16,C.Blue)end
   end
  end
 end
 local function accountCards(x,y,w,h,mobile)
  local sum=session:Summary()
  local p=frame(canvas,"AccountSummary",x,y,w,h,C.Bg);p.BackgroundTransparency=1
  local gap=mobile and 6 or 12;local cw=(w-gap*2)/3
  for i,d in ipairs({{"Balance",mobile and"Balance"or"Virtual balance",sum.Balance},{"Equity",mobile and"Value"or"Account value",sum.Equity},{"Unrealized",mobile and"Open result"or"Open result",sum.Unrealized}})do
   local bx=(i-1)*(cw+gap)
   local tile=button(p,d[1].."Card","",bx,0,cw,h,function()s.Overlay="Account";refresh()end,C.Panel)
   tint(tile);round(tile,10)
   local inset=mobile and 10 or cw<210 and 14 or 58
   if not mobile and cw>=210 then icon(tile,d[1],18,(h-24)/2,24,i==3 and C.Green or C.Blue)end
   text(p,d[1].."Label",d[2],bx+inset,mobile and 6 or 12,cw-inset-8,18,mobile and 9 or 11,C.Muted)
   local value=i==3 and Market.Signed(d[3])or Market.Money(d[3])
   text(p,d[1].."Value",value,bx+inset,mobile and 25 or 34,cw-inset-8,mobile and 25 or 28,mobile and(w<370 and 11 or 12)or cw<220 and 19 or 23,i==3 and(d[3]>=0 and C.Green or C.Red)or C.Text,N)
  end
 end
 local function chart(x,y,w,h,mobile,compact,short,updating,instant)
  local paintStart=os.clock()
  local c=Market.Contracts[s.Contract];local last=session.Prices[s.Contract];local held=session.Positions[s.Contract]
  local p=updating and canvas:FindFirstChild("Chart") or frame(canvas,"Chart",x,y,w,h,C.Chart)
  if not p then return end
  if not updating then panel(p);p.ClipsDescendants=true end
  local headH=mobile and 48 or 56;local toolsH=mobile and 42 or 40;local footH=mobile and 0 or 26
  if not updating then
  local hd=frame(p,"Header",0,0,w,headH,C.Chart);hd.BackgroundTransparency=1
  button(hd,"ContractSelector",s.Contract.."  ⌄",8,0,mobile and 88 or 105,headH,function()s.Overlay="Contracts";refresh()end,false,C.Text,16)
  if mobile then
   text(hd,"LastPrice",Market.Number(last),100,1,w-157,26,18,C.Text,N,RIGHT)
   text(hd,"PriceChange","",100,26,w-157,18,10,C.Green,N,RIGHT)
   button(hd,"ChartTools","···",w-48,0,44,48,function()s.Overlay="Tools";refresh()end,false,C.Blue,19)
  else
   text(hd,"ContractName",c.Short,118,0,math.max(70,w-398),headH,11,C.Muted).TextTruncate=Enum.TextTruncate.AtEnd
   text(hd,"LastPrice",Market.Number(last),w-263,0,133,headH,22,C.Text,N,RIGHT)
   text(hd,"PriceChange","",w-117,0,104,headH,11,C.Green,N,RIGHT)
  end
  rule(hd,0,headH-1,w)
   local tb=frame(p,"Toolbar",0,headH,w,toolsH,C.Chart);tb.BackgroundTransparency=1
   local tx=8
   for _,tf in ipairs({"1m","5m","15m","1h","1D"})do
    local bw=mobile and(w-24)/5 or 40
    button(tb,"Time"..tf,tf,tx,3,bw-4,toolsH-7,function()s.Timeframe=tf;firstPoint=nil;refresh()end,tf==s.Timeframe and C.Raised or C.Panel,tf==s.Timeframe and C.Blue or C.Muted,12);tx+=bw
   end
   if not mobile then
   tx+=12
   for _,tool in ipairs({{"Pan","↔"},{"Crosshair","+"},{"Trend","╱"},{"Line","─"},{"Clear","×"}})do
    local name=tool[1]
    button(tb,"Tool"..name,tool[2],tx,2,32,toolsH-4,function()
     if name=="Clear"then table.clear(s.Drawings);firstPoint=nil else s.Tool=name;firstPoint=nil end;refresh()
    end,s.Tool==name and C.Raised or false,s.Tool==name and C.Blue or C.Muted,18);tx+=34
   end
   if w>510 then text(tb,"DemoData",options.Preview and "PREVIEW"or"SIMULATED",w-86,0,74,toolsH,10,C.Muted,M,RIGHT)end;rule(tb,0,toolsH-1,w)
  end
  end
  local price=p.Header:FindFirstChild("LastPrice");if price then price.Text=Market.Number(last)end
  local change=p.Header:FindFirstChild("PriceChange")
  if change then local open=(session.Quotes[s.Contract]or{}).Open or c.Last;local diff=last-open;change.Text=string.format("%s %.2f%%",diff>=0 and"↑"or"↓",math.abs(diff/open*100));change.TextColor3=diff>=0 and C.Green or C.Red end
  local ph=math.max(80,h-headH-toolsH-footH)
  local plot=p:FindFirstChild("CandlestickPlot")or frame(p,"CandlestickPlot",0,headH+toolsH,w,ph,C.Chart);plot.ClipsDescendants=true
  local allData=session:Candles(s.Contract,s.Timeframe)
  if #allData==0 then
   local message=options.Preview and "Studio edit preview · Press Play to start the market"or session.Ready and "Loading executed trades · simulated"or session.ConnectionStatus or "Connecting to the simulated exchange"
   local waiting=plot:FindFirstChild("Waiting")
   if waiting then waiting.Text=message else text(plot,"Waiting",message,12,40,w-24,40,13,C.Muted,M,CENTER)end
   chartGeometry=nil;return
  end
  local waiting=plot:FindFirstChild("Waiting");if waiting then waiting:Destroy()end
  local right=mobile and 65 or 82;local left=14;local top=mobile and 26 or 53
  local vh=compact and 0 or mobile and 29 or math.clamp(ph*.13,35,60);local bottom=ph-vh-29
  local levels={last}
  if held and s.Levels then
   for _,key in ipairs({"Entry","Stop","Target"})do local n=held[key];if n then table.insert(levels,n)end end
  end
  local viewKey=s.Contract..":"..s.Timeframe
  local state=views[viewKey];if not state then state={};views[viewKey]=state end
  local view=Viewport.Resolve(state,allData,s.Timeframe,c.Tick,mobile,levels)
  local adjustment=drag and drag.Field and drag or pendingProtection
  if adjustment and (adjustment.Key~=viewKey or adjustment.Base~=session.Base or not held or held.Id~=adjustment.Id or held.Triggered or not held[adjustment.Field])then adjustment=nil end
  if adjustment then
   -- Hold the scale under the pointer while quotes arrive and until the server acknowledges.
   view=table.clone(adjustment.View);view.Data={}
   for _,candle in ipairs(allData)do if candle.Time>=view.Left and candle.Time<=view.Right then table.insert(view.Data,candle)end end
  end
  local data=view.Data;local lo,hi=view.Low,view.High
  local pw=w-right-left
  local function yy(n)return top+Viewport.Y(view,n,bottom-top)end
  local function timeX(t)return left+Viewport.X(view,t,pw)end
  local function xx(i)return timeX(data[i].Time)end
  if not plotPool or plotPool.Root~=plot then plotPool=PaintPool.new(plot)end
  plotPool:Begin(not options.Preview and not instant and not drag);painting=plotPool
  local priceLayer=frame(plot,"PriceLayer",left,top,pw,bottom-top,C.Chart,2);priceLayer.BackgroundTransparency=1;priceLayer.ClipsDescendants=true
  local gridCount=compact and 2 or mobile and 4 or 5
  for i=0,gridCount do
   local py=top+9+i*(bottom-top-18)/gridCount;rule(plot,left,py,pw,C.Grid)
   local overlaps=false;for _,n in ipairs(levels)do if math.abs(yy(n)-py)<17 then overlaps=true end end
   if not overlaps then text(plot,"PriceAxis",Market.Number(Market.Snap(hi-(py-top)/(bottom-top)*(hi-lo),s.Contract)),w-right+3,py-9,right-10,18,11,C.Muted,N,RIGHT)end
  end
  local ticks=mobile and 4 or 6
  for i=0,ticks-1 do
   local stamp=math.round(Viewport.TimeAt(view,i/(ticks-1))/view.Interval)*view.Interval;local px=timeX(stamp)
   frame(plot,"TimeGrid",px,top,1,ph-top-23,C.Grid)
   local t
   if s.Timeframe=="1D"then t="DAY "..(math.floor(stamp/86400)+1)
   else t=string.format("%02d:%02d",math.floor(stamp/3600)%24,math.floor(stamp/60)%60)end
   text(plot,"TimeAxis",t,math.clamp(px-22,8,w-right-43),ph-22,48,20,10,C.Muted,N)
  end
  text(plot,"Watermark","GET FUNDED!",0,ph*.41,w-right,48,mobile and 28 or 43,C.Text,B,CENTER).TextTransparency=.965
  local cw=math.clamp(pw/view.Bars*.63,2,32);local maxVol=1
  for _,d in ipairs(data)do maxVol=math.max(maxVol,d.Volume)end
  for i,d in ipairs(data)do
   local px=xx(i);local color=d.Close>=d.Open and C.Green or C.Red
   frame(priceLayer,"Wick",px-left,yy(d.High)-top,1,math.max(1,yy(d.Low)-yy(d.High)),color,nil,d.Time)
   local body=frame(priceLayer,"Candle",px-left-cw/2,math.min(yy(d.Open),yy(d.Close))-top,cw,math.max(1.2,math.abs(yy(d.Open)-yy(d.Close))),d.Close>=d.Open and color or C.Chart,nil,d.Time)
   stroke(body,color)
   if vh>0 then local bh=d.Volume/maxVol*math.max(8,vh-(mobile and 4 or 22));frame(plot,"VolumeBar",px-cw/2,ph-25-bh,cw,bh,color,nil,d.Time).BackgroundTransparency=.48 end
  end
  if vh>0 and not mobile then rule(plot,left,bottom+13,pw);text(plot,"VolumeLabel","Volume",12,bottom+17,80,15,10,C.Muted)end
  local protectionHits={}
  local function level(price,value,color,width,field)
   local py=yy(price);if py<top or py>bottom then return end;dash(plot,left,py,pw,color,5,3)
   if field then table.insert(protectionHits,{Field=field,Y=py-top,Width=width})end
   local tag=frame(plot,field and field.."Handle"or"LevelTag",left,py-10,width,20,C.Panel,4);round(tag,2);stroke(tag,color)
   tag:SetAttribute("Price",price)
   text(tag,"Label",value,5,0,width-10,20,10,color,N,nil,5)
   local tag2=frame(plot,"PriceTag",w-right,py-10,right,20,C.Raised,4)
   text(tag2,"Price",Market.Number(price),3,0,right-9,20,11,color,N,RIGHT,5)
  end
  if held and s.Levels then
   for _,field in ipairs({"Target","Stop"})do
    local price=adjustment and adjustment.Field==field and adjustment.Price or held[field]
    if price then
     local editable=not options.Preview and not held.Triggered
     local moving=adjustment and adjustment.Field==field
     local title=field=="Stop"and(mobile and"SL "or"STOP LOSS ")or(mobile and"TP "or"TAKE PROFIT ")
     local suffix=moving and(adjustment.RequestId and" ..."or" *")or""
     level(price,(editable and"↕ "or"")..title..Market.Signed((price-held.Entry)*held.Quantity*c.Multiplier*held.Direction)..suffix,
      field=="Stop"and C.Red or C.Green,mobile and 116 or 198,editable and field or nil)
    end
   end
   level(held.Entry,(held.Direction>0 and "LONG "or"SHORT ")..held.Quantity..(mobile and ""or" · ENTRY"),C.Blue,mobile and 65 or 114)
  end
  local ly=yy(last);if ly>=top and ly<=bottom then dash(plot,left,ly,pw,C.Muted,2,2)end;ly=math.clamp(ly,top+10,bottom-10)
  local badge=frame(plot,"LastPrice",w-right,ly-10,right,20,C.Blue,5)
  text(badge,"Price",Market.Number(last),2,0,right-8,20,11,C.Bg,N,RIGHT,6)
  for _,d in ipairs(s.Drawings)do
   if d.Contract==s.Contract and d.Timeframe==s.Timeframe then
    if d.Kind=="Line"then dash(priceLayer,0,yy(d.P1)-top,pw,C.Blue,4,3)
    else line(priceLayer,"UserTrend",timeX(d.T1)-left,yy(d.P1)-top,timeX(d.T2)-left,yy(d.P2)-top,C.Blue,2,3)end
   end
  end
  local function ohlc(d)return string.format("O %s  H %s  L %s  C %s",Market.Number(d.Open),Market.Number(d.High),Market.Number(d.Low),Market.Number(d.Close))end
  local recent=data[#data]or allData[#allData]
  local readout=text(plot,"OHLC",ohlc(recent).."  V "..recent.Volume,12,5,w-24,19,mobile and 9 or 11,C.Muted,N,nil,7);readout.Visible=not mobile
  local quote=session.Quotes[s.Contract]or{}
  local function q(n)return n and Market.Number(n)or"—"end
  local quoteY=mobile and 3 or 26
  text(plot,"BidAsk","B "..q(quote.Bid).."  A "..q(quote.Ask).."  SPR "..q(quote.Spread),12,quoteY,w-24,18,mobile and 9 or 11,C.Blue,N,nil,7)
  local cross=frame(plot,"Crosshair",0,top,1,bottom-top,C.Muted,6);cross.Visible=false
  painting=nil;plotPool:Finish()
  chartGeometry={Key=viewKey,State=state,View=view,Plot=plot,Left=left,Top=top,Width=pw,Height=bottom-top,Cross=cross,Readout=readout,Data=data,OHLC=ohlc,ProtectionHits=protectionHits}
  local inputSurface=p:FindFirstChild("ChartInput")
  if not inputSurface then
   inputSurface=frame(p,"ChartInput",left,headH+toolsH+top,pw+right,bottom-top,C.Chart,8);inputSurface.BackgroundTransparency=1;inputSurface.Active=true
   inputSurface.InputBegan:Connect(function(ev)beginChartInput(ev)end)
   inputSurface.InputChanged:Connect(function(ev)
    if ev.UserInputType==Enum.UserInputType.MouseWheel then zoomChart(ev.Position.Z>0 and 0.8 or 1.25,ev.Position.X)
    elseif not drag then moveCrosshair(ev.Position)end
   end)
   inputSurface.MouseLeave:Connect(function()if chartGeometry then chartGeometry.Cross.Visible=false end end)
  end
  local liveButton=p:FindFirstChild("GoLive")
  if not liveButton then
   liveButton=button(p,"GoLive","Go live",w-right-84,headH+toolsH+(mobile and 27 or 3),78,32,function()
    if chartGeometry and not drag and not pendingProtection then Viewport.GoLive(chartGeometry.State);navigationDirty=true;repaintChart()end
   end,C.Raised,C.Blue,11,9)
  end
  liveButton.Visible=not view.Live
  root:SetAttribute("ChartFollowingLive",view.Live);root:SetAttribute("ChartRightTime",view.Right);root:SetAttribute("ChartLeftTime",view.Left)
  root:SetAttribute("ChartLow",view.Low);root:SetAttribute("ChartHigh",view.High);root:SetAttribute("ChartBars",view.Bars)
  root:SetAttribute("VisibleCandles",#data);root:SetAttribute("DrawingCount",#s.Drawings)
  root:SetAttribute("StopPrice",held and held.Stop);root:SetAttribute("TargetPrice",held and held.Target)
  root:SetAttribute("ProtectionPreviewPrice",adjustment and adjustment.Price)
  root:SetAttribute("ProtectionPending",pendingProtection~=nil)
  if not mobile then
  local foot=p:FindFirstChild("Footer")
  if not foot then
   foot=frame(p,"Footer",0,h-footH,w,footH,C.Chart);foot.BackgroundTransparency=1;rule(foot,0,0,w)
   text(foot,"Date","",12,1,math.min(310,w-160),footH-1,10,C.Muted,F)
   text(foot,"Time","",w-151,1,139,footH-1,9,C.Muted,N,RIGHT)
  end
  foot.Date.Text="■ Filled ↑ Up     □ Hollow ↓ Down"
  foot.Time.Text=string.format("%02d:%02d:%02d · %dx",math.floor(session.Time/3600)%24,math.floor(session.Time/60)%60,math.floor(session.Time)%60,session.Speed)
  end
  paintCount+=1;local cost=(os.clock()-paintStart)*1000;paintTotal+=cost;paintMax=math.max(paintMax,cost)
 end
 repaintChart=function()
  if not alive or not root.Parent or s.Sheet or s.Overlay then return end
  local p=canvas:FindFirstChild("Chart");if not p then return end
  local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
  local instant=navigationDirty;navigationDirty=false;chartDirty=false
  local mobile=w<1000 or h<600
  chart(p.Position.X.Offset,p.Position.Y.Offset,p.Size.X.Offset,p.Size.Y.Offset,mobile,mobile and(w>h or h<650),false,true,instant)
 end
 moveCrosshair=function(position)
  local g=chartGeometry;if not g or s.Tool~="Crosshair"or drag then return end
  local x=position.X-g.Plot.AbsolutePosition.X-g.Left
  local y=position.Y-g.Plot.AbsolutePosition.Y-g.Top
  if x<0 or x>g.Width or y<0 or y>g.Height then g.Cross.Visible=false;return end
  g.Cross.Position=UDim2.fromOffset(g.Left+x,g.Top);g.Cross.Visible=true
  local time=Viewport.TimeAt(g.View,x/g.Width);local nearest,distance=nil,math.huge
  for _,c in ipairs(g.Data)do local d=math.abs(c.Time-time);if d<distance then nearest=c;distance=d end end
  if nearest then g.Readout.Text=g.OHLC(nearest).."  V "..nearest.Volume end
 end
 beginChartInput=function(ev)
  local kind=ev.UserInputType
  if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.MouseButton3 and kind~=Enum.UserInputType.Touch then return end
  local g=chartGeometry;if not g or drag or s.Overlay or s.Sheet then return end
  local position=Vector2.new(ev.Position.X,ev.Position.Y)
  local x=position.X-g.Plot.AbsolutePosition.X-g.Left
  local y=position.Y-g.Plot.AbsolutePosition.Y-g.Top
  if x<0 or y<0 or y>g.Height then return end
  local held=session.Positions[s.Contract]
  if kind~=Enum.UserInputType.MouseButton3 and held and not held.Triggered and not pendingProtection then
   local chosen,distance=nil,math.huge
   for _,hit in ipairs(g.ProtectionHits)do
    local label=x<=hit.Width or x>=g.Width
    local tolerance=kind==Enum.UserInputType.Touch and(label and 22 or 14)or(label and 10 or 6)
    local d=math.abs(y-hit.Y)
    if d<=tolerance and d<distance then chosen=hit.Field;distance=d end
   end
   if chosen then
    drag={Input=ev,Kind=kind,Start=position,View=g.View,Height=g.Height,Moved=false,
     Field=chosen,Key=g.Key,Contract=s.Contract,Base=session.Base,Id=held.Id,Original=held[chosen],Price=held[chosen]}
    root:SetAttribute("ChartDragging",true);root:SetAttribute("DraggingProtection",chosen);g.Cross.Visible=false;return
   end
  end
  if x>g.Width or pendingProtection then return end
  local price=Market.Snap(Viewport.PriceAt(g.View,y/g.Height),s.Contract)
  local time=Viewport.TimeAt(g.View,x/g.Width)
  if kind~=Enum.UserInputType.MouseButton3 and s.Tool=="Line"then
   table.insert(s.Drawings,{Kind="Line",P1=price,Contract=s.Contract,Timeframe=s.Timeframe});refresh()
  elseif kind~=Enum.UserInputType.MouseButton3 and s.Tool=="Trend"then
   if not firstPoint then firstPoint={T=time,P=price};toast("Choose the second point for the trend line.")
   else table.insert(s.Drawings,{Kind="Trend",P1=firstPoint.P,T1=firstPoint.T,P2=price,T2=time,Contract=s.Contract,Timeframe=s.Timeframe});firstPoint=nil;refresh()end
  else
   drag={Input=ev,Kind=kind,Start=position,View=g.View,State=g.State,Width=g.Width,Height=g.Height,Moved=false}
   root:SetAttribute("ChartDragging",true)
  end
 end
 zoomChart=function(factor,screenX)
  local g=chartGeometry;if not g or drag or pendingProtection or s.Overlay or s.Sheet then return end
  local x=(screenX-g.Plot.AbsolutePosition.X-g.Left)/g.Width
  Viewport.Zoom(g.State,g.View,factor,x);navigationDirty=true
 end
 finishChartInput=function(commit)
  if not drag then return end
  local finished=drag;drag=nil;root:SetAttribute("ChartDragging",false);root:SetAttribute("DraggingProtection",nil)
  if commit and finished.Field and finished.Moved and finished.Price~=finished.Original then
   local ok,message,_,requestId=session:AmendProtection(finished.Contract,finished.Id,finished.Field,finished.Price,finished.Original)
   if ok then
    finished.RequestId=requestId;pendingProtection=finished
    task.delay(10,function()
     if alive and pendingProtection==finished then pendingProtection=nil;toast("Update not yet confirmed. Showing the last server price.")end
    end)
   else toast(message)end
  end
  if fullRefreshPending then fullRefreshPending=false;refresh()else repaintChart()end
 end
 local function activity(x,y,w,h,mobile,compact,z)
  local p=frame(canvas,"Activity",x,y,w,h,C.Panel,z);panel(p);p.ClipsDescendants=true
  local sum=session:Summary();local working=session:Working()
  local tabs={{"Positions","Open positions · "..sum.Count},{"Orders","Orders · "..#working},{"History","Trade history"}}
  local top=compact and 0 or 43
  if not compact then
   local tw=math.min((w-20)/3,151)
   for i,item in ipairs(tabs)do
    local bx=10+(i-1)*tw
    button(p,"Tab"..item[1],item[2],bx,0,tw,42,function()s.Tab=item[1];refresh()end,false,s.Tab==item[1]and C.Text or C.Muted,mobile and 11 or 12)
    if s.Tab==item[1]then rule(p,bx+8,41,tw-16,C.Blue)end
   end
   rule(p,0,42,w)
  end
  local data={}
  if s.Tab=="Positions"or compact then for _,key in ipairs(Market.ContractOrder)do if session.Positions[key]then table.insert(data,session.Positions[key])end end
  elseif s.Tab=="Orders"then data=working else data=session.History end
  if #data==0 then
   text(p,"EmptyTitle",s.Tab=="Positions"and"No open positions"or s.Tab=="Orders"and"No working orders"or"No completed trades yet",12,top+13,w-24,24,13,C.Text,M,CENTER)
   if not compact then text(p,"EmptyDetail",s.Tab=="Positions"and"Choose a contract and place a simulated order."or s.Tab=="Orders"and"Limit and protective orders appear here."or"Close a position to review your result.",12,top+41,w-24,23,11,C.Muted,F,CENTER)end
   return
  end
  local function scroller(name,yy,hh,ch)
   return make("ScrollingFrame",name,p,{Position=UDim2.fromOffset(0,yy),Size=UDim2.fromOffset(w,hh),CanvasSize=UDim2.fromOffset(0,ch),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Muted,ZIndex=p.ZIndex})
  end
  if mobile then
   local rowH=(s.Tab=="Positions"or compact)and 46 or 79
   local list=scroller("Rows",top,h-top,#data*rowH)
   for i,d in ipairs(data)do
    local row=frame(list,"Row"..i,0,(i-1)*rowH,w,rowH,C.Panel)
    if s.Tab=="Positions"or compact then
     text(row,"Symbol",d.Contract,10,3,47,40,11,C.Text,B)
     text(row,"Direction",(d.Direction>0 and"BUY "or"SELL ")..d.Quantity,58,3,64,40,10,d.Direction>0 and C.Green or C.Red,M)
     text(row,"Pnl",Market.Signed(session:Pnl(d)),123,3,w-200,40,11,session:Pnl(d)>=0 and C.Green or C.Red,N,RIGHT)
     button(row,"Close"..d.Contract,"CLOSE",w-67,2,59,42,function()close(d.Contract)end,C.Raised,C.Text,10)
    elseif s.Tab=="Orders"then
     text(row,"Description",d.Contract.." · "..d.Kind,14,7,w-108,24,13,C.Text,M)
     text(row,"Price",Market.Number(d.Price).." · "..d.Quantity.." contracts",14,35,w-112,27,12,C.Muted,N)
     button(row,"Cancel"..d.Id..(d.Protection or""),"Cancel",w-96,18,82,44,function()local _,message=session:Cancel(d.Id,d.Protection);toast(message)end,C.Raised,C.Text,12)
    else
     text(row,"Description",d.Contract.." · "..d.Quantity.." contracts",14,9,w-124,24,13,C.Text,M)
     text(row,"Pnl",Market.Signed(d.Pnl),w-119,9,105,24,14,d.Pnl>=0 and C.Green or C.Red,N,RIGHT)
     text(row,"Details",Market.Number(d.Entry).." → "..Market.Number(d.Exit).." · "..d.Time,14,37,w-28,25,11,C.Muted,N)
    end
    rule(row,8,rowH-1,w-16)
   end
  else
   local cols=s.Tab=="Positions"and{"Instrument","Side","Qty","Entry","Result","Action"}or s.Tab=="Orders"and{"Instrument","Order","Qty","Price","Status","Action"}or{"Instrument","Qty","Entry","Exit","Result","Closed"}
   local heading=frame(p,"TableHeader",8,top,w-16,30,C.Raised);round(heading,5)
   local fractions={0,.17,.34,.44,.62,.85}
   for i,title in ipairs(cols)do text(p,"Column"..i,title,14+fractions[i]*(w-28),top+3,(w-28)*(i==5 and .23 or .17)-7,25,10,C.Muted)end
   local list=scroller("Rows",top+30,h-top-30,#data*39)
   for i,d in ipairs(data)do
    local row=frame(list,"Row"..i,0,(i-1)*39,w,39,C.Panel);rule(row,0,0,w,C.Grid)
    local vals,positive
    if s.Tab=="Positions"then positive=session:Pnl(d)>=0;vals={d.Contract,d.Direction>0 and"BUY"or"SELL",tostring(d.Quantity),Market.Number(d.Entry),Market.Signed(session:Pnl(d))}
    elseif s.Tab=="Orders"then vals={d.Contract.."Z26",d.Kind,tostring(d.Quantity),Market.Number(d.Price),d.Status or "Working"}
    else positive=d.Pnl>=0;vals={d.Contract.."Z26",tostring(d.Quantity),Market.Number(d.Entry),Market.Number(d.Exit),Market.Signed(d.Pnl),d.Time}end
    for j,value in ipairs(vals)do text(row,"Cell"..j,value,14+fractions[j]*(w-28),2,(w-28)*(j==5 and .23 or .17)-7,35,11,j==5 and positive~=nil and(positive and C.Green or C.Red)or C.Text,j>=3 and N or M)end
    if s.Tab~="History"then button(row,"Action"..i,s.Tab=="Positions"and"CLOSE"or"Cancel",14+.85*(w-28),6,(w-28)*.15-10,27,function()
     if s.Tab=="Positions"then close(d.Contract)else local _,message=session:Cancel(d.Id,d.Protection);toast(message)end
    end,C.Raised,C.Text,10)end
   end
  end
 end
 local function tradeButtons(p,x,y,w)
  local bw=(w-8)/2
  for _,d in ipairs({{1,"BuyLong","↑  BUY",C.Buy,0},{-1,"SellShort","↓  SELL",C.Sell,bw+8}})do
   local enabled=options.Preview or session.CanTrade
   local b=button(p,d[2],d[3],x+d[5],y,bw,48,function()if enabled then place(d[1])end end,enabled and d[4]or C.Raised,enabled and C.Text or C.Muted,16)
   b.Active=enabled;b.Selectable=enabled;tint(b)
   b.Border.Color=enabled and(d[1]>0 and C.Green or C.Red)or C.Border
   b:SetAttribute("Direction",d[1])
  end
 end
 local function quantity(p,x,y,w)
  local q=frame(p,"Quantity",x,y,w,44,C.Bg);round(q,7);stroke(q)
  button(q,"Decrease","−",0,0,44,44,function()s.Qty=math.max(1,s.Qty-1);refresh()end,C.Raised,C.Text,24)
  text(q,"Value",tostring(s.Qty),44,0,w-88,44,17,C.Text,N,CENTER)
  button(q,"Increase","+",w-44,0,44,44,function()s.Qty=math.min(20,s.Qty+1);refresh()end,C.Raised,C.Text,23)
 end
 local function orderOptions(p,w)
  local pad=16;local iw=w-32;local yy=12
  local seg=frame(p,"OrderType",pad,yy,iw,44,C.Bg);round(seg,3)
  for i,kind in ipairs({"Market","Limit"})do
   button(seg,kind,kind,3+(i-1)*(iw-6)/2,3,(iw-6)/2,38,function()s.Type=kind;s.Error=nil;refresh()end,s.Type==kind and C.Raised or false,s.Type==kind and C.Blue or C.Muted,14)
  end
  yy+=58
  if s.Type=="Limit"then
   text(p,"LimitLabel","Limit price",pad,yy,iw,21,12,C.Muted)
   input(p,"LimitPrice",string.format("%.2f",s.Limit),pad,yy+25,iw,44,function(n)s.Limit=n end);yy+=84
  end
  rule(p,pad,yy,iw);yy+=12
  local function protection(key,title,enabled,ticks)
   local toggle=button(p,key.."Toggle",title,pad,yy,iw,44,function()s[key.."On"]=not s[key.."On"];refresh()end,false,C.Text,13)
   toggle.TextXAlignment=Enum.TextXAlignment.Left
   text(toggle,"State",enabled and"ON"or"OFF",iw-45,0,45,44,11,enabled and C.Blue or C.Muted,M,RIGHT)
   info(p,key.."Info",w-94,yy+11,key=="Stop"and"A stop loss exits a losing position. Distance is measured in ticks from entry. MES has $1.25 per tick per contract."or"Take profit exits at your chosen profit target. Its distance is measured in ticks from entry.")
   yy+=46
   if enabled then
    input(p,key.."Ticks",ticks,pad,yy,iw-83,44,function(n)s[key.."Ticks"]=n end)
    text(p,key.."Unit","ticks",w-85,yy,65,44,12,C.Muted,F,RIGHT);yy+=54
   end
  end
  protection("Stop","Stop loss",s.StopOn,s.StopTicks)
  protection("Target","Take profit",s.TargetOn,s.TargetTicks)
  local c=Market.Contracts[s.Contract]
  text(p,"RiskLabel","Estimated risk",pad,yy+8,iw-115,24,12,C.Muted)
  text(p,"Risk",s.StopOn and Market.Money(s.StopTicks*c.Tick*c.Multiplier*s.Qty)or"No stop",w-133,yy+8,117,24,14,C.Text,N,RIGHT);yy+=45
  local desc=text(p,"Explanation","Distances apply above or below entry for your trade direction.",pad,yy,iw,40,11,C.Muted);desc.TextWrapped=true;yy+=49
  if s.Error then text(p,"Error",s.Error,pad,yy,iw,44,12,C.Red).TextWrapped=true;yy+=50 end
  return yy+8
 end
 local function ticket(x,y,w,h)
  local p=frame(canvas,"OrderTicket",x,y,w,h,C.Panel);panel(p,C.Blue:Lerp(C.Border,.55));p.ClipsDescendants=true
  local held=session.Positions[s.Contract];local iw=w-32
  text(p,"Title","Place a trade",20,10,iw,36,21,C.Text,B)
  text(p,"Subtitle","Your next move starts here.",20,44,iw,22,11,C.Muted)
  local sc=make("ScrollingFrame","Fields",p,{Position=UDim2.fromOffset(0,78),Size=UDim2.fromOffset(w,h-90),CanvasSize=UDim2.fromOffset(0,480),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Blue})
  button(sc,"ContractSelector",s.Contract.."   ·   "..Market.Contracts[s.Contract].Short.."  ⌄",16,0,iw,44,function()s.Overlay="Contracts";refresh()end,C.Bg,C.Text,12)
  text(sc,"QtyLabel","Quantity",16,56,iw,22,12,C.Muted);quantity(sc,16,84,iw)
  local mode=button(sc,"OrderSettings",s.Type.." order   ·   Settings",16,137,iw,40,function()s.Advanced=not s.Advanced;refresh()end,false,C.Blue,12);mode.TextXAlignment=Enum.TextXAlignment.Left
  text(mode,"Arrow",s.Advanced and"−"or"+",iw-28,0,28,40,20,C.Blue,N,RIGHT)
  local cardW=(iw-10)/2
  for i,d in ipairs({{"Stop","SL · Stop loss",s.StopOn,s.StopTicks},{"Target","TP · Take profit",s.TargetOn,s.TargetTicks}})do
   local b=button(sc,d[1].."Card","",16+(i-1)*(cardW+10),184,cardW,68,function()s.Advanced=true;refresh()end,C.Bg)
   text(b,"Label",d[2],10,7,cardW-20,20,10,C.Muted)
   text(b,"Distance",d[3]and tostring(d[4]).." ticks"or"Off",10,31,cardW-20,26,16,d[3]and C.Text or C.Muted,N)
  end
  text(sc,"ProtectionHint","Auto-close distances from entry",16,258,iw,22,10,C.Muted,F,CENTER)
  tradeButtons(sc,16,292,iw)
  local c=Market.Contracts[s.Contract]
  text(sc,"Risk",s.StopOn and("Estimated risk  "..Market.Money(s.StopTicks*c.Tick*c.Multiplier*s.Qty))or"No stop loss configured",16,351,iw,24,11,C.Muted,N,CENTER)
  local yy=393
  if s.Advanced then
   local opts=frame(sc,"Advanced",0,yy,w,540,C.Panel);local oh=orderOptions(opts,w);opts.Size=UDim2.fromOffset(w,oh);yy+=oh+10
  end
  rule(sc,16,yy,iw);yy+=15
  if held then
   text(sc,"Position",(held.Direction>0 and"LONG "or"SHORT ")..held.Quantity.." · "..held.Contract,16,yy,iw,23,12,held.Direction>0 and C.Green or C.Red,M);yy+=29
   text(sc,"Pnl",Market.Signed(session:Pnl(held)),16,yy,iw,34,25,session:Pnl(held)>=0 and C.Green or C.Red,N);yy+=39
   text(sc,"Entry","Entry  "..Market.Number(held.Entry),16,yy,iw,23,12,C.Muted,N);yy+=34
   button(sc,"ClosePosition","Close position",16,yy,iw,42,function()close(held.Contract)end,C.Raised,C.Text,13);yy+=53
  else text(sc,"NoPosition","No open position",16,yy,iw,30,12,C.Muted);yy+=40 end
  text(sc,"Simulation","Simulated market · Virtual funds",16,yy,iw,30,10,C.Muted,F,CENTER);yy+=36
  sc.CanvasSize=UDim2.fromOffset(0,yy)
 end
 local function mobileDock(x,y,w,h,compact)
  local p=frame(canvas,"TradeDock",x,y,w,h,C.Bg,10)
  local qw=math.min(144,w*.45)
  text(p,"QtyLabel","Quantity",2,0,w-qw-58,44,11,C.Muted)
  quantity(p,w-qw-51,0,qw)
  button(p,"OrderSettings","···",w-44,0,44,44,function()s.Sheet=true;refresh()end,false,C.Blue,21)
  local cw=(w-8)/2
  for i,d in ipairs({{"Stop","SL · Stop loss",s.StopOn,s.StopTicks},{"Target","TP · Take profit",s.TargetOn,s.TargetTicks}})do
   local b=button(p,d[1].."Card","",(i-1)*(cw+8),compact and 50 or 52,cw,compact and 40 or 56,function()s.Sheet=true;refresh()end,C.Panel)
   if compact then
    text(b,"Distance",(i==1 and"SL · "or"TP · ")..(d[3]and tostring(d[4]).." ticks"or"Off"),6,0,cw-12,40,11,C.Text,N,CENTER)
   else
    text(b,"Label",d[2],10,3,cw-20,20,10,C.Muted)
    text(b,"Distance",d[3]and tostring(d[4]).." ticks"or"Off",10,25,cw-20,24,14,C.Text,N)
   end
  end
  if not compact then text(p,"ProtectionHint",s.Type.." · Auto-close distances from entry",0,111,w,21,9,C.Muted,F,CENTER)end
  tradeButtons(p,0,compact and 98 or 138,w)
 end
 local steps={
  {"Your workspace, your pace","Choose a futures contract, study the chart, and use the order ticket to practice. All prices and funds are simulated."},
  {"Read a candle","Each candle shows open, high, low, and close. Green closes higher; red closes lower. The bars underneath show volume. Change the timeframe to explore."},
  {"Plan before you enter","Market orders consume available liquidity and may fill partially. Limit orders rest at your price or better. Stops and targets trigger closing orders; slippage depends on liquidity."},
  {"Manage your position","Drag the SL or TP line or its price label to change protection. Release to submit; Esc cancels. Prices snap to ticks. Close Position realizes P&L and cancels protection. All funds are simulated."},
 }
 local function overlay(w,h)
  if not s.Overlay then return end
  button(canvas,"OverlayBackdrop","",0,0,w,h,function()s.Overlay=nil;refresh()end,C.Bg,C.Text,12,40).BackgroundTransparency=.28
  local pw=math.min(w-30,390);local ph=s.Overlay=="Contracts"and 328 or s.Overlay=="Guide"and 296 or s.Overlay=="Settings"and 340 or s.Overlay=="Account"and 400 or s.Overlay=="Menu"and 360 or s.Overlay=="Timeframes"and 344 or s.Overlay=="Tools"and 360 or 270
  local viewH=math.min(ph,h-24)
  local shell=frame(canvas,"Dialog",(w-pw)/2,(h-viewH)/2,pw,viewH,C.Panel,41);panel(shell,C.Blue)
  local p=make("ScrollingFrame","Content",shell,{Size=UDim2.fromOffset(pw,viewH),CanvasSize=UDim2.fromOffset(pw,ph),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Muted,ZIndex=41})
  button(p,"Dismiss","×",pw-49,6,42,42,function()s.Overlay=nil;refresh()end,false,C.Muted,24)
  if s.Overlay=="Close"then
   local held=session.Positions[s.CloseContract]
   text(p,"Title","Close this position?",20,17,pw-80,29,18,C.Text,B)
   text(p,"Position",held and(held.Contract.." · "..(held.Direction>0 and"BUY"or"SELL").." · "..held.Quantity)or"This position has already closed.",20,68,pw-40,28,13,C.Text)
   local pnl=held and session:Pnl(held)or 0
   text(p,"Result",held and("Current result: "..Market.Signed(pnl))or"",20,105,pw-40,28,14,pnl>=0 and C.Green or C.Red,N)
   button(p,"KeepOpen","Keep open",20,ph-66,(pw-48)/2,46,function()s.Overlay=nil;refresh()end,C.Raised,C.Text,12)
   button(p,"ConfirmClose","CLOSE",28+(pw-48)/2,ph-66,(pw-48)/2,46,function()
    local key=s.CloseContract;s.Overlay=nil
    if session.Positions[key]then local _,msg=session:Close(key);s.Error=nil;toast(msg)else refresh()end
   end,C.Sell,C.Text,12)
  elseif s.Overlay=="Guide"then
   text(p,"Step","FIRST TRADE / "..s.Guide.." OF 4",20,15,pw-75,25,11,C.Blue,M)
   text(p,"Title",steps[s.Guide][1],20,59,pw-40,35,20,C.Text,B)
   local t=text(p,"Body",steps[s.Guide][2],20,105,pw-40,ph-174,14,C.Muted);t.TextWrapped=true;t.TextYAlignment=Enum.TextYAlignment.Top
   button(p,"Skip","Skip for now",15,ph-57,120,43,function()s.Overlay=nil;refresh()end,false,C.Muted,12)
   button(p,"Next",s.Guide==4 and"Start practicing"or"Next →",pw-168,ph-57,148,43,function()if s.Guide<4 then s.Guide+=1 else s.Overlay=nil end;refresh()end,C.Blue,C.Bg,13)
  elseif s.Overlay=="Contracts"then
   text(p,"Title","Select a contract",20,14,pw-80,33,18,C.Text,B)
   for i,key in ipairs(Market.ContractOrder)do
    local c=Market.Contracts[key];local b=button(p,"Choose"..key,"",14,61+(i-1)*60,pw-28,54,function()selectContract(key)end,key==s.Contract and C.Raised or C.Bg)
    text(b,"Symbol",key.."Z26",12,5,100,21,14,C.Text,B);text(b,"Name",c.Short,12,30,pw-60,17,11,C.Muted)
    text(b,"Price",Market.Number(session.Prices[key]),pw-167,5,124,24,15,C.Text,N,RIGHT)
   end
  elseif s.Overlay=="Timeframes"then
   text(p,"Title","Timeframe",20,17,pw-80,29,18,C.Text,B)
   for i,tf in ipairs({"1m","5m","15m","1h","1D"})do
    button(p,"Choose"..tf,tf,20,62+(i-1)*51,pw-40,45,function()s.Timeframe=tf;s.Overlay=nil;firstPoint=nil;refresh()end,s.Timeframe==tf and C.Panel or false,s.Timeframe==tf and C.Blue or C.Text,15)
   end
  elseif s.Overlay=="Tools"then
   text(p,"Title","Chart tools",20,17,pw-80,29,18,C.Text,B)
   for i,t in ipairs({{"Pan","Drag to pan"},{"Crosshair","Crosshair"},{"Line","Horizontal line"},{"Trend","Trend line"},{"Clear","Clear drawings"}})do
    button(p,t[1],t[2],20,62+(i-1)*51,pw-40,45,function()if t[1]=="Clear"then table.clear(s.Drawings)else s.Tool=t[1]end;s.Overlay=nil;firstPoint=nil;refresh()end,C.Panel,C.Text,14)
   end
  elseif s.Overlay=="Menu"then
   text(p,"Title","Get Funded!",20,17,pw-80,29,18,C.Text,B)
   for i,t in ipairs({{"Guide","First-trade walkthrough"},{"History","Trade review"},{"Settings","Settings & market session"},{"Help","Trading help"},{"Accounts","Switch practice account"}})do
    button(p,t[1],t[2],20,62+(i-1)*53,pw-40,46,function()if t[1]=="History"then s.Sheet="Activity";s.Tab="History";s.Overlay=nil else s.Overlay=t[1];s.Guide=1 end;refresh()end,C.Panel,C.Text,13)
   end
  elseif s.Overlay=="Account"then
   local sum=session:Summary()
   text(p,"Title","Practice account",20,17,pw-80,29,18,C.Text,B)
   local stats={{"Balance",Market.Money(sum.Balance)},{"Equity",Market.Money(sum.Equity)},{"Unrealized P&L",Market.Signed(sum.Unrealized)},{"Session P&L",Market.Signed(sum.Session)},{"Loss remaining",Market.Money(sum.Allowance)}}
   for i,d in ipairs(stats)do
    text(p,"Label"..i,d[1],20,62+(i-1)*47,pw/2-20,42,12,C.Muted)
    text(p,"Value"..i,d[2],pw/2,62+(i-1)*47,pw/2-20,42,15,C.Text,N,RIGHT);rule(p,20,104+(i-1)*47,pw-40)
   end
   button(p,"SwitchAccount","Switch account",20,ph-72,pw-40,44,function()s.Overlay="Accounts";refresh()end,C.Panel,C.Blue,13)
   text(p,"Note","SIMULATED · Virtual funds only",20,ph-28,pw-40,20,10,C.Muted,M,CENTER)
  elseif s.Overlay=="Accounts"then
   text(p,"Title","Practice accounts",20,17,pw-80,29,18,C.Text,B)
   text(p,"Note","Separate virtual balances for each account.",20,58,pw-40,37,12,C.Muted).TextWrapped=true
   button(p,"Account50k","$50,000 Practice",20,107,pw-40,48,function()account(50000)end,C.Panel,C.Text,15)
   button(p,"Account100k","$100,000 Practice",20,166,pw-40,48,function()account(100000)end,C.Panel,C.Text,15)
  elseif s.Overlay=="Settings"then
   text(p,"Title","Workspace settings",20,17,pw-80,29,18,C.Text,B)
   button(p,"SelectAccount","Practice · "..Market.Money(s.Account).." →",20,70,pw-40,44,function()s.Overlay="Accounts";refresh()end,C.Panel,C.Text,13)
   button(p,"ShowLevels",(s.Levels and"☑ "or"☐ ").."Show entry, stop and target lines",20,127,pw-40,44,function()s.Levels=not s.Levels;refresh()end,C.Panel,C.Text,12)
   text(p,"ExchangeStatus",(session.ConnectionStatus or "SIMULATED PREVIEW").." · "..session.Speed.."x",20,184,pw-40,44,13,C.Blue,N).TextWrapped=true
   text(p,"Details","Server-run simulated order book. Prices and slippage come from executions. Virtual funds only; no fees or real market connection. Regime: "..session.Regime,20,243,pw-40,72,12,C.Muted).TextWrapped=true
  else
   text(p,"Title",s.Overlay=="Info"and"Trading terminology"or"Trading help",20,17,pw-80,29,18,C.Text,B)
   local t=text(p,"Body",s.Overlay=="Info"and s.Info or"Long aims to profit from rising prices. Short aims to profit from falling prices. A tick is the smallest price move. MES uses 0.25-point ticks, worth $1.25 per contract.",20,68,pw-40,ph-135,14,C.Muted);t.TextWrapped=true;t.TextYAlignment=Enum.TextYAlignment.Top
   button(p,"Learn","First-trade walkthrough →",20,ph-57,pw-40,42,function()s.Overlay="Guide";s.Guide=1;refresh()end,C.Panel,C.Blue,13)
  end
 end
 local function mobileBadge()
  if options.Preview then return "Preview · Simulated market · Virtual funds"end
  if not session.CanTrade then return session.Ready and "SIMULATED / PAUSED"or "SIMULATED / CONNECTING"end
  return session.PersistenceMode=="Local"and "Simulated · Local / not saved"or "Simulated market · Virtual funds"
 end
 local function mobileScreen(w,h,sum)
  local compact=w>h;local dense=h<650 and not compact
  local head=dense and 48 or 60;local navH=dense and 52 or 58;local dockH=dense and 152 or 190
  local top=frame(canvas,"TopNavigation",0,0,w,head,C.Bg)
  local acc=button(top,"Account","",12,0,w-70,58,function()s.Overlay="Account";refresh()end,false)
  text(acc,"Name","Get Funded!",0,dense and 0 or 3,w-70,dense and 26 or 30,dense and 20 or 22,C.Text,B)
  text(acc,"Brand",mobileBadge(),0,dense and 27 or 34,w-70,dense and 17 or 20,9,C.Muted)
  button(top,"More","···",w-54,2,44,48,function()s.Overlay="Menu";refresh()end,false,C.Blue,22)
  if compact then
   local dw=math.min(300,w*.39);local cx=w-dw-24
   accountCards(12,head,cx,56,true)
   chart(12,head+64,cx,h-head-76,true,true,true)
   mobileDock(cx+24,head+8,dw-12,dockH,false)
  else
   accountCards(12,head,w-24,dense and 54 or 58,true)
   local ah=h>=740 and 112 or 0
   local cy=head+(dense and 62 or 68);local ch=h-cy-navH-dockH-ah-(dense and 20 or 28)
   chart(12,cy,w-24,ch,true,h<650,false)
   mobileDock(12,cy+ch+10,w-24,dockH,dense)
   if ah>0 and s.Sheet~="Activity"then activity(12,h-navH-ah-8,w-24,ah,true,false)end
  end
  local nx=compact and w-math.min(300,w*.39)-12 or 0;local nw=w-nx
  local navigation=frame(canvas,"MobileNavigation",nx,h-navH,nw,navH,C.Bg,25);rule(navigation,0,0,nw)
  nav(navigation,0,0,nw,navH,true)
  if s.Sheet then
   local sw=compact and math.min(390,w-30)or w
   local sh=math.min(h-54,s.Sheet=="Activity"and 350 or s.Type=="Limit"and 540 or 475)
   local sx=w-sw;local sy=h-sh
   button(canvas,"SheetBackdrop","",0,0,w,h,function()s.Sheet=false;refresh()end,C.Bg,C.Text,12,30).BackgroundTransparency=.3
   local sheet=frame(canvas,"OptionsSheet",sx,sy,sw,sh,C.Panel,31);panel(sheet,C.Blue)
   text(sheet,"Title",s.Sheet=="Activity"and"Activity"or"Order settings",16,0,sw-74,48,15,C.Text,M)
   button(sheet,"Done","Done",sw-75,0,67,48,function()s.Sheet=false;refresh()end,false,C.Blue,13);rule(sheet,0,48,sw)
   if s.Sheet=="Activity"then activity(sx,sy+49,sw,sh-49,true,false,32)
   else
    local fields=make("ScrollingFrame","Fields",sheet,{Position=UDim2.fromOffset(0,49),Size=UDim2.fromOffset(sw,sh-49),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Muted,ZIndex=32})
    fields.CanvasSize=UDim2.fromOffset(0,orderOptions(fields,sw))
   end
  end
 end
 render=function()
  if not alive or not root.Parent then return end
  if drag then fullRefreshPending=true;return end
  local size=root.AbsoluteSize;local w=size.X>0 and size.X or 1440;local h=size.Y>0 and size.Y or 900;lastW=w;lastH=h
  local scroll={}
  for _,v in ipairs(canvas:GetDescendants())do if v:IsA("ScrollingFrame")then scroll[v:GetFullName()]=v.CanvasPosition end end
  canvas:ClearAllChildren();canvas.Size=UDim2.fromOffset(w,h)
  chartGeometry=nil;plotPool=nil
  s.Account=session.Base
  if session.Contract~=s.Contract or session.Timeframe~=s.Timeframe then session:Subscribe(s.Contract,s.Timeframe)end
  task.defer(function()if alive then for _,v in ipairs(canvas:GetDescendants())do if v:IsA("ScrollingFrame") and scroll[v:GetFullName()]then v.CanvasPosition=scroll[v:GetFullName()]end end end end)
  local mobile=w<1000 or h<600;local sum=session:Summary()
  if mobile then mobileScreen(w,h,sum)
  else
   local railW=w<1150 and 164 or 196;local gap=16;local statusH=28
   local cx=railW+gap;local usable=w-cx-20;local tw=w<1150 and 264 or 310;local cw=usable-tw-gap
   local rail=frame(canvas,"Sidebar",0,0,railW,h,C.Bg)
   frame(rail,"Edge",railW-1,16,1,h-32,C.Border)
   text(rail,"Wordmark","Get Funded!",20,24,railW-28,32,w<1150 and 20 or 24,C.Text,B)
   text(rail,"Simulation","Simulated market",20,62,railW-30,17,11,C.Muted)
   text(rail,"Funds","Virtual funds",20,80,railW-30,17,11,C.Muted)
   nav(rail,10,122,railW-20,52,false)
   if h>=700 then
    text(rail,"Markets","YOUR MARKETS",22,388,railW-35,24,10,C.Muted,M)
    for i,key in ipairs(Market.ContractOrder)do
     local b=button(rail,"Market"..key,"",12,423+(i-1)*42,railW-26,36,function()selectContract(key)end,key==s.Contract and C.Panel or false)
     text(b,"Symbol",key,12,0,55,36,12,key==s.Contract and C.Blue or C.Text,M)
     text(b,"Dot",key==s.Contract and"●"or"",railW-65,0,20,36,10,C.Blue,M,RIGHT)
    end
   end
   button(rail,"PracticeAccount",(s.Account==50000 and"$50K"or"$100K").." Practice  ⌄",14,h-112,railW-28,42,function()s.Overlay="Account";refresh()end,C.Panel,C.Text,12)
   button(rail,"Settings","Settings",16,h-60,railW-70,42,function()s.Overlay="Settings";refresh()end,false,C.Muted,11)
   button(rail,"Help","?",railW-49,h-60,36,42,function()s.Overlay="Help";refresh()end,false,C.Blue,17)
   accountCards(cx,22,cw,78,false)
   local ay=h-statusH-math.clamp(h*.2,152,206)-12
   chart(cx,116,cw,ay-132,false,false,false)
   ticket(cx+cw+gap,22,tw,ay-38)
   activity(cx,ay,usable,h-statusH-ay-12,false,false)
   local status=frame(canvas,"StatusBar",cx,h-statusH,usable,statusH,C.Bg)
   text(status,"Status",options.Preview and "EDIT PREVIEW · Press Play · Virtual funds"or"SIMULATED · "..session.Regime.." · Virtual funds",0,0,usable-286,statusH,9,C.Muted,N).TextTruncate=Enum.TextTruncate.AtEnd
   text(status,"ExchangeStatus",options.Preview and "SNAPSHOT · SIMULATED"or(session.ConnectionStatus or "CONNECTING"),usable-280,0,280,statusH,9,C.Blue,N,RIGHT).TextTruncate=Enum.TextTruncate.AtEnd
  end
  overlay(w,h)
  if s.Toast then
   local tw=math.min(480,w-24);local ty=mobile and 62 or 30
   local p=frame(canvas,"Toast",(w-tw)/2,ty,tw,49,C.Raised,60);round(p,10);stroke(p,s.Error and C.Red or C.Green)
   text(p,"Message",s.Toast,12,3,tw-24,43,12,C.Text,M,CENTER).TextWrapped=true
  end
  root:SetAttribute("Layout",mobile and"Mobile"or"Desktop");root:SetAttribute("SelectedContract",s.Contract)
  root:SetAttribute("Theme","After Hours")
  root:SetAttribute("Balance",sum.Balance);root:SetAttribute("Equity",sum.Equity);root:SetAttribute("UnrealizedPnL",sum.Unrealized)
  root:SetAttribute("PositionCount",sum.Count);root:SetAttribute("WorkingOrderCount",#session:Working());root:SetAttribute("Simulated",true);root:SetAttribute("SessionSeed",nil);root:SetAttribute("MarketStep",session.Step or 0)
  root:SetAttribute("ExchangeStatus",session.ConnectionStatus or "EDIT PREVIEW")
  root:SetAttribute("EditPreview",options.Preview==true)
 end
 table.insert(connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
  if math.abs(root.AbsoluteSize.X-lastW)>1 or math.abs(root.AbsoluteSize.Y-lastH)>1 then refresh()end
 end))
 if not options.Preview then
  table.insert(connections,UIS.InputBegan:Connect(function(ev,processed)
   if (not processed or drag)and ev.KeyCode==Enum.KeyCode.Escape then finishChartInput(false);s.Overlay=nil;s.Sheet=false;firstPoint=nil;refresh()end
  end))
  table.insert(connections,UIS.InputChanged:Connect(function(ev)
   if not drag then return end
   if drag.Kind==Enum.UserInputType.Touch then if ev~=drag.Input then return end
   elseif ev.UserInputType~=Enum.UserInputType.MouseMovement then return end
   local dx,dy=ev.Position.X-drag.Start.X,ev.Position.Y-drag.Start.Y
   if not drag.Moved and dx*dx+dy*dy<16 then return end
   drag.Moved=true
   if drag.Field then
    local tick=Market.Contracts[drag.Contract].Tick
    drag.Price=math.max(tick,Market.Snap(drag.Original-dy/drag.Height*(drag.View.High-drag.View.Low),drag.Contract))
   else Viewport.Pan(drag.State,drag.View,dx,dy,drag.Width,drag.Height)end
   navigationDirty=true
  end))
  table.insert(connections,UIS.InputEnded:Connect(function(ev)
   if drag and(ev==drag.Input or drag.Kind~=Enum.UserInputType.Touch and ev.UserInputType==drag.Kind)then finishChartInput(ev.UserInputState~=Enum.UserInputState.Cancel)end
  end))
  table.insert(connections,UIS.WindowFocusReleased:Connect(finishChartInput))
  local paintElapsed=0
  table.insert(connections,RunService.RenderStepped:Connect(function(dt)
   paintElapsed+=dt
   -- Input and network batches share one paint per display frame; no 30 Hz drag limiter.
   if navigationDirty or chartDirty then repaintChart()end
   if plotPool then plotPool:Step(dt)end
   if RunService:IsStudio()and paintElapsed>=1 then
    paintElapsed=0;root:SetAttribute("ChartPaintCount",paintCount)
    root:SetAttribute("ChartPaintMeanMs",paintTotal/math.max(1,paintCount));root:SetAttribute("ChartPaintMaxMs",paintMax)
   end
  end))
  local lastStructure=""
  local function marketUpdate()
   if not alive then return end
   if drag and drag.Field then
    local held=session.Positions[drag.Contract]
    if session.Base~=drag.Base or not held or held.Id~=drag.Id or held.Triggered or held[drag.Field]~=drag.Original then
     finishChartInput(false);toast("Position or protection changed. Drag cancelled.")
    end
   end
   if pendingProtection then
    local held=session.Positions[pendingProtection.Contract]
    if session.Base~=pendingProtection.Base or not held or held.Id~=pendingProtection.Id or held.Triggered or not held[pendingProtection.Field]then pendingProtection=nil end
   end
   local signature=tostring(session.Base)..":"..tostring(session.CanTrade)..":"..#session.Orders..":"..#session.History
   for _,key in ipairs(Market.ContractOrder)do
    local p=session.Positions[key]
    if p then signature..=key..p.Quantity..":"..p.Entry..":"..tostring(p.Stop)..":"..tostring(p.Target)end
   end
   for _,o in ipairs(session.Orders)do signature..=":"..o.Id..":"..o.Quantity end
   if signature~=lastStructure and not UIS:GetFocusedTextBox()then lastStructure=signature;refresh();return end
   -- Preserve controls, focus, scroll positions and overlays between network batches.
   local sum=session:Summary();local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y;local mobile=w<1000 or h<600
   chartDirty=true
   local metrics=canvas:FindFirstChild("AccountSummary")
   if metrics then
    for _,field in ipairs({"Balance","Equity","Unrealized","Session","Allowance"})do
     local label=metrics:FindFirstChild(field.."Value")
     if label then label.Text=(field=="Unrealized"or field=="Session")and Market.Signed(sum[field])or Market.Money(sum[field]);if field=="Unrealized"or field=="Session"then label.TextColor3=sum[field]>=0 and C.Green or C.Red end end
    end
   end
   local top=canvas:FindFirstChild("TopNavigation")
   if mobile and top and top:FindFirstChild("Account")then top.Account.Brand.Text=mobileBadge()end
   local held=session.Positions[s.Contract]
   for _,name in ipairs({"OrderTicket","TradeDock"})do local panel=canvas:FindFirstChild(name)
    if panel and held then local label=panel:FindFirstChild("Pnl",true);if label then label.Text=Market.Signed(session:Pnl(held));label.TextColor3=session:Pnl(held)>=0 and C.Green or C.Red end end
   end
   local activityPanel=canvas:FindFirstChild("Activity")
   if activityPanel and s.Tab=="Positions"then
    local index=0
    for _,key in ipairs(Market.ContractOrder)do local p=session.Positions[key];if p then index+=1
     local row=activityPanel:FindFirstChild("Row"..index,true);local label=row and(row:FindFirstChild("Pnl")or row:FindFirstChild("Cell5"))
     if label then label.Text=Market.Signed(session:Pnl(p));label.TextColor3=session:Pnl(p)>=0 and C.Green or C.Red end
    end end
   end
   local status=canvas:FindFirstChild("StatusBar")
   if status then
    status.Status.Text="SIMULATED · "..session.Regime.." · "..(session.News or "Order-driven prices / virtual USD")
    status.ExchangeStatus.Text=session.ConnectionStatus or "CONNECTING"
   end
   root:SetAttribute("ExchangeStatus",session.ConnectionStatus or "CONNECTING")
   root:SetAttribute("Balance",sum.Balance);root:SetAttribute("Equity",sum.Equity);root:SetAttribute("UnrealizedPnL",sum.Unrealized)
   root:SetAttribute("MarketStep",session.Step or 0)
  end
  table.insert(connections,session.Changed.Event:Connect(marketUpdate))
  table.insert(connections,session.Replies.Event:Connect(function(reply)
   if pendingProtection and reply.RequestId==pendingProtection.RequestId then pendingProtection=nil end
   s.Error=not reply.Ok and reply.Message or nil
   if reply.Ok and reply.Result and reply.Result.Filled>0 then s.Tab="Positions"end
   toast(reply.Message)
  end))
 end
 render()
 local controller={Root=root,State=s}
 function controller:Destroy()alive=false;session:Destroy();for _,c in ipairs(connections)do c:Disconnect()end;if root.Parent then root:Destroy()end end
 return controller
end
return UI
