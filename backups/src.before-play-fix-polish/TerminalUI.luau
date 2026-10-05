-- Native Roblox GUI. All panels and chart marks are editable GuiObjects.
local Market = require(script.Parent.MarketClient)
local ChartView = require(script.Parent.ChartView)
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UI = {}
local painting -- Chart painting is synchronous; input handlers live on a separate, stable surface.
local C = {
 -- Colorful game terminal. Opaque plotting surfaces preserve hollow candle readability.
 Bg=Color3.fromRGB(2,17,49), Panel=Color3.fromRGB(5,39,111), Raised=Color3.fromRGB(50,40,147),
 Chart=Color3.fromRGB(3,25,65), Border=Color3.fromRGB(27,92,196), Grid=Color3.fromRGB(20,62,119),
 Text=Color3.fromRGB(245,249,255), Muted=Color3.fromRGB(159,210,248), Blue=Color3.fromRGB(190,132,255),
 Green=Color3.fromRGB(46,249,160), Red=Color3.fromRGB(255,81,127), Buy=Color3.fromRGB(0,211,135), Sell=Color3.fromRGB(249,58,116),
 Cyan=Color3.fromRGB(0,220,255),
}
local F,M,B,N=Enum.Font.BuilderSans,Enum.Font.BuilderSansMedium,Enum.Font.FredokaOne,Enum.Font.RobotoMono
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
 local gamePanel=p.Name=="Chart"or p.Name=="OrderTicket"or p.Name=="Activity"
 round(p,gamePanel and 17 or 14)
 local edge=stroke(p,gamePanel and Color3.fromRGB(0,112,255)or accent or C.Border);edge.Thickness=gamePanel and 4 or 1
 if p.Name=="OrderTicket"or p.Name=="Activity"then
  p.BackgroundColor3=Color3.new(1,1,1)
  tint(p,p.Name=="OrderTicket"and Color3.fromRGB(52,29,190)or Color3.fromRGB(5,46,129),Color3.fromRGB(3,29,79))
 elseif p.BackgroundColor3~=C.Chart then tint(p)end
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
   BackgroundColor3=(b:GetAttribute("RestingColor")or base):Lerp(pressed and Color3.new(0,0,0)or Color3.new(1,1,1),pressed and .18 or hover and .07 or 0),
   Position=resting+UDim2.fromOffset(0,pressed and 1 or 0)})
  tween:Play()
 end
 b.MouseEnter:Connect(function()settle(true,false)end)
 b.MouseLeave:Connect(function()settle(false,false)end)
 b.MouseButton1Down:Connect(function()settle(false,true)end)
 b.MouseButton1Up:Connect(function()settle(true,false)end)
 return b
end
-- Applied only to trading chrome; numeric readouts retain their monospace font.
local function gameControl(b,selected)
 local gradient=b:FindFirstChild("ControlLight")
 if not gradient then
  b.BackgroundColor3=Color3.new(1,1,1);b:SetAttribute("RestingColor",Color3.new(1,1,1));b.Font=Enum.Font.FredokaOne
  b.TextColor3=C.Text
  gradient=make("UIGradient","ControlLight",b,{Rotation=90})
  local edge=b:FindFirstChild("Border")or stroke(b);edge.Thickness=2
  if not b:FindFirstChild("Corners")then round(b,9)end
  -- A gradient on a TextButton also tints its own text. A child label stays white.
  b.TextTransparency=1
  local label=text(b,"ControlLabel",b.Text,0,0,b.Size.X.Offset,b.Size.Y.Offset,b.TextSize,C.Text,Enum.Font.FredokaOne,Enum.TextXAlignment.Center,b.ZIndex+1)
  make("UIStroke","TextOutline",label,{Color=Color3.fromRGB(1,15,49),Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 end
 if b:GetAttribute("ControlSelected")~=selected then
  gradient.Color=ColorSequence.new(selected and Color3.fromRGB(134,67,255)or Color3.fromRGB(15,48,117),selected and Color3.fromRGB(75,25,210)or Color3.fromRGB(3,24,66))
  b.Border.Color=selected and C.Blue or C.Border;b:SetAttribute("ControlSelected",selected)
 end
 return b
end
local function gameHeading(label)
 label.Font=Enum.Font.FredokaOne
 make("UIStroke","TextOutline",label,{Color=Color3.fromRGB(1,15,49),Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 return label
end
local function panelStars(p)
 local w,h=p.Size.X.Offset,p.Size.Y.Offset
 for i,xy in ipairs({{.93,.09,20},{.96,.92,24},{.035,.92,20}})do
  local size=xy[3]
  local star=frame(p,"Star"..i,xy[1]*w-size/2,xy[2]*h-size/2,size,size,C.Panel,p.ZIndex);star.BackgroundTransparency=1
  for ray=0,4 do
   local angle=math.rad(-90+ray*72)
   local arm=frame(star,"Ray",size/2,size/2,size*.46,size*.28,Color3.fromRGB(29,98,226),p.ZIndex)
   arm.AnchorPoint=Vector2.new(0,.5);arm.Rotation=math.deg(angle);arm.BackgroundTransparency=.65;round(arm,size*.1)
  end
 end
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
 elseif kind=="Accounts"or kind=="Trophy"then
  l(.24,.12,.76,.12);l(.24,.12,.31,.5);l(.76,.12,.69,.5);l(.31,.5,.69,.5);l(.5,.5,.5,.72);l(.34,.72,.66,.72)
  l(.34,.72,.28,.9);l(.66,.72,.72,.9);l(.28,.9,.72,.9);l(.24,.2,.08,.2);l(.08,.2,.16,.4);l(.76,.2,.92,.2);l(.92,.2,.84,.4)
 elseif kind=="Lock"then
  l(.2,.45,.8,.45);l(.8,.45,.8,.9);l(.8,.9,.2,.9);l(.2,.9,.2,.45);l(.34,.45,.34,.2);l(.34,.2,.66,.2);l(.66,.2,.66,.45);l(.5,.6,.5,.75)
 elseif kind=="Copy"then
  l(.1,.32,.62,.32);l(.62,.32,.62,.9);l(.62,.9,.1,.9);l(.1,.9,.1,.32);l(.38,.32,.38,.1);l(.38,.1,.9,.1);l(.9,.1,.9,.68);l(.9,.68,.62,.68)
 elseif kind=="Check"then
  l(.14,.55,.4,.8);l(.4,.8,.88,.22)
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
-- Colorful game summary: uploaded transparent artwork with native, live text.
local SC={Ink=Color3.fromRGB(3,18,55),Green=Color3.fromRGB(50,255,91),Red=Color3.fromRGB(255,143,166)}
local SF=Enum.Font.FredokaOne
local summaryThemes={
 Balance={Top=Color3.fromRGB(0,171,255),Bottom=Color3.fromRGB(0,91,230),Edge=Color3.fromRGB(17,211,255),Base=Color3.fromRGB(0,56,153),Image="rbxassetid://84096597834437"},
 Equity={Top=Color3.fromRGB(137,57,255),Bottom=Color3.fromRGB(78,31,220),Edge=Color3.fromRGB(183,105,255),Base=Color3.fromRGB(56,12,145),Image="rbxassetid://135864586704544"},
 Unrealized={Top=Color3.fromRGB(0,216,107),Bottom=Color3.fromRGB(0,145,100),Edge=Color3.fromRGB(10,245,134),Base=Color3.fromRGB(0,84,66),Image="rbxassetid://140314319475475"},
 Trophy={Top=Color3.fromRGB(255,224,33),Bottom=Color3.fromRGB(255,167,0),Edge=Color3.fromRGB(255,244,98),Base=Color3.fromRGB(166,77,0),Image="rbxassetid://80175474742009"},
}
local function summarySurface(tile,kind,compact)
 local theme=summaryThemes[kind]
 local w,h=tile.Size.X.Offset,tile.Size.Y.Offset
 local radius=compact and 10 or 20
 local depth=compact and 3 or 8
 local base=frame(tile.Parent,kind.."Depth",tile.Position.X.Offset,tile.Position.Y.Offset+depth,w,h,theme.Base,2)
 round(base,radius);local outline=stroke(base,SC.Ink);outline.Thickness=compact and 3 or 6
 tile.ZIndex=3;tile.BackgroundColor3=Color3.new(1,1,1)
 tile.Border.Color=theme.Edge;tile.Border.Thickness=compact and 2 or 4
 tile.Corners.CornerRadius=UDim.new(0,radius)
 tint(tile,theme.Top,theme.Bottom)
 local texture=frame(tile,"Texture",5,5,w-10,h-10,theme.Top,3);texture.BackgroundTransparency=1
 texture.ClipsDescendants=true;round(texture,radius-3)
 if not compact then
  for i,xy in ipairs({{.1,.18},{.88,.2},{.12,.78},{.84,.8},{.55,.12}})do
   local d=frame(texture,"Diamond"..i,xy[1]*(w-20),xy[2]*(h-20),12,12,Color3.new(1,1,1),3)
   d.Rotation=45;d.BackgroundTransparency=.93;round(d,2)
  end
  local shine=frame(texture,"Shine",w*.16,-h*.25,w*.13,h*1.6,Color3.new(1,1,1),3)
  shine.Rotation=38;shine.BackgroundTransparency=.94
 end
end
local function summaryIcon(p,kind,x,y,size,negative)
 return make("ImageLabel","IconPanel",p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),
  BackgroundTransparency=1,Image=summaryThemes[kind].Image,ScaleType=Enum.ScaleType.Fit,ZIndex=5,
  Rotation=negative and 180 or 0,ImageColor3=negative and Color3.fromRGB(255,176,189)or Color3.new(1,1,1)})
end
local function summaryText(p,name,value,x,y,w,h,size,color,compact)
 local label=text(p,name,value,x,y,w,h,size,color or C.Text,SF,nil,6)
 label.TextScaled=true
 make("UITextSizeConstraint","TypeSize",label,{MinTextSize=compact and 8 or 10,MaxTextSize=size})
 make("UIStroke","TextOutline",label,{Color=SC.Ink,Thickness=compact and 1.5 or math.clamp(size*.09,2,4),ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual,LineJoinMode=Enum.LineJoinMode.Round})
 return label
end
local SB={Navy=Color3.fromRGB(3,27,78),Blue=Color3.fromRGB(6,49,130),Cyan=Color3.fromRGB(0,189,255),Muted=Color3.fromRGB(144,208,255)}
local sidebarImages={
 Trade="rbxassetid://135864586704544",Accounts="rbxassetid://80175474742009",Positions="rbxassetid://133669386970310",
 Review="rbxassetid://77222088024812",Learn="rbxassetid://103790301090850",Settings="rbxassetid://101222726907418",Help="rbxassetid://135400245653127",
}
local function sidebarImage(p,kind,x,y,size)
 return make("ImageLabel","Icon"..kind,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),
  BackgroundTransparency=1,Image=sidebarImages[kind],ScaleType=Enum.ScaleType.Fit,ZIndex=p.ZIndex+1})
end
local function sidebarText(p,name,value,x,y,w,h,size,color)
 local t=summaryText(p,name,value,x,y,w,h,size,color or C.Text,false)
 t.ZIndex=p.ZIndex+2;t.TextOutline.Thickness=math.clamp(size*.085,1,2.5)
 return t
end
local function sidebarSurface(b,selected,cyan)
 b.Corners.CornerRadius=UDim.new(0,12)
 b.Border.Color=selected and(cyan and Color3.fromRGB(34,232,255)or Color3.fromRGB(193,128,255))or Color3.fromRGB(24,65,143)
 b.Border.Thickness=selected and 3 or 2
 tint(b,selected and(cyan and Color3.fromRGB(0,184,255)or Color3.fromRGB(162,66,255))or Color3.fromRGB(5,37,103),
  selected and(cyan and Color3.fromRGB(0,99,235)or Color3.fromRGB(85,22,231))or Color3.fromRGB(3,23,68))
 if selected then
  local shine=frame(b,"Shine",7,5,b.Size.X.Offset-14,3,Color3.new(1,1,1),b.ZIndex+1)
  shine.BackgroundTransparency=.55;round(shine,2)
  local depth=frame(b,"LowerEdge",8,b.Size.Y.Offset-6,b.Size.X.Offset-16,3,SC.Ink,b.ZIndex+1)
  depth.BackgroundTransparency=.6;round(depth,2)
 end
end
function UI.Mount(gui,options)
 options=options or {}
 local old=gui:FindFirstChild("Workspace");if old then old:Destroy()end
 local root=make("Frame","Workspace",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Bg,BorderSizePixel=0,ClipsDescendants=true})
 local canvas=frame(root,"Canvas",0,0,1440,900,C.Bg)
 local s={Contract="MES",Timeframe="1m",Type="Market",Qty=2,Limit=5820,Stop=5802.5,Target=5842.5,StopOn=true,TargetOn=true,
  Tab="Positions",Nav="Trade",Sheet=false,ProtectionDraft=nil,StopTicks=40,TargetTicks=120,Overlay=nil,Guide=1,Tool="Pan",Drawings={},Levels=true,
  Screen=nil,Coach=nil,CopyDraft=nil,LastCopy=nil}
 local Ladder=Market.Progression
 local session=Market.New(nil,options.Preview,options.PreviewData)
 local render,dirty,alive=nil,false,true
 local connections={}
 local lastW,lastH=0,0
 local firstPoint,toastId=nil,0
 local views={}
 local repaintChart,chartView
 local fullRefreshPending=false
 local function refresh()
  if dirty or not alive then return end
  if chartView and chartView:Busy()then fullRefreshPending=true;return end
  local focused=UIS:GetFocusedTextBox();if focused and focused:IsDescendantOf(root)then return end
  dirty=true;task.defer(function()dirty=false;if alive and root.Parent then render()end end)
 end
 local function toast(message)
  toastId+=1;local id=toastId;s.Toast=message;refresh()
  task.delay(4,function()if alive and id==toastId then s.Toast=nil;refresh()end end)
 end
 -- Funded portfolio helpers. The server sends the portfolio view; the client never computes unlocks.
 local function whole(value)return(Market.Money(value):gsub("%.00$",""))end
 local function net(value)return(value or 0)<0 and "−"..whole(-value)or whole(value or 0)end
 local function activeRow()
  local pf=session.Portfolio;if not pf or not pf.Active then return nil end
  for _,list in ipairs({pf.Accounts or{},pf.Legacy or{}})do for _,row in ipairs(list)do if row.Key==pf.Active then return row end end end
 end
 local function accountName()
  local pf=session.Portfolio
  return pf and pf.ActiveName or(options.Preview and Ladder.Tiers[1].Name)or"Funded account"
 end
 local function accountShort()
  local pf=session.Portfolio
  return pf and pf.ActiveShort or(options.Preview and Ladder.Tiers[1].Short)or"Funded"
 end
 -- Label, headline, progress 0..1, amount and a one-line summary for the next objective.
 local function objective()
  local pf=session.Portfolio
  if not pf or pf.New then local t=Ladder.Tiers[2];return "NEXT UNLOCK",t and t.Name or"Ladder",0,t and("$0 / "..whole(t.Unlock))or"",t and("Next "..t.Short.." · $0 / "..whole(t.Unlock))or""end
  if pf.ActiveKind=="Legacy"then return "LEGACY PRACTICE","Not counted toward unlocks",0,"Net "..net(pf.Earned),"Legacy practice · not counted toward unlocks"end
  if not pf.FirstProfit then
   return "FIRST MILESTONE","Close a trade in profit",0,"Net "..net(pf.Earned),"First milestone: close a trade in profit"
  end
  if not pf.Next then return "LADDER COMPLETE","Every account unlocked",1,"Net "..net(pf.Earned),"Ladder complete · net "..net(pf.Earned)end
  local progress=math.clamp((pf.Earned or 0)/pf.Next.Unlock,0,1)
  local amount=net(pf.Earned).." / "..whole(pf.Next.Unlock)
  return "NEXT UNLOCK · "..pf.Next.Short,"Earn "..whole(pf.Next.Remaining).." more",progress,amount,"Next "..pf.Next.Short.." · "..amount
 end
 local function tierShort(key)for _,t in ipairs(Ladder.Tiers)do if t.Id==key then return t.Short end end return key end
 local function copyStatus()
  local pf=session.Portfolio;local copy=pf and pf.Copy
  if not copy or not copy.Enabled then return nil end
  local n=#copy.Followers
  if pf.Active==copy.Leader then return "Copying to "..n.." account"..(n==1 and""or"s"),true end
  if table.find(copy.Followers,pf.Active)then return "Follows "..tierShort(copy.Leader).." · trades here aren't copied",false end
  return "Copy trading on · "..tierShort(copy.Leader).." leads",false
 end
 local function selectContract(key)
  s.Contract=key;local c=Market.Contracts[key];local p=session.Positions[key]
  s.Limit=Market.Snap(session.Prices[key]-4*c.Scale,key)
  s.Stop=p and p.Stop or Market.Snap(session.Prices[key]-22.25*c.Scale,key)
  s.Target=p and p.Target or Market.Snap(session.Prices[key]+17.75*c.Scale,key)
  s.StopOn=true;s.TargetOn=true;s.Error=nil;s.Overlay=nil;chartView:CancelPlacement()
  if s.Coach==1 then s.Coach=2 end
  refresh()
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
 local function account(key)
  local ok,message=session:Account(key);s.Overlay=nil;s.Error=nil
  if not ok then toast(message)else refresh()end
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
  s.Overlay=nil;s.Sheet=false
  if value=="Accounts"then s.Nav=value;s.Screen="Dashboard";refresh();return end
  if s.Screen=="Dashboard"then
   if not(session.Portfolio and session.Portfolio.Active)then toast("Start a funded account to open the trading workspace.");return end
   s.Screen="Trade"
  end
  s.Nav=value
  if value=="Learn"then s.Overlay="Guide";s.Guide=1
  elseif value=="Review"then s.Tab="History";if mobile then s.Sheet="Activity"end
  elseif value=="Positions"then s.Tab="Positions";if mobile then s.Sheet="Activity"end
  else s.Tab="Positions"end
  refresh()
 end
 local function nav(p,x,y,w,h,mobile)
  local items={"Trade","Accounts","Positions","Review","Learn"}
  for i,value in ipairs(items)do
   local cell=mobile and w/#items or w
   local bx=mobile and x+(i-1)*cell+3 or x
   local by=mobile and y+2 or y+(i-1)*(h+9)
   local bw=mobile and cell-6 or w
   local bh=mobile and h-4 or h
   local selected=s.Nav==value
   local b=button(p,"Nav"..value,"",bx,by,bw,bh,function()navigate(value,mobile)end,Color3.new(1,1,1),C.Text,12,p.ZIndex+2)
   sidebarSurface(b,selected,false)
   local iconSize=mobile and math.min(28,bh-22)or math.min(42,bh-8)
   sidebarImage(b,value,mobile and(bw-iconSize)/2 or 11,mobile and 3 or(bh-iconSize)/2,iconSize)
   local label=sidebarText(b,"Label",value,mobile and 2 or iconSize+20,mobile and bh-20 or 0,mobile and bw-4 or bw-iconSize-28,mobile and 18 or bh,mobile and 10 or 21)
   if mobile then label.TextXAlignment=CENTER end
   if selected and not mobile then
    local marker=frame(b,"Selected",3,10,3,bh-20,Color3.new(1,1,1),b.ZIndex+1);round(marker,2)
   end
  end
 end
 local function accountCards(x,y,w,h,mobile)
  local sum=session:Summary()
  local p=frame(canvas,"AccountSummary",x,y,w,h,C.Bg);p.BackgroundTransparency=1
  local tiles=mobile and 3 or 4
  local gap=mobile and 8 or 18;local cw=(w-gap*(tiles-1))/tiles
  local cardH=h-(mobile and 4 or 10)
  local legacy=session.Portfolio and session.Portfolio.ActiveKind=="Legacy"
  local side=not mobile and cw>=275
  local pad=mobile and 9 or 14
  local iconSize=side and math.min(cw*.4,cardH-30)or 36
  local inset=side and pad+iconSize+2 or pad
  local valueY=side and cardH*.34 or 52
  local valueH=side and math.min(58,cardH*.29)or 34
  local valueSize=side and math.clamp(cw*.12,30,48)or 26
  for i,d in ipairs({{"Balance",mobile and"BALANCE"or legacy and"PRACTICE BALANCE"or"FUNDED BALANCE",sum.Balance},
   {"Equity",mobile and"EQUITY"or"ACCOUNT EQUITY",sum.Equity},{"Unrealized","OPEN P&L",sum.Unrealized}})do
   local bx=(i-1)*(cw+gap)
   local tile=button(p,d[1].."Card","",bx,0,cw,cardH,function()s.Overlay="Account";refresh()end,Color3.new(1,1,1))
   summarySurface(tile,d[1],mobile)
   local accent=i==3 and(d[3]>=0 and SC.Green or SC.Red)or C.Text
   local value=i==3 and Market.Signed(d[3])or Market.Money(d[3])
   if mobile then
    summaryText(tile,"Label",d[2],pad,4,cw-2*pad,16,10,C.Text,true)
    summaryText(p,d[1].."Value",value,bx+pad,23,cw-2*pad,23,w<370 and 12 or 14,accent,true)
   else
    summaryIcon(tile,d[1],side and 6 or pad,side and(cardH-iconSize)/2 or 10,iconSize,i==3 and d[3]<0)
    local lx=side and inset or pad+iconSize+8
    summaryText(tile,"Label",d[2],lx,side and cardH*.16 or 17,cw-lx-pad,side and 30 or 20,side and 22 or 12)
    summaryText(p,d[1].."Value",value,bx+inset,valueY,cw-inset-pad,valueH,valueSize,accent)
    if i==1 then
     local badgeX=side and inset or pad
     local badgeW=cw-badgeX-pad
     local badge=frame(tile,"AccountBadge",badgeX,cardH-44,badgeW,29,Color3.fromRGB(0,44,107),4)
     round(badge,15);stroke(badge,SC.Ink).Thickness=4
     local rim=frame(badge,"Rim",3,3,badgeW-6,23,Color3.fromRGB(0,63,134),4);round(rim,12);stroke(rim,summaryThemes.Balance.Edge).Thickness=2
     local label=summaryText(badge,"Label",accountShort()..(legacy and" PRACTICE"or" ACCOUNT"),7,2,badgeW-14,25,17)
     label.TextXAlignment=CENTER
    end
   end
  end
  if mobile then return end
  local label,title,progress,amount=objective()
  local pf=session.Portfolio
  if pf and pf.ActiveKind~="Legacy"and pf.Next then
   label="NEXT UNLOCK";title=pf.Next.Name or(pf.Next.Short.." Funded")
   progress=math.clamp((pf.Earned or 0)/pf.Next.Unlock,0,1);amount=net(pf.Earned).." / "..whole(pf.Next.Unlock)
  end
  local tile=button(p,"ObjectiveCard","",3*(cw+gap),0,cw,cardH,function()navigate("Accounts")end,Color3.new(1,1,1))
  summarySurface(tile,"Trophy",false)
  local trophySize=side and math.min(iconSize,cardH-58)or iconSize
  summaryIcon(tile,"Trophy",side and 7 or pad,side and 14 or 10,trophySize)
  local lx=side and inset or pad+iconSize+8
  summaryText(tile,"Label",label,lx,side and cardH*.13 or 17,cw-lx-pad,side and 28 or 20,side and 22 or 12)
  summaryText(tile,"Title",title,inset,side and cardH*.34 or 51,cw-inset-pad,side and 39 or 30,side and 32 or 23)
  summaryText(tile,"Amount",amount,inset,cardH-68,cw-inset-pad,25,side and 24 or 18)
  local tw=cw-2*pad
  local track=frame(tile,"Track",pad,cardH-33,tw,21,SC.Ink,4);round(track,11);stroke(track,SC.Ink).Thickness=4
  local well=frame(track,"Well",3,3,tw-6,15,Color3.fromRGB(8,31,84),4);round(well,8);stroke(well,Color3.fromRGB(38,77,161)).Thickness=2
  if progress>0 then
   local fill=frame(track,"Fill",4,4,math.max(9,(tw-8)*progress),13,Color3.new(1,1,1),5);round(fill,7)
   local glow=tint(fill,Color3.fromRGB(255,248,137),Color3.fromRGB(255,187,16));glow.Rotation=90
  end
  -- A zero-value track stays visibly empty, as in the reference.
 end
 -- The candlestick chart, its navigation and drawing tools live in ChartView (presentation only).
 chartView=ChartView.new({C=C,F=F,M=M,B=B,N=N,Market=Market,Session=session,State=s,Options=options,Root=root,Canvas=canvas,
  frame=frame,text=text,button=button,stroke=stroke,round=round,line=line,dash=dash,rule=rule,panel=panel,
  control=gameControl,heading=gameHeading,tint=tint,stars=panelStars,
  setPainting=function(pool)painting=pool end,refresh=refresh,toast=toast,
  onIdle=function(chrome)
   if fullRefreshPending or chrome then fullRefreshPending=false;refresh()else repaintChart()end
  end})
 local function chart(x,y,w,h,mobile,compact,short,updating)
  chartView:Paint(x,y,w,h,mobile,compact,updating)
 end
 repaintChart=function()
  if not alive or not root.Parent or s.Sheet or s.Overlay then return end
  local p=canvas:FindFirstChild("Chart");if not p then return end
  local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
  chartView.Dirty=false
  local mobile=w<1000 or h<600
  chart(p.Position.X.Offset,p.Position.Y.Offset,p.Size.X.Offset,p.Size.Y.Offset,mobile,mobile and(w>h or h<650),false,true)
 end
 local function activity(x,y,w,h,mobile,compact,z)
  local p=frame(canvas,"Activity",x,y,w,h,C.Panel,z);panel(p);panelStars(p);p.ClipsDescendants=true
  local sum=session:Summary();local working=session:Working()
  local tabs={{"Positions","Open positions · "..sum.Count},{"Orders","Orders · "..#working},{"History","Trade history"}}
  local top=compact and 0 or 43
  if not compact then
   local tw=math.min((w-20)/3,186)
   for i,item in ipairs(tabs)do
    local bx=10+(i-1)*tw
    gameControl(button(p,"Tab"..item[1],item[2],bx,5,tw-6,36,function()s.Tab=item[1];refresh()end,C.Panel,C.Text,mobile and 11 or 14),s.Tab==item[1])
    if s.Tab==item[1]then rule(p,bx+8,41,tw-16,C.Blue)end
   end
   rule(p,0,42,w)
  end
  local data={}
  if s.Tab=="Positions"or compact then for _,key in ipairs(Market.ContractOrder)do if session.Positions[key]then table.insert(data,session.Positions[key])end end
  elseif s.Tab=="Orders"then data=working else data=session.History end
  if #data==0 then
   local showIcon=not compact and h-top>=108
   local iconSize=showIcon and math.clamp(h-top-69,34,55)or 0
   local titleY=showIcon and top+iconSize+12 or top+10
   if showIcon then sidebarImage(p,s.Tab=="History"and"Review"or"Positions",(w-iconSize)/2,top+8,iconSize)end
   gameHeading(text(p,"EmptyTitle",s.Tab=="Positions"and"No open positions"or s.Tab=="Orders"and"No working orders"or"No completed trades yet",12,titleY,w-24,24,showIcon and 18 or 13,C.Text,B,CENTER))
   if not compact then text(p,"EmptyDetail",s.Tab=="Positions"and"Choose a contract and place a simulated order."or s.Tab=="Orders"and"Limit and protective orders appear here."or"Close a position to review your result.",12,titleY+26,w-24,23,mobile and 10 or 12,C.Muted,F,CENTER)end
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
  for _,d in ipairs({{1,"BuyLong",s.Type=="Limit"and"↑ BUY LIMIT"or"↑ BUY",C.Buy,0},{-1,"SellShort",s.Type=="Limit"and"↓ SELL LIMIT"or"↓ SELL",C.Sell,bw+8}})do
   local enabled=options.Preview or session.CanTrade
   local b=button(p,d[2],d[3],x+d[5],y,bw,48,function()if enabled then place(d[1])end end,enabled and d[4]or C.Raised,enabled and C.Text or C.Muted,16)
   b.Active=enabled;b.Selectable=enabled;b.Font=B;b.TextSize=20;b.Corners.CornerRadius=UDim.new(0,11)
   if enabled then
    b.BackgroundColor3=Color3.new(1,1,1);b:SetAttribute("RestingColor",Color3.new(1,1,1))
    tint(b,d[1]>0 and Color3.fromRGB(34,253,158)or Color3.fromRGB(255,120,168),d[1]>0 and Color3.fromRGB(0,173,112)or Color3.fromRGB(231,40,99))
    local shine=frame(b,"Shine",8,4,bw-16,3,Color3.new(1,1,1),b.ZIndex);shine.BackgroundTransparency=.35;round(shine,2)
   else tint(b)end
   b.TextTransparency=1
   local label=text(b,"ActionLabel",d[3],5,0,bw-10,48,20,enabled and C.Text or C.Muted,B,CENTER,b.ZIndex+1)
   label.TextScaled=true;make("UITextSizeConstraint","TextSize",label,{MinTextSize=10,MaxTextSize=20})
   make("UIStroke","TextOutline",label,{Color=d[1]>0 and Color3.fromRGB(0,132,84)or Color3.fromRGB(174,24,75),Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
   b.Border.Thickness=3;b.Border.Color=enabled and(d[1]>0 and Color3.fromRGB(129,255,202)or Color3.fromRGB(255,168,197))or C.Border
   b:SetAttribute("Direction",d[1])
  end
 end
 local function openProtection()
  s.ProtectionDraft={StopOn=s.StopOn,TargetOn=s.TargetOn,StopTicks=s.StopTicks,TargetTicks=s.TargetTicks}
  s.Sheet=false;s.Overlay="Protection";s.Error=nil;refresh()
 end
 local function closeProtection()
  s.ProtectionDraft=nil;s.Overlay=nil;s.Error=nil;refresh()
 end
 local function numericStepper(p,name,x,y,w,value,step,minimum,maximum,setter,formatter,enabled)
  local height=44;local bw=math.min(44,math.floor((w-32)/2))
  local shell=frame(p,name,x,y,w,height,C.Bg,p.ZIndex);round(shell,10);stroke(shell,Color3.fromRGB(26,99,212)).Thickness=2
  local current=value
  local field=make("TextBox","Value",shell,{Position=UDim2.fromOffset(bw,0),Size=UDim2.fromOffset(w-bw*2,height),BackgroundTransparency=1,
   Text=formatter and formatter(value)or tostring(value),TextColor3=enabled==false and C.Muted or C.Text,Font=B,TextSize=24,TextScaled=true,
   ClearTextOnFocus=false,TextEditable=enabled~=false,BorderSizePixel=0,ZIndex=shell.ZIndex+1})
  make("UITextSizeConstraint","TextSize",field,{MinTextSize=10,MaxTextSize=24})
  local function display(n)return formatter and formatter(n)or tostring(n)end
  local function commit()
   if enabled==false then return true end
   local n=tonumber((field.Text:gsub("[, $]","")))
   if not n or n~=n or math.abs(n)==math.huge or n<minimum or n>maximum or(step==1 and n%1~=0)then
    s.Error=step==1 and("Enter a whole number from "..minimum.." to "..maximum..".")or"Enter a valid positive limit price."
    field.Text=display(current);toast(s.Error);return false
   end
   n=math.clamp(math.round(n/step)*step,minimum,maximum)
   current=n;field.Text=display(n);setter(n);s.Error=nil;return true
  end
  field.FocusLost:Connect(function()
   if not commit()then return end
   -- Keep the clicked control alive when an input loses focus to a button.
   local contract=Market.Contracts[s.Contract]
   for _,item in ipairs(canvas:GetDescendants())do
    if item.Name=="Risk"and item:IsA("TextLabel")then
     item.Text=s.StopOn and("Estimated risk  "..Market.Money(s.StopTicks*contract.Tick*contract.Multiplier*s.Qty))or"No stop loss configured"
    end
   end
  end)
  for _,d in ipairs({{"Decrease","−",-1,0},{"Increase","+",1,w-bw}})do
   local control=gameControl(button(shell,d[1],d[2],d[4],0,bw,height,function()
    if enabled==false or not commit()then return end
    current=math.clamp(math.round((current+d[3]*step)/step)*step,minimum,maximum)
    field.Text=display(current);setter(current);s.Error=nil;refresh()
   end,C.Raised,C.Text,23,shell.ZIndex+1),true)
   control.Active=enabled~=false;control.Selectable=enabled~=false
   if enabled==false then control.ControlLabel.TextColor3=C.Muted end
  end
  return shell,commit
 end
 local function quantity(p,x,y,w)
  numericStepper(p,"Quantity",x,y,w,s.Qty,1,1,20,function(n)s.Qty=n;if s.Coach==2 then s.Coach=3 end end)
 end
 local function protectionIcon(p,key,x,y,size)
  local color=key=="Stop"and C.Red or C.Green
  local box=frame(p,"Icon"..key,x,y,size,size,C.Bg,p.ZIndex+1);box.BackgroundTransparency=1
  if key=="Target"then
   local ring=frame(box,"Ring",2,2,size-4,size-4,C.Bg,box.ZIndex);ring.BackgroundTransparency=1;round(ring,size);stroke(ring,color).Thickness=3
   local dot=frame(box,"Bullseye",size*.37,size*.37,size*.26,size*.26,color,box.ZIndex);round(dot,size)
   line(box,"Arrow",size*.65,size*.35,size*.94,size*.06,color,3,box.ZIndex)
  else
   local tip=frame(box,"ShieldTip",size*.2,size*.3,size*.6,size*.6,color,box.ZIndex);tip.Rotation=45;round(tip,3)
   local top=frame(box,"Shield",size*.1,size*.12,size*.8,size*.58,color,box.ZIndex);round(top,4)
   local gleam=frame(top,"Gleam",size*.1,size*.05,size*.22,size*.4,Color3.fromRGB(255,157,177),box.ZIndex+1);round(gleam,2)
  end
 end
 local function protectionCards(p,x,y,w)
  local cw=(w-10)/2
  for i,d in ipairs({{"Stop","Stop Loss",C.Red},{"Target","Take Profit",C.Green}})do
   local key=d[1];local enabled=s[key.."On"]
   local card=frame(p,key.."Card",x+(i-1)*(cw+10),y,cw,105,C.Bg,p.ZIndex);round(card,12);stroke(card,d[3]).Thickness=3
   local header=button(card,"Settings","",4,3,cw-8,32,openProtection,false,C.Text,12,card.ZIndex+1)
   protectionIcon(header,key,3,6,20)
   sidebarText(header,"Label",d[2],27,0,cw-45,32,cw<135 and 11 or 13)
   local toggle=button(card,"Toggle",enabled and"ON"or"OFF",cw-35,34,31,18,function()s[key.."On"]=not s[key.."On"];refresh()end,false,enabled and d[3]or C.Muted,9,card.ZIndex+1)
   numericStepper(card,"Distance",6,53,cw-12,s[key.."Ticks"],1,1,10000,function(n)s[key.."Ticks"]=n end,nil,enabled)
   text(card,"Unit","ticks",8,33,cw-46,18,10,C.Muted)
  end
 end
 local function orderOptions(p,w,startY,withQuantity)
  local pad=16;local iw=w-32;local yy=startY or 12
  gameHeading(text(p,"OrderTypeLabel","Order type",pad,yy,iw,21,16,C.Text,B));yy+=26
  local seg=frame(p,"OrderType",pad,yy,iw,40,C.Bg,p.ZIndex);seg.BackgroundTransparency=1
  for i,kind in ipairs({"Market","Limit"})do
   gameControl(button(seg,kind,kind,(i-1)*(iw+8)/2,0,(iw-8)/2,40,function()s.Type=kind;s.Error=nil;refresh()end,C.Panel,C.Text,16,seg.ZIndex),s.Type==kind)
  end
  yy+=45
  local hint=text(p,"OrderExplanation",s.Type=="Market"and"Executes at the available market price"or"Executes at your limit price or better",pad,yy,iw,28,w<300 and 10 or 11,C.Muted,F,CENTER)
  hint.TextWrapped=true;yy+=34
  if s.Type=="Limit"then
   gameHeading(text(p,"LimitLabel","Limit price",pad,yy,iw,21,16,C.Text,B));yy+=25
   local tick=Market.Contracts[s.Contract].Tick
   numericStepper(p,"LimitPrice",pad,yy,iw,s.Limit,tick,tick,99999999,function(n)s.Limit=Market.Snap(n,s.Contract)end,Market.Number);yy+=50
   local current=text(p,"CurrentPrice","Current "..Market.Number(session.Prices[s.Contract]),pad,yy,iw-105,30,11,C.Muted,N)
   current.TextScaled=true;make("UITextSizeConstraint","TextSize",current,{MinTextSize=8,MaxTextSize=11})
   local use=gameControl(button(p,"UseCurrent","Use current",w-113,yy,97,30,function()s.Limit=Market.Snap(session.Prices[s.Contract],s.Contract);s.Error=nil;refresh()end,C.Panel,C.Text,11),false)
   use.Border.Color=C.Cyan;yy+=38
  end
  if withQuantity then
   gameHeading(text(p,"QtyLabel","Quantity",pad,yy,iw,21,16,C.Text,B));yy+=25
   quantity(p,pad,yy,iw);yy+=52
  end
  gameHeading(text(p,"ProtectionLabel","Trade protection",pad,yy,iw-91,32,w<300 and 13 or 15,C.Text,B))
  local settings=gameControl(button(p,"ProtectionSettings","Settings",w-100,yy,84,32,openProtection,C.Panel,C.Text,11),false)
  settings.Border.Color=C.Cyan
  yy+=39;protectionCards(p,pad,yy,iw);yy+=109
  text(p,"ProtectionHint","Distances from entry",pad,yy,iw,22,11,C.Muted,F,CENTER);yy+=26
  if s.Error then local warning=text(p,"Error",s.Error,pad,yy,iw,36,11,C.Red);warning.TextWrapped=true;yy+=40 end
  return yy
 end
 local function ticket(x,y,w,h)
  local p=frame(canvas,"OrderTicket",x,y,w,h,C.Panel);panel(p,C.Blue);panelStars(p);p.ClipsDescendants=true
  local held=session.Positions[s.Contract];local iw=w-32
  gameHeading(text(p,"Title","Place a trade",20,10,iw,36,w<300 and 24 or 28,C.Text,B))
  local copying,leading=copyStatus()
  text(p,"Subtitle",copying or(accountName().." · Virtual funds"),20,44,iw,22,11,copying and C.Blue or C.Muted).TextTruncate=Enum.TextTruncate.AtEnd
  -- Keep order actions reachable while the longer Limit form scrolls.
  local fixed=h>=480
  local footerH=held and 220 or 140
  local sc=make("ScrollingFrame","Fields",p,{Position=UDim2.fromOffset(0,78),Size=UDim2.fromOffset(w,fixed and h-90-footerH or h-90),
   CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Blue,ZIndex=p.ZIndex})
  gameControl(button(sc,"ContractSelector",s.Contract.." · "..Market.Contracts[s.Contract].Short.."  ⌄",16,0,iw,44,function()s.Overlay="Contracts";refresh()end,C.Bg,C.Text,12),false)
  local yy=orderOptions(sc,w,54,true)
  local actionParent=sc
  if fixed then
   sc.CanvasSize=UDim2.fromOffset(0,yy+6)
   actionParent=frame(p,"OrderActions",0,h-footerH,w,footerH,C.Panel,p.ZIndex+1);actionParent.BackgroundTransparency=1;yy=0
  end
  tradeButtons(actionParent,16,yy+4,iw);yy+=58
  local contract=Market.Contracts[s.Contract]
  text(actionParent,"Risk",s.StopOn and("Estimated risk  "..Market.Money(s.StopTicks*contract.Tick*contract.Multiplier*s.Qty))or"No stop loss configured",16,yy,iw,22,11,C.Muted,N,CENTER);yy+=28
  rule(actionParent,16,yy,iw);yy+=6
  if held then
   text(actionParent,"Position",(held.Direction>0 and"LONG "or"SHORT ")..held.Quantity.." · "..held.Contract,16,yy,iw,21,12,held.Direction>0 and C.Green or C.Red,M);yy+=24
   text(actionParent,"Pnl",Market.Signed(session:Pnl(held)),16,yy,iw,27,21,session:Pnl(held)>=0 and C.Green or C.Red,N);yy+=30
   gameControl(button(actionParent,"ClosePosition","Close position",16,yy,iw,36,function()close(held.Contract)end,C.Raised,C.Text,13),false);yy+=40
  else text(actionParent,"NoPosition","No open position",16,yy,iw,18,11,C.Muted);yy+=20 end
  text(actionParent,"Simulation","SIMULATED · Virtual funds only",16,yy,iw,18,9,C.Muted,F,CENTER);yy+=22
  if not fixed then sc.CanvasSize=UDim2.fromOffset(0,yy)end
 end
 local function mobileDock(x,y,w,h,compact)
  local p=frame(canvas,"TradeDock",x,y,w,h,C.Bg,10)
  local qw=math.min(144,w*.45)
  text(p,"QtyLabel","Quantity",2,0,w-qw-58,44,11,C.Muted)
  quantity(p,w-qw-51,0,qw)
  button(p,"OrderSettings","···",w-44,0,44,44,function()s.Sheet=true;refresh()end,false,C.Blue,21)
  local cw=(w-8)/2
  for i,d in ipairs({{"Stop","SL · Stop loss",s.StopOn,s.StopTicks},{"Target","TP · Take profit",s.TargetOn,s.TargetTicks}})do
   local b=button(p,d[1].."Card","",(i-1)*(cw+8),compact and 50 or 52,cw,compact and 40 or 56,openProtection,C.Panel)
   if compact then
    text(b,"Distance",(i==1 and"SL · "or"TP · ")..(d[3]and tostring(d[4]).." ticks"or"Off"),6,0,cw-12,40,11,C.Text,N,CENTER)
   else
    text(b,"Label",d[2],10,3,cw-20,20,10,C.Muted)
    text(b,"Distance",d[3]and tostring(d[4]).." ticks"or"Off",10,25,cw-20,24,14,C.Text,N)
   end
  end
  local copying,leading=copyStatus()
  if not compact then text(p,"ProtectionHint",copying and(s.Type.." · "..copying)or(s.Type.." · Auto-close distances from entry"),0,111,w,21,9,copying and leading and C.Blue or C.Muted,F,CENTER)end
  tradeButtons(p,0,compact and 98 or 138,w)
 end
 local steps={
  {"Your workspace, your pace","Choose a futures contract, study the chart, and use the order ticket to practice. All prices and funds are simulated."},
  {"Read a candle","Each candle shows open, high, low, and close. Green closes higher; red closes lower. The bars underneath show volume. Change the timeframe to explore."},
  {"Plan before you enter","Market orders consume available liquidity and may fill partially. Limit orders rest at your price or better. Stops and targets trigger closing orders; slippage depends on liquidity."},
  {"Manage your position","Drag the SL or TP line or its price label to change protection. Release to submit; Esc cancels. Prices snap to ticks. Close Position realizes P&L and cancels protection. All funds are simulated."},
 }
 local function accountDetailStats()
  local sum=session:Summary();local row=activeRow()
  local realized=row and row.Realized or sum.Balance-session.Base
  return {
   {"Account size",Market.Money(session.Base),C.Text},
   {"Balance",Market.Money(sum.Balance),C.Text},
   {"Equity",Market.Money(sum.Equity),C.Text},
   {"Open P&L",Market.Signed(sum.Unrealized),sum.Unrealized>=0 and SC.Green or SC.Red},
   {"Realized on this account",Market.Signed(realized),realized>=0 and SC.Green or SC.Red},
   {"Loss remaining",Market.Money(sum.Allowance),sum.Allowance>0 and Color3.fromRGB(255,219,51)or SC.Red},
  }
 end
 local function updateAccountDetails()
  local dialog=canvas:FindFirstChild("Dialog")
  local rows=dialog and dialog:FindFirstChild("AccountStats")
  if not rows then return end
  for i,d in ipairs(accountDetailStats())do
   local value=rows:FindFirstChild("Value"..i)
   if value then value.Text=d[2];value.TextColor3=d[3]end
  end
 end
 local function accountDetails(w,h)
  local pw=math.min(560,w-28)
  local ph=math.min(h-28,math.max(520,pw*1.25))
  local narrow=pw<400;local short=h<500
  local headerH=short and 96 or narrow and 100 or 140
  local footerH=short and 94 or narrow and 96 or 118
  local pad=narrow and 16 or 24
  local shell=frame(canvas,"Dialog",(w-pw)/2,(h-ph)/2,pw,ph,Color3.new(1,1,1),41)
  round(shell,23);stroke(shell,Color3.fromRGB(4,221,255)).Thickness=5
  tint(shell,Color3.fromRGB(6,56,147),Color3.fromRGB(3,30,83))
  local inset=frame(shell,"InnerRim",5,5,pw-10,ph-10,Color3.new(1,1,1),41);inset.BackgroundTransparency=1
  round(inset,19);stroke(inset,Color3.fromRGB(31,125,255)).Thickness=2
  local hero=frame(shell,"AccountHeader",9,9,pw-18,headerH-9,Color3.new(1,1,1),42)
  round(hero,18);stroke(hero,Color3.fromRGB(168,100,255)).Thickness=3
  tint(hero,Color3.fromRGB(162,76,255),Color3.fromRGB(87,33,237))
  panelStars(hero)
  local trophySize=short and 70 or narrow and 70 or 111
  sidebarImage(hero,"Accounts",10,(headerH-9-trophySize)/2,trophySize)
  local titleX=trophySize+18
  local closeSize=narrow and 40 or 48
  local title=sidebarText(hero,"Title",accountName(),titleX,short and 14 or narrow and 13 or 25,pw-titleX-closeSize-37,narrow and 34 or 51,narrow and 31 or 47)
  local legacy=session.Portfolio and session.Portfolio.ActiveKind=="Legacy"
  local kind=sidebarText(hero,"Kind",legacy and"LEGACY PRACTICE · NOT COUNTED TOWARD UNLOCKS"or"FUNDED ACCOUNT · SIMULATED CAPITAL",titleX,short and 52 or narrow and 51 or 80,pw-titleX-33,short and 29 or narrow and 30 or 28,narrow and 12 or 15,Color3.fromRGB(236,227,255))
  kind.TextWrapped=true
  local dismiss=button(hero,"Dismiss","",pw-closeSize-32,12,closeSize,closeSize,function()s.Overlay=nil;refresh()end,Color3.new(1,1,1),C.Text,20,44)
  dismiss.Corners.CornerRadius=UDim.new(0,12);dismiss.Border.Color=Color3.fromRGB(255,158,175);dismiss.Border.Thickness=3
  tint(dismiss,Color3.fromRGB(255,109,136),Color3.fromRGB(227,33,77))
  local crossPad=closeSize*.29
  for _,points in ipairs({{crossPad,crossPad,closeSize-crossPad,closeSize-crossPad},{crossPad,closeSize-crossPad,closeSize-crossPad,crossPad}})do
   local shadow=line(dismiss,"CrossShadow",points[1],points[2],points[3],points[4],Color3.fromRGB(174,21,52),8,45);round(shadow,4)
   local cross=line(dismiss,"Cross",points[1],points[2],points[3],points[4],C.Text,5,46);round(cross,3)
  end
  local rowsY=headerH+12
  local rowsH=ph-rowsY-footerH
  local rowH=narrow and 50 or short and 53 or 65
  local rows=make("ScrollingFrame","AccountStats",shell,{Position=UDim2.fromOffset(pad,rowsY),Size=UDim2.fromOffset(pw-pad*2,rowsH),
   CanvasSize=UDim2.fromOffset(0,rowH*6),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Cyan,ZIndex=43})
  local iw=pw-pad*2-8
  local labelW=iw*.55;local valueX=labelW+8;local valueW=iw-valueX
  for i,d in ipairs(accountDetailStats())do
   local yy=(i-1)*rowH
   local label=sidebarText(rows,"Label"..i,d[1],0,yy,labelW,rowH-3,narrow and 18 or 24,Color3.fromRGB(218,237,255))
   label.TextWrapped=true
   local value=sidebarText(rows,"Value"..i,d[2],valueX,yy,valueW,rowH-3,narrow and 22 or 30,d[3]);value.TextXAlignment=RIGHT
   if i<6 then local divider=rule(rows,0,yy+rowH-1,iw,Color3.fromRGB(26,105,220),43);divider.Size=UDim2.fromOffset(iw,2)end
  end
  local footer=frame(shell,"AccountActions",pad,ph-footerH,pw-pad*2,footerH-10,C.Panel,43);footer.BackgroundTransparency=1
  local bw=(pw-pad*2-14)/2;local bh=narrow and 51 or short and 50 or 65
  for i,d in ipairs({{"SwitchAccount","Switch account",false,function()s.Overlay="Accounts";refresh()end},
   {"OpenDashboard","All accounts",true,function()navigate("Accounts")end}})do
   local x=(i-1)*(bw+14)
   local depth=frame(footer,d[1].."Depth",x,12,bw,bh,SC.Ink,43);round(depth,16)
   local b=button(footer,d[1],"",x,5,bw,bh,d[4],Color3.new(1,1,1),C.Text,18,44)
   sidebarSurface(b,true,d[3]);b.Corners.CornerRadius=UDim.new(0,15)
   local label=sidebarText(b,"Label",d[2],8,0,bw-(d[3]and 30 or 16),bh,narrow and 17 or 24)
   label.TextXAlignment=CENTER
   if d[3]then
    local ax=bw-19;local ay=bh/2
    for _,points in ipairs({{ax-5,ay,ax+5,ay},{ax+1,ay-5,ax+6,ay},{ax+1,ay+5,ax+6,ay}})do
     local arrow=line(b,"Arrow",points[1],points[2],points[3],points[4],C.Text,3,46);round(arrow,2)
    end
   end
  end
  local note=sidebarText(footer,"Note","SIMULATED · Virtual funds only",0,bh+19,pw-pad*2,21,narrow and 12 or 15,C.Muted);note.TextXAlignment=CENTER
 end
 local function protectionPopup(w,h)
  local draft=s.ProtectionDraft
  if not draft then closeProtection();return end
  local pw=math.min(530,w-28);local ph=math.min(574,h-28);local narrow=pw<390
  local shell=frame(canvas,"ProtectionDialog",(w-pw)/2,(h-ph)/2,pw,ph,Color3.new(1,1,1),41)
  round(shell,20);stroke(shell,C.Cyan).Thickness=4;tint(shell,Color3.fromRGB(43,30,184),Color3.fromRGB(3,43,110));panelStars(shell)
  local headerH=narrow and 90 or 103
  sidebarImage(shell,"Settings",14,17,narrow and 39 or 52)
  sidebarText(shell,"Title","Trade protection",narrow and 61 or 78,18,pw-(narrow and 117 or 140),34,narrow and 24 or 32)
  local sub=text(shell,"Subtitle","Set distances from your entry price",16,headerH-34,pw-32,24,narrow and 12 or 15,C.Text);sub.TextXAlignment=CENTER
  local close=button(shell,"Dismiss","×",pw-51,14,37,37,closeProtection,Color3.new(1,1,1),C.Text,25,43)
  close.TextTransparency=1;tint(close,Color3.fromRGB(255,117,145),Color3.fromRGB(224,26,70));close.Border.Color=C.Red;close.Border.Thickness=2
  local cross=sidebarText(close,"Label","×",0,0,37,37,27);cross.TextXAlignment=CENTER
  local footerH=112
  local fields=make("ScrollingFrame","Fields",shell,{Position=UDim2.fromOffset(12,headerH),Size=UDim2.fromOffset(pw-24,ph-headerH-footerH),
   CanvasSize=UDim2.fromOffset(0,344),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Cyan,ZIndex=42})
  local commits={}
  local cw=pw-36
  for i,d in ipairs({{"Stop","Stop Loss","Stop distance",C.Red},{"Target","Take Profit","Profit target",C.Green}})do
   local key=d[1];local on=draft[key.."On"]
   local card=frame(fields,key.."Protection",5,(i-1)*172+4,cw,158,C.Bg,42);round(card,14);stroke(card,d[4]).Thickness=3
   protectionIcon(card,key,12,13,27)
   sidebarText(card,"Title",d[2],48,7,cw-136,38,narrow and 18 or 24)
   local toggle=gameControl(button(card,"Toggle",on and"ON"or"OFF",cw-78,10,65,32,function()draft[key.."On"]=not draft[key.."On"];refresh()end,C.Raised,C.Text,14,43),on)
   toggle.Border.Color=on and C.Cyan or C.Border
   text(card,"DistanceLabel",d[3],16,49,cw-32,22,13,C.Text,F,CENTER)
   local _,commit=numericStepper(card,"Distance",16,80,cw-32,draft[key.."Ticks"],1,1,10000,function(n)draft[key.."Ticks"]=n end,nil,on)
   table.insert(commits,commit)
   text(card,"Unit","ticks",16,127,cw-32,22,12,C.Muted,F,CENTER)
  end
  local footer=frame(shell,"Actions",14,ph-footerH,pw-28,footerH-6,C.Panel,43);footer.BackgroundTransparency=1
  text(footer,"Scope","Applies to your next order",0,0,pw-28,23,13,C.Text,F,CENTER)
  local bw=(pw-40)/2
  local cancel=gameControl(button(footer,"Cancel","Cancel",0,31,bw,44,closeProtection,C.Panel,C.Text,narrow and 17 or 22,44),false);cancel.Border.Color=C.Cyan
  gameControl(button(footer,"SaveSettings","Save settings",bw+12,31,bw,44,function()
   for _,commit in ipairs(commits)do if not commit()then return end end
   for _,key in ipairs({"StopOn","TargetOn","StopTicks","TargetTicks"})do s[key]=draft[key]end
   s.ProtectionDraft=nil;s.Overlay=nil;s.Error=nil;refresh()
  end,C.Raised,C.Text,narrow and 16 or 22,44),true)
  text(footer,"Note","SIMULATED · Virtual funds only",0,83,pw-28,20,10,C.Muted,F,CENTER)
 end
 local function overlay(w,h)
  if not s.Overlay then return end
  button(canvas,"OverlayBackdrop","",0,0,w,h,function()s.ProtectionDraft=nil;s.Overlay=nil;refresh()end,C.Bg,C.Text,12,40).BackgroundTransparency=.28
  if s.Overlay=="Account"then accountDetails(w,h);return end
  if s.Overlay=="Protection"then protectionPopup(w,h);return end
  local pf=session.Portfolio
  local switchable={}
  for _,list in ipairs({pf and pf.Accounts or{},pf and pf.Legacy or{}})do for _,row in ipairs(list)do if row.State==nil or row.State=="Active"then table.insert(switchable,row)end end end
  local pw=math.min(w-30,s.Overlay=="CopyIntro"and 430 or 390)
  local ph=s.Overlay=="Contracts"and 328 or s.Overlay=="Guide"and 296 or s.Overlay=="Settings"and 340 or s.Overlay=="Menu"and 426
   or s.Overlay=="Timeframes"and 344 or s.Overlay=="Tools"and 440 or s.Overlay=="Accounts"and 166+#switchable*58 or s.Overlay=="CopyIntro"and 402 or 270
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
    button(p,"Choose"..tf,tf,20,62+(i-1)*51,pw-40,45,function()s.Timeframe=tf;s.Overlay=nil;chartView:CancelPlacement();refresh()end,s.Timeframe==tf and C.Panel or false,s.Timeframe==tf and C.Blue or C.Text,15)
   end
  elseif s.Overlay=="Tools"then
   text(p,"Title","Chart tools",20,17,pw-80,29,18,C.Text,B)
   -- Two columns of touch-size buttons; the active tool and magnet are highlighted.
   local colW=(pw-50)/2
   local items={{"Pan","Select & pan"},{"Crosshair","Crosshair"},{"Trend","Trend line"},{"Line","Horizontal line"},{"Rect","Rectangle"},
    {"Magnet",s.Magnet and"Magnet: on"or"Magnet: off"},{"Undo","Undo"},{"Redo","Redo"},{"Delete","Delete selected"},{"Clear","Clear drawings"},
    {"ResetView","Reset view"},{"AutoFit","Auto fit price"},{"GoLive","Go to live"}}
   for i,t in ipairs(items)do
    local col=(i-1)%2;local row=(i-1)//2
    local active=s.Tool==t[1]or t[1]=="Magnet"and s.Magnet
    button(p,"Tool"..t[1],t[2],20+col*(colW+10),62+row*52,colW,44,function()
     s.Overlay=nil
     if t[1]=="Delete"then chartView:DeleteSelected()
     elseif t[1]=="ResetView"then chartView:ResetView()
     elseif t[1]=="AutoFit"then chartView:AutoFit()
     elseif t[1]=="GoLive"then chartView:GoLive()
     else chartView:Command(t[1])end
     refresh()
    end,active and C.Raised or C.Panel,active and C.Blue or C.Text,13)
   end
  elseif s.Overlay=="Menu"then
   text(p,"Title","Get Funded!",20,17,pw-80,29,18,C.Text,B)
   for i,t in ipairs({{"Dashboard","Funded accounts dashboard"},{"Tour","Guided first trade"},{"Guide","First-trade walkthrough"},{"History","Trade review"},{"Settings","Settings & market session"},{"Accounts","Switch account"}})do
    button(p,t[1],t[2],20,62+(i-1)*53,pw-40,46,function()
     if t[1]=="History"then s.Sheet="Activity";s.Tab="History";s.Overlay=nil
     elseif t[1]=="Dashboard"then navigate("Accounts");return
     elseif t[1]=="Tour"then s.Overlay=nil;s.Coach=1;s.CoachBase=nil
     else s.Overlay=t[1];s.Guide=1 end
     refresh()
    end,C.Panel,C.Text,13)
   end
  elseif s.Overlay=="Accounts"then
   text(p,"Title","Switch account",20,17,pw-80,29,18,C.Text,B)
   text(p,"Note","Each account has its own balance, positions and risk limits. Switching never pauses or closes the others.",20,54,pw-40,44,12,C.Muted).TextWrapped=true
   for i,row in ipairs(switchable)do
    local current=pf and pf.Active==row.Key
    local b=button(p,"Account"..row.Key,"",20,108+(i-1)*58,pw-40,50,function()if current then s.Overlay=nil;refresh()else account(row.Key)end end,current and C.Raised or C.Panel,current and C.Blue or C.Text,13)
    text(b,"Name",row.Name..(row.State==nil and"  ·  legacy"or""),14,4,pw-200,24,14,C.Text,M)
    text(b,"Detail",row.Breached and"Breached · restart from the dashboard"or(current and"Trading now"or"Tap to trade"),14,26,pw-200,18,10,row.Breached and C.Red or current and C.Blue or C.Muted)
    text(b,"Balance",Market.Money(row.Balance or 0),pw-200,0,146,50,13,C.Text,N,RIGHT)
   end
   button(p,"ManageAccounts","Manage funded accounts →",20,ph-58,pw-40,42,function()navigate("Accounts")end,false,C.Blue,13)
  elseif s.Overlay=="CopyIntro"then
   icon(p,"Copy",20,20,24,C.Blue)
   text(p,"Eyebrow","NEW · SECOND ACCOUNT ACTIVE",54,18,pw-110,16,10,C.Blue,M)
   text(p,"Title","Copy trading is available",54,34,pw-110,24,18,C.Text,B)
   local body=text(p,"Body","Trade one account and optionally copy its trades to your other funded accounts.",20,72,pw-40,44,14,C.Text);body.TextWrapped=true
   for i,rule_ in ipairs({"Off until you turn it on. You choose the lead and followers.","Each copy uses that account's own funds and risk limits.","Skipped or rejected copies are reported after every order.","Turning it off never closes positions."})do
    icon(p,"Check",22,128+(i-1)*44,14,C.Green)
    local t=text(p,"Rule"..i,rule_,46,120+(i-1)*44,pw-66,32,12,C.Muted);t.TextWrapped=true
   end
   local bw=(pw-50)/2
   button(p,"NotNow","Not now",20,ph-62,bw,46,function()s.Overlay=nil;session:Flag("CopyIntro");refresh()end,C.Raised,C.Text,13)
   button(p,"SetUpCopy","Set up copying",30+bw,ph-62,bw,46,function()session:Flag("CopyIntro");s.Focus="Copy";navigate("Accounts")end,C.Blue,C.Bg,13)
  elseif s.Overlay=="Settings"then
   text(p,"Title","Workspace settings",20,17,pw-80,29,18,C.Text,B)
   button(p,"SelectAccount",accountName().." · switch →",20,70,pw-40,44,function()s.Overlay="Accounts";refresh()end,C.Panel,C.Text,13)
   button(p,"ShowLevels",(s.Levels and"☑ "or"☐ ").."Show entry, stop and target lines",20,127,pw-40,44,function()s.Levels=not s.Levels;refresh()end,C.Panel,C.Text,12)
   text(p,"ExchangeStatus",(session.ConnectionStatus or "SIMULATED PREVIEW").." · "..session.Speed.."x",20,184,pw-40,44,13,C.Blue,N).TextWrapped=true
   text(p,"Details","Server-run simulated order book. Prices and slippage come from executions. Virtual funds only; no fees or real market connection. Regime: "..session.Regime,20,243,pw-40,72,12,C.Muted).TextWrapped=true
  else
   text(p,"Title",s.Overlay=="Info"and"Trading terminology"or"Trading help",20,17,pw-80,29,18,C.Text,B)
   local t=text(p,"Body",s.Overlay=="Info"and s.Info or"Long aims to profit from rising prices. Short aims to profit from falling prices. A tick is the smallest price move. MES uses 0.25-point ticks, worth $1.25 per contract.",20,68,pw-40,ph-135,14,C.Muted);t.TextWrapped=true;t.TextYAlignment=Enum.TextYAlignment.Top
   button(p,"Learn","First-trade walkthrough →",20,ph-57,pw-40,42,function()s.Overlay="Guide";s.Guide=1;refresh()end,C.Panel,C.Blue,13)
  end
 end
 -- ── Funded journey: welcome, dashboard, guided first trade and celebrations ──────────────────
 local AtEnd,Top=Enum.TextTruncate.AtEnd,Enum.TextYAlignment.Top
 local function chip(p,name,value,x,y,color,w)
  local width=w or(#value*6.4+18)
  local c=frame(p,name,x,y,width,18,color:Lerp(C.Panel,.84));round(c,9);stroke(c,color)
  text(c,"Label",value,0,0,width,18,9,color,M,CENTER)
  return c
 end
 local function progressBar(p,name,x,y,w,h,progress,color)
  local track=frame(p,name,x,y,w,h,C.Raised);round(track,math.floor(h/2))
  if progress>0 then local fill=frame(track,"Fill",0,0,math.max(h,w*math.clamp(progress,0,1)),h,color or C.Green);round(fill,math.floor(h/2))end
  return track
 end
 local function goTrade()s.Screen="Trade";s.Nav="Trade";s.Overlay=nil;refresh()end
 local function startFunded()
  if not session.CanTrade then toast(session.ConnectionStatus or"Connecting to the simulated exchange.");return end
  if s.Starting then return end
  local ok,message=session:Start()
  if ok then s.Starting=true;refresh()else toast(message)end
 end
 local function welcome(w,h)
  local starter=Ladder.Tiers[1]
  local cw=math.min(620,w-24);local narrow=cw<440;local pad=narrow and 20 or 36;local iw=cw-pad*2
  local big=narrow and(cw<360 and 22 or 25)or 36;local lineH=big+8
  local bg=make("ScrollingFrame","Welcome",canvas,{Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),BackgroundColor3=C.Bg,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.Muted})
  -- Decorative executed-candle silhouettes in the brand palette.
  for i=0,math.floor(w/46)do
   local bh=26+((i*53)%90)
   local bar=frame(bg,"Motif",i*46+16,h-bh-28-((i*29)%40),12,bh,(i*7)%3~=0 and C.Green or C.Red);bar.BackgroundTransparency=.9;round(bar,2)
  end
  text(bg,"Watermark","GET FUNDED!",0,narrow and 28 or 36,w,narrow and 70 or 140,narrow and 54 or 132,C.Text,B,CENTER).TextTransparency=.975
  local card=frame(bg,"WelcomeCard",(w-cw)/2,12,cw,400,C.Panel);panel(card,C.Blue:Lerp(C.Border,.45))
  local yy=pad-4
  text(card,"Eyebrow","GET FUNDED!  ·  SIMULATED PROP FIRM",pad,yy,iw,18,11,C.Blue,M);yy+=30
  for i,value in ipairs({"Start with "..whole(starter.Size)..".","Prove your skills.","Build your funded portfolio."})do
   text(card,"Headline"..i,value,pad,yy,iw,lineH,big,C.Text,B);yy+=lineH
  end
  yy+=10
  local body=text(card,"Body","Trade a "..whole(starter.Size).." funded account. Bank net realized profit to unlock larger accounts, then copy trades across them to scale.",pad,yy,iw,narrow and 58 or 44,narrow and 13 or 15,C.Muted)
  body.TextWrapped=true;body.TextYAlignment=Top;yy+=narrow and 66 or 56
  local n=#Ladder.Tiers;local gap=narrow and 6 or 10;local chipW=(iw-gap*(n-1))/n
  for i,t in ipairs(Ladder.Tiers)do
   local c=frame(card,"Tier"..t.Id,pad+(i-1)*(chipW+gap),yy,chipW,58,i==1 and C.Raised or C.Bg);round(c,10);stroke(c,i==1 and C.Blue or C.Border)
   text(c,"Size",t.Short,0,8,chipW,24,narrow and 15 or 18,i==1 and C.Text or C.Muted,B,CENTER)
   text(c,"Unlock",i==1 and"START"or("+"..whole(t.Unlock)),0,33,chipW,16,narrow and 9 or 10,i==1 and C.Blue or C.Muted,M,CENTER)
  end
  yy+=68
  text(card,"Journey","Start  →  Trade  →  Earn  →  Unlock  →  Scale",pad,yy,iw,18,narrow and 10 or 11,C.Muted,M,CENTER);yy+=30
  local ready=session.CanTrade
  local start=button(card,"StartFunded",s.Starting and"Opening your account…"or ready and"Start a Funded Account"or"Connecting to the exchange…",pad,yy,iw,56,startFunded,ready and C.Blue or C.Raised,ready and C.Bg or C.Muted,17)
  start.Font=B;if ready then tint(start)end;yy+=68
  local note=text(card,"Simulated","All trading, prices and funds are simulated. No real money is involved and nothing can be withdrawn.",pad,yy,iw,34,11,C.Muted,F,CENTER)
  note.TextWrapped=true;yy+=34+pad-6
  card.Size=UDim2.fromOffset(cw,yy);card.Position=UDim2.fromOffset((w-cw)/2,math.max(12,(h-yy)/2))
  bg.CanvasSize=UDim2.fromOffset(0,math.max(h,yy+24))
 end
 local function loading(w,h)
  local bg=frame(canvas,"Loading",0,0,w,h,C.Bg)
  text(bg,"Wordmark","Get Funded!",0,h/2-58,w,40,28,C.Text,B,CENTER)
  text(bg,"Status","Connecting to your funded portfolio…",0,h/2-10,w,24,14,C.Muted,M,CENTER)
  text(bg,"Exchange",session.ConnectionStatus or"CONNECTING",0,h/2+18,w,20,10,C.Blue,N,CENTER)
 end
 local function tierCard(p,row,x,y,w,h,mobile,pf)
  local active=row.State=="Active";local starting=row.State=="Start";local ready=row.State=="Unlocked"or starting;local current=pf.Active==row.Key
  local accent=row.Breached and C.Red or current and C.Blue or active and C.Green:Lerp(C.Border,.45)or ready and C.Blue or C.Border
  local card=frame(p,"Tier"..row.Key,x,y,w,h,ready and C.Raised or active and C.Panel or C.Bg);round(card,14);stroke(card,accent)
  if active or ready then tint(card)end
  local status=row.Breached and"BREACHED"or active and(current and"TRADING"or"ACTIVE")or starting and"START HERE"or ready and"READY"or"LOCKED"
  local statusColor=row.Breached and C.Red or active and C.Green or ready and C.Blue or C.Muted
  local role=row.Role and(row.Role=="Lead"and"LEAD"or"FOLLOW")
  local earned=pf.Earned or 0
  if mobile then
   text(card,"Size",row.Short,14,10,104,26,20,(active or ready)and C.Text or C.Muted,B)
   chip(card,"Status",status,14,42,statusColor)
   if role then chip(card,"Role",role,14,66,C.Blue)end
   local tight=w<300;local mx=tight and 100 or 118;local mw=w-mx-(tight and 102 or 122)
   if active then
    text(card,"Balance",Market.Money(row.Balance or 0),mx,14,mw,20,13,C.Text,N).TextTruncate=AtEnd
    text(card,"Realized","Realized "..Market.Signed(row.Realized or 0),mx,38,mw,16,10,(row.Realized or 0)>=0 and C.Green or C.Red,N).TextTruncate=AtEnd
    text(card,"Open",row.Breached and"Loss limit reached"or((row.Positions or 0).." open · "..Market.Signed(row.Unrealized or 0)),mx,58,mw,16,10,row.Breached and C.Red or C.Muted,N).TextTruncate=AtEnd
   elseif ready then
    text(card,"Ready",starting and"Your first account"or"Unlocked · ready",mx,22,mw,18,12,C.Blue,M).TextTruncate=AtEnd
    text(card,"Capital",whole(row.Size).." simulated capital",mx,44,mw,16,10,C.Muted).TextTruncate=AtEnd
   else
    local t=text(card,"Requirement","Unlocks at "..whole(row.Unlock).." net profit",mx,14,mw,30,10,C.Muted);t.TextWrapped=true
    progressBar(card,"Progress",mx,50,mw,5,math.clamp(earned/row.Unlock,0,1),C.Blue)
    text(card,"Remaining",whole(math.max(0,row.Unlock-earned)).." to go",mx,60,mw,16,10,C.Muted,N).TextTruncate=AtEnd
   end
  else
   text(card,"Size",row.Short,16,14,w-32,32,28,(active or ready)and C.Text or C.Muted,B)
   text(card,"Kind","Funded account",16,46,w-32,16,11,C.Muted)
   local sw=#status*6.4+18;chip(card,"Status",status,w-sw-14,20,statusColor,sw)
   if role then local rw=#role*6.4+18;chip(card,"Role",role,w-rw-14,44,C.Blue,rw)end
   if active then
    text(card,"BalanceLabel","Balance",16,72,w-32,14,10,C.Muted)
    text(card,"Balance",Market.Money(row.Balance or 0),16,86,w-32,22,w<200 and 14 or 16,C.Text,N).TextTruncate=AtEnd
    text(card,"RealizedLabel","Realized profit",16,112,w-32,14,10,C.Muted)
    text(card,"Realized",Market.Signed(row.Realized or 0),16,126,w-32,22,w<200 and 14 or 15,(row.Realized or 0)>=0 and C.Green or C.Red,N).TextTruncate=AtEnd
    local t=text(card,"Open",row.Breached and"Loss limit reached. Restart with fresh capital; the loss still counts."or((row.Positions or 0).." open · "..Market.Signed(row.Unrealized or 0).." open P&L"),16,row.Breached and 144 or 152,w-32,row.Breached and 26 or 16,10,row.Breached and C.Red or C.Muted,N)
    t.TextWrapped=row.Breached==true
   elseif ready then
    icon(card,"Check",16,80,18,C.Blue)
    text(card,"Ready",starting and"Your first account"or"Unlocked",42,76,w-58,26,15,C.Blue,M)
    local t=text(card,"Detail",starting and("Opens with "..whole(row.Size).." of simulated funded capital. Trade it to earn realized profit and unlock the next account.")
     or("Earned with "..whole(row.Unlock).." net realized profit. Activating adds "..whole(row.Size).." of simulated funded capital."),16,106,w-32,62,11,C.Muted)
    t.TextWrapped=true;t.TextYAlignment=Top
   else
    icon(card,"Lock",16,80,18,C.Muted)
    local t=text(card,"Requirement","Unlocks at "..whole(row.Unlock).." net realized profit",42,72,w-58,36,11,C.Muted);t.TextWrapped=true
    progressBar(card,"Progress",16,122,w-32,6,math.clamp(earned/row.Unlock,0,1),C.Blue)
    text(card,"Remaining",whole(math.max(0,row.Unlock-earned)).." to go",16,134,w-32,16,10,C.Muted,N)
   end
  end
  local function action(label,fn,primary,muted)
   local bw=mobile and(w<300 and 88 or 106)or w-28;local bx=mobile and w-bw-12 or 14;local by=mobile and(h-40)/2 or h-54
   local b=button(card,"Action",label,bx,by,bw,40,fn,primary and C.Blue or muted and C.Bg or C.Raised,primary and C.Bg or muted and C.Muted or C.Blue,12)
   if primary then b.Font=B;tint(b)end
   return b
  end
  if active and row.Breached then action("Restart",function()local ok,message=session:Restart(row.Key);if not ok then toast(message)end end)
  elseif active and current then action("Trading now  →",goTrade)
  elseif active then action("Trade "..row.Short,function()account(row.Key)end)
  elseif starting then action("Start "..row.Short,startFunded,true)
  elseif ready then action("Activate "..row.Short,function()local ok,message=session:Activate(row.Key);if not ok then toast(message)end end,true)
  else local b=action("Locked",function()end,false,true);b.Active=false;if mobile then b.Visible=false end end
 end
 local function copyCard(p,y,w,mobile,pf)
  local copy=pf.Copy or{Followers={}}
  local card=frame(p,"CopyTrading",0,y,w,100,C.Panel);round(card,14);stroke(card,copy.Enabled and C.Blue or C.Border);tint(card)
  local pad=mobile and 14 or 20;local iw=w-pad*2;local yy=pad-2
  icon(card,"Copy",pad,yy+2,20,C.Blue)
  text(card,"Title","Copy trading",pad+30,yy,iw-110,24,17,C.Text,B)
  chip(card,"State",copy.Enabled and"ON"or"OFF",w-pad-46,yy+3,copy.Enabled and C.Green or C.Muted,46)
  yy+=32
  local intro=text(card,"Intro","Trade one account and optionally copy its trades to your other funded accounts.",pad,yy,iw,mobile and 34 or 20,12,C.Text)
  intro.TextWrapped=true;yy+=mobile and 40 or 28
  if not pf.CopyAvailable then
   local t=text(card,"Unavailable","Available after you activate a second funded account. Copying stays off until you turn it on.",pad,yy,iw,34,11,C.Muted)
   t.TextWrapped=true;yy+=40
   card.Size=UDim2.fromOffset(w,yy+pad-6);return yy+pad-6
  end
  local actives={}for _,row in ipairs(pf.Accounts)do if row.State=="Active"then table.insert(actives,row)end end
  local draft=s.CopyDraft
  if not draft then
   local lead=copy.Leader;local valid=false
   for _,row in ipairs(actives)do if row.Key==lead then valid=true end end
   if not valid then lead=nil;for _,row in ipairs(actives)do if row.Key==pf.Active then lead=row.Key end end;lead=lead or actives[1].Key end
   local followers={}
   if copy.Leader==lead and #copy.Followers>0 then for _,key in ipairs(copy.Followers)do followers[key]=true end
   else for _,row in ipairs(actives)do if row.Key~=lead then followers[row.Key]=true end end end
   draft={Leader=lead,Followers=followers,Sizing=copy.Sizing or"Same"}
  end
  local function edit()s.CopyDraft=draft;refresh()end
  local bw=math.min(124,(iw-8*(#actives-1))/#actives)
  text(card,"LeadLabel","LEAD ACCOUNT · you trade this one",pad,yy,iw,16,10,C.Muted,M);yy+=20
  for i,row in ipairs(actives)do
   local selected=draft.Leader==row.Key
   button(card,"Lead"..row.Key,row.Short,pad+(i-1)*(bw+8),yy,bw,36,function()draft.Leader=row.Key;draft.Followers[row.Key]=nil;edit()end,selected and C.Raised or C.Bg,selected and C.Blue or C.Muted,12)
  end
  yy+=46
  text(card,"FollowLabel","FOLLOWERS · receive copies of new lead orders",pad,yy,iw,16,10,C.Muted,M);yy+=20
  local index=0
  for _,row in ipairs(actives)do
   if row.Key~=draft.Leader then
    local on=draft.Followers[row.Key]==true
    button(card,"Follow"..row.Key,(on and"☑ "or"☐ ")..row.Short,pad+index*(bw+8),yy,bw,36,function()draft.Followers[row.Key]=(not on)or nil;edit()end,on and C.Raised or C.Bg,on and C.Blue or C.Muted,12)
    index+=1
   end
  end
  yy+=46
  text(card,"SizingLabel","COPY SIZE",pad,yy,iw,16,10,C.Muted,M);yy+=20
  local sw=mobile and iw or math.min(iw,460)
  local seg=frame(card,"Sizing",pad,yy,sw,40,C.Bg);round(seg,8)
  for i,opt in ipairs({{"Same","Same quantity"},{"Proportional","Scale by account size"}})do
   local on=draft.Sizing==opt[1]
   button(seg,opt[1],opt[2],3+(i-1)*(sw-6)/2,3,(sw-6)/2,34,function()draft.Sizing=opt[1];edit()end,on and C.Raised or false,on and C.Blue or C.Muted,12)
  end
  yy+=52
  local rules=text(card,"Rules","Copies use each account's own funds and risk limits, so some can be skipped or rejected; every order shows a copy report. Turning copying off never closes positions: each account keeps what it holds and trades on its own.",pad,yy,iw,mobile and 70 or 34,11,C.Muted)
  rules.TextWrapped=true;rules.TextYAlignment=Top;yy+=mobile and 76 or 42
  local followers={}for _,row in ipairs(actives)do if draft.Followers[row.Key]and row.Key~=draft.Leader then table.insert(followers,row.Key)end end
  local function apply(enabled)local ok,message=session:Copy(enabled,draft.Leader,followers,draft.Sizing);if not ok then toast(message)end end
  local bw2=mobile and(iw-8)/2 or 200
  if copy.Enabled then
   button(card,"UpdateCopy","Save changes",pad,yy,bw2,44,function()apply(true)end,C.Raised,C.Blue,13)
   button(card,"DisableCopy","Turn off copying",pad+bw2+8,yy,bw2,44,function()apply(false)end,C.Raised,C.Text,13)
  else
   local can=#followers>0
   local b=button(card,"EnableCopy",can and"Turn on copying"or"Choose a follower",pad,yy,mobile and iw or 240,44,function()if can then apply(true)else toast("Choose at least one follower account.")end end,can and C.Blue or C.Raised,can and C.Bg or C.Muted,13)
   if can then b.Font=B;tint(b)end
  end
  yy+=54
  local last=s.LastCopy
  if last then
   text(card,"LastCopy",string.format("Last copy · %s lead · %d copied · %d skipped · %d rejected",last.Leader,last.Copied,last.Skipped,last.Rejected),pad,yy,iw,16,10,last.Rejected>0 and C.Red or C.Muted,N).TextTruncate=AtEnd
   yy+=24
  end
  card.Size=UDim2.fromOffset(w,yy+pad-10)
  return yy+pad-10
 end
 local function dashboard(x,y,w,h,mobile)
  local pf=session.Portfolio or{Accounts={},Legacy={},Earned=0,Capital=0,Open=0,ActiveCount=0,Copy={Enabled=false,Followers={}}}
  local sc=make("ScrollingFrame","Dashboard",canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,
   ScrollBarThickness=4,ScrollBarImageColor3=C.Muted,ScrollingDirection=Enum.ScrollingDirection.Y})
  local cw=w-(mobile and 6 or 14);local gap=mobile and 10 or 14;local yy
  local narrow=mobile and w<600 -- phone portrait stacks; landscape uses the wide header and KPI row
  local primary=pf.Active and"Continue Trading  →"or"Start a Funded Account"
  local function continueTrading()if pf.Active then goTrade()else startFunded()end end
  if narrow then
   text(sc,"Title","Funded accounts",0,0,cw,30,22,C.Text,B)
   text(sc,"Subtitle","Trade · earn realized profit · unlock more capital",0,30,cw,18,11,C.Muted)
   local b=button(sc,"ContinueTrading",primary,0,56,cw,52,continueTrading,C.Blue,C.Bg,16);b.Font=B;tint(b)
   text(sc,"Resume",pf.Active and("Resume "..(pf.ActiveName or""))or"Your practice accounts are kept below.",0,112,cw,16,10,C.Muted,M,CENTER)
   yy=140
  else
   text(sc,"Title","Funded accounts",0,0,cw-290,36,28,C.Text,B)
   text(sc,"Subtitle","Start → Trade → Earn → Unlock → Scale  ·  simulated capital, virtual funds",0,38,cw-290,20,12,C.Muted).TextTruncate=AtEnd
   local b=button(sc,"ContinueTrading",primary,cw-260,0,260,56,continueTrading,C.Blue,C.Bg,16);b.Font=B;tint(b)
   text(sc,"Resume",pf.Active and("Resume "..(pf.ActiveName or""))or"Starts with "..whole(Ladder.Tiers[1].Size).." of simulated capital",cw-260,60,260,16,10,C.Muted,M,CENTER)
   yy=90
  end
  local copy=pf.Copy or{Followers={}}
  local copyCaption=copy.Enabled and(tierShort(copy.Leader).." leads · "..#copy.Followers.." following")or(pf.CopyAvailable and"Off · ready when you are"or"Needs a 2nd funded account")
  local count=pf.ActiveCount or 0
  local kpis={
   {"Capital","Active funded capital",whole(pf.Capital or 0),"Provided capital · "..count.." account"..(count==1 and""or"s"),C.Text,C.Border},
   {"Earned","Net realized profit",Market.Signed(pf.Earned or 0),"Yours · closed trades · counts toward unlocks",(pf.Earned or 0)>=0 and C.Green or C.Red,C.Green:Lerp(C.Border,.5)},
   {"Open","Open P&L",Market.Signed(pf.Open or 0),"Not counted until you close",(pf.Open or 0)>=0 and C.Green or C.Red,C.Border},
   {"Copy","Copy trading",copy.Enabled and"On"or"Off",copyCaption,copy.Enabled and C.Blue or C.Muted,copy.Enabled and C.Blue or C.Border},
  }
  local cols=narrow and 2 or 4;local kw=(cw-gap*(cols-1))/cols;local kh=mobile and 78 or 96
  for i,k in ipairs(kpis)do
   local col,r=(i-1)%cols,math.floor((i-1)/cols)
   local tile=frame(sc,"Kpi"..k[1],col*(kw+gap),yy+r*(kh+gap),kw,kh,C.Panel);round(tile,12);stroke(tile,k[6]);tint(tile)
   text(tile,"Label",k[2],14,mobile and 8 or 12,kw-28,16,mobile and 10 or 11,C.Muted).TextTruncate=AtEnd
   text(tile,"Value",k[3],14,mobile and 26 or 32,kw-28,mobile and 24 or 30,mobile and 17 or 24,k[5],N).TextTruncate=AtEnd
   local caption=text(tile,"Caption",k[4],14,mobile and 52 or 66,kw-28,mobile and 20 or 18,mobile and 9 or 10,C.Muted);caption.TextWrapped=mobile;caption.TextTruncate=AtEnd
  end
  yy+=math.ceil(#kpis/cols)*(kh+gap)
  local cardH=mobile and(pf.Started and 118 or 160)or 110
  local prog=frame(sc,"NextUnlock",0,yy,cw,cardH,C.Panel);round(prog,14);stroke(prog,C.Blue:Lerp(C.Border,.5));tint(prog)
  local amountW=mobile and 130 or 220
  if not pf.Started then
   text(prog,"Eyebrow","YOUR FUNDED JOURNEY",20,14,cw-40,16,11,C.Blue,M)
   text(prog,"Title","Start with a "..whole(Ladder.Tiers[1].Size).." funded account",20,32,mobile and cw-40 or cw-300,28,mobile and 16 or 21,C.Text,B).TextTruncate=AtEnd
   progressBar(prog,"Progress",20,70,mobile and cw-40 or cw-300,8,0,C.Green)
   text(prog,"Remaining","Your earlier practice accounts are kept below. They don't count toward unlocks.",20,84,mobile and cw-40 or cw-300,mobile and 28 or 18,mobile and 10 or 11,C.Muted).TextWrapped=true
   local start=button(prog,"StartFunded","Start a Funded Account",mobile and 20 or cw-260,mobile and 112 or 34,mobile and cw-40 or 240,42,startFunded,C.Blue,C.Bg,13)
   start.Font=B;tint(start)
  elseif pf.Next then
   text(prog,"Eyebrow","NEXT UNLOCK",20,14,cw-40,16,11,C.Blue,M)
   text(prog,"Title",pf.Next.Name.." account",20,32,cw-40-amountW,28,mobile and 16 or 21,C.Text,B).TextTruncate=AtEnd
   text(prog,"Amount",net(pf.Earned or 0).." / "..whole(pf.Next.Unlock),cw-20-amountW,32,amountW,28,mobile and 13 or 16,C.Text,N,RIGHT)
   progressBar(prog,"Progress",20,70,cw-40,8,math.clamp((pf.Earned or 0)/pf.Next.Unlock,0,1),C.Green)
   text(prog,"Remaining",whole(pf.Next.Remaining).." more net realized profit to go. Starting balances and open P&L don't count.",20,84,cw-40,mobile and 28 or 18,mobile and 10 or 11,C.Muted).TextWrapped=true
  else
   text(prog,"Eyebrow","LADDER COMPLETE",20,14,cw-40,16,11,C.Green,M)
   text(prog,"Title","Every funded account is unlocked",20,32,cw-40,28,mobile and 16 or 21,C.Text,B).TextTruncate=AtEnd
   progressBar(prog,"Progress",20,70,cw-40,8,1,C.Green)
   text(prog,"Remaining","Net realized profit "..Market.Signed(pf.Earned or 0)..". Scale with copy trading across your accounts.",20,84,cw-40,mobile and 28 or 18,mobile and 10 or 11,C.Muted).TextWrapped=true
  end
  yy+=cardH+gap+8
  text(sc,"LadderTitle","Account ladder",0,yy,cw,24,mobile and 16 or 18,C.Text,B)
  if not mobile then text(sc,"LadderNote","Unlocked by lifetime net realized profit across your funded accounts",0,yy,cw,24,11,C.Muted,F,RIGHT)end
  yy+=32
  local rows=pf.Accounts or{}
  local cols2=mobile and 1 or math.clamp(math.floor((cw+12)/188),1,math.max(1,#rows))
  local cardW=(cw-12*(cols2-1))/cols2;local tierH=mobile and 100 or 226
  for i,row in ipairs(rows)do
   tierCard(sc,row,((i-1)%cols2)*(cardW+12),yy+math.floor((i-1)/cols2)*(tierH+12),cardW,tierH,mobile,pf)
  end
  yy+=math.ceil(#rows/cols2)*(tierH+12)+8
  local copyY=yy
  if pf.Started then yy+=copyCard(sc,yy,cw,mobile,pf)+gap+8 end
  if #(pf.Legacy or{})>0 then
   text(sc,"LegacyTitle","Legacy practice accounts",0,yy,cw,24,mobile and 15 or 16,C.Text,B);yy+=26
   local note=text(sc,"LegacyNote","Kept exactly as they were before funded accounts. Still tradable, but never counted toward unlocks or funded capital.",0,yy,cw,mobile and 30 or 18,11,C.Muted)
   note.TextWrapped=true;yy+=mobile and 36 or 26
   for _,row in ipairs(pf.Legacy)do
    local current=pf.Active==row.Key
    local card=frame(sc,"Legacy"..row.Key,0,yy,cw,66,C.Panel);round(card,12);stroke(card,current and C.Blue or C.Border)
    text(card,"Name",row.Name..(row.Breached and"  ·  breached"or""),16,8,cw-190,24,15,row.Breached and C.Red or C.Text,M).TextTruncate=AtEnd
    text(card,"Detail",Market.Money(row.Balance or 0).." · realized "..Market.Signed(row.Realized or 0).." · "..(row.Positions or 0).." open",16,34,cw-190,20,11,C.Muted,N).TextTruncate=AtEnd
    button(card,"Action",current and"Trading now  →"or"Trade",cw-156,13,140,40,function()if current then goTrade()else account(row.Key)end end,C.Raised,C.Blue,12)
    yy+=76
   end
  end
  text(sc,"Footnote","Simulated prop-firm journey · all capital, prices and profits are virtual",0,yy,cw,20,10,C.Muted,F,CENTER);yy+=28
  sc.CanvasSize=UDim2.fromOffset(0,yy)
  if s.Focus=="Copy"then s.Focus=nil;task.defer(function()if sc.Parent then sc.CanvasPosition=Vector2.new(0,math.max(0,copyY-12))end end)end
 end
 local coachSteps={
  {"Pick an instrument","Open the contract list and choose a market. MES, the Micro S&P 500, is a good first pick.",
   {Desktop={"OrderTicket.Fields.ContractSelector"},Mobile={"Chart.Header.ContractSelector"}}},
  {"Set your size","Use − and + to choose how many contracts. Start with 1: your %s account has a %s loss limit.",
   {Desktop={"OrderTicket.Fields.Quantity"},Mobile={"TradeDock.Quantity"}}},
  {"Place a trade","BUY if you expect the price to rise, SELL if you expect it to fall. Your stop loss and take profit attach automatically.",
   {Desktop={"OrderTicket.OrderActions.BuyLong","OrderTicket.OrderActions.SellShort","OrderTicket.Fields.BuyLong","OrderTicket.Fields.SellShort"},Mobile={"TradeDock.BuyLong","TradeDock.SellShort"}}},
  {"Close your position","When you're ready, close it. Closing turns open P&L into realized profit or loss, and only realized profit counts toward unlocks.",
   {Desktop={"OrderTicket.OrderActions.ClosePosition","OrderTicket.Fields.ClosePosition"},Mobile={"Activity.Rows.Row1","MobileNavigation.NavPositions"}}},
  {"First profit milestone","",{Desktop={},Mobile={}}},
 }
 local function findPath(path)
  local node=canvas
  for part in path:gmatch("[^%.]+")do node=node and node:FindFirstChild(part)end
  return node
 end
 local function highlight(target)
  local ring=make("Frame","CoachHighlight",target,{Size=UDim2.new(1,6,1,6),Position=UDim2.fromOffset(-3,-3),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=target.ZIndex+3})
  round(ring,10);local edge=stroke(ring,C.Blue);edge.Thickness=2
  TweenService:Create(edge,TweenInfo.new(.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.65}):Play()
 end
 local function finishCoach(skipped)
  s.Coach=nil;s.CoachBase=nil;s.CoachDismissed=true
  session:Flag(skipped and"TutorialSkipped"or"TutorialDone");refresh()
 end
 local function coachProgress()
  if not s.Coach then return false end
  local fill,hist=session.Fills[1],session.History[1]
  local base=s.CoachBase
  if not base or base.Account~=session.AccountKey then
   s.CoachBase={Account=session.AccountKey,Fill=fill and fill.TradeId,History=hist and hist.TradeId};return false
  end
  local before=s.Coach
  if s.Coach<=3 and fill and fill.TradeId~=base.Fill then s.Coach=4;base.Fill=fill.TradeId end
  if s.Coach==4 and hist and hist.TradeId~=base.History then s.Coach=5 end
  return s.Coach~=before
 end
 local function coach(w,h,mobile,layout)
  if not s.Coach or options.Preview then return end
  local pf=session.Portfolio;if not pf or pf.New then return end
  local step=coachSteps[s.Coach];local title,body=step[1],step[2]
  if s.Coach==2 then local row=activeRow();body=string.format(body,accountShort(),whole(row and row.LossLimit or Ladder.Tiers[1].LossLimit))end
  if s.Coach==5 then
   local nextText=pf.Next and("Next objective: earn "..whole(pf.Next.Unlock).." net realized profit to unlock "..pf.Next.Name..".")or""
   local last=session.History[1]
   if pf.FirstProfit then title="First profit banked";body="Milestone reached: "..Market.Signed(pf.FirstProfit).." realized. "..nextText
   elseif last then body="That trade closed at "..Market.Signed(last.Pnl)..". This milestone completes on your first profitable close. "..nextText
   else body="Close a trade in profit to complete this milestone. "..nextText end
  end
  local hasButton=s.Coach<=2 or s.Coach==5
  local x,y,cw,ch
  if mobile then
   -- Top of the screen, except step 1 whose target (the chart's contract selector) sits there.
   x=12;cw=layout.CoachW or w-24;ch=s.Coach==5 and 142 or 116
   y=s.Coach==1 and h-ch-(layout.Compact and 10 or layout.NavH+8)or layout.Head
  else
   -- Compact and bottom-aligned so the activity tabs, table header and first row stay readable.
   local a=layout.Activity;cw=math.min(640,a[3]*.56)
   local textH=TextService:GetTextSize(body,12,F,Vector2.new(cw-(hasButton and 138 or 28),1000)).Y
   ch=math.clamp(60+textH,86,math.max(86,a[4]-8));x=a[1]+12;y=a[2]+a[4]-ch-8
  end
  local card=frame(canvas,"Coach",x,y,cw,ch,C.Raised,38);round(card,12);stroke(card,C.Blue);tint(card)
  text(card,"Step","GUIDED FIRST TRADE · "..s.Coach.." OF "..#coachSteps,14,8,cw-120,16,10,C.Blue,M)
  button(card,"SkipTour",s.Coach==5 and"Close"or"Skip tour",cw-96,4,86,26,function()finishCoach(s.Coach~=5)end,false,C.Muted,11)
  text(card,"Title",title,14,26,cw-28,24,mobile and 15 or 17,C.Text,B).TextTruncate=AtEnd
  local t=text(card,"Body",body,14,51,cw-(hasButton and 138 or 28),ch-58,mobile and 11 or 12,C.Muted);t.TextWrapped=true;t.TextYAlignment=Top
  if s.Coach<=2 then button(card,"CoachNext","Next  →",cw-100,ch-42,88,34,function()s.Coach+=1;refresh()end,C.Blue,C.Bg,12)end
  if s.Coach==5 then local b=button(card,"FinishTour","Keep trading",cw-126,ch-44,114,36,function()finishCoach(false)end,C.Blue,C.Bg,12);b.Font=B end
  local targets=step[3][mobile and"Mobile"or"Desktop"]
  if s.Coach==4 and mobile then
   local key;for _,k in ipairs(Market.ContractOrder)do if session.Positions[k]then key=k break end end
   local close=key and findPath("Activity.Rows.Row1.Close"..key)
   targets=close and{"Activity.Rows.Row1.Close"..key}or{"MobileNavigation.NavPositions"}
  end
  for _,path in ipairs(targets)do local target=findPath(path);if target then highlight(target)end end
 end
 local celebrationQueue,celebrating={},false
 local function showNextCelebration()
  if celebrating or #celebrationQueue==0 or not alive or not root.Parent then return end
  local event=table.remove(celebrationQueue,1);celebrating=true
  local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y;local mobile=w<1000 or h<600
  local unlocked=event.Kind=="Unlocked"
  local cw=math.min(460,w-24);local ch=unlocked and 166 or 124;local ty=mobile and 66 or 24
  local old=root:FindFirstChild("Celebration");if old then old:Destroy()end
  local card=make("CanvasGroup","Celebration",root,{Size=UDim2.fromOffset(cw,ch),Position=UDim2.fromOffset((w-cw)/2,ty-28),BackgroundColor3=C.Raised,
   BorderSizePixel=0,GroupTransparency=1,ZIndex=80})
  round(card,14);local edge=stroke(card,C.Green);edge.Thickness=1.5
  local badge=frame(card,"Badge",16,18,48,48,C.Green:Lerp(C.Panel,.74),81);round(badge,24);stroke(badge,C.Green)
  icon(badge,unlocked and"Trophy"or"Check",12,12,24,C.Green)
  text(card,"Eyebrow",unlocked and"ACCOUNT UNLOCKED"or"FIRST PROFIT",78,16,cw-124,16,10,C.Green,M,nil,81)
  text(card,"Title",unlocked and(event.Name.." is ready")or(Market.Signed(event.Pnl or 0).." realized"),78,33,cw-110,28,20,C.Text,B,nil,81).TextTruncate=AtEnd
  local message=unlocked and("You reached the "..whole(event.Unlock).." net realized profit milestone. Activating adds "..whole(event.Size).." of simulated funded capital, separate from the profit you earned.")
   or"Your first trade closed in profit. Realized profit is what unlocks larger funded accounts."
  local body=text(card,"Body",message,78,62,cw-94,unlocked and 54 or 48,12,C.Muted,F,nil,81);body.TextWrapped=true;body.TextYAlignment=Top
  local done=false
  local function dismiss()
   if done then return end;done=true
   if not card.Parent then celebrating=false;return end
   local out=TweenService:Create(card,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{GroupTransparency=1,Position=card.Position-UDim2.fromOffset(0,18)})
   out.Completed:Connect(function()card:Destroy();celebrating=false;task.delay(.25,showNextCelebration)end);out:Play()
  end
  button(card,"Dismiss","×",cw-40,8,32,32,dismiss,false,C.Muted,20,82)
  if unlocked then
   local activate=button(card,"ActivateNow","Activate "..event.Short,78,ch-46,156,34,function()
    local ok,reason=session:Activate(event.Tier);if not ok then toast(reason)end;dismiss()
   end,C.Blue,C.Bg,12,82);activate.Font=B
   button(card,"Later","Later",242,ch-46,80,34,dismiss,C.Raised,C.Text,12,82)
  end
  for i=1,14 do
   local angle=i/14*math.pi*2
   local spark=frame(card,"Spark",38,36,4,10,i%2==0 and C.Green or C.Blue,83);spark.Rotation=math.deg(angle)+90;round(spark,2)
   TweenService:Create(spark,TweenInfo.new(.95,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
    {Position=UDim2.fromOffset(38+math.cos(angle)*48,36+math.sin(angle)*48),BackgroundTransparency=1,Rotation=math.deg(angle)+180}):Play()
  end
  TweenService:Create(card,TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{GroupTransparency=0,Position=UDim2.fromOffset((w-cw)/2,ty)}):Play()
  task.delay(unlocked and 12 or 8,dismiss)
 end
 local function celebrate(event)table.insert(celebrationQueue,event);showNextCelebration()end
 local reportId=0
 local function showCopyReport(report)
  s.LastCopy=report;reportId+=1;local id=reportId
  local old=root:FindFirstChild("CopyReport");if old then old:Destroy()end
  if not report.Items or #report.Items==0 then return end
  local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y;local mobile=w<1000 or h<600
  local cw=math.min(500,w-24);local ch=46+#report.Items*26
  local card=make("CanvasGroup","CopyReport",root,{Size=UDim2.fromOffset(cw,ch),Position=UDim2.fromOffset((w-cw)/2,(mobile and 62 or 30)+58),
   BackgroundColor3=C.Raised,BorderSizePixel=0,GroupTransparency=1,ZIndex=70})
  round(card,12);stroke(card,report.Rejected>0 and C.Red or C.Blue)
  text(card,"Header","COPY REPORT · "..report.Leader.." LEAD",14,8,cw-190,18,10,C.Blue,M,nil,71)
  text(card,"Summary",string.format("%d copied · %d skipped · %d rejected",report.Copied,report.Skipped,report.Rejected),cw-190,8,176,18,10,report.Rejected>0 and C.Red or C.Muted,N,RIGHT,71)
  for i,item in ipairs(report.Items)do
   local yy=34+(i-1)*26;local color=item.Status=="Copied"and C.Green or item.Status=="Rejected"and C.Red or C.Muted
   text(card,"Account"..i,item.Name,14,yy,56,22,12,C.Text,B,nil,71)
   text(card,"Status"..i,item.Status,70,yy,72,22,11,color,M,nil,71)
   text(card,"Message"..i,item.Message or"",144,yy,cw-156,22,11,C.Muted,F,nil,71).TextTruncate=AtEnd
  end
  TweenService:Create(card,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=0}):Play()
  task.delay(report.Rejected>0 and 9 or 6,function()
   if id~=reportId or not card.Parent then return end
   local out=TweenService:Create(card,TweenInfo.new(.25),{GroupTransparency=1});out.Completed:Connect(function()card:Destroy()end);out:Play()
  end)
 end
 local function mobileBadge()
  if options.Preview then return "Preview · Simulated market · Virtual funds"end
  if not session.CanTrade then return session.Ready and "SIMULATED / PAUSED"or "SIMULATED / CONNECTING"end
  local _,_,_,_,summary=objective()
  return session.PersistenceMode=="Local"and("Local / not saved · "..summary)or summary
 end
 local function mobileScreen(w,h,sum,screen)
  local compact=w>h;local dense=h<650 and not compact
  local head=dense and 48 or 60;local navH=dense and 52 or 58;local dockH=dense and 152 or 190
  local board=screen=="Dashboard"
  local layout={Head=head,NavH=navH,Compact=compact}
  local top=frame(canvas,"TopNavigation",0,0,w,head,C.Bg)
  local acc=button(top,"Account","",12,0,w-70,58,function()s.Overlay="Account";refresh()end,false)
  -- Trading header: active account (tap to switch) and the next objective with a slim progress line.
  text(acc,"Name",board and"Get Funded!"or(accountName().."  ⌄"),0,dense and 0 or 3,w-70,dense and 26 or 30,dense and 20 or 22,C.Text,B).TextTruncate=AtEnd
  text(acc,"Brand",board and"Funded accounts · simulated capital"or mobileBadge(),0,dense and 27 or 34,w-70,dense and 17 or 20,9,C.Muted).TextTruncate=AtEnd
  if not board then local _,_,progress=objective();progressBar(top,"ObjectiveBar",12,head-4,w-24,3,progress,C.Green)end
  button(top,"More","···",w-54,2,44,48,function()s.Overlay="Menu";refresh()end,false,C.Blue,22)
  if board then
   dashboard(12,head+6,w-24,h-head-navH-12,true)
  elseif compact then
   local dw=math.min(300,w*.39);local cx=w-dw-24;layout.CoachW=cx
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
  local navigation=frame(canvas,"MobileNavigation",nx,h-navH,nw,navH,SB.Navy,25);rule(navigation,0,0,nw,SB.Cyan)
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
    fields.CanvasSize=UDim2.fromOffset(0,orderOptions(fields,sw,12,true))
   end
  end
  return layout
 end
 -- Welcome for first-time players, dashboard for returning players, trading workspace on demand.
 local function currentScreen()
  if options.Preview then return "Trade"end
  local pf=session.Portfolio
  if not pf then return "Loading"end
  if pf.New then s.Screen=nil;return "Welcome"end
  if not pf.Active then s.Screen="Dashboard"end
  s.Screen=s.Screen or"Dashboard"
  return s.Screen
 end
 render=function()
  if not alive or not root.Parent then return end
  if chartView:Busy()then fullRefreshPending=true;return end
  local size=root.AbsoluteSize;local w=size.X>0 and size.X or 1440;local h=size.Y>0 and size.Y or 900;lastW=w;lastH=h
  local scroll={}
  for _,v in ipairs(canvas:GetDescendants())do if v:IsA("ScrollingFrame")then scroll[v:GetFullName()]=v.CanvasPosition end end
  canvas:ClearAllChildren();canvas.Size=UDim2.fromOffset(w,h)
  chartView:Reset()
  if session.Contract~=s.Contract or session.Timeframe~=s.Timeframe then session:Subscribe(s.Contract,s.Timeframe)end
  task.defer(function()if alive then for _,v in ipairs(canvas:GetDescendants())do if v:IsA("ScrollingFrame") and scroll[v:GetFullName()]then v.CanvasPosition=scroll[v:GetFullName()]end end end end)
  local mobile=w<1000 or h<600;local sum=session:Summary()
  local screen=currentScreen();local layout
  if screen=="Trade"then
   local pf=session.Portfolio
   if pf and pf.Tutorial=="Pending"and s.Coach==nil and not s.CoachDismissed and not options.Preview then s.Coach=1;s.CoachBase=nil end
   s.Nav=s.Nav=="Accounts"and"Trade"or s.Nav
  else s.Nav="Accounts"end
  if screen=="Welcome"then welcome(w,h)
  elseif screen=="Loading"then loading(w,h)
  elseif mobile then layout=mobileScreen(w,h,sum,screen)
  else
   local railW=w<1150 and 180 or w<1550 and 220 or 256;local gap=16;local statusH=28
   local cx=railW+gap;local usable=w-cx-20;local tw=w<1150 and 264 or w<1550 and 310 or 360;local cw=usable-tw-gap
   local rw,rh=railW-14,h-28
   local rail=frame(canvas,"Sidebar",10,14,rw,rh,Color3.new(1,1,1),1)
   round(rail,18);stroke(rail,Color3.fromRGB(0,140,255)).Thickness=4
   tint(rail,Color3.fromRGB(5,49,134),Color3.fromRGB(2,25,75))
   local pattern=frame(rail,"Pattern",5,5,rw-10,rh-10,SB.Navy,1);pattern.BackgroundTransparency=1;pattern.ClipsDescendants=true;round(pattern,15)
   for i,pos in ipairs({{.78,.1},{.66,.67},{.2,.77},{.82,.87}})do
    local diamond=frame(pattern,"Diamond"..i,pos[1]*(rw-42),pos[2]*(rh-42),30,30,Color3.fromRGB(0,100,255),1)
    diamond.Rotation=45;diamond.BackgroundTransparency=.84;round(diamond,5)
   end
   local wordmark=sidebarText(rail,"Wordmark",'Get <font color="#FFD336">Funded!</font>',12,18,rw-24,38,rw<185 and 25 or 31)
   wordmark.RichText=true
   sidebarText(rail,"Simulation","Simulated market",18,62,rw-36,20,14,SB.Muted)
   sidebarText(rail,"Funds","Virtual funds",18,83,rw-36,18,14,SB.Muted)
   local navH=h>=800 and 56 or 44
   nav(rail,12,118,rw-24,navH,false)
   local marketY=118+5*(navH+9)+10
   local marketH=h>=900 and 42 or 34
   if marketY+29+4*(marketH+8)<rh-124 and screen=="Trade"then
    sidebarText(rail,"Markets","YOUR MARKETS",14,marketY,rw-28,22,14,SB.Muted)
    for i,key in ipairs(Market.ContractOrder)do
     local selected=key==s.Contract
     local b=button(rail,"Market"..key,"",12,marketY+29+(i-1)*(marketH+8),rw-24,marketH,function()selectContract(key)end,Color3.new(1,1,1),C.Text,12,3)
     sidebarSurface(b,selected,true)
     sidebarText(b,"Symbol",key,16,0,rw-82,marketH,21)
     if selected then
      local dot=frame(b,"Dot",rw-54,(marketH-12)/2,12,12,Color3.fromRGB(93,255,83),5);round(dot,6);stroke(dot,SC.Ink).Thickness=3
     end
    end
   end
   local switcher=button(rail,"AccountSwitcher","",12,rh-112,rw-24,44,function()s.Overlay="Account";refresh()end,Color3.new(1,1,1),C.Text,12,3)
   sidebarSurface(switcher,true,true);sidebarImage(switcher,"Accounts",7,5,34)
   sidebarText(switcher,"Label",accountName(),44,0,rw-99,44,rw<185 and 14 or 19)
   local arrow=frame(switcher,"Dropdown",rw-47,17,12,9,SB.Navy,5);arrow.BackgroundTransparency=1
   local downA=line(arrow,"Left",0,0,6,6,C.Text,3,5);round(downA,2)
   local downB=line(arrow,"Right",6,6,12,0,C.Text,3,5);round(downB,2)
   local settings=button(rail,"Settings","",12,rh-57,rw-76,42,function()s.Overlay="Settings";refresh()end,false,C.Text,12,3)
   sidebarImage(settings,"Settings",0,3,36)
   sidebarText(settings,"Label","Settings",40,0,rw-116,42,18)
   local help=button(rail,"Help","",rw-56,rh-58,44,44,function()s.Overlay="Help";refresh()end,Color3.new(1,1,1),C.Text,12,3)
   sidebarSurface(help,true,false);sidebarImage(help,"Help",5,4,34)
   if screen=="Dashboard"then
    dashboard(cx,22,usable,h-statusH-34,false)
   else
    local summaryH=math.clamp(usable*.135,166,h>=800 and 226 or 176)
    accountCards(cx,22,usable,summaryH,false)
    local contentY=22+summaryH+16
    local ay=h-statusH-math.clamp(h*.2,152,206)-12
    chart(cx,contentY,cw,ay-contentY-16,false,false,false)
    ticket(cx+cw+gap,contentY,tw,h-statusH-contentY-12)
    activity(cx,ay,cw,h-statusH-ay-12,false,false)
    layout={Activity={cx,ay,cw,h-statusH-ay-12}}
   end
   local status=frame(canvas,"StatusBar",cx,h-statusH,usable,statusH,C.Bg)
   text(status,"Status",options.Preview and "EDIT PREVIEW · Press Play · Virtual funds"or"SIMULATED · "..session.Regime.." · Virtual funds",0,0,usable-286,statusH,9,C.Muted,N).TextTruncate=Enum.TextTruncate.AtEnd
   text(status,"ExchangeStatus",options.Preview and "SNAPSHOT · SIMULATED"or(session.ConnectionStatus or "CONNECTING"),usable-280,0,280,statusH,9,C.Blue,N,RIGHT).TextTruncate=Enum.TextTruncate.AtEnd
  end
  if screen=="Trade"and layout then coach(w,h,mobile,layout)end
  overlay(w,h)
  if s.Toast then
   local tw=math.min(480,w-24);local ty=mobile and 62 or 30
   local p=frame(canvas,"Toast",(w-tw)/2,ty,tw,49,C.Raised,60);round(p,10);stroke(p,s.Error and C.Red or C.Green)
   text(p,"Message",s.Toast,12,3,tw-24,43,12,C.Text,M,CENTER).TextWrapped=true
  end
  root:SetAttribute("Layout",mobile and"Mobile"or"Desktop");root:SetAttribute("SelectedContract",s.Contract)
  local pf=session.Portfolio
  root:SetAttribute("Screen",screen);root:SetAttribute("CoachStep",s.Coach);root:SetAttribute("ActiveAccount",pf and pf.Active)
  root:SetAttribute("NetRealized",pf and pf.Earned);root:SetAttribute("CopyEnabled",pf and pf.Copy and pf.Copy.Enabled or false)
  root:SetAttribute("Theme","Colorful Game")
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
   if ev.UserInputType==Enum.UserInputType.Keyboard then
    -- Chart keys (Esc, Delete/Backspace, Ctrl+Z/Y, Ctrl for magnet) are ignored while typing.
    if chartView:KeyBegan(ev)then return end
    if not processed and ev.KeyCode==Enum.KeyCode.Escape then s.ProtectionDraft=nil;s.Overlay=nil;s.Sheet=false;refresh()end
   end
  end))
  table.insert(connections,UIS.InputEnded:Connect(function(ev)
   if ev.UserInputType==Enum.UserInputType.Keyboard then chartView:KeyEnded(ev)else chartView:Ended(ev)end
  end))
  table.insert(connections,UIS.InputChanged:Connect(function(ev)chartView:Changed(ev)end))
  table.insert(connections,UIS.WindowFocusReleased:Connect(function()chartView:FocusLost()end))
  -- Esc opens the Roblox menu in-game (games never receive it); treat that as cancel too.
  table.insert(connections,game:GetService("GuiService").MenuOpened:Connect(function()chartView:FocusLost()end))
  local paintElapsed=0
  table.insert(connections,RunService.RenderStepped:Connect(function(dt)
   paintElapsed+=dt
   chartView:Step(dt)
   -- Input, easing and network batches share one paint per display frame.
   if chartView.Dirty then repaintChart()end
   if RunService:IsStudio()and paintElapsed>=1 then
    paintElapsed=0;root:SetAttribute("ChartPaintCount",chartView.PaintCount)
    root:SetAttribute("ChartPaintMeanMs",chartView.PaintTotal/math.max(1,chartView.PaintCount));root:SetAttribute("ChartPaintMaxMs",chartView.PaintMax)
    root:SetAttribute("ChartPaintLastMs",chartView.LastCost)
   end
  end))
  local lastStructure=""
  local function portfolioSignature()
   local pf=session.Portfolio;if not pf then return"none"end
   local parts={tostring(pf.New),tostring(pf.Revision),tostring(pf.Active),string.format("%.2f",pf.Earned or 0),tostring(pf.ActiveCount)}
   for _,list in ipairs({pf.Accounts or{},pf.Legacy or{}})do
    for _,r in ipairs(list)do table.insert(parts,r.Key..(r.State or"L")..tostring(r.Breached)..string.format("%.2f",r.Balance or 0)..":"..tostring(r.Positions)..":"..tostring(r.Orders))end
   end
   return table.concat(parts,"|")
  end
  local function marketUpdate()
   if not alive then return end
   local cancelled=chartView:OnMarketUpdate()
   if cancelled then toast(cancelled)end
   if coachProgress()then refresh()end
   local screen=currentScreen()
   local signature=screen..":"..tostring(session.AccountKey)..":"..tostring(session.CanTrade)..":"..#session.Orders..":"..#session.History..":"..portfolioSignature()
   for _,key in ipairs(Market.ContractOrder)do
    local p=session.Positions[key]
    if p then signature..=key..p.Quantity..":"..p.Entry..":"..tostring(p.Stop)..":"..tostring(p.Target)end
   end
   for _,o in ipairs(session.Orders)do signature..=":"..o.Id..":"..o.Quantity end
   if signature~=lastStructure and not UIS:GetFocusedTextBox()then lastStructure=signature;refresh();return end
   -- Preserve controls, focus, scroll positions and overlays between network batches.
   local sum=session:Summary();local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y;local mobile=w<1000 or h<600
   local board=canvas:FindFirstChild("Dashboard")
   if board and session.Portfolio then
    -- Open P&L moves every batch; update it in place so dashboard buttons are never rebuilt mid-click.
    local pf=session.Portfolio;local kpi=board:FindFirstChild("KpiOpen")
    if kpi then kpi.Value.Text=Market.Signed(pf.Open or 0);kpi.Value.TextColor3=(pf.Open or 0)>=0 and C.Green or C.Red end
    for _,row in ipairs(pf.Accounts or{})do
     local card=board:FindFirstChild("Tier"..row.Key);local open=card and card:FindFirstChild("Open")
     if open and row.State=="Active"and not row.Breached then open.Text=(row.Positions or 0).." open · "..Market.Signed(row.Unrealized or 0)..(mobile and""or" open P&L")end
    end
   end
   chartView.Dirty=true
   local metrics=canvas:FindFirstChild("AccountSummary")
   if metrics then
    local pnlIcon=metrics:FindFirstChild("UnrealizedCard")
    pnlIcon=pnlIcon and pnlIcon:FindFirstChild("IconPanel")
    if pnlIcon then
     pnlIcon.Rotation=sum.Unrealized<0 and 180 or 0
     pnlIcon.ImageColor3=sum.Unrealized<0 and Color3.fromRGB(255,176,189)or Color3.new(1,1,1)
    end
    for _,field in ipairs({"Balance","Equity","Unrealized","Session","Allowance"})do
     local label=metrics:FindFirstChild(field.."Value")
     if label then label.Text=(field=="Unrealized"or field=="Session")and Market.Signed(sum[field])or Market.Money(sum[field]);if field=="Unrealized"or field=="Session"then label.TextColor3=sum[field]>=0 and SC.Green or SC.Red end end
    end
   end
   updateAccountDetails()
   for _,panelName in ipairs({"OrderTicket","OptionsSheet"})do
    local panel=canvas:FindFirstChild(panelName);local label=panel and panel:FindFirstChild("CurrentPrice",true)
    if label then label.Text="Current "..Market.Number(session.Prices[s.Contract])end
   end
   local top=canvas:FindFirstChild("TopNavigation")
   if mobile and top and top:FindFirstChild("Account")and screen=="Trade"then top.Account.Brand.Text=mobileBadge()end
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
   chartView:OnReply(reply)
   s.Error=not reply.Ok and reply.Message or nil
   if reply.Ok and reply.Result and(reply.Result.Filled or 0)>0 then s.Tab="Positions"end
   local pf=session.Portfolio
   if reply.Kind=="Start"then
    s.Starting=nil
    if reply.Ok then s.Screen="Trade";s.Nav="Trade";s.CoachDismissed=nil;if pf and pf.Tutorial=="Pending"then s.Coach=1;s.CoachBase=nil end end
   elseif reply.Kind=="Account"and reply.Ok then s.Screen="Trade";s.Nav="Trade"
   elseif reply.Kind=="Activate"and reply.Ok then
    -- Copy trading is introduced once the player has a second active funded account. It stays off.
    if pf and(pf.ActiveCount or 0)>=2 and not pf.CopyIntro then s.Overlay="CopyIntro"end
   elseif reply.Kind=="Copy"and reply.Ok then s.CopyDraft=nil
   end
   if reply.Copies then showCopyReport(reply.Copies)end
   if reply.Kind~="Flag"or not reply.Ok then toast(reply.Message)else refresh()end
  end))
  table.insert(connections,session.Events.Event:Connect(function(event)celebrate(event);refresh()end))
 end
 render()
 local controller={Root=root,State=s,Chart=chartView}
 function controller:Destroy()alive=false;chartView:Destroy();session:Destroy();for _,c in ipairs(connections)do c:Disconnect()end;if root.Parent then root:Destroy()end end
 return controller
end
return UI
