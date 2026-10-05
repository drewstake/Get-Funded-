-- Responsive collection: one scroll surface, measured native text, shared badges.
local TextService=game:GetService("TextService")
local TweenService=game:GetService("TweenService")
local Art=require(script.Parent.BadgeArt)
local Config=require(script.Parent.ProgressionConfig)
local View={}
local F=Enum.Font.FredokaOne
local C={Text=Color3.fromRGB(245,248,255),Muted=Color3.fromRGB(188,211,247),Surface=Color3.fromRGB(6,30,74),
 Edge=Color3.fromRGB(46,89,152),Gold=Color3.fromRGB(255,216,74),Cyan=Color3.fromRGB(76,223,255),Purple=Color3.fromRGB(178,126,255),Green=Color3.fromRGB(75,240,174)}
local function make(class,name,parent,props)
 local o=Instance.new(class);o.Name=name;for k,v in pairs(props)do o[k]=v end;o.Parent=parent;return o
end
local function box(p,name,x,y,w,h,color)
 return make("Frame",name,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.Surface,BorderSizePixel=0})
end
local function round(p,r)make("UICorner","Corners",p,{CornerRadius=UDim.new(0,r)})end
local function card(p,name,x,y,w,h,edge)
 local o=box(p,name,x,y,w,h);round(o,14)
 make("UIStroke","Border",o,{Color=edge or C.Edge,Thickness=1.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 return o
end
local function label(p,name,value,x,y,w,h,size,color)
 return make("TextLabel",name,p,{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
 TextColor3=color or C.Text,TextSize=size,Font=F,TextStrokeColor3=Color3.fromRGB(1,15,49),TextStrokeTransparency=.65,
 TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true})
end
local function height(value,size,w)return math.ceil(TextService:GetTextSize(value,size,F,Vector2.new(math.max(1,w-2),10000)).Y)+6 end
local function copy(p,name,value,x,y,w,size,color)
 local h=height(value,size,w);label(p,name,value,x,y,w,h,size,color);return h
end
local function bar(p,name,x,y,w,ratio)
 local track=box(p,name,x,y,w,7,Color3.fromRGB(27,53,96));round(track,4)
 ratio=math.clamp(ratio,0,1);track:SetAttribute("Progress",ratio)
 local fill=box(track,"Fill",0,0,w*ratio,7,C.Cyan);round(fill,4);fill.Visible=ratio>0
end
local function hover(p,icon)
 local base=p.Border.Color
 local function active(on)
  TweenService:Create(p.Border,TweenInfo.new(.13),{Color=on and C.Cyan or base,Thickness=on and 2.5 or 1.5}):Play()
  if icon then TweenService:Create(icon,TweenInfo.new(.13),{Rotation=on and -3 or 0}):Play()end
 end
 p.MouseEnter:Connect(function()active(true)end);p.MouseLeave:Connect(function()active(false)end)
end
local function amount(m,whole)
 return m.Kind=="Profit" and whole(m.Progress or 0).." / "..whole(m.Goal) or tostring(math.floor(m.Progress or 0)).." / "..tostring(m.Goal)
end
function View.Build(parent,pf,x,y,w,h,options)
 local state=options.State or {};local whole=options.Whole;local compact=w<650
 local root=make("ScrollingFrame","Progress",parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
  BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,ScrollingDirection=Enum.ScrollingDirection.Y,CanvasSize=UDim2.new()})
 local cw=w-24;local gap=12
 local content=box(root,"Content",8,8,cw,1);content.BackgroundTransparency=1
 local draw
 draw=function()
  content:ClearAllChildren();local yy=0
  label(content,"Title","Your Progress",0,yy,cw,40,compact and 27 or 34)
  yy=44;yy+=copy(content,"Subtitle","Ranks mark your journey. Titles celebrate your achievements. Both stay yours.",0,yy,cw,14,C.Muted)+12
  if pf.New or not pf.RankId then
   yy+=copy(content,"Loading","Your progression is loading…",0,yy,cw,18,C.Muted)
   content.Size=UDim2.fromOffset(cw,yy);root.CanvasSize=UDim2.fromOffset(0,yy+16);return
  end
  local heroW=compact and cw or math.floor((cw-gap)*.48)
  local heroH=compact and 158 or 216
  local hero=card(content,"CurrentRank",0,yy,heroW,heroH,C.Purple)
  make("UIGradient","Glow",hero,{Color=ColorSequence.new(Color3.fromRGB(105,58,186),Color3.fromRGB(22,35,82)),Rotation=65})
  hero.BackgroundColor3=Color3.new(1,1,1)
  local badgeSize=compact and 70 or 92;local tx=badgeSize+22;local tw=heroW-tx-12
  Art.Create(hero,"RankBadge",pf.RankBadge,10,20,badgeSize)
  label(hero,"RankCaption","PERMANENT RANK "..tostring(pf.RankLevel).." / "..#Config.Ranks,tx,12,tw,20,12,C.Gold)
  local ry=36;ry+=copy(hero,"Rank",pf.Rank,tx,ry,tw,compact and 20 or 25)+4
  label(hero,"TitleCaption","FEATURED TITLE",tx,ry,tw,18,12,C.Muted);ry+=20
  copy(hero,"EquippedTitle",pf.Title,tx,ry,tw,16)
  if not compact then
   label(hero,"ResultsLabel",pf.Failed and "ACCOUNT CLOSED · LIFETIME NET PROFIT"or "ACCOUNT ACTIVE · LIFETIME NET PROFIT",14,heroH-58,heroW-28,18,12,C.Muted)
   label(hero,"Results",options.Signed(pf.Earned or 0),14,heroH-37,heroW-28,28,23,C.Green)
  end
  local nx,ny,nw=compact and 0 or heroW+gap,compact and yy+heroH+gap or yy,compact and cw or cw-heroW-gap
  local n=pf.Next;local nTitle=n and n.Title or "Collection complete!"
  local titleHeight=height(nTitle,23,nw-98)
  local desc=n and n.Name or "Every achievement title is yours. Keep building your legacy."
  local descHeight=height(desc,15,nw-28)
  local nextH=math.max(216,56+titleHeight+descHeight+80)
  if not compact then hero.Size=UDim2.fromOffset(heroW,nextH) end
  local nextCard=card(content,"NextMilestone",nx,ny,nw,nextH,C.Gold)
  label(nextCard,"Eyebrow",n and "NEXT TITLE" or "ALL TITLES EARNED",14,12,nw-94,18,12,C.Gold)
  Art.Create(nextCard,"Badge",n and n.Badge or 16,nw-76,12,62)
  label(nextCard,"Reward",nTitle,14,34,nw-98,titleHeight,23)
  local dy=math.max(82,38+titleHeight)
  label(nextCard,"Goal",desc,14,dy,nw-28,descHeight,15,C.Muted)
  local ratio=n and n.Progress/n.Goal or 1
  bar(nextCard,"Track",14,nextH-59,nw-28,ratio)
  label(nextCard,"Amount",n and amount(n,whole)or "All 16 titles earned",14,nextH-46,nw-28,22,14)
  label(nextCard,"Permanent","Closed trades count. Unlocks are permanent.",14,nextH-23,nw-28,18,12,C.Muted)
  yy=ny+nextH+gap
  if pf.Failed and options.Restart then options.Restart(content,0,yy,cw,44);yy+=56 end
  local count=#(pf.Titles or {})
  if (state.EarnedCount and count>state.EarnedCount)or(state.RankId and state.RankId~=pf.RankId)then
   hero.Border.Thickness=4;TweenService:Create(hero.Border,TweenInfo.new(.65),{Thickness=1.5}):Play()
  end
  state.EarnedCount=count;state.RankId=pf.RankId
  local collection=state.Collection or "Titles"
  for i,tab in ipairs({"Titles","Ranks"})do
   local b=make("TextButton","Tab"..tab,content,{Text=tab=="Titles" and "Title collection" or "Rank ladder",Font=F,TextSize=15,TextColor3=C.Text,
    Position=UDim2.fromOffset((i-1)*(cw/2+4),yy),Size=UDim2.fromOffset(cw/2-4,42),BorderSizePixel=0,
    BackgroundColor3=collection==tab and Color3.fromRGB(104,55,189)or C.Surface});round(b,10)
   b.Activated:Connect(function()state.Collection=tab;draw()end)
  end
  yy+=52
  local explanation=collection=="Titles" and "Earned: checkmark • Next: arrow • Locked: diamond. Hover a badge to highlight it." or "Meet every requirement to rank up. Earned ranks never fall after a loss."
  yy+=copy(content,"CollectionHelp",explanation,0,yy,cw,13,C.Muted)+10
  local items=collection=="Titles" and pf.Milestones or pf.Ranks
  local cols=cw>=1000 and 3 or cw>=620 and 2 or 1;local tileW=(cw-(cols-1)*gap)/cols
  local rowY,rowMax=yy,0
  for i,m in ipairs(items or {})do
   local earned=m.Earned;local isNext=collection=="Titles" and n and n.Key==m.Key or collection=="Ranks" and pf.RankNext and pf.RankNext.Id==m.Id
   local status=earned and "✓ EARNED"or isNext and "→ NEXT"or "◇ LOCKED"
   local title=collection=="Titles" and m.Title or m.Name
   local titleH=height(title,19,tileW-94)
   local description=collection=="Titles" and m.Name or "Complete every requirement:"
   local descH=height(description,14,tileW-28)
   local top=math.max(80,40+titleH);local tileH=top+descH+(collection=="Titles" and 62 or 112)
   local col=(i-1)%cols
   if col==0 and i>1 then rowY+=rowMax+gap;rowMax=0 end
   rowMax=math.max(rowMax,tileH)
   local tile=card(content,m.Key or m.Id,col*(tileW+gap),rowY,tileW,tileH,earned and C.Green or isNext and C.Gold or C.Edge)
   tile:SetAttribute("Earned",earned==true);tile:SetAttribute("Next",isNext==true)
   local badge=Art.Create(tile,"Badge",m.Badge,10,13,64);hover(tile,badge)
   label(tile,"Status",status,84,10,tileW-98,20,12,earned and C.Green or isNext and C.Gold or C.Muted)
   label(tile,"Reward",title,84,34,tileW-98,titleH,19)
   label(tile,"Goal",description,14,top,tileW-28,descH,14,C.Muted)
   local by=top+descH+9
   if collection=="Titles" then
    bar(tile,"Track",14,by,tileW-28,earned and 1 or m.Progress/m.Goal)
    label(tile,"Amount",earned and "Unlocked forever"or amount(m,whole),14,by+13,tileW-28,23,14)
   else
    for j,metric in ipairs({{"Trades",pf.Trades or 0,"trades"},{"Wins",pf.Wins or 0,"profitable trades"},{"Profit",math.max(0,pf.Earned or 0),"net profit"}})do
     local goal=m[metric[1]];local value=math.min(metric[2],goal)
     local text=metric[1]=="Profit" and whole(value).." / "..whole(goal).." net profit" or value.." / "..goal.." "..metric[3]
     label(tile,"Requirement"..j,earned and "✓ "..(metric[1]=="Profit" and whole(goal).." net profit" or goal.." "..(goal==1 and metric[1]=="Trades"and "trade"or metric[3])) or text,14,by+(j-1)*29,tileW-28,21,14)
     bar(tile,"Track"..j,14,by+(j-1)*29+23,tileW-28,earned and 1 or goal==0 and 1 or value/goal)
    end
   end
  end
  yy=rowY+rowMax+16
  if collection=="Titles" and #(pf.Titles or {})>#(pf.Milestones or {}) then yy+=copy(content,"Alumni","Earlier achievements are preserved in your collection.",0,yy,cw,14,C.Muted)end
  -- Alumni titles have no obsolete account-tier labels; they remain permanent.
  if collection=="Titles" then
   local known={};for _,m in ipairs(pf.Milestones or {})do known[m.Title]=true end
   for _,title in ipairs(pf.Titles or {})do if not known[title]then yy+=copy(content,"AlumniTitle","✓ "..title.." · previously earned",0,yy,cw,15,C.Gold)+6 end end
  end
  content.Size=UDim2.fromOffset(cw,yy);root.CanvasSize=UDim2.fromOffset(0,yy+16)
  root:SetAttribute("Collection",collection);root:SetAttribute("Columns",cols)
 end
 draw();return root
end
return View
