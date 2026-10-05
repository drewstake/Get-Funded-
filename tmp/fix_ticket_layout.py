exec((__import__('pathlib').Path(__file__).parent/'fix_chart_ui.py').read_text().split("s=read('ChartViewport.luau')")[0])
s=read('TerminalUI.luau')
s=s.replace('StopTicks','StopDollars').replace('TargetTicks','TargetDollars')
s=replace(s,'StopDollars=40,TargetDollars=120','StopDollars=500,TargetDollars=1500')
start=s.index('  if (s.StopOn and(s.StopDollars');end=s.index('\n  end',start)+len('\n  end')
s=s[:start]+'''  for _,field in ipairs({"Stop","Target"})do
   if s[field.."On"]then
    local resolved,err=Market.Protection(Market.Contracts[s.Contract],qty,s[field.."Dollars"])
    if not resolved then fail(err);effect(paths,"Error");return false end
   end
  end'''+s[end:]
anchor=' local function openProtection()'
s=replace(s,anchor,''' -- Dollar intentions persist when quantity/instrument changes; only the derived ticks/prices change.
 local function protectionValue(field,draft)
  local source=draft or s
  return Market.Protection(Market.Contracts[s.Contract],s.Qty,source[field.."Dollars"])
 end
 local function effective(field,draft)
  local v=protectionValue(field,draft)
  return v and Market.Money(v.Dollars)or"Invalid amount"
 end
 local function updateProtectionReadout()
  for _,item in ipairs(canvas:GetDescendants())do
   if item:IsA("TextLabel")then
    local key=item:GetAttribute("ProtectionField")
    if key then
     local draft=item:GetAttribute("Draft")and s.ProtectionDraft or s
     item.Text=draft and draft[key.."On"]and("Effective "..effective(key,draft).." total")or"Off"
    elseif item.Name=="Risk"then
     item.Text=s.StopOn and("Estimated total loss  "..effective("Stop"))or"No stop loss configured"
    elseif item.Name=="ProtectionHint"then
     item.Text="Estimated totals for "..s.Qty.." contract"..(s.Qty==1 and""or"s").." · fills may vary"
    end
   end
  end
  local entry=s.Type=="Market"and session.Prices[s.Contract]or s.Limit
  for _,key in ipairs({"Stop","Target"})do
   for _,dir in ipairs({1,-1})do
    local p=s[key.."On"]and Market.Protection(Market.Contracts[s.Contract],s.Qty,s[key.."Dollars"],entry,dir,key)
    root:SetAttribute(key..(dir==1 and"BuyPrice"or"SellPrice"),p and p.Price or nil)
    root:SetAttribute(key.."EffectiveDollars",p and p.Dollars or nil)
   end
  end
 end
'''+anchor)
# focus loss updates labels without destroying the button just clicked
start=s.index('   local contract=Market.Contracts[s.Contract]\n   for _,item in ipairs(canvas:GetDescendants())do',s.index(' local function numericStepper'))
end=s.index('\n  end)',start)
s=s[:start]+'   updateProtectionReadout()'+s[end:]
s=replace(s,'or"Enter a valid positive limit price."','or"Enter a valid positive amount."')
s=replace(s,'local cw=stacked and w or(w-gap)/2 local ch=104','local cw=stacked and w or(w-gap)/2 local ch=130')
s=replace(s,'sidebarText(card,"Unit","Ticks",10,31,cw-70,22,12,C.Muted)','sidebarText(card,"Unit","Dollars",10,31,cw-70,22,14,C.Text)')
s=replace(s,'numericStepper(card,"Distance",8,ch-50,cw-16,s[key.."Ticks"],1,1,10000,function(n)s[key.."Ticks"]=n end,nil,enabled)', '''numericStepper(card,"Distance",8,58,cw-16,s[key.."Dollars"],.01,.01,100000000,function(n)s[key.."Dollars"]=n;updateProtectionReadout()end,Market.Money,enabled)
   local e=text(card,"Effective",enabled and("Effective "..effective(key).." total")or"Off",8,104,cw-16,22,12,C.Text,F,CENTER)
   e:SetAttribute("ProtectionField",key)''')
s=replace(s,'"Distances from your entry price"','"Estimated totals for "..s.Qty.." contracts · fills may vary"')
s=replace(s,'("Estimated risk  "..Market.Money(s.StopDollars*contract.Tick*contract.Multiplier*s.Qty))','("Estimated total loss  "..effective("Stop"))')
s=replace(s,'tostring(d[4]).." ticks"','effective(d[1])')
s=replace(s,'" · Auto-close distances from entry"','" · Estimated total loss / profit"')
s=replace(s,' The bars underneath show volume.','')
s=replace(s,'"Set distances from your entry price"','"Estimated total loss / profit for "..s.Qty.." contracts"')
s=replace(s,'{"Stop","Stop Loss","Stop distance",C.Red},{"Target","Take Profit","Profit target",C.Green}','{"Stop","Stop Loss","Total loss amount ($)",C.Red},{"Target","Take Profit","Total profit amount ($)",C.Green}')
s=replace(s,'draft[key.."Ticks"],1,1,10000,function(n)draft[key.."Ticks"]=n end,nil,on','draft[key.."Dollars"],.01,.01,100000000,function(n)draft[key.."Dollars"]=n;updateProtectionReadout()end,Market.Money,on')
s=replace(s,'text(card,"Unit","ticks",16,127,cw-32,22,12,C.Muted,F,CENTER)', '''local unit=text(card,"Unit",on and("Effective "..effective(key,draft).." total")or"Off",16,127,cw-32,22,14,C.Text,F,CENTER)
   unit:SetAttribute("ProtectionField",key);unit:SetAttribute("Draft",true)''')
s=replace(s,'"Applies to your next order"','"Next order · rounded to valid prices · fills may vary"')
s=replace(s,'  local lastStructure=""','  local lastStructure=""')
s=replace(s,'   local cancelled=chartView:OnMarketUpdate()','   updateProtectionReadout()\n   updateUnlockReadout()\n   local cancelled=chartView:OnMarketUpdate()')
# Progress must be present at zero so updates can reveal it without a full rebuild.
start=s.index(' local function progressBar(');end=s.index('\n end',start)
chunk=s[start:end]
chunk=replace(chunk,'  if progress>0 then','  do')
chunk=replace(chunk,'   if color==C.Green then','   fill.Visible=progress>0\n   if color==C.Green then')
s=s[:start]+chunk+s[end:]
# Render and live update both consume authoritative Next, including writeoffs/reset credit.
idx=s.index(' local function tierCard(')
s=s[:idx]+''' local function updateUnlockReadout()
  local pf=session.Portfolio local nextStage=pf and pf.Next
  if not nextStage then return end
  local value,goal=nextStage.Progress or 0,nextStage.Goal
  root:SetAttribute("UnlockProgress",value);root:SetAttribute("UnlockGoal",goal)
  local board=canvas:FindFirstChild("Dashboard") local card=board and board:FindFirstChild("NextUnlock")
  if card and card:FindFirstChild("Amount")then
   card.Amount.Text=whole(value).." / "..whole(goal)
   card.Title.Text=nextStage.Name
   card.Remaining.Text=whole(nextStage.Remaining).." more realized profit. Open P&L is not counted."
   local fill=card.Progress:FindFirstChild("Fill")
   if fill then fill.Visible=value>0;fill.Size=UDim2.fromOffset(math.max(0,(card.Progress.Size.X.Offset-4)*math.clamp(value/goal,0,1)),fill.Size.Y.Offset)end
  end
 end
'''+s[idx:]
s=replace(s,'string.format("%.2f",pf.Earned or 0),tostring(pf.ActiveCount)','string.format("%.2f",pf.Earned or 0),tostring(pf.Progress),pf.Next and tostring(pf.Next.Goal)..":"..tostring(pf.Next.Progress)or"complete",tostring(pf.ActiveCount)')
s=replace(s,'for _,o in ipairs(session.Orders)do signature..=":"..o.Id..":"..o.Quantity end','for _,o in ipairs(session.Orders)do signature..=":"..o.Id..":"..o.Quantity..":"..tostring(o.Price) end')
# Tier mobile: spacious two-line body and a full-width action; keep the existing card finish.
start=s.index('  if mobile then\n   sidebarText(c,"Size",row.Short',s.index(' local function tierCard'))
end=s.index('  else\n   sidebarText(c,"Size",row.Short',start)
s=s[:start]+'''  if mobile then
   sidebarText(c,"Size",row.Short,14,10,w-140,32,26,titleColor)
   chip(c,"Status",status,w-122,14,statusColor,108)
   if role then chip(c,"Role",role,w-122,42,C.Blue,108)end
   if active then
    text(c,"Balance","Balance  "..Market.Money(row.Balance or 0),14,52,w-28,26,20,C.Text,N)
    text(c,"Realized","Realized  "..Market.Signed(row.Realized or 0),14,84,w-28,24,16,(row.Realized or 0)>=0 and SC.Green or SC.Red,N)
    local t=text(c,"Open",row.Breached and(row.Closing and"Blown · closing positions…"or"Blown · equity reached $0")or((row.Positions or 0).." open · "..Market.Signed(row.Unrealized or 0).." open P&L"),14,112,w-28,36,14,C.Text,N);t.TextWrapped=true
   elseif ready then
    sidebarText(c,"Ready",starting and"Your first account"or"Unlocked · ready",14,58,w-28,26,19,Color3.fromRGB(255,222,70))
    text(c,"Capital",whole(row.Size).." simulated capital",14,92,w-28,24,16,C.Text)
   else
    local t=text(c,"Requirement","Stage goal: "..whole(row.Goal).." net profit",14,56,w-28,44,16,C.Text);t.TextWrapped=true
    progressBar(c,"Progress",14,106,w-28,10,math.clamp((row.Progress or 0)/math.max(1,row.Goal or row.Unlock),0,1),C.Blue)
    text(c,"Remaining",whole(math.max(0,(row.Goal or row.Unlock)-(row.Progress or 0))).." to go",14,130,w-28,24,16,C.Text,N)
   end
'''+s[end:]
s=replace(s,'local bw=mobile and(w<300 and 88 or 106)or w-28;local bx=mobile and w-bw-12 or 14;local by=mobile and(h-40)/2 or h-54','local bw=w-28;local bx=14;local by=h-54')
# Desktop cards: wider columns, taller labels/body, reserve bottom action.
start=s.index(' local function tierCard(');end=s.index(' local function copyCard(',start)
chunk=s[start:end]
chunk=chunk.replace(',16,11,Color3.fromRGB',',20,14,Color3.fromRGB').replace(',14,10,Color3.fromRGB',',18,14,Color3.fromRGB')
chunk=chunk.replace('16,86,w-32,24,w<200 and 16 or 19','16,94,w-32,30,24').replace('16,112,w-32,14,10','16,132,w-32,18,14').replace('16,126,w-32,24,w<200 and 15 or 18','16,154,w-32,30,22')
chunk=chunk.replace('row.Breached and 144 or 152,w-32,row.Breached and 26 or 16,10','190,w-32,46,14').replace('t.TextWrapped=row.Breached==true','t.TextWrapped=true')
chunk=chunk.replace('16,110,w-32,58,11','16,112,w-32,110,16').replace('42,72,w-58,36,11','42,78,w-58,54,16').replace('16,118,w-32,6','16,146,w-32,10').replace('16,134,w-32,16,10','16,174,w-32,24,16')
s=s[:start]+chunk+s[end:]
s=replace(s,'math.floor((cw+12)/188)','math.floor((cw+12)/260)')
s=replace(s,'local tierH=mobile and 100 or 226','local tierH=mobile and 218 or 310')
# Dashboard KPI text stays legible instead of shrinking to fit narrow columns.
s=replace(s,'local cols=narrow and 2 or 4;local kw=(cw-gap*(cols-1))/cols;local kh=mobile and 86 or 108','local cols=narrow and 1 or 4;local kw=(cw-gap*(cols-1))/cols;local kh=148')
start=s.index('  for i,k in ipairs(kpis)do',s.index(' local function dashboard'))
end=s.index('  yy+=math.ceil(#kpis/cols)',start)
chunk=s[start:end]
chunk=chunk.replace('mobile and 11 or 13','16').replace('mobile and 20 or 30','30').replace('mobile and 8 or 12','12').replace('mobile and 28 or 34','40').replace('mobile and 28 or 36','36')
chunk=chunk.replace('mobile and 58 or 76','84').replace('mobile and 22 or 18','52').replace('mobile and 9 or 10','14').replace('caption.TextWrapped=mobile;caption.TextTruncate=AtEnd','caption.TextWrapped=true')
s=s[:start]+chunk+s[end:]
s=replace(s,'local cardH=mobile and(pf.Started and 124 or 166)or 118','local cardH=mobile and 204 or 158')
s=replace(s,'summaryText(prog,"Title",pf.Next.Name,tx,32,tw-amountW,34,mobile and 19 or 28','summaryText(prog,"Title",pf.Next.Name,tx,38,mobile and tw or tw-amountW,34,mobile and 23 or 28')
s=replace(s,'cw-20-amountW,32,amountW,34,mobile and 16 or 24','mobile and tx or cw-20-amountW,mobile and 80 or 38,mobile and tw or amountW,34,mobile and 24 or 26')
s=replace(s,'amount.TextXAlignment=RIGHT','amount.TextXAlignment=mobile and Enum.TextXAlignment.Left or RIGHT')
s=replace(s,'progressBar(prog,"Progress",tx,74,tw','progressBar(prog,"Progress",tx,mobile and 124 or 88,tw')
s=replace(s,'whole(pf.Next.Remaining).." more net realized profit to go. Starting balances and open P&L don\'t count.",tx,92,tw,mobile and 28 or 18,mobile and 10 or 11','whole(pf.Next.Remaining).." more realized profit. Open P&L is not counted.",tx,mobile and 146 or 110,tw,46,15')
s=replace(s,'  if not mobile then text(sc,"LadderNote","Unlocked by net realized profit across your funded accounts · blown-account losses don\'t count",0,yy,cw,28,11,SB.Muted,M,RIGHT)end\n  yy+=36','  local note=text(sc,"LadderNote","Realized profit counts toward unlocks; blown-account losses are reset.",0,yy+32,cw,44,15,C.Text,M);note.TextWrapped=true\n  yy+=84')
# General dashboard copy areas get larger measured rows.
start=s.index(' local function copyCard(');end=s.index(' local KPI_LOOK=',start)
chunk=s[start:end].replace('mobile and 34 or 20,12','mobile and 48 or 24,15').replace('yy+=mobile and 40 or 28','yy+=mobile and 56 or 32').replace('iw,34,11','iw,62,15').replace('yy+=40','yy+=70')
chunk=chunk.replace('mobile and 70 or 34,11','mobile and 130 or 58,15').replace('yy+=mobile and 76 or 42','yy+=mobile and 138 or 66').replace('iw,18,12','iw,22,14').replace('yy+=22','yy+=28')
s=s[:start]+chunk+s[end:]
s=replace(s,'"Trade · earn realized profit · unlock more capital",0,34,cw,18,11','"Trade · earn profit · unlock more capital",0,34,cw,22,15')
s=replace(s,'cw,16,10,SB.Muted,M,CENTER','cw,20,14,SB.Muted,M,CENTER')
s=replace(s,'"Stats";s.Nav="Stats";s.StatsScope','"Stats";s.Nav="Stats";s.StatsScope')
write('TerminalUI.luau',s)

s=read('StatsView.luau')
s=s.replace('narrow and 12 or 14','15').replace('narrow and 12 or 13','15').replace('narrow and 11 or 12','15')
s=replace(s,'narrow and 10 or 12','14')
s=replace(s,'local yy=narrow and 60 or 72','local yy=narrow and 70 or 80')
s=replace(s,'cw,18,14','cw,24,14')
s=replace(s,'local bh=12+20+6+dh+(coverage and chH+6 or 0)+12','local eh=measure(eyebrow,14,bw)+6\n local bh=12+eh+6+dh+(coverage and chH+6 or 0)+12')
s=replace(s,'bw,20,15).TextXAlignment=LEFT','bw,eh,14).TextWrapped=true')
s=replace(s,'describe,16,38,bw','describe,16,18+eh,bw')
s=replace(s,'coverage,16,44+dh,bw','coverage,16,24+eh+dh,bw')
s=replace(s,'local kc=narrow and 2 or 4','local kc=narrow and 1 or 4')
s=replace(s,'local kh=mobile and 88 or 110','local kh=144')
start=s.index(' for i,k in ipairs(kpis)');end=s.index(' yy+=math.ceil(#kpis/kc)',start)
chunk=s[start:end]
chunk=chunk.replace('mobile and 8 or 12','12').replace('kw-24,18,mobile and 11 or 13','kw-24,24,16').replace('mobile and 28 or 34','42').replace('mobile and 30 or 38','38').replace('mobile and 22 or 32','32')
chunk=chunk.replace('mobile and 60 or 78','88').replace('mobile and 20 or 18','44').replace('mobile and 9 or 11','14').replace('cap.TextTruncate=AtEnd','cap.TextWrapped=true')
s=s[:start]+chunk+s[end:]
s=replace(s,'math.floor((cw+gap)/200)','math.floor((cw+gap)/250)')
s=replace(s,'local mh=mobile and 84 or 100','local mh=150')
start=s.index(' for i,m in ipairs(items)');end=s.index(' yy+=math.ceil(#items/mc)',start)
chunk=s[start:end]
chunk=chunk.replace('mobile and 8 or 10','10').replace('mw-24,16,mobile and 10 or 12,ctx.Muted','mw-24,36,14,C.Text').replace('l.TextTruncate=AtEnd','l.TextWrapped=true')
chunk=chunk.replace('mobile and 26 or 30','48').replace('mobile and 28 or 34','34').replace('mobile and 20 or 26','mobile and 23 or 28')
chunk=chunk.replace('mobile and 56 or 68','90').replace('mobile and 22 or 24','50').replace('mobile and 9 or 10','14').replace('cap.TextTruncate=AtEnd','cap.TextTruncate=Enum.TextTruncate.None')
s=s[:start]+chunk+s[end:]
s=replace(s,'local rh=narrow and 66 or 58','local rh=narrow and 90 or 70')
s=replace(s,'14,34,cw-28,22,10','14,38,cw-28,44,14').replace('dt.TextTruncate=AtEnd','dt.TextWrapped=true')
s=replace(s,'local ns=15','local ns=15')
s=replace(s,'mobile and 32 or 20,10','mobile and 48 or 24,14').replace('yy+=mobile and 40 or 28','yy+=mobile and 56 or 32')
write('StatsView.luau',s)

