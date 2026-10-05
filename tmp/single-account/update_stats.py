from pathlib import Path
p=Path('src/StatsView.luau');s=p.read_text(encoding='utf-8')
a=s.index('function View.Resolve(');b=s.index('function View.Coverage(',a)
s=s[:a]+'''function View.Resolve(data,state,portfolio)
 local list=data and data.Scopes or {};local scope=list[1]
 state.StatsScope="ALL"
 local period=state.StatsPeriod=="Current" and "Current" or state.StatsPeriod=="Dated" and "Dated" or "Life"
 local agg=scope and (period=="Dated" and scope.Life and scope.Life.Dated or period~="Dated" and scope[period])
 return scope,agg,period,list
end
function View.OpenFor(scope,pf,agg)return pf and pf.Open or agg and agg.Open or 0 end
function View.Describe(scope,agg,period)
 if period=="Current" then return "This run only. Closed trading gains minus losses; starting money is excluded." end
 if period=="Dated" then return "Lifetime closed trades with saved dates. Earlier undated results remain in Lifetime." end
 return "Lifetime trading results across every run and earlier accounts. Losses remain after a restart; grants never count."
end
'''+s[b:]
s=s.replace('Start a funded account and close your first trade. Every completed trade, win, loss and blown account is then tracked here for good, including across restarts.','Close your first trade to see your results. Wins, losses and lifetime history are kept across restarts.').replace('Start a Funded Account','Go to Trade')
s=s.replace('No active funded accounts','Your stats are loading').replace('Your historical results are saved. Open Accounts to restart or activate a usable funded account.','Your results are saved. Return to Trade while the exchange connects.').replace('View Accounts','Go to Trade')
a=s.index(' local funded=piece(');b=s.index(' if not agg then',a)
s=s[:a]+''' local periodItems={{"Life","Lifetime"},{"Current","This run"},{"Dated","Dated history"}}
 local bw=(cw-16)/3
 for i,item in ipairs(periodItems) do
  ctx.control(ctx.button(sc,"Period"..item[1],item[2],(i-1)*(bw+8),yy,bw,46,function()selectFilter("ALL",item[1])end,ctx.C.Raised,ctx.C.Text,narrow and 12 or 17),period==item[1])
 end
 yy+=58
 label(sc,"ScopeDescription",View.Describe(scope,agg or {},period),4,yy,cw-8,narrow and 70 or 46,14,muted,true)
 yy+=narrow and 82 or 58
'''+s[b:]
s=s.replace('Open positions, starting capital, unlocks and resets are excluded. Blown attempts remain in Lifetime.','Open positions, starting money and restart grants are excluded. Failed runs remain in Lifetime.')
s=s.replace('funded accounts','the trading account').replace('blown accounts','failed runs')
p.write_text(s,encoding='utf-8')
p=Path('src/LeaderboardView.luau');s=p.read_text(encoding='utf-8').replace('No completed funded trades yet.','No completed trades yet.').replace('Lifetime net realized profit · losses and copied trades included','Lifetime net trading profit · all runs and losses included').replace('Lifetime net realized profit','Lifetime net trading profit').replace('Be the first to complete a funded trade!','Close a trade to join the leaderboard!').replace('.." tier"','..""').replace('HIGHEST TIER','PERMANENT RANK').replace('local tierW=narrow and 0 or 120','local tierW=narrow and 0 or 170')
s=s.replace('text(badge,"Label",r.Tier or "—",0,1,tierW-17,23,17,C.Text,nil,Enum.TextXAlignment.Center)','local title=text(badge,"Label",r.Tier or "—",4,1,tierW-25,23,14,C.Text,nil,Enum.TextXAlignment.Center);title.TextScaled=true')
p.write_text(s,encoding='utf-8')
