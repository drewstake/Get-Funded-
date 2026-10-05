-- Fixed-viewport progress page. Collections use pagination, never scrolling.
local TextService=game:GetService("TextService")
local View={}
local ART={Badge="rbxassetid://131784853730971",Locked="rbxassetid://139407057080398",Earned="rbxassetid://121210473862886",Trophy="rbxassetid://80175474742009"}
local C={Surface=Color3.fromRGB(7,30,68),Edge=Color3.fromRGB(31,67,114),Text=Color3.fromRGB(245,248,255),Muted=Color3.fromRGB(160,185,222),Purple=Color3.fromRGB(174,113,255),Gold=Color3.fromRGB(255,213,66),Green=Color3.fromRGB(68,238,155),Red=Color3.fromRGB(255,133,145)}
local Heading,Body=Enum.Font.FredokaOne,Enum.Font.GothamMedium
local function make(class,name,parent,props)
 local obj=Instance.new(class);obj.Name=name;for k,v in pairs(props)do obj[k]=v end;obj.Parent=parent;return obj
end
local function box(p,name,x,y,w,h,color)
 return make("Frame",name,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.Surface,BorderSizePixel=0})
end
local function corners(p,r)make("UICorner","Corners",p,{CornerRadius=UDim.new(0,r)})end
local function surface(p,name,x,y,w,h,color,edge)
 local obj=box(p,name,x,y,w,h,color);corners(obj,12)
 make("UIStroke","Border",obj,{Color=edge or C.Edge,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border});return obj
end
local function label(p,name,value,x,y,w,h,size,color,font)
 return make("TextLabel",name,p,{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0,
 TextColor3=color or C.Text,TextSize=size,Font=font or Body,TextStrokeTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
end
local function height(value,size,w,font)
 return math.ceil(TextService:GetTextSize(value,size,font or Body,Vector2.new(math.max(1,w-4),10000)).Y)+4
end
local function wrapped(p,name,value,x,y,w,size,color,font)
 local h=height(value,size,w,font);local obj=label(p,name,value,x,y,w,h,size,color,font);obj.TextWrapped=true;return h,obj
end
local function icon(p,name,asset,x,y,size)
 return make("ImageLabel",name,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),BackgroundTransparency=1,Image=asset,ScaleType=Enum.ScaleType.Fit})
end
local function button(p,name,value,x,y,w,h,selected,fn)
 local b=make("TextButton",name,p,{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=selected and Color3.fromRGB(87,44,165)or C.Surface,
 BorderSizePixel=0,TextColor3=C.Text,Font=Body,TextSize=13,AutoButtonColor=true});corners(b,8);b.Activated:Connect(fn);return b
end
local function requirement(m,whole,start)
 if m.Legacy then return "Previously earned title" end
 if m.Kind=="Trades"or m.Kind=="Wins"then return m.Name end
 if m.Kind=="Balance"then return whole(start+m.Goal).." balance + "..whole(m.Goal).." lifetime profit"end
 return "Earn "..whole(m.Goal).." lifetime net profit"
end
function View.Build(parent,pf,x,y,w,h,options)
 local signed,whole=options.Signed,options.Whole
 local state=options.State or {};local start=options.StartingBalance or require(script.Parent.ProgressionConfig).StartingBalance
 local root=box(parent,"Progress",x,y,w,h);root.BackgroundTransparency=1
 local cw,ch=w-16,h-16
 local content=box(root,"Content",8,8,cw,ch);content.BackgroundTransparency=1
 local compact=cw<640 or ch<520;local short=ch<300;local gap=short and 8 or 12
 local upcoming,earned,known={},{},{}
 for _,m in ipairs(pf.Milestones or {})do
  if m.Earned then table.insert(earned,m);known[m.Title]=true
  elseif not pf.Next or m.Key~=pf.Next.Key then table.insert(upcoming,m)end
 end
 for _,title in ipairs(pf.Titles or {})do
  if not known[title]then table.insert(earned,{Key="Legacy"..tostring(#earned+1),Title=title,Legacy=true});known[title]=true end
 end
 local draw
 local function stats(sx,sy,sw,sh,vertical)
  local p=surface(content,"RunResults",sx,sy,sw,sh)
  for i,data in ipairs({{"Run","Run "..tostring(pf.Run or 1).." · Closed",pf.RunProfit or 0},{"Lifetime","Lifetime net profit",pf.Earned or 0}})do
   local mw=vertical and sw or sw/2;local mh=vertical and sh/2 or sh
   local xx=vertical and 0 or(i-1)*mw;local yy=vertical and(i-1)*mh or 0
   label(p,data[1].."Label",data[2],xx+12,yy+6,mw-24,18,compact and 11 or 14,C.Muted)
   local value=label(p,data[1],signed(data[3]),xx+12,yy+25,mw-24,math.min(30,mh-28),compact and 19 or 25,data[3]<0 and C.Red or C.Green,Heading)
   value.TextScaled=true;make("UITextSizeConstraint","ValueSize",value,{MinTextSize=12,MaxTextSize=compact and 19 or 28})
  end
 end
 local function hero(sx,sy,sw,sh)
  local small=sh<180;local pad=small and 10 or 14
  local p=surface(content,"NextMilestone",sx,sy,sw,sh,Color3.new(1,1,1),C.Purple)
  make("UIGradient","PurpleSurface",p,{Color=ColorSequence.new(Color3.fromRGB(77,38,160),Color3.fromRGB(24,30,89)),Rotation=75})
  local n=pf.Next;local badge=small and 38 or 58
  icon(p,"MilestoneBadge",ART.Badge,sw-pad-badge,pad,badge)
  label(p,"Eyebrow",n and "NEXT MILESTONE"or"ALL TITLES EARNED",pad,pad,sw-pad*2-badge-8,16,11,Color3.fromRGB(209,175,255),Heading)
  local titleH=wrapped(p,"Reward",n and n.Title or"Get Funded Legend",pad,pad+19,sw-pad*2-badge-8,small and 19 or 28,C.Text,Heading)
  local goalY=math.max(pad+19+titleH+2,pad+badge+2)
  local descH=wrapped(p,"Goal",n and requirement(n,whole,start)or"Every milestone complete. Titles stay yours forever.",pad,goalY,sw-pad*2,small and 12 or 13,Color3.fromRGB(222,217,250))
  local note="Closed trades only. Starting money and grants excluded."
  if n and n.Kind~="Trades"and n.Kind~="Wins"and(pf.Earned or 0)<0 then note="Recover "..whole(-(pf.Earned or 0)).." in lifetime losses first."
  elseif n and n.Kind=="Balance"then note="Both balance and lifetime profit must meet the goal."end
  local noteH=height(note,11,sw-pad*2);local barY=sh-pad-noteH-29
  local track=box(p,"Track",pad,barY,sw-pad*2,6,Color3.fromRGB(30,25,72));corners(track,3)
  local ratio=n and math.clamp(n.Progress/math.max(1,n.Goal),0,1)or 1;track:SetAttribute("Progress",ratio)
  local fill=box(track,"Fill",0,0,(sw-pad*2)*ratio,6,C.Gold);corners(fill,3);fill.Visible=ratio>0
  local amount=n and((n.Kind=="Trades"or n.Kind=="Wins")and string.format("%d / %d",n.Progress,n.Goal)or whole(n.Progress).." / "..whole(n.Goal))or"Complete"
  label(p,"Amount",amount,pad,barY+8,sw-pad*2-45,18,12,C.Text,Heading)
  local pct=label(p,"Percentage",tostring(math.floor(ratio*100)).."%",sw-pad-42,barY+8,42,18,12,C.Text,Heading);pct.TextXAlignment=Enum.TextXAlignment.Right
  wrapped(p,"ProgressNote",note,pad,sh-pad-noteH,sw-pad*2,11,Color3.fromRGB(205,194,237))
  p:SetAttribute("CopyBottom",goalY+descH);p:SetAttribute("TrackTop",barY)
 end
 local function section(name,title,items,sx,sy,sw,sh,isEarned)
  local p=surface(content,name,sx,sy,sw,sh);local pad=12
  label(p,"Title",title,pad,8,sw-pad*2-42,28,compact and 18 or 20,C.Text,Heading)
  local count=label(p,"Count",tostring(#items),sw-pad-36,8,36,28,13,C.Muted);count.TextXAlignment=Enum.TextXAlignment.Right
  local top,footer=44,40;local usable=sh-top-footer-8
  local rows={};local textW=sw-pad*2-40
  local roomy=not compact and sh>=320
  local rowFont,descFont=roomy and 18 or 14,roomy and 14 or 12
  for _,m in ipairs(items)do
   local th=height(m.Title,rowFont,textW,Heading);local desc=requirement(m,whole,start)
   table.insert(rows,{Data=m,TitleHeight=th,Desc=desc,Height=math.max(roomy and 64 or 44,th+height(desc,descFont,textW)+8)})
  end
  local pages={{}};local used=0
  for _,row in ipairs(rows)do
   if used>0 and used+row.Height>usable then table.insert(pages,{});used=0 end
   table.insert(pages[#pages],row);used+=row.Height
  end
  local page=math.clamp(state[name]or 1,1,#pages);state[name]=page
  p:SetAttribute("Page",page);p:SetAttribute("PageCount",#pages);p:SetAttribute("ItemCount",#items)
  local yy=top
  for _,row in ipairs(pages[page])do
   local m=row.Data;local r=box(p,m.Key,pad,yy,sw-pad*2,row.Height);r.BackgroundTransparency=1
   icon(r,"StatusIcon",isEarned and ART.Earned or ART.Locked,0,6,28)
   label(r,"Reward",m.Title,40,0,textW,row.TitleHeight,rowFont,C.Text,Heading).TextWrapped=true
   label(r,"Goal",row.Desc,40,row.TitleHeight,textW,row.Height-row.TitleHeight-4,descFont,C.Muted).TextWrapped=true
   yy+=row.Height
  end
  if #items==0 then wrapped(p,"Empty",isEarned and"Close your first trade to earn a title."or"No more upcoming titles.",pad,top,sw-pad*2,13,C.Muted)end
  if #pages>1 then
   local prev=button(p,"Previous","‹",pad,sh-footer,44,32,false,function()state[name]=math.max(1,page-1);draw()end);prev.Active=page>1;prev.TextTransparency=page>1 and 0 or .6
   local nextButton=button(p,"Next","›",sw-pad-44,sh-footer,44,32,false,function()state[name]=math.min(#pages,page+1);draw()end);nextButton.Active=page<#pages;nextButton.TextTransparency=page<#pages and 0 or .6
   label(p,"PageNumber",page.." / "..#pages,60,sh-footer,sw-120,32,12,C.Muted).TextXAlignment=Enum.TextXAlignment.Center
  else label(p,"Permanent",isEarned and"Unlocked titles are permanent."or"Only closed trades count.",pad,sh-30,sw-pad*2,20,11,C.Muted)end
 end
 draw=function()
  content:ClearAllChildren()
  local headH=compact and 36 or 48
  label(content,"Title","Progress",0,0,cw,headH,compact and 25 or 32,C.Text,Heading)
  local rankText=pf.Rank or"New Trader"
  local rankW=math.min(cw*.56,TextService:GetTextSize(rankText,13,Heading,Vector2.new(1000,100)).X+44)
  local rank=surface(content,"Rank",cw-rankW,0,rankW,headH);icon(rank,"Trophy",ART.Trophy,6,(headH-24)/2,24)
  label(rank,"Label",rankText,34,0,rankW-40,headH,13,C.Gold,Heading).TextWrapped=true
  local yy=headH+gap
  if pf.Failed and options.Restart then
   if short then rank.Visible=false;options.Restart(content,cw-220,0,220,headH)
   else options.Restart(content,0,yy,cw,40);yy+=40+gap end
  end
  if compact then
   local tabW=(cw-12)/3;local selected=state.Tab or"Overview"
   for i,tab in ipairs({"Overview","Upcoming","Earned"})do button(content,"Tab"..tab,tab,(i-1)*(tabW+6),yy,tabW,32,selected==tab,function()state.Tab=tab;draw()end)end
   yy+=32+gap;local available=ch-yy;root:SetAttribute("Tab",selected)
   if selected=="Upcoming"then section("UpcomingTitles","Upcoming titles",upcoming,0,yy,cw,available,false)
   elseif selected=="Earned"then section("EarnedTitles","Earned titles",earned,0,yy,cw,available,true)
   elseif cw>=560 and available<270 then
    local statW=math.floor(cw*.29);stats(0,yy,statW,available,true);hero(statW+gap,yy,cw-statW-gap,available)
   else stats(0,yy,cw,58,false);hero(0,yy+58+gap,cw,available-58-gap)end
  else
   stats(0,yy,cw,68,false);yy+=68+gap
   local heroH=ch<660 and 166 or 186;hero(0,yy,cw,heroH);yy+=heroH+gap
   local sw=math.floor((cw-gap)*.52);local remaining=ch-yy
   section("UpcomingTitles","Upcoming titles",upcoming,0,yy,sw,remaining,false)
   section("EarnedTitles","Earned titles",earned,sw+gap,yy,cw-sw-gap,remaining,true)
  end
 end
 draw();return root
end
return View
