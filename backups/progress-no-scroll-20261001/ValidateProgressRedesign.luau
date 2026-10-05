-- Disposable UI fixture. Does not open profiles, send trades, or access persistence.
local shared=game.ReplicatedStorage.MarketReign:Clone()
shared.Name="ProgressRedesignQA";shared.Parent=game.ReplicatedStorage
local gui=Instance.new("ScreenGui");gui.Name="ProgressRedesignQA";gui.IgnoreGuiInset=true;gui.DisplayOrder=150;gui.Parent=game.StarterGui
local ctl
local ok,result=xpcall(function()
 local Market=require(shared.MarketClient);local UI=require(shared.TerminalUI)
 local ladder=require(shared.ProgressionConfig)
 local original=Market.New;local view
 Market.New=function()
  local session=original(nil,true)
  session.Ready=true;session.Portfolio=view;session.AccountKey="Fixture";session.AccountToken="Fixture"
  session.ConnectionStatus="ISOLATED UI PREVIEW";session.CanTrade=false
  return session
 end
 local function portfolio(state)
  local earned=state=="Complete" and 7 or state=="Negative" and 2 or state=="Halfway" and 2 or state=="Balance" and 3 or state=="Legacy" and 2 or 0
  local pf={Rank=earned==7 and "Get Funded Legend" or earned>=2 and "First Win" or "New Trader",Tutorial="Done",Run=1,RunProfit=5812.5,
   Earned=state=="Negative" and -44796.25 or state=="Halfway" and 250 or state=="Complete" and 95000 or state=="Balance" and 2800 or 0,
   Titles={},Milestones={},Accounts={{Key="Fixture",State="Live",Balance=5000,CanRestart=true}},Active="Fixture",Failed=state=="Failed",Migrated=state=="Legacy"}
  for i,m in ipairs(ladder.Milestones)do
   local goal=m.Profit or m.Goal
   local row={Key=m.Id,Kind=m.Kind,Name=m.Name,Title=m.Title,Goal=goal,Progress=i<=earned and goal or 0,Earned=i<=earned}
   if i==earned+1 and state=="Halfway" then row.Progress=250 end
   if i==earned+1 and state=="Balance" then row.Progress=2800 end
   table.insert(pf.Milestones,row)
   if row.Earned then table.insert(pf.Titles,row.Title)elseif not pf.Next then pf.Next=row end
  end
  if state=="Legacy" then table.insert(pf.Titles,"Legacy Market Champion")end
  return pf
 end
 local report={Layouts={},Issues={}}
 for _,state in ipairs({"Fresh","Negative","Halfway","Balance","Complete","Legacy","Failed"})do
  view=portfolio(state)
  for _,size in ipairs({{320,568},{390,844},{844,390},{1000,600},{1440,900},{1920,1080}})do
   local host=Instance.new("Frame");host.Name="Viewport";host.Size=UDim2.fromOffset(size[1],size[2]);host.Parent=gui
   task.wait(.04)
   ctl=UI.Mount(host);ctl.State.Screen="Progress";ctl.State.CoachDismissed=true
   ctl.Root.UIDiagnostics:Invoke("Render");task.wait(.06)
   local issueStart=#report.Issues
   local err=ctl.Root:GetAttribute("RenderError");if err then table.insert(report.Issues,state..": "..err)end
   local sc=assert(ctl.Root.Canvas:FindFirstChild("Progress"),"Progress view missing")
   local content=sc.Content;local hero=content.NextMilestone
   local expected=state=="Complete" and 1 or state=="Halfway" and .5 or state=="Balance" and .56 or 0
   assert(math.abs(hero.Track:GetAttribute("Progress")-expected)<.001,"Incorrect progress in "..state)
   assert(hero.Track.Fill.Visible==(expected>0),"Zero progress should not have a filled sliver")
   if state=="Negative" then assert(hero.ProgressNote.Text:find("44,796"),"Loss recovery explanation missing")end
   if state=="Legacy" then assert(content.EarnedTitles:FindFirstChild("Legacy3"),"Legacy title missing")end
   if state=="Balance" then assert(hero.Goal.Text:find("balance and earn"),"Both balance requirements must be visible")end
   if state=="Failed" then assert(content:FindFirstChildWhichIsA("TextButton",true),"Restart button missing")end
   for _,obj in ipairs(sc:GetDescendants())do
    if obj:IsA("TextLabel") and obj.Visible and obj.Text~="" and not obj.TextFits and not obj.TextScaled then
     table.insert(report.Issues,string.format("%s %dx%d overflow %s: %s",state,size[1],size[2],obj:GetFullName(),obj.Text))
    end
    if obj:IsA("GuiObject") and obj.Visible and obj.Parent:IsA("GuiObject") and obj.Parent~=sc then
     local pw=obj.Parent.AbsoluteSize.X
     local width=pw*obj.Size.X.Scale+obj.Size.X.Offset
     local left=pw*obj.Position.X.Scale+obj.Position.X.Offset-width*obj.AnchorPoint.X
     if left<-.5 or left+width>pw+1 then
      table.insert(report.Issues,state.." horizontal bounds: "..obj:GetFullName())
     end
    end
   end
   table.insert(report.Layouts,{State=state,Width=size[1],Height=size[2],Issues=#report.Issues-issueStart,CanvasHeight=sc.CanvasSize.Y.Offset,ActualRoot=tostring(ctl.Root.AbsoluteSize),ProgressWidth=sc.Size.X.Offset})
   ctl:Destroy();ctl=nil;host:Destroy()
  end
 end
 return report
end,debug.traceback)
if ctl then ctl:Destroy()end
gui:Destroy();shared:Destroy()
assert(ok,result)
local H=game:GetService("HttpService");H:PostAsync("http://127.0.0.1:8774/results",H:JSONEncode(result),Enum.HttpContentType.ApplicationJson)
return result
