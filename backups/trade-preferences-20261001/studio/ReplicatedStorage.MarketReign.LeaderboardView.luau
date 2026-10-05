-- Native responsive leaderboard, using the terminal's Fredoka, outline and glossy-control helpers.
local View={}
function View.Draw(ctx,x,y,w,h,mobile,client)
 local frame,text,round,stroke=ctx.frame,ctx.text,ctx.round,ctx.stroke
 local C=ctx.C local narrow=w<600 local short=h<380
 local compact=short and not narrow
 local p=frame(ctx.Canvas,"Leaderboard",x,y,w,h,C.Panel);round(p,18);stroke(p,C.Cyan).Thickness=3
 p.ClipsDescendants=true
 ctx.tint(p,Color3.fromRGB(8,49,127),Color3.fromRGB(3,24,67))
 local pad=(narrow or short)and 12 or 24;local iw=w-2*pad
 local headerH=short and 32 or narrow and 72 or 88
 if not short then ctx.icon(p,"Trophy",pad,14,narrow and 35 or 56)end
 local tx=short and pad or pad+(narrow and 46 or 74)
 ctx.heading(p,"Title","Leaderboard",tx,short and 0 or 13,compact and 162 or iw-(tx-pad)-80,36,compact and 21 or short and 24 or narrow and 26 or 34)
 local sub=client.Tab=="Global" and "Top 100 · all servers" or "Players in this server"
 if not short then text(p,"Subtitle",sub,tx,narrow and 48 or 53,iw-(tx-pad),20,narrow and 11 or 14,C.Muted)end
 local data=client.Data or {State="Loading",Rows={}}
 if data.Studio and not compact then text(p,"StudioBadge","STUDIO",w-pad-70,12,70,20,11,Color3.fromRGB(255,216,64),nil,Enum.TextXAlignment.Right)end
 local tabsY=compact and 4 or headerH;local tabsX=pad+(compact and 170 or 0)
 local tabW=math.min((iw-(compact and 170 or 0)-88-8)/2,compact and 156 or 190)
 for i,tab in ipairs({"Global","Server"})do
  ctx.gloss(ctx.button(p,"Tab"..tab,tab=="Global"and"Global"or"This Server",tabsX+(i-1)*(tabW+8),tabsY,tabW,40,function()client:Select(tab)end,C.Raised,C.Text,(narrow or compact)and 13 or 17),client.Tab==tab and"Purple"or"Navy")
 end
 local retry=data.State=="Error"or data.State=="Stale"
 ctx.gloss(ctx.button(p,"Retry",retry and"Retry"or client.Busy and"..."or"Refresh",w-pad-76,tabsY,76,40,function()client:Fetch(true)end,C.Raised,C.Text,12),retry and"Cyan"or"Navy")
 local message=({Loading="Loading standings…",Empty="No completed trades yet.",Error="Standings unavailable. Please retry.",Stale="Showing saved results · retry to update."})[data.State]
 if not message then
  message=short and "Lifetime net profit · auto refresh" or "Lifetime net trading profit · all runs and losses included"
  if client.Tab=="Global"and data.SavedAt then message="Lifetime net trading profit · saved "..math.max(0,os.time()-data.SavedAt).."s ago · refreshes every 45s"end
 end
 text(p,"Status",message,pad,tabsY+46,iw,short and 18 or 26,narrow and 10 or 12,retry and Color3.fromRGB(255,214,104)or C.Muted).TextWrapped=true
 local listY=tabsY+(short and 69 or 82)
 local rowH=short and 44 or narrow and 76 or 68
 local pinnedH=short and (narrow and 90 or 64)or narrow and 118 or 98
 local footerY=h-pinnedH-(compact and 8 or pad)
 local function row(parent,name,r,yy,rw,pinned)
  local mine=pinned or data.Your and r.UserId==data.Your.UserId
  local medal=not pinned and r.Rank and ({Color3.fromRGB(255,209,66),Color3.fromRGB(199,222,244),Color3.fromRGB(235,160,102)})[r.Rank]
  local edge=mine and C.Cyan or medal or Color3.fromRGB(29,82,158)
  local medalFill=r.Rank and ({Color3.fromRGB(47,43,66),Color3.fromRGB(29,45,78),Color3.fromRGB(51,36,69)})[r.Rank]
  local tile=frame(parent,name,0,yy,rw,rowH,mine and Color3.fromRGB(40,39,116)or medal and medalFill or Color3.fromRGB(5,30,79));round(tile,12);stroke(tile,edge).Thickness=mine and 2 or 1
  tile:SetAttribute("UserId",r.UserId);tile:SetAttribute("Rank",r.Rank);tile:SetAttribute("Cents",r.Cents);tile:SetAttribute("CurrentPlayer",mine==true)
  local rankW=(narrow or short)and 31 or 48;local avatar=short and 28 or narrow and 36 or 44
  text(tile,"Rank",r.Rank and "#"..r.Rank or "—",5,0,rankW,rowH,narrow and 13 or 19,medal or C.Text,nil,Enum.TextXAlignment.Center)
  local face=Instance.new("ImageLabel");face.Name="Avatar";face.Position=UDim2.fromOffset(rankW+8,short and 8 or 12);face.Size=UDim2.fromOffset(avatar,avatar)
  face.BackgroundColor3=Color3.fromRGB(17,61,125);face.BorderSizePixel=0;face.ZIndex=tile.ZIndex+1
  face.Image=(r.UserId or 0)>0 and ("rbxthumb://type=AvatarHeadShot&id="..r.UserId.."&w=100&h=100")or"";face.Parent=tile;round(face,avatar/2)
  local nx=rankW+avatar+17
  local moneyW=narrow and math.min(132,rw*.4)or math.min(240,rw*.27)
  local tierW=narrow and 0 or 170
  local nw=rw-nx-moneyW-tierW-20
  local playerName=r.DisplayName or r.Name or("Player "..tostring(r.UserId or ""))
  local nameLabel=text(tile,"PlayerName",playerName,nx,short and 1 or 10,nw,24,(narrow or short)and 13 or 18,C.Text)
  nameLabel.TextTruncate=Enum.TextTruncate.AtEnd
  local detail=(mine and "YOU · "or "")..(narrow and (r.Tier or "—").."" or "@"..(r.Name or tostring(r.UserId or "")))
  text(tile,"PlayerDetail",detail,nx,short and 22 or 36,nw,20,(narrow or short)and 10 or 12,mine and C.Cyan or C.Muted).TextTruncate=Enum.TextTruncate.AtEnd
  local profit=text(tile,"Profit",ctx.money((r.Cents or 0)/100),rw-moneyW-tierW-12,short and 0 or 12,moneyW,28,narrow and 17 or 23,(r.Cents or 0)<0 and C.Red or C.Green,nil,Enum.TextXAlignment.Right)
  profit.TextScaled=true
  local constraint=Instance.new("UITextSizeConstraint");constraint.MinTextSize=10;constraint.MaxTextSize=narrow and 17 or 23;constraint.Parent=profit
  text(tile,"ProfitCaption",narrow and "NET PROFIT"or "NET REALIZED",rw-moneyW-tierW-12,short and 27 or 39,moneyW,17,9,C.Muted,nil,Enum.TextXAlignment.Right)
  if not narrow then
   local badge=frame(tile,"Tier",rw-tierW+5,short and 3 or 15,tierW-17,38,Color3.fromRGB(58,35,132));round(badge,10);stroke(badge,Color3.fromRGB(158,109,240))
   local title=text(badge,"Label",r.Tier or "—",4,1,tierW-25,23,14,C.Text,nil,Enum.TextXAlignment.Center);title.TextScaled=true
   text(badge,"Caption","PERMANENT RANK",0,24,tierW-17,11,8,C.Muted,nil,Enum.TextXAlignment.Center)
  end
  return tile
 end
 local list=Instance.new("ScrollingFrame");list.Name="Rows";list.Position=UDim2.fromOffset(pad,listY);list.Size=UDim2.fromOffset(iw,math.max(0,footerY-listY-10))
 list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.ScrollBarImageColor3=C.Cyan;list.ScrollingDirection=Enum.ScrollingDirection.Y;list.Parent=p
 local rowW,inset=ctx.insetScroll(list)
 local rows=data.Rows or {}
 for i,r in ipairs(rows)do row(list,"Player"..tostring(r.UserId),r,(i-1)*(rowH+8),rowW,false)end
 list.CanvasSize=UDim2.fromOffset(0,#rows*(rowH+8)+inset*2)
 if #rows==0 then
  local empty=text(list,"Empty",data.State=="Loading"and"Fetching the latest standings…"or data.State=="Error"and"Your trading progress is safe.\nUse Retry to load the leaderboard."or"Close a trade to join the leaderboard!",0,10,rowW,60,narrow and 13 or 18,C.Muted,nil,Enum.TextXAlignment.Center)
  empty.TextWrapped=true
 end
 local standing=frame(p,"YourStanding",pad,footerY,iw,pinnedH,C.Panel);standing.BackgroundTransparency=1
 local own=data.Your
 local status=own and own.Status or data.State=="Error" and "Standings unavailable" or "Loading…"
 text(standing,"Heading","Your standing",0,0,iw,22,14,C.Cyan)
 local label=text(standing,"StandingStatus",status,0,narrow and 22 or 0,iw,narrow and 18 or 22,narrow and 10 or 12,C.Muted,nil,narrow and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right)
 if own then row(standing,"You",own,narrow and 42 or short and 20 or 28,iw,true)else label.Text=status end
 p:SetAttribute("State",data.State);p:SetAttribute("Tab",client.Tab);p:SetAttribute("RowCount",#rows)
 return p
end
return View
