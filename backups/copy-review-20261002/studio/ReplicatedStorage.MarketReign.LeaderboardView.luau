-- Numeric placement and permanent rank are separate; old snapshots never guess a rank.
local Art=require(script.Parent.BadgeArt)
local Rules=require(script.Parent.ProgressionRules)
local Config=require(script.Parent.ProgressionConfig)
local TextService=game:GetService("TextService")
local View={}
function View.Draw(ctx,x,y,w,h,mobile,client)
 local frame,round,stroke=ctx.frame,ctx.round,ctx.stroke;local C=ctx.C
 local narrow=w<620;local short=h<400;local pad=narrow and 12 or 20;local iw=w-pad*2
 local function text(p,name,value,xx,yy,ww,hh,size,color,align)
  local t=ctx.text(p,name,value,xx,yy,ww,hh,size,color or C.Text,Enum.Font.FredokaOne,align)
  t.TextScaled=false;t.TextWrapped=true;t.TextStrokeTransparency=.65;return t
 end
 local p=frame(ctx.Canvas,"Leaderboard",x,y,w,h,C.Panel);round(p,16);stroke(p,C.Cyan).Thickness=2;p.ClipsDescendants=true
 ctx.tint(p,Color3.fromRGB(8,49,127),Color3.fromRGB(3,24,67))
 local data=client.Data or {State="Loading",Rows={}};local top=short and 38 or 56
 text(p,"Title","Leaderboard",pad,8,iw,short and 28 or 38,short and 24 or 32)
 local tabW=(iw-90)/2
 for i,tab in ipairs({"Global","Server"})do
  ctx.gloss(ctx.button(p,"Tab"..tab,tab=="Global"and "Global"or "Server",pad+(i-1)*(tabW+6),top,tabW,40,
   function()client:Select(tab)end,C.Raised,C.Text,15),client.Tab==tab and "Purple"or "Navy")
 end
 ctx.gloss(ctx.button(p,"Retry",client.Busy and "…"or "Refresh",w-pad-76,top,76,40,function()client:Fetch(true)end,C.Raised,C.Text,13),"Navy")
 local message=({Loading="Loading standings…",Empty="Close a trade to join.",Error="Standings unavailable. Tap Refresh.",Stale="Saved results · refresh to update"})[data.State]
 message=message or (client.Tab=="Global" and "Top 100 · lifetime net trading profit"or "This server · lifetime net trading profit")
 text(p,"Status",message,pad,top+45,iw,short and 20 or 36,13,C.Muted)
 local listY=top+(short and 69 or 88)
 local rowH=narrow and 112 or 82
 local own=data.Your
 local pinnedH=own and rowH+30 or 30
 local footerY=h-pad-pinnedH
 -- Very short landscape view uses one scrollable list, including your standing at the end.
 local inline=footerY-listY<rowH
 local function row(parent,name,r,yy,rw,pinned)
  local mine=pinned or own and r.UserId==own.UserId
  local medal=({Color3.fromRGB(255,217,75),Color3.fromRGB(208,230,250),Color3.fromRGB(240,176,120)})[r.Rank]
  local tile=frame(parent,name,0,yy,rw,rowH,mine and Color3.fromRGB(49,35,115)or Color3.fromRGB(5,29,74));round(tile,12)
  stroke(tile,mine and C.Cyan or medal or Color3.fromRGB(39,79,139)).Thickness=mine and 2 or 1
  tile:SetAttribute("UserId",r.UserId);tile:SetAttribute("Rank",r.Rank);tile:SetAttribute("Cents",r.Cents);tile:SetAttribute("CurrentPlayer",mine==true)
  local placement=frame(tile,"Placement",8,12,36,36,medal or Color3.fromRGB(18,58,109));round(placement,medal and 18 or 8)
  text(placement,"Number",r.Rank and tostring(r.Rank)or "—",0,0,36,36,17,medal and Color3.fromRGB(16,27,57)or C.Text,Enum.TextXAlignment.Center)
  if medal then text(tile,"Podium",({"1ST","2ND","3RD"})[r.Rank],5,49,42,18,12,medal,Enum.TextXAlignment.Center)end
  local rank=r.ProgressionVersion==Config.ProgressionVersion and Rules.Rank(r.ProgressionRankId)or nil
  Art.Create(tile,"RankBadge",rank and rank.Badge,49,10,48)
  if not rank then text(tile,"RankPending","?",53,14,40,40,26,C.Muted,Enum.TextXAlignment.Center)end
  local nx=105;local moneyW=narrow and 0 or math.min(280,rw*.32);local nw=rw-nx-moneyW-16
  local playerName=r.DisplayName or r.Name or "Player "..tostring(r.UserId or "")
  local t=text(tile,"PlayerName",playerName,nx,7,nw,narrow and 37 or 28,narrow and 16 or 19)
  t.TextTruncate=Enum.TextTruncate.AtEnd
  local rankText=rank and rank.Name or "Rank updating…"
  local rt=text(tile,"ProgressionRank",rankText,nx,narrow and 44 or 37,nw,narrow and 36 or 26,14,C.Muted)
  tile:SetAttribute("ProgressionRankId",rank and rank.Id)
  local score=ctx.money((r.Cents or 0)/100)
  local scoreX=narrow and 10 or rw-moneyW-12;local scoreY=narrow and 79 or 12;local scoreW=narrow and rw-20 or moneyW
  local scoreSize=narrow and 21 or 24
  if TextService:GetTextSize(score,scoreSize,Enum.Font.FredokaOne,Vector2.new(10000,100)).X>scoreW then
   local value=math.abs((r.Cents or 0)/100);local unit=value>=1e12 and 1e12 or value>=1e9 and 1e9 or value>=1e6 and 1e6 or 1e3
   local suffix=unit==1e12 and "T"or unit==1e9 and "B"or unit==1e6 and "M"or "K"
   score=((r.Cents or 0)<0 and "−"or "+").."$"..string.format("%.2f",value/unit)..suffix
  end
  text(tile,"Profit",score,scoreX,scoreY,scoreW,27,scoreSize,(r.Cents or 0)<0 and C.Red or C.Green,Enum.TextXAlignment.Right)
  if not narrow then text(tile,"ProfitCaption","NET PROFIT",rw-moneyW-12,45,moneyW,20,12,C.Muted,Enum.TextXAlignment.Right)end
  if mine then text(tile,"YouMarker","YOU",8,narrow and 81 or 61,44,18,12,C.Cyan)end
  local details=Instance.new("TextButton");details.Name="Details";details.Text="";details.BackgroundTransparency=1;details.Size=UDim2.fromScale(1,1);details.ZIndex=tile.ZIndex+3;details.Parent=tile
  details.Activated:Connect(function()
   local old=p:FindFirstChild("PlayerDetails");if old then old:Destroy()end
   local dh=210;local dw=math.min(iw,520)
   local panel=frame(p,"PlayerDetails",(w-dw)/2,math.max(8,(h-dh)/2),dw,dh,C.Panel);panel.ZIndex=30;round(panel,14);stroke(panel,C.Cyan).Thickness=2
   local a=text(panel,"Name",playerName,16,12,dw-76,52,19);a.ZIndex=31
   local b=text(panel,"Rank",rankText,16,69,dw-32,34,16,C.Muted);b.ZIndex=31
   local c=text(panel,"ExactProfit",ctx.money((r.Cents or 0)/100),16,110,dw-32,54,20,C.Green);c.ZIndex=31
   local d=text(panel,"Caption","Lifetime net trading profit",16,168,dw-32,24,14,C.Muted);d.ZIndex=31
   local close=ctx.button(panel,"Close","×",dw-54,8,44,44,function()panel:Destroy()end,C.Raised,C.Text,24);close.ZIndex=32
  end)
  return tile
 end
 local list=Instance.new("ScrollingFrame");list.Name="Rows";list.Position=UDim2.fromOffset(pad,listY)
 list.Size=UDim2.fromOffset(iw,math.max(50,(inline and h-pad or footerY-10)-listY));list.BackgroundTransparency=1;list.BorderSizePixel=0
 list.ScrollBarThickness=4;list.ScrollBarImageColor3=C.Cyan;list.ScrollingDirection=Enum.ScrollingDirection.Y;list.Parent=p
 local rowW,inset=ctx.insetScroll(list);local rows=data.Rows or {};local yy=0
 for _,r in ipairs(rows)do row(list,"Player"..r.UserId,r,yy,rowW,false);yy+=rowH+8 end
 if #rows==0 then
  text(list,"Empty",data.State=="Loading"and "Fetching standings…"or data.State=="Error"and "Your progress is safe. Tap Refresh to try again."or "Close a trade to join the leaderboard!",0,12,rowW,70,17,C.Muted,Enum.TextXAlignment.Center);yy=90
 end
 local standing=frame(inline and list or p,"YourStanding",inline and 0 or pad,inline and yy+10 or footerY,inline and rowW or iw,pinnedH,C.Panel);standing.BackgroundTransparency=1
 text(standing,"Heading",own and "Your standing"or "Loading your standing…",0,0,standing.Size.X.Offset,24,15,C.Cyan)
 if own then
  row(standing,"You",own,30,standing.Size.X.Offset,true)
  if not own.Rank then
   -- Keep placement status separate from the progression title.
   standing:SetAttribute("PlacementStatus",own.Status)
   if not narrow then text(standing,"StandingStatus",own.Status or "",140,0,standing.Size.X.Offset-140,24,12,C.Muted,Enum.TextXAlignment.Right)end
  end
 end
 if inline then yy+=pinnedH+20 end
 list.CanvasSize=UDim2.fromOffset(0,yy+inset*2)
 for _,o in ipairs(p:GetDescendants())do if o:IsA("TextLabel")or o:IsA("TextButton")then o.TextScaled=false;o.Font=Enum.Font.FredokaOne end end
 p:SetAttribute("State",data.State);p:SetAttribute("Tab",client.Tab);p:SetAttribute("RowCount",#rows);return p
end
return View
