-- Funded-account ladder. Shared with clients for display only; MarketServer enforces every rule.
-- Change tiers here. Keep Size and Unlock ascending, and keep Unlock = 0 only for the starter tier.
-- Unlock values are NET REALIZED profit across the player's funded accounts (closed trades only).
-- Starting balances, open P&L, legacy practice accounts and blown-account losses never count toward unlocks.
return {
 Version=3,
 CompletionGoal=78000,
 LegacyUnlocks={F5K=0,F10K=300,F25K=1500,F50K=4000,F100K=10000},
 StarterTier="F5K",
 Tiers={
  {Id="F5K", Short="$5K", Name="$5K Funded", Size=5000, Unlock=0, Price=2000, LossLimit=5000, MaxContracts=5},
  {Id="F10K", Short="$10K", Name="$10K Funded", Size=10000, Unlock=3000, Price=5000, LossLimit=10000, MaxContracts=10},
  {Id="F25K", Short="$25K", Name="$25K Funded", Size=25000, Unlock=8000, Price=15000, LossLimit=25000, MaxContracts=25},
  {Id="F50K", Short="$50K", Name="$50K Funded", Size=50000, Unlock=18000, Price=35000, LossLimit=50000, MaxContracts=50},
  {Id="F100K", Short="$100K", Name="$100K Funded", Size=100000, Unlock=38000, Price=75000, LossLimit=100000, MaxContracts=100},
 },
 -- Stored on accounts for compatibility only: order size is limited by MaxContracts, never by margin.
 MarginUse=0.8,
 -- No usable accounts: a free $5K restart resets only the unearned stage. Tier access and history are permanent.
 AllowRestart=true,
 CopyTrading={
  MinAccounts=2, -- introduced after the player activates a second funded account
  MaxFollowers=20,
  DefaultSizing="Same", -- "Same" copies the lead quantity; "Proportional" scales by account size
 },
 -- Server-enforced limits on creating funded accounts. State is saved in each player's profile inside the
 -- exchange checkpoint, so reconnecting, new request ids or new instance keys never restore a budget.
 -- Times are real seconds of live exchange time (converted with MarketConfig.SimulationSpeed; they do not
 -- elapse while the exchange is paused). Set a value to 0 to disable that particular limit.
 ResetLimits={
  CooldownSeconds=30, -- minimum gap between two voluntary resets of a healthy free $5K account
  Burst=5,            -- free resets/restarts (healthy or after a blown account) usable back to back
  RefillSeconds=720,  -- one free reset/restart credit returns every 12 minutes (5 per hour sustained)
 },
 PurchaseLimits={
  Burst=3,            -- new Shop purchases usable back to back (replays of a saved receipt are free)
  RefillSeconds=60,   -- one purchase credit returns every minute
 },
 AccountLimits={
  MaxRetained=64,     -- hard ceiling on retained funded records per player (usable, finished and archives)
  CompactAbove=16,    -- above this, finished attempts are folded into one archive record per tier
  KeepFinished=4,     -- the newest finished attempts always stay individually visible
  ArchiveRecent=20,   -- per-archive summary rows kept for the most recently folded attempts
  -- Every funded record in the one shared exchange checkpoint (all players, archives included). A secondary
  -- bound; WorldConfig.CapacityFraction pauses new accounts earlier if the saved checkpoint grows large.
  MaxExchangeAccounts=20000,
 },
}
