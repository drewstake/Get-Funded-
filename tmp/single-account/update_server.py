from pathlib import Path
p=Path('src/MarketServer.server.luau');s=p.read_text(encoding='utf-8')
s=s.replace('-- A malformed ladder must stop the server, not corrupt saved profiles.','-- Fail closed on invalid progression configuration.')
s=s.replace('local allowed={Place=true,Cancel=true,Close=true,Subscribe=true,Account=true,AmendProtection=true,AmendOrder=true,\n Start=true,Activate=true,Restart=true,Purchase=true,Copy=true,Flag=true,Stats=true}', 'local allowed={Place=true,Cancel=true,Close=true,Subscribe=true,AmendProtection=true,AmendOrder=true,\n Start=true,Restart=true,Flag=true,Stats=true}')
s=s.replace(' "Key","Tier","PurchaseSequence","Enabled","Leader","Followers","Sizing","Stage"}', ' "Stage"}')
a=s.index(' elseif req.Action=="Activate" then');b=s.index(' elseif req.Action=="Restart" then',a);s=s[:a]+s[b:]
s=s.replace('funded:Restart(uid,req.Tier)','funded:Restart(uid,req.ExpectedAccount)')
a=s.index(' elseif req.Action=="Copy" then');b=s.index(' elseif req.Action=="Flag" then',a);s=s[:a]+s[b:]
s=s.replace(' local plan=funded:Plan(uid,owner)\n local context=plan and funded:Context(owner,req)\n','')
s=s.replace(' local copies=plan and funded:Mirror(plan,req,ok,result,context)\n','')
s=s.replace(' if copies and ok then message..=string.format(" · copied %d/%d",copies.Copied,copies.Total) end\n','')
s=s.replace('{Kind=req.Action,Copies=copies}', '{Kind=req.Action}')
s=s.replace('local compacted=0','')
s=s.replace('funded:Evaluate(uid) if compacted<4 and funded:Compact(uid)>0 then compacted+=1 end','funded:Evaluate(uid)')
s=s.replace('Start a funded account to trade.','Your trading account is loading.')
s=s.replace('Review the selected account and retry.','Review your current run and retry.')
s=s.replace('-- The trading account comes from the player\'s saved funded profile. New players have no account until\n-- they press Start, so joining never creates a starter (or duplicate) account.', '-- Joining idempotently creates one $5,000 account for a new player.')
s=s.replace('-- Trading. The lead order executes first; copies then run through the same engine calls.', '-- Trading owner and current run token are resolved only on the server.')
p.write_text(s,encoding='utf-8')
p=Path('src/MarketClient.luau');s=p.read_text(encoding='utf-8').replace('Progression.Tiers[1].Size','Progression.StartingBalance').replace('Progression.Tiers[1].LossLimit','Progression.StartingBalance')
a=s.index('-- Funded-account lifecycle.');b=s.index('-- orderType:',a)
s=s[:a]+'''-- Lifecycle requests always include ExpectedAccount through Send.
function Session:Start() return self:Send("Start",{}) end
function Session:Restart() return self:Send("Restart",{}) end
function Session:Flag(stage) return self:Send("Flag",{Stage=stage}) end
function Session:RefreshStats() return self:Send("Stats",{}) end
'''+s[b:];p.write_text(s,encoding='utf-8')
p=Path('src/LeaderboardRanking.luau');s=p.read_text(encoding='utf-8');a=s.index(' for _,id in ipairs(p.Ledger)');b=s.index(' return row',a)
s=s[:a]+''' local trades=funded:_counts(p)
 row.Eligible=trades>0
 row.Tier=p.Rank or "New Trader";row.TierSize=0
'''+s[b:];p.write_text(s,encoding='utf-8')
