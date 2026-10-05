-- Stats page: lifetime trading performance across funded accounts and restarts. Every number is computed and
-- persisted by the server (TradeStats / FundedAccounts:Stats). This module only lays it out, using the
-- terminal's Fredoka typography, outlined values, colourful cards and glossy controls (passed in via ctx).
local TextService=game:GetService("TextService")
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

-- Scopes in display order: All funded, each tier with attempts, then legacy practice accounts.
function View.Resolve(data,state)
 local list={}
 for _,x in ipairs(data and data.Scopes or {}) do table.insert(list,x) end
 for _,x in ipairs(data and data.Legacy or {}) do table.insert(list,x) end
 local scope
 for _,x in ipairs(list) do if x.Key==state.StatsScope then scope=x end end
 scope=scope or list[1]
 local period=(scope and scope.Kind~="Legacy" and state.StatsPeriod=="Current") and "Current" or "Life"
 return scope,scope and scope[period],period,list
end
-- Open P&L moves every market update. It is taken from the server's live portfolio summary (the same values the
-- dashboard shows). Only active attempts can hold positions, so lifetime and current open P&L are identical.
function View.OpenFor(scope,pf,agg)
 if not scope then return 0 end
 if pf then
  if scope.Kind=="All" then return pf.Open or 0 end
  local list=scope.Kind=="Tier" and pf.Accounts or pf.Legacy
  for _,r in ipairs(list or {}) do if r.Key==scope.Key then return (r.State==nil or r.State=="Active") and (r.Unrealized or 0) or 0 end end
 end
 return agg and agg.Open or 0
end
function View.Describe(scope,agg,period)
 local a=agg.Attempts or 0
 local blown=agg.Blown>0 and (", including "..commas(agg.Blown).." blown") or ""
 local text
 if scope.Kind=="Legacy" then
  text="Pre-ladder practice account, shown separately. It is never included in funded totals, unlocks or the leaderboard."
 elseif scope.Kind=="All" and period=="Life" then
  text="Every funded attempt you have traded: "..plural(a,"attempt")..blown..". Includes previous attempts and restarts. Legacy practice accounts are excluded."
 elseif scope.Kind=="All" then
  text="Only the "..plural(a,"attempt").." you are trading now. Earlier attempts, restarted accounts and legacy practice accounts are excluded."
 elseif period=="Life" then
  text=scope.Name.." · all "..plural(a,"attempt")..blown..". Restarting opens a new attempt; earlier results stay in these totals."
 else
  local n=scope.Attempt or 1
  text=scope.Name.." · attempt "..n.." only"..(n>1 and ", since its last restart. Earlier attempts are excluded." or ". No restarts yet.")
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
  return "Win/loss breakdown tracked "..(since and ("from "..since) or "since stats began")..". Earlier results without a breakdown (net "..signed(agg.UntrackedNet)..count..") are included in Net realized P&L only."
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
 local sub=ctx.text(sc,"Subtitle",narrow and "Server-calculated results · simulated capital" or "Your trading performance across funded accounts and restarts · calculated by the exchange server",0,narrow and 34 or 42,cw,24,14,ctx.Muted,FONT)
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
  local label=item.Kind=="All" and (narrow and "All funded" or "All Funded Accounts") or item.Kind=="Legacy" and (narrow and "Legacy" or item.Name) or item.Short
  local b=ctx.button(sc,"TabScope"..item.Key,label,col*(tabW+8),yy+row*(tabH+8),tabW,tabH,function() s.StatsScope=item.Key ctx.refresh() end,C.Raised,C.Text,narrow and 14 or 16)
  ctx.control(b,item==scope)
 end
 yy+=math.ceil(#list/cols)*(tabH+8)+2
 if scope.Kind~="Legacy" then
  local segW=narrow and (cw-8)/2 or math.min(300,(cw-8)/2)
  local current=scope.Kind=="All" and (narrow and "Current only" or "Current attempts only") or ("Current attempt"..(scope.Attempt and (" #"..scope.Attempt) or ""))
  for i,p in ipairs({{"Life",narrow and "Lifetime" or "Lifetime · all attempts"},{"Current",current}}) do
   local b=ctx.button(sc,"TabPeriod"..p[1],p[2],(i-1)*(segW+8),yy,segW,38,function() s.StatsPeriod=p[1] ctx.refresh() end,C.Raised,C.Text,narrow and 13 or 15)
   ctx.control(b,period==p[1])
  end
  yy+=46
 end
 -- What this view includes (previous attempts, restarts, legacy) and how complete its history is.
 local eyebrow=(scope.Kind=="All" and "ALL FUNDED ACCOUNTS" or scope.Kind=="Legacy" and "LEGACY PRACTICE · NOT IN FUNDED TOTALS" or string.upper(scope.Name))
  .."  ·  "..(scope.Kind=="Legacy" and "LIFETIME" or period=="Life" and "LIFETIME · INCLUDES RESTARTS" or "CURRENT ATTEMPT ONLY")
 local describe=View.Describe(scope,agg,period)
 local coverage=View.Coverage(agg,sgn)
 if not coverage and agg.AllTrades==0 then
  coverage="No completed trades in this view yet. Close a position and its result appears here within a second."
 end
 local bw=cw-32 local ds=15
 local dh=measure(describe,ds,bw)+4 local chH=coverage and measure(coverage,ds-1,bw)+4 or 0
 local eh=measure(eyebrow,14,bw)+6
 local bh=12+eh+6+dh+(coverage and chH+6 or 0)+12
 local banner=ctx.card(sc,"ScopeInfo",0,yy,cw,bh,Color3.fromRGB(10,52,140),Color3.fromRGB(4,26,78),scope.Kind=="Legacy" and C.Border or C.Cyan,false)
 ctx.heading(banner,"Eyebrow",eyebrow,16,12,bw,eh,14).TextWrapped=true
 local d=ctx.text(banner,"Includes",describe,16,18+eh,bw,dh,ds,soft,FONT) d.TextWrapped=true d.TextYAlignment=TOP
 if coverage then local c=ctx.text(banner,"Coverage",coverage,16,24+eh+dh,bw,chH,ds-1,gold,FONT) c.TextWrapped=true c.TextYAlignment=TOP end
 banner:SetAttribute("Partial",agg.Partial==true)
 yy+=bh+gap
 -- Headline P&L and blown accounts.
 local open=View.OpenFor(scope,pf,agg)
 local total=agg.Net+open
 local L=ctx.looks
 local kpis={
  {"Net","NET REALIZED P&L",sgn(agg.Net),"Total gains − total losses",L.Net,valueColor(agg.Net,true)},
  {"Open","OPEN P&L",sgn(open),"Unrealized · positions still open",L.Open,valueColor(open,true)},
  {"Total","TOTAL P&L",sgn(total),"Net realized + open P&L",L.Total,valueColor(total,true)},
  {"Blown","ACCOUNTS BLOWN",commas(agg.Blown),scope.Kind=="Legacy" and "Practice depletions" or ("Of "..plural(agg.Attempts,"attempt").." · each once"),L.Blown,C.Text},
 }
 local kc=narrow and 1 or 4 local kw=(cw-gap*(kc-1))/kc local kh=144
 for i,k in ipairs(kpis) do
  local col,row=(i-1)%kc,math.floor((i-1)/kc)
  local tile=ctx.card(sc,"Kpi"..k[1],col*(kw+gap),yy+row*(kh+gap),kw,kh,k[5][1],k[5][2],k[5][3],false)
  ctx.value(tile,"Label",k[2],12,12,kw-24,24,16,C.Text,mobile).TextXAlignment=LEFT
  local v=ctx.value(tile,"Value",k[3],12,42,kw-24,38,32,k[6],mobile) v.TextXAlignment=LEFT
  local cap=ctx.text(tile,"Caption",k[4],12,88,kw-24,44,14,Color3.fromRGB(235,245,255),FONT) cap.TextWrapped=true cap.ZIndex=6
 end
 yy+=math.ceil(#kpis/kc)*(kh+gap)+4
 -- Trade results.
 ctx.heading(sc,"ResultsTitle","Trade results",0,yy,narrow and cw or 220,28,mobile and 19 or 22).TextXAlignment=LEFT
 if not narrow then ctx.text(sc,"ResultsNote","Closed trades only · starting capital, unlocks and restart funding never count",230,yy,cw-230,28,11,ctx.Muted,FONT,RIGHT).TextTruncate=AtEnd end
 yy+=34
 local tracked=agg.Partial and " (tracked)" or ""
 local count=commas(agg.AllTrades)..(agg.CountUnknown and "+" or "")
 local items={
  {"Gains","TOTAL GAINS",money(agg.Gains),"Sum of positive closes"..tracked,agg.Gains>0.004 and C.Green or C.Text},
  {"Losses","TOTAL LOSSES",money(agg.Loss),"Sum of negative closes, as a positive"..tracked,agg.Loss>0.004 and C.Red or C.Text},
  {"Trades","COMPLETED TRADES",count,"Closing fills in your trade history",C.Text},
  {"WinningTrades","WINNING TRADES",commas(agg.Wins),"Closed above $0.00"..tracked,agg.Wins>0 and C.Green or C.Text},
  {"LosingTrades","LOSING TRADES",commas(agg.Losses),"Closed below $0.00"..tracked,agg.Losses>0 and C.Red or C.Text},
  {"EvenTrades","BREAK-EVEN TRADES",commas(agg.Even),"Closed at $0.00, to the cent"..tracked,C.Text},
  {"WinRate","WIN RATE",pct(agg.WinRate),agg.Partial and "Wins / tracked trades" or "Wins / completed trades",C.Text},
  {"Best","BEST TRADE",agg.Best and sgn(agg.Best) or "—","Largest single close"..tracked,valueColor(agg.Best)},
  {"Worst","WORST TRADE",agg.Worst and sgn(agg.Worst) or "—","Smallest single close"..tracked,valueColor(agg.Worst)},
  {"Average","AVERAGE PER TRADE",agg.Average and sgn(agg.Average) or "—",agg.AverageScope=="Tracked" and "Tracked net / tracked trades" or "Net realized / completed trades",valueColor(agg.Average)},
 }
 local mc=narrow and 2 or math.clamp(math.floor((cw+gap)/250),2,5)
 local mw=(cw-gap*(mc-1))/mc local mh=150
 for i,m in ipairs(items) do
  local col,row=(i-1)%mc,math.floor((i-1)/mc)
  local c=ctx.card(sc,"Metric"..m[1],col*(mw+gap),yy+row*(mh+gap),mw,mh,Color3.fromRGB(10,44,118),Color3.fromRGB(4,24,70),C.Border,false)
  local l=ctx.text(c,"Label",m[2],12,10,mw-24,36,14,C.Text,FONT) l.TextWrapped=true
  local v=ctx.value(c,"Value",m[3],12,48,mw-24,34,mobile and 23 or 28,m[5],mobile) v.TextXAlignment=LEFT
  local cap=ctx.text(c,"Caption",m[4],12,90,mw-24,50,14,soft,FONT) cap.TextWrapped=true cap.TextTruncate=Enum.TextTruncate.None cap.TextYAlignment=TOP
 end
 yy+=math.ceil(#items/mc)*(mh+gap)+6
 -- Account / tier breakdown (All funded scope). Tap a row to open that scope.
 if scope.Kind=="All" and #list>1 then
  ctx.heading(sc,"BreakdownTitle","Breakdown by account",0,yy,narrow and cw or 280,28,mobile and 19 or 22).TextXAlignment=LEFT
  if not narrow then ctx.text(sc,"BreakdownNote","Lifetime per tier · all attempts and restarts · tap to open",290,yy,cw-290,28,11,ctx.Muted,FONT,RIGHT).TextTruncate=AtEnd end
  yy+=34
  local rh=narrow and 90 or 70
  for i,item in ipairs(list) do
   if item.Kind~="All" then
    local life=item.Life
    local legacy=item.Kind=="Legacy"
    local r=ctx.button(sc,"Breakdown"..item.Key,"",0,yy,cw,rh,function() s.StatsScope=item.Key ctx.refresh() end,Color3.new(1,1,1),C.Text,12)
    ctx.tint(r,legacy and Color3.fromRGB(10,36,92) or Color3.fromRGB(12,58,150),legacy and Color3.fromRGB(4,20,58) or Color3.fromRGB(5,30,86))
    r.Corners.CornerRadius=UDim.new(0,14) r.Border.Color=legacy and C.Border or Color3.fromRGB(0,140,255) r.Border.Thickness=2
    local name=legacy and (item.Name.." · not in totals") or item.Name
    local detail=legacy and (plural(life.AllTrades,"trade").." · practice account") or (plural(life.Attempts,"attempt").." · "..commas(life.Blown).." blown · "..plural(life.AllTrades,"trade").." · win rate "..pct(life.WinRate))
    if narrow then
     ctx.heading(r,"Name",name,14,6,cw-150,26,16).TextXAlignment=LEFT
     local dt=ctx.text(r,"Detail",detail,14,38,cw-28,44,14,soft,FONT) dt.TextWrapped=true
     local nv=ctx.value(r,"Net",sgn(life.Net),cw-136,6,122,26,16,valueColor(life.Net,true),true) nv.TextXAlignment=RIGHT
    else
     ctx.heading(r,"Name",name,18,0,math.min(300,cw*.3),rh,18).TextXAlignment=LEFT
     local dt=ctx.text(r,"Detail",detail,18+math.min(300,cw*.3)+10,0,cw-math.min(300,cw*.3)-240,rh,12,soft,FONT) dt.TextWrapped=true
     ctx.text(r,"NetLabel","NET REALIZED",cw-200,8,184,16,10,ctx.Muted,FONT,RIGHT)
     local nv=ctx.value(r,"Net",sgn(life.Net),cw-200,22,184,28,20,valueColor(life.Net,true),false) nv.TextXAlignment=RIGHT
    end
    yy+=rh+8
   end
  end
  yy+=gap-2
 end
 -- How the numbers are counted.
 local notes={
  "Completed trade: one closing fill in your Trade History. A partial close counts once for the contracts it closed; the rest counts when it closes. Reversing a position counts its closing part.",
  "Win rate = winning trades divided by completed trades. A trade that rounds to $0.00 is break-even: it counts as completed, not as a win or a loss.",
  "Net realized P&L = total gains − total losses. Starting capital, unlocks and restart funding are capital, never trading gains.",
  "Open P&L is unrealized on positions still open and moves with the market. Total P&L = net realized + open.",
  "Accounts blown counts each attempt whose equity reached $0, once. A restart opens a new attempt; the blown attempt and its losses stay in lifetime totals.",
  "Copied trades count once for each account that actually traded them. Legacy practice accounts are shown separately and never included in funded totals.",
 }
 local ns=15 local nw=cw-48
 local heights={} local nh=12+26+8
 for i,n in ipairs(notes) do heights[i]=measure(n,ns,nw)+2 nh+=heights[i]+8 end
 local howto=ctx.card(sc,"HowCounted",0,yy,cw,nh+8,Color3.fromRGB(10,44,118),Color3.fromRGB(4,24,70),C.Border,false)
 ctx.heading(howto,"Title","How your stats are counted",16,12,cw-32,26,narrow and 16 or 18).TextXAlignment=LEFT
 local ny=46
 for i,n in ipairs(notes) do
  local dot=ctx.frame(howto,"Bullet"..i,18,ny+ns/2-2,8,8,C.Cyan) ctx.round(dot,4)
  local t=ctx.text(howto,"Note"..i,n,34,ny,nw,heights[i],ns,soft,FONT) t.TextWrapped=true t.TextYAlignment=TOP
  ny+=heights[i]+8
 end
 yy+=nh+8+gap
 local foot=ctx.text(sc,"Footnote","Calculated and saved by the exchange server · simulated capital, virtual funds",0,yy,cw,mobile and 48 or 24,14,C.Muted,FONT,CENTER)
 foot.TextWrapped=true
 yy+=mobile and 56 or 32
 sc:SetAttribute("Scope",scope.Key) sc:SetAttribute("Period",period)
 sc:SetAttribute("NetRealized",agg.Net) sc:SetAttribute("OpenPnL",open) sc:SetAttribute("Trades",agg.AllTrades) sc:SetAttribute("Blown",agg.Blown)
 return finish("Ready")
end
-- Live open/total P&L between rebuilds (market batches arrive ten times a second).
function View.Update(ctx,sc)
 local data=ctx.Data if not data or data.Error or data.New then return end
 local scope,agg=View.Resolve(data,ctx.State)
 if not scope or not agg then return end
 local open=View.OpenFor(scope,ctx.Portfolio,agg) local total=agg.Net+open
 for _,pair in ipairs({{"KpiOpen",open},{"KpiTotal",total}}) do
  local tile=sc:FindFirstChild(pair[1]) local label=tile and tile:FindFirstChild("Value")
  if label then
   local v=pair[2]
   label.Text=math.abs(v)<0.005 and "$0.00" or ctx.signed(v)
   label.TextColor3=math.abs(v)<0.005 and ctx.C.Text or v>0 and ctx.SC.Green or ctx.SC.Red
  end
 end
 sc:SetAttribute("OpenPnL",open)
end
return View
