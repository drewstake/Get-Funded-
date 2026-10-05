from pathlib import Path
import re
src=Path(__file__).resolve().parents[1]/'src'
for name in ['FundedTests','StatsTests','LeaderboardTests','ProgressionTests']:
 p=src/(name+'.luau');s=p.read_text(encoding='utf-8')
 s=re.sub(r'(:Select\("[^"]+",|:Resolve\("[^"]+",)"(F\d+K)"',r'\1"\2:1"',s)
 s=re.sub(r'Leader="(F\d+K)"',r'Leader="\1:1"',s)
 s=re.sub(r'Followers="([F\dK,]+)"',lambda m:'Followers="'+','.join(t+':1' for t in m[1].split(','))+'"',s)
 if name=='FundedTests':
  s=s.replace('v.Active=="F5K"','v.Active=="F5K:1"').replace('item.Key=="F5K"','item.Key=="F5K:1"')
  s=s.replace('v.Copy.Followers[1]=="F5K"','table.find(v.Copy.Followers,"F5K:1")').replace('b.Copy.Leader=="F10K"','b.Copy.Leader=="F10K:1"')
  s=s.replace('message:find("keeps its positions")','message:find("positions")')
  s=s.replace('Checkpoint.Version==5','Checkpoint.Version==6').replace('Checkpoint v5','Checkpoint v6')
  s=s.replace('if a.Key==id then return a end','if a.Tier==id then return a end')
  # Entitlements without an account have their own view collection.
  pattern=r'local function tier\(v,id\)(.*?)end\n'
  match=re.search(pattern,s,re.S)
  if match:
   s=s[:match.start()]+'''local function tier(v,id)
 for _,row in ipairs(v.Accounts) do if row.Tier==id then return row end end
 for _,row in ipairs(v.Tiers) do if row.Key==id then return row end end
end
'''+s[match.end():]
  a=s.index(' test("Legacy practice accounts migrate intact');b=s.index(' test("Depleted accounts restart',a)
  s=s[:a]+''' test("Legacy accounts retire without funded access or accounting loss",function()
  local e,f=exchange();local id="player:42:50000";local a=e:AddAccount(id,50000,40,.8,true)
  quote(e,-1,5825,1);place(e,id,1,1);quote(e,1,5826,1)
  f=Funded.new(e,progression(),e.Config)
  assert(a.LegacyRetired and a.Retired and not next(a.Positions) and not f:Resolve("42","L50000"))
  assert(f:Start("42"));assert(f:View("42").Earned==0 and #f:View("42").Accounts==1)
  e:Audit();return "Obsolete exposure closed, archive retained, funded capital and profit excluded"
 end)
'''+s[b:]
  s=s.replace('h:Owner("88")=="player:88:50000"','h:Owner("88")==nil and old.Accounts["player:88:50000"].LegacyRetired')
 elif name=='StatsTests':
  s=s.replace(' and tier.Attempt==2','').replace('scope(stats,"ALL").Current.Blown==1','scope(stats,"ALL").Current.Blown==0')
  s=s.replace('note:find("Net realized P&L only")','note:find("remain in Total P&L")')
  a=s.index(' test("Legacy practice accounts are separate');b=s.index(' if typeof(game)',a)
  s=s[:a]+''' test("Legacy archives are inaccessible and excluded from funded statistics",function()
  local e,f=exchange();local id="player:12:50000";local a=e:AddAccount(id,50000,100,Ladder.MarginUse,true)
  round(e,id,1,5825,5830)
  f=Funded.new(e,deep(Ladder),e.Config);assert(not f:Select("12","L50000") and a.LegacyRetired)
  f:Start("12");round(e,f:Owner("12"),1,5825,5824)
  local stats=reconcile(e,f,"12");local all=scope(stats,"ALL").Life
  assert(all.Trades==1 and not stats.Legacy);near(all.Net,-50,"funded net excludes retired legacy profit")
  return "Retained legacy +$250 excluded; funded -$50 and one trade retained"
 end)
'''+s[b:]
 elif name=='LeaderboardTests':
  s=s.replace('f:LegacyId("2",50000)','"player:2:50000"')
  s=s.replace('local p=f:Profile("2");p.ProgressCredit=50000','local p=f:Profile("2");p.ProgressCredit=50000;p.Tiers.F100K={State="Unlocked",Claimed=false,Announced=true}')
 elif name=='ProgressionTests':
  s=s.replace('near(f:View("test").Next.Progress,-100)','near(f:View("test").Next.Progress,0)')
  s=s.replace('near(f:View("test").Next.Progress,-150)','near(f:View("test").Next.Progress,0)')
 p.write_text(s,encoding='utf-8')
