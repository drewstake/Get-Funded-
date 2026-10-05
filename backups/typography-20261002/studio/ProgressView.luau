-- Stable achievement columns: one ladder per metric, one remembered scroll surface.
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
 state.Scroll=state.Scroll or {}
 local draw;local drawing=false;local scrollKey
 root:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
  if scrollKey and not drawing then state.Scroll[scrollKey]=root.CanvasPosition.Y end
 end)
 draw=function()
  drawing=true
  content:ClearAllChildren();local yy=0
  label(content,"Title","Your Progress",0,yy,cw,40,compact and 27 or 34)
  yy=44;yy+=copy(content,"Subtitle","Build your record. Earn ranks and titles that stay yours.",0,yy,cw,14,C.Muted)+12
  if pf.New or not pf.RankId then
   yy+=copy(content,"Loading","Loading your ranks and titles…",0,yy,cw,18,C.Muted)
   content.Size=UDim2.fromOffset(cw,yy);root.CanvasSize=UDim2.fromOffset(0,yy+16);drawing=false;return
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
  label(hero,"TitleCaption",#(pf.Titles or {})>0 and "FEATURED TITLE"or "TITLE COLLECTION",tx,ry,tw,18,12,C.Muted);ry+=20
  copy(hero,"EquippedTitle",pf.Title,tx,ry,tw,16)
  if not compact then
   label(hero,"ResultsLabel","LIFETIME NET PROFIT",14,heroH-58,heroW-28,18,12,C.Muted)
   label(hero,"Results",options.Signed(pf.Earned or 0),14,heroH-37,heroW-28,28,23,C.Green)
  end
  local nx,ny,nw=compact and 0 or heroW+gap,compact and yy+heroH+gap or yy,compact and cw or cw-heroW-gap
  local n=pf.Next;local nTitle=n and n.Title or "Every title is yours"
  local titleHeight=height(nTitle,23,nw-98)
  local desc=n and n.Name or "You reached every title milestone in Get Funded!"
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
  label(nextCard,"Amount",n and amount(n,whole)or "All titles earned",14,nextH-46,nw-28,22,14)
  label(nextCard,"Permanent","Earned titles stay yours.",14,nextH-23,nw-28,18,12,C.Muted)
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
  local explanation=collection=="Titles" and "Close trades, earn wins and build lifetime net profit. Each goal earns a title." or "Meet all three lifetime goals to rank up. Losses never take an earned rank away."
  yy+=copy(content,"CollectionHelp",explanation,0,yy,cw,13,C.Muted)+10
  local cols=cw>=1000 and 3 or cw>=620 and 2 or 1
  local function tile(parent,m,px,py,tileW,fixedH,isNext)
   local earned=m.Earned
   local status=earned and "✓ EARNED"or isNext and "→ NEXT"or "◇ LOCKED"
   local title=collection=="Titles" and m.Title or m.Name
   local titleH=height(title,19,tileW-94)
   local starter=collection=="Ranks" and m.Trades==0 and m.Wins==0 and m.Profit==0
   local description=collection=="Titles" and m.Name or starter and "Your starting rank. Your first title is next."or earned and "Lifetime goals met:"or "Meet all three lifetime goals:"
   local descH=height(description,14,tileW-28)
   local top=math.max(80,40+titleH);local tileH=fixedH or top+descH+(collection=="Titles" and 62 or 112)
   local tile=card(parent,m.Key or m.Id,px,py,tileW,tileH,earned and C.Green or isNext and C.Gold or C.Edge)
   tile:SetAttribute("Earned",earned==true);tile:SetAttribute("Next",isNext==true)
   local badge=Art.Create(tile,"Badge",m.Badge,10,13,64);hover(tile,badge)
   label(tile,"Status",status,84,10,tileW-98,20,12,earned and C.Green or isNext and C.Gold or C.Muted)
   label(tile,"Reward",title,84,34,tileW-98,titleH,19)
   label(tile,"Goal",description,14,top,tileW-28,descH,14,C.Muted)
   local by=top+descH+9
   if collection=="Titles" then
    bar(tile,"Track",14,by,tileW-28,earned and 1 or m.Progress/m.Goal)
    local value=earned and (m.EarlierGoal and "Kept from an earlier goal" or "Yours to keep")or amount(m,whole)
    label(tile,"Amount",value,14,by+13,tileW-28,height(value,14,tileW-28),14)
   elseif not starter then
    for j,metric in ipairs({{"Trades",pf.Trades or 0,"closed trades"},{"Wins",pf.Wins or 0,"profitable trades"},{"Profit",math.max(0,pf.Earned or 0),"lifetime net profit"}})do
     local goal=m[metric[1]];local value=math.min(metric[2],goal)
     local text=metric[1]=="Profit" and whole(value).." / "..whole(goal).." lifetime net profit" or value.." / "..goal.." "..metric[3]
     local requirement=earned and "✓ "..(metric[1]=="Profit" and whole(goal).." lifetime net profit"or goal.." "..metric[3])or text
     local rh=height(requirement,14,tileW-28)
     label(tile,"Requirement"..j,requirement,14,by,tileW-28,rh,14)
     bar(tile,"Track"..j,14,by+rh+2,tileW-28,earned and 1 or goal==0 and 1 or value/goal)
     by+=rh+14
    end
   end
   if collection=="Ranks" then tileH=starter and top+descH+20 or by+12;tile.Size=UDim2.fromOffset(tileW,tileH)end
   return tileH
  end
  if collection=="Titles" then
   local groups={
    {Kind="Trades",Name="Closed trades",Tab="Trades",Color=C.Cyan,Value=tostring(pf.Trades or 0).." closed"},
    {Kind="Wins",Name="Profitable trades",Tab="Wins",Color=C.Green,Value=tostring(pf.Wins or 0).." profitable"},
    {Kind="Profit",Name="Lifetime net profit",Tab="Profit",Color=C.Gold,Value=options.Signed(pf.Earned or 0)},
   }
   for _,g in ipairs(groups)do
    g.Items={};g.Earned=0
    for _,m in ipairs(pf.Milestones or {})do if m.Kind==g.Kind then table.insert(g.Items,m)end end
    table.sort(g.Items,function(a,b)return a.Goal==b.Goal and a.Key<b.Key or a.Goal<b.Goal end)
    for _,m in ipairs(g.Items)do if m.Earned then g.Earned+=1 elseif not g.Next then g.Next=m.Key end end
   end
   cols=cw>=840 and 3 or 1
   if cols==1 then
    state.Track=state.Track or "Trades"
    local tabW=(cw-2*gap)/3
    for i,g in ipairs(groups)do
     local b=make("TextButton","TrackTab"..g.Kind,content,{Text=g.Tab,Font=F,TextSize=14,TextColor3=C.Text,
      Position=UDim2.fromOffset((i-1)*(tabW+gap),yy),Size=UDim2.fromOffset(tabW,36),BorderSizePixel=0,
      BackgroundColor3=state.Track==g.Kind and Color3.fromRGB(104,55,189)or C.Surface});round(b,10)
     b.Activated:Connect(function()state.Track=g.Kind;draw()end)
    end
    yy+=46
   end
   local tileW=(cw-(cols-1)*gap)/cols
   -- A shared height keeps rows aligned even when names or amounts wrap.
   local tileH=0
   for _,m in ipairs(pf.Milestones or {})do
    local top=math.max(80,40+height(m.Title,19,tileW-98))
    local value=m.Earned and (m.EarlierGoal and "Kept from an earlier goal"or "Yours to keep")or amount(m,whole)
    tileH=math.max(tileH,top+height(m.Name,14,tileW-28)+22+height(value,14,tileW-28)+16)
   end
   local bottom=yy
   for i,g in ipairs(groups)do if cols==3 or state.Track==g.Kind then
    local gx=cols==3 and (i-1)*(tileW+gap)or 0
    local lane=box(content,"Column"..g.Kind,gx,yy,tileW,1);lane.BackgroundTransparency=1
    lane:SetAttribute("Kind",g.Kind);lane:SetAttribute("NextKey",g.Next)
    local header=card(lane,"Header",0,0,tileW,94,g.Color)
    label(header,"Category",g.Name,14,10,tileW-28,24,18,g.Color)
    label(header,"Total",g.Value,14,38,tileW-28,24,18)
    label(header,"Earned",g.Earned.." / "..#g.Items.." titles earned",14,68,tileW-28,18,12,C.Muted)
    local ly=106
    for _,m in ipairs(g.Items)do
     tile(lane,m,0,ly,tileW,tileH,g.Next==m.Key);ly+=tileH+gap
    end
    lane.Size=UDim2.fromOffset(tileW,ly-gap);bottom=math.max(bottom,yy+ly)
   end end
   yy=bottom+4
  else
   local tileW=(cw-(cols-1)*gap)/cols;local rowY,rowMax=yy,0
   for i,m in ipairs(pf.Ranks or {})do
    local col=(i-1)%cols
    if col==0 and i>1 then rowY+=rowMax+gap;rowMax=0 end
    rowMax=math.max(rowMax,tile(content,m,col*(tileW+gap),rowY,tileW,nil,pf.RankNext and pf.RankNext.Id==m.Id))
   end
   yy=rowY+rowMax+16
  end
  if collection=="Titles" and #(pf.Titles or {})>#(pf.Milestones or {}) then yy+=copy(content,"Alumni","Earlier achievements are preserved in your collection.",0,yy,cw,14,C.Muted)end
  -- Alumni titles have no obsolete account-tier labels; they remain permanent.
  if collection=="Titles" then
   local known={};for _,m in ipairs(pf.Milestones or {})do known[m.Title]=true end
   for _,title in ipairs(pf.Titles or {})do if not known[title]then yy+=copy(content,"AlumniTitle","✓ "..title.." · previously earned",0,yy,cw,15,C.Gold)+6 end end
  end
  content.Size=UDim2.fromOffset(cw,yy);root.CanvasSize=UDim2.fromOffset(0,yy+16)
  scrollKey=collection..(collection=="Titles"and cols==1 and (state.Track or "Trades")or "")
  root.CanvasPosition=Vector2.new(0,math.clamp(state.Scroll[scrollKey]or 0,0,math.max(0,yy+16-h)))
  drawing=false
  root:SetAttribute("Collection",collection);root:SetAttribute("Columns",cols)
 end
 draw();return root
end
return View
