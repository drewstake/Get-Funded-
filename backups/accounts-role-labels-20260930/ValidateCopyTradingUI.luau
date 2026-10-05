-- Accounts card and compact copy editor validation (Studio Edit mode, command bar or MCP).
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
 local function find(o,name)return o:FindFirstChild(name,true)end
 local function open(ctl)
  ctl.State.CopyDraft=nil;show(ctl,"Trade","Copy");return ctl.Root.Canvas.Dialog.Content
 end
 local function visibleIn(o,parent)
  local a,b=o.AbsolutePosition,parent.AbsolutePosition;local s,t=o.AbsoluteSize,parent.AbsoluteSize
  return a.X>=b.X-1 and a.Y>=b.Y-1 and a.X+s.X<=b.X+t.X+1 and a.Y+s.Y<=b.Y+t.Y+1
 end
 -- Layout, responsive clipping, and the changed row action.
 local sizes={{1920,1080},{1440,900},{1280,720},{1024,600},{844,390},{390,844},{360,640},{320,568}}
 for _,size in ipairs(sizes)do
  reset()
  local ctl=mount(size[1],size[2]);local tag=size[1].."x"..size[2];local canvas=ctl.Root.Canvas
  show(ctl,"Trade");local rows=rowsOf(canvas)
  check(rows[K5] and rows[K10a] and rows[K10b],"all usable accounts listed "..tag)
  check(rows[K5]:GetAttribute("Selected")==true and rows[K10b]:GetAttribute("Selected")==false,"selected marker "..tag)
  check(rows[K10a]:FindFirstChild("Name").Text=="$10K Account #1" and rows[K10b]:FindFirstChild("Name").Text=="$10K Account #2","duplicate account names "..tag)
  check(canvas.AccountSummary.AccountsCard.Count.Label.Text=="3","account count "..tag)
  local before=#sends;click(rows[K10b]);settle()
  check(#sends==before+1 and sends[#sends].Action=="Account" and p.Active==K10b and not ctl.State.Overlay,"row switches trading account "..tag)
  check(rowsOf(canvas)[K10b]:GetAttribute("Selected")==true,"selection follows reply "..tag)
  audit(canvas,tag.." Trade")
  before=#sends;click(canvas.AccountSummary.AccountsCard.OpenCopy)
  check(#sends==before and ctl.State.Overlay=="Copy","header opens copy editor "..tag)
  local dialog=canvas.Dialog;local c=dialog.Content
  check(visibleIn(dialog,ctl.Root),"dialog within viewport "..tag)
  check(visibleIn(c.SaveCopy,c),"primary action stays in view "..tag)
  check(c.FollowerList.AbsoluteSize.Y>=find(c,"Follow"..K5).AbsoluteSize.Y,"one follower fits "..tag)
  check(not find(c,"Follow"..K10a),"source excluded from targets "..tag)
  check(find(c,"Follow"..K5):GetAttribute("Checked")==true,"saved follower "..tag)
  check(c.LeaderLabel.Text=="COPY FROM" and c.FollowLabel.Text=="COPY TO","short headings "..tag)
  check(c.SaveCopy.ControlLabel.Text=="Stop Copying","active action "..tag)
  for _,name in ipairs({"Same","Proportional","SizingLabel","RemoveLeader","Rules","Unsaved","LeaderLabelHint","FollowLabelHint"})do check(not find(c,name),"obsolete control "..name.." "..tag)end
  check(dialog.Header.State.Label.Text=="ON","header status "..tag)
  click(c.LeaderSelector);c=canvas.Dialog.Content
  check(c.LeaderChoices and visibleIn(c.LeaderChoices,c),"bounded source dropdown "..tag)
  audit(dialog,tag.." Copy")
  show(ctl,"Dashboard");local cc=canvas.Dashboard.CopyTrading
  check(cc.LeaderSelector:GetAttribute("AccountKey")==K10a and find(cc,"Follow"..K5):GetAttribute("Checked"),"shared editor "..tag)
  check(not find(cc,"SizingLabel") and not find(cc,"RemoveLeader"),"simplified Accounts tab "..tag)
  audit(canvas.Dashboard,tag.." Accounts")
  ctl:Destroy()
 end
 report.SizesPassed=#sizes
 -- Start / edit / save / stop, duplicate identities, pending guard, and draft discard.
 for _,size in ipairs({{1440,900},{390,844}})do
  reset();local ctl=mount(size[1],size[2]);local canvas=ctl.Root.Canvas;local tag=size[1].."x"..size[2]
  local c=open(ctl)
  click(find(c,"Follow"..K10b));c=canvas.Dialog.Content
  check(c.SaveCopy.ControlLabel.Text=="Save Changes" and c.StopCopy,"edited setup retains stop action")
  check(not table.find(p.Copy.Followers,K10b),"draft must not reach server")
  c=open(ctl);check(not find(c,"Follow"..K10b):GetAttribute("Checked"),"reopen discards draft")
  click(find(c,"Follow"..K10b));c=canvas.Dialog.Content
  local before=#sends;click(c.SaveCopy);check(canvas.Dialog.Content.SaveCopy.ControlLabel.Text=="Saving…","pending label")
  click(canvas.Dialog.Content.SaveCopy);check(#sends==before+1,"pending blocks duplicate send");settle()
  check(table.find(p.Copy.Followers,K10b) and canvas.Dialog.Content.SaveCopy.ControlLabel.Text=="Stop Copying","save applied")
  c=canvas.Dialog.Content;click(c.LeaderSelector);click(find(canvas.Dialog.Content,"ChooseLeader"..K10b));c=canvas.Dialog.Content
  check(not find(c,"Follow"..K10b) and find(c,"Follow"..K5):GetAttribute("Checked"),"new source excluded and other checks kept")
  click(c.SaveCopy);settle();check(p.Copy.Leader==K10b,"second same-size account becomes source")
  c=canvas.Dialog.Content;click(find(c,"Follow"..K5));c=canvas.Dialog.Content
  check(not c.SaveCopy.Active and c.StopCopy.Active,"empty active draft can still stop")
  click(c.StopCopy);settle();check(not p.Copy.Enabled,"stop applied")
  c=canvas.Dialog.Content;check(c.SaveCopy.ControlLabel.Text=="Start Copying","saved selection retained while off")
  click(c.SaveCopy);settle();check(p.Copy.Enabled and p.Copy.Leader==K10b,"restart retained setup")
  show(ctl,"Dashboard");local cc=canvas.Dashboard.CopyTrading
  check(cc.LeaderSelector:GetAttribute("AccountKey")==K10b,"Accounts tab reflects saved setup")
  click(cc.SaveCopy);settle();check(not p.Copy.Enabled,"stop from Accounts tab")
  report.Flows[tag]="switch, discard draft, save, duplicate-send guard, change source, stop incomplete draft, restart, cross-entry sync passed"
  ctl:Destroy()
 end
 -- Existing proportional setups are preserved although their control has been removed.
 f:SetCopy(uid,{Enabled=true,Leader=K10a,Followers=K5,Sizing="Proportional"})
 local ctl=mount(1440,900);local c=open(ctl)
 click(find(c,"Follow"..K10b));click(ctl.Root.Canvas.Dialog.Content.SaveCopy);settle()
 check(sends[#sends].Req.Sizing=="Proportional" and p.Copy.Sizing=="Proportional","hidden sizing must not change")
 ctl:Destroy()
 -- A fresh setup, without a retained leader, cannot start until both choices exist.
 p.Copy={Enabled=false,Followers={},Sizing="Same"}
 ctl=mount(390,844);c=open(ctl)
 check(not c.SaveCopy.Active and c.SaveCopy.ControlLabel.Text=="Choose an account","fresh setup")
 click(c.LeaderSelector);click(find(ctl.Root.Canvas.Dialog.Content,"ChooseLeader"..K10b));c=ctl.Root.Canvas.Dialog.Content
 check(not c.SaveCopy.Active,"requires destination")
 click(find(c,"Follow"..K10a));click(ctl.Root.Canvas.Dialog.Content.SaveCopy);settle()
 check(p.Copy.Enabled and p.Copy.Leader==K10b and p.Copy.Followers[1]==K10a,"start fresh setup")
 ctl:Destroy()
 -- Overflow: five followers scroll while the action stays fixed at every viewport.
 p.WalletCents=100000000
 for _=1,4 do check(f:Purchase(uid,"F10K",p.PurchaseSequence+1),"overflow fixture purchase")end
 for _,size in ipairs(sizes)do
  ctl=mount(size[1],size[2]);c=open(ctl)
  check(c.FollowerList.CanvasSize.Y.Offset>c.FollowerList.Size.Y.Offset and c.FollowerList.ScrollBarThickness>0,"followers scroll")
  check(visibleIn(c.SaveCopy,c),"overflow action visible")
  local lastKey=key("F10K",6)
  c.FollowerList.CanvasPosition=Vector2.new(0,10000);task.wait()
  click(find(c,"Follow"..lastKey));c=ctl.Root.Canvas.Dialog.Content
  check(find(c,"Follow"..lastKey):GetAttribute("Checked"),"last follower selectable")
  check(c.FollowerList.CanvasPosition.Y>0,"follower scroll retained after toggle")
  audit(ctl.Root.Canvas.Dialog,"overflow "..size[1].."x"..size[2]);ctl:Destroy()
 end
 report.OverflowSizesPassed=#sizes
 -- Existing account activation remains reachable.
 ctl=mount(1440,900);show(ctl,"Dashboard")
 click(ctl.Root.Canvas.Dashboard.TierF25K.Action);settle()
 check(sends[#sends].Action=="Activate" and p.Tiers.F25K.Claimed,"free activation unchanged")
 ctl:Destroy()

end)
for _,item in ipairs(live)do pcall(function()item[1]:Destroy();item[2]:Destroy()end)end
gui:Destroy();shared:Destroy();server:Destroy()
if not ok then report.Error=tostring(err)end
return H:JSONEncode(report)
