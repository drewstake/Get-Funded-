from pathlib import Path

root = Path(__file__).resolve().parents[1]
def edit(name, fn):
    p = root / 'src' / name
    p.write_text(fn(p.read_text(encoding='utf-8')), encoding='utf-8')
def replace(s, old, new):
    assert old in s, old[:150]
    return s.replace(old, new)

def funded(s):
    s=replace(s, 'function Funded:Join(uid)', '''-- Re-earning uses new net realized profit, never migration credits or loss write-offs.
-- Snapshot every existing attempt at forfeiture; exclude accounts already blown at that time.
-- The full baseline and requirement are checkpointed with the tier, including during liquidation.
function Funded:ReearnProgress(p,entry)
 local r=entry.Reearn local total=0 local seen={}
 for _,id in ipairs(p.Ledger) do
  local a=self.Engine.Accounts[id]
  if a and not seen[id] and not r.Excluded[id] then
   seen[id]=true total+=a.Realized-(r.Baseline[id] or 0)
  end
 end
 return total
end
function Funded:Forfeit(p)
 local changed=false local previous=0
 for _,key in ipairs(self.Order) do
  local entry=p.Tiers[key] local tier=self.Tiers[key]
  local a=entry and self.Engine.Accounts[entry.Account]
  if key~=self.Config.StarterTier and entry and entry.State=="Active" and a and a.Locked then
   local baseline,excluded={},{}
   for _,id in ipairs(p.Ledger) do local old=self.Engine.Accounts[id]
    if old then baseline[id]=old.Realized;if ended(old) then excluded[id]=true end end
   end
   entry.Reearn={Goal=tier.Unlock-previous,Baseline=baseline,Excluded=excluded,At=self.Engine.Time,Role=self:Role(p,key)}
   entry.State="Locked" entry.Announced=true
   local copy=p.Copy
   if copy.Leader==key then copy.Enabled=false;copy.Leader=nil end
   for i=#copy.Followers,1,-1 do if copy.Followers[i]==key then table.remove(copy.Followers,i) end end
   if #copy.Followers==0 then copy.Enabled=false end
   if p.Active==key then p.Active=nil end
   changed=true
  end
  if entry and entry.Reearn and a and a.Locked and not next(a.Positions) and not next(a.OpenOrders) then
   if not a.Retired then a.Retired=true;changed=true end
  end
  previous=tier.Unlock
 end
 if not p.Active then
  -- Prefer a healthy funded account; the starter remains reachable for its free reset.
  for _,key in ipairs(self.Order) do local entry=p.Tiers[key];local a=entry and self.Engine.Accounts[entry.Account]
   if entry and entry.State=="Active" and a and not a.Locked then p.Active=key;break end
  end
  if not p.Active and p.Tiers[self.Config.StarterTier] then p.Active=self.Config.StarterTier end
  if p.Active then changed=true end
 end
 if changed then self:_touch(p) end
 return changed
end

function Funded:Join(uid)''')
    s=replace(s, 'self:WriteOff(p)\n -- One player', 'self:WriteOff(p)\n self:Forfeit(p)\n -- One player')
    s=replace(s, 'local a=entry and entry.State=="Active" and self.Engine.Accounts[entry.Account]', 'local a=entry and (entry.State=="Active" or entry.Reearn) and self.Engine.Accounts[entry.Account]')
    s=replace(s, 'CanRestart=self.Config.AllowRestart==true and not closing', 'CanRestart=a.Tier==self.Config.StarterTier and self.Config.AllowRestart==true and not closing')
    s=replace(s, 'if entry.State=="Active" then return true,t.Name.." is already active." end\n entry.Account=self:_open(uid,p,tierId,1)\n entry.State="Active" entry.Attempt=1', '''if entry.State=="Active" then return true,t.Name.." is already active." end
 if entry.State~="Unlocked" then return false,"Re-earn "..t.Name.." with "..money(entry.Reearn.Goal).." new net realized profit. No reset is available." end
 local old=self.Engine.Accounts[entry.Account]
 if old and (next(old.Positions) or next(old.OpenOrders)) then return false,"Wait for liquidation to finish before activating this tier." end
 local attempt=(entry.Attempt or 0)+1
 entry.Account=self:_open(uid,p,tierId,attempt)
 entry.Reearn=nil entry.DepletionNotice=nil
 entry.State="Active" entry.Attempt=attempt''')
    s=replace(s, 'function Funded:Restart(uid,tierId)\n', '''function Funded:Restart(uid,tierId)
 if tierId~=self.Config.StarterTier then return false,"Only the $5K account has a free reset. Re-earn higher tiers through their progression goal." end
''')
    s=replace(s, '-- Unlocks are one-way, recorded once, and announced once (Announced flag is saved).', '-- Initial unlocks and re-earned tiers are announced once (Announced flag is saved).')
    s=replace(s, 'local earned,changed=self:Earned(p),false', 'local earned,changed=self:Earned(p),self:Forfeit(p)')
    s=replace(s, '  if not p.Tiers[id] and progress+EPS>=self.Tiers[id].Unlock then', '''  local entry=p.Tiers[id]
  if entry and entry.State=="Locked" and entry.Reearn and self:ReearnProgress(p,entry)+EPS>=entry.Reearn.Goal and self:Final(self.Engine.Accounts[entry.Account]) then
   entry.State="Unlocked" entry.UnlockedAt=self.Engine.Time entry.Announced=false changed=true
  elseif not entry and progress+EPS>=self.Tiers[id].Unlock then''')
    s=replace(s, 'Role=self:Role(p,id),Leader=', 'Role=entry.Reearn and entry.Reearn.Role or self:Role(p,id),Reearn=entry.Reearn~=nil,Leader=')
    s=replace(s, '  if entry and entry.State=="Active" then\n   local a=e.Accounts[entry.Account] local s=e:Summary(a)', '''  if entry and entry.Reearn then
   row.Reearn=true row.Goal=entry.Reearn.Goal row.Progress=self:ReearnProgress(p,entry)
  end
  if entry and (entry.State=="Active" or entry.Reearn) then
   local a=e.Accounts[entry.Account] local s=e:Summary(a)''')
    s=replace(s, 'if d then row.Depleted=true', 'if d and entry.State~="Unlocked" then row.Depleted=true')
    s=replace(s, '   view.Capital+=t.Size view.Open+=s.Unrealized view.ActiveCount+=1', '   if entry.State=="Active" then view.Capital+=t.Size view.Open+=s.Unrealized view.ActiveCount+=1 end')
    s=replace(s, 'if not entry and not view.Next and t.Unlock>0 then view.Next={Key=id,Name=t.Name,Short=t.Short,Unlock=t.Unlock,Goal=t.Unlock-previous,Progress=progress-previous,Remaining=math.max(0,t.Unlock-progress)} end', 'if (not entry or entry.State=="Locked") and not view.Next and t.Unlock>0 then view.Next={Key=id,Name=t.Name,Short=t.Short,Unlock=t.Unlock,Goal=row.Goal,Progress=row.Progress,Reearn=row.Reearn,Remaining=math.max(0,row.Goal-row.Progress)} end')
    s=replace(s, 'row.Orders=count(a.OpenOrders) row.Breached=a.Locked', 'row.Orders=count(a.OpenOrders) row.Breached=a.Locked and entry.State~="Unlocked"')
    s=replace(s, 'add(f,"Skipped","Account blown (equity reached $0). Restart it to resume copying.")', 'add(f,"Skipped",f.Key==self.Config.StarterTier and "Account blown (equity reached $0). Reset the $5K to resume copying." or "Account blown. Re-earn this tier through its progression goal.")')
    return s
edit('FundedAccounts.luau', funded)
def server(s):
    s=replace(s, 'local function emit(player,state)\n', '''local function emit(player,state)
 if funded then
  local owner=funded:Owner(state.Uid)
  if state.Owner~=owner then state.Owner=owner;state.Full=true end
 end
''')
    s=replace(s, 'local req=item.Request local uid=state.Uid', '''local req=item.Request local uid=state.Uid
 funded:Evaluate(uid)
 local owner=funded:Owner(uid)
 if state.Owner~=owner then
  state.Owner=owner;state.Full=true
  if req.Action=="Place" or req.Action=="Close" or req.Action=="Cancel" or req.Action=="AmendOrder" or req.Action=="AmendProtection" then
   reply(state,req.Id,false,"Your trading account changed after depletion. Review the selected account and retry.") return
  end
 end''')
    return s
edit('MarketServer.server.luau',server)
edit('ProgressionConfig.luau',lambda s: s.replace('-- A depleted account (equity at or below zero) can restart with fresh capital.', '-- Only the starter $5K account can restart with fresh capital. Higher tiers must be re-earned.'))

def ui(s):
    start=s.index('    local key=item:GetAttribute("ProtectionField")')
    end=s.index('\n   end\n  end',start)
    s=s[:start]+'''    if item.Name=="Risk"then
     item.Text=s.StopOn and("Estimated total loss  "..effective("Stop"))or"No stop loss configured"
    end'''+s[end:]
    s=replace(s,'setter,formatter,enabled)\n  local height=44;local bw=math.min(44,math.floor((w-32)/2))','setter,formatter,enabled,direct)\n  local height=direct and 52 or 44;local bw=direct and 0 or math.min(44,math.floor((w-32)/2))')
    s=replace(s,'  for _,d in ipairs({{"Decrease","−",-1,0},{"Increase","+",1,w-bw}})do','  for _,d in ipairs(direct and {} or {{"Decrease","−",-1,0},{"Increase","+",1,w-bw}})do')
    start=s.index('  local stacked=w<290 local gap=10')
    end=s.index('\n local function orderOptions',start)
    s=s[:start]+'''  local stacked=w<400 local gap=10
  local cw=stacked and w or(w-gap)/2 local ch=98
  for i,d in ipairs({{"Stop","Stop Loss ($)",C.Red},{"Target","Take Profit ($)",C.Green}})do
   local key=d[1];local enabled=s[key.."On"]
   local cx=stacked and x or x+(i-1)*(cw+gap) local cy=stacked and y+(i-1)*(ch+gap)or y
   local card=frame(p,key.."Card",cx,cy,cw,ch,C.Bg,p.ZIndex);round(card,12);stroke(card,d[3]).Thickness=3
   local header=button(card,"Settings","",6,4,cw-64,30,openProtection,false,C.Text,12,card.ZIndex+1)
   protectionIcon(header,key,3,5,20)
   local label=sidebarText(header,"Label",d[2],29,0,cw-95,30,16);label.TextScaled=true
   make("UITextSizeConstraint","TextSize",label,{MinTextSize=12,MaxTextSize=16})
   local toggle=button(card,"Toggle",enabled and"ON"or"OFF",cw-54,7,44,26,function()s[key.."On"]=not s[key.."On"];refresh()end,C.Bg,enabled and d[3]or C.Muted,12,card.ZIndex+1)
   toggle.Font=B;toggle.Border.Color=enabled and d[3]or C.Border;toggle.Corners.CornerRadius=UDim.new(0,11)
   numericStepper(card,"Distance",8,38,cw-16,s[key.."Dollars"],.01,.01,protectionMaximum,function(n)s[key.."Dollars"]=n;updateProtectionReadout()end,Market.Money,enabled,true)
  end
  return stacked and ch*2+gap or ch
 end
'''+s[end:]
    s=replace(s,'  sidebarText(p,"ProtectionHint","Estimated totals for "..s.Qty.." contracts · fills may vary",pad,yy,iw,20,12,C.Muted).TextXAlignment=CENTER;yy+=24\n','')
    s=replace(s,'local ph=math.min(574,h-28)','local ph=math.min(492,h-28)')
    s=replace(s,'"Estimated total loss / profit for "..s.Qty.." contracts"','"Total dollars for your selected quantity"')
    s=replace(s,'CanvasSize=UDim2.fromOffset(0,344)','CanvasSize=UDim2.fromOffset(0,256)')
    s=replace(s,'{{"Stop","Stop Loss","Total loss amount ($)",C.Red},{"Target","Take Profit","Total profit amount ($)",C.Green}}','{{"Stop","Stop Loss ($)","",C.Red},{"Target","Take Profit ($)","",C.Green}}')
    s=replace(s,'(i-1)*172+4,cw,158','(i-1)*128+4,cw,114')
    s=replace(s,'narrow and 18 or 24)\n   local toggle','narrow and 14 or 22)\n   local toggle')
    s=replace(s,'   text(card,"DistanceLabel",d[3],16,49,cw-32,22,13,C.Text,F,CENTER)\n','')
    s=replace(s,'numericStepper(card,"Distance",16,80','numericStepper(card,"Distance",16,52')
    s=replace(s,'end,Market.Money,on)','end,Market.Money,on,true)')
    start=s.index('   local unit=text(card,"Unit",on and("Effective')
    end=s.index('\n  end',start)
    s=s[:start]+s[end:]
    s=replace(s,'{"Undo","Undo"},{"Redo","Redo"},','')
    s=replace(s,'  if not row or not row.Depleted then fail("Only a blown funded account can restart.");return end','  if not row or not row.Depleted or row.Key~=Ladder.StarterTier then fail("Only the $5K has a free reset. Re-earn higher tiers through their progression goal.");return end')
    s=replace(s,'  local label,disabled=restartLabel(row,short)\n  local b=', '  if row.Reearn then return nil end\n  local label,disabled=restartLabel(row,short)\n  local b=')
    s=replace(s,'local row=tierRow(s.BlownTier);local role=row.Role;', 'local row=tierRow(s.BlownTier);local reearn=row.Reearn;local role=row.Role;')
    s=replace(s,'   local introH=TextService:GetTextSize(intro', '''   if reearn then intro="Your "..row.Name.." account was blown and this tier is locked again. Earn "..whole(row.Goal).." new net realized profit on your remaining accounts to unlock it again. Prior profit does not count." end
   local introH=TextService:GetTextSize(intro''')
    s=replace(s,'   local bulletH,bulletsH={},0', '''   if reearn then bullets={"No reset is available. Only the $5K account has a free reset.","This attempt's result and trade history stay in Stats. Your other accounts keep their positions.","The blown account is removed from copy trading. Review your copy settings after re-earning it."} end
   local bulletH,bulletsH={},0''')
    s=replace(s,'closing and"Closing remaining positions…"or"All positions closed · ready to restart"','closing and"Closing remaining positions…"or reearn and"Tier locked · re-earn to unlock"or"All positions closed · ready to restart"')
    s=replace(s,'or"Liquidation finished. Restart is available now."','or(reearn and("New profit goal: "..whole(row.Goal))or"Liquidation finished. Restart is available now.")')
    s=replace(s,'" left · restart unlocks when flat"','(reearn and" left · tier locked"or" left · restart unlocks when flat")')
    s=replace(s,'optionLabel(p,"RestartHeading","Restarting this account:"','optionLabel(p,"RestartHeading",reearn and"Earning this tier again:"or"Restarting this account:"')
    s=replace(s,'    restartButton(p,row,pad+lw+12,y,iw-lw-12,buttonsH,narrow and 16 or 19,45,false,true)','    if reearn then popupButton(p,"ViewAccounts","View accounts",pad+lw+12,y,iw-lw-12,buttonsH,function()s.Overlay=nil;navigate("Accounts")end,"Purple",narrow and 16 or 19)\n    else restartButton(p,row,pad+lw+12,y,iw-lw-12,buttonsH,narrow and 16 or 19,45,false,true) end')
    s=replace(s,'"Nothing restarts automatically. Only Restart Account opens a new attempt."','reearn and"Only new net realized profit counts toward re-earning this tier."or"The $5K free reset opens a new attempt."')
    s=replace(s,'local status=row.Breached and(', 'local status=row.Reearn and row.State=="Locked" and"RE-EARN"or row.Breached and(')
    s=replace(s,'"Stage goal: "..whole(row.Goal).." net profit"','(row.Reearn and"Re-earn: "or"Stage goal: ")..whole(row.Goal).." new net profit"')
    s=replace(s,'"Stage goal: "..whole(row.Goal).." net realized profit"','(row.Reearn and"Re-earn: "or"Stage goal: ")..whole(row.Goal).." net realized profit"')
    s=replace(s,'"Realized profit counts toward unlocks; blown-account losses are reset."','"Only $5K has a free reset. Blown $10K+ tiers must be re-earned with new profit; prior profit does not count."')
    s=replace(s,'local note=text(sc,"LadderNote",','local note=text(sc,"LadderNote",')
    s=replace(s,'0,yy+32,cw,44,15,C.Text,M);note.TextWrapped=true\n  yy+=84','0,yy+32,cw,64,15,C.Text,M);note.TextWrapped=true\n  yy+=104')
    return s
edit('TerminalUI.luau',ui)
