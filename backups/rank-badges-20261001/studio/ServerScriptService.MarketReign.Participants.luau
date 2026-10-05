-- One deterministic scheduler; participants never own task loops or modify trade prices.
local Participants={}
Participants.__index=Participants
local RNG={} RNG.__index=RNG
function RNG.new(seed) return setmetatable({State=math.floor(math.abs(seed))%2147483646+1},RNG) end
function RNG:Next() self.State=self.State*48271%2147483647 return self.State/2147483647 end
function RNG:Range(a,b) return a+(b-a)*self:Next() end
function RNG:Int(a,b) return math.floor(self:Range(a,b+1)) end
function RNG:Noise() return (self:Next()+self:Next()+self:Next()-1.5)*2 end
Participants.RNG=RNG
function Participants.new(engine)
 local self=setmetatable({Engine=engine,Config=engine.Config,Random=RNG.new(engine.Seed),Agents={},Markets={},Regime=nil,
  NextRegime=0,NextNews=80,NextBeliefs=0,News="No synthetic news",NewsUntil=0,Events={}},Participants)
 local r=self.Random
 self:_regime()
 for _,key in ipairs(self.Config.ContractOrder) do
  local book=engine.Books[key]
  self.Markets[key]={Fair=book.Reference,Anchor=book.Reference,Impulse=0}
  for i=1,self.Config.MakersPerInstrument do self:_agent(key,"Maker",i) end
  for i=1,self.Config.ParticipantsPerInstrument do
   local total=0 for _,kind in ipairs({"Liquidity","Momentum","Value","Reversion","Protective"}) do total+=self.Config.BehaviorWeights[kind] or 0 end
   local draw=r:Range(0,total) local chosen="Liquidity"
   for _,kind in ipairs({"Liquidity","Momentum","Value","Reversion","Protective"}) do draw-=self.Config.BehaviorWeights[kind] or 0 if draw<=0 then chosen=kind break end end
   self:_agent(key,chosen,i)
  end
  if self.Config.WhaleFrequency>0 then for i=1,self.Config.WhalesPerInstrument do self:_agent(key,"Whale",i) end end
 end
 -- A genuine opening auction: finite makers post, and a participant crosses a quote.
 for _,a in ipairs(self.Agents) do if a.Kind=="Maker" then self:_maker(a) end end
 for _,key in ipairs(self.Config.ContractOrder) do
  for _,a in ipairs(self.Agents) do if a.Key==key and a.Kind~="Maker" then
   engine:Submit(a.Id,{Contract=key,Direction=r:Next()<0.5 and 1 or -1,Quantity=1,Type="Market"}) break
  end end
 end
 return self
end
function Participants:_agent(key,kind,index)
 local r=self.Random local maker=kind=="Maker" local whale=kind=="Whale"
 local id="bot:"..key..":"..kind..":"..index
 local budget=r:Int(maker and 350000 or whale and 600000 or 50000,maker and 650000 or whale and 1100000 or 160000)
 local a={Id=id,Key=key,Kind=kind,Budget=budget,Risk=r:Range(0.45,0.85),Limit=r:Int(maker and 140 or whale and 180 or 16,maker and 250 or whale and 350 or 60),
  Speed=r:Range(maker and 1.5 or whale and 28 or 2.5,maker and 4.5 or whale and 100 or 13),Size=r:Int(maker and 3 or whale and 18 or 1,maker and 9 or whale and 60 or 5),
  Bias=r:Range(-0.55,0.55),Belief=self.Markets[key].Fair+r:Noise()*9,Patience=r:Range(4,35),Aggression=r:Range(0.2,0.8),
  Next=r:Range(0.2,18),Stop=r:Int(16,85),Target=r:Int(20,140),Parent=0,ParentSide=1}
 if whale then a.Bias=index%2==0 and -0.3 or 0.3 end
 self.Engine:AddAccount(id,budget,a.Limit,a.Risk,false) table.insert(self.Agents,a)
end
-- Add a new market on migration without reseeding or advancing the saved exchange.
-- Retired (close-only) books keep their original participants and economics until positions close.
function Participants:AddMarket(key)
 local e=self.Engine local r=self.Random local first=#self.Agents+1
 local book=e.Books[key]
 self.Markets[key]={Fair=book.Reference,Anchor=book.Reference,Impulse=0}
 for i=1,self.Config.MakersPerInstrument do self:_agent(key,"Maker",i) end
 for i=1,self.Config.ParticipantsPerInstrument do
  local total=0 for _,kind in ipairs({"Liquidity","Momentum","Value","Reversion","Protective"}) do total+=self.Config.BehaviorWeights[kind] or 0 end
  local draw=r:Range(0,total) local chosen="Liquidity"
  for _,kind in ipairs({"Liquidity","Momentum","Value","Reversion","Protective"}) do draw-=self.Config.BehaviorWeights[kind] or 0 if draw<=0 then chosen=kind break end end
  self:_agent(key,chosen,i)
 end
 if self.Config.WhaleFrequency>0 then for i=1,self.Config.WhalesPerInstrument do self:_agent(key,"Whale",i) end end
 for i=first,#self.Agents do
  local a=self.Agents[i] a.Next+=e.Time
  if a.Kind=="Maker" then self:_maker(a) end
 end
 for i=first,#self.Agents do
  local a=self.Agents[i]
  if a.Kind~="Maker" then e:Submit(a.Id,{Contract=key,Direction=r:Next()<0.5 and 1 or -1,Quantity=1,Type="Market"}) break end
 end
end
function Participants:_regime()
 local r=self.Random local total=0 for _,regime in ipairs(self.Config.Regimes) do total+=regime.Weight end
 local draw=r:Range(0,total) local chosen=self.Config.Regimes[1]
 for _,regime in ipairs(self.Config.Regimes) do draw-=regime.Weight if draw<=0 then chosen=regime break end end
 self.Regime=chosen self.Direction=r:Next()<0.5 and 1 or -1
 self.NextRegime=self.Engine.Time+r:Range(self.Config.RegimeSeconds[1],self.Config.RegimeSeconds[2])
 table.insert(self.Events,{Step=self.Engine.Step,Kind="Regime",Name=chosen.Name,Direction=self.Direction})
 if #self.Events>40 then table.remove(self.Events,1) end
end
function Participants:_maker(a)
 local e=self.Engine local b=e.Books[a.Key] local r=self.Random local c=b.Spec local market=self.Markets[a.Key]
 e:CancelAll(a.Id,a.Key)
 local account=e.Accounts[a.Id] if account.Locked then return end
 local p=account.Positions[a.Key] local inventory=p and p.Quantity*p.Direction or 0
 local stress=self.Regime.Volatility*self.Config.Volatility+math.min(6,b.Volatility)*0.2
 local center=(b.Last or b.Reference)*0.83+market.Fair*0.17-inventory/a.Limit*(5+stress*5)+r:Noise()*0.7
 local spread=math.max(1,math.floor(stress*0.8+b.Volatility*0.2+r:Range(0,1.4)))
 local liquidity=self.Regime.Liquidity*self.Config.Liquidity
 if self.Engine.Time<self.NewsUntil then liquidity*=0.6 end
 if r:Next()>math.min(1,liquidity*1.7) then return end
 for depth=1,3 do
  for _,side in ipairs({1,-1}) do
   local size=math.max(1,math.floor(a.Size*liquidity*r:Range(0.55,1.25)*(1-inventory/a.Limit*side*0.8)))
   local tick=math.max(1,math.round(center-side*(spread+(depth-1)*math.max(1,math.floor(stress)))))
   e:Submit(a.Id,{Contract=a.Key,Direction=side,Quantity=size,Type="Limit",Price=tick*c.Tick,Expires=e.Time+a.Speed*2.8})
  end
 end
end
function Participants:_trader(a)
 local e=self.Engine local b=e.Books[a.Key] local r=self.Random local c=b.Spec
 local account=e.Accounts[a.Id] if account.Locked then return end
 if r:Next()<0.25 then return end -- varied inactivity, even around news
 local last=b.Last or b.Reference local market=self.Markets[a.Key]
 a.Belief+=(market.Fair-a.Belief)*r:Range(0.02,0.18)+r:Noise()*self.Regime.Volatility*c.Scale*0.6
 local p=account.Positions[a.Key] local inventory=p and p.Quantity*p.Direction or 0
 local recent=b.Recent local previous=recent[math.max(1,#recent-r:Int(8,35))] or last
 local momentum=(last-previous)/math.max(3,b.Volatility*8)
 local edge=(a.Belief-last)/math.max(4,b.Volatility*8)
 local signal=a.Bias+r:Noise()*1.3-inventory/a.Limit*1.8
 if a.Kind=="Momentum" then signal+=momentum*r:Range(0.5,1.4)
 elseif a.Kind=="Value" then signal+=edge*r:Range(0.6,1.5)
 elseif a.Kind=="Reversion" then signal-=momentum*r:Range(0.6,1.6) signal+=edge*0.3
 elseif a.Kind=="Protective" then signal+=edge*0.4 end
 if math.abs(signal)<r:Range(0.1,0.55) then return end
 local side=signal>0 and 1 or -1 local size=r:Int(1,a.Size)
 local aggressive=r:Next()<a.Aggression
 if a.Kind=="Whale" then
  if a.Parent>0 then side=a.ParentSide size=math.min(a.Parent,r:Int(4,math.max(5,math.floor(a.Size/3)))) a.Parent-=size
  else
   size=r:Int(math.floor(a.Size/2),a.Size)
   if r:Next()<0.55 then a.Parent=size*r:Int(2,4) a.ParentSide=side size=math.min(a.Parent,r:Int(4,12)) a.Parent-=size end
  end
  aggressive=r:Next()<0.8
 end
 if r:Next()<0.45 then e:CancelAll(a.Id,a.Key) end
 local request={Contract=a.Key,Direction=side,Quantity=size,Type=aggressive and "Market" or "Limit",Expires=e.Time+a.Patience*r:Range(0.5,1.5)}
 if not aggressive then
  local distance=r:Int(1,math.max(2,math.floor(3+self.Regime.Volatility*3)))
  request.Price=math.max(1,math.round(last-side*distance))*c.Tick
 end
 if a.Kind=="Protective" or (a.Kind~="Maker" and r:Next()<0.16) then request.StopTicks=a.Stop request.TargetTicks=a.Target end
 e:Submit(a.Id,request)
end
function Participants:Step()
 local e=self.Engine local r=self.Random
 e:AdvanceClock(self.Config.StepSeconds)
 if e.Time>=self.NextRegime then self:_regime() end
 if self.Config.NewsFrequency>0 and e.Time>=self.NextNews then
  local sign=r:Next()<0.5 and 1 or -1
  local magnitude=r:Range(8,40)*self.Config.Volatility
  for _,key in ipairs(self.Config.ContractOrder) do
   local m=self.Markets[key] local shock=sign*magnitude*e.Books[key].Spec.Scale*r:Range(0.4,1.5)
   m.Anchor+=shock m.Impulse+=shock*0.1
  end
  self.News=(sign>0 and "Optimistic" or "Cautious").." synthetic outlook"
  self.NewsUntil=e.Time+r:Range(20,55) self.NextNews=e.Time+r:Range(140,420)/self.Config.NewsFrequency
  table.insert(self.Events,{Step=e.Step,Kind="News",Name=self.News,Direction=sign}) if #self.Events>40 then table.remove(self.Events,1) end
 end
 if e.Time>=self.NextBeliefs then
  for _,key in ipairs(self.Config.ContractOrder) do
   local m=self.Markets[key] local c=e.Books[key].Spec
   m.Anchor+=self.Regime.Trend*self.Direction*c.Scale+r:Noise()*self.Regime.Volatility*self.Config.Volatility*c.Scale*0.16
   m.Fair+=(m.Anchor-m.Fair)*0.025+m.Impulse*0.06
   m.Impulse*=0.96
   m.Fair=math.clamp(m.Fair,e.Books[key].Reference*0.6,e.Books[key].Reference*1.4)
  end
  self.NextBeliefs=e.Time+1
 end
 for _,a in ipairs(self.Agents) do
  if e.Time>=a.Next then
   if a.Kind=="Maker" then self:_maker(a) else self:_trader(a) end
   local delay=a.Speed*r:Range(0.45,1.65)/self.Regime.Activity
   if a.Kind=="Whale" then delay=a.Parent>0 and r:Range(1.5,6) or delay/math.max(0.0001,self.Config.WhaleFrequency) end
   a.Next=e.Time+delay
   e:ProcessStops()
  end
 end
end
return Participants
