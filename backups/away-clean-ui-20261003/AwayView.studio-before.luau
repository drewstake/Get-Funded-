-- Live, server-authored absence results. Artwork is decorative only.
local View={}
function View.Draw(ctx,w,h,summary,dismiss)
 local C=ctx.C;local pw=math.min(w-24,620);local ph=math.min(h-24,650);local pad=pw<380 and 14 or 22
 local panel=ctx.frame(ctx.Canvas,"AwayDialog",(w-pw)/2,(h-ph)/2,pw,ph,C.Panel,41)
 ctx.round(panel,18);ctx.stroke(panel,C.Cyan).Thickness=2
 ctx.tint(panel,Color3.fromRGB(6,48,120),Color3.fromRGB(3,24,66))
 local icon=Instance.new("ImageLabel");icon.Name="AwayArtwork";icon.Image="rbxassetid://112099938354389";icon.BackgroundTransparency=1
 icon.Position=UDim2.fromOffset(pad,12);icon.Size=UDim2.fromOffset(44,44);icon.ZIndex=43;icon.Parent=panel
 local function label(parent,name,value,x,y,ww,hh,size,color,font)
  local t=ctx.text(parent,name,value,x,y,ww,hh,size,color or C.Text,font or Enum.Font.GothamMedium,nil,44)
  t.TextWrapped=true;t.TextYAlignment=Enum.TextYAlignment.Top;return t
 end
 label(panel,"Title","While You Were Away",pad+52,14,pw-pad*2-52,54,pw<380 and 21 or 27,C.Text,Enum.Font.FredokaOne)
 local scroll=Instance.new("ScrollingFrame");scroll.Name="Results";scroll.Position=UDim2.fromOffset(pad,78)
 scroll.Size=UDim2.fromOffset(pw-pad*2,ph-148);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=4;scroll.ZIndex=43;scroll.Parent=panel
 local iw=pw-pad*2-10;local yy=0
 local function copy(name,value,size,color,font)
  local th=game:GetService("TextService"):GetTextSize(value,size,font or Enum.Font.GothamMedium,Vector2.new(iw-4,10000)).Y+10
  label(scroll,name,value,0,yy,iw,th,size,color,font);yy+=th+5
 end
 local secs=summary.Seconds or 0
 local elapsed=secs>=86400 and string.format("%dd %dh",secs//86400,secs%86400//3600)or secs>=3600 and string.format("%dh %dm",secs//3600,secs%3600//60)or secs>=60 and string.format("%dm %ds",secs//60,secs%60)or string.format("%ds",secs)
 copy("TimeAway","Away for "..elapsed,14,C.Muted)
 copy("Total",ctx.signed(summary.Total or 0).." during your absence",24,(summary.Total or 0)<0 and C.Red or C.Green,Enum.Font.FredokaOne)
 copy("RealizedChange","Realized change since disconnect: "..ctx.signed(summary.RealizedChange or 0),16,(summary.RealizedChange or 0)<0 and C.Red or C.Green)
 copy("UnrealizedChange","Unrealized change on open trades: "..ctx.signed(summary.UnrealizedChange or 0),16,(summary.UnrealizedChange or 0)<0 and C.Red or C.Green)
 copy("Booked","Booked P&L: "..ctx.signed(summary.Realized or 0).." (includes "..ctx.signed(summary.CarriedIn or 0).." earned before disconnect).",13,C.Muted)
 yy+=8
 for i,row in ipairs(summary.Rows or {})do
  copy("Trade"..i,row.Contract.." · "..(row.Direction>0 and "Long "or "Short ")..row.Quantity.." · "..row.Remaining.." still open",17,C.Text,Enum.Font.FredokaOne)
  copy("Change"..i,"Since disconnect: "..ctx.signed(row.RealizedChange+row.UnrealizedChange),15,row.RealizedChange+row.UnrealizedChange<0 and C.Red or C.Green)
  for j,exit in ipairs(row.Exits or {})do
   copy("Exit"..i.."_"..j,exit.Reason.." · "..exit.Quantity.." closed @ "..string.format("%.2f",exit.Notional/exit.Quantity).." · "..ctx.signed(exit.Change).." since disconnect",13,C.Muted)
  end
  yy+=8
 end
 copy("Coverage",summary.Coverage or "",12,C.Muted)
 scroll.CanvasSize=UDim2.fromOffset(0,yy)
 local b=ctx.button(panel,"Continue","Continue",pad,ph-58,pw-pad*2,44,dismiss,C.Raised,C.Text,20,45)
 ctx.gloss(b,"Purple")
 panel:SetAttribute("SummaryId",summary.Id);panel:SetAttribute("Total",summary.Total)
 return panel
end
return View
