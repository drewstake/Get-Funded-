-- Permanent tier entitlements, independent funded instances, and earned-profit wallet.
-- The complete profile, receipts and account ledger share one fenced exchange checkpoint.
local Funded={} Funded.__index=Funded
local TradeStats=require(script.Parent.TradeStats)
local EPS=1e-6
local function money(n)
 local raw=string.format("%.2f",math.abs(n or 0));local whole,decimal=raw:match("^(%d+)%.(%d+)$")
 whole=whole:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
 return ((n or 0)<0 and "-" or "").."$"..whole..(decimal=="00" and "" or "."..decimal)
end
Funded.Money=money
local function count(t) local n=0 for _ in pairs(t or {}) do n+=1 end return n end
local function sortedKeys(t) local r={} for k in pairs(t or {}) do table.insert(r,k) end table.sort(r) return r end
local function ended(a) return a.Retired==true or a.Locked==true or a.Depleted==true end
function Funded.Validate(config)
 assert(type(config.Tiers)=="table" and #config.Tiers>0,"Missing funded tiers")
 local seen,size,unlock={},0,-1
 for i,t in ipairs(config.Tiers) do
  assert(type(t.Id)=="string" and #t.Id<=8 and not t.Id:find("[,:]"),"Invalid tier id")
  assert(not seen[t.Id] and t.Size>size and t.Unlock>unlock,"Invalid funded ladder")
  assert((i==1)==(t.Unlock==0) and t.LossLimit==t.Size and t.MaxContracts>=1,"Invalid tier limits")
  assert(type(t.Price)=="number" and t.Price>0 and t.Price%1==0,"Invalid shop price")
  seen[t.Id]=true size=t.Size unlock=t.Unlock
 end
 assert(config.Tiers[1].Id==config.StarterTier,"Invalid starter tier")
end
function Funded.Key(uid) return tostring(uid) end
function Funded:Group(uid) return "player:"..uid end
function Funded:Profile(uid) return self.Engine.Profiles[uid] end
function Funded:_touch(p) p.Revision=(p.Revision or 0)+1 end
function Funded:Usable(a) return a and self.Tiers[a.Tier]~=nil and not ended(a) and not a.LegacyRetired end
function Funded:Final(a) return a and ended(a) and not next(a.Positions) and not next(a.OpenOrders) end
function Funded:StageFloor(p)
 local floor=0 for _,key in ipairs(self.Order) do if p.Tiers[key] then floor=math.max(floor,self.Tiers[key].Unlock) end end return floor
end
function Funded:InstanceName(entry,short)
 local t=self.Tiers[entry.Tier]
 return (short and t.Short or t.Name).." #"..entry.Attempt
end
function Funded:Entries(p)
 local result,seen={},{} for _,id in ipairs(p.Ledger) do
  local a=self.Engine.Accounts[id];local key=a and a.InstanceKey
  if key and p.Instances[key] and p.Instances[key].Account==id and not seen[id] then seen[id]=true;table.insert(result,p.Instances[key]) end
 end return result
end
function Funded:_new(uid,migrated)
 local p={V=self.Config.Version,Tiers={},Instances={},Ledger={},Legacy={},Revision=1,Created=self.Engine.Time,Migrated=migrated,
  ProgressState={Carry=0,Values={},Seen={}},WalletCents=0,WalletEarnedCents=0,WalletSpentCents=0,WalletHighs={},
  Purchases={},PurchaseSequence=0,Tutorial="None",CopyIntro=false,Copy={Enabled=false,Followers={},Sizing=self.Config.CopyTrading.DefaultSizing}}
 self.Engine.Profiles[uid]=p return p
end
-- Upgrade only once. Tier records (even formerly Locked/Reearn), retained attempts and write-offs
-- are independent evidence of earned access. Nothing in this migration edits funded trading results.
function Funded:Migrate(p,uid)
 if (p.V or 1)>=self.Config.Version and p.Instances and p.ProgressState then return end
 local e=self.Engine
 p.Tiers=p.Tiers or {};p.Ledger=p.Ledger or {};p.Legacy=p.Legacy or {}
 p.Copy=p.Copy or {Enabled=false,Followers={},Sizing="Same"}
 local previousActive=p.Active;local oldCopy=table.clone(p.Copy);oldCopy.Followers=table.clone(p.Copy.Followers or {})
 local credit=p.ProgressCredit or 0
 if (p.V or 1)<2 then
  for key in pairs(p.Tiers) do local t=self.Tiers[key];if t then credit=math.max(credit,t.Unlock-(self.Config.LegacyUnlocks[key] or 0)) end end
 end
 local ledger,seen={},{}
 local function retain(id)
  local a=e.Accounts[id]
  if a and self.Tiers[a.Tier] and not seen[id] then seen[id]=true;table.insert(ledger,id) end
 end
 for _,id in ipairs(p.Ledger) do retain(id) end
 for _,entry in pairs(p.Tiers) do if type(entry)=="table" and entry.Account then retain(entry.Account) end end
 for _,id in ipairs(e.AccountOrder) do local a=e.Accounts[id]
  if a.Player and id:sub(1,#("player:"..uid..":"))=="player:"..uid..":" then retain(id) end
 end
 p.Ledger=ledger;p.Instances={};p.WalletHighs={};p.Purchases={};p.PurchaseSequence=0
 local highest=0;local oldProgress=credit;local wallet=0;local hasUsable=false;local hasCurrentProfit=false
 for i,key in ipairs(self.Order) do if p.Tiers[key] then highest=math.max(highest,i) end end
 for _,w in pairs(p.WriteOffs or {}) do for i,key in ipairs(self.Order) do if w.Tier==key then highest=math.max(highest,i) end end end
 for _,id in ipairs(ledger) do
  local a=e.Accounts[id];local t=self.Tiers[a.Tier]
  for i,key in ipairs(self.Order) do if key==a.Tier then highest=math.max(highest,i) end end
  local attempt=tonumber(id:match(":(%d+)$")) or 1;local key=a.Tier..":"..attempt
  while p.Instances[key] do attempt+=1;key=a.Tier..":"..attempt end
  a.InstanceKey=key;a.ProfileId=uid
  p.Instances[key]={Key=key,Tier=a.Tier,Account=id,Attempt=attempt,Source="Migrated",Created=a.Created or p.Created,DepletionNotice=ended(a) or nil}
  local w=(p.WriteOffs or {})[id]
  oldProgress+=w and w.Counted or (ended(a) and math.max(0,a.Realized) or a.Realized)
  if self:Usable(a) then hasUsable=true;hasCurrentProfit=hasCurrentProfit or math.abs(a.Realized)>EPS or next(a.Positions)~=nil end
  -- Seed only currently earned positive net profit. Recover the saved high watermark from retained
  -- closing history so losing/recovering the same profit cannot mint the same wallet credit again.
  local running=a.Realized;for _,h in ipairs(a.History or {}) do running-=h.Pnl or 0 end
  local high=math.max(0,running,a.Realized)
  for i=#(a.History or {}),1,-1 do running+=a.History[i].Pnl or 0;high=math.max(high,running) end
  p.WalletHighs[id]=math.max(0,math.round(high*100));wallet+=math.max(0,math.round(a.Realized*100))
 end
 for i=1,highest do
  local key=self.Order[i];local entry=p.Tiers[key] or {UnlockedAt=e.Time,Announced=true}
  entry.Reearn=nil;entry.State="Unlocked";entry.Claimed=false
  for _,item in pairs(p.Instances) do if item.Tier==key then entry.Claimed=true end end
  -- Keep old entitlement metadata, including its original account reference, as migration evidence.
  p.Tiers[key]=entry
 end
 p.ProgressCredit=credit -- retained migration evidence; never Shop currency or new qualifying profit
 local residual=math.max(0,oldProgress-self:StageFloor(p))
 if not hasUsable or not hasCurrentProfit then residual=0 end
 p.ProgressState={Carry=residual,Values={},Seen={}}
 for _,id in ipairs(ledger) do p.ProgressState.Seen[id]=e.Accounts[id].Realized end
 p.WalletCents=wallet;p.WalletEarnedCents=wallet;p.WalletSpentCents=0
 local function convert(key)
  if p.Instances[key] then return key end
  local entry=p.Tiers[key]
  if entry and entry.Account and e.Accounts[entry.Account] then return e.Accounts[entry.Account].InstanceKey end
 end
 p.Active=convert(previousActive);p.Copy={Enabled=oldCopy.Enabled,Leader=convert(oldCopy.Leader),Followers={},Sizing=oldCopy.Sizing or "Same"}
 local copied={} for _,key in ipairs(oldCopy.Followers) do local k=convert(key)
  if k and k~=p.Copy.Leader and not copied[k] then copied[k]=true;table.insert(p.Copy.Followers,k) end
 end
 p.LegacyArchive=p.Legacy;p.Legacy={};p.V=self.Config.Version;p.Migrated=p.Migrated or "permanent-v3";self:_touch(p)
end
function Funded:RetireLegacy()
 local e=self.Engine
 for _,id in ipairs(e.AccountOrder) do local a=e.Accounts[id]
  if a.Player and id:match("^player:") and not self.Tiers[a.Tier] then
   e:CancelAll(id)
   -- Close obsolete exposure against the existing house using the same accounting path. Retain
   -- the resulting archived ledger so exchange inventory/cash audits continue to reconcile.
   for contract,pos in pairs(table.clone(a.Positions)) do
    pos.Stop=nil;pos.Target=nil;pos.Triggered="Account retired"
    while a.Positions[contract] do
     local held=a.Positions[contract]
     local ok=e:Submit(id,{Contract=contract,Direction=-held.Direction,Quantity=math.min(held.Quantity,e.Config.MaxPlayerQuantity),Type="Market",ReduceOnly=true},{})
     if not ok then break end
    end
   end
   a.LegacyRetired=true;a.Locked=true;a.Retired=not next(a.Positions)
  end
 end
end
function Funded.new(engine,config,market)
 Funded.Validate(config);engine.Profiles=engine.Profiles or {}
 local self=setmetatable({Engine=engine,Config=config,Market=market or engine.Config,Tiers={},Order={}},Funded)
 for i,t in ipairs(config.Tiers) do self.Tiers[t.Id]=t;self.Order[i]=t.Id end
 -- Imported saves can contain funded accounts without a profile. Recover them rather than discard.
 for _,id in ipairs(engine.AccountOrder) do local a=engine.Accounts[id];local uid=id:match("^player:([^:]+):")
  if a.Player and uid and not engine.Profiles[uid] then engine.Profiles[uid]={V=1,Tiers={},Ledger={},Legacy={},Copy={Enabled=false,Followers={},Sizing="Same"}} end
 end
 for uid,p in pairs(engine.Profiles) do self:Migrate(p,uid);self:Join(uid) end
 self:RetireLegacy()
 for _,id in ipairs(engine.AccountOrder) do local a=engine.Accounts[id];if a.Player then TradeStats.Reconcile(engine,a,os.time()) end end
 -- Called synchronously after every closing fill. An intermediate winning close can earn a tier
 -- even if a later closing fill loses; open P&L never enters this callback.
 engine.OnFundedClose=function(a) if a.ProfileId then self:Evaluate(a.ProfileId) end end
 return self
end
function Funded:Join(uid)
 local p=self:Profile(uid);if not p then return nil end
 self:Migrate(p,uid)
 for _,entry in ipairs(self:Entries(p)) do local a=self.Engine.Accounts[entry.Account];local t=self.Tiers[entry.Tier]
  a.Group=self:Group(uid);a.ProfileId=uid;a.Limit=math.min(t.MaxContracts,self.Market.MaxPlayerInventory);a.Risk=self.Config.MarginUse
 end
 self:Reconcile(p);self:CleanCopy(p)
 if not p.Active or not p.Instances[p.Active] or not self:Usable(self.Engine.Accounts[p.Instances[p.Active].Account]) then
  for _,entry in ipairs(self:Entries(p)) do if self:Usable(self.Engine.Accounts[entry.Account]) then p.Active=entry.Key;break end end
 end
 return p
end
function Funded:Resolve(uid,key)
 local p=self:Profile(uid);if not p or type(key)~="string" then return nil end
 local entry=p.Instances[key];local a=entry and self.Engine.Accounts[entry.Account]
 if entry and a and not a.LegacyRetired and self.Tiers[entry.Tier] then return entry.Account,"Funded",self.Tiers[entry.Tier] end
end
function Funded:Owner(uid) local p=self:Profile(uid);return p and self:Resolve(uid,p.Active) or nil end
function Funded:_open(uid,p,tierId,source)
 local t=self.Tiers[tierId];local attempt=1
 for _,item in ipairs(self:Entries(p)) do if item.Tier==tierId then attempt=math.max(attempt,item.Attempt+1) end end
 local id="player:"..uid..":"..tierId..":"..attempt
 while self.Engine.Accounts[id] do attempt+=1;id="player:"..uid..":"..tierId..":"..attempt end
 local key=tierId..":"..attempt
 local a=self.Engine:AddAccount(id,t.Size,math.min(t.MaxContracts,self.Market.MaxPlayerInventory),self.Config.MarginUse,true)
 a.LossLimit=t.LossLimit;a.Group=self:Group(uid);a.Tier=tierId;a.InstanceKey=key;a.ProfileId=uid
 local entry={Key=key,Tier=tierId,Account=id,Attempt=attempt,Source=source,Created=self.Engine.Time}
 p.Instances[key]=entry;table.insert(p.Ledger,id)
 p.ProgressState.Seen[id]=0;p.ProgressState.Values[id]=0;p.WalletHighs[id]=0
 self:_touch(p);return entry
end
function Funded:ActiveTiers(p)
 local r={} for _,entry in ipairs(self:Entries(p)) do if self:Usable(self.Engine.Accounts[entry.Account]) then table.insert(r,entry.Key) end end return r
end
function Funded:CanRestart(p)
 if not self.Config.AllowRestart or #self:ActiveTiers(p)>0 then return false end
 for _,entry in ipairs(self:Entries(p)) do local a=self.Engine.Accounts[entry.Account];if next(a.Positions) or next(a.OpenOrders) then return false end end
 return p.Tiers[self.Config.StarterTier]~=nil
end
function Funded:ResetProgress(p)
 p.ProgressState.Carry=0
 for _,entry in ipairs(self:Entries(p)) do local id=entry.Account;p.ProgressState.Values[id]=0;p.ProgressState.Seen[id]=self.Engine.Accounts[id].Realized end
 p.ProgressResetAt=self.Engine.Time
end
function Funded:Reconcile(p)
 local s=p.ProgressState;local changed=false;local usable=0
 for _,entry in ipairs(self:Entries(p)) do
  local id=entry.Account;local a=self.Engine.Accounts[id];local delta=a.Realized-(s.Seen[id] or a.Realized)
  if self:Usable(a) then usable+=1;s.Values[id]=(s.Values[id] or 0)+delta
  else s.Values[id]=0 end -- finished/blown losses never become future unlock debt
  if delta~=0 then changed=true end;s.Seen[id]=a.Realized
  local high=math.max(0,math.round(a.Realized*100));local prior=p.WalletHighs[id] or 0
  if high>prior then
   local credit=high-prior;p.WalletCents+=credit;p.WalletEarnedCents+=credit;p.WalletHighs[id]=high;changed=true
  end
 end
 if usable==0 and (s.Carry~=0 or next(s.Values)) then
  s.Carry=0;for id in pairs(s.Values) do if s.Values[id]~=0 then changed=true end;s.Values[id]=0 end
 end
 if changed then self:_touch(p) end
end
function Funded:StageProgress(p) local n=p.ProgressState.Carry or 0;for _,v in pairs(p.ProgressState.Values) do n+=v end;return n end
function Funded:Progress(p) return self:StageFloor(p)+self:StageProgress(p) end
function Funded:WrittenOff(_p) return 0 end
function Funded:EligibleOpen(p)
 local n=0;for _,entry in ipairs(self:Entries(p)) do local a=self.Engine.Accounts[entry.Account];if self:Usable(a) then n+=self.Engine:Summary(a).Unrealized end end return n
end
function Funded:Consume(p,goal)
 local s=p.ProgressState;local n=math.min(goal,math.max(0,s.Carry));s.Carry-=n;goal-=n
 for _,id in ipairs(p.Ledger) do local v=s.Values[id] or 0;local used=math.min(goal,math.max(0,v));s.Values[id]=v-used;goal-=used end
 assert(goal<EPS,"Qualifying profit does not cover unlock")
end
function Funded:CleanCopy(p)
 local c=p.Copy;local good={};for _,k in ipairs(self:ActiveTiers(p)) do good[k]=true end
 if not good[c.Leader] then c.Enabled=false;c.Leader=nil end
 local seen,followers={},{};for _,k in ipairs(c.Followers or {}) do if good[k] and k~=c.Leader and not seen[k] then seen[k]=true;table.insert(followers,k) end end
 if #followers==0 then c.Enabled=false end;c.Followers=followers
end
function Funded:Start(uid)
 local p=self:Profile(uid) or self:_new(uid);local key=self.Config.StarterTier;local t=self.Tiers[key]
 if p.Tiers[key] and p.Tiers[key].Claimed then return true,"Your funded accounts are ready.",false end
 p.Tiers[key]=p.Tiers[key] or {State="Unlocked",UnlockedAt=self.Engine.Time,Announced=true}
 local entry=self:_open(uid,p,key,"Starter");p.Tiers[key].Claimed=true;p.Tiers[key].Account=entry.Account
 p.Active=entry.Key;p.Tutorial="Pending";self:_touch(p)
 return true,"Your "..t.Name.." is live.",true
end
function Funded:Activate(uid,tierId)
 local p=self:Profile(uid);local t=self.Tiers[tierId];local entitlement=p and p.Tiers[tierId]
 if not t or not entitlement then return false,"Earn this tier through closed funded profit first." end
 if entitlement.Claimed then return true,"First activation already claimed. Additional accounts are available in the Shop." end
 local entry=self:_open(uid,p,tierId,"Unlock");entitlement.Claimed=true;entitlement.Account=entry.Account;entitlement.Announced=true
 if not p.Active then p.Active=entry.Key end
 self:_touch(p);return true,self:InstanceName(entry).." activated. Funded capital is separate from Shop balance."
end
function Funded:Select(uid,key)
 local id,_,t=self:Resolve(uid,key);if not id or not self:Usable(self.Engine.Accounts[id]) then return false,"Choose a usable funded account." end
 local p=self:Profile(uid);p.Active=key;self:_touch(p);return true,"Now trading "..self:InstanceName(p.Instances[key]).."."
end
function Funded:Restart(uid,_key)
 local p=self:Profile(uid)
 if not p or not self:CanRestart(p) then return false,"A free $5K restart is available when no usable accounts remain and liquidation is finished." end
 self:ResetProgress(p)
 for _,old in ipairs(self:Entries(p)) do local a=self.Engine.Accounts[old.Account];if self:Final(a) then a.Retired=true end end
 local entry=self:_open(uid,p,self.Config.StarterTier,"Free restart");p.Active=entry.Key
 self:_touch(p);return true,"Fresh $5K account ready. Permanent tiers and history kept; next-stage progress starts at $0."
end
-- Sequence is a server-issued, persisted purchase intent. A repeated confirmation or reconnect
-- replay returns the original receipt; an old intent can never become a second charge.
function Funded:Purchase(uid,tierId,sequence)
 local p=self:Profile(uid);local t=self.Tiers[tierId]
 if not p or not t or not p.Tiers[tierId] then return false,"This tier has not been permanently unlocked." end
 if type(sequence)~="number" or sequence%1~=0 or sequence<1 or sequence>1e9 then return false,"Invalid purchase confirmation." end
 local receipt=p.Purchases[tostring(sequence)]
 if receipt then
  if receipt.Tier~=tierId then return false,"This purchase confirmation was already used." end
  return true,"Account already purchased. No additional charge.",receipt
 end
 if sequence~=p.PurchaseSequence+1 then return false,"Shop updated. Review the current price and confirm again." end
 local cost=t.Price*100
 if p.WalletCents<cost then return false,"Not enough earned-profit balance. You need "..money((cost-p.WalletCents)/100).." more." end
 if self:CanRestart(p) then self:ResetProgress(p) end
 local entry=self:_open(uid,p,tierId,"Shop")
 p.WalletCents-=cost;p.WalletSpentCents+=cost;p.PurchaseSequence=sequence
 receipt={Sequence=sequence,Tier=tierId,Key=entry.Key,Account=entry.Account,PriceCents=cost,At=self.Engine.Time}
 p.Purchases[tostring(sequence)]=receipt
 if not p.Active or not self:Usable(self.Engine.Accounts[self:Owner(uid)]) then p.Active=entry.Key end
 self:_touch(p);return true,self:InstanceName(entry).." purchased for "..money(t.Price)..".",receipt
end
function Funded:SetCopy(uid,req)
 local p=self:Profile(uid);if not p then return false,"Start a funded account first." end
 if req.Enabled~=1 and req.Enabled~=true then p.Copy.Enabled=false;self:_touch(p);return true,"Copy trading off. Existing positions stay on each account." end
 local good={};for _,k in ipairs(self:ActiveTiers(p)) do good[k]=true end
 if not good[req.Leader] then return false,"Choose a usable account to lead." end
 local chosen,followers={},{}
 for k in string.gmatch(type(req.Followers)=="string" and req.Followers or "","[^,]+") do
  if not good[k] then return false,"Choose usable funded followers." end
  if k~=req.Leader and not chosen[k] then chosen[k]=true;table.insert(followers,k) end
 end
 if #followers<1 then return false,"Choose at least one other account to follow." end
 if #followers>(self.Config.CopyTrading.MaxFollowers or 20) then return false,"Too many copy followers." end
 p.Copy={Enabled=true,Leader=req.Leader,Followers=followers,Sizing=req.Sizing=="Proportional" and "Proportional" or "Same"}
 p.CopyIntro=true;self:_touch(p);return true,"Copy trading on. Each account keeps its own trades and limits."
end
function Funded:Flag(uid,stage)
 local p=self:Profile(uid);if not p then return false,"Start a funded account first." end
 if stage=="TutorialDone" or stage=="TutorialSkipped" then if p.Tutorial=="Pending" then p.Tutorial=stage=="TutorialDone" and "Done" or "Skipped" end
 elseif stage=="CopyIntro" then p.CopyIntro=true else return false,"Unknown onboarding step." end
 self:_touch(p);return true,"Saved."
end
function Funded:Earned(p)
 local n,seen=0,{};for _,id in ipairs(p.Ledger) do local a=self.Engine.Accounts[id];if a and self.Tiers[a.Tier] and not seen[id] then seen[id]=true;n+=a.Realized end end;return n
end
function Funded:Evaluate(uid)
 local p=self:Profile(uid);if not p then return false end
 self:Reconcile(p);self:CleanCopy(p)
 if not p.Tiers[self.Config.StarterTier] then return false end
 local changed=false;local previous=0
 for _,id in ipairs(self.Order) do local t=self.Tiers[id];local goal=t.Unlock-previous
  if not p.Tiers[id] then
   if self:StageProgress(p)+EPS<goal then break end
   self:Consume(p,goal);p.Tiers[id]={State="Unlocked",Claimed=false,UnlockedAt=self.Engine.Time,Earned=self:Earned(p),Announced=false};changed=true
  end
  previous=t.Unlock
 end
 local last=self.Tiers[self.Order[#self.Order]]
 if p.Tiers[last.Id] and not p.Completion and self:StageProgress(p)+EPS>=self.Config.CompletionGoal-last.Unlock then
  p.Completion={At=self.Engine.Time,Announced=false};changed=true
 end
 if not p.FirstProfit then
  for _,id in ipairs(p.Ledger) do for _,h in ipairs(self.Engine.Accounts[id].History or {}) do
   if h.Pnl>EPS then p.FirstProfit={Pnl=h.Pnl,Contract=h.Contract,At=self.Engine.Time,Announced=false};changed=true;break end
  end;if p.FirstProfit then break end end
 end
 local current=p.Instances[p.Active]
 if not current or not self:Usable(self.Engine.Accounts[current.Account]) then
  local available=self:ActiveTiers(p);if #available>0 and p.Active~=available[1] then p.Active=available[1];changed=true end
 end
 if changed then self:_touch(p) end;return changed
end
function Funded:Depletion(entry)
 local a=entry and self.Engine.Accounts[entry.Account];if not a or not ended(a) then return nil end
 local contracts=0;for _,pos in pairs(a.Positions) do contracts+=pos.Quantity end
 return {Closing=next(a.Positions)~=nil or next(a.OpenOrders)~=nil,Positions=count(a.Positions),Contracts=contracts,Event=entry.Key}
end
function Funded:Role(p,key)
 if not p.Copy.Enabled then return nil end
 return p.Copy.Leader==key and "Lead" or table.find(p.Copy.Followers,key) and "Follow" or nil
end
function Funded:TakeEvents(uid)
 local p=self:Profile(uid);if not p then return nil end;local events={}
 if p.FirstProfit and p.FirstProfit.Announced==false then p.FirstProfit.Announced=true;table.insert(events,{Kind="FirstProfit",Pnl=p.FirstProfit.Pnl,Contract=p.FirstProfit.Contract}) end
 for _,id in ipairs(self.Order) do local entry=p.Tiers[id];local t=self.Tiers[id]
  if entry and entry.Announced==false then entry.Announced=true;table.insert(events,{Kind="Unlocked",Tier=id,Name=t.Name,Short=t.Short,Size=t.Size,Unlock=t.Unlock,Earned=self:Earned(p)}) end
 end
 if p.Completion and not p.Completion.Announced then p.Completion.Announced=true;table.insert(events,{Kind="Completed",Name="Top tier complete"}) end
 for _,entry in ipairs(self:Entries(p)) do local d=self:Depletion(entry)
  if d and not entry.DepletionNotice then
   entry.DepletionNotice=true
   local a=self.Engine.Accounts[entry.Account];local t=self.Tiers[entry.Tier]
   table.insert(events,{Kind="Depleted",Tier=entry.Key,Name=self:InstanceName(entry),Short=self:InstanceName(entry,true),Event=d.Event,
    Attempt=entry.Attempt,Size=t.Size,Equity=self.Engine:Summary(a).Equity,Realized=a.Realized,Positions=d.Positions,Closing=d.Closing,CanRestart=self:CanRestart(p)})
  end
 end
 if #events==0 then return nil end;self:_touch(p);return events
end
function Funded:View(uid)
 local p=self:Profile(uid);if not p then return {New=true,Revision=0} end
 local e=self.Engine;local stage=self:StageProgress(p);local open=self:EligibleOpen(p)
 local v={Revision=p.Revision,Active=p.Active,Tutorial=p.Tutorial,CopyIntro=p.CopyIntro,Migrated=p.Migrated~=nil,
  Started=p.Tiers[self.Config.StarterTier] and p.Tiers[self.Config.StarterTier].Claimed or false,Earned=self:Earned(p),
  Completed=p.Completion~=nil,Progress=self:Progress(p),ProgressCredit=p.ProgressCredit or 0,WrittenOff=0,Capital=0,Open=0,Accounts={},Tiers={},Legacy={},
  ActiveCount=0,UsableCount=0,BlownCount=0,UnlockedCount=0,CanRestart=self:CanRestart(p),
  Wallet=p.WalletCents/100,WalletEarned=p.WalletEarnedCents/100,WalletSpent=p.WalletSpentCents/100,PurchaseSequence=p.PurchaseSequence+1,
  FirstProfit=p.FirstProfit and p.FirstProfit.Pnl,
  Copy={Enabled=p.Copy.Enabled,Leader=p.Copy.Leader,Followers=table.clone(p.Copy.Followers),Sizing=p.Copy.Sizing}}
 local previous=0
 for _,id in ipairs(self.Order) do local t=self.Tiers[id];local entry=p.Tiers[id];local goal=t.Unlock-previous
  local row={Key=id,Tier=id,Name=t.Name,Short=t.Short,Size=t.Size,Price=t.Price,Unlock=t.Unlock,Goal=goal,Progress=math.max(0,stage),
   Permanent=entry~=nil,Claimable=entry and not entry.Claimed or false,Affordable=p.WalletCents>=t.Price*100,
   State=entry and "Unlocked" or id==self.Config.StarterTier and "Start" or "Locked",Owned=0,Usable=0,Blown=0}
  if entry then v.UnlockedCount+=1 end
  for _,item in ipairs(self:Entries(p)) do if item.Tier==id then row.Owned+=1;if self:Usable(e.Accounts[item.Account]) then row.Usable+=1 else row.Blown+=1 end end end
  if not entry and t.Unlock>0 and not v.Next then
   v.Next={Key=id,Name=t.Name,Short=t.Short,Goal=goal,Unlock=t.Unlock,Progress=math.max(0,stage),Confirmed=math.max(0,stage),
    EligibleOpen=open,Projected=math.max(0,stage+open),Remaining=math.max(0,goal-stage),ProjectedRemaining=math.max(0,goal-stage-open)}
  end
  table.insert(v.Tiers,row);previous=t.Unlock
 end
 for _,entry in ipairs(self:Entries(p)) do
  local a=e.Accounts[entry.Account];local t=self.Tiers[entry.Tier];local summary=e:Summary(a);local d=self:Depletion(entry);local usable=self:Usable(a)
  table.insert(v.Accounts,{Key=entry.Key,Tier=entry.Tier,Name=self:InstanceName(entry),Short=self:InstanceName(entry,true),Size=t.Size,Account=entry.Account,
   State="Active",Permanent=true,Usable=usable,Attempt=entry.Attempt,Source=entry.Source,Balance=a.Balance,Equity=summary.Equity,
   Realized=a.Realized,Unrealized=summary.Unrealized,Allowance=summary.Allowance,Positions=summary.Count,Orders=count(a.OpenOrders),
   LossLimit=t.LossLimit,MaxContracts=t.MaxContracts,Breached=not usable,Depleted=d~=nil,Closing=d and d.Closing,CanRestart=v.CanRestart,
   DepletionEvent=d and d.Event,OpenContracts=d and d.Contracts,Role=self:Role(p,entry.Key)})
  if not a.Retired then v.Open+=summary.Unrealized end
  if usable then v.Capital+=t.Size;v.ActiveCount+=1;v.UsableCount+=1 else v.BlownCount+=1 end
 end
 if not v.Next and not p.Completion and p.Tiers[self.Order[#self.Order]] then
  local goal=self.Config.CompletionGoal-previous
  v.Next={Key="Completion",Name="Top-tier milestone",Short="TOP TIER",Milestone=true,Goal=goal,Progress=math.max(0,stage),Confirmed=math.max(0,stage),
   Projected=math.max(0,stage+open),EligibleOpen=open,Remaining=math.max(0,goal-stage),ProjectedRemaining=math.max(0,goal-stage-open)}
 end
 v.CopyAvailable=v.UsableCount>=self.Config.CopyTrading.MinAccounts
 local current=p.Instances[p.Active]
 if current then v.ActiveName=self:InstanceName(current);v.ActiveShort=self:InstanceName(current,true);v.ActiveSize=self.Tiers[current.Tier].Size;v.ActiveKind="Funded" else v.Active=nil end
 return v
end
function Funded:Stats(uid)
 local p=self:Profile(uid);if not p then return {Ready=true,New=true,Scopes={}} end
 local all,now=TradeStats.Empty(),TradeStats.Empty();local tiers,seen={},{}
 for _,id in ipairs(p.Ledger) do local a=self.Engine.Accounts[id]
  if a and self.Tiers[a.Tier] and not seen[id] then
   seen[id]=true;local t=tiers[a.Tier] or {Life=TradeStats.Empty(),Current=TradeStats.Empty()};tiers[a.Tier]=t
   TradeStats.Include(all,self.Engine,a);TradeStats.Include(t.Life,self.Engine,a)
   if self:Usable(a) then TradeStats.Include(now,self.Engine,a);TradeStats.Include(t.Current,self.Engine,a) end
  end
 end
 local scopes={{Key="ALL",Kind="All",Name="All Funded Accounts",Short="All funded",Life=TradeStats.Finish(all),Current=TradeStats.Finish(now)}}
 for _,id in ipairs(self.Order) do local t=tiers[id];if t then local info=self.Tiers[id];table.insert(scopes,{Key=id,Kind="Tier",Name=info.Name,Short=info.Short,Life=TradeStats.Finish(t.Life),Current=TradeStats.Finish(t.Current)}) end end
 return {Ready=true,Started=p.Tiers[self.Config.StarterTier]~=nil,Scopes=scopes,Tiers=count(tiers)}
end
function Funded:StatsKey(uid)
 local p=self:Profile(uid);if not p then return "new" end
 local parts={#p.Ledger}
 for _,id in ipairs(p.Ledger) do local a=self.Engine.Accounts[id];local s=a.Stats
  table.insert(parts,id..":"..a.Realized..":"..tostring(a.Locked)..":"..tostring(a.Retired)..":"..tostring(s and s.LastTradeId))
 end
 return table.concat(parts,"|")
end
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

-- Copy membership is by instance key, including multiple accounts of one tier.
function Funded:Plan(uid,owner)
 local p=self:Profile(uid)
 if not p or not p.Copy.Enabled then return nil end
 local lead=p.Instances[p.Copy.Leader]
 if not lead or lead.Account~=owner or not self:Usable(self.Engine.Accounts[owner]) then return nil end
 local followers,seen={},{}
 for _,key in ipairs(p.Copy.Followers) do
  local entry=p.Instances[key]
  if entry and entry.Account~=owner and not seen[entry.Account] and self:Usable(self.Engine.Accounts[entry.Account]) then
   seen[entry.Account]=true
   table.insert(followers,{Key=key,Id=entry.Account,Tier=self.Tiers[entry.Tier],Name=self:InstanceName(entry,true)})
  end
 end
 if #followers==0 then return nil end
 return {Leader=self.Tiers[lead.Tier],LeaderName=self:InstanceName(lead,true),Followers=followers,Sizing=p.Copy.Sizing}
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
 local function add(f,status,message) table.insert(items,{Key=f.Key,Name=f.Name or f.Tier.Short,Status=status,Message=message}) end
 for _,f in ipairs(plan.Followers) do
  local account=e.Accounts[f.Id] local action=req.Action
  if not ok then add(f,"Skipped","Lead request was rejected, so nothing was copied.")
  elseif account.Locked and (action=="Place" or action=="AmendProtection" or action=="AmendOrder") then
   add(f,"Skipped","Account blown. Tier access is permanent; get another account in the Shop.")
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
 local report={Leader=plan.LeaderName or plan.Leader.Short,Action=req.Action,Items=items,Copied=0,Skipped=0,Rejected=0,Total=#items,Sizing=plan.Sizing}
 for _,item in ipairs(items) do report[item.Status]+=1 end
 return report
end
return Funded
