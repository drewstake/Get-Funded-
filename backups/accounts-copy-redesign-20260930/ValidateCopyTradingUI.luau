-- Copy-trading UI + account-name validation (Studio Edit mode, run from the command bar or MCP).
-- Native fixtures with the real FundedAccounts/MarketEngine and TerminalUI; only Session:Send is stubbed,
-- and it forwards Copy/Account/Activate/Flag to FundedAccounts like the server does. No remotes,
-- DataStores or player data. Everything it creates is removed. Returns a JSON report.
local H=game:GetService("HttpService")
local shared=game.ReplicatedStorage.MarketReign:Clone();shared.Name="CopyTradingUI";shared.Parent=game.ReplicatedStorage
local server=game.ServerScriptService.MarketReign:Clone();server.Name="CopyTradingUI";server.MarketServer.Enabled=false;server.Parent=game.ServerScriptService
local gui=Instance.new("ScreenGui");gui.Name="CopyTradingUI";gui.IgnoreGuiInset=true;gui.Parent=game.StarterGui
shared.TerminalUI.Source=shared.TerminalUI.Source:gsub('b%.Activated:Connect%(function%(%.%.%.%)',function()
 return 'local hook=Instance.new("BindableFunction");hook.Name="TestActivate";hook.OnInvoke=fn;hook.Parent=b;b.Activated:Connect(function(...)'
end)
local report={Checks=0,Layouts=0,Issues={},Flows={},Messages={}}
local live={}
local function check(v,msg) report.Checks+=1;assert(v,msg) end
local function deep(v)if type(v)~="table"then return v end local o={}for k,x in pairs(v)do o[k]=deep(x)end return o end
local function child(o,name) return o and o:FindFirstChild(name) end
local function label(o,name) local c=child(o,name) return c and c.Text end
local function audit(root,tag)
 for _,v in ipairs(root:GetDescendants())do
  if (v:IsA("TextLabel")or v:IsA("TextButton")) and v.Visible then
   if v.Text:match("#%d") then table.insert(report.Issues,tag.." sequence text '"..v.Text.."' at "..(v:GetFullName():gsub(".*Canvas%.",""))) end
   if v:IsA("TextLabel") and v.Text~="" and not v.TextFits and not v.TextScaled and v.TextTruncate==Enum.TextTruncate.None then
    table.insert(report.Issues,tag.." text overflow "..(v:GetFullName():gsub(".*Canvas%.","")))
   end
  end
 end
 report.Layouts+=1
end
local ok,err=pcall(function()
 local E=require(server.MarketEngine);local F=require(server.FundedAccounts);local C=require(shared.MarketConfig);local L=require(shared.ProgressionConfig)
 local e=E.new(C,85);local f=F.new(e,L,C);local uid="fixture"
 f:Start(uid);f:Flag(uid,"TutorialDone")
 local p=f:Profile(uid);local starter=e.Accounts[f:Owner(uid)]
 starter.Realized=9000;starter.Balance=14000;f:Evaluate(uid)
 check(p.Tiers.F10K and p.Tiers.F25K,"fixture tiers unlocked")
 check(f:Activate(uid,"F10K"),"activate 10K")
 p.WalletCents=2000000
 local okBuy,msg=f:Purchase(uid,"F10K",p.PurchaseSequence+1);check(okBuy,"buy second 10K: "..tostring(msg))
 local function key(tier,n) local list={} for _,entry in ipairs(f:Entries(p))do if entry.Tier==tier then table.insert(list,entry.Key)end end return list[n] end
 local K5,K10a,K10b=key("F5K",1),key("F10K",1),key("F10K",2)
 check(K5 and K10a and K10b and K10a~=K10b,"two separate $10K instances")
 local function reset() f:SetCopy(uid,{Enabled=true,Leader=K10a,Followers=K5,Sizing="Same"});f:Select(uid,K5) end
 reset()
 local pf=f:View(uid)
 for _,row in ipairs(pf.Accounts)do check(not row.Name:find("#") and not row.Short:find("#"),"server name has sequence: "..row.Name) end
 check(pf.ActiveName=="$5K Account","active name "..tostring(pf.ActiveName))
 local claimable=0;for _,t in ipairs(pf.Tiers)do if t.Claimable then claimable+=1 end end;check(claimable==1,"F25K should be claimable")
 local sends={};local sessions={}
 local M=require(shared.MarketClient);local original=M.New
 M.New=function()
  local a=e.Accounts[f:Owner(uid)]
  local snapshot=e:Snapshot(a.Id,"ES","1m",true);snapshot.CandlesBySeries={}
  local s=original(nil,true,snapshot);table.insert(sessions,s)
  s.Preview=false;s.Ready=true;s.CanTrade=true;s.AccountKey=p.Active;s.AccountToken=a.Id
  s.Portfolio=f:View(uid);s.Stats=f:Stats(uid);s.SummaryData=e:Summary(a);s.StatsAt=1
  function s:Send(action,req)
   table.insert(sends,{Action=action,Req=deep(req)});local id=#sends
   task.delay(.25,function() -- long enough to observe the pending state
    local yes,message
    if action=="Copy"then yes,message=f:SetCopy(uid,req)
    elseif action=="Account"then yes,message=f:Select(uid,req.Key)
    elseif action=="Activate"then yes,message=f:Activate(uid,req.Tier)
    elseif action=="Flag"then yes,message=f:Flag(uid,req.Stage)
    else yes,message=true,"Fixture" end
    table.insert(report.Messages,action..": "..tostring(message))
    local owner=e.Accounts[f:Owner(uid)]
    s.Portfolio=f:View(uid);s.AccountKey=p.Active;s.AccountToken=owner.Id;s.SummaryData=e:Summary(owner)
    s.Replies:Fire({Kind=action,RequestId=id,Ok=yes,Message=message,Tier=req.Tier,Key=req.Key});s.Changed:Fire()
   end)
   return true,"Sent","Orders",id
  end
  return s
 end
 local UI=require(shared.TerminalUI)
 local function mount(w,h)
  local host=Instance.new("Frame");host.Size=UDim2.fromOffset(w,h);host.Parent=gui
  local ctl=UI.Mount(host);table.insert(live,{ctl,host});task.wait();task.wait()
  return ctl,host
 end
 local function settle() task.wait(.4);task.wait();task.wait() end
 local function render(ctl) ctl.Root.UIDiagnostics:Invoke("Render");task.wait();task.wait();check(not ctl.Root:GetAttribute("RenderError"),tostring(ctl.Root:GetAttribute("RenderError"))) end
 local function show(ctl,screen,overlay) ctl.State.Screen=screen;ctl.State.Nav=screen;ctl.State.Overlay=overlay;ctl.State.Sheet=false;ctl.State.Toast=nil;render(ctl) end
 local function click(b) check(b and b:FindFirstChild("TestActivate"),"missing button "..tostring(b and b:GetFullName()));b.TestActivate:Invoke();task.wait();task.wait() end
 local function list(canvas) return canvas.AccountSummary.AccountsCard.AccountList end
 local function rowsOf(canvas) local out={} for _,r in ipairs(list(canvas):GetChildren())do if r:GetAttribute("AccountKey")then out[r:GetAttribute("AccountKey")]=r end end return out end
 -- 1. Layout and content at every supported size.
 local sizes={{1920,1080},{1440,900},{1280,720},{1024,600},{844,390},{390,844},{360,640},{320,568}}
 for _,size in ipairs(sizes)do
  local ctl=mount(size[1],size[2]);local tag=size[1].."x"..size[2]
  local canvas=ctl.Root.Canvas
  show(ctl,"Trade")
  local rows=rowsOf(canvas)
  check(rows[K5] and rows[K10a] and rows[K10b],"usable accounts not listed individually "..tag)
  check(rows[K10a]:GetAttribute("Role")=="Leader" and rows[K5]:GetAttribute("Role")=="Follower" and rows[K10b]:GetAttribute("Role")==nil,"roles wrong "..tag)
  check(rows[K5]:GetAttribute("Selected")==true and rows[K10a]:GetAttribute("Selected")==false and rows[K10b]:GetAttribute("Selected")==false,"selected marker "..tag)
  check(label(child(rows[K10a],"Role"),"Label")=="Leader" and label(child(rows[K5],"Role"),"Label")=="Follower" and not child(rows[K10b],"Role"),"role labels "..tag)
  check(label(rows[K10a],"Name")=="$10K Account" and label(rows[K10b],"Name")=="$10K Account" and label(rows[K5],"Name")=="$5K Account","names "..tag)
  audit(canvas,tag.." Trade")
  local before=#sends;local active=ctl.Root:GetAttribute("ActiveAccount")
  click(rows[K10b])
  check(ctl.State.Overlay=="Copy" and #sends==before and ctl.Root:GetAttribute("ActiveAccount")==active and ctl.State.Screen=="Trade","row click must only open copy setup "..tag)
  local dialog=canvas.Dialog;local content=dialog.Content
  check(dialog.AbsoluteSize.X<=size[1] and dialog.AbsoluteSize.Y<=size[2],"copy dialog exceeds viewport "..tag)
  check(label(content.LeaderSelector,"Name")=="$10K Account" and content.LeaderSelector:GetAttribute("AccountKey")==K10a,"leader shown "..tag)
  check(not content:FindFirstChild("Follow"..K10a),"leader listed as follower "..tag)
  check(content["Follow"..K5]:GetAttribute("Checked")==true and content["Follow"..K10b]:GetAttribute("Checked")==false,"followers reflect saved "..tag)
  check(content:FindFirstChild("RemoveLeader") and content.SaveCopy.ControlLabel.Text:find("Saved"),"actions "..tag)
  audit(dialog,tag.." Copy")
  show(ctl,"Dashboard")
  local board=canvas.Dashboard
  check(not board:FindFirstChild("AccessTitle"),"permanent tier access title remains "..tag)
  for _,t in ipairs(pf.Tiers)do check(not board:FindFirstChild("Access"..t.Key),"access card remains "..tag)end
  check(board:FindFirstChild("ReadyTitle") and board:FindFirstChild("TierF25K"),"claimable tier activation missing "..tag)
  local cc=board.CopyTrading
  check(cc.LeaderSelector:GetAttribute("AccountKey")==K10a and cc["Follow"..K5]:GetAttribute("Checked")==true,"accounts tab copy editor out of sync "..tag)
  check(label(child(board["Tier"..K10a],"Role"),"Label")=="LEADER" and label(child(board["Tier"..K5],"Role"),"Label")=="FOLLOWER" and not child(board["Tier"..K10b],"Role"),"account card roles "..tag)
  for _,v in ipairs(board:GetDescendants())do if (v:IsA("TextLabel")or v:IsA("TextButton"))and v.Text:lower():find("permanent tier access")then table.insert(report.Issues,tag.." permanent tier access text "..v:GetFullName())end end
  audit(board,tag.." Accounts")
  ctl:Destroy()
 end
 report.SizesPassed=#sizes
 -- 2. End-to-end flows on desktop and phone.
 local function flow(w,h)
  reset();for _,s in ipairs(sessions)do s.Portfolio=f:View(uid);s.AccountKey=p.Active end
  local ctl=mount(w,h);local canvas=ctl.Root.Canvas;local tag="flow "..w.."x"..h;local steps={}
  show(ctl,"Trade")
  click(list(canvas)["Account"..K10a])
  local c=canvas.Dialog.Content
  click(c["Follow"..K10b]);c=canvas.Dialog.Content
  check(c["Follow"..K10b]:GetAttribute("Checked")==true and c.SaveCopy:GetAttribute("Changed")==true and c:FindFirstChild("Unsaved"),"draft toggle "..tag)
  check(list(canvas)["Account"..K10b]:GetAttribute("Role")==nil,"unsaved change leaked to trade list "..tag)
  ctl.State.Overlay=nil;render(ctl)
  click(list(canvas)["Account"..K5]);c=canvas.Dialog.Content
  check(c["Follow"..K10b]:GetAttribute("Checked")==false and c.SaveCopy:GetAttribute("Changed")==false,"reopen must show saved config "..tag)
  table.insert(steps,"unsaved draft discarded on reopen")
  click(c["Follow"..K10b]);c=canvas.Dialog.Content
  local n=#sends;click(c.SaveCopy);check(canvas.Dialog.Content.SaveCopy.ControlLabel.Text=="Saving…","pending label "..tag);settle()
  local last=sends[#sends]
  check(#sends==n+1 and last.Action=="Copy" and last.Req.Enabled==1 and last.Req.Leader==K10a,"save request "..tag)
  local fol={};for k in last.Req.Followers:gmatch("[^,]+")do fol[k]=true end
  check(fol[K5] and fol[K10b] and not fol[K10a],"saved followers "..tag)
  check(list(canvas)["Account"..K10b]:GetAttribute("Role")=="Follower","trade list not updated after save "..tag)
  check(ctl.State.Overlay=="Copy" and canvas.Dialog.Content.SaveCopy.ControlLabel.Text:find("Saved") and ctl.State.PendingCopy==nil,"popup shows saved state "..tag)
  table.insert(steps,"follower saved; trade list shows Follower")
  click(canvas.Dialog.Content.LeaderSelector)
  check(canvas.Dialog.Content.LeaderSelector:GetAttribute("Open")==true and canvas.Dialog.Content:FindFirstChild("ChooseLeader"..K10b),"leader list opens "..tag)
  click(canvas.Dialog.Content["ChooseLeader"..K5]);c=canvas.Dialog.Content
  check(c.LeaderSelector:GetAttribute("AccountKey")==K5 and not c:FindFirstChild("Follow"..K5) and c:FindFirstChild("Follow"..K10a),"leader change "..tag)
  check(c["Follow"..K10a]:GetAttribute("Checked")==false and c["Follow"..K10b]:GetAttribute("Checked")==true,"follower state after leader change "..tag)
  check(list(canvas)["Account"..K10a]:GetAttribute("Role")=="Leader","leader change not saved yet "..tag)
  click(c["Follow"..K10a]);click(canvas.Dialog.Content.SaveCopy);settle()
  check(sends[#sends].Req.Leader==K5,"leader change saved "..tag)
  local L2=list(canvas)
  check(L2["Account"..K5]:GetAttribute("Role")=="Leader" and L2["Account"..K10a]:GetAttribute("Role")=="Follower" and L2["Account"..K10b]:GetAttribute("Role")=="Follower","roles after leader change "..tag)
  check(p.Active==K5 and L2["Account"..K5]:GetAttribute("Selected")==true,"active account unchanged "..tag)
  table.insert(steps,"leader changed to $5K; roles swapped; trading account unchanged")
  show(ctl,"Dashboard")
  local cc=canvas.Dashboard.CopyTrading
  check(cc.LeaderSelector:GetAttribute("AccountKey")==K5 and cc["Follow"..K10a]:GetAttribute("Checked")==true and cc["Follow"..K10b]:GetAttribute("Checked")==true,"accounts tab sync "..tag)
  check(canvas.Dashboard["Tier"..K5].Role.Label.Text=="LEADER","accounts card role sync "..tag)
  table.insert(steps,"Accounts tab shows the same saved setup")
  click(cc.RemoveLeader);settle()
  check(sends[#sends].Action=="Copy" and sends[#sends].Req.Enabled==0 and not p.Copy.Enabled,"remove leader request "..tag)
  cc=canvas.Dashboard.CopyTrading
  check(cc.LeaderSelector:GetAttribute("AccountKey")==nil and cc.State.Label.Text=="OFF" and not cc:FindFirstChild("RemoveLeader"),"leader removed "..tag)
  show(ctl,"Trade")
  for _,r in ipairs(list(canvas):GetChildren())do if r:GetAttribute("AccountKey")then check(r:GetAttribute("Role")==nil,"role remains after removal "..tag)end end
  table.insert(steps,"Remove leader turned copying off; no roles shown")
  click(list(canvas)["Account"..K10b]);c=canvas.Dialog.Content
  check(c.SaveCopy.ControlLabel.Text=="Choose a leader to start" and c.SaveCopy.Active==false,"no leader state "..tag)
  click(c.LeaderSelector);click(canvas.Dialog.Content["ChooseLeader"..K10b]);c=canvas.Dialog.Content
  check(c.SaveCopy.ControlLabel.Text=="Check a follower to start","needs follower "..tag)
  click(c["Follow"..K10a]);c=canvas.Dialog.Content
  check(c.SaveCopy.ControlLabel.Text=="Start copying","start label "..tag)
  click(c.SaveCopy);settle()
  check(p.Copy.Enabled and p.Copy.Leader==K10b and #p.Copy.Followers==1 and p.Copy.Followers[1]==K10a,"start copying with second $10K as leader "..tag)
  L2=list(canvas)
  check(L2["Account"..K10b]:GetAttribute("Role")=="Leader" and L2["Account"..K10a]:GetAttribute("Role")=="Follower" and L2["Account"..K5]:GetAttribute("Role")==nil,"same-size accounts keep separate roles "..tag)
  table.insert(steps,"second $10K leads the first $10K; $5K not participating")
  ctl.State.Overlay="Accounts";render(ctl)
  click(canvas.Dialog.Content["Account"..K10b]);settle()
  check(sends[#sends].Action=="Account" and sends[#sends].Req.Key==K10b and p.Active==K10b,"switch to second $10K "..tag)
  show(ctl,"Trade");L2=list(canvas)
  check(L2["Account"..K10b]:GetAttribute("Selected")==true and L2["Account"..K10a]:GetAttribute("Selected")==false,"selected marker follows the switched account "..tag)
  check(ctl.Root:GetAttribute("ActiveAccount")==K10b,"active attribute "..tag)
  local header=canvas:FindFirstChild("Sidebar") and canvas.Sidebar.AccountSwitcher.Label.Text or canvas.TopNavigation.Account:FindFirstChild("Name").Text
  check(header:find("%$10K Account") and not header:find("#"),"header name "..header)
  table.insert(steps,"switched to the second $10K separately; header '"..header.."'")
  report.Flows[tag]=steps
  ctl:Destroy()
 end
 flow(1440,900);flow(390,844)
 -- 3. The free first activation stays reachable from the Accounts tab.
 reset()
 local ctl=mount(1440,900);show(ctl,"Dashboard")
 click(ctl.Root.Canvas.Dashboard.TierF25K.Action);settle()
 check(sends[#sends].Action=="Activate" and sends[#sends].Req.Tier=="F25K" and p.Tiers.F25K.Claimed,"free activation from Accounts tab")
 show(ctl,"Dashboard");check(not ctl.Root.Canvas.Dashboard:FindFirstChild("ReadyTitle"),"ready card should go away after activation")
 check(ctl.Root.Canvas.Dashboard:FindFirstChild("TierF25K:1"),"activated $25K account card")
 report.Activation="Ready card activated F25K; card replaced by the new account"
 ctl:Destroy()
end)
for _,item in ipairs(live)do pcall(function()item[1]:Destroy();item[2]:Destroy()end)end
gui:Destroy();shared:Destroy();server:Destroy()
if not ok then report.Error=tostring(err)end
return H:JSONEncode(report)
