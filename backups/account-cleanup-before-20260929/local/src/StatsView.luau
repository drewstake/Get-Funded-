-- Stats page: lifetime trading performance across funded accounts and restarts. Every number is computed and
-- persisted by the server (TradeStats / FundedAccounts:Stats). Only Stats content is drawn here, using
-- individual editable components from 06 - Polished Stats Pieces. TerminalUI owns all shared navigation.
local TextService=game:GetService("TextService")
local Kit=require(script.Parent.StatsPieces)
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

-- Show individual tiers in server order ($5K first), with any legacy scopes kept separate.
-- The combined funded total is intentionally not an account-picker option.
function View.Resolve(data,state)
 local list={}
 for _,x in ipairs(data and data.Scopes or {}) do if x.Kind~="All" then table.insert(list,x) end end
 local scope
 for _,x in ipairs(list) do if x.Key==state.StatsScope then scope=x end end
 scope=scope or list[1]
 local period=state.StatsPeriod=="Dated" and "Dated" or "Life"
 local agg=scope and (period=="Dated" and scope.Life and scope.Life.Dated or period~="Dated" and scope[period])
 return scope,agg,period,list
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
 local C=ctx.C local s=ctx.State local data=ctx.Data
 local cw=w-12 local narrow=cw<620 local gap=narrow and 12 or 18
 local white=Color3.fromHex("F5F8FF") local muted=Color3.fromHex("ABC8F6")
 local sc=ctx.make("ScrollingFrame","Stats",ctx.Canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),
  BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=muted,ScrollingDirection=Enum.ScrollingDirection.Y})
 local function label(parent,name,value,xx,yy,ww,hh,size,color,body)
  return ctx.make("TextLabel",name,parent,{Position=UDim2.fromOffset(xx,yy),Size=UDim2.fromOffset(ww,hh),BackgroundTransparency=1,
   Text=value,TextColor3=color or white,TextSize=size,Font=FONT,TextXAlignment=LEFT,TextWrapped=true})
 end
 local function box(o,xx,yy,ww,hh)
  o.Position=UDim2.fromOffset(xx,yy) o.Size=UDim2.fromOffset(ww,hh) return o
 end
 local function fit(o,size)
  o.TextScaled=true
  ctx.make("UITextSizeConstraint","TypeSize",o,{MinTextSize=10,MaxTextSize=size})
  return o
 end
 local function piece(name,xx,yy,ww,hh)
  local o=Kit.Create(name,sc) box(o,xx,yy,ww,hh) return o
 end
 local function bind(button,fn) return button.Activated:Connect(fn) end
 local titleH=narrow and 40 or 66
 label(sc,"Title","Your Stats",4,0,cw-8,titleH,narrow and 32 or 52)
 label(sc,"Subtitle","Your trading performance at a glance",4,titleH,cw-8,30,narrow and 16 or 22,muted)
 local yy=titleH+44
 local function finish(state)
  sc.CanvasSize=UDim2.fromOffset(0,yy+8) sc:SetAttribute("State",state) return sc
 end
 local function stateCard(name,title,body,action,fn)
  local bodyH=measure(body,15,cw-40)+12
  local ch=bodyH+120
  local c=ctx.card(sc,name,0,yy,cw,ch,Color3.fromHex("093982"),Color3.fromHex("041B49"),Color3.fromHex("0866D6"),false)
  fit(label(c,"Heading",title,20,12,cw-40,36,24),24)
  local b=label(c,"Body",body,20,54,cw-40,bodyH,15,muted) b.TextYAlignment=TOP
  ctx.gloss(ctx.button(c,"StateAction",action,20,ch-54,math.min(260,cw-40),44,fn,C.Raised,C.Text,16),"Cyan")
  yy+=ch+gap
 end
 if not data or data.Loading then
  local waiting=ctx.Status and not ctx.CanTrade
  stateCard("StatsLoading",waiting and "Waiting for the exchange" or "Loading your stats…",
   waiting and (tostring(ctx.Status)..". Your saved results are safe; stats appear as soon as the exchange is ready.") or "Fetching your lifetime results from the exchange server.","Retry",ctx.retry)
  return finish(waiting and "Waiting" or "Loading")
 end
 if data.Error then stateCard("StatsError","Stats unavailable",data.Error,"Retry",ctx.retry) return finish("Error") end
 local scope,agg,period,list=View.Resolve(data,s)
 if data.New or not scope then
  stateCard("StatsEmpty","No stats yet","Start a funded account and close your first trade. Every completed trade, win, loss and blown account is then tracked here for good, including across restarts.","Start a Funded Account",ctx.start)
  return finish("Empty")
 end
 -- All transient UI is confined to the Stats viewport; the terminal owns the sidebar.
 local layer=ctx.make("Frame","StatsOverlays",ctx.Canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(cw,h),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=50,Visible=not s.Overlay and not s.Sheet})
 local dropdowns={}
 local help
 local function closeHelp() if help then help:Destroy() help=nil end end
 local function showHelp(key,title,body,pinned)
  closeHelp()
  if pinned then s.StatsHelp=key end
  local hw=math.min(530,cw-16)
  local bodyH=TextService:GetTextSize(body,16,FONT,Vector2.new(hw-40,10000)).Y+16
  local hh=math.min(h-16,bodyH+80)
  help=ctx.make("Frame","StatsMetricHelp",layer,{Position=UDim2.fromOffset(math.max(8,(cw-hw)/2),math.max(8,(h-hh)/2)),Size=UDim2.fromOffset(hw,hh),BackgroundColor3=Color3.fromHex("062250"),ZIndex=111})
  ctx.round(help,16) ctx.stroke(help,Color3.fromHex("487DDB"))
  fit(label(help,"Title",title,20,12,hw-78,40,24),24).ZIndex=112
  local bodyScroll=ctx.make("ScrollingFrame","Copy",help,{Position=UDim2.fromOffset(20,62),Size=UDim2.fromOffset(hw-40,hh-76),CanvasSize=UDim2.fromOffset(0,bodyH),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ZIndex=112})
  local copy=label(bodyScroll,"Body",body,0,0,hw-44,bodyH,16,muted,true) copy.TextYAlignment=TOP copy.ZIndex=113
  local close=ctx.button(help,"Close","×",hw-54,8,44,44,function()s.StatsHelp=nil closeHelp()end,false,white,28,114)
 end
 local function helpButton(button,key,title,body)
  bind(button,function()
   if s.StatsHelp==key and help then s.StatsHelp=nil closeHelp() else showHelp(key,title,body,true) end
  end)
  button.MouseEnter:Connect(function()if not s.StatsHelp then showHelp(key,title,body,false)end end)
  button.MouseLeave:Connect(function()if not s.StatsHelp then closeHelp()end end)
  button.SelectionGained:Connect(function()if not s.StatsHelp then showHelp(key,title,body,false)end end)
  button.SelectionLost:Connect(function()if not s.StatsHelp then closeHelp()end end)
  if s.StatsHelp==key then showHelp(key,title,body,true)end
 end
 local input=game:GetService("UserInputService").InputBegan:Connect(function(ev)
  if ev.KeyCode==Enum.KeyCode.Escape or ev.KeyCode==Enum.KeyCode.ButtonB then s.StatsHelp=nil closeHelp()end
 end)
 sc:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
  for _,d in ipairs(dropdowns)do d:Close()end
  if not s.StatsHelp then closeHelp()end
 end)
 sc.Destroying:Connect(function()
  input:Disconnect()
  for _,d in ipairs(dropdowns)do d:Destroy()end
  layer:Destroy()
 end)
 local function selectFilter(scopeKey,periodKey)
  local target
  for _,item in ipairs(list)do if item.Key==scopeKey then target=item break end end
  local nextAggregate=target and (periodKey=="Dated" and target.Life and target.Life.Dated or periodKey~="Dated" and target[periodKey])
  if type(nextAggregate)~="table" then
   showHelp("Unavailable","Stats unavailable","This scope has not loaded yet. Your previous selection is still shown. Retry when the exchange is ready.",true)
   return false
  end
  s.StatsScope=scopeKey s.StatsPeriod=periodKey s.StatsHelp=nil ctx.refresh() return true
 end
 local funded=piece("FundedDropdown",0,0,1,52)
 local function dropdownLayout(b,xx,yy,ww)
  box(b,xx,yy,ww,52)
  fit(box(b:FindFirstChild(b.Name.."Label"),18,0,ww-62,52),19)
  box(b:FindFirstChild(b.Name.."Chevron"),ww-42,14,24,24)
 end
 if not narrow then
  local fw=math.clamp(cw*.28,300,395)
  label(sc,"AccountLabel","Funded accounts",8,yy,140,52,17,muted,true)
  dropdownLayout(funded,150,yy,fw)
  yy+=70
 else
  label(sc,"AccountLabel","Funded accounts",4,yy,cw-8,24,15,muted,true)
  dropdownLayout(funded,0,yy+28,cw)
  yy+=94
 end
 local items={}
 for _,item in ipairs(list)do
  table.insert(items,{Key=item.Key,Label=item.Name or item.Short or item.Key})
 end
 table.insert(dropdowns,Kit.BindDropdown(layer,funded,items,scope.Key,function(key)return selectFilter(key,period)end))
 if not agg then
  stateCard("StatsError","Stats unavailable","The selected scope has not loaded yet. Retry to fetch your saved results.","Retry",ctx.retry)
  return finish("Error")
 end
 local heroH=narrow and 222 or 214
 local hero=piece("HeroCard",0,yy,cw,heroH)
 local pad=narrow and 20 or 32
 fit(box(hero.TotalTitle,pad,18,176,44),32) box(hero.TotalHelp,pad+176,18,44,44)
 fit(box(hero.TotalValue,pad,70,narrow and cw-pad*2 or cw*.61-pad,90),narrow and 56 or 84)
 fit(box(hero.TotalCaption,pad,narrow and 150 or 165,cw-pad*2,30),19)
 if narrow then
  box(hero.AttemptsLabel,pad,185,(cw-pad*2)*.4,24)
  box(hero.ClosedTradesLabel,pad+(cw-pad*2)*.4,185,(cw-pad*2)*.6,24)
  hero.HeroDivider.Visible=false hero.AttemptsIcon.Visible=false hero.ClosedTradesIcon.Visible=false hero.HeroWatermark.Visible=false
 else
  box(hero.HeroDivider,cw*.63,38,1,136)
  local rx=cw*.66 local rw=cw-rx-20
  box(hero.AttemptsLabel,rx,56,rw*.43,32) box(hero.ClosedTradesLabel,rx+rw*.45,56,rw*.55,32)
  box(hero.AttemptsIcon,rx+rw*.14,108,52,52) box(hero.ClosedTradesIcon,rx+rw*.64,96,68,68)
  box(hero.HeroWatermark,cw-122,102,110,110)
 end
 fit(hero.AttemptsLabel,narrow and 15 or 21) fit(hero.ClosedTradesLabel,narrow and 15 or 21)
 yy+=heroH+gap
 local cols=cw>=900 and 3 or cw>=620 and 2 or 1
 local kw=(cw-gap*(cols-1))/cols local kh=math.clamp(kw*.60,230,265)
 local metrics={"Trade","Average","Factor"}
 for i,key in ipairs(metrics)do
  local card=piece(key.."Card",((i-1)%cols)*(kw+gap),yy+math.floor((i-1)/cols)*(kh+gap),kw,kh)
  local p=kw<360 and 20 or 26
  fit(box(card[key.."Title"],p,18,kw-p-62,44),kw<360 and 24 or 28)
  box(card[key.."Help"],kw-58,16,44,44)
  fit(box(card[key.."Value"],p,76,kw-p*2,62),52)
  box(card[key.."Bar"],p,146,kw-p*2,21)
  if key=="Trade" then
   fit(box(card.TradeCaption,p,kh-62,kw-p*2,46),20)
  else
   local half=(kw-p*2-10)/2
   for n=0,1 do
    local dx=p+n*(half+10)
    fit(box(card[key.."DetailLabel"..n],dx,kh-66,half,28),18)
    fit(box(card[key.."Detail"..n],dx,kh-38,half,28),22)
   end
  end
 end
 yy+=math.ceil(3/cols)*(kh+gap)
 local dailyH=cw>=1120 and 158 or narrow and 344 or 218
 local daily=piece("DailyStats",0,yy,cw,dailyH)
 fit(box(daily.DailyTitle,24,12,154,42),30) box(daily.DailyHelp,180,12,44,44)
 local dw=cw>=1120 and cw*.26 or (cw-64)/2
 local second=cw>=1120 and cw*.28 or cw/2+8
 if narrow then dw=cw-90 second=24 end
 fit(box(daily.DayTitle,24,64,narrow and cw-48 or dw,30),18)
 box(daily.DayCalendar,24,100,37,37) fit(box(daily.DayValue,74,97,narrow and cw-100 or dw-50,42),34)
 local by=narrow and 158 or 64
 fit(box(daily.BestTitle,second,by,narrow and cw-48 or dw,30),18)
 box(daily.BestCalendar,second,by+36,37,37) fit(box(daily.BestValue,second+50,by+33,narrow and cw-100 or dw-50,42),34)
 daily.DailyDividerA.Visible=not narrow box(daily.DailyDividerA,second-16,68,1,70)
 daily.DailyDividerB.Visible=cw>=1120 box(daily.DailyDividerB,cw*.56,68,1,70)
 local cx=cw>=1120 and cw*.58 or 24
 local cy=cw>=1120 and 72 or narrow and 247 or 154
 box(daily.DailyInfo,cx,cy+5,30,30)
 local buttonW=cw>=1120 and 206 or 190
 local copyW=cw>=1120 and cw-cx-buttonW-86 or narrow and cw-94 or cw-buttonW-94
 fit(box(daily.CoverageCopy,cx+44,cy,copyW,narrow and 42 or 52),16)
 box(daily.DatedButton,narrow and 24 or cw-buttonW-24,narrow and 295 or cy, narrow and cw-48 or buttonW,44)
 local dbw=daily.DatedButton.Size.X.Offset
 fit(box(daily.DatedButton.DatedButtonLabel,16,0,dbw-44,44),17)
 box(daily.DatedButton.DatedArrow,dbw-28,12,20,20)
 daily.DatedButton.DatedButtonLabel.Text=period=="Dated" and "View lifetime stats" or "View dated history"
 bind(daily.DatedButton,function()selectFilter(scope.Key,period=="Dated" and "Life" or "Dated")end)
 yy+=dailyH+14
 -- Populate every value before the next render; the extracted pieces contain no sample history.
 local formatted=Kit.ApplyAggregate(sc,agg)
 hero.AttemptsLabel.Text=plural(agg.Attempts or 0,"attempt")
 hero.ClosedTradesLabel.Text=commas(agg.AllTrades or agg.Trades or 0)..(agg.CountUnknown and "+" or "").." closed trades"
 if (agg.Even or 0)>0 and not agg.Partial and not agg.CountUnknown then sc.TradeCard.TradeCaption.Text=formatted[2].Caption end
 if (agg.AllTrades or agg.Trades or 0)==0 and not agg.CountUnknown then daily.CoverageCopy.Text="No closed trades in this scope yet." end
 local describe=View.Describe(scope,agg,period)
 local coverage=View.Coverage(agg,ctx.signed)
 if (agg.UndatedTrades or 0)>0 or agg.CountUnknown then
  coverage=(coverage and coverage.." " or "").."Earlier trades have no calendar date. Daily metrics are unavailable for this scope; Dated history applies the same dated-trades filter to all six metrics."
 elseif period=="Dated" and agg.FirstClosedAt then
  coverage="From "..os.date("!%Y-%m-%d",agg.FirstClosedAt).." through today (UTC). Earlier undated results remain in Lifetime."
 end
 if not coverage and agg.AllTrades==0 then coverage="No completed trades in this view yet. Close a position and its result appears here within a second." end
 local descriptions={
  Total="Net realized profit or loss from closed trades. Open positions, starting capital, unlocks and resets are excluded. Blown attempts remain in Lifetime.",
  Trade="Winning closing fills divided by all closing fills. Break-even fills count in the denominator. Partial closes count per closing fill, matching Trade History.",
  Average="Average winning P&L divided by the absolute average losing P&L. Both dollar averages are shown. ∞ means positive wins with no losses; — means no usable denominator.",
  Factor="Sum of positive closed P&L divided by the absolute sum of negative closed P&L. ∞ means positive gains and zero losses. With no gains or losses, the ratio is unavailable.",
 }
 for _,m in ipairs(formatted)do
  local button=sc:FindFirstChild(m.Key.."Help",true)
  if button then helpButton(button,m.Key,m.Title,(descriptions[m.Key] or m.Help).."\n\n"..m.Caption..(m.Key=="Total" and "\n\n"..describe or "")) end
 end
 helpButton(daily.DailyHelp,"Daily","Daily stats",formatted[4].Help.."\n"..formatted[4].Caption.."\n\n"..formatted[6].Help.."\n"..formatted[6].Caption..(coverage and "\n\n"..coverage or ""))
 sc:SetAttribute("MetricColumns",cols) sc:SetAttribute("Scope",scope.Key) sc:SetAttribute("Period",period)
 sc:SetAttribute("NetRealized",agg.Net) sc:SetAttribute("Trades",agg.AllTrades) sc:SetAttribute("Blown",agg.Blown) sc:SetAttribute("Partial",agg.Partial==true)
 return finish("Ready")
end
-- All six metrics are realized. Server Stats packets rebuild this page through TerminalUI's existing path.
function View.Update(_ctx,_sc) end
return View
