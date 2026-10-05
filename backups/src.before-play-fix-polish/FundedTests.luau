-- Funded-account ladder, onboarding and copy-trading regression suite (server only).
-- Studio: StudioDiagnostics:Invoke("FundedTests"). Uses isolated engines; never touches the live exchange.
local Engine=require(script.Parent.MarketEngine)
local Funded=require(script.Parent.FundedAccounts)
local Shared=game.ReplicatedStorage.MarketReign
local Default=require(Shared.MarketConfig)
local Ladder=require(Shared.ProgressionConfig)
local Tests={}
local function deep(v) if type(v)~="table" then return v end local r={} for k,x in pairs(v) do r[k]=deep(x) end return r end
local function progression(unlocks)
 local c=deep(Ladder)
 for id,value in pairs(unlocks or {}) do for _,t in ipairs(c.Tiers) do if t.Id==id then t.Unlock=value end end end
 return c
end
local function exchange(unlocks)
 local c=table.clone(Default) c.MaxTradeHistory=100000 c.MaxOrderHistory=100000
 local e=Engine.new(c,55)
 e:AddAccount("maker",1e9,100000,0.99,false) e:AddAccount("taker",1e9,100000,0.99,false)
 return e,Funded.new(e,progression(unlocks),c)
end
local function quote(e,side,price,qty,key)
 local ok,r=e:Submit("maker",{Contract=key or "MES",Direction=side,Quantity=qty,Type="Limit",Price=price}) assert(ok,tostring(r)) return r
end
local function mark(e,price,key) -- one bot-to-bot execution moves the last traded price
 quote(e,-1,price,1,key) local ok,r=e:Submit("taker",{Contract=key or "MES",Direction=1,Quantity=1,Type="Market"}) assert(ok and r.Filled==1,"mark failed")
end
local function place(e,id,side,qty,key,extra)
 local r={Action="Place",Contract=key or "MES",Direction=side,Quantity=qty,Type="Market"}
 for k,v in pairs(extra or {}) do r[k]=v end
 local ok,res=Funded.Perform(e,id,r) assert(ok,tostring(res)) return res,r
end
local function playerAccounts(e,uid)
 local n=0 for id in pairs(e.Accounts) do if id:sub(1,#("player:"..uid..":"))=="player:"..uid..":" then n+=1 end end return n
end
local function tier(view,id) for _,row in ipairs(view.Accounts) do if row.Key==id then return row end end end
local function near(a,b) return math.abs(a-b)<1e-6 end

function Tests.Run()
 local report={} local function test(name,fn)
  local ok,result=pcall(fn) table.insert(report,{Name=name,Passed=ok,Detail=ok and result or tostring(result)})
 end
 test("First join creates nothing; Start creates exactly one $5K starter",function()
  local e,f=exchange()
  assert(f:Join("101")==nil and f:Owner("101")==nil and f:View("101").New,"New player received an implicit account")
  local ok,_,created=f:Start("101") assert(ok and created)
  local again,_,createdAgain=f:Start("101") assert(again and not createdAgain,"Second Start created an account")
  f:Start("101") assert(playerAccounts(e,"101")==1,"Duplicate starter account")
  local a=e.Accounts[f:Owner("101")]
  assert(a.Base==5000 and a.Balance==5000 and a.LossLimit==500 and a.Limit==5 and a.Group=="player:101")
  local v=f:View("101")
  assert(v.Started and v.Active=="F5K" and v.Capital==5000 and v.Earned==0 and v.Tutorial=="Pending" and v.Next.Key=="F10K")
  assert(not v.Copy.Enabled and not v.CopyAvailable,"Copy trading must start off")
  assert(f:Flag("101","TutorialSkipped") and f:View("101").Tutorial=="Skipped")
  return "One starter account; repeated Start is idempotent; tutorial state saved"
 end)
 test("Only net realized profit unlocks; starting balance and open P&L never count",function()
  local e,f=exchange() f:Start("7") local id=f:Owner("7")
  quote(e,-1,5825,2) place(e,id,1,2)
  mark(e,5900)
  assert(e:Summary(e.Accounts[id]).Unrealized>700,"Expected a large open gain")
  f:Evaluate("7") assert(f:View("7").Earned==0 and tier(f:View("7"),"F10K").State=="Locked","Unrealized gain unlocked an account")
  assert(f:TakeEvents("7")==nil)
  quote(e,1,5855,2) assert(Funded.Perform(e,id,{Action="Close",Contract="MES"}))
  assert(near(e.Accounts[id].Realized,300) and near(e.Accounts[id].Balance,5300))
  f:Evaluate("7") local v=f:View("7")
  assert(near(v.Earned,300),"Earned must exclude the $5,000 starting balance")
  assert(tier(v,"F10K").State=="Unlocked" and tier(v,"F25K").State=="Locked" and v.Next.Key=="F25K")
  local events=f:TakeEvents("7")
  assert(events and #events==2 and events[1].Kind=="FirstProfit" and events[2].Kind=="Unlocked" and events[2].Tier=="F10K")
  f:Evaluate("7") assert(f:TakeEvents("7")==nil,"Unlock announced twice")
  local saved=f:Profile("7").Tiers.F10K.UnlockedAt f:Evaluate("7") assert(f:Profile("7").Tiers.F10K.UnlockedAt==saved)
  return "Open +$750 did not unlock; realized +$300 unlocked $10K once"
 end)
 test("Activation needs an unlock, never duplicates, and switching changes the trading account",function()
  local e,f=exchange({F10K=1}) f:Start("8") local id=f:Owner("8")
  assert(not f:Activate("8","F10K"),"Activated a locked tier")
  quote(e,-1,5825,1) place(e,id,1,1) quote(e,1,5826,1) Funded.Perform(e,id,{Action="Close",Contract="MES"}) f:Evaluate("8")
  assert(not f:Activate("8","F25K"))
  assert(f:Activate("8","F10K")) local n=playerAccounts(e,"8")
  assert(f:Activate("8","F10K") and playerAccounts(e,"8")==n,"Second activation created another account")
  assert(f:Owner("8")==id,"Activation must not silently switch the traded account")
  assert(f:Select("8","F10K")) local ten=f:Owner("8") assert(ten~=id and e.Accounts[ten].Base==10000 and e.Accounts[ten].LossLimit==800)
  assert(not f:Select("8","F25K") and not f:Select("8","L50000") and f:Owner("8")==ten)
  assert(f:Select("8","F5K") and f:Owner("8")==id)
  local v=f:View("8") assert(v.ActiveCount==2 and v.Capital==15000 and near(v.Earned,5) and v.CopyAvailable)
  return "Locked/duplicate activation rejected; switching F5K <-> F10K works"
 end)
 test("Copy trading: off by default, explicit lead/followers, per-account limits, clear reports",function()
  local e,f=exchange({F10K=1,F25K=2}) f:Start("9") local five=f:Owner("9")
  assert(not f:SetCopy("9",{Enabled=1,Leader="F5K",Followers="F10K"}),"Copy enabled with one account")
  quote(e,-1,5825,1) place(e,five,1,1) quote(e,1,5827,1) Funded.Perform(e,five,{Action="Close",Contract="MES"}) f:Evaluate("9")
  assert(f:Activate("9","F10K") and f:Activate("9","F25K"))
  local lead,twentyFive=f:Resolve("9","F10K"),f:Resolve("9","F25K")
  assert(f:Plan("9",lead)==nil,"Copy active before being enabled")
  assert(not f:SetCopy("9",{Enabled=1,Leader="F10K",Followers="F50K"}))
  assert(not f:SetCopy("9",{Enabled=1,Leader="F10K",Followers="F10K"}),"Leader cannot follow itself")
  assert(f:SetCopy("9",{Enabled=1,Leader="F10K",Followers="F25K,F5K",Sizing="Same"}))
  local v=f:View("9") assert(v.Copy.Enabled and v.Copy.Followers[1]=="F5K" and tier(v,"F10K").Role=="Lead" and tier(v,"F25K").Role=="Follow")
  quote(e,-1,20485.5,20,"MNQ")
  local plan=f:Plan("9",lead)
  local res,req=place(e,lead,1,3,"MNQ",{StopTicks=40,TargetTicks=80})
  local copies=f:Mirror(plan,req,true,res,f:Context(lead,req))
  assert(copies.Total==2 and copies.Copied==1 and copies.Rejected==1,"Expected one copy and one margin rejection")
  local rejected for _,item in ipairs(copies.Items) do if item.Key=="F5K" then rejected=item end end
  assert(rejected.Status=="Rejected" and rejected.Message:find("margin"),"Rejected copy must carry the engine reason")
  local fp=e.Accounts[twentyFive].Positions.MNQ assert(fp and fp.Quantity==3 and fp.Stop and fp.Target,"Follower copy missing")
  assert(not e.Accounts[five].Positions.MNQ,"Rejected follower received a position")
  -- Linked limit orders are cancelled together.
  local limit,limitReq=place(e,lead,1,1,"MES",{Type="Limit",Price=5800})
  local placed=f:Mirror(plan,limitReq,true,limit,f:Context(lead,limitReq)) assert(placed.Copied==2)
  local linked=0 for _,o in pairs(e.Orders) do if o.Link==limit.Id then linked+=1 end end assert(linked==2)
  local cancelReq={Action="Cancel",OrderId=limit.Id} local context=f:Context(lead,cancelReq)
  local cancelOk,cancelResult=Funded.Perform(e,lead,cancelReq) local cancelled=f:Mirror(plan,cancelReq,cancelOk,cancelResult,context)
  assert(cancelled.Copied==2 and next(e.Accounts[twentyFive].OpenOrders)==nil and next(e.Accounts[five].OpenOrders)==nil)
  -- Protection moves follow the lead price; followers without that position are skipped.
  local stop=e.Accounts[lead].Positions.MNQ.Stop-5
  local amend={Action="AmendProtection",Contract="MNQ",OrderId=e.Accounts[lead].Positions.MNQ.Id,Protection="Stop",Price=stop,ExpectedPrice=e.Accounts[lead].Positions.MNQ.Stop}
  context=f:Context(lead,amend) local amendOk,amendResult=Funded.Perform(e,lead,amend) assert(amendOk,amendResult)
  local amended=f:Mirror(plan,amend,true,amendResult,context)
  assert(amended.Copied==1 and amended.Skipped==1 and e.Accounts[twentyFive].Positions.MNQ.Stop==stop)
  -- Closing the lead closes matching copies only.
  quote(e,1,20480,10,"MNQ")
  local closeReq={Action="Close",Contract="MNQ"} context=f:Context(lead,closeReq)
  local closeOk,closeResult=Funded.Perform(e,lead,closeReq)
  local closed=f:Mirror(plan,closeReq,closeOk,closeResult,context)
  assert(closed.Copied==1 and closed.Skipped==1 and not e.Accounts[twentyFive].Positions.MNQ and not e.Accounts[lead].Positions.MNQ)
  -- A rejected lead copies nothing.
  local badReq={Action="Place",Contract="MES",Direction=1,Quantity=50,Type="Market"}
  local badOk,badResult=Funded.Perform(e,lead,badReq) assert(not badOk)
  local none=f:Mirror(plan,badReq,badOk,badResult,{}) assert(none.Copied==0 and none.Skipped==2)
  return "1 copied + 1 margin rejection reported; linked cancel, SL move and close mirrored"
 end)
 test("Disabling copy keeps every position; accounts then trade independently",function()
  local e,f=exchange({F10K=1}) f:Start("11") local five=f:Owner("11")
  quote(e,-1,5825,1) place(e,five,1,1) quote(e,1,5827,1) Funded.Perform(e,five,{Action="Close",Contract="MES"}) f:Evaluate("11")
  f:Activate("11","F10K") local ten=f:Resolve("11","F10K")
  assert(f:SetCopy("11",{Enabled=1,Leader="F5K",Followers="F10K"}))
  quote(e,-1,5830,4) local plan=f:Plan("11",five)
  local res,req=place(e,five,1,1,"MES",{StopTicks=40}) f:Mirror(plan,req,true,res,f:Context(five,req))
  local before=table.clone(e.Accounts[ten].Positions.MES)
  local ok,message=f:SetCopy("11",{Enabled=0}) assert(ok and message:find("keeps its positions"))
  local after=e.Accounts[ten].Positions.MES
  assert(after and after.Quantity==before.Quantity and after.Entry==before.Entry and after.Stop==before.Stop,"Disabling copy changed a follower position")
  assert(f:Plan("11",five)==nil)
  quote(e,1,5829,2) Funded.Perform(e,five,{Action="Close",Contract="MES"})
  assert(not e.Accounts[five].Positions.MES and e.Accounts[ten].Positions.MES,"Independent close affected the other account")
  place(e,ten,1,1) assert(e.Accounts[ten].Positions.MES.Quantity==2 and f:Plan("11",ten)==nil)
  return "Follower kept its position and SL; later trades stayed independent"
 end)
 test("One player's accounts never trade against each other",function()
  local e,f=exchange({F10K=1}) f:Start("12") local five=f:Owner("12")
  quote(e,-1,5825,1) place(e,five,1,1) quote(e,1,5827,1) Funded.Perform(e,five,{Action="Close",Contract="MES"}) f:Evaluate("12")
  f:Activate("12","F10K") local ten=f:Resolve("12","F10K")
  local own=place(e,five,-1,1,"MES",{Type="Limit",Price=5830}) quote(e,-1,5831,1)
  local fill=place(e,ten,1,1)
  assert(fill.Filled==1 and fill.Average==5831 and not e.Orders[own.Id],"Cross-account self-trade was not prevented")
  assert(e.Trades[#e.Trades].Seller=="maker") e:Audit()
  return "Older same-player quote cancelled; fill came from another participant"
 end)
 test("Legacy practice accounts migrate intact and never count toward unlocks",function()
  local e,f=exchange() local legacy="player:42:50000"
  e:AddAccount(legacy,50000,40,0.8,true)
  quote(e,-1,5825,1) place(e,legacy,1,1) quote(e,1,5865.75,1) Funded.Perform(e,legacy,{Action="Close",Contract="MES"})
  quote(e,-1,5866,1) place(e,legacy,1,1,"MES",{StopTicks=80})
  local p=f:Join("42")
  assert(p and p.Migrated and #p.Legacy==1 and p.Active=="L50000" and f:Owner("42")==legacy and e.Accounts[legacy].Group=="player:42")
  local v=f:View("42")
  assert(not v.New and not v.Started and v.Earned==0 and v.Capital==0)
  assert(tier(v,"F5K").State=="Start" and v.Next.Key=="F10K","Unstarted starter must offer Start, not a $0 lock")
  assert(near(v.Legacy[1].Balance,50203.75) and v.Legacy[1].Positions==1 and e.Accounts[legacy].Positions.MES.Stop,"Legacy balance/position changed")
  f:Join("42") assert(#f:Profile("42").Legacy==1,"Join duplicated legacy accounts")
  assert(f:Start("42")) f:Evaluate("42")
  v=f:View("42") assert(v.Earned==0 and tier(v,"F10K").State=="Locked" and v.Active=="F5K","Legacy profit counted toward unlocks")
  assert(f:Select("42","L50000") and f:Owner("42")==legacy)
  return "Balance 50,203.75, open position and SL kept; legacy profit excluded"
 end)
 test("Breached accounts restart with fresh capital; realized losses still count",function()
  local e,f=exchange() f:Start("5") local id=f:Owner("5")
  quote(e,-1,5825,3) place(e,id,1,3) mark(e,5790)
  assert(not f:Restart("5","F5K"),"Restarted an account in good standing")
  quote(e,1,5790,3) e:AdvanceClock(0.25)
  local a=e.Accounts[id] assert(a.Locked and not a.Positions.MES and near(a.Realized,-525),"Loss limit did not liquidate")
  assert(not select(1,e:Submit(id,{Contract="MES",Direction=1,Quantity=1,Type="Market"})),"Breached account accepted an entry")
  assert(f:Restart("5","F5K")) local fresh=f:Owner("5")
  assert(fresh~=id and e.Accounts[fresh].Balance==5000 and not e.Accounts[fresh].Locked and playerAccounts(e,"5")==2)
  local v=f:View("5") assert(near(v.Earned,-525) and near(v.Next.Remaining,825),"Restart erased realized losses")
  assert(not f:Restart("5","F5K"))
  return "Loss -$525 kept in net profit; attempt 2 active"
 end)
 test("Copy sizing: same quantity, proportional by account size, capped",function()
  assert(Funded.Size(3,10000,25000,"Same",20)==3)
  assert(Funded.Size(3,10000,25000,"Proportional",20)==7 and Funded.Size(3,10000,5000,"Proportional",20)==1)
  assert(Funded.Size(1,10000,5000,"Proportional",20)==0 and Funded.Size(15,5000,100000,"Proportional",20)==20)
  return "3→7 at 2.5x, 1→0 skipped, capped at 20"
 end)
 test("Ladder configuration is validated",function()
  local bad=progression() bad.Tiers[2].Unlock=0 assert(not pcall(Funded.Validate,bad))
  bad=progression() bad.Tiers[3].Size=1000 assert(not pcall(Funded.Validate,bad))
  Funded.Validate(progression())
  return "Non-ascending sizes and a second free tier are rejected"
 end)
 if typeof(game)=="Instance" then
  test("Checkpoint v2 keeps profiles; v1 checkpoints restore and migrate",function()
   local Checkpoint=require(script.Parent.WorldCheckpoint) local Participants=require(script.Parent.Participants)
   local http=game:GetService("HttpService")
   local e=Engine.new(Default,4242) local population=Participants.new(e) for _=1,300 do population:Step() end
   e:AddAccount("player:88:50000",50000,40,0.8,true)
   local legacyOnly=Checkpoint.Capture(e,population)
   local f=Funded.new(e,progression(),Default) f:Join("88") f:Start("88")
   f:Profile("88").Tiers.F10K={State="Unlocked",UnlockedAt=e.Time,Earned=300,Announced=true}
   f:Activate("88","F10K") f:SetCopy("88",{Enabled=1,Leader="F10K",Followers="F5K",Sizing="Proportional"}) f:Flag("88","TutorialDone")
   local encoded=http:JSONDecode(http:JSONEncode(Checkpoint.Encode(Checkpoint.Capture(e,population))))
   assert(encoded.Version==2)
   local restored=Checkpoint.Restore(Checkpoint.Decode(encoded),Default)
   local g=Funded.new(restored,progression(),Default)
   local a,b=f:View("88"),g:View("88")
   assert(b.Copy.Enabled and b.Copy.Leader=="F10K" and b.Copy.Sizing=="Proportional" and b.Tutorial=="Done" and b.ActiveCount==2)
   assert(a.Revision==b.Revision and g:Owner("88")==f:Owner("88") and tier(b,"F10K").State=="Active")
   g:Evaluate("88") assert(g:TakeEvents("88")==nil,"Restored unlock announced again")
   legacyOnly.Version=1 legacyOnly.Engine.Profiles=nil
   local old=Checkpoint.Restore(Checkpoint.Decode(Checkpoint.Encode(legacyOnly)),Default)
   local h=Funded.new(old,progression(),Default)
   local p=h:Join("88") assert(p and p.Migrated and h:Owner("88")=="player:88:50000" and old.Accounts["player:88:50000"].Balance==50000)
   old:Audit() restored:Audit()
   return {V2Bytes=#encoded.Payload,Profiles=1,V1Migrated=true}
  end)
 end
 return report
end
return Tests
