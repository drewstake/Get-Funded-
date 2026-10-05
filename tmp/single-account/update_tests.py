from pathlib import Path
# The removed product model's tests stay in source backups for historical reproduction.
obsolete=['FundedTests','DepletionTests','ProgressionTests','ReearnTests','PermanentShopTests','StatsTests','LeaderboardTests']
dest=Path('tools/legacy-tests/pre-single-account');dest.mkdir(parents=True,exist_ok=True)
for name in obsolete:
 p=Path('src')/(name+'.luau')
 if p.exists(): p.replace(dest/p.name)
p=Path('src/MarketServer.server.luau');s=p.read_text(encoding='utf-8')
s='\n'.join(line for line in s.splitlines() if not any('command=="'+n+'"' in line for n in obsolete))+'\n'
s=s.replace('  if command=="SecurityTests"', '  if command=="SingleAccountTests"then return require(script.Parent.SingleAccountTests).Run()end\n  if command=="SecurityTests"')
s=s.replace('-- Compaction is spread out: at most four oversized profiles are folded per maintenance tick.','-- Progress from offline protective fills is evaluated on the same saved profile.')
p.write_text(s,encoding='utf-8')
p=Path('src/WorldTests.luau');s=p.read_text(encoding='utf-8')
s=s.replace('local Tests={}', 'local F=require(script.Parent.FundedAccounts)\nlocal L=require(game.ReplicatedStorage.MarketReign.ProgressionConfig)\nlocal Tests={}')
s=s.replace('e:AddAccount("player:test:50000",50000,40,0.8,true)', 'local f=F.new(e,L,Default);f:Start("test");local id=f:Owner("test")')
s=s.replace('"player:test:50000"','id')
s=s.replace('local player=e:AddAccount("player:w:5000",5000,5,0.8,true)', 'local f=F.new(e,L,Default);f:Start("w");local player=e.Accounts[f:Owner("w")]')
s=s.replace('a.Engine:AddAccount("player:7:50000",50000,40,0.8,true)', 'local f=F.new(a.Engine,L,c);f:Start("7");local id=f:Owner("7")')
s=s.replace('"player:7:50000"','id')
p.write_text(s,encoding='utf-8')
p=Path('src/TradeLimitsTests.luau');s=p.read_text(encoding='utf-8');s=s.replace('local Ladder=require(game.ReplicatedStorage.MarketReign.ProgressionConfig)', 'local Ladder=table.clone(require(game.ReplicatedStorage.MarketReign.ProgressionConfig))\n-- One account limit; the remaining suite covers exchange sizing and protection boundaries.\nLadder.Tiers={{Id="Single",Size=Ladder.StartingBalance,MaxContracts=Ladder.MaxContracts,Short="Trading account"}}')
p.write_text(s,encoding='utf-8')
# Retain unrelated security regressions; deleted shop/reset model is covered by SingleAccountTests.
p=Path('src/SecurityTests.luau');s=p.read_text(encoding='utf-8');original=s
(dest/'SecurityTests.luau').write_text(original,encoding='utf-8')
a=s.index('function Tests.Run()');b=s.index(' ------------------------------------------------------------------------------------------ F3 replies',a)
start='''function Tests.Run()
 local report={}
 local function test(name,fn)local ok,value=pcall(fn);table.insert(report,{Name=name,Passed=ok,Detail=ok and (value or "Passed") or tostring(value)})end
'''
s=s[:a]+start+s[b:]
s=s.replace('equal(f:Profile("q1").WalletCents,0,"wallet credited")','assert(f:Profile("q1").WalletCents==nil,"Wallet returned")')
p.write_text(s,encoding='utf-8')
p=Path('src/WorldService.luau');s=p.read_text(encoding='utf-8')
a=s.index('-- Freeze the exchange around a purchase');b=s.index('function World:Maintain()',a);s=s[:a]+s[b:]
s=s.replace('  self.Uncommitted={} self.TransactionBusy=false self.PendingPurchase=nil\n','')
s=s.replace('self.Closing or self.TransactionBusy or','self.Closing or')
s=s.replace(' if self.TransactionBusy then return "Saving account purchase…" end\n','')
s=s.replace(' -- Receipts created before this capture become durable only if this exact commit succeeds.\n local covered=table.clone(self.Uncommitted or {})\n','')
a=s.index(' if ok and self.Uncommitted');b=s.index(' if not ok then self.LastError',a);s=s[:a]+s[b:]
a=s.index('   self.TransactionBusy=false');b=s.index('   self.Engine=nil',a);s=s[:a]+s[b:]
s=s.replace(' self.Uncommitted={}','')
s=s.replace('if kind=="Start" or kind=="Activate" then','if kind=="Start" then')
p.write_text(s,encoding='utf-8')
p=Path('tools/RefreshStudioPreview.luau');s=p.read_text(encoding='utf-8').replace('local ladder=require(shared.ProgressionConfig);local starter=ladder.Tiers[1]','local ladder=require(shared.ProgressionConfig)');p.write_text(s,encoding='utf-8')
p=Path('src/WorldConfig.luau');s=p.read_text(encoding='utf-8');a=s.index(' -- Minimum gap between two NEW Shop');b=s.index(' -- Per-connection acknowledgement',a);s=s[:a]+s[b:];s=s.replace('Free resets/restarts and Shop purchases','New profiles and free restarts').replace('and earned tier activations','');p.write_text(s,encoding='utf-8')
p=Path('src/TerminalUI.luau');s=p.read_text(encoding='utf-8').replace('(accountName().."  ⌄")','"Get Funded!"').replace('-- Trading header: active account (tap to switch) and the next objective with a slim progress line.','-- Trading header and next goal. Help explains balance and open results.');p.write_text(s,encoding='utf-8')
