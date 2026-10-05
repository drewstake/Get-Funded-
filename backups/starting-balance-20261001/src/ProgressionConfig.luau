-- Permanent titles only: no deposits, purchases, or extra currency.
return {
 Version=4,StartingBalance=5000,MaxContracts=5,MarginUse=0.8,
 ResetLimits={Burst=5,RefillSeconds=720},AccountLimits={MaxExchangeAccounts=20000},
 Milestones={
  {Id="FirstTrade",Name="Close your first trade",Kind="Trades",Goal=1,Title="Trader"},
  {Id="FirstWin",Name="Close a profitable trade",Kind="Wins",Goal=1,Title="First Win"},
  {Id="Profit500",Name="Earn $500 net trading profit",Kind="Profit",Goal=500,Title="Rising Trader"},
  {Id="Balance10K",Name="Grow your balance to $10,000",Kind="Balance",Goal=10000,Profit=5000,Title="Skilled Trader"},
  {Id="Balance25K",Name="Grow your balance to $25,000",Kind="Balance",Goal=25000,Profit=20000,Title="Market Pro"},
  {Id="Balance50K",Name="Grow your balance to $50,000",Kind="Balance",Goal=50000,Profit=45000,Title="Market Master"},
  {Id="Balance100K",Name="Grow your balance to $100,000",Kind="Balance",Goal=100000,Profit=95000,Title="Get Funded Legend"},
 },
}
