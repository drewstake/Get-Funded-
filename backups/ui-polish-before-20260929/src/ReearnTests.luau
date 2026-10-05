-- Isolated exchange tests: no remotes or DataStore writes.
local Engine=require(script.Parent.MarketEngine)
local Funded=require(script.Parent.FundedAccounts)
local Checkpoint=require(script.Parent.WorldCheckpoint)
local Participants=require(script.Parent.Participants)
local Shared=game.ReplicatedStorage.MarketReign
local Config=require(Shared.MarketConfig)
local Ladder=require(Shared.ProgressionConfig)
local Http=game:GetService("HttpService")
local Tests={}
local function near(a,b)assert(math.abs(a-b)<.00001,tostring(a).." ~= "..tostring(b))end
local function quote(e,side,price,qty,key)
 e:CancelAll("fixture:maker")
 assert(e:Submit("fixture:maker",{Contract=key or "ES",Direction=side,Quantity=qty,Type="Limit",Price=price}))
end
local function roundTrip(e,owner,entry,exit,qty)
 quote(e,-1,entry,qty);assert(Funded.Perform(e,owner,{Action="Place",Contract="ES",Direction=1,Quantity=qty,Type="Market"}))
 quote(e,1,exit,qty);assert(Funded.Perform(e,owner,{Action="Close",Contract="ES"}))
end
local function setup()
 local e=Engine.new(Config,91)
 e:AddAccount("fixture:maker",1e9,100000,.99,false);e:AddAccount("fixture:taker",1e9,100000,.99,false)
 local f=Funded.new(e,Ladder,Config);assert(f:Start("fixture"))
 roundTrip(e,f:Owner("fixture"),5800,5960,5);f:Evaluate("fixture")
 for _,t in ipairs(Ladder.Tiers)do if t.Id~="F5K" then assert(f:Activate("fixture",t.Id)) end end
 f:TakeEvents("fixture")
 return e,f,f:Profile("fixture")
end
local function blow(e,f,p,tier,closingOnly)
 local a=e.Accounts[p.Tiers[tier.Id].Account]
 quote(e,-1,5960,tier.MaxContracts)
 assert(Funded.Perform(e,a.Id,{Action="Place",Contract="ES",Direction=1,Quantity=tier.MaxContracts,Type="Market"}))
 quote(e,-1,5940,1);assert(e:Submit("fixture:taker",{Contract="ES",Direction=1,Quantity=1,Type="Market"}))
 assert(a.Locked,"Equity-zero did not latch")
 f:Evaluate("fixture")
 if not closingOnly then e:AdvanceClock(.25);f:Evaluate("fixture") end
 return a
end
function Tests.Run()
 local results={}
 local function test(name,fn)local ok,result=pcall(fn);table.insert(results,{Name=name,Passed=ok,Detail=ok and(result or "Passed")or tostring(result)})end
 for i=2,#Ladder.Tiers do local t=Ladder.Tiers[i]
  test(t.Short.." is revoked, rejects resets, and re-unlocks only at its fresh stage goal",function()
   local e,f,p=setup();assert(f:Select("fixture",t.Id))
   local a=blow(e,f,p,t);local entry=p.Tiers[t.Id];local history=#a.History
   assert(entry.State=="Locked" and entry.Reearn and a.Retired)
   assert(not f:Resolve("fixture",t.Id) and not f:Select("fixture",t.Id))
   assert(not f:Restart("fixture",t.Id) and not f:Activate("fixture",t.Id))
   assert(not e:Submit(a.Id,{Contract="ES",Direction=1,Quantity=1,Type="Market"}))
   assert(p.Active=="F5K" and #f:ActiveTiers(p)==4)
   for _=1,3 do f:Join("fixture");f:Evaluate("fixture") end
   near(f:ReearnProgress(p,entry),0);assert(entry.State=="Locked","Old credited profit re-unlocked the tier")
   local goal=t.Unlock-Ladder.Tiers[i-1].Unlock;near(entry.Reearn.Goal,goal)
   roundTrip(e,p.Tiers.F5K.Account,5940,5940+(goal-62.5)/250,5);f:Evaluate("fixture")
   near(f:ReearnProgress(p,entry),goal-62.5);assert(entry.State=="Locked","Unlocked below goal")
   roundTrip(e,p.Tiers.F5K.Account,5960,5960.25,5);f:Evaluate("fixture")
   assert(entry.State=="Unlocked" and f:Activate("fixture",t.Id))
   assert(entry.Attempt==2 and entry.Account~=a.Id and entry.Reearn==nil)
   near(e.Accounts[entry.Account].Balance,t.Size);near(a.Realized,-t.Size);assert(#a.History==history)
   local stats=f:Stats("fixture");assert(stats.Scopes[1].Life.Blown==1)
   assert(not f:Restart("fixture",t.Id));e:Audit()
   return {Goal=goal,Attempt=entry.Attempt,RetainedHistory=history}
  end)
 end
 test("A blown follower is removed while unaffected copy followers and positions survive",function()
  local e,f,p=setup();assert(f:SetCopy("fixture",{Enabled=1,Leader="F5K",Followers="F10K,F25K"}))
  quote(e,-1,20500,1,"NQ");assert(Funded.Perform(e,p.Tiers.F25K.Account,{Action="Place",Contract="NQ",Direction=1,Quantity=1,Type="Market"}))
  blow(e,f,p,Ladder.Tiers[2])
  assert(p.Copy.Enabled and p.Copy.Leader=="F5K" and #p.Copy.Followers==1 and p.Copy.Followers[1]=="F25K")
  assert(e.Accounts[p.Tiers.F25K.Account].Positions.NQ.Quantity==1)
  assert(not f:SetCopy("fixture",{Enabled=1,Leader="F5K",Followers="F10K"}))
  assert(#f:Plan("fixture",p.Tiers.F5K.Account).Followers==1)
 end)
 test("A blown lead disables copying and selects a surviving account during liquidation",function()
  local e,f,p=setup();assert(f:Select("fixture","F10K"));assert(f:SetCopy("fixture",{Enabled=1,Leader="F10K",Followers="F5K,F25K"}))
  local a=blow(e,f,p,Ladder.Tiers[2],true)
  assert(a.Positions.ES and p.Active=="F5K" and not p.Copy.Enabled and not p.Copy.Leader)
  assert(p.Tiers.F10K.State=="Locked" and not a.Retired)
  local row=f:View("fixture").Accounts[2];assert(row.Closing and row.Depleted and not row.CanRestart and row.Reearn)
  assert(not f:Restart("fixture","F10K"));e:AdvanceClock(.25);f:Evaluate("fixture");assert(a.Retired and not next(a.Positions))
 end)
 test("Fresh profit, locks, active account, copy settings and statistics persist through checkpoint/rejoin",function()
  local e,f,p=setup();local population=Participants.new(e)
  for _,id in ipairs(e.AccountOrder)do e:CancelAll(id) end
  assert(f:Select("fixture","F10K"));assert(f:SetCopy("fixture",{Enabled=1,Leader="F10K",Followers="F5K"}))
  local a=blow(e,f,p,Ladder.Tiers[2]);roundTrip(e,p.Tiers.F5K.Account,5940,5960,1);f:Evaluate("fixture")
  local before=f:Stats("fixture").Scopes[1].Life.Net
  for _=1,3 do
   local encoded=Http:JSONDecode(Http:JSONEncode(Checkpoint.Encode(Checkpoint.Capture(e,population))))
   e,population=Checkpoint.Restore(Checkpoint.Decode(encoded),Config)
   f=Funded.new(e,Ladder,Config);p=f:Join("fixture");f:Evaluate("fixture")
   assert(p.Tiers.F10K.State=="Locked" and p.Active=="F5K" and not p.Copy.Enabled)
   near(f:ReearnProgress(p,p.Tiers.F10K),1000);near(f:Stats("fixture").Scopes[1].Life.Net,before)
   assert(e.Accounts[a.Id].Retired and not f:Restart("fixture","F10K"))
  end
  roundTrip(e,p.Tiers.F5K.Account,5940,5980,1);f:Evaluate("fixture");assert(p.Tiers.F10K.State=="Unlocked")
  assert(f:Activate("fixture","F10K") and p.Tiers.F10K.Attempt==2)
 end)
 test("Older saved blown higher tiers migrate once, and repeated blow-ups start a new baseline",function()
  local e,f,p=setup();local a=blow(e,f,p,Ladder.Tiers[2])
  p.Tiers.F10K.Reearn=nil;p.Tiers.F10K.State="Active";a.Retired=nil;p.Active="F10K"
  f=Funded.new(e,Ladder,Config);f:Evaluate("fixture");assert(p.Tiers.F10K.State=="Locked")
  local baseline=Http:JSONEncode(p.Tiers.F10K.Reearn);f:Join("fixture");f:Evaluate("fixture")
  assert(Http:JSONEncode(p.Tiers.F10K.Reearn)==baseline)
  roundTrip(e,p.Tiers.F5K.Account,5940,6000,1);f:Evaluate("fixture");assert(f:Activate("fixture","F10K"))
  local b=blow(e,f,p,Ladder.Tiers[2]);assert(b.Id~=a.Id and p.Tiers.F10K.State=="Locked")
  near(f:ReearnProgress(p,p.Tiers.F10K),0);assert(not f:Activate("fixture","F10K"))
 end)
 test("Later losses and write-offs cannot manufacture profit; each locked tier keeps its own baseline",function()
  local e,f,p=setup();blow(e,f,p,Ladder.Tiers[2]);blow(e,f,p,Ladder.Tiers[3])
  near(f:ReearnProgress(p,p.Tiers.F10K),-25000);near(f:ReearnProgress(p,p.Tiers.F25K),0)
  roundTrip(e,p.Tiers.F5K.Account,5940,6000,1);f:Evaluate("fixture")
  near(f:ReearnProgress(p,p.Tiers.F10K),-22000);near(f:ReearnProgress(p,p.Tiers.F25K),3000)
  assert(p.Tiers.F10K.State=="Locked" and p.Tiers.F25K.State=="Locked")
  roundTrip(e,p.Tiers.F5K.Account,5940,5980,1);f:Evaluate("fixture")
  assert(p.Tiers.F10K.State=="Locked" and p.Tiers.F25K.State=="Unlocked")
  assert(f:Activate("fixture","F25K") and not f:Activate("fixture","F10K"))
 end)
 return results
end
return Tests
