-- Server-authoritative funded-account ladder, onboarding flags and optional copy trading.
-- Profiles live in engine.Profiles and are saved inside the same exchange checkpoint as balances,
-- so an unlock can never restore without the profit that earned it (and vice versa).
-- Every order, copied or not, is executed by MarketEngine with that account's own limits.
local Funded={} Funded.__index=Funded
local EPS=1e-6
local TradeStats=require(script.Parent.TradeStats)

local function money(n)
 local raw=string.format("%.2f",math.abs(n or 0)) local whole,decimal=raw:match("^(%d+)%.(%d+)$")
 whole=whole:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
 return ((n or 0)<0 and "-" or "").."$"..whole..(decimal=="00" and "" or "."..decimal)
end
Funded.Money=money
local function count(map) local n=0 for _ in pairs(map or {}) do n+=1 end return n end
local function sortedKeys(t) local keys={} for k in pairs(t) do table.insert(keys,k) end table.sort(keys) return keys end

function Funded.Validate(config)
 assert(type(config.Tiers)=="table" and #config.Tiers>0,"Progression needs at least one tier")
 local seen,prevSize,prevUnlock={},0,-1
 for i,t in ipairs(config.Tiers) do
  assert(type(t.Id)=="string" and #t.Id>0 and #t.Id<=8 and not t.Id:find("[,:]") and not t.Id:match("^L%d"),"Tier ids must be 1-8 characters without ',' or ':'")
  assert(not seen[t.Id],"Duplicate tier id "..t.Id) seen[t.Id]=true
  assert(t.Size>prevSize,"Tier sizes must ascend") assert(t.Unlock>prevUnlock,"Unlock requirements must ascend")
  assert((i==1)==(t.Unlock==0),"Only the first (starter) tier unlocks at 0")
  assert(t.LossLimit==t.Size and t.MaxContracts>=1,"Tier risk limits must be positive")
  prevSize,prevUnlock=t.Size,t.Unlock
 end
 assert(config.Tiers[1].Id==config.StarterTier,"StarterTier must be the first tier")
end

function Funded.new(engine,config,market)
 Funded.Validate(config)
 engine.Profiles=engine.Profiles or {}
 local self=setmetatable({Engine=engine,Config=config,Market=market or engine.Config,Tiers={},Order={}},Funded)
 for i,t in ipairs(config.Tiers) do self.Tiers[t.Id]=t self.Order[i]=t.Id end
 for uid,p in pairs(engine.Profiles) do self:Migrate(p);self:Join(uid) end
 -- Lifetime stats: idempotent migration for accounts saved before stats existed, drift repair for others.
 local now=os.time()
 for _,id in ipairs(engine.AccountOrder) do local a=engine.Accounts[id] if a.Player then TradeStats.Reconcile(engine,a,now) end end
 return self
end
function Funded.Key(userId) return tostring(userId) end
function Funded:Group(uid) return "player:"..uid end
function Funded:LegacyId(uid,base) return "player:"..uid..":"..base end
function Funded:LegacyName(base) return "$"..(base%1000==0 and tostring(base//1000).."K" or tostring(base)).." Practice" end
function Funded:Profile(uid) return self.Engine.Profiles[uid] end
function Funded:_touch(p) p.Revision=(p.Revision or 0)+1 end
function Funded:_new(uid,migrated)
 local p={V=self.Config.Version,ProgressCredit=0,Tiers={},Ledger={},Legacy={},WriteOffs={},Banked={},ResetV=1,Tutorial="None",CopyIntro=false,Revision=1,Created=self.Engine.Time,Migrated=migrated,
  Copy={Enabled=false,Followers={},Sizing=self.Config.CopyTrading.DefaultSizing=="Proportional" and "Proportional" or "Same"}}
 self.Engine.Profiles[uid]=p
 return p
end

-- Called whenever a player joins or the exchange restores. A player with pre-ladder practice accounts
-- gets a migrated profile that keeps those accounts exactly as they were. New players get nothing
-- until they press Start, so no starter account is ever created implicitly.
-- A one-time credit bridges completed old stages without fabricating realized profit.
-- Surplus profit and losses within the current stage remain intact; unlocks never go backwards.
function Funded:Migrate(p)
 if (p.V or 1)>=self.Config.Version then return end
 local credit=0
 for _,id in ipairs(self.Order) do
  if p.Tiers[id] then credit=math.max(credit,self.Tiers[id].Unlock-(self.Config.LegacyUnlocks[id] or 0)) end
 end
 p.ProgressCredit=credit p.V=self.Config.Version self:_touch(p)
end

-- Unlock progress after a blown account ---------------------------------------------------------
-- An attempt that ends blown (equity reached $0) or is replaced by a restart is written off for unlock
-- progress once it is final (nothing left to close). Its losses stop counting toward unlocks, so the
-- next attempt starts from the beginning of the player's current stage instead of from a hole. The
-- attempt's realized result, trade history, Stats and leaderboard profit are untouched (Earned below
-- stays lifetime). The amount it still counts is frozen in p.WriteOffs[accountId], which is saved with
-- the profile in the exchange checkpoint, so the reset survives leaving, rejoining and restores.
local function ended(a) return a.Retired==true or a.Depleted==true or a.Locked==true end
function Funded:Final(a) return a.Retired==true or (ended(a) and not next(a.Positions) and not next(a.OpenOrders)) end
-- What one ledger attempt contributes to unlock progress.
function Funded:Counted(p,id,a)
 local w=p.WriteOffs and p.WriteOffs[id]
 if w then return w.Counted end
 -- Blown but still liquidating: losses already don't count; the amount is frozen when it is flat.
 if ended(a) then return math.max(0,a.Realized) end
 return a.Realized
end
function Funded:StageFloor(p)
 local floor=0 for _,id in ipairs(self.Order) do if p.Tiers[id] then floor=math.max(floor,self.Tiers[id].Unlock) end end
 return floor
end
-- Profit an attempt had counted toward unlocks when each unlock was reached (p.Banked, saved).
function Funded:Bank(p)
 p.Banked=p.Banked or {}
 for _,id in ipairs(p.Ledger) do
  local a=self.Engine.Accounts[id]
  if a and a.Tier and self.Tiers[a.Tier] and not (p.WriteOffs and p.WriteOffs[id]) then
   p.Banked[id]=math.max(p.Banked[id] or 0,self:Counted(p,id,a))
  end
 end
end
-- Freezes the contribution of every final blown/restarted attempt: none of its losses count. If profit
-- it had banked toward an unlock the player already reached is now gone, it keeps just enough of that
-- banked profit to return the player to the start of the current stage (never more, so blowing an
-- account can never raise progress or forgive another account's losses). Idempotent.
-- Profiles saved before this rule (no ResetV) have no banked record: finished attempts' losses are
-- written off, and live attempts' current profit is banked once so a later blow-up is handled the same way.
function Funded:WriteOff(p)
 local e=self.Engine p.WriteOffs=p.WriteOffs or {} p.Banked=p.Banked or {}
 local changed=false
 if p.ResetV==nil then
  for _,id in ipairs(p.Ledger) do
   local a=e.Accounts[id]
   if a and a.Tier and self.Tiers[a.Tier] and p.WriteOffs[id]==nil and self:Final(a) then
    p.WriteOffs[id]={Counted=math.max(0,a.Realized),Realized=a.Realized,Tier=a.Tier,At=e.Time} changed=true
   end
  end
  if self:StageFloor(p)>0 then self:Bank(p) end
  p.ResetV=1
 end
 local floor=self:StageFloor(p)
 for _,id in ipairs(p.Ledger) do
  local a=e.Accounts[id]
  if a and a.Tier and self.Tiers[a.Tier] and p.WriteOffs[id]==nil and self:Final(a) then
   local base=math.max(0,a.Realized)
   local others=self:Progress(p)-base
   local counted=math.max(base,math.min(p.Banked[id] or 0,floor-others))
   p.WriteOffs[id]={Counted=counted,Realized=a.Realized,Tier=a.Tier,At=e.Time}
   changed=true
  end
 end
 if changed then self:_touch(p) end
 return changed
end
-- Losses written off from unlock progress (for display): realized minus what those attempts still count.
function Funded:WrittenOff(p)
 local total=0 for id,w in pairs(p.WriteOffs or {}) do if self.Engine.Accounts[id] then total+=w.Counted-w.Realized end end
 return total
end
function Funded:Progress(p)
 local total=p.ProgressCredit or 0 local seen={}
 for _,id in ipairs(p.Ledger) do
  local a=self.Engine.Accounts[id]
  if a and a.Tier and self.Tiers[a.Tier] and not seen[id] then seen[id]=true total+=self:Counted(p,id,a) end
 end
 return total
end

function Funded:Join(uid)
 local e=self.Engine local p=e.Profiles[uid]
 if not p then
  local found={}
  for _,base in ipairs(self.Config.LegacyBases or {}) do if e.Accounts[self:LegacyId(uid,base)] then table.insert(found,base) end end
  if #found==0 then return nil end
  p=self:_new(uid,"practice-v1")
  for _,base in ipairs(found) do table.insert(p.Legacy,base) end
  p.Active="L"..found[1]
 end
 self:Migrate(p)
 -- Risk settings are current policy, never saved progress. Refresh existing funded accounts too.
 for key,entry in pairs(p.Tiers) do
  local a=e.Accounts[entry.Account] local tier=self.Tiers[key]
  if a and tier then a.Limit=math.min(tier.MaxContracts,self.Market.MaxPlayerInventory);a.Risk=self.Config.MarginUse end
 end
 -- Blown attempts that finished while the player was away (or before this rule) are written off now.
 self:WriteOff(p)
 -- One player's accounts never trade against each other (cross-account self-trade prevention).
 for _,base in ipairs(p.Legacy) do local a=e.Accounts[self:LegacyId(uid,base)] if a then a.Group=self:Group(uid) end end
 return p
end

function Funded:Resolve(uid,key)
 local p=self.Engine.Profiles[uid]
 if not p or type(key)~="string" then return nil end
 local legacy=tonumber(key:match("^L(%d+)$") or "")
 if legacy then
  for _,base in ipairs(p.Legacy) do
   if base==legacy and self.Engine.Accounts[self:LegacyId(uid,base)] then return self:LegacyId(uid,base),"Legacy",base end
  end
  return nil
 end
 local entry=p.Tiers[key]
 if entry and entry.State=="Active" and self.Engine.Accounts[entry.Account] then return entry.Account,"Funded",self.Tiers[key] end
 return nil
end
function Funded:Owner(uid)
 local p=self.Engine.Profiles[uid]
 return p and p.Active and (self:Resolve(uid,p.Active)) or nil
end
function Funded:IsLegacyOwner(uid,owner)
 local _,kind=self:Resolve(uid,(self.Engine.Profiles[uid] or {}).Active)
 return kind=="Legacy" and owner==self:Owner(uid)
end
function Funded:_open(uid,p,tierId,attempt)
 local t=self.Tiers[tierId]
 local id="player:"..uid..":"..tierId..":"..attempt
 assert(not self.Engine.Accounts[id],"Funded account already exists")
 local a=self.Engine:AddAccount(id,t.Size,math.min(t.MaxContracts,self.Market.MaxPlayerInventory),self.Config.MarginUse,true)
 a.LossLimit=t.LossLimit a.Group=self:Group(uid) a.Tier=tierId
 table.insert(p.Ledger,id)
 return id
end
function Funded:ActiveTiers(p)
 local list={} for _,id in ipairs(self.Order) do local e=p.Tiers[id] if e and e.State=="Active" then table.insert(list,id) end end
 return list
end
-- Authoritative depletion status for an active tier. The engine latches Locked when equity reaches $0
-- or below; negative open P&L with positive equity never counts. Restart and the UI share this rule.
function Funded:Depletion(entry)
 local a=entry and entry.State=="Active" and self.Engine.Accounts[entry.Account]
 if not a or not a.Locked then return nil end
 local positions,orders=count(a.Positions),count(a.OpenOrders)
 local closing=positions>0 or orders>0
 local contracts=0 for _,p in pairs(a.Positions) do contracts+=p.Quantity end
 return {Closing=closing,Positions=positions,Orders=orders,Contracts=contracts,CanRestart=self.Config.AllowRestart==true and not closing,
  Event=entry.Account:match("[^:]+:[^:]+$") or entry.Account}
end
function Funded:Role(p,id)
 if not p.Copy.Enabled then return nil end
 if p.Copy.Leader==id then return "Lead" end
 if table.find(p.Copy.Followers,id) then return "Follow" end
 return nil
end

function Funded:Start(uid)
 local p=self.Engine.Profiles[uid] or self:Join(uid) or self:_new(uid)
 local starter=self.Config.StarterTier local t=self.Tiers[starter]
 if p.Tiers[starter] then
  -- Idempotent: repeated or duplicated Start requests never create a second starter account.
  p.Active=starter self:_touch(p)
  return true,"Your "..t.Name.." account is ready.",false
 end
 local id=self:_open(uid,p,starter,1)
 p.Tiers[starter]={State="Active",Account=id,Attempt=1,UnlockedAt=self.Engine.Time,ActivatedAt=self.Engine.Time,Announced=true}
 p.Active=starter p.Tutorial="Pending" self:_touch(p)
 return true,"Your "..money(t.Size).." funded account is live. Trading and funds are simulated.",true
end

function Funded:Activate(uid,tierId)
 local p=self.Engine.Profiles[uid]
 if not p or not p.Tiers[self.Config.StarterTier] then return false,"Start your funded account first." end
 local t=self.Tiers[tierId] if not t then return false,"Unknown account tier." end
 local entry=p.Tiers[tierId]
 if not entry then return false,t.Name.." unlocks at "..money(t.Unlock).." net realized profit." end
 if entry.State=="Active" then return true,t.Name.." is already active." end
 entry.Account=self:_open(uid,p,tierId,1)
 entry.State="Active" entry.Attempt=1 entry.ActivatedAt=self.Engine.Time entry.Announced=true
 self:_touch(p)
 return true,t.Name.." activated. Its "..money(t.Size).." is simulated funded capital, separate from your earned profits."
end

function Funded:Select(uid,key)
 local id,kind,info=self:Resolve(uid,key)
 if not id then return false,"That account isn't available." end
 local p=self.Engine.Profiles[uid] p.Active=key self:_touch(p)
 return true,"Now trading "..(kind=="Legacy" and self:LegacyName(info) or info.Name).."."
end

function Funded:Restart(uid,tierId)
 if not self.Config.AllowRestart then return false,"Account restarts are disabled." end
 local p=self.Engine.Profiles[uid] local entry=p and p.Tiers[tierId] local t=self.Tiers[tierId]
 if not entry or entry.State~="Active" then return false,"Only an active funded account can restart." end
 local old=self.Engine.Accounts[entry.Account]
 local depletion=self:Depletion(entry)
 if not depletion then
  -- A duplicated request processed in the same exchange step is still rejected, with a clear reason.
  if entry.RestartedAt==self.Engine.Time then return false,t.Name.." was already restarted." end
  return false,t.Name.." is in good standing. Only a depleted account can restart."
 end
 if depletion.Closing then return false,"Closing remaining positions on "..t.Name..". Restart unlocks once liquidation finishes." end
 -- The blown attempt is flat, so its unlock-progress write-off is final before the new attempt opens.
 self:WriteOff(p)
 entry.Attempt+=1 entry.Account=self:_open(uid,p,tierId,entry.Attempt) entry.RestartedAt=self.Engine.Time
 -- Retired attempts stay in the ledger (history, Stats, leaderboard); their losses don't count toward unlocks.
 old.Retired=true -- Preserve the complete retained trade history of every attempt.
 self:_touch(p)
 return true,t.Name.." restarted with "..money(t.Size).." of fresh simulated capital. The blown attempt stays in your history; its losses don't count against unlock progress."
end

function Funded:SetCopy(uid,req)
 local p=self.Engine.Profiles[uid]
 if not p or not p.Tiers[self.Config.StarterTier] then return false,"Start your funded account first." end
 local enabled=req.Enabled==1 or req.Enabled==true
 if not enabled then
  local was=p.Copy.Enabled p.Copy.Enabled=false self:_touch(p)
  return true,was and "Copy trading off. Every account keeps its positions and orders and now trades independently." or "Copy trading is off."
 end
 if #self:ActiveTiers(p)<self.Config.CopyTrading.MinAccounts then return false,"Activate a second funded account to use copy trading." end
 local leader=req.Leader
 if type(leader)~="string" or not self:Resolve(uid,leader) or not self.Tiers[leader] then return false,"Choose an active funded account to lead." end
 local chosen={}
 for key in string.gmatch(type(req.Followers)=="string" and req.Followers or "","[^,]+") do
  if not self.Tiers[key] or not self:Resolve(uid,key) then return false,"Followers must be your active funded accounts." end
  if key~=leader then chosen[key]=true end
 end
 local followers={} for _,id in ipairs(self.Order) do if chosen[id] then table.insert(followers,id) end end
 if #followers==0 then return false,"Choose at least one account to follow the lead." end
 local sizing=req.Sizing=="Proportional" and "Proportional" or req.Sizing=="Same" and "Same" or p.Copy.Sizing
 p.Copy={Enabled=true,Leader=leader,Followers=followers,Sizing=sizing} p.CopyIntro=true self:_touch(p)
 return true,string.format("Copy trading on. New %s orders copy to %d account%s. Existing positions are unchanged.",
  self.Tiers[leader].Short,#followers,#followers==1 and "" or "s")
end

function Funded:Flag(uid,stage)
 local p=self.Engine.Profiles[uid] if not p then return false,"Start your funded account first." end
 if stage=="TutorialDone" or stage=="TutorialSkipped" then
  if p.Tutorial=="Pending" then p.Tutorial=stage=="TutorialDone" and "Done" or "Skipped" end
 elseif stage=="CopyIntro" then p.CopyIntro=true
 else return false,"Unknown onboarding step." end
 self:_touch(p) return true,"Saved."
end

-- Lifetime net realized profit across every funded account the player has ever traded (including
-- restarted attempts). Historical record for Stats and leaderboards; unlocks use Progress above.
-- Account.Realized excludes the starting balance and open P&L by construction.
function Funded:Earned(p)
 local total=0 local seen={}
 for _,id in ipairs(p.Ledger) do
  local a=self.Engine.Accounts[id]
  -- A retained attempt counts once, even if an old saved ledger repeats its id.
  if a and a.Tier and self.Tiers[a.Tier] and not seen[id] then seen[id]=true;total+=a.Realized end
 end
 return total
end

-- Unlocks are one-way, recorded once, and announced once (Announced flag is saved).
function Funded:Evaluate(uid)
 local p=self.Engine.Profiles[uid]
 if not p or not p.Tiers[self.Config.StarterTier] then return false end
 self:Migrate(p)
 self:WriteOff(p)
 local earned,changed=self:Earned(p),false
 local progress=self:Progress(p)
 for _,id in ipairs(self.Order) do
  if not p.Tiers[id] and progress+EPS>=self.Tiers[id].Unlock then
   p.Tiers[id]={State="Unlocked",UnlockedAt=self.Engine.Time,Earned=earned,Announced=false} changed=true
  end
 end
 -- Record what each attempt had counted when this unlock was reached (see WriteOff).
 if changed then self:Bank(p) end
 if not p.Completion and progress+EPS>=self.Config.CompletionGoal then
  p.Completion={At=self.Engine.Time,Announced=false} changed=true
 end
 if not p.FirstProfit then
  for _,accountId in ipairs(p.Ledger) do
   local a=self.Engine.Accounts[accountId]
   for _,h in ipairs(a and a.History or {}) do
    if h.Pnl>EPS then p.FirstProfit={Pnl=h.Pnl,Contract=h.Contract,At=self.Engine.Time,Announced=false} changed=true break end
   end
   if p.FirstProfit then break end
  end
 end
 if changed then self:_touch(p) end
 return changed
end
function Funded:TakeEvents(uid)
 local p=self.Engine.Profiles[uid] if not p then return nil end
 local events={}
 if p.FirstProfit and p.FirstProfit.Announced==false then
  p.FirstProfit.Announced=true table.insert(events,{Kind="FirstProfit",Pnl=p.FirstProfit.Pnl,Contract=p.FirstProfit.Contract})
 end
 for _,id in ipairs(self.Order) do
  local entry=p.Tiers[id]
  if entry and entry.Announced==false then
   entry.Announced=true local t=self.Tiers[id]
   table.insert(events,{Kind="Unlocked",Tier=id,Name=t.Name,Short=t.Short,Size=t.Size,Unlock=t.Unlock,Earned=self:Earned(p)})
  end
 end
 if p.Completion and not p.Completion.Announced then
  p.Completion.Announced=true table.insert(events,{Kind="Completed",Name="Top tier complete"})
 end
 -- One notice per depletion event (per account attempt). The marker is saved with the profile, so
 -- reconnecting, refreshing or switching accounts never announces the same depletion again.
 for _,id in ipairs(self.Order) do
  local entry=p.Tiers[id] local d=self:Depletion(entry)
  if d and entry.DepletionNotice~=d.Event then
   entry.DepletionNotice=d.Event
   local t=self.Tiers[id] local a=self.Engine.Accounts[entry.Account] local s=self.Engine:Summary(a)
   table.insert(events,{Kind="Depleted",Tier=id,Name=t.Name,Short=t.Short,Size=t.Size,Attempt=entry.Attempt,Event=d.Event,
    Equity=s.Equity,Realized=a.Realized,Closing=d.Closing,Positions=d.Positions,CanRestart=d.CanRestart,
    Role=self:Role(p,id),Leader=p.Copy.Enabled and self.Tiers[p.Copy.Leader] and self.Tiers[p.Copy.Leader].Short or nil})
  end
 end
 if #events==0 then return nil end
 self:_touch(p) return events
end

function Funded:View(uid)
 local e=self.Engine local p=e.Profiles[uid]
 if not p then return {New=true,Revision=0} end
 local earned=self:Earned(p) local progress=self:Progress(p) local previous=0
 local view={Revision=p.Revision,Active=p.Active,Tutorial=p.Tutorial,CopyIntro=p.CopyIntro,Migrated=p.Migrated~=nil,
  ProgressCredit=p.ProgressCredit or 0,Completed=p.Completion~=nil,Progress=progress,WrittenOff=self:WrittenOff(p),
  Started=p.Tiers[self.Config.StarterTier]~=nil,Earned=earned,Capital=0,Open=0,Accounts={},Legacy={},ActiveCount=0,
  FirstProfit=p.FirstProfit and p.FirstProfit.Pnl or nil,
  Copy={Enabled=p.Copy.Enabled,Leader=p.Copy.Leader,Followers=table.clone(p.Copy.Followers),Sizing=p.Copy.Sizing}}
 for _,id in ipairs(self.Order) do
  local t=self.Tiers[id] local entry=p.Tiers[id]
  -- A player who has not started yet (e.g. migrated from practice accounts) sees the starter as "Start".
  local row={Key=id,Name=t.Name,Short=t.Short,Size=t.Size,Unlock=t.Unlock,LossLimit=t.LossLimit,MaxContracts=t.MaxContracts,
   Goal=t.Unlock-previous,Progress=progress-previous,
   State=entry and entry.State or (id==self.Config.StarterTier and "Start" or "Locked")}
  if entry and entry.State=="Active" then
   local a=e.Accounts[entry.Account] local s=e:Summary(a)
   row.Balance=s.Balance row.Equity=s.Equity row.Unrealized=s.Unrealized row.Realized=a.Realized row.Allowance=s.Allowance
   row.Positions=s.Count row.Orders=count(a.OpenOrders) row.Breached=a.Locked row.Attempt=entry.Attempt
   local d=self:Depletion(entry)
   if d then row.Depleted=true row.Closing=d.Closing row.CanRestart=d.CanRestart row.DepletionEvent=d.Event row.OpenContracts=d.Contracts end
   -- Earlier attempts of this tier stay in the ledger and in lifetime net realized profit (not unlock progress).
   local prior=0 for _,accountId in ipairs(p.Ledger) do local old=e.Accounts[accountId] if accountId~=entry.Account and old and old.Tier==id then prior+=old.Realized end end
   row.PriorRealized=prior
   view.Capital+=t.Size view.Open+=s.Unrealized view.ActiveCount+=1
  end
  if p.Copy.Enabled and row.State=="Active" then
   if p.Copy.Leader==id then row.Role="Lead" elseif table.find(p.Copy.Followers,id) then row.Role="Follow" end
  end
  if not entry and not view.Next and t.Unlock>0 then view.Next={Key=id,Name=t.Name,Short=t.Short,Unlock=t.Unlock,Goal=t.Unlock-previous,Progress=progress-previous,Remaining=math.max(0,t.Unlock-progress)} end
  table.insert(view.Accounts,row) previous=t.Unlock
 end
 if not view.Next and not p.Completion then
  view.Next={Key="Completion",Name="Top-tier milestone",Short="TOP TIER",Milestone=true,Unlock=self.Config.CompletionGoal,
   Goal=self.Config.CompletionGoal-previous,Progress=progress-previous,Remaining=math.max(0,self.Config.CompletionGoal-progress)}
 end
 view.CopyAvailable=view.ActiveCount>=self.Config.CopyTrading.MinAccounts
 for _,base in ipairs(p.Legacy) do
  local a=e.Accounts[self:LegacyId(uid,base)]
  if a then
   local s=e:Summary(a)
   table.insert(view.Legacy,{Key="L"..base,Name=self:LegacyName(base),Size=base,Balance=s.Balance,Equity=s.Equity,Unrealized=s.Unrealized,
    Realized=a.Realized,Allowance=s.Allowance,Positions=s.Count,Orders=count(a.OpenOrders),Breached=a.Locked})
  end
 end
 local _,kind,info=self:Resolve(uid,p.Active)
 if kind=="Funded" then view.ActiveName=info.Name view.ActiveShort=info.Short view.ActiveSize=info.Size view.ActiveKind="Funded"
 elseif kind=="Legacy" then view.ActiveName=self:LegacyName(info) view.ActiveShort=self:LegacyName(info) view.ActiveSize=info view.ActiveKind="Legacy"
 else view.Active=nil end
 return view
end

-- Lifetime trading statistics for the Stats page. Every value is computed here from the persisted per-account
-- counters (TradeStats) and the live engine summary; the client only formats it.
--  * All Funded Accounts: every funded attempt in the ledger once (retired/restarted attempts included).
--  * Tier: that tier's attempts. Each scope also has Current: only the attempt trading now.
--  * Legacy practice accounts are reported separately and never enter funded totals.
function Funded:Stats(uid)
 local e=self.Engine local p=e.Profiles[uid]
 if not p then return {Ready=true,New=true,Scopes={},Legacy={}} end
 local all,allNow=TradeStats.Empty(),TradeStats.Empty()
 local tiers,seen={}, {}
 for _,id in ipairs(p.Ledger) do
  local a=e.Accounts[id]
  if a and a.Tier and self.Tiers[a.Tier] and not seen[id] then
   seen[id]=true
   local t=tiers[a.Tier] or {Life=TradeStats.Empty(),Current=TradeStats.Empty()} tiers[a.Tier]=t
   TradeStats.Include(all,e,a) TradeStats.Include(t.Life,e,a)
   local entry=p.Tiers[a.Tier]
   if entry and entry.State=="Active" and entry.Account==id then
    TradeStats.Include(allNow,e,a) TradeStats.Include(t.Current,e,a) t.Attempt=entry.Attempt
   end
  end
 end
 local active=0 for _ in pairs(tiers) do active+=1 end
 local scopes={{Key="ALL",Kind="All",Name="All Funded Accounts",Short="All funded",Life=TradeStats.Finish(all),Current=TradeStats.Finish(allNow)}}
 for _,id in ipairs(self.Order) do
  local t=tiers[id]
  if t then
   local info=self.Tiers[id]
   table.insert(scopes,{Key=id,Kind="Tier",Name=info.Name,Short=info.Short,Attempt=t.Attempt,Life=TradeStats.Finish(t.Life),Current=TradeStats.Finish(t.Current)})
  end
 end
 local legacy={}
 for _,base in ipairs(p.Legacy) do
  local a=e.Accounts[self:LegacyId(uid,base)]
  if a then
   table.insert(legacy,{Key="L"..base,Kind="Legacy",Name=self:LegacyName(base),Short=self:LegacyName(base),
    Life=TradeStats.Finish(TradeStats.Include(TradeStats.Empty(),e,a))})
  end
 end
 return {Ready=true,Started=p.Tiers[self.Config.StarterTier]~=nil,Scopes=scopes,Legacy=legacy,Tiers=active}
end
-- Cheap change signature: the Stats packet is resent only when a counted value can have changed.
-- Open P&L moves continuously and is shown from the live portfolio summary instead.
function Funded:StatsKey(uid)
 local e=self.Engine local p=e.Profiles[uid]
 if not p then return "new" end
 local parts={#p.Ledger,#p.Legacy}
 local function add(a)
  local s=a and a.Stats
  table.insert(parts,s and (s.Trades..":"..s.LastTradeId..":"..s.UntrackedTrades..":"..tostring(a.Depleted)..":"..tostring(a.Retired)) or "-")
 end
 for _,id in ipairs(p.Ledger) do add(e.Accounts[id]) end
 for _,base in ipairs(p.Legacy) do add(e.Accounts[self:LegacyId(uid,base)]) end
 for _,id in ipairs(self.Order) do local entry=p.Tiers[id] if entry then table.insert(parts,id..tostring(entry.Account)) end end
 return table.concat(parts,"|")
end

-- Shared trade execution: identical for lead, copied and independent orders.
function Funded.Perform(engine,owner,req)
 local a=engine.Accounts[owner]
 if not a then return false,"Unknown account." end
 if req.Action=="Place" then return engine:Submit(owner,req)
 elseif req.Action=="AmendProtection" then return engine:AmendProtection(owner,req)
 elseif req.Action=="AmendOrder" then return engine:AmendOrder(owner,req)
 elseif req.Action=="Cancel" then
  if type(req.OrderId)~="number" then return false,"Unknown order." end
  if req.Protection then return engine:CancelProtection(owner,req.OrderId,req.Protection) end
  return engine:Cancel(owner,req.OrderId)
 elseif req.Action=="Close" then
  local p=a.Positions[req.Contract]
  if not p then return false,"No open position." end
  engine:CancelAll(owner,req.Contract)
  -- Latched close survives a partial fill/empty book and cannot reverse the position.
  p.Triggered="Player close" p.Stop=nil p.Target=nil
  return engine:Submit(owner,{Contract=req.Contract,Direction=-p.Direction,Quantity=math.min(p.Quantity,engine.Config.MaxPlayerQuantity),Type="Market",ReduceOnly=true})
 end
 return false,"Request rejected."
end
function Funded.Describe(result)
 local message=result.Filled>0 and string.format("Filled %d @ %.2f · slippage %+.2f pts",result.Filled,result.Average,result.Slippage) or result.Status
 if result.Remaining>0 then message..=" · "..result.Remaining.." working" end
 if result.Cancelled>0 then message..=" · "..result.Cancelled.." unfilled" end
 return message
end
function Funded.Size(quantity,leaderSize,followerSize,sizing)
 local n=sizing=="Proportional" and math.floor(quantity*followerSize/leaderSize+1e-9) or quantity
 -- Never silently shrink a copy. Submit validates the follower's actual available capacity.
 return n
end

-- Copy plan for an order from this account; nil unless copying is enabled and it is the lead.
function Funded:Plan(uid,owner)
 local p=self.Engine.Profiles[uid]
 if not p or not p.Copy.Enabled then return nil end
 local lead=p.Tiers[p.Copy.Leader]
 if not lead or lead.State~="Active" or lead.Account~=owner then return nil end
 local followers={}
 for _,key in ipairs(p.Copy.Followers) do
  local entry=p.Tiers[key]
  if entry and entry.State=="Active" and entry.Account~=owner and self.Engine.Accounts[entry.Account] then
   table.insert(followers,{Key=key,Id=entry.Account,Tier=self.Tiers[key]})
  end
 end
 if #followers==0 then return nil end
 return {Leader=self.Tiers[p.Copy.Leader],Followers=followers,Sizing=p.Copy.Sizing}
end
-- Captured before the lead action runs: a close or protective change needs the lead's prior position.
function Funded:Context(owner,req)
 local a=self.Engine.Accounts[owner] if not a then return {} end
 if req.Action=="Close" then local p=a.Positions[req.Contract] return {Contract=req.Contract,Direction=p and p.Direction} end
 if req.Action=="AmendProtection" or (req.Action=="Cancel" and req.Protection) then
  for _,key in ipairs(self.Engine.Config.ContractOrder) do local p=a.Positions[key] if p and p.Id==req.OrderId then return {Contract=key,Direction=p.Direction} end end
 end
 return {}
end
function Funded:Mirror(plan,req,ok,result,context)
 if not plan then return nil end
 local e=self.Engine local items={}
 local function add(f,status,message) table.insert(items,{Key=f.Key,Name=f.Tier.Short,Status=status,Message=message}) end
 for _,f in ipairs(plan.Followers) do
  local account=e.Accounts[f.Id] local action=req.Action
  if not ok then add(f,"Skipped","Lead request was rejected, so nothing was copied.")
  elseif account.Locked and (action=="Place" or action=="AmendProtection" or action=="AmendOrder") then
   add(f,"Skipped","Account blown (equity reached $0). Restart it to resume copying.")
  elseif action=="Place" then
   local quantity=Funded.Size(req.Quantity,plan.Leader.Size,f.Tier.Size,plan.Sizing,e.Config.MaxPlayerQuantity)
   if quantity<1 then add(f,"Skipped","Rounds to 0 contracts at proportional size.")
   else
    local copyOk,copy=e:Submit(f.Id,{Contract=req.Contract,Direction=req.Direction,Quantity=quantity,Type=req.Type,Price=req.Price,
     StopTicks=req.StopDollars and require(game.ReplicatedStorage.MarketReign.TradeProtection).Resolve(e.Books[req.Contract].Spec,req.Quantity,req.StopDollars).Ticks or req.StopTicks,
     TargetTicks=req.TargetDollars and require(game.ReplicatedStorage.MarketReign.TradeProtection).Resolve(e.Books[req.Contract].Spec,req.Quantity,req.TargetDollars).Ticks or req.TargetTicks,Link=type(result)=="table" and result.Id or nil})
    if not copyOk then add(f,"Rejected",copy)
    elseif copy.Filled==0 and copy.Remaining==0 then add(f,"Rejected",copy.Status)
    else add(f,"Copied",Funded.Describe(copy)) end
   end
  elseif action=="Close" then
   local p=account.Positions[req.Contract]
   if not context.Direction or not p or p.Direction~=context.Direction then add(f,"Skipped","No matching "..req.Contract.." position.")
   else
    local copyOk,copy=Funded.Perform(e,f.Id,{Action="Close",Contract=req.Contract})
    add(f,copyOk and "Copied" or "Rejected",type(copy)=="table" and Funded.Describe(copy) or copy)
   end
  elseif action=="AmendOrder" then
   local found=false
   for _,id in ipairs(sortedKeys(account.OpenOrders)) do
    local o=e.Orders[id]
    if o and o.Link==req.OrderId and o.Type=="Limit" then
     found=true
     local copied,message=e:AmendOrder(f.Id,{Contract=o.Contract,OrderId=id,Price=req.Price,ExpectedPrice=o.Price*e.Books[o.Contract].Spec.Tick,ExpectedQuantity=o.Remaining})
     add(f,copied and "Copied" or "Rejected",message)
    end
   end
   if not found then add(f,"Skipped","No linked limit order still working.") end
  elseif action=="Cancel" and not req.Protection then
   local cancelled=0
   for _,id in ipairs(sortedKeys(account.OpenOrders)) do
    local o=e.Orders[id] if o and o.Link==req.OrderId and e:Cancel(f.Id,id) then cancelled+=1 end
   end
   if cancelled>0 then add(f,"Copied","Cancelled "..cancelled.." linked order"..(cancelled==1 and "" or "s")..".")
   else add(f,"Skipped","No linked order still working.") end
  elseif action=="AmendProtection" or action=="Cancel" then
   local field=req.Protection local label=field=="Stop" and "SL" or "TP"
   local p=context.Contract and account.Positions[context.Contract]
   if not p or p.Direction~=context.Direction or p.Triggered or not p[field] then add(f,"Skipped","No matching "..label.." to update.")
   elseif action=="AmendProtection" then
    local copyOk,copy=e:AmendProtection(f.Id,{Contract=context.Contract,OrderId=p.Id,Protection=field,Price=req.Price,ExpectedPrice=p[field]})
    add(f,copyOk and "Copied" or "Rejected",copy)
   else
    local copyOk,copy=e:CancelProtection(f.Id,p.Id,field)
    add(f,copyOk and "Copied" or "Rejected",copy)
   end
  end
 end
 local report={Leader=plan.Leader.Short,Action=req.Action,Items=items,Copied=0,Skipped=0,Rejected=0,Total=#items,Sizing=plan.Sizing}
 for _,item in ipairs(items) do report[item.Status]+=1 end
 return report
end
return Funded
