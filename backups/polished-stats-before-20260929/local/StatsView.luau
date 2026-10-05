-- Stats page: lifetime trading performance across funded accounts and restarts. Every number is computed and
-- persisted by the server (TradeStats / FundedAccounts:Stats). This module only lays it out, using the
-- terminal's Fredoka typography, outlined values, colourful cards and glossy controls (passed in via ctx).
local TextService=game:GetService("TextService")
local Charts=require(script.Parent.StatsCharts)
local View={}
local LEFT,CENTER,RIGHT=Enum.TextXAlignment.Left,Enum.TextXAlignment.Center,Enum.TextXAlignment.Right
local TOP=Enum.TextYAlignment.Top
local AtEnd=Enum.TextTruncate.AtEnd
local FONT=Enum.Font.FredokaOne

local function commas(n)
 local raw=tostring(math.floor(math.abs(n or 0)+0.5))
 return ((n or 0)<0 and "-" or "")..raw:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
local function plural(n,word) return commas(n).." "..word..(n==1 and "" or "s") end
local function pct(rate) return rate and string.format("%.1f%%",rate*100) or "—" end
local function dateText(t)
 if type(t)~="number" then return nil end
 local ok,v=pcall(function() return DateTime.fromUnixTimestamp(t):FormatLocalTime("ll","en-us") end)
 return ok and v or nil
end
local function measure(value,size,width) return TextService:GetTextSize(value,size,FONT,Vector2.new(math.max(1,width),10000)).Y end
View.Commas=commas

-- Scopes in display order: All funded, each tier with attempts, then legacy accounts.
function View.Resolve(data,state)
 local list={}
 for _,x in ipairs(data and data.Scopes or {}) do table.insert(list,x) end
 local scope
 for _,x in ipairs(list) do if x.Key==state.StatsScope then scope=x end end
 scope=scope or list[1]
 local period=state.StatsPeriod=="Dated" and "Dated" or (scope and state.StatsPeriod=="Current") and "Current" or "Life"
 local agg=scope and (period=="Dated" and scope.Life.Dated or scope[period])
 return scope,agg or (scope and scope.Life),period,list
end
-- Open P&L moves every market update. It is taken from the server's live portfolio summary (the same values the
-- dashboard shows). Only active attempts can hold positions, so lifetime and current open P&L are identical.
function View.OpenFor(scope,pf,agg)
 if not scope then return 0 end
 if pf then
  if scope.Kind=="All" then return pf.Open or 0 end
  local total,seen=0,{}
  for _,r in ipairs(pf.Accounts or {}) do
   if r.Tier==scope.Key and not seen[r.Key] then seen[r.Key]=true;total+=r.Unrealized or 0 end
  end
  return total
 end
 return agg and agg.Open or 0
end
function View.Describe(scope,agg,period)
 if period=="Dated" then return "Only closed trades with saved calendar dates, across all attempts (including blown accounts). All six cards use this same dated history." end
 local a=agg.Attempts or 0
 local blown=agg.Blown>0 and (", including "..commas(agg.Blown).." blown") or ""
 local text
 if scope.Kind=="All" and period=="Life" then
  text="Every funded attempt you have traded: "..plural(a,"attempt")..blown..". Includes previous attempts and restarts."
 elseif scope.Kind=="All" then
  text="Only the "..plural(a,"attempt").." you are trading now. Blown and retired accounts are excluded."
 elseif period=="Life" then
  text=scope.Name.." · all "..plural(a,"attempt")..blown..". Restarting opens a new attempt; earlier results stay in these totals."
 else
  text=scope.Name.." · all "..plural(a,"usable account").." in this tier. Blown and retired accounts are excluded."
 end
 if (agg.Breached or 0)>0 then
  text..=" "..plural(agg.Breached,"earlier attempt").." ended under the old loss-limit rules and "..(agg.Breached==1 and "is" or "are").." not counted as blown."
 end
 return text
end
function View.Coverage(agg,signed)
 if agg.Partial then
  local since=dateText(agg.Since)
  local count=agg.UntrackedTrades>0 and (" across "..(agg.CountUnknown and "at least " or "")..plural(agg.UntrackedTrades,"earlier trade"))
   or (agg.CountUnknown and " across an unknown number of earlier trades" or "")
  return "Earlier results without a full breakdown (net "..signed(agg.UntrackedNet)..count..") remain in Total P&L. Ratios are unavailable for this incomplete scope; use Dated history for a consistent tracked scope."
 elseif agg.Recovered then
  return "Includes earlier trades rebuilt from your saved trade history."
 end
 return nil
end

function View.Draw(ctx,x,y,w,h,mobile)
 local C,SC=ctx.C,ctx.SC
 local s=ctx.State local data=ctx.Data local pf=ctx.Portfolio
 local signed,money=ctx.signed,ctx.money
 local sc=ctx.make("ScrollingFrame","Stats",ctx.Canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),
  BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,ScrollingDirection=Enum.ScrollingDirection.Y})
 local cw=w-(mobile and 6 or 14) local narrow=cw<600 local gap=mobile and 10 or 14
 local soft=Color3.fromRGB(214,234,255) local gold=Color3.fromRGB(255,214,104)
 local function valueColor(v,onCard) if math.abs(v or 0)<0.005 then return C.Text end return v>0 and (onCard and SC.Green or C.Green) or (onCard and SC.Red or C.Red) end
 local function sgn(v) if math.abs(v or 0)<0.005 then return "$0.00" end return signed(v) end
 -- Header
 ctx.heading(sc,"Title","Your Stats",0,0,cw,narrow and 34 or 40,narrow and 26 or 34)
 local sub=ctx.text(sc,"Subtitle",narrow and "Server-calculated results" or "Closed trades · saved across restarts · calculated by the exchange server",0,narrow and 34 or 42,cw,24,14,ctx.Muted,FONT)
 sub.TextTruncate=AtEnd
 local yy=narrow and 70 or 80
 local function finish(state)
  sc.CanvasSize=UDim2.fromOffset(0,yy)
  sc:SetAttribute("State",state)
  return sc
 end
 -- Loading, error and empty states share one card.
 local function stateCard(name,title,body,label,fn,variant)
  local tx=mobile and 16 or 104 local tw=cw-tx-(mobile and 16 or 24)
  local bodyH=measure(body,15,tw)+4
  local ch=math.max(mobile and 0 or 132,18+30+8+bodyH+(label and 60 or 12))
  local c=ctx.card(sc,name,0,yy,cw,ch,Color3.fromRGB(10,44,118),Color3.fromRGB(4,24,70),C.Cyan,not mobile)
  if not mobile then ctx.icon(c,"Unrealized",18,(ch-72)/2,72) end
  ctx.value(c,"Heading",title,tx,16,tw,30,narrow and 19 or 24,C.Text,mobile).TextXAlignment=LEFT
  local b=ctx.text(c,"Body",body,tx,52,tw,bodyH,15,soft,FONT) b.TextWrapped=true b.TextYAlignment=TOP
  if label then
   local bw=math.min(tw,260)
   local btn=ctx.gloss(ctx.button(c,"StateAction",label,tx,ch-54,bw,42,fn,C.Raised,C.Text,16),variant or "Purple")
   btn.Corners.CornerRadius=UDim.new(0,14)
  end
  yy+=ch+gap
 end
 if not data or data.Loading then
  local waiting=ctx.Status and not ctx.CanTrade
  stateCard("StatsLoading",waiting and "Waiting for the exchange" or "Loading your stats…",
   waiting and (tostring(ctx.Status)..". Your saved results are safe; stats appear as soon as the exchange is ready.") or "Fetching your lifetime results from the exchange server.",
   "Retry",ctx.retry,"Cyan")
  return finish(waiting and "Waiting" or "Loading")
 end
 if data.Error then
  stateCard("StatsError","Stats unavailable",data.Error,"Retry",ctx.retry,"Cyan")
  return finish("Error")
 end
 local scope,agg,period,list=View.Resolve(data,s)
 if data.New or not scope then
  stateCard("StatsEmpty","No stats yet","Start a funded account and close your first trade. Every completed trade, win, loss and blown account is then tracked here for good, including across restarts.",
   "Start a Funded Account",ctx.start,"Purple")
  return finish("Empty")
 end
 -- Scope tabs: All funded · each tier · legacy practice.
 local cols=narrow and math.min(#list,3) or math.min(#list,7)
 local tabH=narrow and 40 or 44
 local tabW=(cw-8*(cols-1))/cols
 if not narrow then tabW=math.min(tabW,190) end
 for i,item in ipairs(list) do
  local col,row=(i-1)%cols,math.floor((i-1)/cols)
  local label=item.Kind=="All" and (narrow and "All funded" or "All Funded Accounts") or item.Short
  local b=ctx.button(sc,"TabScope"..item.Key,label,col*(tabW+8),yy+row*(tabH+8),tabW,tabH,function() s.StatsScope=item.Key ctx.refresh() end,C.Raised,C.Text,narrow and 14 or 16)
  ctx.control(b,item==scope)
 end
 yy+=math.ceil(#list/cols)*(tabH+8)+2
 if scope then
  local segW=(cw-16)/3
  local current=narrow and "Usable only" or "All usable accounts"
  for i,p in ipairs({{"Life",narrow and "Lifetime" or "Lifetime · all attempts"},{"Current",current},{"Dated","Dated history"}}) do
   local b=ctx.button(sc,"TabPeriod"..p[1],p[2],(i-1)*(segW+8),yy,segW,38,function() s.StatsPeriod=p[1] ctx.refresh() end,C.Raised,C.Text,narrow and 11 or 15)
   ctx.control(b,period==p[1])
  end
  yy+=46
 end
 -- What this view includes (previous attempts, restarts, legacy) and how complete its history is.
 local eyebrow=(scope.Kind=="All" and "ALL FUNDED ACCOUNTS" or string.upper(scope.Name))
  .."  ·  "..(period=="Dated" and "DATED HISTORY" or period=="Life" and "LIFETIME · INCLUDES RESTARTS" or "CURRENT ATTEMPTS").." · UTC DAYS"
 local describe=View.Describe(scope,agg,period)
 local coverage=View.Coverage(agg,sgn)
 if (agg.UndatedTrades or 0)>0 or agg.CountUnknown then
  coverage=(coverage and coverage.." " or "").."Earlier trades have no calendar date. Daily metrics are unavailable for this scope; Dated history applies the same dated-trades filter to all six cards."
 elseif period=="Dated" and agg.FirstClosedAt then
  coverage="From "..os.date("!%Y-%m-%d",agg.FirstClosedAt).." through today (UTC). Earlier undated results remain in Lifetime."
 end
 if not coverage and agg.AllTrades==0 then
  coverage="No completed trades in this view yet. Close a position and its result appears here within a second."
 end
 local bw=cw-32 local ds=15
 local dh=measure(describe,ds,bw)+4 local chH=coverage and measure(coverage,ds-1,bw)+4 or 0
 local eh=measure(eyebrow,14,bw)+6
 local bh=12+eh+6+dh+(coverage and chH+6 or 0)+12
 local banner=ctx.card(sc,"ScopeInfo",0,yy,cw,bh,Color3.fromRGB(10,52,140),Color3.fromRGB(4,26,78),C.Cyan,false)
 ctx.heading(banner,"Eyebrow",eyebrow,16,12,bw,eh,14).TextWrapped=true
 local d=ctx.text(banner,"Includes",describe,16,18+eh,bw,dh,ds,soft,FONT) d.TextWrapped=true d.TextYAlignment=TOP
 if coverage then local c=ctx.text(banner,"Coverage",coverage,16,24+eh+dh,bw,chH,ds-1,gold,FONT) c.TextWrapped=true c.TextYAlignment=TOP end
 banner:SetAttribute("Partial",agg.Partial==true)
 yy+=bh+gap
 -- Six reference-style cards, sharing exactly the scope selected above.
 local blue=Color3.fromRGB(0,112,255)
 local green,pink=Color3.fromRGB(34,255,164),Color3.fromRGB(255,94,151)
 local cyan=Color3.fromRGB(151,230,255)
 local neutral=Color3.fromRGB(42,85,148)
 local metricCols=cw>=940 and 3 or cw>=620 and 2 or 1
 local kw=(cw-gap*(metricCols-1))/metricCols
 local kh=math.clamp(kw*.49,218,254)
 local cardsY=yy
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
 local helpW=math.min(480,cw)
 local help=ctx.frame(ctx.Canvas,"StatsMetricHelp",0,0,helpW,100,Color3.fromRGB(4,25,76),50)
 ctx.round(help,16) ctx.stroke(help,cyan).Thickness=2 help.Visible=false
 local helpTitle=ctx.text(help,"Title","",16,12,helpW-70,28,20,cyan,FONT,nil,51)
 local helpBody=ctx.text(help,"Body","",16,46,helpW-32,50,15,C.Text,FONT,nil,51)
 helpBody.TextWrapped=true helpBody.TextYAlignment=TOP
 local helpClose=ctx.button(help,"Close","×",helpW-50,4,44,44,function() s.StatsHelp=nil help.Visible=false end,false,C.Text,24,52)
 local helpY=yy+math.ceil(#metrics/metricCols)*(kh+gap)+2
 help.Position=UDim2.fromOffset(0,helpY)
 local function showHelp(index)
  local m=metrics[index]
  helpTitle.Text=m[2] helpTitle.TextSize=cw<400 and 15 or 20
  helpTitle.TextScaled=true
  helpBody.Text=m[6]
  local hh=measure(m[6],15,helpW-32)+64
  helpBody.Size=UDim2.fromOffset(helpW-32,hh-58)
  help.Size=UDim2.fromOffset(helpW,hh)
  local col,row=(index-1)%metricCols,math.floor((index-1)/metricCols)
  help.Position=UDim2.fromOffset(math.clamp(x+col*(kw+gap),8,math.max(8,ctx.Canvas.AbsoluteSize.X-helpW-8)),
   math.clamp(y+cardsY+row*(kh+gap)+68-sc.CanvasPosition.Y,8,math.max(8,ctx.Canvas.AbsoluteSize.Y-hh-8)))
  help.Visible=true
 end
 local function ring(parent,name,cx,cy,radius,thick,greenShare,lossShare,half)
  return Charts.Draw(ctx,parent,name,cx,cy,radius,thick,greenShare,lossShare,half,{Win=green,Loss=pink,Neutral=neutral})
 end
 for i,m in ipairs(metrics) do
  local col,row=(i-1)%metricCols,math.floor((i-1)/metricCols)
  local tile=ctx.card(sc,"Metric"..m[1],col*(kw+gap),yy+row*(kh+gap),kw,kh,
   i==1 and Color3.fromRGB(93,34,249) or Color3.fromRGB(5,51,142),
   i==1 and Color3.fromRGB(40,14,181) or Color3.fromRGB(3,25,77),
   i==1 and Color3.fromRGB(156,108,255) or blue,true)
  tile.Border.Thickness=4 tile.Corners.CornerRadius=UDim.new(0,20)
  for j,pos in ipairs({{kw-104,3,64},{kw-69,kh-76,43}})do
   local star=ctx.text(tile,"StarAccent"..j,"★",pos[1],pos[2],pos[3],pos[3],pos[3],i==1 and Color3.fromRGB(157,76,255) or Color3.fromRGB(0,96,230),Enum.Font.SourceSansBold,CENTER,2)
   star.TextTransparency=.5 star.TextStrokeTransparency=1
  end
  local label=ctx.value(tile,"Label",m[2],16,14,kw-74,66,kw>=440 and 28 or 23,cyan,mobile)
  label.TextXAlignment=LEFT label.TextWrapped=true
  local q=ctx.button(tile,"Help","?",kw-56,14,44,44,function()
   if s.StatsHelp==i then s.StatsHelp=nil help.Visible=false else s.StatsHelp=i showHelp(i) end
  end,false,cyan,24,8)
  local disc=ctx.frame(q,"Disc",8,8,28,28,cyan,7) ctx.round(disc,14)
  q.TextTransparency=1
  local glyph=ctx.text(q,"Question","?",8,8,28,28,22,Color3.fromRGB(5,35,90),FONT,CENTER,9) glyph.TextStrokeTransparency=1
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
   local losing=i==2 and agg.Trades>0 and agg.Losses/agg.Trades or i==4 and rate and (agg.LosingDays or 0)/agg.DayCount or 0
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
   local l=ctx.value(tile,"GrossLoss",(agg.Loss>0 and "−" or "")..money(agg.Loss),kw*.72,167,kw*.24-12,21,14,pink,mobile) l.TextScaled=true
  end
 end
 yy=helpY
 -- Help floats within the viewport; hover and mobile tap never require scrolling to read it.
 if s.StatsHelp then showHelp(s.StatsHelp) end
 local foot=ctx.text(sc,"Footnote","UTC days: 00:00–24:00 · Copy fills count once per account · Lifetime retains blown attempts",0,yy,cw,46,13,ctx.Muted,FONT,CENTER)
 foot.TextWrapped=true
 yy+=54
 sc:SetAttribute("Scope",scope.Key) sc:SetAttribute("Period",period)
 sc:SetAttribute("NetRealized",agg.Net) sc:SetAttribute("Trades",agg.AllTrades) sc:SetAttribute("Blown",agg.Blown)
 return finish("Ready")
end
-- All six metrics are realized. Market ticks do not change Stats; a new server Stats packet rebuilds it.
function View.Update(_ctx,_sc) end
return View
