from pathlib import Path
p=Path('src/TerminalUI.luau');s=p.read_text(encoding='utf-8')
def section(start,end,new):
 global s
 a=s.index(start);b=s.index(end,a);s=s[:a]+new+'\n'+s[b:]
section(' local function accountName()', ' local function tierRow(key)', ''' local function accountName()return "Trading account"end
 local function accountShort()return "Trading account"end
 local function tradeAccountName()return "Trading account"end
 local function goalAmount(n)
  if not n then return "All titles earned" end
  if n.Kind=="Trades" or n.Kind=="Wins" then return math.floor(n.Progress).." / "..n.Goal end
  return whole(n.Progress).." / "..whole(n.Goal).." net profit"
 end
 local function objective()
  local pf=session.Portfolio;local n=pf and pf.Next
  if not n then return "NEXT GOAL",pf and "All milestones earned" or "Close your first trade",pf and 1 or 0,pf and "Keep growing your balance" or "0 / 1","Trade · Grow · Earn titles" end
  return "NEXT GOAL",n.Name,math.clamp(n.Progress/n.Goal,0,1),goalAmount(n),n.Name
 end''')
section(' local function confirmReset(key)', ' local function restartButton(', '')
section(' local function account(key)', ' local function info(', '') if ' local function info(' in s else None
# The old account switching helper is adjacent to glossary controls in this build.
if ' local function account(key)' in s:
 a=s.index(' local function account(key)');b=s.index('\n end',a)+len('\n end');s=s[:a]+s[b:]
section(' local function navigate(value,mobile)', ' local function nav(', ''' local function navigate(value,mobile)
  s.Overlay=nil;s.Sheet=false;s.Nav=value;s.Screen=value
  if value=="Review" then s.Screen="Trade";s.Nav="Trade";s.Tab="History";if mobile then s.Sheet="Activity" end end
  refresh()
 end''')
s=s.replace('local items={"Trade","Accounts","Shop","Stats","Leaderboard"}','local items={"Trade","Progress","Stats","Leaderboard"}')
s=s.replace('sidebarImage(b,value,','sidebarImage(b,value=="Progress" and "Accounts" or value,')
section(' local function accountCards(', ' -- The candlestick chart,', ''' local function accountCards(x,y,w,h,mobile)
  local sum=session:Summary();local pf=session.Portfolio
  local panel=frame(canvas,"AccountSummary",x,y,w,h,C.Bg);panel.BackgroundTransparency=1
  local gap=mobile and 8 or 16;local cw=(w-gap*2)/3;local ch=h-8
  for i,d in ipairs({{"Balance","BALANCE",Market.Money(sum.Balance),"In-game money"},{"Unrealized","OPEN GAIN / LOSS",Market.Signed(sum.Unrealized),"Changes until you close"}}) do
   local tile=button(panel,d[1].."Card","",(i-1)*(cw+gap),0,cw,ch,function()s.Overlay="Help";refresh()end,Color3.new(1,1,1))
   summarySurface(tile,d[1],mobile)
   summaryText(tile,"Label",d[2],8,8,cw-16,mobile and 25 or 28,mobile and 10 or 17,C.Text,true).TextWrapped=true
   summaryText(tile,d[1].."Value",d[3],8,mobile and 38 or 53,cw-16,mobile and 27 or 46,mobile and 16 or 36,i==2 and (sum.Unrealized>=0 and SC.Green or SC.Red) or C.Text,true)
   summaryText(tile,"Detail",mobile and (i==1 and "In-game money" or "Not yet in balance") or d[4],8,ch-28,cw-16,22,mobile and 9 or 13,C.Text,true)
  end
  local label,title,progress,amount=objective();local failed=pf and pf.Failed
  local tile=button(panel,"ObjectiveCard","",2*(cw+gap),0,cw,ch,function()if failed then openBlown(pf.Active) else navigate("Progress") end end,Color3.new(1,1,1))
  summarySurface(tile,failed and "Blown" or "Trophy",mobile)
  summaryText(tile,"Label",failed and "ACCOUNT FAILED" or label,8,8,cw-16,mobile and 19 or 28,mobile and 10 or 17,C.Text,true)
  local t=summaryText(tile,"Title",failed and "Free $5,000 restart" or title,10,mobile and 29 or 46,cw-20,mobile and 40 or 58,mobile and 13 or 24,C.Text,true);t.TextWrapped=true
  summaryText(tile,"Amount",failed and "Equity reached $0" or amount,8,ch-28,cw-16,20,mobile and 9 or 13,C.Text,true)
  local track=frame(tile,"Track",12,ch-7,cw-24,3,SC.Ink,4)
  local fill=frame(track,"Fill",0,0,(cw-24)*progress,3,C.Green,5);fill.Visible=progress>0
 end''')
# Remove obsolete account details and separate prose-only tutorial.
section(' local steps={', ' local function protectionPopup(', '')
s=s.replace('  if s.Overlay=="Account"then accountDetails(w,h);return end','  if s.Overlay=="Account"then s.Overlay="Help" end')
section('  local switchable={}', '  local narrow=pw<380', '  local pw=math.min(w-28,s.Overlay=="Tools" and 470 or 460)')
section('  if s.Overlay=="ResetAccount"then', '   local _,p=popupShell(w,h,pw,190,"Quantity limit"', '  if s.Overlay=="QuantityLimit"then')
section('  elseif s.Overlay=="Guide"then', '  elseif s.Overlay=="Contracts"then', '')
section('  elseif s.Overlay=="Menu"then', '  elseif s.Overlay=="Settings"then', '''  elseif s.Overlay=="Menu"then
   local items={{"Help","Help & guided first trade","Help"},{"Progress","Your progress","Accounts"},{"History","This run's trades","Review"},{"Settings","Settings & sound","Settings"}}
   local _,p=popupShell(w,h,pw,#items*58,"Get Funded!","Help","Menu")
   for i,t in ipairs(items) do
    local b=option(p,t[1],pad,(i-1)*58,iw,50,false,function()
     if t[1]=="Progress" then navigate("Progress");return
     elseif t[1]=="History" then s.Screen="Trade";s.Nav="Trade";s.Sheet="Activity";s.Tab="History";s.Overlay=nil
     else s.Overlay=t[1] end;refresh()
    end)
    sidebarImage(b,t[3],10,7,36).ZIndex=b.ZIndex+3;optionLabel(b,"Label",t[2],56,0,iw-70,50,narrow and 16 or 18)
   end
  elseif s.Overlay=="Blown"then
   local row=tierRow(s.BlownTier)
   local _,p=popupShell(w,h,pw,330,"Account failed","Alert")
   body(p,"Intro","Equity reached $0. Equity is your balance plus the gain or loss on open trades.",pad,0,iw,70,15,C.Text)
   body(p,"Result","This run: "..Market.Signed(row.Realized or 0).." closed trading result.",pad,82,iw,48,16)
   body(p,"Recovery","Start again with $5,000 in-game money. Your titles, milestone rewards and lifetime trading results are kept. Losses stay in lifetime net profit.",pad,138,iw,106,15)
   restartButton(p,row,pad,260,iw,48,17,45,false,true)
''')
section('   local acct=option(p,"SelectAccount"', '   local rows={', '   body(p,"AccountNote","One trading account · all money is in-game",pad,0,iw,48,16)')
a=s.index('   local info=s.Overlay=="Info"');b=s.index('\n  end\n end',a)
s=s[:a]+'''   local info=s.Overlay=="Info"
   local _,p=popupShell(w,h,pw,410,info and "Trading terms" or "How to play","Help")
   body(p,"Body",info and s.Info or "Start with $5,000 in-game money. Buy if you expect a price rise; sell if you expect a fall. Start with size 1. A stop loss helps limit a loss; take profit closes at your target.\\n\\nBalance changes when trades close. Open gain/loss changes with the market and is not yet in your balance. Closing adds the trade's final gain or subtracts its loss.\\n\\nEquity = balance + open gain/loss. At $0 equity, the account fails. Restart free after positions close. Earn permanent titles from closed trades and net profit; grants never count.",pad,0,iw,326,narrow and 13 or 15,C.Text)
   popupButton(p,"ReplayTutorial","Replay guided first trade",pad,348,iw,48,function()s.Screen="Trade";s.Nav="Trade";s.Overlay=nil;s.Sheet=false;s.Coach=1;s.CoachBase=nil;s.CoachDismissed=nil;refresh()end,"Cyan",narrow and 14 or 18)
'''+s[b:]
section(' local function startFunded()', ' local function loading(', '')
section(' local function updateUnlockReadout()', ' local coachSteps=', ''' local function updateUnlockReadout()
  local _,title,ratio,amount=objective();local pf=session.Portfolio
  local panel=canvas:FindFirstChild("AccountSummary");local tile=panel and panel:FindFirstChild("ObjectiveCard")
  if tile and not (pf and pf.Failed) then tile.Title.Text=title;tile.Amount.Text=amount;tile.Track.Fill.Size=UDim2.fromScale(ratio,1) end
  root:SetAttribute("GoalProgress",pf and pf.Next and pf.Next.Progress)
 end
 local KPI_LOOK={Net={C.Blue,C.Panel,C.Cyan},Open={C.Blue,C.Panel,C.Cyan},Capital={C.Blue,C.Panel,C.Cyan},Copy={C.Blue,C.Panel,C.Cyan}}
 local function progressScreen(x,y,w,h,mobile)
  local pf=session.Portfolio or {};local sc=make("ScrollingFrame","Progress",canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan})
  local cw=insetScroll(sc);local yy=0
  sidebarText(sc,"Title","Your progress",4,0,cw-8,44,mobile and 29 or 38);yy=54
  sidebarText(sc,"Rank","Rank: "..(pf.Rank or "New Trader"),4,yy,cw-8,40,mobile and 21 or 28,Color3.fromRGB(255,225,80));yy+=50
  local n=pf.Next;local note="Close trades to earn permanent titles. Net trading profit includes wins and losses across every run. Starting money and restart grants never count."
  if pf.Migrated then note..=" Your earlier results and legacy titles are preserved." end
  local t=text(sc,"Rules",note,4,yy,cw-8,mobile and 106 or 58,15,C.Text,M);t.TextWrapped=true;yy+=t.Size.Y.Offset+16
  if pf.Failed then
   local row=activeRow();restartButton(sc,row,0,yy,cw,48,18,4);yy+=64
  end
  local result=card(sc,"RunResults",0,yy,cw,110,C.Blue,C.Panel,C.Cyan,false)
  sidebarText(result,"Run","Run "..(pf.Run or 1).." · closed result "..Market.Signed(pf.RunProfit or 0),14,10,cw-28,40,mobile and 17 or 24)
  sidebarText(result,"Lifetime","Lifetime net profit: "..Market.Signed(pf.Earned or 0),14,60,cw-28,32,mobile and 16 or 22);yy+=126
  for _,m in ipairs(pf.Milestones or {}) do
   local c=card(sc,m.Key,0,yy,cw,132,m.Earned and Color3.fromRGB(96,40,190) or C.Blue,C.Panel,m.Earned and C.Green or C.Cyan,false)
   local name=sidebarText(c,"Goal",(m.Earned and "✓ " or n and n.Key==m.Key and "NEXT: " or "")..m.Name,14,8,cw-28,44,mobile and 18 or 24);name.TextWrapped=true
   sidebarText(c,"Reward","Title: "..m.Title..(m.Earned and " · earned forever" or ""),14,56,cw-28,26,mobile and 14 or 18)
   sidebarText(c,"Amount",goalAmount(m),14,92,cw-28,24,mobile and 12 or 16);yy+=148
  end
  if pf.Titles and #pf.Titles>0 then
   local t=text(sc,"TitleCollection","Your permanent titles: "..table.concat(pf.Titles,", "),4,yy,cw-8,100,15,C.Text,M);t.TextWrapped=true;yy+=116
  end
  sc.CanvasSize=UDim2.fromOffset(0,yy)
 end''')
# Coach remains connected to actual fills and closes; Help replays the same coach.
s=s.replace('"Set your size","Use − and + to choose how many contracts. Start with 1: your %s starts with %s equity. It fails only when equity is depleted."','"Set your size","Start with 1 contract. Your balance starts at $5,000 in-game money. Equity is balance plus open gain/loss. The account fails at $0 equity."')
s=s.replace('  if s.Coach==2 then local row=activeRow();body=string.format(body,accountShort(),whole(row and row.LossLimit or Ladder.Tiers[1].LossLimit))end','')
a=s.index('  if s.Coach==5 then');b=s.index('  local hasButton=',a)
s=s[:a]+'''  if s.Coach==1 then body="All money here is in-game. Start with $5,000, trade, grow your balance and earn permanent titles. Choose a market to begin." end
  if s.Coach==5 then
   local last=session.History[1];title="First trade complete"
   body=(last and "Closed result: "..Market.Signed(last.Pnl)..". " or "").."Your balance now includes that result. "..(pf.Next and "Next: "..pf.Next.Name.."." or "All milestones earned!")
  end
'''+s[b:]
section(' local celebrationQueue,celebrating=', ' local function mobileBadge()', ''' local function celebrate(event)
  toast("Milestone reached: "..event.Name.." · Title earned: "..event.Title,"success")
 end''')
section(' local function currentScreen()', ' local lastPopup', ''' local function currentScreen()
  if not options.Preview and not session.Portfolio then return "Loading" end
  return s.Screen or "Trade"
 end''')
# Screen routing and static rank replace all switchers/shop routes.
s=s.replace('screen=="Dashboard"','screen=="Progress"').replace('s.Screen=="Dashboard"','s.Screen=="Progress"')
s=s.replace('or screen=="Shop"','').replace('or s.Screen=="Shop"','')
s=s.replace('  elseif screen=="Shop"then\n   shop(12,head+6,w-24,h-head-navH-12,true)\n','')
s=s.replace('   elseif screen=="Shop"then\n    shop(cx,22,usable,h-34,false)\n','')
s=s.replace('dashboard(', 'progressScreen(')
s=s.replace('   s.Nav=s.Nav=="Accounts"and"Trade"or s.Nav','   s.Nav="Trade"')
s=s.replace('  elseif screen=="Shop"then s.Nav="Shop"\n  else s.Nav="Accounts"end','  else s.Nav="Progress"end')
s=s.replace('  if screen=="Welcome"then welcome(w,h)\n  elseif screen=="Loading"then loading(w,h)','  if screen=="Loading"then loading(w,h)')
section('   local switcher=button(rail,"AccountSwitcher"', '   local settings=button(', '''   local rank=sidebarText(rail,"Rank",session.Portfolio and session.Portfolio.Rank or "New Trader",12,rh-111,rw-24,46,18,Color3.fromRGB(255,225,80));rank.TextWrapped=true''')
s=s.replace('74+8*(navH+9)+10','74+4*(navH+9)+10')
s=s.replace('math.clamp(usable*.135,190,h>=800 and 226 or 190)','math.clamp(usable*.12,140,170)')
s=s.replace('board and"Funded accounts"or mobileBadge()','board and "Trade · Grow · Earn titles" or mobileBadge()')
s=s.replace('start=function()navigate("Accounts")end','start=function()navigate("Trade")end')
s=s.replace('Connecting to your funded portfolio…','Connecting to your trading account…')
s=s.replace('  root:SetAttribute("NetRealized",pf and pf.Earned);root:SetAttribute("CopyEnabled",pf and pf.Copy and pf.Copy.Enabled or false)','  root:SetAttribute("NetRealized",pf and pf.Earned)')
s=s.replace('tostring(pf.Wallet),tostring(pf.PurchaseSequence),','')
s=s.replace('   updateAccountDetails()\n','')
section('   if reply.Kind=="Purchase" then', '   if fx and reply.Kind', '')
section('   elseif reply.Kind=="Account"and reply.Ok', '   -- Successful orders update', '''   elseif reply.Kind=="Restart"and reply.Ok then
    s.Overlay=nil;blownQueue={};s.Screen="Trade";s.Nav="Trade"
   end''')
s=s.replace('or reply.Kind=="Activate"','').replace('or reply.Kind=="Purchase"','').replace('or reply.Kind=="Copy"','')
s=s.replace('   if fx then fx:Play("Milestone")end;celebrate(event);refresh()', '''   if event.Kind=="TradeClosed" then
    toast("Closed "..Market.Signed(event.Pnl).." · Balance "..Market.Money(event.Balance)..(event.Next and " · Next: "..event.Next.Name.." ("..goalAmount(event.Next)..")" or " · All milestones earned"),"info")
   elseif event.Kind=="Milestone" then if fx then fx:Play("Milestone") end;celebrate(event) end
   refresh()''')
s=s.replace('Closed profits minus losses count toward unlocks.','Closing adds the final gain to your balance or subtracts the loss.')
s=s.replace('Closing turns open P&L into realized profit or loss, and closed profits minus losses count toward unlocks.','Closing adds the final gain to your balance or subtracts the loss. Only closed trades count toward your goals.')
s=s.replace('A free $5K restart is available when no usable accounts remain.','A free $5,000 restart is available after your account fails.')
s=s.replace('Account blown · view Accounts','Account failed · tap the goal card').replace('Account blown · closing positions…','Account failed · closing positions…')
s=s.replace('CopyDraft=nil,','').replace('local repaintChart,chartView,copyPanel','local repaintChart,chartView')
p.write_text(s,encoding='utf-8')
