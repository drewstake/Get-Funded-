-- Authoritative lifetime trading statistics, stored on each player account inside the exchange checkpoint.
-- A "completed trade" is one closing execution: exactly one row of the account's Trade History. A partial
-- close records the contracts it closed; the rest count when they close. A reversal counts its closing part.
-- Counters are updated by MarketEngine on the same execution that changes Balance/Realized, so they save and
-- restore atomically with the ledger. Display history is bounded (MaxAccountHistory); these counters are not.
local Stats={Version=1,EvenCents=0}
local EPS=0.005 -- half a cent: reconciliation tolerance for floating-point P&L

function Stats.New(origin,now)
 return {V=Stats.Version,Trades=0,Wins=0,Losses=0,Even=0,Gains=0,Loss=0,Best=nil,Worst=nil,LastTradeId=0,
  UntrackedNet=0,UntrackedTrades=0,CountUnknown=false,Origin=origin or "Live",Since=now}
end
-- Classify by the cent: a result that rounds to $0.00 is break-even. Sums use the exact values so that
-- Gains - Loss equals the ledger's realized total.
function Stats.Add(s,row)
 local pnl=row.Pnl or 0
 local cents=math.round(pnl*100)
 s.Trades+=1
 if cents>Stats.EvenCents then s.Wins+=1 elseif cents<-Stats.EvenCents then s.Losses+=1 else s.Even+=1 end
 if pnl>0 then s.Gains+=pnl elseif pnl<0 then s.Loss-=pnl end
 if s.Best==nil or pnl>s.Best then s.Best=pnl end
 if s.Worst==nil or pnl<s.Worst then s.Worst=pnl end
 if type(row.TradeId)=="number" and row.TradeId>s.LastTradeId then s.LastTradeId=row.TradeId end
end
function Stats.Tracked(s) return s.Gains-s.Loss end

-- Depletion is recorded per attempt, once. New executions set Depleted when the engine latches Locked at
-- $0 equity. Saved attempts from before this marker existed are classified from their final state.
function Stats.MarkDepletion(engine,a)
 if a.Depleted or a.Breached or not a.Locked or not a.Player then return end
 local equity=engine:Summary(a).Equity
 -- Checkpoint v3 reopened every positive-equity account that older loss rules had locked, so a current
 -- (not retired) locked account is depleted. A retired attempt still holding most of its capital was
 -- restarted under the earlier loss-limit rules and is reported separately, not as blown.
 if equity<=0 or not a.Retired or a.Balance<=a.Base*0.5 then a.Depleted=true
 else a.Breached="Earlier loss limit" end
end

-- Idempotent migration + drift repair. Safe to call on every restore.
--  * Accounts without Stats are rebuilt from their saved Trade History. When the rows reconcile with the
--    ledger (realized total, and the completed-trade counter when present) and the history was never trimmed,
--    the rebuild is complete ("Recovered"). Otherwise the unmatched part is kept as an untracked remainder
--    ("Partial") so Net realized still equals the ledger, and the UI labels the breakdown period.
--  * Accounts with Stats pick up any retained rows newer than LastTradeId (e.g. written by an older server
--    build), and any remaining mismatch is moved into the untracked remainder. Nothing is ever counted twice.
function Stats.Reconcile(engine,a,now)
 if not a.Player then return nil end
 local max=engine.Config.MaxAccountHistory or 60
 local rows=a.History or {}
 local s=a.Stats local fresh=type(s)~="table" or s.V~=Stats.Version
 if fresh then s=Stats.New("Recovered",now) a.Stats=s end
 -- History is newest first. Skip the scan when the newest row is already counted.
 local newest=rows[1]
 if fresh or (newest and type(newest.TradeId)=="number" and newest.TradeId>s.LastTradeId) then
  for i=#rows,1,-1 do
   local h=rows[i]
   if fresh or (type(h.TradeId)=="number" and h.TradeId>s.LastTradeId) then Stats.Add(s,h) end
  end
 end
 local gap=a.Realized-(Stats.Tracked(s)+s.UntrackedNet)
 local ledger=a.CompletedTrades
 if fresh then
  local trimmed=#rows>=max
  local countKnown=(ledger==nil and not trimmed) or ledger==s.Trades
  if math.abs(gap)<EPS and countKnown then
   s.Origin=#rows>0 and "Recovered" or "Live"
   -- The completed-trade counter predates some saves; a complete rebuild makes it exact.
   if ledger==nil and s.Trades>0 then a.CompletedTrades=s.Trades end
  else
   s.Origin="Partial" s.PartialSince=now
   s.UntrackedNet=gap
   s.UntrackedTrades=math.max(0,(ledger or #rows)-s.Trades)
   -- A counter that started from an already-trimmed history can itself undercount. Say so.
   s.CountUnknown=trimmed and ledger~=s.Trades
  end
 else
  if math.abs(gap)>=EPS then s.UntrackedNet+=gap s.Origin="Partial" s.PartialSince=s.PartialSince or now end
  local counted=s.Trades+s.UntrackedTrades
  if ledger and ledger>counted then s.UntrackedTrades+=ledger-counted s.Origin="Partial" s.PartialSince=s.PartialSince or now end
 end
 Stats.MarkDepletion(engine,a)
 return s
end

-- Aggregation used by every Stats scope. Open P&L comes from the live engine summary of open positions.
function Stats.Empty()
 return {Attempts=0,Blown=0,Breached=0,Trades=0,Wins=0,Losses=0,Even=0,Gains=0,Loss=0,Net=0,Open=0,
  UntrackedNet=0,UntrackedTrades=0,CountUnknown=false,Partial=false,Recovered=false,Since=nil}
end
function Stats.Include(agg,engine,a)
 local s=a.Stats or Stats.Reconcile(engine,a,os.time())
 agg.Attempts+=1
 if a.Depleted then agg.Blown+=1 elseif a.Breached then agg.Breached+=1 end
 for _,k in ipairs({"Trades","Wins","Losses","Even","Gains","Loss","UntrackedNet","UntrackedTrades"}) do agg[k]+=s[k] end
 agg.Net+=a.Realized
 if not a.Retired then agg.Open+=engine:Summary(a).Unrealized end
 if s.Best~=nil and (agg.Best==nil or s.Best>agg.Best) then agg.Best=s.Best end
 if s.Worst~=nil and (agg.Worst==nil or s.Worst<agg.Worst) then agg.Worst=s.Worst end
 if s.Origin=="Partial" then
  agg.Partial=true agg.CountUnknown=agg.CountUnknown or s.CountUnknown
  if s.PartialSince and (agg.Since==nil or s.PartialSince<agg.Since) then agg.Since=s.PartialSince end
 elseif s.Origin=="Recovered" then agg.Recovered=true end
 return agg
end
-- Derived values, computed once on the server so every client shows the same numbers.
function Stats.Finish(agg)
 if math.abs(agg.UntrackedNet)<EPS then agg.UntrackedNet=0 end
 agg.Total=agg.Net+agg.Open
 agg.WinRate=agg.Trades>0 and agg.Wins/agg.Trades or nil
 agg.AllTrades=agg.Trades+agg.UntrackedTrades
 if not agg.CountUnknown and agg.AllTrades>0 then agg.Average=agg.Net/agg.AllTrades agg.AverageScope="All"
 elseif agg.Trades>0 then agg.Average=(agg.Gains-agg.Loss)/agg.Trades agg.AverageScope="Tracked" end
 return agg
end
return Stats
