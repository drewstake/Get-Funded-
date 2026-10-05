-- Native Roblox GUI. All panels and chart marks are editable GuiObjects.
local Market = require(script.Parent.MarketClient)
local ChartView = require(script.Parent.ChartView)
local Feedback = require(script.Parent.UIFeedback)
local LeaderboardClient = require(script.Parent.LeaderboardClient)
local LeaderboardView = require(script.Parent.LeaderboardView)
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local UI = {}
local painting -- Chart painting is synchronous; input handlers live on a separate, stable surface.
local fx -- Interaction feedback (tweens and sounds) for the mounted workspace; nil in Edit previews.
local C = {
 -- Colorful game terminal. Opaque plotting surfaces preserve hollow candle readability.
 Bg=Color3.fromRGB(2,17,49), Panel=Color3.fromRGB(5,39,111), Raised=Color3.fromRGB(50,40,147),
 Chart=Color3.fromRGB(3,25,65), Border=Color3.fromRGB(27,92,196), Grid=Color3.fromRGB(20,62,119),
 Text=Color3.fromRGB(245,249,255), Muted=Color3.fromRGB(159,210,248), Blue=Color3.fromRGB(190,132,255),
 Green=Color3.fromRGB(46,249,160), Red=Color3.fromRGB(255,81,127), Buy=Color3.fromRGB(0,211,135), Sell=Color3.fromRGB(249,58,116),
 Cyan=Color3.fromRGB(0,220,255),
}
-- All interface copy uses the same rounded family. Chart axes use a compact numeric font.
local F,M,B,N=Enum.Font.FredokaOne,Enum.Font.FredokaOne,Enum.Font.FredokaOne,Enum.Font.FredokaOne
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
  TextColor3=color or C.Text,TextSize=size or 13,Font=font or F,
  TextStrokeColor3=Color3.fromRGB(1,15,49),TextStrokeTransparency=(font==Enum.Font.RobotoMono or name=="Watermark"or(color and math.max(color.R,color.G,color.B)<.35))and 1 or .55,
  TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=z or p.ZIndex})
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
-- Tabs, segments, toggles and pickers use the softer selection sound.
local SELECT_NAMES={Market=true,Limit=true,Toggle=true,Same=true,Proportional=true,ShowLevels=true,SoundToggle=true}
local function selectable(name)
 return SELECT_NAMES[name]or name:match("^Tab")or name:match("^Nav")or name:match("^Market%u")or name:match("^Time")
  or name:match("^Choose")or name:match("^Lead")or name:match("^Follow")or name:match("^Tool")or name:match("^Level")
end
local function button(p,name,value,x,y,w,h,fn,color,fg,size,z)
 local b=make("TextButton",name,p,{Text=clean(value),Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.Raised,
  BackgroundTransparency=color==false and 1 or 0,BorderSizePixel=0,TextColor3=fg or C.Text,TextSize=size or 13,Font=M,
  TextStrokeColor3=Color3.fromRGB(1,15,49),TextStrokeTransparency=.55,AutoButtonColor=false,ZIndex=z or p.ZIndex})
 if color~=false then round(b);stroke(b,fg==C.Blue and C.Blue or C.Border)end
 -- One guarded activation path: repeat clicks are debounced, disabled controls ignored, and each
 -- control plays its sound (attribute "Sound": Click, Tick, Select, Open, None).
 b.Activated:Connect(function(...)
  local f=fx
  if f then
   if b.Active==false or f:Guard(b,b:GetAttribute("Debounce"))then return end
   local sound=b:GetAttribute("Sound")
   if sound~="None"then f:Play(sound or(selectable(name)and"Select"or"Click"))end
  end
  fn(...)
 end)
 if fx and name~="OverlayBackdrop"and name~="SheetBackdrop"then
  local area=w*h
  fx:Bind(b,area>18000 and{Lift=1.015,Press=.975}or area>6000 and{Lift=1.025,Press=.955}or{Lift=1.05,Press=.92})
 end
 return b
end
-- Glossy game controls. Every variant: vertical gradient, bright rim, shine strip and outlined label.
local GLOSS={
 Purple={Color3.fromRGB(152,80,255),Color3.fromRGB(80,28,214),Color3.fromRGB(196,140,255)},
 Navy={Color3.fromRGB(15,48,117),Color3.fromRGB(3,24,66),Color3.fromRGB(27,92,196)},
 Cyan={Color3.fromRGB(0,192,255),Color3.fromRGB(0,94,228),Color3.fromRGB(80,232,255)},
 Green={Color3.fromRGB(34,253,158),Color3.fromRGB(0,173,112),Color3.fromRGB(129,255,202)},
 Pink={Color3.fromRGB(255,120,168),Color3.fromRGB(231,40,99),Color3.fromRGB(255,168,197)},
 Red={Color3.fromRGB(255,109,136),Color3.fromRGB(222,30,72),Color3.fromRGB(255,158,175)},
 Gold={Color3.fromRGB(255,222,40),Color3.fromRGB(255,158,0),Color3.fromRGB(255,244,120)},
}
local GLOSS_INK={Purple=Color3.fromRGB(40,10,120),Navy=Color3.fromRGB(1,15,49),Cyan=Color3.fromRGB(0,48,130),Green=Color3.fromRGB(0,112,72),
 Pink=Color3.fromRGB(160,20,70),Red=Color3.fromRGB(140,14,44),Gold=Color3.fromRGB(150,70,0)}
local function glossy(b,variant)
 variant=GLOSS[variant]and variant or"Navy"
 local g=GLOSS[variant]
 local gradient=b:FindFirstChild("ControlLight")
 if not gradient then
  b.BackgroundColor3=Color3.new(1,1,1);b.BackgroundTransparency=0;b:SetAttribute("RestingColor",Color3.new(1,1,1));b.Font=Enum.Font.FredokaOne
  gradient=make("UIGradient","ControlLight",b,{Rotation=90})
  local edge=b:FindFirstChild("Border")or stroke(b);edge.Thickness=2
  if not b:FindFirstChild("Corners")then round(b,9)end
  -- A gradient on a TextButton also tints its own text. A child label stays white.
  b.TextTransparency=1;b.TextStrokeTransparency=1
  local label=text(b,"ControlLabel",b.Text,4,0,b.Size.X.Offset-8,b.Size.Y.Offset,b.TextSize,C.Text,Enum.Font.FredokaOne,Enum.TextXAlignment.Center,b.ZIndex+2)
  label.TextStrokeTransparency=1
  label.TextScaled=true;make("UITextSizeConstraint","TextSize",label,{MinTextSize=8,MaxTextSize=math.max(8,b.TextSize)})
  make("UIStroke","TextOutline",label,{Color=GLOSS_INK[variant],Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 end
 if b:GetAttribute("Gloss")~=variant then
  gradient.Color=ColorSequence.new(g[1],g[2]);b.Border.Color=g[3];b:SetAttribute("Gloss",variant)
  local label=b:FindFirstChild("ControlLabel");local outline=label and label:FindFirstChild("TextOutline")
  if outline then outline.Color=GLOSS_INK[variant]end
  local shine=b:FindFirstChild("Shine")
  if variant~="Navy"and not shine and b.Size.X.Offset>=30 and b.Size.Y.Offset>=24 then
   shine=make("Frame","Shine",b,{Position=UDim2.fromOffset(8,3),Size=UDim2.fromOffset(b.Size.X.Offset-16,3),BackgroundColor3=Color3.new(1,1,1),
    BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=b.ZIndex+1});round(shine,2)
  elseif variant=="Navy"and shine then shine:Destroy()end
 end
 return b
end
-- Glossy selection controls share the interface typography.
local function gameControl(b,selected)
 glossy(b,selected and"Purple"or"Navy")
 if b:GetAttribute("ControlSelected")~=selected then
  b.Border.Color=selected and C.Blue or C.Border;b:SetAttribute("ControlSelected",selected)
  if fx then fx:Selected(b,selected)end
 end
 return b
end
local function gameHeading(label)
 label.Font=Enum.Font.FredokaOne;label.TextStrokeTransparency=1
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
-- Red glossy close button with a drawn cross (the reference popups' X).
local function dismissButton(p,x,y,size,fn,z)
 local d=button(p,"Dismiss","",x,y,size,size,fn,Color3.new(1,1,1),C.Text,20,z or p.ZIndex+2)
 d.Corners.CornerRadius=UDim.new(0,math.floor(size*.26));d.Border.Color=Color3.fromRGB(255,158,175);d.Border.Thickness=3
 tint(d,Color3.fromRGB(255,109,136),Color3.fromRGB(227,33,77))
 local pad=size*.3
 for _,pts in ipairs({{pad,pad,size-pad,size-pad},{pad,size-pad,size-pad,pad}})do
  local shadow=line(d,"CrossShadow",pts[1],pts[2]+1,pts[3],pts[4]+1,Color3.fromRGB(174,21,52),math.max(5,size*.16),d.ZIndex+1);round(shadow,4)
  local cross=line(d,"Cross",pts[1],pts[2],pts[3],pts[4],C.Text,math.max(3,size*.1),d.ZIndex+2);round(cross,3)
 end
 return d
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
 label.TextStrokeTransparency=1
 label.TextScaled=true
 make("UITextSizeConstraint","TypeSize",label,{MinTextSize=compact and 8 or 10,MaxTextSize=size})
 make("UIStroke","TextOutline",label,{Color=SC.Ink,Thickness=compact and 1.5 or math.clamp(size*.09,2,4),ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual,LineJoinMode=Enum.LineJoinMode.Round})
 return label
end
local SB={Navy=Color3.fromRGB(3,27,78),Blue=Color3.fromRGB(6,49,130),Cyan=Color3.fromRGB(0,189,255),Muted=Color3.fromRGB(144,208,255)}
local sidebarImages={
 Leaderboard="rbxassetid://80175474742009",
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
 if fx then fx:Destroy()end
 fx=not options.Preview and Feedback.new(root,{})or nil
 local feedback=fx
 local s={Contract="ES",Timeframe="1m",Type="Market",Qty=1,Limit=5820,Stop=5802.5,Target=5842.5,StopOn=true,TargetOn=true,
  Tab="Positions",Nav="Trade",Sheet=false,ProtectionDraft=nil,StopTicks=40,TargetTicks=120,Overlay=nil,Guide=1,Tool="Pan",Drawings={},Levels=true,
  Screen=nil,Coach=nil,CopyDraft=nil,LastCopy=nil,SoundOn=true,SoundLevel="Medium",PendingOrder=nil,PendingClose=nil}
 local Ladder=Market.Progression
 local session=Market.New(nil,options.Preview,options.PreviewData)
 local leaderboard=LeaderboardClient.new(options.Preview,options.LeaderboardData)
 if options.LeaderboardData then s.Screen="Leaderboard";s.Nav="Leaderboard" end
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
 -- kind: "error" (red, error sound), "success" (green) or "info" (cyan). Sounds for success come
 -- from server replies, never from the toast itself.
 local function toast(message,kind)
  if not message or message==""then return end
  toastId+=1;local id=toastId;s.Toast=message;s.ToastKind=kind or(s.Error and"error"or"info");refresh()
  task.delay(s.ToastKind=="error"and 5 or 4,function()if alive and id==toastId then s.Toast=nil;refresh()end end)
 end
 local function fail(message)
  s.Error=message;if fx then fx:Play("Error")end;toast(message,"error")
 end
 local shownToast
 local function toastView(w,h,mobile)
  local kind=s.ToastKind or"info"
  local accent=kind=="error"and Color3.fromRGB(255,110,140)or kind=="success"and Color3.fromRGB(60,255,160)or C.Cyan
  local tw=math.min(500,w-24);local ty=mobile and 62 or 30
  local lines=TextService:GetTextSize(s.Toast,14,Enum.Font.FredokaOne,Vector2.new(tw-78,1000)).Y
  local th=math.clamp(lines+26,52,96)
  local p=frame(canvas,"Toast",(w-tw)/2,ty,tw,th,Color3.new(1,1,1),60);round(p,16)
  local edge=stroke(p,accent);edge.Thickness=3
  tint(p,kind=="error"and Color3.fromRGB(92,20,74)or kind=="success"and Color3.fromRGB(4,88,84)or Color3.fromRGB(8,62,160),Color3.fromRGB(3,24,72))
  local badge=frame(p,"Badge",12,(th-32)/2,32,32,accent,61);round(badge,16);stroke(badge,SC.Ink).Thickness=2
  if kind=="error"then
   local bar=frame(badge,"Mark",14,6,4,13,SC.Ink,62);round(bar,2);local dot=frame(badge,"Dot",14,22,4,4,SC.Ink,62);round(dot,2)
  elseif kind=="success"then
   line(badge,"Tick",8,17,14,23,SC.Ink,4,62);line(badge,"Tick",13,23,24,10,SC.Ink,4,62)
  else
   local dot=frame(badge,"Dot",14,7,4,4,SC.Ink,62);round(dot,2);local bar=frame(badge,"Mark",14,13,4,12,SC.Ink,62);round(bar,2)
  end
  local label=summaryText(p,"Message",s.Toast,54,4,tw-68,th-8,14,C.Text,true)
  label.TextWrapped=true;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextScaled=false;label.TextSize=14;label.ZIndex=61
  if fx and shownToast~=toastId then
   shownToast=toastId
   local target=p.Position;p.Position=target-UDim2.fromOffset(0,16)
   fx:Tween(p,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Position=target})
  end
 end
 -- Effects queued by replies run after the rebuild they trigger, on the rebuilt controls.
 local queuedEffects={}
 local function locate(path)
  local node=canvas
  for part in path:gmatch("[^%.]+")do node=node and node:FindFirstChild(part)end
  return node
 end
 local function runEffects()
  if not fx or #queuedEffects==0 then return end
  local list=queuedEffects;queuedEffects={}
  for _,e in ipairs(list)do
   local target;for _,path in ipairs(e.Paths)do target=target or locate(path)end
   if target then
    if e.Kind=="Success"then fx:Pulse(target);fx:Ring(target,e.Color or C.Green,14)
    elseif e.Kind=="Error"then fx:Shake(target)
    elseif e.Kind=="Pulse"then fx:Pulse(target)end
   end
  end
 end
 local function effect(paths,kind,color)
  if not fx then return end
  table.insert(queuedEffects,{Paths=paths,Kind=kind,Color=color})
  task.delay(.08,runEffects) -- in case no rebuild follows
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
    if not pf.Next then return "LADDER COMPLETE","Top-tier milestone earned",1,"Net "..net(pf.Earned),"Ladder complete · net "..net(pf.Earned)end
  local progress=math.clamp((pf.Next.Progress or 0)/pf.Next.Goal,0,1)
  local amount=whole(pf.Next.Progress).." / "..whole(pf.Next.Goal)
  return (pf.Next.Milestone and "TOP-TIER GOAL" or "NEXT UNLOCK · "..pf.Next.Short),"Earn "..whole(pf.Next.Remaining).." more",progress,amount,"Next "..pf.Next.Short.." · "..amount
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
 local tradePaths={"OrderTicket.OrderActions.BuyLong","OrderTicket.Fields.BuyLong","TradeDock.BuyLong"}
 local sellPaths={"OrderTicket.OrderActions.SellShort","OrderTicket.Fields.SellShort","TradeDock.SellShort"}
 -- One order in flight at a time: BUY/SELL show "Sending" until the server replies (or 6 s pass).
 -- Success feedback only comes from that server reply.
 local function place(dir)
  if s.PendingOrder then return end
  local paths=dir>0 and tradePaths or sellPaths
  if s.Qty<1 or s.Qty>20 or s.Qty%1~=0 then fail("Enter a whole quantity from 1 to 20.");effect(paths,"Error");return end
  if (s.StopOn and(s.StopTicks<1 or s.StopTicks%1~=0))or(s.TargetOn and(s.TargetTicks<1 or s.TargetTicks%1~=0))then
   fail("Protection distances must be positive whole ticks.");effect(paths,"Error");return
  end
  local ok,msg,tab,requestId=session:Place(s.Contract,dir,s.Qty,s.Type,s.Limit,s.StopOn and s.StopTicks or nil,s.TargetOn and s.TargetTicks or nil)
  if ok then
   s.Error=nil;s.Tab=tab;s.Sheet=false
   local pending={Id=requestId,Direction=dir,At=os.clock()};s.PendingOrder=pending
   if fx then fx:Play("Send")end
   toast("Sending "..(dir>0 and"buy"or"sell").." order to the simulated exchange…","info")
   task.delay(6,function()
    if alive and s.PendingOrder==pending then s.PendingOrder=nil;fail("No confirmation from the exchange yet. Check Orders before retrying.")end
   end)
  else fail(msg);effect(paths,"Error")end
 end
 local function account(key)
  local ok,message=session:Account(key);s.Overlay=nil;s.Error=nil
  if not ok then fail(message)else refresh()end
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
   Text=tostring(value),PlaceholderText="Price",TextColor3=enabled==false and C.Muted or C.Text,TextSize=15,Font=N,TextStrokeColor3=SC.Ink,TextStrokeTransparency=.55,ClearTextOnFocus=false,
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
  if value=="Leaderboard"then s.Nav=value;s.Screen=value;refresh();return end
  if value=="Accounts"then s.Nav=value;s.Screen="Dashboard";refresh();return end
  if s.Screen=="Dashboard"or s.Screen=="Leaderboard"then
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
  local items=mobile and {"Trade","Accounts","Leaderboard","Positions","Learn"}or{"Trade","Accounts","Leaderboard","Positions","Review","Learn"}
  for i,value in ipairs(items)do
   local cell=mobile and w/#items or w
   local bx=mobile and x+(i-1)*cell+3 or x
   local by=mobile and y+2 or y+(i-1)*(h+9)
   local bw=mobile and cell-6 or w
   local bh=mobile and h-4 or h
   local selected=s.Nav==value
   local b=button(p,"Nav"..value,"",bx,by,bw,bh,function()navigate(value,mobile)end,Color3.new(1,1,1),C.Text,12,p.ZIndex+2)
   sidebarSurface(b,selected,false);if fx then fx:Selected(b,selected)end
   local iconSize=mobile and math.min(28,bh-22)or math.min(42,bh-8)
   sidebarImage(b,value,mobile and(bw-iconSize)/2 or 11,mobile and 3 or(bh-iconSize)/2,iconSize)
   local label=sidebarText(b,"Label",value,mobile and 2 or iconSize+20,mobile and bh-20 or 0,mobile and bw-4 or bw-iconSize-28,mobile and 18 or bh,mobile and 10 or value=="Leaderboard"and 17 or 21)
   label.TextScaled=true;make("UITextSizeConstraint","NavTextSize",label,{MinTextSize=8,MaxTextSize=mobile and 10 or value=="Leaderboard"and 17 or 21})
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
   label=pf.Next.Milestone and "TOP-TIER GOAL" or "NEXT UNLOCK";title=pf.Next.Name or(pf.Next.Short.." Funded")
   progress=math.clamp((pf.Next.Progress or 0)/pf.Next.Goal,0,1);amount=whole(pf.Next.Progress).." / "..whole(pf.Next.Goal)
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
 chartView=ChartView.new({C=C,F=F,M=M,B=B,N=Enum.Font.RobotoMono,Market=Market,Session=session,State=s,Options=options,Root=root,Canvas=canvas,
  frame=frame,text=text,button=button,stroke=stroke,round=round,line=line,dash=dash,rule=rule,panel=panel,
  control=gameControl,gloss=glossy,heading=gameHeading,caption=sidebarText,tint=tint,stars=panelStars,
  setPainting=function(pool)painting=pool end,refresh=refresh,toast=toast,
  onIdle=function(chrome)
   if fullRefreshPending or chrome then fullRefreshPending=false;refresh()else repaintChart()end
  end})
 -- A paint error must never leave the pooled painter installed (every later GUI object would be
 -- routed into the chart pool) or stop later frames. Errors are reported once and the chart recovers.
 local chartFault,faultAt=nil,0
 local function chart(x,y,w,h,mobile,compact,short,updating)
  local ok,err=xpcall(chartView.Paint,debug.traceback,chartView,x,y,w,h,mobile,compact,updating)
  if ok then
   if chartFault then chartFault=nil;root:SetAttribute("ChartError",nil)end
   return
  end
  painting=nil;chartView:Reset()
  local message=tostring(err)
  if message~=chartFault or os.clock()-faultAt>10 then warn("[Get Funded!] Chart paint failed; recovering: "..message)end
  chartFault=message;faultAt=os.clock();root:SetAttribute("ChartError",message:sub(1,200))
  -- Rebuild the chart panel on the next frame (at most once a second while the fault repeats).
  task.delay(updating and 1 or 0,function()if alive then fullRefreshPending=false;refresh()end end)
 end
 repaintChart=function()
  -- The chart keeps updating behind popups; its input surface is blocked while one is open.
  if not alive or not root.Parent then return end
  local p=canvas:FindFirstChild("Chart");if not p then return end
  local w,h=root.AbsoluteSize.X,root.AbsoluteSize.Y
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
  if s.Tab=="Positions"or compact then for _,key in ipairs(Market.PositionOrder)do if session.Positions[key]then table.insert(data,session.Positions[key])end end
  elseif s.Tab=="Orders"then data=working else data=session.History end
  if #data==0 then
   local showIcon=not compact and h-top>=108
   local iconSize=showIcon and math.clamp(h-top-69,34,55)or 0
   local titleY=showIcon and top+iconSize+12 or top+10
   -- While the guided-tour card covers the left of the panel, centre the empty state on the right.
   local ex,ew=12,w-24
   if s.Coach and not mobile and not compact then ex=math.floor(w*.58);ew=w-ex-12 end
   if showIcon then sidebarImage(p,s.Tab=="History"and"Review"or"Positions",ex+(ew-iconSize)/2,top+8,iconSize)end
   gameHeading(text(p,"EmptyTitle",s.Tab=="Positions"and"No open positions"or s.Tab=="Orders"and"No working orders"or"No completed trades yet",ex,titleY,ew,24,showIcon and 18 or 13,C.Text,B,CENTER))
   if not compact then text(p,"EmptyDetail",s.Tab=="Positions"and"Choose a contract and place a simulated order."or s.Tab=="Orders"and"Limit and protective orders appear here."or"Close a position to review your result.",ex,titleY+26,ew,23,mobile and 10 or 12,C.Muted,F,CENTER).TextWrapped=true end
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
     glossy(button(row,"Close"..d.Contract,"CLOSE",w-67,3,59,40,function()close(d.Contract)end,C.Raised,C.Text,12),"Pink"):SetAttribute("Sound","Open")
    elseif s.Tab=="Orders"then
     text(row,"Description",d.Contract.." · "..d.Kind,14,7,w-108,24,13,C.Text,M)
     text(row,"Price",Market.Number(d.Price).." · "..d.Quantity.." contracts",14,35,w-112,27,12,C.Muted,N)
     glossy(button(row,"Cancel"..d.Id..(d.Protection or""),"Cancel",w-96,18,82,44,function()local ok,message=session:Cancel(d.Id,d.Protection);if ok then toast("Cancelling order…","info")else fail(message)end end,C.Raised,C.Text,13),"Navy").Border.Color=C.Cyan
    else
     text(row,"Description",d.Contract.." · "..d.Quantity.." contracts",14,9,w-124,24,13,C.Text,M)
     text(row,"Pnl",Market.Signed(d.Pnl),w-119,9,105,24,14,d.Pnl>=0 and C.Green or C.Red,N,RIGHT)
     text(row,"Details",Market.Number(d.Entry).." → "..Market.Number(d.Exit).." · "..d.Time,14,37,w-28,25,11,C.Muted,N)
    end
    rule(row,8,rowH-1,w-16)
   end
  else
   local cols=s.Tab=="Positions"and{"Instrument","Side","Qty","Entry","Result","Action"}or s.Tab=="Orders"and{"Instrument","Order","Qty","Price","Status","Action"}or{"Instrument","Qty","Entry","Exit","Result","Closed"}
   local heading=frame(p,"TableHeader",8,top+2,w-16,28,Color3.new(1,1,1));round(heading,8)
   tint(heading,Color3.fromRGB(96,48,230),Color3.fromRGB(58,26,170));stroke(heading,Color3.fromRGB(150,100,255))
   local fractions={0,.17,.34,.44,.62,.85}
   for i,title in ipairs(cols)do text(p,"Column"..i,title,14+fractions[i]*(w-28),top+3,(w-28)*(i==5 and .23 or .17)-7,25,11,Color3.fromRGB(236,226,255),Enum.Font.FredokaOne)end
   local list=scroller("Rows",top+30,h-top-30,#data*39)
   for i,d in ipairs(data)do
    local row=frame(list,"Row"..i,0,(i-1)*39,w,39,C.Panel);rule(row,0,0,w,C.Grid)
    local vals,positive
    if s.Tab=="Positions"then positive=session:Pnl(d)>=0;vals={d.Contract,d.Direction>0 and"BUY"or"SELL",tostring(d.Quantity),Market.Number(d.Entry),Market.Signed(session:Pnl(d))}
    elseif s.Tab=="Orders"then vals={d.Contract.."Z26",d.Kind,tostring(d.Quantity),Market.Number(d.Price),d.Status or "Working"}
    else positive=d.Pnl>=0;vals={d.Contract.."Z26",tostring(d.Quantity),Market.Number(d.Entry),Market.Number(d.Exit),Market.Signed(d.Pnl),d.Time}end
    for j,value in ipairs(vals)do text(row,"Cell"..j,value,14+fractions[j]*(w-28),2,(w-28)*(j==5 and .23 or .17)-7,35,11,j==5 and positive~=nil and(positive and C.Green or C.Red)or C.Text,j>=3 and N or M)end
    if s.Tab~="History"then
     local positions=s.Tab=="Positions"
     local b=glossy(button(row,"Action"..i,positions and"CLOSE"or"Cancel",14+.85*(w-28),5,(w-28)*.15-10,29,function()
      if positions then close(d.Contract)else local ok,message=session:Cancel(d.Id,d.Protection);if ok then toast("Cancelling order…","info")else fail(message)end end
     end,C.Raised,C.Text,12),positions and"Pink"or"Navy")
     if positions then b:SetAttribute("Sound","Open")else b.Border.Color=C.Cyan end
    end
   end
  end
 end
 local function tradeButtons(p,x,y,w)
  local bw=(w-8)/2
  local pending=s.PendingOrder
  for _,d in ipairs({{1,"BuyLong",s.Type=="Limit"and"↑ BUY LIMIT"or"↑ BUY",C.Buy,0},{-1,"SellShort",s.Type=="Limit"and"↓ SELL LIMIT"or"↓ SELL",C.Sell,bw+8}})do
   local enabled=options.Preview or session.CanTrade
   if pending then d[3]=pending.Direction==d[1]and"SENDING…"or d[3]end
   local b=button(p,d[2],d[3],x+d[5],y,bw,48,function()if enabled then place(d[1])end end,enabled and d[4]or C.Raised,enabled and C.Text or C.Muted,16)
   b.Active=enabled;b.Selectable=enabled;b.Font=B;b.TextSize=20;b.Corners.CornerRadius=UDim.new(0,11)
   if enabled then
    b.BackgroundColor3=Color3.new(1,1,1);b:SetAttribute("RestingColor",Color3.new(1,1,1))
    tint(b,d[1]>0 and Color3.fromRGB(34,253,158)or Color3.fromRGB(255,120,168),d[1]>0 and Color3.fromRGB(0,173,112)or Color3.fromRGB(231,40,99))
    local shine=frame(b,"Shine",8,4,bw-16,3,Color3.new(1,1,1),b.ZIndex);shine.BackgroundTransparency=.35;round(shine,2)
   else tint(b)end
   b.TextTransparency=1;b.TextStrokeTransparency=1
   local label=text(b,"ActionLabel",d[3],5,0,bw-10,48,20,enabled and C.Text or C.Muted,B,CENTER,b.ZIndex+1)
   label.TextStrokeTransparency=1
   label.TextScaled=true;make("UITextSizeConstraint","TextSize",label,{MinTextSize=10,MaxTextSize=20})
   make("UIStroke","TextOutline",label,{Color=d[1]>0 and Color3.fromRGB(0,132,84)or Color3.fromRGB(174,24,75),Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
   b.Border.Thickness=3;b.Border.Color=enabled and(d[1]>0 and Color3.fromRGB(129,255,202)or Color3.fromRGB(255,168,197))or C.Border
   b:SetAttribute("Direction",d[1]);b:SetAttribute("Sound","None");b:SetAttribute("Debounce",.3)
   if pending then
    -- Waiting for the exchange: both sides are locked so a double click can never send twice.
    b:SetAttribute("Disabled",true)
    if pending.Direction~=d[1]then label.TextTransparency=.45 end
    if fx then
     local shine=b:FindFirstChild("Shine")
     if shine then fx:Loop(TweenService:Create(shine,TweenInfo.new(.45,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{BackgroundTransparency=.05}))end
    end
   end
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
   Text=formatter and formatter(value)or tostring(value),TextColor3=enabled==false and C.Muted or C.Text,Font=B,TextSize=24,TextScaled=true,TextStrokeColor3=SC.Ink,TextStrokeTransparency=.55,
   ClearTextOnFocus=false,TextEditable=enabled~=false,BorderSizePixel=0,ZIndex=shell.ZIndex+1})
  make("UITextSizeConstraint","TextSize",field,{MinTextSize=10,MaxTextSize=24})
  local function display(n)return formatter and formatter(n)or tostring(n)end
  local function commit()
   if enabled==false then return true end
   local n=tonumber((field.Text:gsub("[, $]","")))
   if not n or n~=n or math.abs(n)==math.huge or n<minimum or n>maximum or(step==1 and n%1~=0)then
    s.Error=step==1 and("Enter a whole number from "..minimum.." to "..maximum..".")or"Enter a valid positive limit price."
    field.Text=display(current);fail(s.Error);if fx then fx:Shake(shell)end;return false
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
   control:SetAttribute("Sound","Tick");control:SetAttribute("Debounce",.05)
   if enabled==false then control.ControlLabel.TextColor3=C.Muted end
  end
  if fx then fx:Bump(field,field.Text)end
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
   sidebarText(card,"Unit","ticks",8,33,cw-46,18,11,C.Muted)
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
  local hint=sidebarText(p,"OrderExplanation",s.Type=="Market"and"Executes at the available market price"or"Executes at your limit price or better",pad,yy,iw,28,w<300 and 11 or 12,C.Muted);hint.TextXAlignment=CENTER
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
  sidebarText(p,"ProtectionHint","Distances from entry",pad,yy,iw,22,12,C.Muted).TextXAlignment=CENTER;yy+=26
  if s.Error then local warning=text(p,"Error",s.Error,pad,yy,iw,36,11,C.Red);warning.TextWrapped=true;yy+=40 end
  return yy
 end
 local function ticket(x,y,w,h)
  local p=frame(canvas,"OrderTicket",x,y,w,h,C.Panel);panel(p,C.Blue);panelStars(p);p.ClipsDescendants=true
  local held=session.Positions[s.Contract];local iw=w-32
  gameHeading(text(p,"Title","Place a trade",20,10,iw,36,w<300 and 24 or 28,C.Text,B))
  local copying,leading=copyStatus()
  sidebarText(p,"Subtitle",copying or(accountName().." · Virtual funds"),20,44,iw,22,12,copying and C.Blue or C.Muted).TextTruncate=Enum.TextTruncate.AtEnd
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
  sidebarText(actionParent,"Risk",s.StopOn and("Estimated risk  "..Market.Money(s.StopTicks*contract.Tick*contract.Multiplier*s.Qty))or"No stop loss configured",16,yy,iw,22,13,C.Muted).TextXAlignment=CENTER;yy+=28
  rule(actionParent,16,yy,iw);yy+=6
  if held then
   text(actionParent,"Position",(held.Direction>0 and"LONG "or"SHORT ")..held.Quantity.." · "..held.Contract,16,yy,iw,21,12,held.Direction>0 and C.Green or C.Red,M);yy+=24
   text(actionParent,"Pnl",Market.Signed(session:Pnl(held)),16,yy,iw,27,21,session:Pnl(held)>=0 and C.Green or C.Red,N);yy+=30
   local closing=s.PendingClose and s.PendingClose.Contract==held.Contract
   local cb=glossy(button(actionParent,"ClosePosition",closing and"Closing…"or"Close position",16,yy,iw,36,function()if not s.PendingClose then close(held.Contract)end end,C.Raised,C.Text,14),"Pink")
   cb:SetAttribute("Sound","Open");if closing then cb:SetAttribute("Disabled",true)end;yy+=40
  else sidebarText(actionParent,"NoPosition","No open position",16,yy,iw,18,13,C.Muted);yy+=20 end
  sidebarText(actionParent,"Simulation","SIMULATED · Virtual funds only",16,yy,iw,18,10,C.Muted).TextXAlignment=CENTER;yy+=22
  if not fixed then sc.CanvasSize=UDim2.fromOffset(0,yy)end
 end
 local function mobileDock(x,y,w,h,compact)
  local p=frame(canvas,"TradeDock",x,y,w,h,C.Bg,10)
  local qw=math.min(144,w*.45)
  sidebarText(p,"QtyLabel","Quantity",2,0,w-qw-58,44,w<340 and 14 or 16)
  quantity(p,w-qw-51,0,qw)
  local more=glossy(button(p,"OrderSettings","···",w-44,0,44,44,function()s.Sheet=true;refresh()end,C.Raised,C.Text,20),"Navy")
  more.Border.Color=C.Cyan;more:SetAttribute("Sound","None")
  local cw=(w-8)/2
  for i,d in ipairs({{"Stop","SL · Stop loss",s.StopOn,s.StopTicks,C.Red},{"Target","TP · Take profit",s.TargetOn,s.TargetTicks,C.Green}})do
   local bh=compact and 40 or 56
   local b=button(p,d[1].."Card","",(i-1)*(cw+8),compact and 50 or 52,cw,bh,openProtection,Color3.new(1,1,1))
   b.Corners.CornerRadius=UDim.new(0,12);b.Border.Color=d[5];b.Border.Thickness=3
   tint(b,Color3.fromRGB(8,40,104),Color3.fromRGB(3,22,62))
   b:SetAttribute("Sound","None")
   if compact then
    protectionIcon(b,d[1],7,(bh-18)/2,18)
    local t=text(b,"Distance",(i==1 and"SL · "or"TP · ")..(d[3]and tostring(d[4]).." ticks"or"Off"),28,0,cw-34,bh,12,d[3]and C.Text or C.Muted,N,CENTER)
    t.ZIndex=b.ZIndex+2
   else
    protectionIcon(b,d[1],8,6,18)
    local l=sidebarText(b,"Label",d[2],30,2,cw-38,22,12);l.ZIndex=b.ZIndex+2
    local t=text(b,"Distance",d[3]and tostring(d[4]).." ticks"or"Off",10,26,cw-20,26,15,d[3]and C.Text or C.Muted,N);t.ZIndex=b.ZIndex+2
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
   {"Account equity",Market.Money(sum.Equity),C.Text},
   {"Open P&L",Market.Signed(sum.Unrealized),sum.Unrealized>=0 and SC.Green or SC.Red},
   {"Realized on this account",Market.Signed(realized),realized>=0 and SC.Green or SC.Red},
   {"Maximum loss",Market.Money(session.Base),Color3.fromRGB(255,219,51)},
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
  local note=sidebarText(footer,"Note","Account fails only at $0 equity",0,bh+19,pw-pad*2,21,narrow and 12 or 15,C.Muted);note.TextXAlignment=CENTER
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
  dismissButton(shell,pw-56,14,42,closeProtection,43)
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
 -- Shared popup chrome (reference popups): cyan-rimmed gradient shell, purple header band with a
 -- colorful icon and outlined title, and a red close button. Content scrolls when the screen is short.
 local function popupShell(w,h,pw,contentH,title,iconKind,subtitle)
  local narrow=pw<380
  local headH=subtitle and(narrow and 76 or 84)or(narrow and 60 or 66)
  local top=headH+20
  local ph=top+contentH+10
  local viewH=math.min(ph,h-24)
  local shell=frame(canvas,"Dialog",(w-pw)/2,(h-viewH)/2,pw,viewH,Color3.new(1,1,1),41)
  round(shell,22);stroke(shell,Color3.fromRGB(4,221,255)).Thickness=4
  tint(shell,Color3.fromRGB(6,56,147),Color3.fromRGB(3,30,83))
  local rim=frame(shell,"InnerRim",5,5,pw-10,viewH-10,Color3.new(1,1,1),41);rim.BackgroundTransparency=1
  round(rim,18);stroke(rim,Color3.fromRGB(31,125,255)).Thickness=2
  local hero=frame(shell,"Header",9,9,pw-18,headH,Color3.new(1,1,1),42)
  round(hero,16);stroke(hero,Color3.fromRGB(168,100,255)).Thickness=3
  tint(hero,Color3.fromRGB(150,70,255),Color3.fromRGB(84,32,232));panelStars(hero)
  local iconSize=math.min(52,headH-16);local tx=16
  if iconKind then sidebarImage(hero,iconKind,10,(headH-iconSize)/2,iconSize);tx=iconSize+20 end
  local closeSize=narrow and 38 or 42
  local tw=pw-18-tx-closeSize-22
  local t=sidebarText(hero,"Title",title,tx,subtitle and 8 or 0,tw,subtitle and 40 or headH,narrow and 22 or 27)
  t.ZIndex=45
  if subtitle then local sub=sidebarText(hero,"Subtitle",subtitle,tx,headH-34,tw,24,narrow and 11 or 13,Color3.fromRGB(236,227,255));sub.ZIndex=45 end
  dismissButton(hero,pw-18-closeSize-10,(headH-closeSize)/2,closeSize,function()s.ProtectionDraft=nil;s.Overlay=nil;refresh()end,46)
  local content=make("ScrollingFrame","Content",shell,{Position=UDim2.fromOffset(0,top),Size=UDim2.fromOffset(pw,viewH-top-6),
   CanvasSize=UDim2.fromOffset(pw,contentH),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,ZIndex=43})
  return shell,content
 end
 -- A selectable row: purple (or cyan) glossy when selected, deep navy otherwise.
 local function option(p,name,x,y,ow,oh,selected,fn,cyan)
  local b=button(p,name,"",x,y,ow,oh,fn,Color3.new(1,1,1),C.Text,14,44)
  sidebarSurface(b,selected,cyan);if fx then fx:Selected(b,selected)end
  return b
 end
 local function optionLabel(b,name,value,x,y,ow,oh,size,color)
  local t=sidebarText(b,name,value,x,y,ow,oh,size,color);t.ZIndex=b.ZIndex+3;return t
 end
 -- ON/OFF pill switch with a sliding knob.
 local function switch(p,name,x,y,on,fn)
  local b=glossy(button(p,name,on and"ON   "or"   OFF",x,y,86,36,fn,C.Raised,C.Text,15,45),on and"Purple"or"Navy")
  b.Corners.CornerRadius=UDim.new(0,18);b.Border.Color=on and C.Cyan or C.Border
  local knob=frame(b,"Knob",on and 56 or 6,6,24,24,on and Color3.fromRGB(220,250,255)or Color3.fromRGB(120,150,200),b.ZIndex+3);round(knob,12)
  stroke(knob,on and C.Cyan or C.Border).Thickness=2
  b:SetAttribute("On",on)
  return b
 end
 local function popupButton(p,name,value,x,y,bw,bh,fn,variant,size)
  local b=glossy(button(p,name,value,x,y,bw,bh,fn,C.Raised,C.Text,size or 18,45),variant)
  b.Corners.CornerRadius=UDim.new(0,14);b.Border.Thickness=3
  return b
 end
 local function body(p,name,value,x,y,bw,bh,size,color)
  local t=text(p,name,value,x,y,bw,bh,size or 14,color or Color3.fromRGB(214,234,255),M,nil,44)
  t.TextWrapped=true;t.TextYAlignment=Enum.TextYAlignment.Top;return t
 end
 local function overlay(w,h)
  if not s.Overlay then return end
  button(canvas,"OverlayBackdrop","",0,0,w,h,function()s.ProtectionDraft=nil;s.Overlay=nil;refresh()end,C.Bg,C.Text,12,40).BackgroundTransparency=.28
  if s.Overlay=="Account"then accountDetails(w,h);return end
  if s.Overlay=="Protection"then protectionPopup(w,h);return end
  local pf=session.Portfolio
  local switchable={}
  for _,list in ipairs({pf and pf.Accounts or{},pf and pf.Legacy or{}})do for _,row in ipairs(list)do if row.State==nil or row.State=="Active"then table.insert(switchable,row)end end end
  local pw=math.min(w-28,s.Overlay=="CopyIntro"and 460 or s.Overlay=="Tools"and 470 or 430)
  local narrow=pw<380
  local pad=narrow and 16 or 22;local iw=pw-pad*2
  local function close()s.Overlay=nil;refresh()end
  if s.Overlay=="Close"then
   local held=session.Positions[s.CloseContract]
   local _,p=popupShell(w,h,pw,204,"Close position?","Positions")
   optionLabel(p,"Position",held and(held.Contract.." · "..(held.Direction>0 and"LONG"or"SHORT").." · "..held.Quantity.." contract"..(held.Quantity==1 and""or"s"))or"This position has already closed.",pad,0,iw,30,narrow and 17 or 20)
   local pnl=held and session:Pnl(held)or 0
   if held then
    local box=frame(p,"ResultBox",pad,38,iw,58,Color3.fromRGB(3,24,70),44);round(box,14);stroke(box,pnl>=0 and SC.Green or SC.Red).Thickness=2
    optionLabel(box,"ResultLabel","Current result",14,0,iw*.5,58,narrow and 15 or 17,Color3.fromRGB(214,234,255))
    local r=summaryText(box,"Result",Market.Signed(pnl),iw*.45,6,iw*.55-14,46,28,pnl>=0 and SC.Green or SC.Red,false);r.TextXAlignment=RIGHT;r.ZIndex=46
   end
   local bw=(iw-12)/2
   popupButton(p,"KeepOpen","Keep open",pad,112,bw,54,close,"Navy",narrow and 17 or 20).Border.Color=C.Cyan
   local confirm=popupButton(p,"ConfirmClose","Close",pad+bw+12,112,bw,54,function()
    local key=s.CloseContract;s.Overlay=nil
    if session.Positions[key]and not s.PendingClose then
     local ok,msg,_,requestId=session:Close(key);s.Error=nil
     if ok then
      local pending={Id=requestId,Contract=key};s.PendingClose=pending
      if fx then fx:Play("Send")end;toast("Closing "..key.."…","info")
      task.delay(6,function()if alive and s.PendingClose==pending then s.PendingClose=nil;refresh()end end)
     else fail(msg)end
    else refresh()end
   end,"Pink",narrow and 17 or 20)
   confirm:SetAttribute("Sound","None");confirm:SetAttribute("Debounce",.4)
   text(p,"Note","Closed profits minus losses count toward unlocks.",pad,172,iw,30,11,C.Muted,F,CENTER,44).TextWrapped=true
  elseif s.Overlay=="Guide"then
   local _,p=popupShell(w,h,pw,262,"First-trade guide","Learn","STEP "..s.Guide.." OF "..#steps)
   optionLabel(p,"Title",steps[s.Guide][1],pad,0,iw,32,narrow and 19 or 23)
   body(p,"Body",steps[s.Guide][2],pad,38,iw,120,narrow and 13 or 15)
   for i=1,#steps do
    local dot=frame(p,"StepDot"..i,pw/2-(#steps*22)/2+(i-1)*22+4,166,14,14,i==s.Guide and C.Blue or Color3.fromRGB(20,60,140),44)
    round(dot,7);stroke(dot,i<=s.Guide and C.Cyan or C.Border).Thickness=2
   end
   local bw=(iw-12)/2
   popupButton(p,"Skip","Skip for now",pad,196,bw,52,close,"Navy",narrow and 15 or 18).Border.Color=C.Cyan
   popupButton(p,"Next",s.Guide==#steps and"Start practicing"or"Next  →",pad+bw+12,196,bw,52,function()if s.Guide<#steps then s.Guide+=1 else s.Overlay=nil end;refresh()end,"Purple",narrow and 15 or 18)
  elseif s.Overlay=="Contracts"then
   local _,p=popupShell(w,h,pw,#Market.ContractOrder*66,"Select a contract","Trade","E-mini futures · simulated market")
   for i,key in ipairs(Market.ContractOrder)do
    local c=Market.Contracts[key];local selected=key==s.Contract
    local b=option(p,"Choose"..key,pad,(i-1)*66,iw,58,selected,function()s.Overlay=nil;selectContract(key)end)
    optionLabel(b,"Symbol",key.."Z26",14,4,120,28,narrow and 18 or 21)
    local n=text(b,"Name",c.Short,14,31,iw-170,20,12,Color3.fromRGB(214,234,255),M,nil,b.ZIndex+3);n.TextTruncate=Enum.TextTruncate.AtEnd
    text(b,"Price",Market.Number(session.Prices[key]),iw-168,0,selected and 126 or 154,58,16,C.Text,N,RIGHT,b.ZIndex+3)
    if selected then local dot=frame(b,"Dot",iw-30,23,12,12,Color3.fromRGB(93,255,83),b.ZIndex+3);round(dot,6);stroke(dot,SC.Ink).Thickness=3 end
   end
  elseif s.Overlay=="Timeframes"then
   local list={"1m","5m","15m","1h","1D"}
   local _,p=popupShell(w,h,pw,#list*56,"Timeframe","Trade","Candle interval")
   for i,tf in ipairs(list)do
    local b=option(p,"Choose"..tf,pad,(i-1)*56,iw,48,s.Timeframe==tf,function()s.Timeframe=tf;s.Overlay=nil;chartView:CancelPlacement();refresh()end)
    local t=optionLabel(b,"Label",tf,0,0,iw,48,20);t.TextXAlignment=CENTER
   end
  elseif s.Overlay=="Tools"then
   -- Two columns of touch-size buttons; the active tool and magnet are highlighted.
   local items={{"Pan","Select & pan"},{"Crosshair","Crosshair"},{"Trend","Trend line"},{"Line","Horizontal line"},{"Rect","Rectangle"},
    {"Magnet",s.Magnet and"Magnet: on"or"Magnet: off"},{"Undo","Undo"},{"Redo","Redo"},{"Delete","Delete selected"},{"Clear","Clear drawings"},
    {"ResetView","Reset view"},{"AutoFit","Auto fit price"},{"GoLive","Go to live"}}
   local colW=(iw-10)/2
   local _,p=popupShell(w,h,pw,math.ceil(#items/2)*54,"Chart tools","Settings","Draw, navigate and fit the chart")
   for i,t in ipairs(items)do
    local col=(i-1)%2;local row=(i-1)//2
    local active=s.Tool==t[1]or t[1]=="Magnet"and s.Magnet
    local b=option(p,"Tool"..t[1],pad+col*(colW+10),row*54,colW,46,active,function()
     s.Overlay=nil
     if t[1]=="Delete"then chartView:DeleteSelected()
     elseif t[1]=="ResetView"then chartView:ResetView()
     elseif t[1]=="AutoFit"then chartView:AutoFit()
     elseif t[1]=="GoLive"then chartView:GoLive()
     else chartView:Command(t[1])end
     refresh()
    end)
    local l=optionLabel(b,"Label",t[2],8,0,colW-16,46,narrow and 13 or 16);l.TextXAlignment=CENTER
   end
  elseif s.Overlay=="Menu"then
   local items={{"Dashboard","Funded accounts dashboard","Accounts"},{"Tour","Guided first trade","Learn"},{"Guide","First-trade walkthrough","Learn"},
    {"History","Trade review","Review"},{"Settings","Settings & sound","Settings"},{"Accounts","Switch account","Positions"}}
   local _,p=popupShell(w,h,pw,#items*58,"Get Funded!","Accounts","Menu")
   for i,t in ipairs(items)do
    local b=option(p,t[1],pad,(i-1)*58,iw,50,false,function()
     if t[1]=="History"then s.Sheet="Activity";s.Tab="History";s.Overlay=nil
     elseif t[1]=="Dashboard"then navigate("Accounts");return
     elseif t[1]=="Tour"then s.Overlay=nil;s.Coach=1;s.CoachBase=nil
     else s.Overlay=t[1];s.Guide=1 end
     refresh()
    end)
    sidebarImage(b,t[3],10,7,36).ZIndex=b.ZIndex+3
    optionLabel(b,"Label",t[2],56,0,iw-70,50,narrow and 16 or 18)
   end
  elseif s.Overlay=="Accounts"then
   local _,p=popupShell(w,h,pw,62+#switchable*64+56,"Switch account","Accounts")
   body(p,"Note","Each account has its own balance, positions and risk limits. Switching never pauses or closes the others.",pad,0,iw,48,narrow and 12 or 13)
   for i,row in ipairs(switchable)do
    local current=pf and pf.Active==row.Key
    local b=option(p,"Account"..row.Key,pad,56+(i-1)*64,iw,56,current,function()if current then s.Overlay=nil;refresh()else account(row.Key)end end)
    local bx=iw-150
    optionLabel(b,"Name",row.Name..(row.State==nil and"  ·  legacy"or""),14,4,bx-18,28,narrow and 16 or 18).TextTruncate=Enum.TextTruncate.AtEnd
    text(b,"Detail",row.Breached and"Account depleted · restart from the dashboard"or(current and"Trading now"or"Tap to trade"),14,31,bx-18,18,11,row.Breached and Color3.fromRGB(255,170,190)or Color3.fromRGB(226,238,255),M,nil,b.ZIndex+3).TextTruncate=Enum.TextTruncate.AtEnd
    text(b,"Balance",Market.Money(row.Balance or 0),bx,0,136,56,14,C.Text,N,RIGHT,b.ZIndex+3)
   end
   local y2=56+#switchable*64+6
   popupButton(p,"ManageAccounts","All accounts  →",pad,y2,iw,48,function()navigate("Accounts")end,"Cyan",narrow and 16 or 19)
  elseif s.Overlay=="CopyIntro"then
   local _,p=popupShell(w,h,pw,300,"Copy trading","Positions","NEW · SECOND ACCOUNT ACTIVE")
   body(p,"Body","Trade one account and optionally copy its trades to your other funded accounts.",pad,0,iw,40,narrow and 14 or 15,C.Text)
   for i,rule_ in ipairs({"Off until you turn it on. You choose the lead and followers.","Each copy uses that account's own funds and risk limits.","Skipped or rejected copies are reported after every order.","Turning it off never closes positions."})do
    local badge=frame(p,"Check"..i,pad,52+(i-1)*44,24,24,SC.Green,44);round(badge,12);stroke(badge,SC.Ink).Thickness=2
    line(badge,"Tick",6,12,10,17,SC.Ink,3,45);line(badge,"Tick",9,17,18,7,SC.Ink,3,45)
    body(p,"Rule"..i,rule_,pad+34,52+(i-1)*44,iw-34,40,narrow and 12 or 13)
   end
   local bw=(iw-12)/2
   popupButton(p,"NotNow","Not now",pad,236,bw,52,function()s.Overlay=nil;session:Flag("CopyIntro");refresh()end,"Navy",narrow and 16 or 19).Border.Color=C.Cyan
   popupButton(p,"SetUpCopy","Set up copying",pad+bw+12,236,bw,52,function()session:Flag("CopyIntro");s.Focus="Copy";navigate("Accounts")end,"Purple",narrow and 15 or 18)
  elseif s.Overlay=="Settings"then
   local _,p=popupShell(w,h,pw,366,"Settings","Settings","Workspace, sound and market session")
   local acct=option(p,"SelectAccount",pad,0,iw,50,true,function()s.Overlay="Accounts";refresh()end,true)
   optionLabel(acct,"Label",accountName().."  ·  switch  →",14,0,iw-28,50,narrow and 16 or 18)
   local rows={
    {"ShowLevels","Chart levels","Entry, stop and target lines",s.Levels,function()s.Levels=not s.Levels;refresh()end},
    {"SoundToggle","Sound effects","Clicks, confirmations and alerts",s.SoundOn~=false,function()
     s.SoundOn=s.SoundOn==false;if fx then fx:SetSound(s.SoundOn~=false);if s.SoundOn~=false then fx:Play("Select")end end;refresh()end},
   }
   for i,r in ipairs(rows)do
    local y=62+(i-1)*62
    local card=frame(p,r[1].."Row",pad,y,iw,54,Color3.fromRGB(3,24,70),44);round(card,14);stroke(card,C.Border).Thickness=2
    optionLabel(card,"Label",r[2],14,4,iw-120,26,narrow and 16 or 18)
    text(card,"Detail",r[3],14,29,iw-120,18,11,C.Muted,M,nil,46).TextTruncate=Enum.TextTruncate.AtEnd
    local sw=switch(card,r[1],iw-98,9,r[4],r[5]);sw:SetAttribute("Sound",r[1]=="SoundToggle"and"None"or nil)
   end
   local vy=62+2*62
   optionLabel(p,"VolumeLabel","Volume",pad,vy,110,40,narrow and 16 or 18)
   local levels={"Low","Medium","High"};local segW=(iw-110-8*2)/3
   for i,level in ipairs(levels)do
    local on=(s.SoundLevel or"Medium")==level
    local b=gameControl(button(p,"Level"..level,level,pad+110+(i-1)*(segW+8),vy,segW,40,function()
     s.SoundLevel=level;if fx then fx:SetSound(nil,level)end;refresh()
    end,C.Panel,C.Text,narrow and 13 or 15,45),on)
    if s.SoundOn==false then b.ControlLabel.TextTransparency=.45 end
   end
   local box=frame(p,"Session",pad,vy+54,iw,96,Color3.fromRGB(3,24,70),44);round(box,14);stroke(box,C.Border).Thickness=2
   text(box,"ExchangeStatus",(session.ConnectionStatus or"SIMULATED PREVIEW").." · "..session.Speed.."x",14,8,iw-28,22,12,C.Cyan,N,nil,46).TextTruncate=Enum.TextTruncate.AtEnd
   body(box,"Details","Server-run simulated order book. Prices and slippage come from executions. Virtual funds only; no fees or real market connection. Regime: "..session.Regime,14,34,iw-28,82,12)
  else
   local info=s.Overlay=="Info"
   local _,p=popupShell(w,h,pw,210,info and"Trading terms"or"Trading help","Help")
   body(p,"Body",info and s.Info or"Long profits from rises; short from falls. ES ticks are 0.25 points ($12.50 per contract). Account equity includes open P&L. Failure is at $0 equity; margin exits can happen sooner.",pad,0,iw,140,narrow and 14 or 15,C.Text)
   popupButton(p,"Learn","First-trade walkthrough  →",pad,150,iw,50,function()s.Overlay="Guide";s.Guide=1;refresh()end,"Cyan",narrow and 15 or 18)
  end
 end
 -- ── Funded journey: welcome, dashboard, guided first trade and celebrations ──────────────────
 local AtEnd,Top=Enum.TextTruncate.AtEnd,Enum.TextYAlignment.Top
 local function chip(p,name,value,x,y,color,w)
  local width=w or(#value*7+22)
  local c=frame(p,name,x,y,width,22,color:Lerp(SC.Ink,.62));round(c,11);stroke(c,color).Thickness=2
  local t=text(c,"Label",value,0,0,width,22,11,color:Lerp(Color3.new(1,1,1),.35),Enum.Font.FredokaOne,CENTER);t.ZIndex=c.ZIndex+1
  return c
 end
 -- Game progress track: ink rim, dark well and a glossy gold (or green) fill.
 local function progressBar(p,name,x,y,w,h,progress,color)
  h=math.max(h,8)
  local track=frame(p,name,x,y,w,h+4,SC.Ink);round(track,math.floor((h+4)/2))
  local well=frame(track,"Well",2,2,w-4,h,Color3.fromRGB(8,31,84));round(well,math.floor(h/2));stroke(well,Color3.fromRGB(38,77,161))
  if progress>0 then
   local fill=frame(track,"Fill",2,2,math.max(h,(w-4)*math.clamp(progress,0,1)),h,Color3.new(1,1,1));round(fill,math.floor(h/2))
   if color==C.Green then tint(fill,Color3.fromRGB(120,255,170),Color3.fromRGB(0,190,110))else tint(fill,Color3.fromRGB(255,248,137),Color3.fromRGB(255,176,16))end
  end
  return track
 end
 -- Colourful card surface shared by dashboard cards: gradient body, bright rim, optional stars.
 local function card(p,name,x,y,w,h,top,bottom,edge,stars)
  local c=frame(p,name,x,y,w,h,Color3.new(1,1,1));round(c,18)
  local e=stroke(c,edge);e.Thickness=3
  tint(c,top,bottom);if stars then panelStars(c)end
  return c
 end
 local function goTrade()s.Screen="Trade";s.Nav="Trade";s.Overlay=nil;refresh()end
 local function startFunded()
  if not session.CanTrade then fail(session.ConnectionStatus or"Connecting to the simulated exchange.");return end
  if s.Starting then return end
  local ok,message=session:Start()
  if ok then s.Starting=true;refresh()else fail(message)end
 end
 local function welcome(w,h)
  local starter=Ladder.Tiers[1]
  local cw=math.min(640,w-24);local narrow=cw<440;local pad=narrow and 18 or 32;local iw=cw-pad*2
  local big=narrow and(cw<360 and 22 or 25)or 34;local lineH=big+8
  local bg=make("ScrollingFrame","Welcome",canvas,{Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),BackgroundColor3=C.Bg,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan})
  -- Decorative executed-candle silhouettes in the brand palette.
  for i=0,math.floor(w/46)do
   local bh=26+((i*53)%90)
   local bar=frame(bg,"Motif",i*46+16,h-bh-28-((i*29)%40),12,bh,(i*7)%3~=0 and C.Green or C.Red);bar.BackgroundTransparency=.82;round(bar,3)
  end
  for i,xy in ipairs({{.08,.14},{.9,.2},{.14,.7},{.86,.76}})do
   local d=frame(bg,"Diamond"..i,xy[1]*w-18,xy[2]*h-18,36,36,Color3.fromRGB(0,100,255));d.Rotation=45;d.BackgroundTransparency=.86;round(d,6)
  end
  local shell=card(bg,"WelcomeCard",(w-cw)/2,12,cw,400,Color3.fromRGB(6,56,147),Color3.fromRGB(3,30,83),Color3.fromRGB(4,221,255),false)
  shell.Border.Thickness=5
  local rim=frame(shell,"InnerRim",5,5,cw-10,390,Color3.new(1,1,1));rim.BackgroundTransparency=1;round(rim,15);stroke(rim,Color3.fromRGB(31,125,255)).Thickness=2
  local heroH=narrow and 92 or 124
  local hero=card(shell,"Hero",10,10,cw-20,heroH,Color3.fromRGB(150,70,255),Color3.fromRGB(84,32,232),Color3.fromRGB(168,100,255),true)
  local trophy=heroH-16
  sidebarImage(hero,"Accounts",8,8,trophy)
  local brand=sidebarText(hero,"Brand",'Get <font color="#FFD336">Funded!</font>',trophy+18,narrow and 10 or 16,cw-trophy-60,narrow and 42 or 58,narrow and 32 or 48)
  brand.RichText=true
  sidebarText(hero,"Eyebrow","SIMULATED PROP FIRM · VIRTUAL FUNDS",trophy+20,heroH-(narrow and 36 or 44),cw-trophy-60,22,narrow and 11 or 14,Color3.fromRGB(236,227,255))
  local yy=heroH+26
  for i,value in ipairs({"Start with "..whole(starter.Size)..".","Prove your skills.","Build your funded portfolio."})do
   sidebarText(shell,"Headline"..i,value,pad,yy,iw,lineH,big,i==1 and Color3.fromRGB(255,222,70)or C.Text);yy+=lineH
  end
  yy+=8
  local intro=text(shell,"Body","Trade a "..whole(starter.Size).." funded account. Bank net realized profit to unlock larger accounts, then copy trades across them to scale.",pad,yy,iw,narrow and 58 or 44,narrow and 13 or 15,Color3.fromRGB(214,234,255),M)
  intro.TextWrapped=true;intro.TextYAlignment=Top;yy+=narrow and 64 or 54
  local n=#Ladder.Tiers;local gap=narrow and 6 or 10;local chipW=(iw-gap*(n-1))/n
  for i,t in ipairs(Ladder.Tiers)do
   local first=i==1
   local c=card(shell,"Tier"..t.Id,pad+(i-1)*(chipW+gap),yy,chipW,62,first and Color3.fromRGB(150,80,255)or Color3.fromRGB(15,48,117),first and Color3.fromRGB(80,28,214)or Color3.fromRGB(3,24,66),first and Color3.fromRGB(196,140,255)or C.Border,false)
   c.Corners.CornerRadius=UDim.new(0,14);c.Border.Thickness=2
   local size=sidebarText(c,"Size",t.Short,0,6,chipW,28,narrow and 16 or 21);size.TextXAlignment=CENTER
   local unlock=sidebarText(c,"Unlock",first and"START"or("+"..whole(t.Unlock)),0,34,chipW,20,narrow and 10 or 12,first and C.Text or Color3.fromRGB(255,214,60))
   unlock.TextXAlignment=CENTER
  end
  yy+=74
  local journey=sidebarText(shell,"Journey","Start  →  Trade  →  Earn  →  Unlock  →  Scale",pad,yy,iw,20,narrow and 11 or 13,SB.Muted);journey.TextXAlignment=CENTER;yy+=30
  local ready=session.CanTrade
  local start=glossy(button(shell,"StartFunded",s.Starting and"Opening your account…"or ready and"Start a Funded Account"or"Connecting to the exchange…",pad,yy,iw,60,startFunded,C.Raised,C.Text,narrow and 19 or 24),ready and not s.Starting and"Purple"or"Navy")
  start.Corners.CornerRadius=UDim.new(0,16);start.Border.Thickness=3
  if not ready or s.Starting then start.ControlLabel.TextColor3=C.Muted;start:SetAttribute("Disabled",s.Starting==true)end
  yy+=74
  glossy(button(shell,"Leaderboard","View Leaderboard",pad,yy,iw,44,function()navigate("Leaderboard")end,C.Raised,C.Text,17),"Cyan")
  yy+=56
  local note=text(shell,"Simulated","All trading, prices and funds are simulated. No real money is involved and nothing can be withdrawn.",pad,yy,iw,34,11,C.Muted,F,CENTER)
  note.TextWrapped=true;yy+=34+pad-6
  shell.Size=UDim2.fromOffset(cw,yy);shell.Position=UDim2.fromOffset((w-cw)/2,math.max(12,(h-yy)/2))
  rim.Size=UDim2.fromOffset(cw-10,yy-10)
  bg.CanvasSize=UDim2.fromOffset(0,math.max(h,yy+24))
 end
 local function loading(w,h)
  local bg=frame(canvas,"Loading",0,0,w,h,C.Bg)
  local mark=sidebarText(bg,"Wordmark",'Get <font color="#FFD336">Funded!</font>',0,h/2-78,w,56,w<500 and 36 or 48);mark.RichText=true;mark.TextXAlignment=CENTER
  local status=sidebarText(bg,"Status","Connecting to your funded portfolio…",0,h/2-12,w,26,w<500 and 14 or 17,SB.Muted);status.TextXAlignment=CENTER
  text(bg,"Exchange",session.ConnectionStatus or"CONNECTING",0,h/2+20,w,20,11,C.Cyan,N,CENTER)
  for i=1,3 do
   local dot=frame(bg,"Dot"..i,w/2-36+(i-1)*28,h/2+56,16,16,i==2 and C.Blue or C.Cyan);round(dot,8);stroke(dot,SC.Ink).Thickness=2
   if fx then fx:Loop(TweenService:Create(dot,TweenInfo.new(.42,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true,(i-1)*.14),{Position=dot.Position-UDim2.fromOffset(0,10)}))end
  end
 end
 local function tierCard(p,row,x,y,w,h,mobile,pf)
  local active=row.State=="Active";local starting=row.State=="Start";local ready=row.State=="Unlocked"or starting;local current=pf.Active==row.Key
  -- Current: purple · active: blue · ready: gold · breached: pink · locked: deep navy.
  local look=row.Breached and{Color3.fromRGB(120,24,80),Color3.fromRGB(60,10,52),Color3.fromRGB(255,120,168)}
   or current and{Color3.fromRGB(128,62,250),Color3.fromRGB(66,24,196),Color3.fromRGB(196,140,255)}
   or active and{Color3.fromRGB(0,120,230),Color3.fromRGB(0,56,150),Color3.fromRGB(80,232,255)}
   or ready and{Color3.fromRGB(190,120,0),Color3.fromRGB(120,60,0),Color3.fromRGB(255,222,40)}
   or{Color3.fromRGB(10,40,100),Color3.fromRGB(3,22,62),C.Border}
  local c=card(p,"Tier"..row.Key,x,y,w,h,look[1],look[2],look[3],not mobile and(active or ready))
  local status=row.Breached and"DEPLETED"or active and(current and"TRADING"or"ACTIVE")or starting and"START HERE"or ready and"READY"or"LOCKED"
  local statusColor=row.Breached and C.Red or active and C.Green or ready and Color3.fromRGB(255,222,40)or C.Muted
  local role=row.Role and(row.Role=="Lead"and"LEAD"or"FOLLOW")
  local earned=pf.Earned or 0
  local lit=active or ready
  local titleColor=lit and C.Text or Color3.fromRGB(150,180,225)
  if mobile then
   sidebarText(c,"Size",row.Short,14,8,104,30,22,titleColor)
   chip(c,"Status",status,14,42,statusColor)
   if role then chip(c,"Role",role,14,68,C.Blue)end
   local tight=w<300;local mx=tight and 100 or 118;local mw=w-mx-(tight and 102 or 122)
   if active then
    text(c,"Balance",Market.Money(row.Balance or 0),mx,14,mw,20,13,C.Text,N).TextTruncate=AtEnd
    text(c,"Realized","Realized "..Market.Signed(row.Realized or 0),mx,38,mw,16,10,(row.Realized or 0)>=0 and SC.Green or SC.Red,N).TextTruncate=AtEnd
    text(c,"Open",row.Breached and"Account depleted"or((row.Positions or 0).." open · "..Market.Signed(row.Unrealized or 0)),mx,58,mw,16,10,row.Breached and SC.Red or Color3.fromRGB(214,234,255),N).TextTruncate=AtEnd
   elseif ready then
    sidebarText(c,"Ready",starting and"Your first account"or"Unlocked · ready",mx,20,mw,20,13,Color3.fromRGB(255,222,70)).TextTruncate=AtEnd
    text(c,"Capital",whole(row.Size).." simulated capital",mx,44,mw,16,10,Color3.fromRGB(255,240,200)).TextTruncate=AtEnd
   else
    local t=text(c,"Requirement","Stage goal: "..whole(row.Goal).." net profit",mx,12,mw,30,10,Color3.fromRGB(190,214,250));t.TextWrapped=true
    progressBar(c,"Progress",mx,46,mw,6,math.clamp((row.Progress or 0)/math.max(1,row.Goal or row.Unlock),0,1),C.Blue)
    text(c,"Remaining",whole(math.max(0,(row.Goal or row.Unlock)-(row.Progress or 0))).." to go",mx,62,mw,16,10,C.Muted,N).TextTruncate=AtEnd
   end
  else
   sidebarText(c,"Size",row.Short,16,12,w-32,36,30,titleColor)
   text(c,"Kind","Funded account",16,48,w-32,16,11,Color3.fromRGB(214,234,255),M)
   local sw=#status*7+22;chip(c,"Status",status,w-sw-14,18,statusColor,sw)
   if role then local rw=#role*7+22;chip(c,"Role",role,w-rw-14,44,C.Blue,rw)end
   if active then
    text(c,"BalanceLabel","Balance",16,72,w-32,14,10,Color3.fromRGB(214,234,255),M)
    summaryText(c,"Balance",Market.Money(row.Balance or 0),16,86,w-32,24,w<200 and 16 or 19,C.Text,false).TextXAlignment=Enum.TextXAlignment.Left
    text(c,"RealizedLabel","Realized profit",16,112,w-32,14,10,Color3.fromRGB(214,234,255),M)
    summaryText(c,"Realized",Market.Signed(row.Realized or 0),16,126,w-32,24,w<200 and 15 or 18,(row.Realized or 0)>=0 and SC.Green or SC.Red,false).TextXAlignment=Enum.TextXAlignment.Left
    local t=text(c,"Open",row.Breached and"Account depleted. Restart with fresh capital; the loss still counts."or((row.Positions or 0).." open · "..Market.Signed(row.Unrealized or 0).." open P&L"),16,row.Breached and 144 or 152,w-32,row.Breached and 26 or 16,10,row.Breached and Color3.fromRGB(255,180,200)or Color3.fromRGB(214,234,255),N)
    t.TextWrapped=row.Breached==true
   elseif ready then
    summaryIcon(c,"Trophy",12,72,34)
    sidebarText(c,"Ready",starting and"Your first account"or"Unlocked!",52,74,w-66,30,17,Color3.fromRGB(255,228,80))
    local t=text(c,"Detail",starting and("Opens with "..whole(row.Size).." of simulated funded capital. Trade it to earn realized profit and unlock the next account.")
     or("Unlocked. Activating adds "..whole(row.Size).." of simulated funded capital."),16,110,w-32,58,11,Color3.fromRGB(255,240,210))
    t.TextWrapped=true;t.TextYAlignment=Top
   else
    icon(c,"Lock",16,78,18,Color3.fromRGB(120,170,240))
    local t=text(c,"Requirement","Stage goal: "..whole(row.Goal).." net realized profit",42,72,w-58,36,11,Color3.fromRGB(190,214,250));t.TextWrapped=true
    progressBar(c,"Progress",16,118,w-32,6,math.clamp((row.Progress or 0)/math.max(1,row.Goal or row.Unlock),0,1),C.Blue)
    text(c,"Remaining",whole(math.max(0,(row.Goal or row.Unlock)-(row.Progress or 0))).." to go",16,134,w-32,16,10,C.Muted,N)
   end
  end
  local function action(label,fn,variant,muted)
   local bw=mobile and(w<300 and 88 or 106)or w-28;local bx=mobile and w-bw-12 or 14;local by=mobile and(h-40)/2 or h-54
   local b=glossy(button(c,"Action",label,bx,by,bw,40,fn,C.Raised,C.Text,mobile and 13 or 15),variant)
   b.Corners.CornerRadius=UDim.new(0,12)
   if muted then b.ControlLabel.TextColor3=C.Muted end
   return b
  end
  if active and row.Breached then action("Restart",function()local ok,message=session:Restart(row.Key);if not ok then fail(message)end end,"Pink")
  elseif active and current then action("Trading now  →",goTrade,"Purple")
  elseif active then action("Trade "..row.Short,function()account(row.Key)end,"Cyan")
  elseif starting then action("Start "..row.Short,startFunded,"Green")
  elseif ready then action("Activate "..row.Short,function()local ok,message=session:Activate(row.Key);if not ok then fail(message)end end,"Gold")
  else local b=action("Locked",function()end,"Navy",true);b.Active=false;if mobile then b.Visible=false end end
 end
 local function copyCard(p,y,w,mobile,pf)
  local copy=pf.Copy or{Followers={}}
  local cc=card(p,"CopyTrading",0,y,w,100,Color3.fromRGB(10,52,140),Color3.fromRGB(4,26,78),copy.Enabled and C.Cyan or C.Border,false)
  local pad=mobile and 14 or 20;local iw=w-pad*2;local yy=pad-4
  sidebarImage(cc,"Positions",pad-4,yy-2,30)
  sidebarText(cc,"Title","Copy trading",pad+32,yy,iw-110,28,20)
  chip(cc,"State",copy.Enabled and"ON"or"OFF",w-pad-50,yy+3,copy.Enabled and C.Green or C.Muted,50)
  yy+=36
  local intro=text(cc,"Intro","Trade one account and optionally copy its trades to your other funded accounts.",pad,yy,iw,mobile and 34 or 20,12,C.Text,M)
  intro.TextWrapped=true;yy+=mobile and 40 or 28
  if not pf.CopyAvailable then
   local t=text(cc,"Unavailable","Available after you activate a second funded account. Copying stays off until you turn it on.",pad,yy,iw,34,11,C.Muted)
   t.TextWrapped=true;yy+=40
   cc.Size=UDim2.fromOffset(w,yy+pad-6);return yy+pad-6
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
  sidebarText(cc,"LeadLabel","LEAD ACCOUNT · you trade this one",pad,yy,iw,18,12,SB.Muted);yy+=22
  for i,row in ipairs(actives)do
   local selected=draft.Leader==row.Key
   gameControl(button(cc,"Lead"..row.Key,row.Short,pad+(i-1)*(bw+8),yy,bw,38,function()draft.Leader=row.Key;draft.Followers[row.Key]=nil;edit()end,C.Raised,C.Text,15),selected)
  end
  yy+=48
  sidebarText(cc,"FollowLabel","FOLLOWERS · receive copies of new lead orders",pad,yy,iw,18,12,SB.Muted);yy+=22
  local index=0
  for _,row in ipairs(actives)do
   if row.Key~=draft.Leader then
    local on=draft.Followers[row.Key]==true
    local b=glossy(button(cc,"Follow"..row.Key,(on and"✓ "or"")..row.Short,pad+index*(bw+8),yy,bw,38,function()draft.Followers[row.Key]=(not on)or nil;edit()end,C.Raised,C.Text,15),on and"Cyan"or"Navy")
    if fx then fx:Selected(b,on)end
    index+=1
   end
  end
  yy+=48
  sidebarText(cc,"SizingLabel","COPY SIZE",pad,yy,iw,18,12,SB.Muted);yy+=22
  local sw=mobile and iw or math.min(iw,460)
  for i,opt in ipairs({{"Same","Same quantity"},{"Proportional","Scale by account size"}})do
   gameControl(button(cc,opt[1],opt[2],pad+(i-1)*(sw+8)/2,yy,(sw-8)/2,40,function()draft.Sizing=opt[1];edit()end,C.Raised,C.Text,14),draft.Sizing==opt[1])
  end
  yy+=52
  local rules=text(cc,"Rules","Copies use each account's own funds and risk limits, so some can be skipped or rejected; every order shows a copy report. Turning copying off never closes positions: each account keeps what it holds and trades on its own.",pad,yy,iw,mobile and 70 or 34,11,Color3.fromRGB(190,214,250))
  rules.TextWrapped=true;rules.TextYAlignment=Top;yy+=mobile and 76 or 42
  local followers={}for _,row in ipairs(actives)do if draft.Followers[row.Key]and row.Key~=draft.Leader then table.insert(followers,row.Key)end end
  local function apply(enabled)local ok,message=session:Copy(enabled,draft.Leader,followers,draft.Sizing);if not ok then fail(message)end end
  local bw2=mobile and(iw-8)/2 or 220
  if copy.Enabled then
   glossy(button(cc,"UpdateCopy","Save changes",pad,yy,bw2,46,function()apply(true)end,C.Raised,C.Text,16),"Purple")
   glossy(button(cc,"DisableCopy","Turn off copying",pad+bw2+8,yy,bw2,46,function()apply(false)end,C.Raised,C.Text,16),"Navy").Border.Color=C.Cyan
  else
   local can=#followers>0
   local b=glossy(button(cc,"EnableCopy",can and"Turn on copying"or"Choose a follower",pad,yy,mobile and iw or 260,46,function()if can then apply(true)else fail("Choose at least one follower account.")end end,C.Raised,C.Text,16),can and"Purple"or"Navy")
   if not can then b.ControlLabel.TextColor3=C.Muted end
  end
  yy+=56
  local last=s.LastCopy
  if last then
   text(cc,"LastCopy",string.format("Last copy · %s lead · %d copied · %d skipped · %d rejected",last.Leader,last.Copied,last.Skipped,last.Rejected),pad,yy,iw,16,10,last.Rejected>0 and SC.Red or C.Muted,N).TextTruncate=AtEnd
   yy+=24
  end
  cc.Size=UDim2.fromOffset(w,yy+pad-10)
  return yy+pad-10
 end
 local KPI_LOOK={
  Capital={Color3.fromRGB(0,171,255),Color3.fromRGB(0,91,230),Color3.fromRGB(17,211,255),"Balance"},
  Earned={Color3.fromRGB(0,216,107),Color3.fromRGB(0,145,100),Color3.fromRGB(10,245,134),"Unrealized"},
  Open={Color3.fromRGB(137,57,255),Color3.fromRGB(78,31,220),Color3.fromRGB(183,105,255),"Equity"},
  Copy={Color3.fromRGB(10,60,150),Color3.fromRGB(4,30,86),C.Cyan,nil},
 }
 local function dashboard(x,y,w,h,mobile)
  local pf=session.Portfolio or{Accounts={},Legacy={},Earned=0,Capital=0,Open=0,ActiveCount=0,Copy={Enabled=false,Followers={}}}
  local sc=make("ScrollingFrame","Dashboard",canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,
   ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,ScrollingDirection=Enum.ScrollingDirection.Y})
  local cw=w-(mobile and 6 or 14);local gap=mobile and 10 or 14;local yy
  local narrow=mobile and w<600 -- phone portrait stacks; landscape uses the wide header and KPI row
  local primary=pf.Active and"Continue Trading  →"or"Start a Funded Account"
  local function continueTrading()if pf.Active then goTrade()else startFunded()end end
  local function primaryButton(bx,by,bw,bh)
   local b=glossy(button(sc,"ContinueTrading",primary,bx,by,bw,bh,continueTrading,C.Raised,C.Text,narrow and 19 or 22),"Purple")
   b.Corners.CornerRadius=UDim.new(0,16);b.Border.Thickness=3
   return b
  end
  if narrow then
   sidebarText(sc,"Title","Funded accounts",0,0,cw,34,26)
   text(sc,"Subtitle","Trade · earn realized profit · unlock more capital",0,34,cw,18,11,SB.Muted,M)
   primaryButton(0,58,cw,56)
   text(sc,"Resume",pf.Active and("Resume "..(pf.ActiveName or""))or"Your practice accounts are kept below.",0,118,cw,16,10,SB.Muted,M,CENTER)
   yy=144
  else
   sidebarText(sc,"Title","Funded accounts",0,0,cw-300,40,34)
   text(sc,"Subtitle","Start → Trade → Earn → Unlock → Scale  ·  simulated capital, virtual funds",0,42,cw-300,20,12,SB.Muted,M).TextTruncate=AtEnd
   primaryButton(cw-270,2,270,58)
   text(sc,"Resume",pf.Active and("Resume "..(pf.ActiveName or""))or"Starts with "..whole(Ladder.Tiers[1].Size).." of simulated capital",cw-270,64,270,16,10,SB.Muted,M,CENTER)
   yy=92
  end
  local copy=pf.Copy or{Followers={}}
  local copyCaption=copy.Enabled and(tierShort(copy.Leader).." leads · "..#copy.Followers.." following")or(pf.CopyAvailable and"Off · ready when you are"or"Needs a 2nd funded account")
  local count=pf.ActiveCount or 0
  local kpis={
   {"Capital","ACTIVE FUNDED CAPITAL",whole(pf.Capital or 0),"Provided capital · "..count.." account"..(count==1 and""or"s"),C.Text},
   {"Earned","NET REALIZED PROFIT",Market.Signed(pf.Earned or 0),"Closed trades · counts toward unlocks",(pf.Earned or 0)>=0 and C.Text or SC.Red},
   {"Open","OPEN P&L",Market.Signed(pf.Open or 0),"Not counted until you close",(pf.Open or 0)>=0 and SC.Green or SC.Red},
   {"Copy","COPY TRADING",copy.Enabled and"On"or"Off",copyCaption,copy.Enabled and SC.Green or C.Text},
  }
  local cols=narrow and 2 or 4;local kw=(cw-gap*(cols-1))/cols;local kh=mobile and 86 or 108
  for i,k in ipairs(kpis)do
   local col,r=(i-1)%cols,math.floor((i-1)/cols)
   local look=KPI_LOOK[k[1]]
   local tile=card(sc,"Kpi"..k[1],col*(kw+gap),yy+r*(kh+gap),kw,kh,look[1],look[2],look[3],false)
   local ix=12
   if look[4]and not mobile and kw>=230 then summaryIcon(tile,look[4],10,(kh-58)/2,58);ix=76 end
   summaryText(tile,"Label",k[2],ix,mobile and 8 or 12,kw-ix-12,18,mobile and 11 or 13,C.Text,mobile).TextXAlignment=Enum.TextXAlignment.Left
   local v=summaryText(tile,"Value",k[3],ix,mobile and 28 or 34,kw-ix-12,mobile and 28 or 36,mobile and 20 or 30,k[5],mobile);v.TextXAlignment=Enum.TextXAlignment.Left
   local caption=text(tile,"Caption",k[4],ix,mobile and 58 or 76,kw-ix-12,mobile and 22 or 18,mobile and 9 or 10,Color3.fromRGB(235,245,255),M);caption.TextWrapped=mobile;caption.TextTruncate=AtEnd;caption.ZIndex=6
  end
  yy+=math.ceil(#kpis/cols)*(kh+gap)
  local cardH=mobile and(pf.Started and 124 or 166)or 118
  local prog=card(sc,"NextUnlock",0,yy,cw,cardH,Color3.fromRGB(255,214,40),Color3.fromRGB(255,150,0),Color3.fromRGB(255,244,98),not mobile)
  prog.Border.Thickness=4
  local tx=20;local amountW=mobile and 130 or 220
  if not mobile then summaryIcon(prog,"Trophy",12,(cardH-86)/2,86);tx=108 end
  local tw=cw-tx-20
  if not pf.Started then
   summaryText(prog,"Eyebrow","YOUR FUNDED JOURNEY",tx,12,tw,20,14,C.Text,mobile).TextXAlignment=Enum.TextXAlignment.Left
   summaryText(prog,"Title","Start with a "..whole(Ladder.Tiers[1].Size).." funded account",tx,32,mobile and tw or tw-280,32,mobile and 18 or 26,C.Text,mobile).TextXAlignment=Enum.TextXAlignment.Left
   progressBar(prog,"Progress",tx,72,mobile and tw or tw-280,10,0,C.Blue)
   text(prog,"Remaining","Your earlier practice accounts are kept below. They don't count toward unlocks.",tx,90,mobile and tw or tw-280,mobile and 28 or 18,mobile and 10 or 11,SC.Ink,M).TextWrapped=true
   local start=glossy(button(prog,"StartFunded","Start a Funded Account",mobile and tx or cw-280,mobile and 120 or 36,mobile and tw or 260,44,startFunded,C.Raised,C.Text,16),"Purple")
   start.Corners.CornerRadius=UDim.new(0,14)
  elseif pf.Next then
   summaryText(prog,"Eyebrow",pf.Next.Milestone and "TOP-TIER GOAL" or "NEXT UNLOCK",tx,12,tw,20,14,C.Text,mobile).TextXAlignment=Enum.TextXAlignment.Left
   summaryText(prog,"Title",pf.Next.Name,tx,32,tw-amountW,34,mobile and 19 or 28,C.Text,mobile).TextXAlignment=Enum.TextXAlignment.Left
   local amount=summaryText(prog,"Amount",whole(pf.Next.Progress).." / "..whole(pf.Next.Goal),cw-20-amountW,32,amountW,34,mobile and 16 or 24,C.Text,mobile);amount.TextXAlignment=RIGHT
   progressBar(prog,"Progress",tx,74,tw,10,math.clamp((pf.Next.Progress or 0)/pf.Next.Goal,0,1),C.Blue)
   text(prog,"Remaining",whole(pf.Next.Remaining).." more net realized profit to go. Starting balances and open P&L don't count.",tx,92,tw,mobile and 28 or 18,mobile and 10 or 11,SC.Ink,M).TextWrapped=true
  else
   summaryText(prog,"Eyebrow","LADDER COMPLETE",tx,12,tw,20,14,C.Text,mobile).TextXAlignment=Enum.TextXAlignment.Left
   summaryText(prog,"Title","Top-tier milestone complete",tx,32,tw,34,mobile and 19 or 28,C.Text,mobile).TextXAlignment=Enum.TextXAlignment.Left
   progressBar(prog,"Progress",tx,74,tw,10,1,C.Green)
   text(prog,"Remaining","Net realized profit "..Market.Signed(pf.Earned or 0)..". Scale with copy trading across your accounts.",tx,92,tw,mobile and 28 or 18,mobile and 10 or 11,SC.Ink,M).TextWrapped=true
  end
  yy+=cardH+gap+8
  sidebarText(sc,"LadderTitle","Account ladder",0,yy,cw,28,mobile and 19 or 22)
  if not mobile then text(sc,"LadderNote","Unlocked by lifetime net realized profit across your funded accounts",0,yy,cw,28,11,SB.Muted,M,RIGHT)end
  yy+=36
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
   sidebarText(sc,"LegacyTitle","Legacy practice accounts",0,yy,cw,28,mobile and 18 or 20);yy+=30
   local note=text(sc,"LegacyNote","Kept exactly as they were before funded accounts. Still tradable, but never counted toward unlocks or funded capital.",0,yy,cw,mobile and 44 or 18,11,SB.Muted,M)
   note.TextWrapped=true;yy+=mobile and 50 or 26
   for _,row in ipairs(pf.Legacy)do
    local current=pf.Active==row.Key
    local lc=card(sc,"Legacy"..row.Key,0,yy,cw,70,Color3.fromRGB(10,44,118),Color3.fromRGB(4,24,70),current and C.Blue or C.Border,false)
    sidebarText(lc,"Name",row.Name..(row.Breached and"  ·  depleted"or""),16,8,cw-190,28,18,row.Breached and SC.Red or C.Text).TextTruncate=AtEnd
    text(lc,"Detail",Market.Money(row.Balance or 0).." · realized "..Market.Signed(row.Realized or 0).." · "..(row.Positions or 0).." open",16,38,cw-190,20,11,Color3.fromRGB(214,234,255),N).TextTruncate=AtEnd
    local b=glossy(button(lc,"Action",current and"Trading now  →"or"Trade",cw-160,14,144,42,function()if current then goTrade()else account(row.Key)end end,C.Raised,C.Text,15),current and"Purple"or"Cyan")
    b.Corners.CornerRadius=UDim.new(0,12)
    yy+=80
   end
  end
  text(sc,"Footnote","Simulated prop-firm journey · all capital, prices and profits are virtual",0,yy,cw,mobile and 32 or 20,10,C.Muted,F,CENTER).TextWrapped=true;yy+=mobile and 40 or 28
  sc.CanvasSize=UDim2.fromOffset(0,yy)
  if s.Focus=="Copy"then s.Focus=nil;task.defer(function()if sc.Parent then sc.CanvasPosition=Vector2.new(0,math.max(0,copyY-12))end end)end
 end
 local coachSteps={
  {"Pick an instrument","Open the contract list and choose a market. ES, the E-mini S&P 500, is a good first pick.",
   {Desktop={"OrderTicket.Fields.ContractSelector"},Mobile={"Chart.Header.ContractSelector"}}},
  {"Set your size","Use − and + to choose how many contracts. Start with 1: your %s account starts with %s equity. It fails only when equity is depleted.",
   {Desktop={"OrderTicket.Fields.Quantity"},Mobile={"TradeDock.Quantity"}}},
  {"Place a trade","BUY if you expect the price to rise, SELL if you expect it to fall. Your stop loss and take profit attach automatically.",
   {Desktop={"OrderTicket.OrderActions.BuyLong","OrderTicket.OrderActions.SellShort","OrderTicket.Fields.BuyLong","OrderTicket.Fields.SellShort"},Mobile={"TradeDock.BuyLong","TradeDock.SellShort"}}},
  {"Close your position","When you're ready, close it. Closing turns open P&L into realized profit or loss, and closed profits minus losses count toward unlocks.",
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
  local pulse=TweenService:Create(edge,TweenInfo.new(.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.65})
  if fx then fx:Loop(pulse)else pulse:Play()end
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
   local nextText=pf.Next and("Next objective: earn "..whole(pf.Next.Remaining).." more net realized profit for "..pf.Next.Name..".")or""
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
  local card=frame(canvas,"Coach",x,y,cw,ch,Color3.new(1,1,1),38);round(card,16);stroke(card,C.Cyan).Thickness=3
  tint(card,Color3.fromRGB(122,56,245),Color3.fromRGB(58,22,176))
  sidebarText(card,"Step","GUIDED FIRST TRADE · "..s.Coach.." OF "..#coachSteps,14,6,cw-124,18,11,Color3.fromRGB(236,227,255))
  local skip=glossy(button(card,"SkipTour",s.Coach==5 and"Close"or"Skip tour",cw-98,6,88,26,function()finishCoach(s.Coach~=5)end,C.Raised,C.Text,12,39),"Navy")
  skip.Border.Color=C.Cyan
  sidebarText(card,"Title",title,14,24,cw-28,26,mobile and 16 or 19).TextTruncate=AtEnd
  local t=text(card,"Body",body,14,52,cw-(hasButton and 138 or 28),ch-58,mobile and 11 or 12,Color3.fromRGB(236,232,255),M);t.TextWrapped=true;t.TextYAlignment=Top
  if s.Coach<=2 then glossy(button(card,"CoachNext","Next  →",cw-104,ch-44,92,36,function()s.Coach+=1;refresh()end,C.Raised,C.Text,15,39),"Cyan")end
  if s.Coach==5 then glossy(button(card,"FinishTour","Keep trading",cw-130,ch-46,118,38,function()finishCoach(false)end,C.Raised,C.Text,15,39),"Green")end
  local targets=step[3][mobile and"Mobile"or"Desktop"]
  if s.Coach==4 and mobile then
   local key;for _,k in ipairs(Market.PositionOrder)do if session.Positions[k]then key=k break end end
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
  local completed=event.Kind=="Completed"
  local cw=math.min(460,w-24);local ch=unlocked and 166 or 124;local ty=mobile and 66 or 24
  local old=root:FindFirstChild("Celebration");if old then old:Destroy()end
  local card=make("CanvasGroup","Celebration",root,{Size=UDim2.fromOffset(cw,ch),Position=UDim2.fromOffset((w-cw)/2,ty-28),BackgroundColor3=Color3.new(1,1,1),
   BorderSizePixel=0,GroupTransparency=1,ZIndex=80})
  round(card,18);local edge=stroke(card,Color3.fromRGB(255,244,98));edge.Thickness=3
  tint(card,Color3.fromRGB(150,70,255),Color3.fromRGB(70,26,200))
  local badge=make("ImageLabel","Badge",card,{Position=UDim2.fromOffset(10,14),Size=UDim2.fromOffset(60,60),BackgroundTransparency=1,
   Image=unlocked and summaryThemes.Trophy.Image or summaryThemes.Unrealized.Image,ScaleType=Enum.ScaleType.Fit,ZIndex=81})
  local eyebrow=sidebarText(card,"Eyebrow",completed and "TOP TIER COMPLETE" or unlocked and"ACCOUNT UNLOCKED"or"FIRST PROFIT",78,12,cw-124,20,13,Color3.fromRGB(255,228,80));eyebrow.ZIndex=82
  local title=sidebarText(card,"Title",completed and "You completed the ladder!" or unlocked and(event.Name.." is ready")or(Market.Signed(event.Pnl or 0).." realized"),78,32,cw-110,30,22);title.ZIndex=82;title.TextTruncate=AtEnd
  local message=completed and "Your final $40,000 stage goal is complete. Keep trading across your funded accounts." or unlocked and("You reached the "..whole(event.Unlock).." net realized profit milestone. Activating adds "..whole(event.Size).." of simulated funded capital, separate from the profit you earned.")
   or"Your first trade closed in profit. Realized profit is what unlocks larger funded accounts."
  local body=text(card,"Body",message,78,64,cw-94,unlocked and 54 or 48,12,Color3.fromRGB(236,232,255),M,nil,81);body.TextWrapped=true;body.TextYAlignment=Top
  local done=false
  local function dismiss()
   if done then return end;done=true
   if not card.Parent then celebrating=false;return end
   local out=TweenService:Create(card,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{GroupTransparency=1,Position=card.Position-UDim2.fromOffset(0,18)})
   out.Completed:Connect(function()card:Destroy();celebrating=false;task.delay(.25,showNextCelebration)end);out:Play()
  end
  dismissButton(card,cw-42,10,32,dismiss,83)
  if unlocked then
   glossy(button(card,"ActivateNow","Activate "..event.Short,78,ch-48,160,38,function()
    local ok,reason=session:Activate(event.Tier);if not ok then fail(reason)end;dismiss()
   end,C.Raised,C.Text,15,82),"Gold")
   glossy(button(card,"Later","Later",246,ch-48,84,38,dismiss,C.Raised,C.Text,15,82),"Navy").Border.Color=C.Cyan
  end
  for i=1,14 do
   local angle=i/14*math.pi*2
   local spark=frame(card,"Spark",40,44,4,10,i%2==0 and Color3.fromRGB(255,228,80)or C.Cyan,83);spark.Rotation=math.deg(angle)+90;round(spark,2)
   TweenService:Create(spark,TweenInfo.new(.95,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
    {Position=UDim2.fromOffset(40+math.cos(angle)*48,44+math.sin(angle)*48),BackgroundTransparency=1,Rotation=math.deg(angle)+180}):Play()
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
  local card=make("CanvasGroup","CopyReport",root,{Size=UDim2.fromOffset(cw,ch),Position=UDim2.fromOffset((w-cw)/2,(mobile and 62 or 30)+64),
   BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,GroupTransparency=1,ZIndex=70})
  round(card,14);stroke(card,report.Rejected>0 and C.Red or C.Cyan).Thickness=3
  tint(card,Color3.fromRGB(8,60,156),Color3.fromRGB(3,28,80))
  sidebarText(card,"Header","COPY REPORT · "..report.Leader.." LEAD",14,6,cw-190,22,13).ZIndex=71
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
 local function leaderboardScreen(x,y,w,h,mobile)
  LeaderboardView.Draw({Canvas=canvas,C=C,frame=frame,text=text,round=round,stroke=stroke,tint=tint,heading=sidebarText,
   button=button,gloss=glossy,icon=function(p,kind,xx,yy,size)summaryIcon(p,kind,xx,yy,size)end,money=Market.Signed},x,y,w,h,mobile,leaderboard)
 end
 local function mobileScreen(w,h,sum,screen)
  local compact=w>h;local dense=h<650 and not compact
  local head=dense and 48 or 60;local navH=dense and 52 or 58;local dockH=dense and 152 or 190
  if compact and screen=="Leaderboard"then head=0;navH=48 end
  local board=screen=="Dashboard"or screen=="Leaderboard"
  local layout={Head=head,NavH=navH,Compact=compact}
  local top=frame(canvas,"TopNavigation",0,0,w,head,C.Bg)
  if head==0 then top.Visible=false end
  local acc=button(top,"Account","",12,0,w-70,head,function()s.Overlay="Account";refresh()end,false)
  -- Trading header: active account (tap to switch) and the next objective with a slim progress line.
  local title=sidebarText(acc,"Name",board and'Get <font color="#FFD336">Funded!</font>'or(accountName().."  ⌄"),0,dense and 0 or 3,w-70,dense and 26 or 30,dense and 20 or 22)
  title.RichText=true;title.TextXAlignment=Enum.TextXAlignment.Left
  local brand=text(acc,"Brand",board and"Funded accounts · simulated capital"or mobileBadge(),0,dense and 27 or 34,w-70,dense and 17 or 20,9,C.Muted);brand.TextTruncate=AtEnd
  if compact and screen=="Leaderboard"then brand.Visible=false end
  if not board then local _,_,progress=objective();progressBar(top,"ObjectiveBar",12,head-4,w-24,3,progress,C.Green)end
  local more=glossy(button(top,"More","···",w-54,6,44,40,function()s.Overlay="Menu";refresh()end,C.Raised,C.Text,20),"Navy")
  more.Border.Color=C.Cyan;more:SetAttribute("Sound","None")
  if screen=="Leaderboard"then
   leaderboardScreen(12,head+6,w-24,h-head-navH-12,true)
  elseif board then
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
  local nx=compact and not board and w-math.min(300,w*.39)-12 or 0;local nw=w-nx
  local navigation=frame(canvas,"MobileNavigation",nx,h-navH,nw,navH,SB.Navy,25);rule(navigation,0,0,nw,SB.Cyan)
  nav(navigation,0,0,nw,navH,true)
  if s.Sheet then
   local sw=compact and math.min(390,w-30)or w
   local sh=math.min(h-54,s.Sheet=="Activity"and 350 or s.Type=="Limit"and 540 or 475)
   local sx=w-sw;local sy=h-sh
   button(canvas,"SheetBackdrop","",0,0,w,h,function()s.Sheet=false;refresh()end,C.Bg,C.Text,12,30).BackgroundTransparency=.3
   local sheet=frame(canvas,"OptionsSheet",sx,sy,sw,sh+20,Color3.new(1,1,1),31);round(sheet,20)
   stroke(sheet,Color3.fromRGB(4,221,255)).Thickness=3;tint(sheet,Color3.fromRGB(8,60,156),Color3.fromRGB(3,28,80))
   local grip=frame(sheet,"Grip",sw/2-22,6,44,5,Color3.fromRGB(120,190,255),32);grip.BackgroundTransparency=.3;round(grip,3)
   sidebarText(sheet,"Title",s.Sheet=="Activity"and"Activity"or"Order settings",16,4,sw-100,44,19).ZIndex=33
   local done=glossy(button(sheet,"Done","Done",sw-86,7,74,36,function()s.Sheet=false;refresh()end,C.Raised,C.Text,15,33),"Purple")
   done.Corners.CornerRadius=UDim.new(0,12);rule(sheet,0,48,sw,C.Cyan)
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
  if s.Screen=="Leaderboard"then return "Leaderboard"end
  if options.Preview then return "Trade"end
  local pf=session.Portfolio
  if not pf then return "Loading"end
  if pf.New then s.Screen=nil;return "Welcome"end
  if not pf.Active then s.Screen="Dashboard"end
  s.Screen=s.Screen or"Dashboard"
  return s.Screen
 end
 local lastPopup
 local popupParts={"OverlayBackdrop","Dialog","ProtectionDialog","SheetBackdrop","OptionsSheet"}
 local function popupKey()
  if s.Overlay then return"O:"..s.Overlay..(s.Overlay=="Info"and tostring(s.Info)or"")end
  if s.Sheet then return"S:"..tostring(s.Sheet)end
 end
 local function renderNow()
  if not alive or not root.Parent then return end
  if chartView:Busy()then fullRefreshPending=true;return end
  local size=root.AbsoluteSize;local w=size.X>0 and size.X or 1440;local h=size.Y>0 and size.Y or 900;lastW=w;lastH=h
  local scroll={}
  for _,v in ipairs(canvas:GetDescendants())do if v:IsA("ScrollingFrame")then scroll[v:GetFullName()]=v.CanvasPosition end end
  -- A popup that just closed (or was replaced) fades out from a separate layer instead of vanishing.
  local key=popupKey()
  if fx then
   fx:StopLoops()
   if lastPopup and key~=lastPopup then
    local items={}
    for _,name in ipairs(popupParts)do local o=canvas:FindFirstChild(name);if o then table.insert(items,o)end end
    fx:Ghost(items)
   end
  end
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
  elseif screen=="Leaderboard"then s.Nav="Leaderboard"
  else s.Nav="Accounts"end
  leaderboard:SetVisible(screen=="Leaderboard")
  if screen=="Welcome"then welcome(w,h)
  elseif screen=="Loading"then loading(w,h)
  elseif mobile then layout=mobileScreen(w,h,sum,screen)
  else
   local railW=w<1150 and 180 or w<1550 and 220 or 256;local gap=16
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
   local navH=h>=860 and 56 or h>=710 and 44 or 36
   nav(rail,12,118,rw-24,navH,false)
   local marketY=118+6*(navH+9)+10
   local marketH=h>=900 and 42 or 34
   if marketY+29+4*(marketH+8)<rh-124 and screen=="Trade"then
    sidebarText(rail,"Markets","YOUR MARKETS",14,marketY,rw-28,22,14,SB.Muted)
    for i,key in ipairs(Market.ContractOrder)do
     local selected=key==s.Contract
     local b=button(rail,"Market"..key,"",12,marketY+29+(i-1)*(marketH+8),rw-24,marketH,function()selectContract(key)end,Color3.new(1,1,1),C.Text,12,3)
     sidebarSurface(b,selected,true);if fx then fx:Selected(b,selected)end
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
   if screen=="Leaderboard"then
    leaderboardScreen(cx,22,usable,h-34,false)
   elseif screen=="Dashboard"then
    dashboard(cx,22,usable,h-34,false)
   else
    local summaryH=math.clamp(usable*.135,166,h>=800 and 226 or 176)
    accountCards(cx,22,usable,summaryH,false)
    local contentY=22+summaryH+16
    local ay=h-math.clamp(h*.2,152,206)-12
    chart(cx,contentY,cw,ay-contentY-16,false,false,false)
    ticket(cx+cw+gap,contentY,tw,h-contentY-12)
    activity(cx,ay,cw,h-ay-12,false,false)
    layout={Activity={cx,ay,cw,h-ay-12}}
   end
  end
  if screen=="Trade"and layout then coach(w,h,mobile,layout)end
  overlay(w,h)
  if fx and key and key~=lastPopup then
   local dialog;for _,name in ipairs({"Dialog","ProtectionDialog","OptionsSheet"})do dialog=dialog or canvas:FindFirstChild(name)end
   fx:Open(dialog,canvas:FindFirstChild("OverlayBackdrop")or canvas:FindFirstChild("SheetBackdrop"),dialog and dialog.Name=="OptionsSheet"and not(w>h))
   fx:Accent("Open")
  end
  lastPopup=key
  if s.Toast then toastView(w,h,mobile)end
  root:SetAttribute("Layout",mobile and"Mobile"or"Desktop");root:SetAttribute("SelectedContract",s.Contract)
  local pf=session.Portfolio
  root:SetAttribute("Screen",screen);root:SetAttribute("CoachStep",s.Coach);root:SetAttribute("ActiveAccount",pf and pf.Active)
  root:SetAttribute("NetRealized",pf and pf.Earned);root:SetAttribute("CopyEnabled",pf and pf.Copy and pf.Copy.Enabled or false)
  root:SetAttribute("Theme","Colorful Game")
  root:SetAttribute("Balance",sum.Balance);root:SetAttribute("Equity",sum.Equity);root:SetAttribute("UnrealizedPnL",sum.Unrealized)
  root:SetAttribute("PositionCount",sum.Count);root:SetAttribute("WorkingOrderCount",#session:Working());root:SetAttribute("Simulated",true);root:SetAttribute("SessionSeed",nil);root:SetAttribute("MarketStep",session.Step or 0)
  root:SetAttribute("ExchangeStatus",session.ConnectionStatus or "EDIT PREVIEW")
  root:SetAttribute("EditPreview",options.Preview==true)
  runEffects()
 end
 render=function()
  local ok,err=xpcall(renderNow,debug.traceback)
  if not ok then
   -- Keep the workspace usable: the next refresh rebuilds everything from state.
   painting=nil;warn("[Get Funded!] Workspace render failed; it will rebuild on the next update: "..tostring(err))
   root:SetAttribute("RenderError",tostring(err):sub(1,200))
  end
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
   leaderboard:Step()
   chartView:Step(dt)
   -- Input, easing and network batches share one paint per display frame.
   if chartView.Dirty or chartView.HoverDirty then repaintChart()end
   if RunService:IsStudio()and paintElapsed>=1 then
    paintElapsed=0;root:SetAttribute("ChartPaintCount",chartView.PaintCount)
    root:SetAttribute("ChartPaintMeanMs",chartView.PaintTotal/math.max(1,chartView.PaintCount));root:SetAttribute("ChartPaintMaxMs",chartView.PaintMax)
    root:SetAttribute("ChartPaintLastMs",chartView.LastCost)
    root:SetAttribute("ChartOverlayPaintCount",chartView.OverlayPaintCount or 0)
    root:SetAttribute("ChartOverlayMeanMs",(chartView.OverlayPaintTotal or 0)/math.max(1,chartView.OverlayPaintCount or 0))
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
   if currentScreen()=="Leaderboard"then return end
   local cancelled=chartView:OnMarketUpdate()
   if cancelled then toast(cancelled)end
   if coachProgress()then refresh()end
   local screen=currentScreen()
   local signature=screen..":"..tostring(session.AccountKey)..":"..tostring(session.CanTrade)..":"..#session.Orders..":"..#session.History..":"..portfolioSignature()
   for _,key in ipairs(Market.PositionOrder)do
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
    if kpi then kpi.Value.Text=Market.Signed(pf.Open or 0);kpi.Value.TextColor3=(pf.Open or 0)>=0 and SC.Green or SC.Red end
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
    for _,key in ipairs(Market.PositionOrder)do local p=session.Positions[key];if p then index+=1
     local row=activityPanel:FindFirstChild("Row"..index,true);local label=row and(row:FindFirstChild("Pnl")or row:FindFirstChild("Cell5"))
     if label then label.Text=Market.Signed(session:Pnl(p));label.TextColor3=session:Pnl(p)>=0 and C.Green or C.Red end
    end end
   end
   root:SetAttribute("ExchangeStatus",session.ConnectionStatus or "CONNECTING")
   root:SetAttribute("Balance",sum.Balance);root:SetAttribute("Equity",sum.Equity);root:SetAttribute("UnrealizedPnL",sum.Unrealized)
   root:SetAttribute("MarketStep",session.Step or 0)
  end
  table.insert(connections,session.Changed.Event:Connect(marketUpdate))
  table.insert(connections,session.Replies.Event:Connect(function(reply)
   chartView:OnReply(reply)
   s.Error=not reply.Ok and reply.Message or nil
   -- Server-confirmed feedback. Rejections are always audible; confirmations only for real actions.
   local order=s.PendingOrder and reply.RequestId==s.PendingOrder.Id and s.PendingOrder
   local closing=s.PendingClose and reply.RequestId==s.PendingClose.Id and s.PendingClose
   if order then s.PendingOrder=nil end
   if closing then s.PendingClose=nil end
   if fx and reply.Kind~="Flag"then
    if not reply.Ok then
     fx:Play("Error")
     if order then effect(order.Direction>0 and tradePaths or sellPaths,"Error")end
    elseif order then
     fx:Play("Success");effect(order.Direction>0 and tradePaths or sellPaths,"Success",order.Direction>0 and C.Buy or C.Sell)
    elseif closing or reply.Kind=="Start"or reply.Kind=="Activate"or reply.Kind=="Restart"then fx:Play("Success")
    elseif reply.Kind=="Cancel"or reply.Kind=="Copy"or reply.Kind=="AmendProtection"then fx:Play("Select")end
   end
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
   if reply.Kind~="Flag"or not reply.Ok then toast(reply.Message,not reply.Ok and"error"or(order or closing)and"success"or"info")else refresh()end
  end))
  table.insert(connections,session.Events.Event:Connect(function(event)if fx then fx:Play("Milestone")end;celebrate(event);refresh()end))
 end
 table.insert(connections,leaderboard.Changed.Event:Connect(refresh))
 render()
 -- Studio-only layout/test hook: read or set presentation state and rebuild synchronously.
 if RunService:IsStudio()and not options.Preview then
  local hook=Instance.new("BindableFunction");hook.Name="UIDiagnostics";hook.Parent=root
  hook.OnInvoke=function(command,key,value)
   if command=="Set"then s[key]=value;render();return true
   elseif command=="Get"then return s[key]
   elseif command=="Render"then render();return true end
   return nil
  end
 end
 local controller={Root=root,State=s,Chart=chartView}
 function controller:Destroy()alive=false;leaderboard:Destroy();chartView:Destroy();session:Destroy();if feedback then feedback:Destroy()end;if fx==feedback then fx=nil end;for _,c in ipairs(connections)do c:Disconnect()end;if root.Parent then root:Destroy()end end
 return controller
end
return UI
