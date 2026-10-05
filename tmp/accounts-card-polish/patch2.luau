local P={}
P[1]={From=[==[-- Flat account rows (Accounts card and copy editor): one clean rim and a soft shine, no lower edge.]==],To=[==[function UI.Mount(gui,options)]==],New=[==[-- Flat account rows (Accounts card and copy editor): one clean rim, no shine strip or lower edge.
local ROW_LOOK={
 Purple={Color3.fromRGB(156,72,255),Color3.fromRGB(92,30,228),Color3.fromRGB(171,102,255)},
 Cyan={Color3.fromRGB(0,176,255),Color3.fromRGB(0,100,230),Color3.fromRGB(64,222,255)},
 Navy={Color3.fromRGB(6,48,122),Color3.fromRGB(3,29,82),Color3.fromRGB(26,88,186)},
}
local function rowSurface(b,variant,radius,edge)
 local look=ROW_LOOK[variant]or ROW_LOOK.Navy
 b.Corners.CornerRadius=UDim.new(0,radius)
 b.Border.Color=look[3];b.Border.Thickness=edge or 2
 tint(b,look[1],look[2])
end
]==]}
P[2]={From=[==[    else
     local cash=summaryIcon(b,"Balance",nx,(rowH-marker)/2,marker);cash.ZIndex=9
    end]==],To=[==[]==],New=[==[    elseif mobile then
     -- A tiny cash icon reads as noise at phone size; an outlined marker keeps the names aligned.
     local ring=frame(b,"Marker",nx+(marker-7)/2,(rowH-7)/2,7,7,Color3.new(1,1,1),9);ring.BackgroundTransparency=1
     round(ring,4);stroke(ring,Color3.fromRGB(120,170,240)).Thickness=1
    else
     local cash=summaryIcon(b,"Balance",nx,(rowH-marker)/2,marker);cash.ZIndex=9
    end]==]}
P[3]={From=[==[  local iconSize=math.min(52,headH-16);local tx=16]==],To=[==[]==],New=[==[  local iconSize=plain and(narrow and 38 or 48)or math.min(52,headH-16);local tx=16]==]}
P[4]={From=[==[  local tw=pw-18-tx-closeSize-22]==],To=[==[]==],New=[==[  local tw=pw-18-tx-closeSize-(plain and 14 or 22)]==]}
P[5]={From=[==[   -- The ON/OFF pill follows the title text instead of crowding the close button.]==],To=[==[   local contentH=copyPanel(p,pad,0,iw,narrow,pf,p.Size.Y.Offset-6)+6]==],New=[==[   -- The ON/OFF pill follows the title; on narrow phones the title shrinks instead of wrapping.
   local font=Enum.Font.FredokaOne
   local stateH=narrow and 24 or 28;local labelSize=narrow and 13 or 15
   local dotSize=narrow and 7 or 8;local dx=narrow and 8 or 11
   local stateText=on and"ON"or"OFF"
   local labelW=math.ceil(TextService:GetTextSize(stateText,labelSize,font,Vector2.new(200,50)).X)
   local stateW=dx+dotSize+5+labelW+(narrow and 9 or 12)
   local room=title.Size.X.Offset-stateW-10
   local function width(n)return math.ceil(TextService:GetTextSize("Copy Trading",n,font,Vector2.new(1000,100)).X)+4 end
   local size=narrow and 22 or 27
   while size>16 and width(size)>room do size-=1 end
   local tw=math.min(width(size),room)
   title.Size=UDim2.fromOffset(tw,title.Size.Y.Offset);title.TextWrapped=false
   local fitSize=title:FindFirstChildOfClass("UITextSizeConstraint");if fitSize then fitSize.MaxTextSize=size end
   local tone=on and C.Green or Color3.fromRGB(128,160,214)
   local state=frame(hero,"State",title.Position.X.Offset+tw+10,math.floor((hero.Size.Y.Offset-stateH)/2),stateW,stateH,on and Color3.fromRGB(2,48,58)or SB.Navy,45)
   round(state,stateH/2);stroke(state,tone).Thickness=2
   local dot=frame(state,"Dot",dx,math.floor((stateH-dotSize)/2),dotSize,dotSize,tone,46);round(dot,dotSize/2)
   local lx=dx+dotSize+5
   local stateLabel=sidebarText(state,"Label",stateText,lx,0,stateW-lx-(narrow and 5 or 8),stateH,labelSize,on and C.Green or C.Muted);stateLabel.ZIndex=46
]==]}
P[6]={From=[==[  local gap=compact and 6 or 10
  local labelH=compact and 22 or 26]==],To=[==[]==],New=[==[  local gap=compact and 8 or 12
  local actionGap=compact and 10 or 16
  local labelH=compact and 22 or 26]==]}
P[7]={From=[==[maxH-(yy-y)-gap-actionH-gap-footerH))end]==],To=[==[]==],New=[==[maxH-(yy-y)-actionGap-actionH-gap-footerH))end]==]}
P[8]={From=[==[  yy+=viewRows+gap
]==],To=[==[]==],New=[==[  yy+=viewRows+actionGap
]==]}
P[9]={From=[==[yy-pickerY-actionH-footerH-gap*2))]==],To=[==[]==],New=[==[yy-pickerY-actionH-footerH-gap-actionGap))]==]}
local function apply(src)
 for i,p in ipairs(P)do
  local a=string.find(src,p.From,1,true);assert(a,"patch "..i..": From not found")
  assert(not string.find(src,p.From,a+1,true),"patch "..i..": From not unique")
  local b
  if p.To==""then b=a+#p.From else b=string.find(src,p.To,a+#p.From,true);assert(b,"patch "..i..": To not found")end
  src=string.sub(src,1,a-1)..p.New..string.sub(src,b)
 end
 return src
end
return apply
