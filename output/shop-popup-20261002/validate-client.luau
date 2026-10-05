-- Temporary Studio client fixture; removed from StarterPlayer after validation.
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local pg=Players.LocalPlayer:WaitForChild("PlayerGui")
local root,hook
repeat
 local gui=pg:FindFirstChild("MarketReign")
 root=gui and gui:FindFirstChild("Workspace");hook=root and root:FindFirstChild("UIDiagnostics")
 Run.Heartbeat:Wait()
until hook and root.Parent
local originalSize=root.Size
local report={Layouts={},Issues={},LayoutChecks=0,Assets={}}
local deadline=os.clock()+30
repeat Run.Heartbeat:Wait()until root:GetAttribute("Screen")~="Loading"or os.clock()>deadline
local originalScreen=hook:Invoke("Get","Screen")
local originalOverlay=hook:Invoke("Get","Overlay")
local originalQty=hook:Invoke("Get","Qty")
local originalContract=hook:Invoke("Get","Contract")
local ok,err=xpcall(function()
 for _,size in ipairs({{320,568},{390,844},{844,390},{1280,720},{1440,900},{1920,1080}})do
  root.Size=UDim2.fromOffset(size[1],size[2]);Run.Heartbeat:Wait()
  for _,screen in ipairs({"Trade","Stats","Progress","Leaderboard"})do
   hook:Invoke("Set","Screen",screen);hook:Invoke("Set","Overlay","Shop")
   task.wait(.35)
   local canvas=root.Canvas
   local nav=canvas:FindFirstChild("Sidebar")or canvas:FindFirstChild("MobileNavigation")
   assert(nav and nav.NavShop,"Shop navigation missing")
   assert(root:GetAttribute("Screen")==screen and hook:Invoke("Get","Nav")==screen,"Shop changed underlying screen")
   local dialog=canvas:FindFirstChild("ShopDialog");assert(dialog,"Shop did not open")
   assert(canvas.OverlayBackdrop and canvas.OverlayBackdrop.Active,"Modal backdrop missing")
   assert(dialog.Active,"Modal interior must block input behind the popup")
   local ap,sz=dialog.AbsolutePosition-root.AbsolutePosition,dialog.AbsoluteSize
   assert(ap.X>=-1 and ap.Y>=-1 and ap.X+sz.X<=size[1]+1 and ap.Y+sz.Y<=size[2]+1,"Popup outside viewport")
   assert(dialog.CloseShop.Size.X.Offset>=44 and dialog.CloseShop.Size.Y.Offset>=44,"Close target too small")
   for _,v in ipairs(dialog:GetDescendants())do
    if v:IsA("TextLabel") and not v.TextFits and not v.TextScaled and v.Text~="" then
     table.insert(report.Issues,size[1].."x"..size[2].." "..v:GetFullName().." "..v.Text)
    end
    if v.Name=="Availability"then assert(not v.Active and not v.Interactable and v:GetAttribute("PurchaseEnabled")==false,"Unconfigured purchase enabled")end
    if v:IsA("ImageLabel")then report.Assets[v.Image]=v.IsLoaded end
   end
   report.LayoutChecks+=1
   hook:Invoke("Set","Overlay",nil)
   assert(hook:Invoke("Get","Qty")==originalQty and hook:Invoke("Get","Contract")==originalContract,"Shop changed order state")
  end
  table.insert(report.Layouts,size[1].."x"..size[2])
 end
end,debug.traceback)
report.Ok=ok;report.Error=not ok and tostring(err)or nil
root.Size=originalSize;hook:Invoke("Set","Screen",originalScreen);hook:Invoke("Set","Overlay",originalOverlay)
local result=Instance.new("StringValue");result.Name="ShopValidationResult";result.Value=Http:JSONEncode(report);result.Parent=pg
print("SHOP_VALIDATION "..result.Value)
