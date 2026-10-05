from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
src=root/'src'
backup=root/'backups/ui-polish-before-20260929/src'
backup.mkdir(parents=True,exist_ok=True)
for p in src.glob('*.luau'): shutil.copy2(p,backup/p.name)
p=src/'TerminalUI.luau'; s=p.read_text(encoding='utf-8')
def rep(a,b):
 global s
 assert a in s, a[:100]
 s=s.replace(a,b)
rep('local summary="Next "..pf.Next.Short.." · "..Market.Money(projected)..string.format(" (%.1f%%) projected · ",projected/pf.Next.Goal*100)..Market.Money(confirmed).." confirmed"','local summary="Next "..pf.Next.Short.." · "..amount')
a=s.index(' -- "Max 5 ES"'); b=s.index(' local function account(key)',a)
s=s[:a]+''' -- The neutral quantity control respects the account ceiling and the best available side.
 -- Direction-specific capacity (including working orders) is still rechecked on submission.
 local function quantityLimit()
  local row=activeRow()
  local limit=session.Limit or (row and row.MaxContracts) or Market.MaxOrderQuantity
  local buy,sell=session:MaxOrder(s.Contract,1),session:MaxOrder(s.Contract,-1)
  if buy~=nil and sell~=nil then limit=math.min(limit,math.max(buy,sell))end
  return math.max(0,math.floor(math.min(limit,Market.MaxOrderQuantity)))
 end
 local limitPopupPending=false
 local function quantityLimitPopup(limit)
  s.QuantityLimit=limit;s.QuantitySymbol=s.Contract;s.QuantityAccount=accountName()
  if s.Overlay=="QuantityLimit"or limitPopupPending then return end
  limitPopupPending=true
  -- FocusLost and the clicked + button may both reach here in one input event.
  task.defer(function()
   limitPopupPending=false
   if not alive then return end
   s.Overlay="QuantityLimit";s.Sheet=false;s.Error=nil;refresh()
  end)
 end
''' + s[b:]
rep('  summaryText(tile,"Confirmed","",pad,cardH-53,cw-2*pad,18,side and 14 or 12,C.Text,true)\n  tile.Amount.Position=UDim2.fromOffset(inset,cardH-83)\n  tile.Amount.Size=UDim2.fromOffset(cw-inset-pad,24)\n  tile.Amount.TextSize=side and 19 or 14\n','')
rep('  local mark=frame(track,"ConfirmedMarker",4,2,3,17,C.Cyan,7);round(mark,1)\n  summaryText(track,"Percent","0% projected",6,0,tw-12,21,side and 14 or 12,C.Text,true).ZIndex=8\n','')
rep('setter,formatter,enabled,direct)','setter,formatter,enabled,direct,onExceeded)')
rep('   local maximum=upperBound()\n   local n=', '   local maximum=upperBound()\n   local lower=math.min(minimum,maximum)\n   local n=')
rep('   if not n or n~=n or math.abs(n)==math.huge or n<minimum or n>maximum or(step==1 and n%1~=0)then','''   if onExceeded and n and n==n and math.abs(n)<math.huge and n>maximum then
    current=maximum;field.Text=display(current);setter(current);s.Error=nil;onExceeded(maximum);return false
   end
   if not n or n~=n or math.abs(n)==math.huge or n<lower or n>maximum or(step==1 and n%1~=0)then''')
rep('math.round(n/step)*step,minimum,maximum)','math.round(n/step)*step,lower,maximum)')
rep('    current=math.clamp(math.round((current+d[3]*step)/step)*step,minimum,upperBound())','''    local maximum=upperBound()
    local requested=math.round((current+d[3]*step)/step)*step
    current=math.clamp(requested,math.min(minimum,maximum),maximum)
    if onExceeded and requested>maximum then
     field.Text=display(current);setter(current);s.Error=nil;onExceeded(maximum);return
    end''')
rep('  numericStepper(p,"Quantity",x,y,w,s.Qty,1,1,Market.MaxOrderQuantity,function(n)s.Qty=n;if s.Coach==2 then s.Coach=3 end end)','''  s.Qty=math.min(s.Qty,quantityLimit())
  numericStepper(p,"Quantity",x,y,w,s.Qty,1,1,quantityLimit,function(n)s.Qty=n;if s.Coach==2 then s.Coach=3 end end,nil,true,false,quantityLimitPopup)''')
a=s.index('   heading("QtyLabel","Quantity",yy,iw-110)');b=s.index('   yy+=28',a)
s=s[:a]+'   heading("QtyLabel","Quantity",yy,iw)\n'+s[b:]
rep('  heading("ProtectionLabel","Trade protection",yy+4,iw-104)\n  local settings=gameControl(button(p,"ProtectionSettings","Settings",w-pad-94,yy,94,30,openProtection,C.Panel,C.Text,12),false)\n  settings.Border.Color=C.Cyan','  heading("ProtectionLabel","Trade protection",yy+4,iw)')
rep('  local footerH=152 -- compact, stable actions: fills/closures do not move BUY/SELL','  local footerH=132 -- compact, stable actions: fills/closures do not move BUY/SELL')
rep('  sidebarText(actionParent,"Simulation","SIMULATED · Virtual funds only",16,yy,iw,16,10,C.Muted).TextXAlignment=CENTER;yy+=20\n','')
rep('  local footerH=short and 80 or 112','  local footerH=80')
rep('  if not short then text(footer,"Note","SIMULATED · Virtual funds only",0,83,pw-28,20,10,C.Muted,F,CENTER)end\n','')
rep('  if s.Overlay=="Close"then\n','''  if s.Overlay=="QuantityLimit"then
   local _,p=popupShell(w,h,pw,190,"Quantity limit","Accounts")
   local message="You've reached the maximum of "..tostring(s.QuantityLimit).." "..s.QuantitySymbol.." contracts for your "..s.QuantityAccount.." account."
   body(p,"LimitMessage",message,pad,4,iw,112,narrow and 17 or 19,C.Text)
   popupButton(p,"GotIt","Got it",pad,130,iw,48,close,"Purple",20)
  elseif s.Overlay=="Close"then
''')
rep('  local note=text(shell,"Simulated","All trading, prices and funds are simulated. No real money is involved and nothing can be withdrawn.",pad,yy,iw,34,11,C.Muted,F,CENTER)\n  note.TextWrapped=true;yy+=34+pad-6','  yy+=pad-6')
rep('  local percent=string.format("%.1f%% projected",100*projected/goal)\n','')
rep('   objectiveCard.Confirmed.Text="Confirmed "..Market.Money(confirmed).." · close to unlock"\n   objectiveCard.Track.Percent.Text=percent\n','')
rep('   objectiveCard.Track.ConfirmedMarker.Position=UDim2.fromOffset(4+(objectiveCard.Track.Size.X.Offset-11)*math.clamp(confirmed/goal,0,1),2)\n','')
a=s.index('  local board=canvas:FindFirstChild("Dashboard") local c=board and board:FindFirstChild("NextUnlock")');b=s.index('\n end\n local function tierCard',a)
s=s[:a]+s[b:]
a=s.index('  local cardH=mobile and 204 or 158\n  local prog=card(sc,"NextUnlock"');b=s.index('  sidebarText(sc,"LadderTitle"',a)
s=s[:a]+'  yy+=8\n'+s[b:]
rep('  text(sc,"Footnote","Simulated prop-firm journey · all capital, prices and profits are virtual",0,yy,cw,mobile and 32 or 20,10,C.Muted,F,CENTER).TextWrapped=true;yy+=mobile and 40 or 28','  yy+=8')
rep('   sidebarText(rail,"Simulation","Simulated market",18,62,rw-36,20,14,SB.Muted)\n   sidebarText(rail,"Funds","Virtual funds",18,83,rw-36,18,14,SB.Muted)\n','')
rep('nav(rail,12,118,','nav(rail,12,74,')
rep('local marketY=118+7*','local marketY=74+7*')
rep('  local heroH=narrow and 92 or 124','  local heroH=narrow and 76 or 100')
rep('  sidebarText(hero,"Eyebrow","SIMULATED PROP FIRM · VIRTUAL FUNDS",trophy+20,heroH-(narrow and 36 or 44),cw-trophy-60,22,narrow and 11 or 14,Color3.fromRGB(236,227,255))\n','')
rep('    local maxText=panel and panel:FindFirstChild("QtyMax",true)\n    if maxText then maxText.Text=maxLabel(s.Contract)end\n','')
rep('   updateAccountDetails()','''   updateAccountDetails()
   local maximum=quantityLimit()
   if s.Qty>maximum then s.Qty=maximum end
   for _,panelName in ipairs({"OrderTicket","TradeDock","OptionsSheet"})do
    local panel=canvas:FindFirstChild(panelName)
    local quantity=panel and panel:FindFirstChild("Quantity",true)
    if quantity and not quantity.Value:IsFocused()then quantity.Value.Text=tostring(s.Qty)end
   end''')
# Copy edits preserve account terminology and useful mechanics without disclaimer-only rows.
for a,b in {
 'accountName().." · Virtual funds"':'accountName()',
 'use the order ticket to practice. All prices and funds are simulated.':'use the order ticket to place a trade.',
 ' All funds are simulated.':'',
 'FUNDED ACCOUNT · SIMULATED CAPITAL':'FUNDED ACCOUNT',
 'E-mini futures · simulated market':'E-mini futures',
 'Server-run simulated order book. Prices and slippage come from executions. Virtual funds only; no fees or real market connection. Regime: ':'Prices and slippage come from executions in the order book. Regime: ',
 'SIMULATED PREVIEW':'EDIT PREVIEW',
 'Start → Trade → Earn → Unlock → Scale  ·  simulated capital, virtual funds':'Start → Trade → Earn → Unlock → Scale',
 'Preview · Simulated market · Virtual funds':'Studio preview',
 'SIMULATED / PAUSED':'EXCHANGE / PAUSED',
 'SIMULATED / CONNECTING':'EXCHANGE / CONNECTING',
 'Funded accounts · simulated capital':'Funded accounts',
 'simulated funded capital':'funded capital',
 'simulated capital':'capital',
 'simulated exchange':'exchange',
 'simulated order':'order',
}.items(): s=s.replace(a,b)
p.write_text(s,encoding='utf-8')
for name in ['ChartView','MarketClient','FundedAccounts','WorldService','StatsView','TradingClient.client']:
 p=src/(name+'.luau');s=p.read_text(encoding='utf-8')
 for a,b in {
  ' · simulated capital':'', ' · simulated':'', 'simulated exchange':'exchange',
  'simulated funded capital':'funded capital','fresh simulated capital':'fresh capital',
  ' Trading and funds are simulated.':'',
  'Server-authoritative simulated order book. Virtual funds only.':'Server-authoritative order book.',
 }.items():s=s.replace(a,b)
 p.write_text(s,encoding='utf-8')
