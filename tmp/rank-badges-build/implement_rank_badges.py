from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def read(n):return (ROOT/'src'/f'{n}.luau').read_text(encoding='utf-8-sig')
def write(n,s):(ROOT/'src'/f'{n}.luau').write_text(s,encoding='utf-8')
titles=[
 ('FirstTrade','Opening Bell','Trades',1,2,'Trader'),('FirstWin','Green Spark','Wins',1,3,'First Win'),
 ('Trades5','Tape Reader','Trades',5,4,''),('Profit500','Profit Scout','Profit',500,5,'Rising Trader'),
 ('Wins10','Green Collector','Wins',10,6,''),('Trades25','Market Navigator','Trades',25,7,''),
 ('Profit2500','Golden Edge','Profit',2500,8,''),('Balance10K','Momentum Maker','Profit',5000,9,'Skilled Trader'),
 ('Trades100','Order Veteran','Trades',100,10,''),('Balance25K','Market Pro','Profit',15000,11,''),
 ('Wins100','Profit Ace','Wins',100,12,''),('Balance50K','Market Master','Profit',40000,13,''),
 ('Trades500','Closing Champion','Trades',500,14,''),('Balance100K','Get Funded Legend','Profit',90000,15,''),
 ('Wins500','Emerald Titan','Wins',500,14,''),('Profit250K','Market Sovereign','Profit',250000,16,'')]
ranks=[('Rookie','Market Rookie',0,0,0,1),('Apprentice','Trading Apprentice',1,0,0,2),
 ('Rising','Rising Trader',5,2,500,4),('Skilled','Skilled Trader',25,10,5000,7),
 ('Pro','Market Pro',100,40,15000,11),('Master','Market Master',250,100,40000,13),
 ('Legend','Trading Legend',500,200,90000,15),('Sovereign','Market Sovereign',1000,500,250000,16)]
s='''-- Permanent progression uses realized trading evidence; grants never count.
return {
 Version=4,ProgressionVersion=1,StartingBalance=10000,MinimumContracts=5,BalancePerContract=1000,MarginUse=0.8,
 ResetLimits={Burst=5,RefillSeconds=720},AccountLimits={MaxExchangeAccounts=20000},
 BadgeAtlas="rbxassetid://114491192679289",BadgeAtlasSize=1254,
 Ranks={
'''
for id,name,trades,wins,profit,badge in ranks:s+=f'  {{Id="{id}",Name="{name}",Trades={trades},Wins={wins},Profit={profit},Badge={badge}}},\n'
s+=' },\n Milestones={\n'
for id,title,kind,goal,badge,old in titles:
 name=f'Complete {goal:,} trade'+('' if goal==1 else 's') if kind=='Trades' else f'Close {goal:,} profitable trade'+('' if goal==1 else 's') if kind=='Wins' else f'Earn ${goal:,} lifetime net profit'
 s+=f'  {{Id="{id}",Name="{name}",Kind="{kind}",Goal={goal},Title="{title}",Badge={badge}'+(f',OldTitle="{old}"' if old else '')+'},\n'
write('ProgressionConfig',s+' },\n}\n')
write('ProgressionRules','''-- Shared definitions and pure presentation. Only FundedAccounts awards progression.
local Config=require(script.Parent.ProgressionConfig)
local Rules={}
function Rules.Rank(id)
 for index,r in ipairs(Config.Ranks) do if r.Id==id then return r,index end end
 return nil
end
function Rules.Metric(m,net,trades,wins)
 return math.max(0,m.Kind=="Trades" and trades or m.Kind=="Wins" and wins or net)
end
function Rules.Qualifies(r,net,trades,wins)
 return trades>=r.Trades and wins>=r.Wins and (r.Profit==0 or net+1e-6>=r.Profit)
end
function Rules.Obsolete(title)
 return title:match("^Legacy .*Trader$")~=nil or title:match("^%d+K Trader$")~=nil or title=="Legacy Top Tier Complete"
end
function Rules.Normalize(p,at)
 if p.ProgressionVersion==Config.ProgressionVersion then return false end
 p.LegacyProgression=p.LegacyProgression or {Titles=table.clone(p.Titles or {}),Rank=p.Rank}
 p.Awards=p.Awards or {};p.AlumniTitles=p.AlumniTitles or {}
 local known={};for _,m in ipairs(Config.Milestones)do known[m.Title]=m; if m.OldTitle then known[m.OldTitle]=m end end
 local seen={};for _,title in ipairs(p.AlumniTitles)do seen[title]=true end
 for _,title in ipairs(p.Titles or {})do
  local m=known[title]
  if m then p.Awards[m.Id]=p.Awards[m.Id] or {At=at,Title=title,Preserved=true}
  else
   local display=Rules.Obsolete(title) and "Founding Trader" or title
   if not seen[display]then table.insert(p.AlumniTitles,display);seen[display]=true end
  end
 end
 p.ProgressionVersion=Config.ProgressionVersion
 return true
end
function Rules.Titles(p)
 local titles,seen={},{};local current
 for _,m in ipairs(Config.Milestones)do if p.Awards[m.Id]then
  if not seen[m.Title]then table.insert(titles,m.Title);seen[m.Title]=true end;current=m
 end end
 for _,title in ipairs(p.AlumniTitles or {})do if not seen[title]then table.insert(titles,title);seen[title]=true end end
 return titles,current
end
return Rules
''')
write('BadgeArt','''-- One uploaded ImageGen atlas, shared by titles and both leaderboard modes.
local Config=require(script.Parent.ProgressionConfig)
local Art={}
function Art.Create(parent,name,index,x,y,size)
 local icon=Instance.new("ImageLabel");icon.Name=name;icon.BackgroundTransparency=1
 icon.Position=UDim2.fromOffset(x,y);icon.Size=UDim2.fromOffset(size,size);icon.ScaleType=Enum.ScaleType.Fit
 icon.ZIndex=parent.ZIndex+1;icon:SetAttribute("BadgeIndex",index)
 if index then
  local n=math.clamp(index,1,16)-1;local cell=Config.BadgeAtlasSize/4
  local left,top=math.floor(n%4*cell),math.floor(math.floor(n/4)*cell)
  icon.Image=Config.BadgeAtlas;icon.ImageRectOffset=Vector2.new(left,top)
  icon.ImageRectSize=Vector2.new(math.floor((n%4+1)*cell)-left,math.floor((math.floor(n/4)+1)*cell)-top)
 end
 icon.Parent=parent;return icon
end
return Art
''')
f=read('FundedAccounts')
f=f.replace('local TradeStats=', 'local Rules=require(game.ReplicatedStorage.MarketReign.ProgressionRules)\nlocal TradeStats=',1)
f=f.replace('  self.Engine:ContractLimit(self.Engine.Accounts[p.Account])\n  return','  self.Engine:ContractLimit(self.Engine.Accounts[p.Account])\n  self:Evaluate(uid,true)\n  return',1)
f=f.replace('q.PlayerName=p.PlayerName;q.DisplayName=p.DisplayName','q.PlayerName=p.PlayerName;q.DisplayName=p.DisplayName\n q.Awards=clone(original.Awards or {});q.Titles=clone(original.Titles or {})')
start=f.index('function Funded:_metric(');end=f.index('function Funded:_credits',start)
f=f[:start]+'''function Funded:_metric(p,m,net,trades,wins)
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
 if previous and previous.Id~=rank.Id and not silent then
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
''' +f[end:]
f=f.replace('self:_open(uid,self:_new(uid),self.Config.StartingBalance,"Start")','self:_open(uid,self:_new(uid),self.Config.StartingBalance,"Start")\n self:Evaluate(uid,true)')
f=f.replace('Rank=p.Rank,Titles=clone(p.Titles)', 'Rank=p.Rank,RankId=p.RankId,Trades=trades,Wins=wins,Titles=clone(p.Titles)')
f=f.replace('local r={Key=m.Id,Name=m.Name','local r={Key=m.Id,Badge=m.Badge,Name=m.Name')
f=f.replace('v.Completed=v.Next==nil;return v','''local rank,index=Rules.Rank(p.RankId)
 v.RankBadge=rank and rank.Badge;v.RankLevel=index;v.RankNext=index and clone(self.Config.Ranks[index+1])
 local _,title=Rules.Titles(p);v.Title=title and title.Title or (#p.Titles>0 and p.Titles[#p.Titles] or "Your story starts here")
 v.TitleId=title and title.Id;v.TitleBadge=title and title.Badge or 1
 v.Ranks={};for _,r in ipairs(self.Config.Ranks)do local item=clone(r);item.Earned=p.RankAwards[r.Id]~=nil;table.insert(v.Ranks,item)end
 v.Completed=v.Next==nil;return v''')
write('FundedAccounts',f)
r=read('LeaderboardRanking')
r=r.replace('local Ranking=', 'local Rules=require(game.ReplicatedStorage.MarketReign.ProgressionRules)\nlocal Ranking=',1)
r=r.replace('row.Tier=p.Rank or "New Trader";row.TierSize=0','local rank=Rules.Rank(p.RankId)\n row.ProgressionRankId=rank and rank.Id;row.ProgressionVersion=p.ProgressionVersion\n row.Tier=rank and rank.Name or nil;row.TierSize=0')
write('LeaderboardRanking',r)
s=read('StatsView')
start=s.index(' local heroH=');end=s.index(' yy+=heroH+gap',start)
s=s[:start]+''' local heroH=200
 local hero=piece("HeroCard",0,yy,cw,heroH)
 local pad=narrow and 20 or 32
 for _,name in ipairs({"AttemptsLabel","ClosedTradesLabel","AttemptsIcon","ClosedTradesIcon","HeroDivider","HeroWatermark"})do
  local part=hero:FindFirstChild(name);if part then part:Destroy()end
 end
 fit(box(hero.TotalTitle,pad,18,176,44),32);box(hero.TotalHelp,pad+176,18,44,44)
 fit(box(hero.TotalValue,pad,66,cw-pad*2,86),narrow and 56 or 78)
 fit(box(hero.TotalCaption,pad,156,cw-pad*2,30),19)
'''+s[end:]
s='\n'.join(line for line in s.split('\n')if not ('hero.AttemptsLabel.Text='in line or 'hero.ClosedTradesLabel.Text='in line))
write('StatsView',s)
print('Wrote progression definitions, permanent award migration, rank projection, badge renderer and Stats cleanup.')
