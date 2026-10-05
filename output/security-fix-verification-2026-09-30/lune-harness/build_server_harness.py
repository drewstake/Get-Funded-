# Generates a verification harness that runs the CURRENT MarketServer.server.luau source lexically against
# mocked Roblox boundaries (same technique as the audit's server-boundary-harness.luau, which is left unchanged).
import sys
audit=open('/home/claude/gf/output/security-audit-2026-09-30/server-boundary-harness.luau',encoding='utf-8').read().split('\n')
begin=[i for i,l in enumerate(audit) if 'BEGIN UNCHANGED MarketServer' in l][0]
prefix='\n'.join(audit[:begin])
server=open(sys.argv[1],encoding='utf-8').read().replace('\r\n','\n')
def rep(old,new):
    global prefix
    assert prefix.count(old)==1,old
    prefix=prefix.replace(old,new)
rep('-- Isolated audit of the actual MarketServer source with mocked Roblox boundaries.',
    '-- FIX VERIFICATION (generated): the current MarketServer source runs lexically against mocked Roblox boundaries.\n'
    '-- Same technique as output/security-audit-2026-09-30/server-boundary-harness.luau. No live remotes, stores or Play.')
rep('local modules={config=AuditConfig,ladder=AuditLadder,WorldService={new=function()return auditWorld end},FundedAccounts=AuditFunded,LeaderboardRanking=AuditRanking,LeaderboardService={new=function()return fakeBoard end}}',
    'local modules={config=AuditConfig,ladder=AuditLadder,WorldService={new=function()return auditWorld end},FundedAccounts=AuditFunded,LeaderboardRanking=AuditRanking,LeaderboardService={new=function()return fakeBoard end},\n'
    ' ReplyBuffer=require(Server.ReplyBuffer),WorldConfig=require(Server.WorldConfig)}')
rep('local script={Parent={WorldService="WorldService",FundedAccounts="FundedAccounts",LeaderboardService="LeaderboardService",LeaderboardRanking="LeaderboardRanking"}}',
    'local script={Parent={WorldService="WorldService",FundedAccounts="FundedAccounts",LeaderboardService="LeaderboardService",LeaderboardRanking="LeaderboardRanking",ReplyBuffer="ReplyBuffer",WorldConfig="WorldConfig"}}')
rep('local auditWorld={Studio=true,Engine=AuditEngine,Population=population,Epoch=1,Mode="Local",CanRun=function()return true end,Label=function()return "AUDIT"end,Maintain=function()end}',
    'local purchases=0\n'
    'local auditWorld={Studio=true,Engine=AuditEngine,Population=population,Epoch=1,Mode="Local",CanRun=function()return true end,Label=function()return "AUDIT"end,Maintain=function()end,\n'
    ' HasCapacity=function()return true end,\n'
    ' Purchase=function(_,_,_,tier,sequence,complete)purchases+=1;complete(true,"Mock purchase saved.",{Sequence=sequence,Tier=tier});return true end}')
rep('local function signal()local s={}function s:Connect(fn)self.Callback=fn;return {Disconnect=function()end}end return s end',
    'local function signal()local s={Callbacks={}}function s:Connect(fn)self.Callback=fn;table.insert(self.Callbacks,fn);return {Disconnect=function()end}end return s end')
rep('local otherPlayer={UserId=902,Name="AuditTwo",DisplayName="Audit Two"}',
    'local otherPlayer={UserId=902,Name="AuditTwo",DisplayName="Audit Two"}\nlocal thirdPlayer={UserId=903,Name="AuditThree",DisplayName="Audit Three"}')
rep('GetPlayers=function()return {auditPlayer,otherPlayer}end','GetPlayers=function()return {auditPlayer,otherPlayer,thirdPlayer}end')
rep('function o:FireClient(player,packet)sends+=1;self.LastPacket=packet end',
    'function o:FireClient(player,packet)sends+=1;self.LastPacket=packet;self.Packets=self.Packets or {};self.Packets[player]=self.Packets[player] or {};table.insert(self.Packets[player],packet)end')
rep('local require=function(k)assert(modules[k],"Unexpected module");return modules[k]end','local require=function(k)assert(modules[k],"Unexpected module "..tostring(k));return modules[k]end')
rep('local os={clock=function()return now end,time=function()return 1000 end}',
    'local os={clock=function()return now end,time=function()return 1000 end}\nlocal debug={profilebegin=function()end,profileend=function()end}')
suffix=r'''
-- END CURRENT MarketServer.server.luau
local Settings=modules.WorldConfig
local function frame(dt)fakeRun.Heartbeat.Callback(dt or AuditConfig.StepSeconds/AuditConfig.SimulationSpeed+.000001)end
frame()
local nextRequestId=0
local function fire(player,req)nextRequestId+=1;req.Id=nextRequestId;remoteMap.OrderRequest.OnServerEvent.Callback(player,req)end
local function send(player,req)now+=0.2;fire(player,req);frame();return clients[player].Replies[#clients[player].Replies]end
local report={Limits={MaxQueuedReplies=Settings.MaxQueuedReplies,ReplyMaxAgeSeconds=Settings.ReplyMaxAgeSeconds}}
local maxSeen=0
local function watch()for _,s in pairs(clients)do maxSeen=math.max(maxSeen,#s.Replies);assert(#s.ReplyTimes==#s.Replies,"reply timestamps out of sync")end end
-- 1. Accepted actions from a client that never subscribes (the audit reproduction, 601 Starts).
send(auditPlayer,{Action="Start"})
for _=1,600 do send(auditPlayer,{Action="Start"});watch()end
report.AcceptedStarts={Requests=601,Buffered=#clients[auditPlayer].Replies,Dropped=clients[auditPlayer].DroppedReplies,PacketsSent=sends,Subscribed=clients[auditPlayer].Subscribed,SeenRetained=#clients[auditPlayer].SeenOrder}
-- 2. Rejected actions (stale account token) from the same unsubscribed client.
for _=1,600 do send(auditPlayer,{Action="Place",ExpectedAccount="not-mine",Contract="ES",Direction=1,Quantity=1,Type="Market"});watch()end
local last=clients[auditPlayer].Replies[#clients[auditPlayer].Replies]
report.RejectedActions={Requests=600,Buffered=#clients[auditPlayer].Replies,LastOk=last and last.Ok,Dropped=clients[auditPlayer].DroppedReplies}
-- 3. Queue-full responses: requests arrive while the scheduler is not draining the queue.
local busy=0
for _=1,2000 do
 now+=0.17;fire(auditPlayer,{Action="Start"});watch()
 local r=clients[auditPlayer].Replies[#clients[auditPlayer].Replies]
 if r and r.Message=="Exchange busy. Please retry." then busy+=1 end
end
report.QueueFull={Requests=2000,QueueLength=#queue,BusyReplies=busy,Buffered=#clients[auditPlayer].Replies}
frame(1.01);frame(1.01);frame(1.01);frame(1.01);frame(1.01);frame(1.01);frame(1.01);frame(1.01);frame(1.01);watch()
report.QueueFull.AfterDrain=#clients[auditPlayer].Replies;report.QueueFull.QueueAfterDrain=#queue
-- 4. Age bound: an idle, never-subscribed connection releases everything on a maintenance tick.
now+=Settings.ReplyMaxAgeSeconds+1;frame(1.01)
report.AgeExpiry={Buffered=#clients[auditPlayer].Replies,FullResyncPending=clients[auditPlayer].Full}
report.MaxBufferedEver=maxSeen
-- 5. Ownership/boundary checks from the audit harness still hold.
send(otherPlayer,{Action="Start"})
local one=clients[auditPlayer].Owner;local two=clients[otherPlayer].Owner
local place=send(otherPlayer,{Action="Place",ExpectedAccount=two,Contract="ES",Direction=1,Quantity=1,Type="Limit",Price=5700})
assert(place and place.Ok,"other player could not place")
local foreignId=place.Result.Id
local crossCancel=send(auditPlayer,{Action="Cancel",ExpectedAccount=one,OrderId=foreignId})
local stale=send(auditPlayer,{Action="Place",ExpectedAccount=two,Contract="ES",Direction=1,Quantity=1,Type="Market"})
local forged=send(auditPlayer,{Action="Place",ExpectedAccount=one,Owner=two,UserId=902,Balance=999999,FillTicks=1,Contract="ES",Direction=1,Quantity=1,Type="Market"})
report.Ownership={ForeignCancelRejected=not crossCancel.Ok,ForeignOrderIntact=AuditEngine.Orders[foreignId]~=nil,ForeignAccountTokenRejected=not stale.Ok,ExtraFieldsCouldNotSelectOtherOwner=forged.Ok and AuditEngine.Accounts[one].Positions.ES~=nil and AuditEngine.Accounts[two].Positions.ES==nil,StartingBalanceUnchanged=AuditEngine.Accounts[one].Balance==5000}
local denied=0
for _,bad in ipairs({
 {Action="Place",Quantity=0/0},{Action="Place",Quantity=math.huge},{Action="Place",Quantity=-math.huge},
 {Action="Place",Quantity={}},{Action="Place",Quantity=true},{Action="Place",Contract=string.rep("x",33)},
 {Action="Copy",Followers=string.rep("x",513)},{Action="Place",ExpectedAccount=string.rep("x",65)},
 {Action="Unknown"}
})do
 now+=1;nextRequestId+=1;bad.Id=nextRequestId
 local before=#queue;remoteMap.OrderRequest.OnServerEvent.Callback(auditPlayer,bad)
 if #queue==before and not clients[auditPlayer].Seen[nextRequestId]then denied+=1 end
end
report.InvalidBoundaryInputs={Cases=9,Denied=denied}
local idDenied=0
for _,id in ipairs({0,-1,1.5,1e9+1,0/0,math.huge,-math.huge,"1",{}})do
 now+=1;local before=#queue;remoteMap.OrderRequest.OnServerEvent.Callback(auditPlayer,{Id=id,Action="Start"})
 if #queue==before then idDenied+=1 end
end
report.InvalidIds={Cases=9,Denied=idDenied}
-- 6. Subscribing later still synchronizes: one full authoritative packet with the kept replies.
local update=remoteMap.MarketUpdate
for _=1,40 do send(auditPlayer,{Action="Start"})end
local before=#clients[auditPlayer].Replies
send(auditPlayer,{Action="Subscribe",Contract="ES",Timeframe="1m"})
local packet=update.Packets[auditPlayer][#update.Packets[auditPlayer]]
report.SubscribeSync={BufferedBefore=before,Delivered=#packet.Replies,RepliesDropped=packet.RepliesDropped,Full=packet.Full,HasPortfolio=packet.Portfolio~=nil,HasPositions=packet.Positions~=nil,AfterSubscribe=#clients[auditPlayer].Replies}
-- 7. Normal onboarding for a subscribed newcomer: Start and a Shop purchase acknowledgement both arrive.
now+=1;send(thirdPlayer,{Action="Subscribe",Contract="ES",Timeframe="1m"})
send(thirdPlayer,{Action="Start"})
for _=1,10 do frame(0.05)end
local got={}
for _,p in ipairs(update.Packets[thirdPlayer] or {})do for _,r in ipairs(p.Replies or {})do got[r.Kind or "?"]=r end end
local profile=AuditEngine.Profiles[tostring(thirdPlayer.UserId)]
profile.Tiers.F5K.Claimed=true
send(thirdPlayer,{Action="Purchase",Tier="F5K",PurchaseSequence=1})
for _=1,10 do frame(0.05)end
for _,p in ipairs(update.Packets[thirdPlayer] or {})do for _,r in ipairs(p.Replies or {})do got[r.Kind or "?"]=r end end
report.Onboarding={StartOk=got.Start and got.Start.Ok,StartCreated=got.Start and got.Start.Created,PurchaseOk=got.Purchase and got.Purchase.Ok,PurchaseReceipt=got.Purchase and got.Purchase.Receipt and got.Purchase.Receipt.Sequence,
 DroppedForSubscribedClient=clients[thirdPlayer].DroppedReplies or 0}
-- 8. Disconnect cleanup.
for _,cb in ipairs(fakePlayers.PlayerRemoving.Callbacks)do cb(auditPlayer)end
report.Disconnect={StateReleased=clients[auditPlayer]==nil}
local ok=report.AcceptedStarts.Buffered<=Settings.MaxQueuedReplies and report.RejectedActions.Buffered<=Settings.MaxQueuedReplies
 and report.QueueFull.BusyReplies>0 and report.QueueFull.Buffered<=Settings.MaxQueuedReplies and report.MaxBufferedEver<=Settings.MaxQueuedReplies
 and report.AgeExpiry.Buffered==0 and report.SubscribeSync.Full and report.SubscribeSync.HasPortfolio and report.Onboarding.StartOk and report.Onboarding.PurchaseOk
 and report.Onboarding.DroppedForSubscribedClient==0 and report.Disconnect.StateReleased and report.InvalidIds.Denied==9 and report.InvalidBoundaryInputs.Denied==9
 and report.Ownership.ForeignCancelRejected and report.Ownership.ForeignOrderIntact and report.Ownership.ForeignAccountTokenRejected and report.Ownership.ExtraFieldsCouldNotSelectOtherOwner
report.Passed=ok
return RealGame:GetService("HttpService"):JSONEncode(report)
'''
out=prefix+'\n-- BEGIN CURRENT MarketServer.server.luau (copied at generation time)\n'+server+suffix
open(sys.argv[2],'w',encoding='utf-8').write(out)
print("wrote",sys.argv[2],len(out))
