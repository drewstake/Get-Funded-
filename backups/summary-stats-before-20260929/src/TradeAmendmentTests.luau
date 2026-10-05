-- Isolated regression checks: no live accounts, DataStores or remotes.
local E=require(script.Parent.MarketEngine)
local F=require(script.Parent.FundedAccounts)
local Config=require(game.ReplicatedStorage.MarketReign.MarketConfig)
local Protection=require(game.ReplicatedStorage.MarketReign.TradeProtection)
return function()
 local n=0
 local function check(ok,msg)n+=1;assert(ok,msg)end
 for _,key in ipairs(Config.ContractOrder)do
  local spec=Config.Contracts[key]
  for _,qty in ipairs({1,3,5})do
   local amount=127.39
   for _,side in ipairs({1,-1})do
    for _,field in ipairs({"Stop","Target"})do
     local p=Protection.Resolve(spec,qty,amount,spec.Last,side,field)
     check(p and math.abs(p.Price/spec.Tick-math.round(p.Price/spec.Tick))<1e-6,"tick-aligned "..key)
     check(math.abs(p.Dollars-amount)<=spec.Tick*spec.Multiplier*qty/2+.001 or p.Ticks==1,"nearest valid total")
     check((p.Price-spec.Last)*side*(field=="Stop"and -1 or 1)>0,"correct protection side")
    end
   end
  end
 end
 for _,bad in ipairs({0,-1,math.huge,0/0})do check(not Protection.Resolve(Config.Contracts.ES,1,bad),"invalid dollars")end
 local e=E.new(Config,41)
 local a=e:AddAccount("test",100000,100,.8,true)
 e:AddAccount("other",100000,100,.8,true)
 local spec=Config.Contracts.ES local price=spec.Last-20
 local ok,r=F.Perform(e,a.Id,{Action="Place",Contract="ES",Direction=1,Quantity=3,Type="Limit",Price=price,StopDollars=100,TargetDollars=200})
 check(ok,"place dollar-protected limit")
 local id=r.Id local o=e.Orders[id]
 check(o.StopTicks==3 and o.TargetTicks==5,"server converts totals using quantity")
 local function req(p,expected,qty)return {Action="AmendOrder",Contract="ES",OrderId=id,Price=p,ExpectedPrice=expected or price,ExpectedQuantity=qty or 3}end
 local function reject(owner,r)
  local old=o.Price local accepted=F.Perform(e,owner,r)
  check(not accepted and o.Price==old and e.Orders[id]==o,"rejection is atomic")
 end
 reject("other",req(price+1))
 reject(a.Id,req(price+.1))
 reject(a.Id,req(price+1,price+2))
 reject(a.Id,req(price+1,nil,2))
 reject(a.Id,req(spec.Last*2))
 a.Locked=true;reject(a.Id,req(price+1));a.Locked=false
 check(F.Perform(e,a.Id,req(price+1)),"accepted amendment")
 check(o.Price*spec.Tick==price+1 and o.Id==id and o.Remaining==3 and o.StopTicks==3,"preserves identity, quantity, protection")
 price+=1
 check(F.Perform(e,a.Id,req(spec.Last+10)),"marketable amendment accepted")
 check(not e.Orders[id] and a.Positions.ES.Quantity==3,"marketable amendment fills normally")
 local p=a.Positions.ES
 check(math.abs((p.Entry-p.Stop)*spec.Multiplier*3-112.5)<.001,"chart stop reflects effective total")
 check(math.abs((p.Target-p.Entry)*spec.Multiplier*3-187.5)<.001,"chart target reflects effective total")
 check(not F.Perform(e,a.Id,req(price)),"filled order cannot be amended")
 local accepted,v=e:Submit(a.Id,{Contract="ES",Direction=-1,Quantity=1,Type="Limit",Price=spec.Last+30})
 check(accepted and e:Cancel(a.Id,v.Id) and not e.Orders[v.Id],"cancel exact pending order")
 check(a.Positions.ES.Quantity==3,"cancel leaves position intact")
 check(not e:Submit(a.Id,{Contract="ES",Direction=1,Quantity=1,Type="Market",StopDollars=100,StopTicks=10}),"reject ambiguous units")
 e:Audit()
 return {Passed=true,Cases=n}
end
