-- Stats page: trading performance for the current account. Every number is computed and
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
local function measure(value,size,width) return TextService:GetTextSize(value,size,FONT,Vector2.new(math.max(1,width),10000)).Y end
View.Commas=commas

-- Always use the current account, including when an older UI state selected another period.
-- Do not display a previous account's cached packet while a restart is loading.
function View.Resolve(data,state,portfolio)
 local list=data and data.Scopes or {};local scope=list[1]
 state.StatsScope="ALL";state.StatsPeriod="Current"
 local agg=scope and scope.Current
 if data and portfolio and data.Run and portfolio.Run and data.Run~=portfolio.Run then agg=nil end
 return scope,agg,"Current",list
end
function View.OpenFor(scope,pf,agg)return pf and pf.Open or agg and agg.Open or 0 end
function View.Describe(scope,agg,period)
 return "Current account only. Starting money and open profit are excluded."
end
function View.Coverage(agg,signed)
 if agg.Partial then
  local count=agg.UntrackedTrades>0 and (" across "..(agg.CountUnknown and "at least " or "")..plural(agg.UntrackedTrades,"earlier trade"))
   or (agg.CountUnknown and " across an unknown number of earlier trades" or "")
  return "Results without a full breakdown (net "..signed(agg.UntrackedNet)..count..") are included in realized profit. Ratios need a complete trade breakdown."
 elseif agg.Recovered then
  return "Includes earlier trades rebuilt from your saved trade history."
 end
 return nil
end

function View.Draw(ctx,x,y,w,h,mobile)
 local C=ctx.C local s=ctx.State local data=ctx.Data
 local white=Color3.fromHex("F5F8FF") local muted=Color3.fromHex("ABC8F6")
 local sc=ctx.make("ScrollingFrame","Stats",ctx.Canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),
  BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=muted,ScrollingDirection=Enum.ScrollingDirection.Y})
 local cw,inset=ctx.insetScroll(sc) local narrow=cw<620 local gap=narrow and 12 or 18
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
 label(sc,"Subtitle","Every closed trade, measured.",4,titleH,cw-8,30,narrow and 16 or 22,muted)
 local yy=titleH+44
 local function finish(state)
  sc.CanvasSize=UDim2.fromOffset(0,yy+inset*2+8) sc:SetAttribute("State",state) return sc
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
   waiting and (tostring(ctx.Status)..". Stats will load when the exchange is ready.") or "Loading closed trades from your current account.","Retry",ctx.retry)
  return finish(waiting and "Waiting" or "Loading")
 end
 if data.Error then stateCard("StatsError","Stats unavailable",data.Error,"Retry",ctx.retry) return finish("Error") end
 local scope,agg,period=View.Resolve(data,s,ctx.Portfolio)
 if data.New or not scope then
  if data.New then
   stateCard("StatsEmpty","No stats yet","Close your first trade to see your current account's results.","Go to Trade",ctx.start)
  else
   stateCard("StatsEmpty","Your stats are loading","Return to Trade while the exchange connects.","Go to Trade",ctx.start)
  end
  return finish("Empty")
 end
 -- All transient UI is confined to the Stats viewport; the terminal owns the sidebar.
 local layer=ctx.make("Frame","StatsOverlays",ctx.Canvas,{Position=UDim2.fromOffset(x+inset,y),Size=UDim2.fromOffset(cw,h),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=50,Visible=not s.Overlay and not s.Sheet})
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
  if not s.StatsHelp then closeHelp()end
 end)
 sc.Destroying:Connect(function()
  input:Disconnect()
  layer:Destroy()
 end)
 label(sc,"ScopeDescription",View.Describe(scope,agg or {},period),4,yy,cw-8,narrow and 70 or 46,14,muted,true)
 yy+=narrow and 82 or 58
 if not agg then
  stateCard("StatsLoading","Loading your account stats…","Your current account's results are loading. Retry to fetch the latest stats.","Retry",ctx.retry)
  return finish("Loading")
 end
 local heroH=200
 local hero=piece("HeroCard",0,yy,cw,heroH)
 local pad=narrow and 20 or 32
 for _,name in ipairs({"AttemptsLabel","ClosedTradesLabel","AttemptsIcon","ClosedTradesIcon","HeroDivider","HeroWatermark"})do
  local part=hero:FindFirstChild(name);if part then part:Destroy()end
 end
 local totalTitleW=math.min(260,cw-pad*2-44)
 fit(box(hero.TotalTitle,pad,18,totalTitleW,44),32);box(hero.TotalHelp,pad+totalTitleW,18,44,44)
 fit(box(hero.TotalValue,pad,66,cw-pad*2,86),narrow and 56 or 78)
 fit(box(hero.TotalCaption,pad,156,cw-pad*2,30),19)
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
 local dailyH=cw>=1120 and 158 or narrow and 304 or 218
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
 local copyW=cw-cx-68
 fit(box(daily.CoverageCopy,cx+44,cy,copyW,narrow and 42 or 52),16)
 daily.DatedButton:Destroy()
 yy+=dailyH+14
 -- Populate every value before the next render; the extracted pieces contain no sample history.
 local formatted=Kit.ApplyAggregate(sc,agg)
 if (agg.Even or 0)>0 and not agg.Partial and not agg.CountUnknown then sc.TradeCard.TradeCaption.Text=formatted[2].Caption end
 if (agg.AllTrades or agg.Trades or 0)==0 and not agg.CountUnknown then daily.CoverageCopy.Text="No closed trades in this account yet." end
 local describe=View.Describe(scope,agg,period)
 local coverage=View.Coverage(agg,ctx.signed)
 if (agg.UndatedTrades or 0)>0 or agg.CountUnknown then
  coverage=(coverage and coverage.." " or "").."Some trades have no saved calendar date. Daily metrics are unavailable until every closed trade in this account has a date."
 end
 if not coverage and agg.AllTrades==0 then coverage="No closed trades in this account yet. Close a trade to add its result." end
 local descriptions={
  Total="Realized profit is the net profit or loss from closed trades in this account. It excludes open profit and starting money. Progress and Leaderboard use lifetime net profit across all accounts, including restarts.",
  Trade="Profitable closed trades divided by all closed trades, including break-even trades. Each closing fill counts as one trade, even when it closes only part of a position. Each has a row in Trade history.",
  Average="Average profit per winning trade divided by average loss per losing trade. Both amounts are shown below. ∞ means wins with no losses. — means there is not enough data to calculate the ratio.",
  Factor="Total profit from winning trades divided by total losses from losing trades. ∞ means profits with no losses. — means there are no profits or losses yet.",
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
