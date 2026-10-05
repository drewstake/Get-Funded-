-- Disposable price-execution fixture. Normal Submit creates the one-sided book; no live state.
local S=game.ServerScriptService.MarketReign
local C=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local L=require(game.ReplicatedStorage.MarketReign.ProgressionConfig)
local E=require(S.MarketEngine);local F=require(S.FundedAccounts);local P=require(S.Participants)
local H=game:GetService("HttpService")
local e=E.new(C,17);local f=F.new(e,L,C);assert(f:Start("audit-spread"));local id=f:Owner("audit-spread")
local b=e.Books.ES;local tick=b.Spec.Tick
-- A valid participant bid above the last/reference is permitted when there is no ask.
e:AddAccount("audit-maker",1000000,500,.8,false)
assert(e:Submit("audit-maker",{Contract="ES",Direction=1,Quantity=10,Type="Limit",Price=(b.Last or b.Reference)*tick+tick}))
local initial=e.Accounts[id].Balance;local loops=10
for _=1,loops do
 assert(F.Perform(e,id,{Action="Place",Contract="ES",Direction=1,Quantity=5,Type="Market"}))
 assert(F.Perform(e,id,{Action="Close",Contract="ES"}))
end
local result={RoundTrips=loops,Gain=e.Accounts[id].Balance-initial,Wallet=f:Profile("audit-spread").WalletCents/100,
 BookBid=b.Bids[1].Price*tick,LastOrReference=(b.Last or b.Reference)*tick,AskCount=#b.Asks,BidQuantity=b.Bids[1].Quantity,MarketVolume=e.TotalVolume}
e:Audit()
local observed={}
for _,seed in ipairs({17,1729,4821})do
 local sim=E.new(C,seed);local pop=P.new(sim)
 local count=0;local first
 for step=1,8000 do
  pop:Step()
  for _,symbol in ipairs(C.ContractOrder)do
   local book=sim.Books[symbol];local last=book.Last or book.Reference
   if (#book.Asks==0 and book.Bids[1] and book.Bids[1].Price>last) or (#book.Bids==0 and book.Asks[1] and book.Asks[1].Price<last) then
    count+=1;first=first or {Step=step,Symbol=symbol,Last=last,Bid=book.Bids[1]and book.Bids[1].Price,Ask=book.Asks[1]and book.Asks[1].Price}
   end
  end
 end
 table.insert(observed,{Seed=seed,Opportunities=count,First=first})
end
return H:JSONEncode({Fixture=result,NormalSimulation=observed})
