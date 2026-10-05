-- Funded-account ladder. Shared with clients for display only; MarketServer enforces every rule.
-- Change tiers here. Keep Size and Unlock ascending, and keep Unlock = 0 only for the starter tier.
-- Unlock values are lifetime NET REALIZED profit across the player's funded accounts (closed trades only).
-- Starting balances, open P&L and legacy practice accounts never count toward unlocks.
return {
 Version=2,
 CompletionGoal=78000,
 LegacyUnlocks={F5K=0,F10K=300,F25K=1500,F50K=4000,F100K=10000},
 StarterTier="F5K",
 Tiers={
  {Id="F5K", Short="$5K", Name="$5K Funded", Size=5000, Unlock=0, LossLimit=5000, MaxContracts=5},
  {Id="F10K", Short="$10K", Name="$10K Funded", Size=10000, Unlock=3000, LossLimit=10000, MaxContracts=10},
  {Id="F25K", Short="$25K", Name="$25K Funded", Size=25000, Unlock=8000, LossLimit=25000, MaxContracts=20},
  {Id="F50K", Short="$50K", Name="$50K Funded", Size=50000, Unlock=18000, LossLimit=50000, MaxContracts=30},
  {Id="F100K", Short="$100K", Name="$100K Funded", Size=100000, Unlock=38000, LossLimit=100000, MaxContracts=40},
 },
 -- Fraction of equity each funded account may commit as simulated margin.
 MarginUse=0.8,
 -- A depleted account (equity at or below zero) can restart with fresh capital. Its realized loss stays
 -- in the lifetime net-profit total, so restarting never erases progress requirements.
 AllowRestart=true,
 -- Practice accounts created before the funded ladder existed. Kept and tradable, never counted.
 LegacyBases={50000,100000},
 LegacyTradable=true,
 CopyTrading={
  MinAccounts=2, -- introduced after the player activates a second funded account
  DefaultSizing="Same", -- "Same" copies the lead quantity; "Proportional" scales by account size
 },
}
