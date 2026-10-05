-- Native implementation of output/imagegen/while-you-were-away-clean-v1.png.
-- Every amount comes from the server's absence summary, including the expanded audit details.
local TextService=game:GetService("TextService")
local View={}
local FONT=Enum.Font.FredokaOne
local LEFT,CENTER,RIGHT=Enum.TextXAlignment.Left,Enum.TextXAlignment.Center,Enum.TextXAlignment.Right
function View.Draw(ctx,w,h,summary,dismiss)
 local C=ctx.C
 local scale=math.min((w-24)/360,1.28)
 local compact=h-24<474*scale
 if compact then scale=math.min(scale,1)end
 local function px(n)return math.round(n*scale)end
 local pw=px(360)
 local baseHeight=math.min(h-24,px(compact and 356 or 474)+(compact and 0 or math.max(0,44-px(42))+2))
 local pad=px(22);local iw=pw-2*pad
 local panel=ctx.frame(ctx.Canvas,"AwayDialog",(w-pw)/2,(h-baseHeight)/2,pw,baseHeight,Color3.new(1,1,1),41)
 panel:SetAttribute("StaticButtons",true)
 ctx.round(panel,px(20));ctx.stroke(panel,C.Cyan).Thickness=2
 ctx.tint(panel,Color3.fromRGB(5,37,94),Color3.fromRGB(2,18,52))
 local function label(parent,name,value,x,y,ww,hh,size,color,align)
  local t=ctx.text(parent,name,value,x,y,ww,hh,size,color or C.Text,FONT,align or LEFT,44)
  t.TextStrokeTransparency=1
  return t
 end
 local function fit(t,size)
  t.TextScaled=true
  local constraint=Instance.new("UITextSizeConstraint");constraint.MinTextSize=10;constraint.MaxTextSize=size;constraint.Parent=t
  return t
 end
 local function color(n)return n<0 and C.Red or n>0 and C.Green or C.Muted end
 local secs=math.max(0,math.floor(summary.Seconds or 0))
 local elapsed=secs>=86400 and string.format("%dd %dh",secs//86400,secs%86400//3600)
  or secs>=3600 and string.format("%dh %dm",secs//3600,secs%3600//60)
  or secs>=60 and string.format("%dm %ds",secs//60,secs%60)or string.format("%ds",secs)

 -- Native shapes reproduce the mockup's purple clock without a raster dependency.
 local clockSize=px(compact and 40 or 56)
 local clock=ctx.frame(panel,"AwayArtwork",px(compact and 25 or 44),px(compact and 16 or 42),clockSize,clockSize,Color3.new(1,1,1),43)
 ctx.round(clock,clockSize/2);ctx.tint(clock,Color3.fromRGB(177,93,255),Color3.fromRGB(102,36,243))
 local inset=math.max(4,px(compact and 5 or 7))
 local face=ctx.frame(clock,"Face",inset,inset,clockSize-2*inset,clockSize-2*inset,Color3.fromRGB(10,27,74),44);ctx.round(face,clockSize/2)
 local function hand(name,x,y,ww,hh,rotation)
  local f=ctx.frame(clock,name,x,y,ww,hh,C.Text,45);ctx.round(f,ww/2);f.Rotation=rotation or 0
 end
 hand("Minute",clockSize*.45,clockSize*.23,clockSize*.10,clockSize*.31)
 hand("Hour",clockSize*.46,clockSize*.48,clockSize*.27,clockSize*.10,20)
 for i,ray in ipairs({{.86,-.24,.09,.25,20},{1.12,-.08,.09,.23,48},{1.23,.20,.19,.08,0}})do
  local f=ctx.frame(clock,"Ray"..i,clockSize*ray[1],clockSize*ray[2],clockSize*ray[3],clockSize*ray[4],C.Cyan,44)
  ctx.round(f,px(3));f.Rotation=ray[5]
 end
 local titleX=px(compact and 82 or 128)
 fit(label(panel,"Title",compact and "While you were away"or "While you\nwere away",titleX,px(compact and 13 or 26),pw-titleX-px(18),px(compact and 28 or 66),px(compact and 23 or 32)),px(compact and 23 or 32))
 fit(label(panel,"TimeAway","Away for "..elapsed,titleX,px(compact and 43 or 96),pw-titleX-px(18),px(23),px(compact and 14 or 16),C.Muted),px(compact and 14 or 16))

 local bodyTop=px(compact and 68 or 136)
 local body=Instance.new("ScrollingFrame");body.Name="Results";body.Position=UDim2.fromOffset(pad,bodyTop)
 body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=0;body.ScrollBarImageColor3=C.Muted
 body.ScrollingDirection=Enum.ScrollingDirection.Y;body.ClipsDescendants=true;body.ZIndex=43;body.Parent=panel
 body:SetAttribute("StaticButtons",true)
 local total=summary.Total or 0
 label(body,"NetChange","Net change",0,0,iw,px(compact and 18 or 22),px(compact and 14 or 16),C.Muted,CENTER)
 fit(label(body,"Total",ctx.signed(total),0,px(compact and 18 or 24),iw,px(compact and 42 or 58),px(compact and 38 or 48),color(total),CENTER),px(compact and 38 or 48))
 label(body,"SinceLeft","Since you left",0,px(compact and 60 or 84),iw,px(22),px(compact and 13 or 15),C.Muted,CENTER)
 local function rule(name,y)
  local f=ctx.frame(body,name,0,px(y),iw,1,C.Border,43);f.BackgroundTransparency=.25
 end
 rule("SummaryDivider",compact and 84 or 106)
 local function amountRow(name,title,value,y)
  label(body,name.."Label",title,px(6),px(y),iw*.48,px(compact and 24 or 28),px(compact and 15 or 17))
  fit(label(body,name,ctx.signed(value),iw*.48,px(y),iw*.52-px(6),px(compact and 24 or 28),px(compact and 17 or 19),color(value),RIGHT),px(compact and 17 or 19))
 end
 amountRow("RealizedChange","Closed trades",summary.RealizedChange or 0,compact and 92 or 124)
 amountRow("UnrealizedChange","Open trades",summary.UnrealizedChange or 0,compact and 117 or 156)
 rule("DetailsDivider",compact and 146 or 190)

 local rows=summary.Rows or {};local state=ctx.State or {}
 local expanded=state.AwayDetailsId==summary.Id and summary.Id~=nil
 local toggleY=px(compact and 153 or 204);local toggleH=math.max(44,px(42))
 local contentBottom=toggleY+toggleH
 local details=ctx.frame(body,"TradeDetails",0,contentBottom+px(12),iw,0,C.Panel,43);details.BackgroundTransparency=1
 local yy=0;local detailWidth=iw-px(12)
 local function copy(name,value,size,tone)
  local fontSize=px(size)
  local height=TextService:GetTextSize(value,fontSize,FONT,Vector2.new(detailWidth,10000)).Y+px(8)
  local t=label(details,name,value,px(6),yy,detailWidth,height,fontSize,tone)
  t.TextWrapped=true;t.TextYAlignment=Enum.TextYAlignment.Top;yy+=height+px(4)
 end
 if #rows==0 then copy("Empty","No trades changed while you were away.",14,C.Muted)end
 for i,row in ipairs(rows)do
  if i>1 then yy+=px(10)end
  copy("Trade"..i,row.Contract.." · "..(row.Direction>0 and "Long "or "Short ")..row.Quantity,17)
  local change=(row.RealizedChange or 0)+(row.UnrealizedChange or 0)
  copy("Change"..i,ctx.signed(change).." since you left · "..(row.Remaining or 0).." still open",14,color(change))
  for j,exit in ipairs(row.Exits or {})do
   local quantity=exit.Quantity or 0
   local price=quantity>0 and string.format("%.2f",(exit.Notional or 0)/quantity)or "—"
   copy("Exit"..i.."_"..j,exit.Reason.." · "..quantity.." closed @ "..price.." · "..ctx.signed(exit.Change or 0).." since you left",13,C.Muted)
  end
 end
 yy+=px(8)
 copy("Booked","Booked P&L: "..ctx.signed(summary.Realized or 0).." (includes "..ctx.signed(summary.CarriedIn or 0).." from before you left).",12,C.Muted)
 if summary.Coverage and summary.Coverage~=""then copy("Coverage",summary.Coverage,12,C.Muted)end
 details.Size=UDim2.fromOffset(iw,yy)
 local toggle,chevron,disclosure,continue
 local function layout()
  state.AwayDetailsId=expanded and summary.Id or nil
  local extra=expanded and math.min(px(210),math.max(0,h-24-baseHeight))or 0
  local ph=baseHeight+extra
  panel.Position=UDim2.fromOffset((w-pw)/2,(h-ph)/2);panel.Size=UDim2.fromOffset(pw,ph)
  local buttonH=compact and 44 or px(60);local buttonY=ph-px(compact and 12 or 16)-buttonH
  continue.Position=UDim2.fromOffset(pad-px(4),buttonY)
  local viewportH=buttonY-px(14)-bodyTop
  body.Size=UDim2.fromOffset(iw,viewportH)
  local canvasH=contentBottom+(expanded and px(12)+yy or 0)
  body.CanvasSize=UDim2.fromOffset(0,canvasH)
  body.ScrollBarThickness=canvasH>viewportH and 3 or 0
  if not expanded then body.CanvasPosition=Vector2.zero end
  details.Visible=expanded
  disclosure.Text=#rows==0 and(expanded and "Hide details"or "View details")or(expanded and "Hide "or "View ")..#rows..(#rows==1 and " trade"or " trades")
  chevron.Rotation=expanded and 180 or 0
  panel:SetAttribute("DetailsExpanded",expanded)
 end
 toggle=ctx.button(body,"ToggleDetails","",px(1),toggleY,iw-px(2),toggleH,function()expanded=not expanded;layout()end,Color3.new(1,1,1),C.Text,px(17),45)
 ctx.tint(toggle,Color3.fromRGB(12,38,91),Color3.fromRGB(7,28,71));toggle:SetAttribute("RestingColor",Color3.new(1,1,1))
 toggle.Corners.CornerRadius=UDim.new(0,px(10));toggle.Border.Thickness=1.5
 disclosure=label(toggle,"Label","",px(14),0,iw-px(62),toggleH,px(17));disclosure.ZIndex=46
 chevron=ctx.frame(toggle,"Chevron",iw-px(35),toggleH/2-px(5),px(12),px(10),C.Text,46);chevron.BackgroundTransparency=1
 for i,rotation in ipairs({45,-45})do
  local arm=ctx.frame(chevron,"Arm"..i,px(i==1 and 0 or 5),px(3),px(8),px(3),C.Text,46);arm.Rotation=rotation;ctx.round(arm,px(1))
 end
 continue=ctx.button(panel,"Continue","Continue",pad-px(4),0,iw+px(8),compact and 44 or px(60),dismiss,C.Raised,C.Text,px(compact and 23 or 27),45)
 ctx.gloss(continue,"Purple");continue.Corners.CornerRadius=UDim.new(0,px(14));continue.Border.Thickness=px(3)
 layout()
 panel:SetAttribute("SummaryId",summary.Id);panel:SetAttribute("Total",total);panel:SetAttribute("TradeCount",#rows)
 return panel
end
return View
