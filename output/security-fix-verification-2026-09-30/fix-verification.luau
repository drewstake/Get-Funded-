-- FIX VERIFICATION, 2026-09-30. Re-runs the audit's isolated reproductions against the fixed modules and
-- records outcomes instead of asserting that the exploit succeeds. Disposable engines, profiles and an
-- injected in-memory store only: no live remotes, no DataStore, no Play session, no real purchase.
-- Runs in Studio Edit mode (after the fixed sources are synced) or under the Lune harness.
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

-- F1a. The audit loop: 200 immediate resets using the latest active key.
do
 local e=E.new(C,12345);local pop=P.new(e);local f=F.new(e,L,C)
 assert(f:Start("audit-reset"))
 local before=CP.Encode(CP.Capture(e,pop))
 local accepted,rejected,firstRejection=0,0,nil
 for _=1,200 do
  local p=f:Profile("audit-reset");local ok,message=f:Restart("audit-reset",p.Active)
  if ok then accepted+=1 else rejected+=1;firstRejection=firstRejection or message end
 end
 local p=f:Profile("audit-reset");local after=CP.Encode(CP.Capture(e,pop))
 report.ResetGrowth={Requests=200,Accepted=accepted,Rejected=rejected,FirstRejection=firstRejection,Attempts=#p.Ledger,Usable=#f:ActiveTiers(p),
  BeforeRaw=before.RawBytes,AfterRaw=after.RawBytes,PortfolioBytes=#H:JSONEncode(f:View("audit-reset")),
  RestoredAttempts=#CP.Restore(CP.Decode(after),C).Profiles["audit-reset"].Ledger}
end

-- F1b. A sustained attacker: one reset request every 1/6 s (the remote limiter's rate) for one hour of live
-- exchange time, alternating reconnects (new Funded views) and fresh instance keys.
do
 local e=E.new(C,777);local f=F.new(e,L,C);assert(f:Start("attacker"))
 local accepted,requests,maxRetained=0,0,0
 local step=C.SimulationSpeed/6
 for i=1,6*3600 do
  e.Time+=step;requests+=1
  if i%600==0 then f=F.new(e,L,C);f:Join("attacker") end
  local p=f:Profile("attacker")
  if f:Restart("attacker",p.Active) then accepted+=1 end
  maxRetained=math.max(maxRetained,#p.Ledger)
 end
 report.SustainedResetAttack={RealSeconds=3600,Requests=requests,Accepted=accepted,MaxRetained=maxRetained,Accounts=f:PlayerAccounts(),
  Expected="Burst "..f:Limit("ResetLimits","Burst").." + one credit per "..f:Limit("ResetLimits","RefillSeconds").."s"}
end

-- F1c. Growth with the rate limits disabled: compaction alone keeps the retained record bounded.
do
 local l=clone(L);l.ResetLimits={CooldownSeconds=0,Burst=0,RefillSeconds=0}
 local e=E.new(C,4242);local pop=P.new(e);local f=F.new(e,l,C);assert(f:Start("bulk"))
 local sizes={}
 for i=1,1000 do assert(f:Restart("bulk",f:Profile("bulk").Active)) if i%250==0 then
  local p=f:Profile("bulk");table.insert(sizes,{Resets=i,Retained=#p.Ledger,Raw=CP.Encode(CP.Capture(e,pop)).RawBytes,Portfolio=#H:JSONEncode(f:View("bulk"))})
 end end
 local stats=f:Stats("bulk").Scopes[1].Life
 report.CompactionOnly={Samples=sizes,LifetimeAttempts=stats.Attempts,Audit=pcall(function()e:Audit()end)}
end

-- F2. The audit's purchase replay: one purchase, then replays of sequence 1.
do
 local store={Writes=0,Value=nil}
 function store:UpdateAsync(_,fn)local value=fn(clone(self.Value));if value then self.Writes+=1;self.Value=clone(value)end;return clone(value)end
 function store:GetAsync()return clone(self.Value)end
 local settings=clone(require(S.WorldConfig))
 local w=W.new(C,{Store=store,Settings=settings,Studio=true,PlaceId=123,JobId="isolated-verification",CanOwn=true,Now=function()return 1000 end})
 w:Open();assert(w:CanRun(),w.LastError)
 local f=F.new(w.Engine,L,C);assert(f:Start("audit-shop"));assert(f:Start("bystander"))
 f:Profile("audit-shop").WalletCents=200000 -- fixture: profit earned before the test
 local completed,frozen,sameReceipt=0,0,0;local first
 local function finish(ok,_,receipt)assert(ok);completed+=1;first=first or receipt;if receipt and receipt.Account==first.Account then sameReceipt+=1 end end
 assert(w:Purchase(f,"audit-shop","F5K",1,finish))
 local deadline=os.clock()+3 while completed<1 and os.clock()<deadline do task.wait() end
 local writes=store.Writes;local bystanderTrades=0
 local other=f:Owner("bystander");local b=w.Engine.Books.ES
 for _=1,10 do
  assert(w:Purchase(f,"audit-shop","F5K",1,finish))
  if not w:CanRun() or w.TransactionBusy then frozen+=1 end
  b.Bids={};b.Asks={}
  if F.Perform(w.Engine,other,{Action="Place",Contract="ES",Direction=1,Quantity=1,Type="Market"}) and F.Perform(w.Engine,other,{Action="Close",Contract="ES"}) then bystanderTrades+=1 end
 end
 task.wait()
 local p=f:Profile("audit-shop")
 report.PurchaseReplay={Replays=10,ExtraWrites=store.Writes-writes,GlobalFreezes=frozen,Callbacks=completed,SameReceipt=sameReceipt,Attempts=#p.Ledger,
  WalletCents=p.WalletCents,SpentCents=p.WalletSpentCents,BystanderRoundTrips=bystanderTrades}
 w.Settings.MaxEncodedBytes=1
 local saved=w:Save(false)
 report.SaveSizeFailure={SaveSucceeded=saved,CanRun=w:CanRun(),Healthy=w.Healthy,Error=w.LastError}
end

-- Checkpoint codec: the audit's 32,000,020-byte compressible fixture, then the configured boundary.
do
 local ok,err=pcall(CP.Encode,{AuditPadding=string.rep("x",32000001)})
 local limit=CP.MaxDecodedBytes;local base=#H:JSONEncode({P=""})
 local atLimit=CP.Encode({P=string.rep("x",limit-base)},limit)
 local decoded=pcall(CP.Decode,atLimit)
 local over=pcall(CP.Encode,{P=string.rep("x",limit-base+1)},limit)
 report.Codec={AuditFixtureWriterAccepted=ok,AuditFixtureError=ok and "" or tostring(err),WriterLimit=limit,ReaderLimit=CP.MaxDecodedBytes,StoredValueLimit=require(S.WorldConfig).MaxEncodedBytes,
  AtLimitRaw=atLimit.RawBytes,AtLimitDecoded=decoded,OverLimitAccepted=over}
end

-- S1. The audit's crossed fallback fixture (long) and its mirror (short).
do
 local function fixture(direction)
  local e=E.new(C,17);local f=F.new(e,L,C);assert(f:Start("audit-spread"));local id=f:Owner("audit-spread")
  local b=e.Books.ES;local tick=b.Spec.Tick
  e:AddAccount("audit-maker",1000000,500,.8,false)
  -- Long: a participant bid above last with no ask. Short: a participant ask below last with no bid.
  assert(e:Submit("audit-maker",{Contract="ES",Direction=direction,Quantity=10,Type="Limit",Price=(b.Last or b.Reference)*tick+direction*tick}))
  local initial=e.Accounts[id].Balance
  for _=1,10 do
   assert(F.Perform(e,id,{Action="Place",Contract="ES",Direction=direction,Quantity=5,Type="Market"}))
   assert(F.Perform(e,id,{Action="Close",Contract="ES"}))
  end
  e:Audit()
  return {RoundTrips=10,Gain=e.Accounts[id].Balance-initial,Wallet=f:Profile("audit-spread").WalletCents/100,MarketVolume=e.TotalVolume}
 end
 report.Pricing={Long=fixture(1),Short=fixture(-1)}
 local scans={}
 for _,seed in ipairs({17,1729,4821}) do
  local sim=E.new(C,seed);local pop=P.new(sim);local oneSidedCrossed,effectiveCrossed,oneSided=0,0,0
  for _=1,8000 do
   pop:Step()
   for _,symbol in ipairs(C.ContractOrder) do
    local book=sim.Books[symbol];local last=book.Last or book.Reference
    if #book.Asks==0 or #book.Bids==0 then oneSided+=1 end
    if (#book.Asks==0 and book.Bids[1] and book.Bids[1].Price>last) or (#book.Bids==0 and book.Asks[1] and book.Asks[1].Price<last) then oneSidedCrossed+=1 end
    if sim:_touch(book,1)<sim:_touch(book,-1) then effectiveCrossed+=1 end -- a buy below a sell = free round trip
   end
  end
  table.insert(scans,{Seed=seed,Steps=8000,OneSidedSnapshots=oneSided,RawCrossedFallbackStates=oneSidedCrossed,EffectiveCrossedQuotes=effectiveCrossed})
 end
 report.Pricing.NormalSimulation=scans
end
return H:JSONEncode(report)
