-- Progress-page presentation only. All goals, awards and values come from FundedAccounts.
-- Original ImageGen PNGs and their upload manifest live in icons/progress/.
local TextService = game:GetService("TextService")
local View = {}
local ART = {
 Badge="rbxassetid://131784853730971",
 Locked="rbxassetid://139407057080398",
 Earned="rbxassetid://121210473862886",
 Cash="rbxassetid://84096597834437",
 Trophy="rbxassetid://80175474742009",
}
local C = {
 Surface=Color3.fromRGB(7,30,68), Edge=Color3.fromRGB(31,67,114),
 Text=Color3.fromRGB(245,248,255), Muted=Color3.fromRGB(160,185,222),
 Purple=Color3.fromRGB(174,113,255), Gold=Color3.fromRGB(255,213,66),
 Green=Color3.fromRGB(68,238,155), Red=Color3.fromRGB(255,133,145),
}
local Heading=Enum.Font.FredokaOne
local Body=Enum.Font.GothamMedium
local function make(class,name,parent,props)
 local obj=Instance.new(class);obj.Name=name
 for key,value in pairs(props) do obj[key]=value end
 obj.Parent=parent;return obj
end
local function box(p,name,x,y,w,h,color)
 return make("Frame",name,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color,BorderSizePixel=0})
end
local function corners(p,r)
 make("UICorner","Corners",p,{CornerRadius=UDim.new(0,r)})
end
local function surface(p,name,x,y,w,h,color,edge)
 local obj=box(p,name,x,y,w,h,color or C.Surface);corners(obj,14)
 make("UIStroke","Border",obj,{Color=edge or C.Edge,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 return obj
end
local function label(p,name,value,x,y,w,h,size,color,font)
 return make("TextLabel",name,p,{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
  BackgroundTransparency=1,BorderSizePixel=0,TextColor3=color or C.Text,TextSize=size,
  Font=font or Body,TextStrokeTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
  TextYAlignment=Enum.TextYAlignment.Center})
end
local function wrap(p,name,value,x,y,w,size,color,font)
 local height=math.ceil(TextService:GetTextSize(value,size,font or Body,Vector2.new(math.max(1,w-4),10000)).Y)+6
 local obj=label(p,name,value,x,y,w,height,size,color,font);obj.TextWrapped=true
 return height,obj
end
local function icon(p,name,asset,x,y,size)
 return make("ImageLabel",name,p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),
  BackgroundTransparency=1,Image=asset,ScaleType=Enum.ScaleType.Fit})
end
local function line(p,name,x,y,w)
 return box(p,name,x,y,w,1,C.Edge)
end

-- Balance milestones also require current closed balance. Never describe them as profit-only.
local function requirement(m,whole,startingBalance)
 if m.Kind=="Trades" or m.Kind=="Wins" then return m.Name end
 if m.Kind=="Balance" then
  return "Reach "..whole(startingBalance+m.Goal).." balance and earn "..whole(m.Goal).." lifetime net profit"
 end
 return "Earn "..whole(m.Goal).." in lifetime net trading profit"
end

function View.Build(parent,pf,x,y,w,h,options)
 local signed,whole=options.Signed,options.Whole
 local sc=make("ScrollingFrame","Progress",parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
  CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,
  ScrollBarImageColor3=C.Edge,ScrollingDirection=Enum.ScrollingDirection.Y})
 local cw=math.max(200,w-24)
 local content=box(sc,"Content",8,8,cw,1,C.Surface);content.BackgroundTransparency=1
 local narrow=cw<660;local tiny=cw<430;local short=h<400 and w>h
 local pad=short and 14 or narrow and 16 or 22
 local body=(narrow or short) and 14 or 16;local yy=0
 local start=options.StartingBalance or 5000
 label(content,"Title","Progress",0,0,cw,44,(narrow or short) and 30 or 38,C.Text,Heading)
 if short then yy=56
 else
  local sh=wrap(content,"Subtitle","Trade. Earn titles. Keep them forever.",0,48,cw,body,C.Muted)
  yy=48+sh+16
 end
 local rankText=pf.Rank or "New Trader"
 local rankW=math.min(cw,math.ceil(TextService:GetTextSize(rankText,16,Heading,Vector2.new(1000,100)).X)+70)
 local inlineRank=(not narrow or short) and cw-rankW>(short and 180 or 370)
 local rank=surface(content,"Rank",inlineRank and cw-rankW or 0,inlineRank and 4 or yy,rankW,42)
 icon(rank,"Trophy",ART.Trophy,9,7,28)
 label(rank,"Label",rankText,44,0,rankW-54,42,16,C.Gold,Heading)
 if not inlineRank then yy+=58 end

 if pf.Failed and options.Restart then
  options.Restart(content,0,yy,cw,48);yy+=64
 end

 local stats=surface(content,"RunResults",0,yy,cw,tiny and 164 or 98)
 local cellW=tiny and cw or cw/2
 local function metric(name,title,value,index,art)
  local mx=tiny and 0 or index*cellW;local my=tiny and index*82 or 0
  local ix=mx+pad;local tx=ix
  if not tiny and cellW>=300 then
   if art then icon(stats,name.."Icon",art,ix,my+25,46)
   else
    for i,bh in ipairs({32,23,14})do
     local bar=box(stats,"NetBar"..i,ix+(i-1)*14,my+60-bh,10,bh,value<0 and C.Red or C.Green);corners(bar,3)
    end
   end
   tx+=60
  end
  label(stats,name.."Label",title,tx,my+15,cellW-(tx-mx)-pad,24,body,C.Muted)
  local v=label(stats,name,signed(value),tx,my+42,cellW-(tx-mx)-pad,34,tiny and 25 or 28,value<0 and C.Red or C.Green,Heading)
  -- Extreme lifetime values remain readable rather than overflowing their column.
  local constraint=make("UITextSizeConstraint","ValueSize",v,{MinTextSize=14,MaxTextSize=v.TextSize})
  v.TextScaled=true
 end
 metric("Run","Run "..tostring(pf.Run or 1).." · Closed result",pf.RunProfit or 0,0,ART.Cash)
 metric("Lifetime","Lifetime net profit",pf.Earned or 0,1)
 if tiny then line(stats,"Divider",pad,82,cw-pad*2)
 else box(stats,"Divider",cellW,19,1,60,C.Edge) end
 if not short then yy+=stats.Size.Y.Offset+18 end

 local nextGoal=pf.Next
 local hero=surface(content,"NextMilestone",0,yy,cw,1,Color3.new(1,1,1),C.Purple)
 make("UIGradient","PurpleSurface",hero,{Color=ColorSequence.new(Color3.fromRGB(77,38,160),Color3.fromRGB(24,30,89)),Rotation=75})
 local badgeSize=short and 52 or tiny and 54 or narrow and 74 or 112
 icon(hero,"MilestoneBadge",ART.Badge,cw-pad-badgeSize,pad,badgeSize)
 label(hero,"Eyebrow",nextGoal and "NEXT MILESTONE" or "ALL TITLES EARNED",pad,pad,cw-pad*2-badgeSize-12,22,tiny and 12 or 14,Color3.fromRGB(209,175,255),Heading)
 local headingY=pad+30
 local titleH=wrap(hero,"Reward",nextGoal and nextGoal.Title or "Get Funded Legend",pad,headingY,cw-pad*2-badgeSize-12,(tiny or short) and 23 or 32,C.Text,Heading)
 local goalY=math.max(headingY+titleH+6,tiny and pad+badgeSize+10 or 0)
 local desc=nextGoal and requirement(nextGoal,whole,start) or "Every milestone is complete. Your titles are yours forever."
 local descW=tiny and cw-pad*2 or cw-pad*2-badgeSize-16
 local descH=wrap(hero,"Goal",desc,pad,goalY,descW,body,Color3.fromRGB(222,217,250))
 local barY=math.max(goalY+descH+18,pad+badgeSize+18)
 local ratio=nextGoal and math.clamp(nextGoal.Progress/math.max(1,nextGoal.Goal),0,1) or 1
 local track=box(hero,"Track",pad,barY,cw-pad*2,10,Color3.fromRGB(30,25,72));corners(track,5)
 track:SetAttribute("Progress",ratio)
 local fill=box(track,"Fill",0,0,(cw-pad*2)*ratio,10,C.Gold);corners(fill,5);fill.Visible=ratio>0
 local amount=nextGoal and ((nextGoal.Kind=="Trades" or nextGoal.Kind=="Wins")
  and string.format("%d / %d",nextGoal.Progress,nextGoal.Goal) or whole(nextGoal.Progress).." / "..whole(nextGoal.Goal)) or "Complete"
 label(hero,"Amount",amount,pad,barY+18,cw-pad*2-56,24,body,C.Text,Heading)
 local percentage=label(hero,"Percentage",tostring(math.floor(ratio*100)).."%",cw-pad-52,barY+18,52,24,body,C.Text,Heading)
 percentage.TextXAlignment=Enum.TextXAlignment.Right
 local note="Unlocked titles are permanent."
 if nextGoal and nextGoal.Kind~="Trades" and nextGoal.Kind~="Wins" then
  if (pf.Earned or 0)<0 then note="Recover "..whole(-(pf.Earned or 0)).." in lifetime losses before profit progress begins."
  elseif nextGoal.Kind=="Balance" then note="Both current balance and lifetime net profit must meet the goal."
  else note="Wins and losses across all runs count toward net profit." end
 end
 local noteH=wrap(hero,"ProgressNote",note,pad,barY+52,cw-pad*2,13,Color3.fromRGB(199,188,233))
 local heroH=barY+52+noteH+pad
 hero.Size=UDim2.fromOffset(cw,heroH);yy+=heroH+18
 if short then stats.Position=UDim2.fromOffset(0,yy);yy+=stats.Size.Y.Offset+18 end

 local upcoming,earned,knownTitles={},{},{}
 for _,m in ipairs(pf.Milestones or {})do
  if m.Earned then table.insert(earned,m);knownTitles[m.Title]=true
  elseif not nextGoal or m.Key~=nextGoal.Key then table.insert(upcoming,m) end
 end
 for _,title in ipairs(pf.Titles or {})do
  if not knownTitles[title]then
   table.insert(earned,{Key="Legacy"..tostring(#earned+1),Title=title,Name="Previously earned title",Legacy=true});knownTitles[title]=true
  end
 end
 local leftW=narrow and cw or math.floor((cw-18)*.56)
 local rightW=narrow and cw or cw-leftW-18
 local function section(name,title,items,sx,sy,sw,isEarned)
  local panel=surface(content,name,sx,sy,sw,1)
  label(panel,"Title",title,pad,16,sw-pad*2,30,narrow and 20 or 23,C.Text,Heading)
  local caption=isEarned and tostring(#items).." unlocked · Yours forever" or "Keep trading to unlock the next titles."
  local ch=wrap(panel,"Caption",caption,pad,50,sw-pad*2,13,C.Muted)
  local rowY=50+ch+14
  for i,m in ipairs(items)do
   local row=box(panel,m.Key or "Title"..i,pad,rowY,sw-pad*2,1,C.Surface);row.BackgroundTransparency=1
   local tw=sw-pad*2-52
   icon(row,"StatusIcon",isEarned and ART.Earned or ART.Locked,0,9,36)
   local titleH=wrap(row,"Reward",m.Title,52,5,tw,body,C.Text,Heading)
   local rh=wrap(row,"Goal",isEarned and (m.Legacy and m.Name or requirement(m,whole,start)) or requirement(m,whole,start),52,7+titleH,tw,13,C.Muted)
   local rowH=math.max(70,7+titleH+rh+16);row.Size=UDim2.fromOffset(sw-pad*2,rowH)
   rowY+=rowH
   if i<#items then line(panel,"Divider"..i,pad,rowY,sw-pad*2);rowY+=8 end
  end
  if #items==0 then
   rowY+=wrap(panel,"Empty",isEarned and "Close your first trade to earn a title." or "You have reached the final milestone.",pad,rowY,sw-pad*2,body,C.Muted)+16
  end
  local panelH=rowY+pad;panel.Size=UDim2.fromOffset(sw,panelH)
  return panelH
 end
 local leftH=section("UpcomingTitles","Upcoming titles",upcoming,0,yy,leftW,false)
 local rightY=narrow and yy+leftH+18 or yy
 local rightH=section("EarnedTitles","Earned titles",earned,narrow and 0 or leftW+18,rightY,rightW,true)
 yy=narrow and rightY+rightH+18 or yy+math.max(leftH,rightH)+18
 line(content,"FooterRule",0,yy,cw);yy+=14
 local rules="Only closed trades count. Starting money and restart grants are excluded."
 if pf.Migrated then rules..=" Your earlier results and legacy titles are preserved." end
 yy+=wrap(content,"Rules",rules,0,yy,cw,13,C.Muted)+20
 content.Size=UDim2.fromOffset(cw,yy);sc.CanvasSize=UDim2.fromOffset(0,yy+16)
 return sc
end
return View
