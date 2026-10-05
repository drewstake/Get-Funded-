from pathlib import Path
import shutil
root=Path.cwd()
backup=root/'backups/starting-balance-20261001'
out=root/'output/starting-balance-20261001'
out.mkdir(parents=True,exist_ok=True)
files=['src/ProgressionConfig.luau','src/FundedAccounts.luau','src/TerminalUI.luau','src/ProgressView.luau','src/MarketServer.server.luau','src/MarketEngine.luau','src/MarketConfig.luau','src/SingleAccountTests.luau','src/TradeLimitsTests.luau','tools/ValidateProgressRedesign.luau']
for name in files+['Get Funded!.rbxl']:
    dest=backup/name
    dest.parent.mkdir(parents=True,exist_ok=True)
    if not dest.exists(): shutil.copy2(root/name,dest)
def change(name,replacements):
    p=root/name;s=p.read_text(encoding='utf-8')
    for a,b in replacements:
        assert a in s,(name,a)
        s=s.replace(a,b)
    p.write_text(s,encoding='utf-8',newline='\n')
change('src/ProgressionConfig.luau',[
 ('StartingBalance=5000','StartingBalance=10000'),
 ('  {Id="Balance10K",Name="Grow your balance to $10,000",Kind="Balance",Goal=10000', '  -- Retain the saved award ID so existing Skilled Trader titles stay earned.\n  {Id="Balance10K",Name="Grow your balance to $15,000",Kind="Balance",Goal=15000'),
 ('Profit=20000','Profit=15000'),('Profit=45000','Profit=40000'),('Profit=95000','Profit=90000')])
change('src/FundedAccounts.luau',[
 ('c.StartingBalance==5000','type(c.StartingBalance)=="number" and c.StartingBalance>0 and c.StartingBalance<math.huge and c.StartingBalance%1==0'),
 ('Rule="5000 + selected','Rule=tostring(self.Config.StartingBalance).." + selected'),
 ('Your $5,000','Your $10,000'),('Fresh start: $5,000','Fresh start: $10,000')])
change('src/TerminalUI.luau',[('$5,000','$10,000'),('$5K','$10K')])
change('src/ProgressView.luau',[('options.StartingBalance or 5000','options.StartingBalance or require(script.Parent.ProgressionConfig).StartingBalance')])
change('src/MarketServer.server.luau',[('$5,000','$10,000')])
for name in ['src/MarketEngine.luau','src/MarketConfig.luau']:
    change(name,[('$5K','$10K')])
change('src/SingleAccountTests.luau',[
 ('$5000 account','$10000 account'),('Balance==5000','Balance==10000'),
 ('sum.Equity==5500','sum.Equity==10500'),('Balance==5500','Balance==10500'),
 ('b.Last-=400','b.Last-=800'),('StopTicks=800','StopTicks=1600'),
 ('result(e,id,-5500)','result(e,id,-10500)'),('scope.Life.Net==-5000','scope.Life.Net==-10000'),
 ('result(e,id,-5000)','result(e,id,-10000)'),
 ('a.Balance==7500','a.Balance==12500'),
 ('e:AddAccount("player:101:F10K:1",10000,10','e:AddAccount("player:101:F25K:1",25000,25'),
 ('a.Tier="F10K";result(e,a.Id,-6000)','a.Tier="F25K";result(e,a.Id,-11000)'),
 ('==-6000','==-11000'),
 ('result(e,f:Owner("101"),-5500)','result(e,f:Owner("101"),-10500)'),('Cents==-500000','Cents==-1000000')])
change('src/TradeLimitsTests.luau',[
 ('a.Realized=-4000 -- a $5K account that has lost $4,000','a.Realized=1000-a.Base -- a starter account reduced to $1,000'),
 ('a.Realized=-5000','a.Realized=-a.Base'),('a.Balance=5000;a.Realized=0','a.Balance=a.Base;a.Realized=0'),('$5K','$10K')])
change('tools/ValidateProgressRedesign.luau',[('Balance=5000','Balance=ladder.StartingBalance')])
print('Updated starting balance and related UI, progression, and fixtures.')
