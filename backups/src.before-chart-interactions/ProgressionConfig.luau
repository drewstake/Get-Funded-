-- Funded-account ladder. Shared with clients for display only; MarketServer enforces every rule.
-- Change tiers here. Keep Size and Unlock ascending, and keep Unlock = 0 only for the starter tier.
-- Unlock values are lifetime NET REALIZED profit across the player's funded accounts (closed trades only).
-- Starting balances, open P&L and legacy practice accounts never count toward unlocks.
return {
 StarterTier="F5K",
 Tiers={
  {Id="F5K", Short="$5K", Name="$5K Funded", Size=5000, Unlock=0, LossLimit=500, MaxContracts=5},
  {Id="F10K", Short="$10K", Name="$10K Funded", Size=10000, Unlock=300, LossLimit=800, MaxContracts=10},
  {Id="F25K", Short="$25K", Name="$25K Funded", Size=25000, Unlock=1500, LossLimit=1500, MaxContracts=20},
  {Id="F50K", Short="$50K", Name="$50K Funded", Size=50000, Unlock=4000, LossLimit=2500, MaxContracts=30},
  {Id="F100K", Short="$100K", Name="$100K Funded", Size=100000, Unlock=10000, LossLimit=4000, MaxContracts=40},
 },
 -- Fraction of equity each funded account may commit as simulated margin.
 MarginUse=0.8,
 -- A breached account (loss allowance used up) can restart with fresh capital. Its realized loss stays
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
