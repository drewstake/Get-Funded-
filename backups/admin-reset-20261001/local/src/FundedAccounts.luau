-- Single-account lifecycle; historical module name keeps place references stable.
-- All grants, archives and rewards share the exchange's fenced checkpoint.
local Funded={} Funded.__index=Funded
local Rules=require(game.ReplicatedStorage.MarketReign.ProgressionRules)
local TradeStats=require(script.Parent.TradeStats)
local Protection=require(game.ReplicatedStorage.MarketReign.TradeProtection)
local function clone(v) if type(v)~="table" then return v end local r={} for k,x in pairs(v) do r[k]=clone(x) end return r end
local function keys(t) local r={} for k in pairs(t or {}) do table.insert(r,k) end table.sort(r) return r end
function Funded.Validate(c)
 assert(c.Version==4 and type(c.StartingBalance)=="number" and c.StartingBalance>0 and c.StartingBalance<math.huge and c.StartingBalance%1==0,"Invalid single-account configuration")
 assert(type(c.MinimumContracts)=="number" and c.MinimumContracts>=1 and c.MinimumContracts<math.huge and c.MinimumContracts%1==0
  and type(c.BalancePerContract)=="number" and c.BalancePerContract>0 and c.BalancePerContract<math.huge,"Invalid contract limit configuration")
 local seen={} for _,m in ipairs(c.Milestones) do assert(not seen[m.Id] and m.Goal>0 and m.Title,"Invalid milestone");seen[m.Id]=true end
end
function Funded.Key(uid) return tostring(uid) end
function Funded:Profile(uid) return self.Engine.Profiles[uid] end
function Funded:_touch(p) p.Revision=(p.Revision or 0)+1 end
function Funded:Owner(uid) local p=self:Profile(uid);return p and p.Account end
function Funded:Usable(a) return a and not (a.Locked or a.Depleted or a.Retired or a.LegacyRetired) end
function Funded:_new(uid)
 local p={V=4,Run=0,Ledger={},Tiers={},Awards={},Titles={},Rank="New Trader",Tutorial="Pending",Revision=1,
  Created=self.Engine.Time,Events={},RunHistory={},Limits={}}
 self.Engine.Profiles[uid]=p return p
end
function Funded:_open(uid,p,balance,source)
 p.Run+=1
 local id="player:"..uid..":single:"..p.Run
 assert(not self.Engine.Accounts[id],"Duplicate run identity")
 local a=self.Engine:AddAccount(id,balance,self.Config.MinimumContracts,self.Config.MarginUse,true)
 a.ProfileId=uid;a.Group="player:"..uid;a.SingleAccount=true;a.Run=p.Run
 p.Account=id;p.Active=id;p.RunStartBalance=balance;p.RunSource=source;p.FailureNotice=nil
 table.insert(p.Ledger,id);self:_touch(p);return a
end
function Funded:CreationAllowed(kind)
 if (self.Capacity and not self.Capacity(kind)) or #self.Engine.AccountOrder>=self.Config.AccountLimits.MaxExchangeAccounts then
  return false,"The exchange is at capacity. Please try again later."
 end
 return true
end
-- Run before the first durable V8 checkpoint, without interleaved client or market steps.
-- Close through Submit so the house counter-entry, cash flow and inventory stay balanced.
function Funded:Migrate(p,uid)
 if p.V==4 then
  assert(p.Account and self.Engine.Accounts[p.Account] and p.Awards and p.Ledger,"Invalid single-account profile")
  self.Engine:ContractLimit(self.Engine.Accounts[p.Account])
  self:Evaluate(uid,true)
  return
 end
 assert((p.V or 1)<4,"Unsupported player profile version")
 local e=self.Engine;local original=clone(p);local ids,seen={},{}
 local function retain(id)
  assert(e.Accounts[id] and e.Accounts[id].Player,"Missing historical player account")
  if not seen[id] then seen[id]=true;table.insert(ids,id) end
 end
 for _,id in ipairs(p.Ledger or {}) do retain(id) end
 local prefix="player:"..uid..":"
 for _,id in ipairs(e.AccountOrder) do if e.Accounts[id].Player and id:sub(1,#prefix)==prefix then retain(id) end end
 local active=(p.Instances or {})[p.Active] or (p.Tiers or {})[p.Active]
 local selected=type(active)=="table" and active.Account or nil
 if not seen[selected] or not self:Usable(e.Accounts[selected]) then
  selected=nil
  for i=#ids,1,-1 do local a=e.Accounts[ids[i]];if self:Usable(a) and not a.Archive then selected=ids[i];break end end
 end
 local evidence={}
 for _,id in ipairs(ids) do
  local a=e.Accounts[id]
  evidence[id]={Base=a.Base,Balance=a.Balance,Realized=a.Realized,Positions=clone(a.Positions),Orders={}}
  for _,orderId in ipairs(keys(a.OpenOrders)) do table.insert(evidence[id].Orders,clone(e.Orders[orderId])) end
  e:CancelAll(id)
  for _,contract in ipairs(keys(a.Positions)) do
   local pos=a.Positions[contract];pos.Stop=nil;pos.Target=nil;pos.Triggered="Single account migration"
   while a.Positions[contract] do
    local held=a.Positions[contract]
    local ok,result=e:Submit(id,{Contract=contract,Direction=-held.Direction,Quantity=math.min(held.Quantity,e.Config.MaxPlayerQuantity),Type="Market",ReduceOnly=true},{})
    assert(ok and result.Filled>0,"Could not settle historical position")
   end
  end
  TradeStats.Reconcile(e,a,os.time());a.Retired=true;a.LegacyRetired=true;a.Locked=true;a.MigrationArchived=true
 end
 local pending={};for _,v in ipairs(e.PendingStops) do if not seen[v.Owner] then table.insert(pending,v) end end;e.PendingStops=pending
 local carry=selected and e.Accounts[selected].Realized or 0
 local balance=selected and self.Config.StartingBalance+carry or (#ids==0 and self.Config.StartingBalance or 0)
 local q=self:_new(uid);q.Ledger=ids;q.LegacyProfile=original
 q.Migration={Version=1,At=e.Time,Selected=selected,CarryProfit=carry,Balance=balance,Accounts=evidence,
  Rule=tostring(self.Config.StartingBalance).." + selected account net result after closing; no combined balances or wallet conversion"}
 q.PlayerName=p.PlayerName;q.DisplayName=p.DisplayName
 q.Awards=clone(original.Awards or {});q.Titles=clone(original.Titles or {})
 for _,tier in ipairs({"F5K","F10K","F25K","F50K","F100K"}) do
  if (original.Tiers or {})[tier] then table.insert(q.Titles,"Legacy "..tier:sub(2).." Trader") end
 end
 if original.Completion then table.insert(q.Titles,"Legacy Top Tier Complete") end
 local a=self:_open(uid,q,balance,"Migration")
 if balance<=0 then a.Locked=true;a.Depleted=true;a.DepletedAt=e.Time end
 -- Carry is capital on the new run. Its profit is already on the old ledger, counted once.
 self:Evaluate(uid,true)
end
function Funded.new(engine,config,market,options)
 Funded.Validate(config);engine.Profiles=engine.Profiles or {}
 local self=setmetatable({Engine=engine,Config=config,Market=market or engine.Config,Capacity=options and options.Capacity},Funded)
 engine.OnFundedClose=nil
 for _,id in ipairs(engine.AccountOrder) do
  local a=engine.Accounts[id];local uid=id:match("^player:([^:]+):")
  if a.Player and uid and not engine.Profiles[uid] then engine.Profiles[uid]={V=1,Tiers={},Ledger={}} end
 end
 for _,uid in ipairs(keys(engine.Profiles)) do self:Migrate(engine.Profiles[uid],uid) end
 engine.OnFundedClose=function(a,row)
  local p=a.ProfileId and self:Profile(a.ProfileId)
  if p and p.Account==a.Id then
   local earned=self:Evaluate(a.ProfileId,nil,true)
   local view=self:View(a.ProfileId);p.Events=p.Events or {}
   table.insert(p.Events,{Kind="TradeClosed",Account=a.Id,TradeId=row.TradeId,Reason=row.Reason,
    Pnl=row.Pnl,Balance=a.Balance,Next=view.Next,Run=p.Run,Rewards=earned})
   while #p.Events>16 do table.remove(p.Events,1) end
   self:_touch(p)
  end
 end
 return self
end
function Funded:Join(uid)
 local p=self:Profile(uid);if not p then self:Start(uid);p=self:Profile(uid) end;return p
end
function Funded:Start(uid)
 if self:Profile(uid) then return true,"Your trading account is ready.",false end
 local ok,reason=self:CreationAllowed("Start");if not ok then return false,reason end
 self:_open(uid,self:_new(uid),self.Config.StartingBalance,"Start")
 self:Evaluate(uid,true)
 return true,"Your $10,000 in-game trading balance is ready.",true
end
function Funded:Earned(p)
 local total=0 for _,id in ipairs(p.Ledger) do total+=self.Engine.Accounts[id].Realized end return total
end
function Funded:_counts(p)
 local trades,wins=0,0
 for _,id in ipairs(p.Ledger) do local a=self.Engine.Accounts[id];local s=a.Stats or TradeStats.Reconcile(self.Engine,a,os.time())
  trades+=(s.Trades or 0)+(s.UntrackedTrades or 0);wins+=s.Wins or 0
 end
 return trades,wins
end
function Funded:_metric(p,m,net,trades,wins)
 return Rules.Metric(m,net,trades,wins),m.Goal
end
function Funded:Evaluate(uid,silent,closingTrade)
 local p=self:Profile(uid);if not p then return end
 local a=self.Engine.Accounts[p.Account];assert(a,"Missing single account")
 local migrated=Rules.Normalize(p,self.Engine.Time)
 local net=self:Earned(p);local trades,wins=self:_counts(p)
 p.ProfitHigh=math.max(p.ProfitHigh or 0,net)
 local earned={}
 for _,m in ipairs(self.Config.Milestones)do
  -- Saved high-water profit is authoritative historical evidence for newly introduced titles.
  local value=self:_metric(p,m,migrated and p.ProfitHigh or net,trades,wins)
  if not p.Awards[m.Id] and value+1e-6>=m.Goal then
   p.Awards[m.Id]={At=self.Engine.Time,Net=net,Run=p.Run,Title=m.Title}
   table.insert(earned,m.Title)
   if not silent and not closingTrade then p.Events=p.Events or {};table.insert(p.Events,{Kind="Milestone",Name=m.Name,Title=m.Title,Id=m.Id})end
   self:_touch(p)
  end
 end
 p.Titles=Rules.Titles(p)
 local previous,index=Rules.Rank(p.RankId);index=index or 1
 p.RankAwards=p.RankAwards or {}
 for i,r in ipairs(self.Config.Ranks)do
  if i<=index or Rules.Qualifies(r,migrated and p.ProfitHigh or net,trades,wins)then
   if not p.RankAwards[r.Id]then p.RankAwards[r.Id]={At=self.Engine.Time,Net=net};self:_touch(p)end
   index=math.max(index,i)
  end
 end
 local rank=self.Config.Ranks[index];p.RankId=rank.Id;p.Rank=rank.Name
 if previous and previous.Id~=rank.Id and not silent and not closingTrade then
  p.Events=p.Events or {};table.insert(p.Events,{Kind="RankUp",Id=rank.Id,Name=rank.Name})
 end
 if migrated then self:_touch(p)end
 if a.Depleted and p.FailureNotice~=p.Run then
  p.FailureNotice=p.Run;p.Events=p.Events or {}
  if not silent then table.insert(p.Events,{Kind="Depleted",Tier=a.Id,Event=tostring(p.Run),Name="Trading account"})end
  self:_touch(p)
 end
 return earned
end
function Funded:_credits(p)
 local state=p.Limits.Reset or {};local c=self.Config.ResetLimits
 return math.min(c.Burst,(state.Tokens or c.Burst)+math.max(0,self.Engine.Time-(state.At or self.Engine.Time))/(c.RefillSeconds*self.Market.SimulationSpeed))
end
function Funded:CanRestart(p)
 local a=self.Engine.Accounts[p.Account]
 return a.Depleted==true and not next(a.Positions) and not next(a.OpenOrders)
end
-- Completed runs are folded into one accounting record. Legacy migration records remain intact.
function Funded:_archiveRun(uid,p,a)
 assert(not next(a.Positions) and not next(a.OpenOrders),"Cannot archive exposure")
 local id="player:"..uid..":single-history";local archive=self.Engine.Accounts[id]
 if not archive then
  archive=self.Engine:AddAccount(id,0,0,0,true);archive.Retired=true;archive.Locked=true;archive.LegacyRetired=true
  archive.Archive={Attempts=0,Blown=0,Breached=0};table.insert(p.Ledger,id)
 end
 archive.Base+=a.Base;archive.Balance+=a.Balance;archive.Realized+=a.Realized;archive.CashFlow+=a.CashFlow
 archive.Archive.Attempts+=1;archive.Archive.Blown+=1
 archive.CompletedTrades=(archive.CompletedTrades or 0)+(a.CompletedTrades or 0);TradeStats.Merge(archive.Stats,a.Stats)
 for _,row in ipairs(a.History) do table.insert(archive.History,clone(row)) end
 table.sort(archive.History,function(x,y)return x.TradeId>y.TradeId end)
 while #archive.History>self.Engine.Config.MaxAccountHistory do table.remove(archive.History) end
 table.insert(p.RunHistory,1,{Run=p.Run,StartBalance=a.Base,FinalBalance=a.Balance,Net=a.Realized,ClosedAt=self.Engine.Time})
 while #p.RunHistory>32 do table.remove(p.RunHistory) end
 self.Engine.Accounts[a.Id]=nil;table.remove(self.Engine.AccountOrder,table.find(self.Engine.AccountOrder,a.Id))
 table.remove(p.Ledger,table.find(p.Ledger,a.Id))
 local pending={};for _,v in ipairs(self.Engine.PendingStops) do if v.Owner~=a.Id then table.insert(pending,v) end end;self.Engine.PendingStops=pending
end
function Funded:Restart(uid,expected)
 local p=self:Profile(uid);if not p then return false,"Wait for your account to load." end
 if expected~=p.Account then return false,"This restart is out of date. Review your current run." end
 if not self:CanRestart(p) then return false,"A free restart is available after equity reaches $0 and all positions close." end
 local credits=self:_credits(p)
 if credits<1 then return false,"Please wait before restarting again. Your history and rewards are safe." end
 local ok,reason=self:CreationAllowed("Restart");if not ok then return false,reason end
 self:_archiveRun(uid,p,self.Engine.Accounts[p.Account]);p.Limits.Reset={Tokens=credits-1,At=self.Engine.Time}
 self:_open(uid,p,self.Config.StartingBalance,"Restart")
 return true,"Fresh start: $10,000 in-game money. Your titles and lifetime results are kept."
end
function Funded:Flag(uid,stage)
 local p=self:Profile(uid);if not p then return false,"Wait for your account." end
 if stage~="TutorialDone" and stage~="TutorialSkipped" then return false,"Unknown tutorial step." end
 p.Tutorial=stage=="TutorialDone" and "Done" or "Skipped";self:_touch(p);return true,"Saved."
end
function Funded:TakeEvents(uid)
 local p=self:Profile(uid);if not p or not p.Events or #p.Events==0 then return nil end
 local events=p.Events;p.Events={};return events
end
function Funded:SetProtectionPreferences(uid,value)
 local p=self:Profile(uid);if not p then return false,"Wait for your account to load." end
 local nextValue=Protection.ValidatePreferences(value)
 if not nextValue then return false,"Enter valid stop-loss and take-profit amounts and switches." end
 if not p.ProtectionPreferences or not Protection.SamePreferences(p.ProtectionPreferences,nextValue)then
  p.ProtectionPreferences=nextValue;self:_touch(p)
 end
 return true,"Trade protection settings saved."
end
function Funded:View(uid)
 local p=self:Profile(uid);if not p then return {New=true,Revision=0} end
 local a=self.Engine.Accounts[p.Account];local sum=self.Engine:Summary(a);local net=self:Earned(p);local trades,wins=self:_counts(p)
 local failed=a.Depleted==true;local closing=next(a.Positions)~=nil or next(a.OpenOrders)~=nil
 local row={Key=a.Id,Name="Trading account",Short="Trading account",State="Active",Usable=not failed,Depleted=failed,Breached=failed,
  Closing=failed and closing,CanRestart=self:CanRestart(p),DepletionEvent=tostring(p.Run),Balance=a.Balance,Equity=sum.Equity,
  Unrealized=sum.Unrealized,Realized=a.Realized,Limit=self.Engine:ContractLimit(a),Size=a.Base,LossLimit=math.max(0,sum.Equity),Positions=sum.Count}
 local v={Revision=p.Revision,Started=true,Active=a.Id,ActiveName="Trading account",ActiveShort="Trading account",ActiveSize=a.Base,
  Run=p.Run,RunProfit=a.Realized,RunStartBalance=p.RunStartBalance,Earned=net,Open=sum.Unrealized,Balance=a.Balance,Equity=sum.Equity,
  ProtectionPreferences=Protection.Preferences(p.ProtectionPreferences),
  Rank=p.Rank,RankId=p.RankId,Trades=trades,Wins=wins,Titles=clone(p.Titles),Awards=clone(p.Awards),Tutorial=p.Tutorial,Accounts={row},CanRestart=row.CanRestart,
  ActiveCount=failed and 0 or 1,UsableCount=failed and 0 or 1,Failed=failed,Milestones={},Migrated=p.Migration~=nil}
 for _,m in ipairs(self.Config.Milestones) do
  local value,goal=self:_metric(p,m,net,trades,wins)
  local r={Key=m.Id,Badge=m.Badge,Name=m.Name,Short=m.Name,Title=m.Title,Kind=m.Kind,Goal=goal,Progress=math.min(value,goal),
   Remaining=math.max(0,goal-value),Earned=p.Awards[m.Id]~=nil}
  table.insert(v.Milestones,r);if not r.Earned and not v.Next then v.Next=clone(r) end
 end
 local rank,index=Rules.Rank(p.RankId)
 v.RankBadge=rank and rank.Badge;v.RankLevel=index;v.RankNext=index and clone(self.Config.Ranks[index+1])
 local _,title=Rules.Titles(p);v.Title=title and title.Title or (#p.Titles>0 and p.Titles[#p.Titles] or "Your story starts here")
 v.TitleId=title and title.Id;v.TitleBadge=title and title.Badge or 1
 v.Ranks={};for _,r in ipairs(self.Config.Ranks)do local item=clone(r);item.Earned=p.RankAwards[r.Id]~=nil;table.insert(v.Ranks,item)end
 v.Completed=v.Next==nil;return v
end
function Funded:Stats(uid)
 local p=self:Profile(uid);if not p then return {Ready=true,New=true,Scopes={}} end
 local all,current=TradeStats.Empty(),TradeStats.Empty()
 for _,id in ipairs(p.Ledger) do TradeStats.Include(all,self.Engine,self.Engine.Accounts[id]) end
 TradeStats.Include(current,self.Engine,self.Engine.Accounts[p.Account])
 return {Ready=true,Started=true,Run=p.Run,RunStartBalance=p.RunStartBalance,Scopes={
  {Key="ALL",Kind="All",Name="Trading history",Short="Trading history",Life=TradeStats.Finish(all),Current=TradeStats.Finish(current)}}}
end
function Funded:StatsKey(uid)
 local p=self:Profile(uid);if not p then return "new" end
 local a=self.Engine.Accounts[p.Account];return p.Revision..":"..a.Revision..":"..tostring(a.Depleted)
end
function Funded.Perform(engine,owner,req)
 local a=engine.Accounts[owner];if not a then return false,"Unknown account." end
 if req.Action=="Place" then return engine:Submit(owner,req)
 elseif req.Action=="AmendProtection" then return engine:AmendProtection(owner,req)
 elseif req.Action=="AmendOrder" then return engine:AmendOrder(owner,req)
 elseif req.Action=="Cancel" then
  if type(req.OrderId)~="number" then return false,"Unknown order." end
  if req.Protection then return engine:CancelProtection(owner,req.OrderId,req.Protection) end
  return engine:Cancel(owner,req.OrderId)
 elseif req.Action=="Close" then
  local p=a.Positions[req.Contract];if not p then return false,"No open position." end
  engine:CancelAll(owner,req.Contract);p.Triggered="Player close";p.Stop=nil;p.Target=nil
  return engine:Submit(owner,{Contract=req.Contract,Direction=-p.Direction,Quantity=math.min(p.Quantity,engine.Config.MaxPlayerQuantity),Type="Market",ReduceOnly=true})
 end
 return false,"Request rejected."
end
function Funded.Describe(result) return result.Filled>0 and string.format("Filled %d @ %.2f",result.Filled,result.Average) or result.Status end
return Funded
