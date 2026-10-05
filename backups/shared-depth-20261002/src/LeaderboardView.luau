-- Numeric placement and permanent rank are separate; old snapshots never guess a rank.
local Art=require(script.Parent.BadgeArt)
local Rules=require(script.Parent.ProgressionRules)
local Config=require(script.Parent.ProgressionConfig)
local TextService=game:GetService("TextService")
local View={}
local DISPLAY=Enum.Font.FredokaOne
local BODY=Enum.Font.GothamMedium
local NUMBER=Enum.Font.RobotoMono
local function height(value,size,width,font)
 return math.ceil(TextService:GetTextSize(value,size,font or DISPLAY,Vector2.new(math.max(1,width-4),10000)).Y*1.12)+6
end
function View.Draw(ctx,x,y,w,h,mobile,client)
 local frame,round,stroke=ctx.frame,ctx.round,ctx.stroke;local C=ctx.C
 local narrow=w<720;local short=h<400;local pad=narrow and 12 or 20;local iw=w-pad*2
 local muted=Color3.fromRGB(203,220,248)
 local gain,loss=Color3.fromRGB(99,246,188),Color3.fromRGB(255,139,179)
 local function text(p,name,value,xx,yy,ww,hh,size,color,align,font)
  local t=ctx.text(p,name,value,xx,yy,ww,hh,size,color or C.Text,font or DISPLAY,align)
  if font==NUMBER then t.FontFace=Font.new(t.FontFace.Family,Enum.FontWeight.Bold)end
  t.TextScaled=false;t.TextWrapped=true;t.LineHeight=1.12;t.TextStrokeTransparency=font and 1 or .88;return t
 end
 local p
 if short then
  p=Instance.new("ScrollingFrame");p.Name="Leaderboard";p.Position=UDim2.fromOffset(x,y);p.Size=UDim2.fromOffset(w,h)
  p.BackgroundColor3=C.Panel;p.BorderSizePixel=0;p.ScrollBarThickness=4;p.ScrollBarImageColor3=C.Cyan
  p.ScrollingDirection=Enum.ScrollingDirection.Y;p.Parent=ctx.Canvas
 else p=frame(ctx.Canvas,"Leaderboard",x,y,w,h,C.Panel)end
 round(p,16);stroke(p,C.Cyan).Thickness=2;p.ClipsDescendants=true
 ctx.tint(p,Color3.fromRGB(8,49,127),Color3.fromRGB(3,24,67))
 local data=client.Data or {State="Loading",Rows={}};local top=short and 46 or 62
 text(p,"Title","Leaderboard",pad,8,iw,short and 34 or 44,short and 26 or 34)
 local tabW=(iw-96)/2
 local function fixedButton(button)
  for _,o in ipairs(button:GetDescendants())do
   if o:IsA("TextLabel")then o.TextScaled=false;o.TextSize=15;o.TextWrapped=false end
  end
 end
 for i,tab in ipairs({"Global","Server"})do
  local b=ctx.button(p,"Tab"..tab,tab=="Global"and "Global"or "Server",pad+(i-1)*(tabW+6),top,tabW,44,
   function()client:Select(tab)end,C.Raised,C.Text,16)
  ctx.gloss(b,client.Tab==tab and "Purple"or "Navy");fixedButton(b)
 end
 local refresh=ctx.button(p,"Retry",client.Busy and "…"or "Refresh",w-pad-80,top,80,44,function()client:Fetch(true)end,C.Raised,C.Text,15)
 ctx.gloss(refresh,"Navy");fixedButton(refresh)
 local message=({Loading="Loading standings…",Empty="Close a trade to join.",Error="Standings unavailable. Select Refresh.",Stale="Earlier standings · refresh to update"})[data.State]
 message=message or (client.Tab=="Global" and "Top 100 · lifetime net profit"or "This server · lifetime net profit")
 local statusH=height(message,15,iw,BODY)
 text(p,"Status",message,pad,top+50,iw,statusH,15,muted,nil,BODY)
 local listY=top+statusH+58
 local own=data.Your
 local function layout(r,rw)
  local rank=r.ProgressionVersion==Config.ProgressionVersion and Rules.Rank(r.ProgressionRankId)or nil
  local name=r.DisplayName or r.Name or "Player "..tostring(r.UserId or "")
  local rankText=rank and rank.Name or "Loading rank…"
  local nx=112
  local moneyW=narrow and 0 or math.min(300,math.max(220,rw*.33))
  local nw=rw-nx-moneyW-20
  local nameH=height(name,narrow and 18 or 21,nw)
  local rankH=height(rankText,15,nw,BODY)
  local nameBottom=12+nameH+4+rankH
  local rowH=math.max(narrow and 126 or r.Rank and r.Rank<=3 and 112 or 96,nameBottom+(narrow and 48 or 16))
  return {Rank=rank,Name=name,RankText=rankText,NX=nx,NW=nw,NameH=nameH,RankH=rankH,MoneyW=moneyW,Height=rowH}
 end
 local function row(parent,name,r,yy,rw,pinned)
  local l=layout(r,rw);local rowH=l.Height
  local mine=pinned or own and r.UserId==own.UserId
  local medal=({Color3.fromRGB(255,219,112),Color3.fromRGB(210,229,248),Color3.fromRGB(238,181,140)})[r.Rank]
  local tile=frame(parent,name,0,yy,rw,rowH,mine and Color3.fromRGB(43,39,112)or Color3.fromRGB(5,29,74));round(tile,12)
  stroke(tile,mine and C.Cyan or medal or Color3.fromRGB(49,89,147)).Thickness=mine and 2 or 1
  if mine then local rail=frame(tile,"CurrentPlayerAccent",0,12,4,rowH-24,C.Cyan);round(rail,2)end
  tile:SetAttribute("UserId",r.UserId);tile:SetAttribute("Rank",r.Rank);tile:SetAttribute("Cents",r.Cents);tile:SetAttribute("CurrentPlayer",mine==true)
  local placement=frame(tile,"Placement",10,12,42,42,medal or Color3.fromRGB(18,58,109));round(placement,medal and 21 or 10)
  text(placement,"Number",r.Rank and tostring(r.Rank)or "—",0,0,42,42,20,medal and Color3.fromRGB(16,27,57)or C.Text,Enum.TextXAlignment.Center)
  if medal then text(tile,"Podium",({"1ST","2ND","3RD"})[r.Rank],8,59,46,20,13,medal,Enum.TextXAlignment.Center)end
  Art.Create(tile,"RankBadge",l.Rank and l.Rank.Badge,58,12,46)
  if not l.Rank then text(tile,"RankPending","?",61,16,40,40,26,muted,Enum.TextXAlignment.Center)end
  text(tile,"PlayerName",l.Name,l.NX,12,l.NW,l.NameH,narrow and 18 or 21)
  text(tile,"ProgressionRank",l.RankText,l.NX,16+l.NameH,l.NW,l.RankH,15,muted,nil,BODY)
  tile:SetAttribute("ProgressionRankId",l.Rank and l.Rank.Id)
  local score=ctx.money((r.Cents or 0)/100)
  local scoreX=narrow and 62 or rw-l.MoneyW-14
  local scoreW=narrow and rw-76 or l.MoneyW
  local scoreSize=narrow and 20 or 23
  if TextService:GetTextSize(score,scoreSize,NUMBER,Vector2.new(10000,100)).X>scoreW then
   local value=math.abs((r.Cents or 0)/100);local unit=value>=1e12 and 1e12 or value>=1e9 and 1e9 or value>=1e6 and 1e6 or 1e3
   local suffix=unit==1e12 and "T"or unit==1e9 and "B"or unit==1e6 and "M"or "K"
   score=((r.Cents or 0)<0 and "−"or "+").."$"..string.format("%.2f",value/unit)..suffix
  end
  local profit=text(tile,"Profit",score,scoreX,narrow and rowH-38 or 16,scoreW,32,scoreSize,(r.Cents or 0)<0 and loss or gain,Enum.TextXAlignment.Right,NUMBER)
  profit.TextWrapped=false
  if not narrow then text(tile,"ProfitCaption","LIFETIME NET PROFIT",rw-l.MoneyW-14,54,l.MoneyW,24,13,muted,Enum.TextXAlignment.Right,BODY)end
  if mine then text(tile,"YouMarker","YOU",10,rowH-27,44,22,13,C.Cyan,Enum.TextXAlignment.Center)end
  local details=Instance.new("TextButton");details.Name="Details";details.Text="";details.BackgroundTransparency=1;details.Size=UDim2.fromScale(1,1);details.ZIndex=tile.ZIndex+3;details.Parent=tile
  details.Activated:Connect(function()
   local old=p:FindFirstChild("PlayerDetails");if old then old:Destroy()end
   local dw=math.min(iw,540)
   local nameH=height(l.Name,21,dw-80)
   local rankH=height(l.RankText,16,dw-32,BODY)
   local exact=ctx.money((r.Cents or 0)/100)
   local profitH=height(exact,21,dw-32,NUMBER)
   local contentH=nameH+rankH+profitH+92
   local dh=math.min(h-16,contentH)
   local scrollY=short and p.CanvasPosition.Y or 0
   if short then p.ScrollingEnabled=false end
   local panel=frame(p,"PlayerDetails",(w-dw)/2,scrollY+math.max(8,(h-dh)/2),dw,dh,C.Panel);panel.ZIndex=30;round(panel,14);stroke(panel,C.Cyan).Thickness=2
   local content=Instance.new("ScrollingFrame");content.Name="Content";content.BackgroundTransparency=1;content.BorderSizePixel=0
   content.Position=UDim2.fromOffset(0,8);content.Size=UDim2.new(1,0,1,-16);content.CanvasSize=UDim2.fromOffset(0,contentH-16)
   content.ScrollBarThickness=3;content.ZIndex=31;content.Parent=panel
   local a=text(content,"Name",l.Name,16,4,dw-80,nameH,21);a.ZIndex=31
   local b=text(content,"Rank",l.RankText,16,nameH+14,dw-32,rankH,16,muted,nil,BODY);b.ZIndex=31
   local c=text(content,"ExactProfit",exact,16,nameH+rankH+24,dw-32,profitH,21,(r.Cents or 0)<0 and loss or gain,nil,NUMBER);c.ZIndex=31
   local d=text(content,"Caption","Lifetime net profit",16,nameH+rankH+profitH+36,dw-32,26,15,muted,nil,BODY);d.ZIndex=31
   local close=ctx.button(panel,"Close","×",dw-54,8,44,44,function()panel:Destroy();if short then p.ScrollingEnabled=true end end,C.Raised,C.Text,24);close.ZIndex=32
  end)
  return rowH
 end
 local list=Instance.new("ScrollingFrame");list.Name="Rows";list.Position=UDim2.fromOffset(pad,listY)
 list.Size=UDim2.fromOffset(iw,1);list.BackgroundTransparency=1;list.BorderSizePixel=0
 list.ScrollBarThickness=4;list.ScrollBarImageColor3=C.Cyan;list.ScrollingDirection=Enum.ScrollingDirection.Y;list.Parent=p
 local rowW,inset=ctx.insetScroll(list)
 local pinnedH=own and layout(own,rowW).Height+34 or 30
 local footerY=h-pad-pinnedH
 -- Short landscape views keep your standing in the same scrollable list.
 local inline=short or footerY-listY<140
 list.Size=UDim2.fromOffset(iw,math.max(50,(inline and h-pad or footerY-12)-listY))
 local rows=data.Rows or {};local yy=0
 for _,r in ipairs(rows)do yy+=row(list,"Player"..r.UserId,r,yy,rowW,false)+10 end
 if #rows==0 then
  local message=data.State=="Loading"and "Loading standings…"or data.State=="Error"and "Could not load standings. Select Refresh to try again."or "No standings yet. Close a trade to join."
  local eh=height(message,17,rowW,BODY)
  text(list,"Empty",message,0,12,rowW,eh,17,muted,Enum.TextXAlignment.Center,BODY);yy=eh+28
 end
 local standing=frame(inline and list or p,"YourStanding",inline and 0 or pad+inset,inline and yy+10 or footerY,rowW,pinnedH,C.Panel);standing.BackgroundTransparency=1
 text(standing,"Heading",own and "Your standing"or "Loading your standing…",0,0,own and not narrow and 146 or rowW,28,17,C.Cyan)
 if own then
  row(standing,"You",own,34,rowW,true)
  if not own.Rank then
   standing:SetAttribute("PlacementStatus",own.Status)
   if not narrow then text(standing,"StandingStatus",own.Status or "",150,0,rowW-150,28,14,muted,Enum.TextXAlignment.Right,BODY)end
  end
 end
 if inline then yy+=pinnedH+20 end
 list.CanvasSize=UDim2.fromOffset(0,yy+inset*2)
 if short then
  -- Scroll the heading with the rows so a short landscape viewport can show a full row.
  list.Size=UDim2.fromOffset(iw,yy+inset*2);list.ScrollingEnabled=false;list.ScrollBarThickness=0
  p.CanvasSize=UDim2.fromOffset(0,listY+yy+inset*2+pad)
 end
 p:SetAttribute("State",data.State);p:SetAttribute("Tab",client.Tab);p:SetAttribute("RowCount",#rows);return p
end
return View
