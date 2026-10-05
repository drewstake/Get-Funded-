from pathlib import Path
p=Path(__file__).resolve().parents[1]/'src/ChartView.luau'
s=p.read_text(encoding='utf-8')
a=s.index('  tx+=12\n  local items=')
b=s.index('\n  if w>700 then',a)
s=s[:a]+'''  tx+=12
  local items={"Pan","Crosshair","Trend","Line","Rect","|","Magnet","Clear"}
  local room=w-tx-(w>700 and 90 or 8)
  local bw=math.clamp(math.floor((room-12)/7),28,40)
  for _,name in ipairs(items)do
   if name=="|" then
    local divider=frame(tb,"ToolDivider",tx+4,10,1,toolsH-20,C.Cyan);divider.BackgroundTransparency=.6;tx+=12
   else
    local active=s.Tool==name or name=="Magnet"and s.Magnet
    local fg=active and C.Text or Color3.fromRGB(174,210,250)
    local b=button(tb,"Tool"..name,"",tx,4,bw-5,toolsH-8,function()self:Command(name)end,C.Panel,fg,14)
    ctx.control(b,active);b.Corners.CornerRadius=UDim.new(0,8)
    b.Border.Color=active and Color3.fromRGB(192,144,255)or Color3.fromRGB(26,88,166)
    b.Border.Thickness=active and 2 or 1
    b:SetAttribute("Tooltip",name=="Magnet"and"Magnet (hold Ctrl)"or name=="Clear"and"Clear drawings on this chart"or TOOL_NAMES[name])
    b:SetAttribute("Active",active==true)
    local cx,cy=(bw-5)/2,(toolsH-8)/2
    local ink=frame(b,"ToolIcon",cx-9,cy-9,18,18,C.Panel,b.ZIndex+2);ink.BackgroundTransparency=1
    local function path(x1,y1,x2,y2)line(ink,"Ink",x1,y1,x2,y2,fg,2,ink.ZIndex)end
    local function dot(x,y)
     local d=frame(ink,"Ink",x-2,y-2,4,4,fg,ink.ZIndex);round(d,2)
    end
    if name=="Pan"then
     path(4,2,4,15);path(4,2,14,11);path(4,15,8,11);path(8,11,14,11);path(9,12,12,17)
    elseif name=="Crosshair"then
     path(9,0,9,5);path(9,13,9,18);path(0,9,5,9);path(13,9,18,9);dot(9,9)
    elseif name=="Trend"then path(3,15,15,3);dot(3,15);dot(15,3)
    elseif name=="Line"then path(1,9,17,9);dot(9,9)
    elseif name=="Rect"then path(2,3,16,3);path(16,3,16,15);path(16,15,2,15);path(2,15,2,3)
    elseif name=="Magnet"then
     path(3,2,3,11);path(3,11,6,15);path(6,15,12,15);path(12,15,15,11);path(15,11,15,2)
     path(2,5,4,5);path(14,5,16,5)
    elseif name=="Clear"then
     path(3,5,15,5);path(6,2,12,2);path(5,6,6,16);path(6,16,12,16);path(12,16,13,6);path(9,8,9,13)
    end
    b.MouseEnter:Connect(function()
     b.Border.Color=active and Color3.fromRGB(219,188,255)or C.Cyan
     for _,part in ipairs(ink:GetChildren())do if part:IsA("Frame")then part.BackgroundColor3=C.Text end end
    end)
    b.MouseLeave:Connect(function()
     b.Border.Color=active and Color3.fromRGB(192,144,255)or Color3.fromRGB(26,88,166)
     for _,part in ipairs(ink:GetChildren())do if part:IsA("Frame")then part.BackgroundColor3=fg end end
    end)
    tx+=bw
   end
  end'''+s[b:]
s=s.replace(' if self.Hover and drawingContext then',' if self.Hover and drawingContext and not self:Blocked() then')
needle=' local snap=hoverPoint and hoverPoint.Snap'
s=s.replace(needle,''' -- Use the exact click conversion, including tick rounding and OHLC magnet snapping.
 local ready=self.S.Tool=="Trend" and hoverPoint and not self.LastTouch and not self.Pending and not self.OrderPending
 if ready and self.Drag and self.Drag.Kind~="Place" then ready=false end
 if ready then
  local dx,dy=X(hoverPoint.Time),Y(hoverPoint.Price)
  local dot=frame(layer,"TrendReadyDot",dx-3,dy-3,6,6,C.Text,10);round(dot,3)
  stroke(dot,C.Blue).Thickness=2
  ctx.Root:SetAttribute("TrendReadyTime",hoverPoint.Time);ctx.Root:SetAttribute("TrendReadyPrice",hoverPoint.Price)
 else ctx.Root:SetAttribute("TrendReadyTime",nil);ctx.Root:SetAttribute("TrendReadyPrice",nil) end
'''+needle)
s=s.replace('if self.Drag or self.Placement then self:Cancel()', 'if self.Drag or self.Placement or DRAW[self.S.Tool] then self:Cancel();self.Ctx.refresh()')
s=s.replace('if self.Drag then self:Finish(false);return true end\n  if self.Placement then self.Placement=nil;self.Dirty=true;return true end', 'if self.Drag or self.Placement then self:Cancel();self.Ctx.refresh();return true end')
s=s.replace(' self.Placement=nil self.Dirty=true\nend\n-- Window focus', ' self.Placement=nil self.Hover=nil self.Dirty=true\n if DRAW[self.S.Tool] then self.S.Tool="Pan" end\nend\n-- Window focus')
s=s.replace(' self.S.Tool=name self.Placement=nil',' if self.Drag then self:Finish(false)end\n self.S.Tool=name self.Placement=nil self.Hover=nil')
p.write_text(s,encoding='utf-8')

p=p.with_name('MarketServer.server.luau');s=p.read_text(encoding='utf-8')
s=s.replace('local fields={','local fields={"ExpectedAccount",')
s=s.replace('field=="Followers" and 64 or 32','(field=="Followers" or field=="ExpectedAccount") and 64 or 32')
s=s.replace('Player=player,Request=clean,Sequence=sequence,Epoch=epoch','Player=player,Request=clean,Sequence=sequence,Epoch=epoch,Owner=state.Owner')
s=s.replace(' local owner=state.Owner\n if not owner', ''' local owner=state.Owner
 if item.Owner~=owner or req.ExpectedAccount~=owner then reply(state,req.Id,false,"Your trading account changed. Review the selected account and retry.") return end
 if not owner''')
p.write_text(s,encoding='utf-8')
p=p.with_name('MarketClient.luau');s=p.read_text(encoding='utf-8')
s=s.replace(' self.Pending[self.NextId]=os.clock() self.Remote:FireServer(request)',' request.ExpectedAccount=self.AccountKey\n self.Pending[self.NextId]=os.clock() self.Remote:FireServer(request)')
p.write_text(s,encoding='utf-8')
