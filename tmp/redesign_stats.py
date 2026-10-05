from pathlib import Path
p=Path(__file__).resolve().parents[1]/'src/StatsView.luau'
s=p.read_text(encoding='utf-8')
s=s.replace('local period=(scope and scope.Kind~="Legacy" and state.StatsPeriod=="Current") and "Current" or "Life"\n return scope,scope and scope[period],period,list', '''local period=state.StatsPeriod=="Dated" and "Dated" or (scope and scope.Kind~="Legacy" and state.StatsPeriod=="Current") and "Current" or "Life"
 local agg=scope and (period=="Dated" and scope.Life.Dated or scope[period])
 return scope,agg or (scope and scope.Life),period,list''')
s=s.replace('local a=agg.Attempts or 0','''if period=="Dated" then return "Only closed trades with saved calendar dates, across all attempts (including blown accounts). All six cards use this same dated history." end
 local a=agg.Attempts or 0''')
s=s.replace('"Your trading performance across funded accounts and restarts · calculated by the exchange server"', '"Closed trades · saved across restarts · calculated by the exchange server"')
s=s.replace('if scope.Kind~="Legacy" then\n  local segW=narrow and (cw-8)/2 or math.min(300,(cw-8)/2)', 'if scope then\n  local segW=(cw-16)/3')
s=s.replace('{{"Life",narrow and "Lifetime" or "Lifetime · all attempts"},{"Current",current}}', '{{"Life",narrow and "Lifetime" or "Lifetime · all attempts"},{"Current",scope.Kind=="Legacy" and "Lifetime practice" or current},{"Dated","Dated history"}}')
s=s.replace('narrow and 13 or 15','narrow and 11 or 15')
s=s.replace('.."  ·  "..(scope.Kind=="Legacy" and "LIFETIME" or period=="Life" and "LIFETIME · INCLUDES RESTARTS" or "CURRENT ATTEMPT ONLY")', '.."  ·  "..(period=="Dated" and "DATED HISTORY" or scope.Kind=="Legacy" and "LIFETIME" or period=="Life" and "LIFETIME · INCLUDES RESTARTS" or "CURRENT ATTEMPTS").." · UTC DAYS"')
s=s.replace('local coverage=View.Coverage(agg,sgn)', '''local coverage=View.Coverage(agg,sgn)
 if (agg.UndatedTrades or 0)>0 or agg.CountUnknown then
  coverage=(coverage and coverage.." " or "").."Earlier trades have no calendar date. Daily metrics are unavailable for this scope; Dated history applies the same dated-trades filter to all six cards."
 elseif period=="Dated" and agg.FirstClosedAt then
  coverage="From "..os.date("!%Y-%m-%d",agg.FirstClosedAt).." through today (UTC). Earlier undated results remain in Lifetime."
 end''')
start=s.index(' -- Headline P&L and blown accounts.')
s=s[:start]+r''' -- Six reference-style cards, sharing exactly the scope selected above.
 local blue=Color3.fromRGB(0,112,255)
 local green,pink=Color3.fromRGB(34,255,164),Color3.fromRGB(255,94,151)
 local cyan=Color3.fromRGB(151,230,255)
 local neutral=Color3.fromRGB(42,85,148)
 local metricCols=cw>=940 and 3 or cw>=620 and 2 or 1
 local kw=(cw-gap*(metricCols-1))/metricCols
 local kh=math.clamp(kw*.49,218,254)
 sc:SetAttribute("MetricColumns",metricCols)
 local complete=not agg.Partial and not agg.CountUnknown
 local function ratio(v) return v and string.format("%.2f",v) or "—" end
 local function percent(v) return v and string.format("%.2f%%",v*100) or "—" end
 local noLoss=complete and agg.NoLosses
 local metrics={
  {"Total","Total P&L",sgn(agg.Net),valueColor(agg.Net,true),"Net realized · closed trades only",
   "Net realized profit or loss from closed trades. Open positions, starting capital, unlocks and resets are excluded. Blown attempts remain in Lifetime."},
  {"TradeWin","Trade Win %",complete and percent(agg.WinRate) or "—",C.Text,
   complete and (commas(agg.Wins).." wins / "..commas(agg.Trades).." closed · "..commas(agg.Even).." even") or "Earlier trade breakdown unavailable",
   "Winning closing fills divided by all closing fills. Break-even fills count in the denominator. Partial closes count per closing fill, matching Trade History."},
  {"Average","Avg Win / Avg Loss",complete and (noLoss and "∞" or ratio(agg.WinLossRatio)) or "—",C.Text,
   noLoss and "No losing trades" or agg.Trades==0 and "No closed trades" or not agg.AvgLoss and "No losing trades" or "Average win ÷ absolute average loss",
   "Average winning P&L divided by the absolute average losing P&L. Both dollar averages are shown. ∞ means positive wins with no losses; — means no usable denominator."},
  {"DayWin","Day Win %",percent(agg.DayWinRate),C.Text,
   agg.DailyComplete and (commas(agg.WinningDays or 0).." profitable / "..commas(agg.DayCount or 0).." trading days") or "Calendar dates missing · see Dated history",
   "Profitable trading days divided by days with closed trades, including losing and break-even days. Each day is midnight-to-midnight UTC. Accounts are combined by date within this scope."},
  {"Factor","Profit Factor",complete and (noLoss and "∞" or ratio(agg.ProfitFactor)) or "—",C.Text,
   noLoss and "No gross losses" or "Gross wins ÷ absolute gross losses",
   "Sum of positive closed P&L divided by the absolute sum of negative closed P&L. ∞ means positive gains and zero losses. With no gains or losses, the ratio is unavailable."},
  {"BestDay","Best Day % of Total Profit",percent(agg.BestDayShare),C.Text,
   not agg.DailyComplete and "Calendar dates missing · see Dated history" or agg.Net<=0 and "Requires positive total net profit" or agg.BestDay and ("Best day "..sgn(agg.BestDay)) or "No closed trades",
   "Highest net daily profit divided by total net realized profit in this scope. UTC days. It can exceed 100% when other days lose money. Unavailable if total net profit is zero/negative or dates are missing."},
 }
 -- One accessible help panel. A 44px question target supports hover, keyboard focus and tap.
 local help=ctx.frame(sc,"MetricHelp",0,0,cw,100,Color3.fromRGB(4,25,76),50)
 ctx.round(help,16) ctx.stroke(help,cyan).Thickness=2 help.Visible=false
 local helpTitle=ctx.text(help,"Title","",16,12,cw-70,28,20,cyan,FONT,nil,51)
 local helpBody=ctx.text(help,"Body","",16,46,cw-32,50,15,C.Text,FONT,nil,51)
 helpBody.TextWrapped=true helpBody.TextYAlignment=TOP
 local helpClose=ctx.button(help,"Close","×",cw-50,4,44,44,function() s.StatsHelp=nil help.Visible=false end,false,C.Text,24,52)
 local helpY=yy+math.ceil(#metrics/metricCols)*(kh+gap)+2
 help.Position=UDim2.fromOffset(0,helpY)
 local function showHelp(index)
  local m=metrics[index]
  helpTitle.Text=m[2] helpTitle.TextSize=cw<400 and 15 or 20
  helpTitle.TextScaled=true
  helpBody.Text=m[6]
  local hh=measure(m[6],15,cw-32)+64
  helpBody.Size=UDim2.fromOffset(cw-32,hh-58)
  help.Size=UDim2.fromOffset(cw,hh) help.Visible=true
  sc.CanvasSize=UDim2.fromOffset(0,helpY+hh+38)
 end
 local function ring(parent,name,cx,cy,radius,thick,greenShare,lossShare,half)
  local n=half and 54 or 80
  local arc=half and math.pi or 2*math.pi
  local start=half and math.pi or -math.pi/2
  local container=ctx.frame(parent,name,0,0,kw,kh,C.Panel,4) container.BackgroundTransparency=1
  for i=1,n do
   local t=(i-.5)/n
   local color=neutral
   if greenShare then
    -- Semicircles put profits at the right, like the reference. Breakeven stays neutral.
    local sample=half and 1-t or t
    color=sample<greenShare and green or sample<greenShare+(lossShare or 0) and pink or neutral
   end
   local angle=start+t*arc
   local seg=ctx.frame(container,"Segment",cx+math.cos(angle)*radius,cy+math.sin(angle)*radius,thick,arc*radius/n+1.5,color,4)
   seg.AnchorPoint=Vector2.new(.5,.5) seg.Rotation=math.deg(angle) ctx.round(seg,thick/2)
  end
  return container
 end
 for i,m in ipairs(metrics) do
  local col,row=(i-1)%metricCols,math.floor((i-1)/metricCols)
  local tile=ctx.card(sc,"Metric"..m[1],col*(kw+gap),yy+row*(kh+gap),kw,kh,
   i==1 and Color3.fromRGB(93,34,249) or Color3.fromRGB(5,51,142),
   i==1 and Color3.fromRGB(40,14,181) or Color3.fromRGB(3,25,77),
   i==1 and Color3.fromRGB(156,108,255) or blue,true)
  tile.Border.Thickness=4 tile.Corners.CornerRadius=UDim.new(0,20)
  local label=ctx.value(tile,"Label",m[2],16,14,kw-74,66,kw>=440 and 28 or 23,cyan,mobile)
  label.TextXAlignment=LEFT label.TextWrapped=true
  local q=ctx.button(tile,"Help","?",kw-56,14,44,44,function()
   if s.StatsHelp==i then s.StatsHelp=nil help.Visible=false else s.StatsHelp=i showHelp(i) sc.CanvasPosition=Vector2.new(0,math.max(0,helpY-h+help.Size.Y.Offset+12)) end
  end,false,cyan,24,8)
  local function hover() if not s.StatsHelp then showHelp(i) end end
  local function leave() if not s.StatsHelp then help.Visible=false end end
  q.MouseEnter:Connect(hover) q.MouseLeave:Connect(leave) q.SelectionGained:Connect(hover) q.SelectionLost:Connect(leave)
  local chart=i==2 or i==3 or i==4 or i==5
  local vw=chart and kw*.48-16 or kw-32
  local val=ctx.value(tile,"Value",m[3],16,96,vw,65,i==1 and 58 or kw>=440 and 46 or 36,m[4],mobile)
  val.TextXAlignment=LEFT val.TextScaled=true
  local cap=ctx.text(tile,"Caption",m[5],16,kh-44,kw-32,36,kw<360 and 12 or 14,soft,FONT,nil,6)
  cap.TextWrapped=true
  if i==2 or i==4 then
   local rate=i==2 and complete and agg.WinRate or i==4 and agg.DayWinRate or nil
   local losing=i==2 and agg.Trades>0 and agg.Losses/agg.Trades or i==4 and rate and (1-rate) or 0
   local r=math.min(kw*.205,81)
   ring(tile,"Gauge",kw*.745,163,r,math.max(12,r*.23),rate,losing,true)
  elseif i==3 then
   local gx,gw=kw*.50,kw*.45-12
   local total=(agg.AvgWin or 0)+(agg.AvgLoss or 0)
   local track=ctx.frame(tile,"AverageBar",gx,96,gw,16,neutral,5) ctx.round(track,8)
   if complete and total>0 then
    local winW=gw*(agg.AvgWin or 0)/total
    if winW>0 then local f=ctx.frame(track,"Win",0,0,winW,16,green,5) ctx.round(f,8) end
    if winW<gw then local f=ctx.frame(track,"Loss",winW,0,gw-winW,16,pink,5) ctx.round(f,8) end
   end
   for j,v in ipairs({{agg.AvgWin,green},{agg.AvgLoss,pink}})do
    local t=ctx.value(tile,j==1 and"AvgWin"or"AvgLoss",complete and v[1] and ((j==2 and "−" or "")..money(v[1])) or "—",gx,116+(j-1)*27,gw,25,18,v[2],mobile)
    t.TextXAlignment=LEFT t.TextScaled=true
   end
  elseif i==5 then
   local gross=agg.Gains+agg.Loss local share=complete and gross>0 and agg.Gains/gross or nil
   ring(tile,"Donut",kw*.73,122,math.min(kw*.11,41),13,share,share and 1-share or 0,false)
   local g=ctx.value(tile,"GrossWin",money(agg.Gains),kw*.47,167,kw*.24,21,14,green,mobile) g.TextScaled=true
   local l=ctx.value(tile,"GrossLoss","−"..money(agg.Loss),kw*.72,167,kw*.24-12,21,14,pink,mobile) l.TextScaled=true
  end
 end
 yy=helpY
 -- Reserve enough space for hover help without moving cards. Tap scrolls the explanation into view.
 if s.StatsHelp then showHelp(s.StatsHelp) end
 local foot=ctx.text(sc,"Footnote","UTC days: 00:00–24:00 · Copy fills count once per account · Lifetime retains blown attempts",0,yy+220,cw,46,13,ctx.Muted,FONT,CENTER)
 foot.TextWrapped=true
 yy+=274
 sc:SetAttribute("Scope",scope.Key) sc:SetAttribute("Period",period)
 sc:SetAttribute("NetRealized",agg.Net) sc:SetAttribute("Trades",agg.AllTrades) sc:SetAttribute("Blown",agg.Blown)
 return finish("Ready")
end
-- All six metrics are realized. Market ticks do not change Stats; a new server Stats packet rebuilds it.
function View.Update(_ctx,_sc) end
return View
'''
p.write_text(s,encoding='utf-8')
