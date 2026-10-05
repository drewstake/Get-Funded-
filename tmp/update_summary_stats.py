from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'src/TerminalUI.luau'
s=p.read_text(encoding='utf-8')
s=s.replace('local function objective()', '''local function usableAccounts()
  local pf=session.Portfolio
  if pf and pf.UsableCount~=nil then return pf.UsableCount end
  local count=0
  for _,row in ipairs(pf and pf.Accounts or {})do if row.State=="Active"and not row.Breached and not row.Depleted then count+=1 end end
  return pf and count or options.Preview and 1 or 0
 end
 local function objective()''')
s=s.replace('{"Balance",mobile and"BALANCE"or legacy and"PRACTICE BALANCE"or"FUNDED BALANCE",sum.Balance}', '{"Accounts","ACCOUNTS",usableAccounts()}')
s=s.replace('function()s.Overlay="Account";refresh()end,Color3.new(1,1,1))\n   summarySurface(tile,d[1],mobile)', 'function()if i==1 then navigate("Accounts")else s.Overlay="Account";refresh()end end,Color3.new(1,1,1))\n   summarySurface(tile,i==1 and"Balance"or d[1],mobile)')
s=s.replace('local value=i==3 and Market.Signed(d[3])or Market.Money(d[3])','local value=i==1 and(tostring(d[3])..(mobile and" usable"or" USABLE"))or i==3 and Market.Signed(d[3])or Market.Money(d[3])')
s=s.replace('summaryIcon(tile,d[1],side and 6', 'summaryIcon(tile,i==1 and"Balance"or d[1],side and 6')
s=s.replace('summaryText(p,d[1].."Value",value,bx+pad,23,cw-2*pad,23,w<370 and 12 or 14,accent,true)', '''summaryText(tile,d[1].."Value",value,pad,21,cw-2*pad,i==1 and 18 or 23,w<370 and 12 or 14,accent,true)
    if i==1 then summaryText(tile,"Selected",accountShort().." selected",pad,39,cw-2*pad,14,9,C.Text,true)end''')
s=s.replace('summaryText(p,d[1].."Value",value,bx+inset,valueY,cw-inset-pad,valueH,valueSize,accent)', 'summaryText(tile,d[1].."Value",value,inset,valueY,cw-inset-pad,valueH,i==1 and math.min(valueSize,34)or valueSize,accent)')
s=s.replace('accountShort()..(legacy and" PRACTICE"or" ACCOUNT")','accountShort()..(legacy and" PRACTICE"or" SELECTED")')
s=s.replace('local label=metrics:FindFirstChild(field.."Value")','local label=metrics:FindFirstChild(field.."Value",true)')
s=s.replace('"AccountSummary.BalanceCard"','"AccountSummary.AccountsCard"')
# Extra readout line and dual-color progress, retaining the illustrated trophy card.
s=s.replace('local tw=cw-2*pad\n  local track=', '''summaryText(tile,"Confirmed","",pad,cardH-49,cw-2*pad,15,side and 11 or 10,C.Text,true)
  tile.Amount.Position=UDim2.fromOffset(inset,cardH-78)
  tile.Amount.Size=UDim2.fromOffset(cw-inset-pad,24)
  tile.Amount.TextSize=side and 19 or 14
  local tw=cw-2*pad
  local track=''')
s=s.replace('-- A zero-value track stays visibly empty, as in the reference.', '''local mark=frame(track,"ConfirmedMarker",4,2,3,17,C.Cyan,7);round(mark,1)
  summaryText(track,"Percent","0% projected",0,0,tw,21,10,C.Text,true).ZIndex=8
  -- A zero-value track stays visibly empty, as in the reference.''')
start=s.index(' local function updateUnlockReadout()')
end=s.index(' local function tierCard(',start)
s=s[:start]+''' local function updateUnlockReadout()
  local pf=session.Portfolio local n=pf and pf.Next
  if not n then return end
  local confirmed,goal=n.Progress or 0,math.max(1,n.Goal or 1)
  local projected=n.Projected or confirmed
  local ratio=math.clamp(projected/goal,0,1)
  local amount=Market.Money(projected).." / "..whole(goal)
  local percent=string.format("%.1f%% projected",100*projected/goal)
  root:SetAttribute("UnlockProgress",confirmed);root:SetAttribute("UnlockProjected",projected);root:SetAttribute("UnlockGoal",goal)
  local summary=canvas:FindFirstChild("AccountSummary") local objectiveCard=summary and summary:FindFirstChild("ObjectiveCard")
  if objectiveCard and pf.ActiveKind~="Legacy"then
   objectiveCard.Amount.Text=amount
   objectiveCard.Title.Text=n.Name
   objectiveCard.Confirmed.Text="Confirmed "..Market.Money(confirmed).." · close to unlock"
   objectiveCard.Track.Percent.Text=percent
   local fill=objectiveCard.Track.Fill
   fill.Visible=projected>0;fill.Size=UDim2.fromOffset((objectiveCard.Track.Size.X.Offset-8)*ratio,fill.Size.Y.Offset)
   objectiveCard.Track.ConfirmedMarker.Position=UDim2.fromOffset(4+(objectiveCard.Track.Size.X.Offset-11)*math.clamp(confirmed/goal,0,1),2)
  end
  local board=canvas:FindFirstChild("Dashboard") local c=board and board:FindFirstChild("NextUnlock")
  if c and c:FindFirstChild("Amount")then
   c.Amount.Text=amount
   c.Title.Text=n.Name
   c.Remaining.Text=percent.." · Confirmed "..Market.Money(confirmed).." / "..whole(goal)..". Only qualifying closed profit unlocks accounts."
   local fill=c.Progress:FindFirstChild("Fill")
   if fill then fill.Visible=projected>0;fill.Size=UDim2.fromOffset(math.max(0,(c.Progress.Size.X.Offset-4)*ratio),fill.Size.Y.Offset)end
  end
 end
''' +s[end:]
s=s.replace('"Funded accounts",0,0','"Your accounts",0,0')
s=s.replace('"Account ladder",0,yy','"Owned accounts & locked tiers",0,yy')
s=s.replace('active and(current and"TRADING"or"ACTIVE")','active and(current and"SELECTED"or"OWNED")')
# Call after all screens are constructed, including the first render and account switching.
s=s.replace('local controller={Root=root,State=s,Chart=chartView}', 'local controller={Root=root,State=s,Chart=chartView}')
s=s.replace('  canvas:ClearAllChildren();canvas.Size=UDim2.fromOffset(w,h)','  canvas:ClearAllChildren();canvas.Size=UDim2.fromOffset(w,h)')
# render tail marker found in source
marker='  root:SetAttribute("Balance",sum.Balance)'
idx=s.index(marker,s.index('render=function') if 'render=function' in s else 0)
s=s[:idx]+'  updateUnlockReadout()\n'+s[idx:]
p.write_text(s,encoding='utf-8')
