-- SECURITY AUDIT: Edit-mode, disposable tables only. No live remotes or persistent services.
local S=game.ServerScriptService.MarketReign
local Shared=game.ReplicatedStorage.MarketReign
local E=require(S.MarketEngine)
local F=require(S.FundedAccounts)
local P=require(S.Participants)
local CP=require(S.WorldCheckpoint)
local W=require(S.WorldService)
local H=game:GetService("HttpService")
local function clone(t)if type(t)~="table"then return t end local r={}for k,v in pairs(t)do r[k]=clone(v)end return r end
local C=clone(require(Shared.MarketConfig));C.WarmupSeconds=0
local L=clone(require(Shared.ProgressionConfig))
local report={}
do
 local e=E.new(C,12345);local pop=P.new(e);local f=F.new(e,L,C)
 assert(f:Start("audit-reset"))
 local before=CP.Encode(CP.Capture(e,pop))
 local accepted=0
 for i=1,200 do
  local p=f:Profile("audit-reset");assert(f:Restart("audit-reset",p.Active));accepted+=1
 end
 local p=f:Profile("audit-reset")
 local after=CP.Encode(CP.Capture(e,pop))
 local retired=0;for _,id in ipairs(p.Ledger)do if e.Accounts[id].Retired then retired+=1 end end
 report.ResetGrowth={Accepted=accepted,Attempts=#p.Ledger,Retired=retired,Usable=#f:ActiveTiers(p),Wallet=p.WalletCents,
 BeforeRaw=before.RawBytes,AfterRaw=after.RawBytes,BeforeEncoded=#H:JSONEncode(before),AfterEncoded=#H:JSONEncode(after),PortfolioBytes=#H:JSONEncode(f:View("audit-reset"))}
 local restored=CP.Restore(CP.Decode(after),C)
 report.ResetGrowth.RestoredAttempts=#restored.Profiles["audit-reset"].Ledger
end
do
 local store={Writes=0,Value=nil}
 function store:UpdateAsync(_,fn)self.Writes+=1;local value=fn(clone(self.Value));if value then self.Value=clone(value)end;return clone(value)end
 function store:GetAsync()return clone(self.Value)end
 local settings=clone(require(S.WorldConfig))
 local w=W.new(C,{Store=store,Settings=settings,Studio=true,PlaceId=123,JobId="isolated-audit",CanOwn=true,Now=function()return 1000 end})
 w:Open();assert(w:CanRun(),w.LastError)
 local f=F.new(w.Engine,L,C);assert(f:Start("audit-shop"))
 -- Fixture seed represents profit earned before the test, never a live profile.
 f:Profile("audit-shop").WalletCents=200000
 local completed=0
 local function finish(ok)assert(ok);completed+=1 end
 local function drain(wanted)
  local deadline=os.clock()+3
  while completed<wanted and os.clock()<deadline do task.wait()end
  assert(completed==wanted,"deferred mock save did not finish")
 end
 assert(w:Purchase(f,"audit-shop","F5K",1,finish));drain(1)
 local writes=store.Writes;local frozen=0
 for i=1,10 do
  assert(w:Purchase(f,"audit-shop","F5K",1,finish))
  if not w:CanRun()then frozen+=1 end
  drain(i+1)
 end
 local p=f:Profile("audit-shop")
 report.PurchaseReplay={Replays=10,ExtraWrites=store.Writes-writes,GlobalFreezes=frozen,Callbacks=completed,Attempts=#p.Ledger,WalletCents=p.WalletCents,SpentCents=p.WalletSpentCents}
 -- Force only this in-memory world's save-size threshold below its current serialized size.
 w.Settings.MaxEncodedBytes=1
 local saved=w:Save(false)
 report.SaveSizeFailure={SaveSucceeded=saved,CanRun=w:CanRun(),Healthy=w.Healthy,Error=w.LastError}
end
return H:JSONEncode(report)
