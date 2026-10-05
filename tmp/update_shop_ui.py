from pathlib import Path
root=Path(__file__).resolve().parents[1];f=root/'src/TerminalUI.luau';s=f.read_text(encoding='utf-8')
s=s.replace('Leaderboard="rbxassetid://80175474742009",Stats=', 'Shop="rbxassetid://133669386970310",Leaderboard="rbxassetid://80175474742009",Stats=')
s=s.replace('if value=="Leaderboard"or value=="Stats"then','if value=="Leaderboard"or value=="Stats"or value=="Shop"then')
s=s.replace('s.Screen=="Dashboard"or s.Screen=="Leaderboard"or s.Screen=="Stats"then','s.Screen=="Dashboard"or s.Screen=="Leaderboard"or s.Screen=="Stats"or s.Screen=="Shop"then')
s=s.replace('mobile and {"Trade","Accounts","Stats","Leaderboard","Positions","Learn"}or{"Trade","Accounts","Stats","Leaderboard","Positions","Review","Learn"}', 'mobile and {"Trade","Accounts","Shop","Stats","Leaderboard","Positions"}or{"Trade","Accounts","Shop","Stats","Leaderboard","Positions","Review","Learn"}')
s=s.replace('local marketY=74+7*(navH+9)+10','local marketY=74+8*(navH+9)+10')
s=s.replace('if s.Screen=="Leaderboard"then return "Leaderboard"end','if s.Screen=="Leaderboard"then return "Leaderboard"end\n  if s.Screen=="Shop"then return "Shop"end')
s=s.replace('screen=="Dashboard"or screen=="Leaderboard"or screen=="Stats"','screen=="Dashboard"or screen=="Leaderboard"or screen=="Stats"or screen=="Shop"')
s=s.replace('elseif screen=="Stats"then s.Nav="Stats"','elseif screen=="Stats"then s.Nav="Stats"\n  elseif screen=="Shop"then s.Nav="Shop"')
s=s.replace('elseif screen=="Stats"then\n   statsScreen', 'elseif screen=="Shop"then\n   shop(12,head+6,w-24,h-head-navH-12,true)\n  elseif screen=="Stats"then\n   statsScreen')
s=s.replace('elseif screen=="Stats"then\n    statsScreen', 'elseif screen=="Shop"then\n    shop(cx,22,usable,h-34,false)\n   elseif screen=="Stats"then\n    statsScreen')
s=s.replace('for _,list in ipairs({pf.Accounts or{},pf.Legacy or{}})', 'for _,list in ipairs({pf.Accounts or{}})')
s=s.replace('for _,list in ipairs({pf and pf.Accounts or{},pf and pf.Legacy or{}})do for _,row in ipairs(list)do if row.State==nil or row.State=="Active"then', 'for _,list in ipairs({pf and pf.Accounts or{}})do for _,row in ipairs(list)do if row.State=="Active" and not row.Breached then')
s=s.replace('  if pf.ActiveKind=="Legacy"then return "LEGACY ACCOUNT","Not counted toward unlocks",0,"Net "..net(pf.Earned),"Legacy · not counted toward unlocks"end\n','')
s=s.replace('local projected=pf.Next.Projected or confirmed','local projected=math.max(0,pf.Next.Projected or confirmed)').replace('local projected=n.Projected or confirmed','local projected=math.max(0,n.Projected or confirmed)')
s=s.replace('local function tierShort(key)for _,t in ipairs(Ladder.Tiers)do if t.Id==key then return t.Short end end return key end','local function tierShort(key)\n  for _,row in ipairs(session.Portfolio and session.Portfolio.Accounts or {}) do if row.Key==key then return row.Short end end\n  for _,t in ipairs(Ladder.Tiers)do if t.Id==key then return t.Short end end return key or "Account" end')
s=s.replace('return short and"Restart"or"Restart Account",s.PendingRestart~=nil','return "Free $5K restart",s.PendingRestart~=nil')
s=s.replace('if not row or not row.Depleted or row.Key~=Ladder.StarterTier then fail("Only the $5K has a free reset. Re-earn higher tiers through their progression goal.");return end','if not row or not row.Depleted or not row.CanRestart then fail("A free $5K restart is available when no usable accounts remain.");return end')
s=s.replace('  if row.Reearn then return nil end\n','')
s=s.replace('row.Reearn and row.State=="Locked" and"RE-EARN"or ', '')
s=s.replace('(row.Reearn and"Re-earn: "or"Stage goal: ")', '"Stage goal: "')
s=s.replace('Equity hit $0 · liquidated. Restart restores "..whole(row.Size)..".', 'Tier access stays unlocked. History is preserved.')
# Replace the depletion dialog: permanent access, per-instance results and a global recovery action.
a=s.index('  elseif s.Overlay=="Blown"then',s.index('local function overlay'));b=s.index('  elseif s.Overlay=="Settings"then',a)
s=s[:a]+'''  elseif s.Overlay=="Blown"then
   local row=tierRow(s.BlownTier)
   local _,p=popupShell(w,h,pw,354,"Account blown","Alert",row.Name)
   body(p,"Intro",row.Closing and "Equity reached $0. The remaining positions are closing." or "This account can no longer trade. Its result and history stay in Stats.",pad,0,iw,66,15,C.Text)
   optionLabel(p,"Permanent","Your tier stays unlocked forever",pad,74,iw,30,narrow and 15 or 18,SC.Green)
   body(p,"Result","Account result: "..Market.Signed(row.Realized or 0)..". Blown-account losses do not become debt toward future unlocks.",pad,116,iw,64,14)
   body(p,"Recovery",pf.CanRestart and "No usable accounts remain. A free $5K restart starts next-stage progress at $0 and keeps every earned tier." or "Switch to a usable account, or buy another instance of an unlocked tier in the Shop.",pad,188,iw,70,14)
   if pf.CanRestart then restartButton(p,row,pad,274,iw,48,17,45,false,true)
   else popupButton(p,"OpenShop","Open Shop",pad,274,iw,48,function()navigate("Shop")end,"Purple",18) end
   text(p,"Note","Permanent access · independent accounts · retained history",pad,330,iw,20,10,C.Muted,F,CENTER,44).TextWrapped=true
'''+s[b:]
# Purchase confirmation and durable success are styled with the same illustrated dialog components.
marker='  if s.Overlay=="QuantityLimit"then'
confirm='''  if s.Overlay=="Purchase"then
   local intent=s.ShopIntent
   if not intent then close();return end
   local _,p=popupShell(w,h,pw,352,"Buy account?","Shop",intent.Name)
   optionLabel(p,"Price","Price  "..whole(intent.Price),pad,0,iw,34,23,Color3.fromRGB(255,222,70))
   optionLabel(p,"Available","Available  "..Market.Money(pf.Wallet or 0),pad,42,iw,26,17,SC.Green)
   optionLabel(p,"After","After purchase  "..Market.Money(math.max(0,(pf.Wallet or 0)-intent.Price)),pad,78,iw,26,16)
   body(p,"Details","Adds a separate "..whole(intent.Size).." funded account with its own balance, positions and history. Your tier access, unlock progress and trading stats stay intact.",pad,116,iw,100,15)
   local pending=s.PendingPurchase~=nil
   local buy=popupButton(p,"ConfirmPurchase",pending and "Saving purchase…" or "Confirm · "..whole(intent.Price),pad,234,iw,50,function()
    if s.PendingPurchase then return end
    local ok,message,_,id=session:Purchase(intent.Tier,intent.Sequence)
    if not ok then fail(message);return end
    local request={Id=id,Tier=intent.Tier,Sequence=intent.Sequence};s.PendingPurchase=request;s.Error=nil;refresh()
    task.delay(20,function()
     if alive and s.PendingPurchase==request then s.PendingPurchase=nil;toast("Confirmation is taking longer. Retrying this confirmation checks the same purchase.","info") end
    end)
   end,pending and "Navy" or "Green",18)
   buy.Active=not pending;buy:SetAttribute("Debounce",1)
   popupButton(p,"CancelPurchase",pending and "Close" or "Cancel",pad,296,iw,42,close,"Navy",16)
  elseif s.Overlay=="PurchaseComplete"then
   local receipt=s.ShopReceipt
   local _,p=popupShell(w,h,pw,260,"Account added!","Shop")
   body(p,"Receipt",receipt and (tierShort(receipt.Key).." is ready. Purchase #"..receipt.Sequence.." saved.") or "Your new account is ready.",pad,0,iw,64,19,SC.Green)
   body(p,"Balance","Available Shop balance: "..Market.Money(pf.Wallet or 0)..". Switch accounts whenever you are ready to trade.",pad,76,iw,70,15)
   popupButton(p,"ViewPurchasedAccount","View accounts",pad,164,iw,48,function()navigate("Accounts")end,"Purple",18)
   popupButton(p,"ContinueShopping","Continue shopping",pad,222,iw,38,close,"Navy",16)
  elseif s.Overlay=="QuantityLimit"then'''
s=s.replace(marker,confirm)
# Keep each owned instance distinct and readable at phone widths.
s=s.replace('sidebarText(c,"Size",row.Short,14,10,w-140,32,26,titleColor)','sidebarText(c,"Size",row.Short,14,10,w-140,32,22,titleColor).TextScaled=true')
s=s.replace('sidebarText(c,"Size",row.Short,16,12,w-32,36,30,titleColor)','sidebarText(c,"Size",row.Short,16,12,w-132,36,24,titleColor).TextScaled=true')
s=s.replace('text(c,"Kind","Funded account",','text(c,"Kind","Permanent tier access",')
start=s.index('  if active and row.Breached then',s.index('local function tierCard'));end=s.index('  elseif active and current then',start)
s=s[:start]+'''  if active and row.Breached then
   action(row.Closing and "Closing positions…" or "View blown account",function()openBlown(row.Key)end,"Pink")
'''+s[end:]
s=s.replace('if row.State=="Active"then table.insert(actives,row)end','if row.State=="Active" and not row.Breached then table.insert(actives,row)end')
s=s.replace('local bw=math.min(124,(iw-8*(#actives-1))/#actives)','local columns=math.max(1,math.floor((iw+8)/140));local bw=(iw-8*(columns-1))/columns')
s=s.replace('pad+(i-1)*(bw+8),yy,bw,38','pad+((i-1)%columns)*(bw+8),yy+math.floor((i-1)/columns)*46,bw,38')
s=s.replace('pad+index*(bw+8),yy,bw,38','pad+(index%columns)*(bw+8),yy+math.floor(index/columns)*46,bw,38')
s=s.replace('  yy+=48\n  sidebarText(cc,"FollowLabel"','  yy+=math.ceil(#actives/columns)*46+4\n  sidebarText(cc,"FollowLabel"')
s=s.replace('  yy+=48\n  sidebarText(cc,"SizingLabel"','  yy+=math.ceil(index/columns)*46+4\n  sidebarText(cc,"SizingLabel"')
# Replace old mixed tier/legacy dashboard with permanent tiers, usable instances, then blown history.
a=s.index(' local function dashboard(');b=s.index(' local coachSteps=',a)
s=s[:a]+''' local function shop(x,y,w,h,mobile)
  local pf=session.Portfolio or {Tiers={},Wallet=0}
  local sc=make("ScrollingFrame","Shop",canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,ScrollingDirection=Enum.ScrollingDirection.Y})
  local cw=w-10;local narrow=cw<600;local yy=0
  sidebarText(sc,"Title","Account Shop",0,0,cw,44,narrow and 28 or 36);yy=54
  local wallet=card(sc,"EarnedWallet",0,yy,cw,narrow and 208 or 160,Color3.fromRGB(8,160,130),Color3.fromRGB(2,76,100),SC.Green,true)
  sidebarText(wallet,"Label","AVAILABLE EARNED PROFIT",18,12,cw-36,24,narrow and 15 or 18)
  sidebarText(wallet,"Balance",Market.Money(pf.Wallet or 0),18,42,cw-36,44,32,Color3.fromRGB(255,234,80))
  local explanation=text(wallet,"Explanation","Earn balance when closed funded trades set a new net-profit high on an account. Recovering old losses earns no extra balance. Starting capital and open P&L never count.",18,96,cw-36,narrow and 100 or 52,14,C.Text,M);explanation.TextWrapped=true
  yy+=wallet.Size.Y.Offset+18
  local note=text(sc,"PermanentNote","Unlocked tiers stay yours forever. Buy as many separate accounts as you can afford.",0,yy,cw,narrow and 56 or 28,15,C.Text,M);note.TextWrapped=true;yy+=narrow and 70 or 42
  local cols=narrow and 1 or math.max(1,math.floor((cw+14)/270));local gap=14;local bw=(cw-gap*(cols-1))/cols;local bh=270
  for i,row in ipairs(pf.Tiers or {}) do
   local bx=((i-1)%cols)*(bw+gap);local by=yy+math.floor((i-1)/cols)*(bh+gap)
   local c=card(sc,"Shop"..row.Key,bx,by,bw,bh,row.Permanent and Color3.fromRGB(103,47,224) or Color3.fromRGB(10,46,115),row.Permanent and Color3.fromRGB(38,28,120) or Color3.fromRGB(3,24,65),row.Permanent and Color3.fromRGB(198,137,255) or C.Border,true)
   sidebarText(c,"Size",row.Short.." account",16,12,bw-32,32,25)
   text(c,"Capital",whole(row.Size).." funded capital",16,50,bw-32,24,16,C.Text,M)
   chip(c,"Access",row.Permanent and "UNLOCKED FOREVER" or "LOCKED",16,84,row.Permanent and SC.Green or C.Muted,bw-32)
   sidebarText(c,"Price",whole(row.Price),16,120,bw-32,34,29,Color3.fromRGB(255,228,80))
   local detail=row.Permanent and ((row.Usable or 0).." usable · "..(row.Blown or 0).." blown · "..(row.Affordable and "Ready to buy" or (whole(math.max(0,row.Price-(pf.Wallet or 0))).." more needed"))) or ("Earn this tier through the funded ladder.")
   local label=text(c,"Availability",detail,16,160,bw-32,48,14,C.Text,M);label.TextWrapped=true
   local enabled=row.Permanent and row.Affordable and not s.PendingPurchase
   local buy=glossy(button(c,"Buy",s.PendingPurchase and "Saving…" or not row.Permanent and "Tier locked" or not row.Affordable and "Insufficient balance" or "Buy account",14,218,bw-28,40,function()
    if not enabled then return end
    s.ShopIntent={Tier=row.Key,Name=row.Name,Size=row.Size,Price=row.Price,Sequence=pf.PurchaseSequence};s.Overlay="Purchase";refresh()
   end,C.Raised,C.Text,16),enabled and "Green" or "Navy")
   buy.Active=enabled;buy:SetAttribute("Affordable",row.Affordable);buy:SetAttribute("Unlocked",row.Permanent)
  end
  yy+=math.ceil(#(pf.Tiers or {})/cols)*(bh+gap)
  if pf.CanRestart then
   local recovery=glossy(button(sc,"FreeRestart","No usable accounts? Get a free $5K restart",0,yy,cw,56,function()
    for _,row in ipairs(pf.Accounts or {}) do if row.Depleted then restartAccount(row.Key);return end end
   end,C.Raised,C.Text,narrow and 14 or 19),"Pink");yy+=70
  end
  sc.CanvasSize=UDim2.fromOffset(0,yy+8)
 end
 local function dashboard(x,y,w,h,mobile)
  local pf=session.Portfolio or {Accounts={},Tiers={},Copy={Enabled=false,Followers={}}}
  local sc=make("ScrollingFrame","Dashboard",canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),CanvasSize=UDim2.new(),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,ScrollingDirection=Enum.ScrollingDirection.Y})
  local cw=w-10;local narrow=cw<600;local yy=0
  sidebarText(sc,"Title","Your accounts",0,0,cw,42,narrow and 28 or 36)
  local subtitle=text(sc,"Subtitle",(pf.UnlockedCount or 0).." permanent tiers · "..(pf.UsableCount or 0).." usable accounts · "..(pf.BlownCount or 0).." blown",0,48,cw,46,15,SB.Muted,M);subtitle.TextWrapped=true;yy=100
  glossy(button(sc,"OpenShop","Shop · "..Market.Money(pf.Wallet or 0).." available",0,yy,cw,48,function()navigate("Shop")end,C.Raised,C.Text,narrow and 17 or 22),"Purple");yy+=62
  if pf.CanRestart then
   local recovery=text(sc,"RecoveryNote","All accounts are blown. Start a free $5K account with $0 progress toward your next unearned tier. Permanent unlocks and funded history stay with you.",0,yy,cw,narrow and 88 or 48,15,C.Text,M);recovery.TextWrapped=true;yy+=recovery.Size.Y.Offset+8
   glossy(button(sc,"FreeRestart","Free $5K restart",0,yy,cw,48,function()
    for _,row in ipairs(pf.Accounts or {}) do if row.Depleted then restartAccount(row.Key);return end end
   end,C.Raised,C.Text,20),"Pink");yy+=64
  elseif not pf.Started then glossy(button(sc,"Start","Start free $5K account",0,yy,cw,48,startFunded,C.Raised,C.Text,20),"Green");yy+=64 end
  if pf.Next then
   local n=pf.Next;local c=card(sc,"NextUnlock",0,yy,cw,146,Color3.fromRGB(9,112,216),Color3.fromRGB(3,43,118),C.Cyan,true)
   sidebarText(c,"Label","NEXT UNLOCK · "..n.Name,16,10,cw-32,26,narrow and 16 or 22)
   sidebarText(c,"Amount",Market.Money(math.max(0,n.Projected or n.Progress)).." / "..whole(n.Goal),16,44,cw-32,34,narrow and 24 or 30)
   progressBar(c,"Progress",16,90,cw-32,12,math.clamp((n.Projected or n.Progress)/math.max(1,n.Goal),0,1),SC.Green)
   text(c,"Rule","Live P&L preview · only closed profit unlocks tiers",16,112,cw-32,26,narrow and 11 or 14,C.Text,M).TextWrapped=true
   yy+=162
  end
  sidebarText(sc,"AccessTitle","Permanent tier access",0,yy,cw,30,23);yy+=38
  local cols=narrow and 1 or math.max(1,math.floor((cw+12)/245));local bw=(cw-12*(cols-1))/cols;local bh=164
  for i,row in ipairs(pf.Tiers or {}) do
   local c=card(sc,"Access"..row.Key,((i-1)%cols)*(bw+12),yy+math.floor((i-1)/cols)*(bh+12),bw,bh,Color3.fromRGB(10,62,148),Color3.fromRGB(3,30,83),row.Permanent and SC.Green or C.Border,false)
   sidebarText(c,"Name",row.Name,14,10,bw-28,28,22)
   text(c,"Status",row.Permanent and "UNLOCKED FOREVER" or "Not yet earned",14,48,bw-28,22,14,row.Permanent and SC.Green or C.Muted,M)
   local label=row.Claimable and "Activate first account · free" or row.Permanent and "Open Shop" or "Earn "..whole(row.Goal).." this stage"
   local b=glossy(button(c,"Action",label,12,102,bw-24,44,function()
    if row.Claimable then local ok,message=session:Activate(row.Key);if not ok then fail(message)end
    elseif row.Permanent then navigate("Shop") end
   end,C.Raised,C.Text,14),row.Claimable and "Gold" or row.Permanent and "Purple" or "Navy")
   b.Active=row.Permanent
  end
  yy+=math.ceil(#(pf.Tiers or {})/cols)*(bh+12)+12
  local function accountSection(title,blown)
   local rows={};for _,row in ipairs(pf.Accounts or {}) do if (row.Breached==true)==blown then table.insert(rows,row) end end
   sidebarText(sc,blown and "BlownTitle" or "OwnedTitle",title.." ("..#rows..")",0,yy,cw,30,23);yy+=40
   if #rows==0 then text(sc,"EmptyAccounts",blown and "Your funded history stays here when an account is blown." or "No usable accounts yet.",0,yy,cw,44,14,SB.Muted,M).TextWrapped=true;yy+=56;return end
   local ncols=narrow and 1 or math.max(1,math.floor((cw+12)/280));local width=(cw-12*(ncols-1))/ncols;local height=narrow and 218 or 300
   for i,row in ipairs(rows) do tierCard(sc,row,((i-1)%ncols)*(width+12),yy+math.floor((i-1)/ncols)*(height+12),width,height,narrow,pf) end
   yy+=math.ceil(#rows/ncols)*(height+12)+12
  end
  accountSection("Usable owned accounts",false)
  local copyY=yy;if pf.Started then yy+=copyCard(sc,yy,cw,narrow,pf)+22 end
  accountSection("Blown accounts · history kept",true)
  sc.CanvasSize=UDim2.fromOffset(0,yy+8)
  if s.Focus=="Copy"then s.Focus=nil;task.defer(function()if sc.Parent then sc.CanvasPosition=Vector2.new(0,math.max(0,copyY-12))end end)end
 end
'''+s[b:]
# Live next-unlock preview on account management as well as trading summary.
s=s.replace('  local summary=canvas:FindFirstChild("AccountSummary") local objectiveCard=', '''  local dashboard=canvas:FindFirstChild("Dashboard");local nextCard=dashboard and dashboard:FindFirstChild("NextUnlock")
  if nextCard then
   nextCard.Amount.Text=amount
   local fill=nextCard.Progress:FindFirstChild("Fill")
   if fill then fill.Size=UDim2.fromOffset((nextCard.Progress.Size.X.Offset-4)*ratio,fill.Size.Y.Offset);fill.Visible=projected>0 end
  end
  local summary=canvas:FindFirstChild("AccountSummary") local objectiveCard=''')
s=s.replace('   if restarting then s.PendingRestart=nil end','''   if restarting then s.PendingRestart=nil end
   if reply.Kind=="Purchase" then
    s.PendingPurchase=nil
    if reply.Ok then s.ShopReceipt=reply.Receipt;s.ShopIntent=nil;s.Overlay="PurchaseComplete" end
   end''')
s=s.replace('or reply.Kind=="Restart"then fx:Play("Success")','or reply.Kind=="Restart"or reply.Kind=="Purchase"then fx:Play("Success")')
s=s.replace('if pf and pf.Active==reply.Tier then s.Screen="Trade";s.Nav="Trade"end','if pf and pf.Active then s.Screen="Trade";s.Nav="Trade"end')
# Wallet changes and purchase receipts participate in structure refreshes.
s=s.replace('local parts={pf.Revision', 'local parts={pf.Revision')
# Prevent old popup lists and client tokens from growing outside the screen: popupShell already scrolls.
f.write_text(s,encoding='utf-8')
# Stats sums open P&L across every distinct instance in a tier.
f=root/'src/StatsView.luau';s=f.read_text(encoding='utf-8')
s=s.replace(' for _,x in ipairs(data and data.Legacy or {}) do table.insert(list,x) end\n','')
a=s.index('  local list=scope.Kind=="Tier"');b=s.index('\n end\n return agg',a)
s=s[:a]+'''  local total,seen=0,{}
  for _,r in ipairs(pf.Accounts or {}) do
   if r.Tier==scope.Key and not seen[r.Key] then seen[r.Key]=true;total+=r.Unrealized or 0 end
  end
  return total'''+s[b:]
s=s.replace('if scope.Kind=="Legacy" then\n  text="Pre-ladder account, shown separately. It is never included in funded totals, unlocks or the leaderboard."\n elseif scope.Kind=="All" and period=="Life" then','if scope.Kind=="All" and period=="Life" then')
s=s.replace(' Legacy accounts are excluded.','').replace('Earlier attempts, restarted accounts and legacy accounts are excluded.','Blown and retired accounts are excluded.')
a=s.index('  local n=scope.Attempt or 1');b=s.index('\n end',a)
s=s[:a]+'''  text=scope.Name.." · all "..plural(a,"usable account").." in this tier. Blown and retired accounts are excluded."'''+s[b:]
s=s.replace('(scope and scope.Kind~="Legacy" and state.StatsPeriod=="Current")','(scope and state.StatsPeriod=="Current")')
s=s.replace(' or item.Kind=="Legacy" and (narrow and "Legacy" or item.Name)','')
s=s.replace('local current=scope.Kind=="All" and (narrow and "Current only" or "Current attempts only") or ("Current attempt"..(scope.Attempt and (" #"..scope.Attempt) or ""))','local current=narrow and "Usable only" or "All usable accounts"')
s=s.replace('scope.Kind=="Legacy" and "Legacy lifetime" or current','current')
s=s.replace(' or scope.Kind=="Legacy" and "LEGACY ACCOUNTS · NOT IN FUNDED TOTALS"','').replace(' or scope.Kind=="Legacy" and "LIFETIME"','')
s=s.replace('scope.Kind=="Legacy" and C.Border or C.Cyan','C.Cyan')
f.write_text(s,encoding='utf-8')
