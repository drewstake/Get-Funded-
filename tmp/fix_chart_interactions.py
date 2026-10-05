from pathlib import Path
p=Path('src/ChartView.luau')
s=p.read_text(encoding='utf-8')
s=s.replace(' local candle\n if inspecting then',' local candle\n ctx.Root:SetAttribute("CrosshairTime",nil)\n ctx.Root:SetAttribute("CrosshairX",nil)\n ctx.Root:SetAttribute("CrosshairSnapped",false)\n if inspecting then')
s=s.replace('local v=g.View local t=v.Left+x/g.Pxs\n   local magnet=self:MagnetOn()','local v=g.View local t=Viewport.TimeAt(v,x/g.Width)')
s=s.replace('if best and not magnet and bd>v.Interval*0.6 then best=nil end','if best and bd>v.Interval*0.6 then best=nil end')
a=s.index('   -- The lines follow the pointer.')
b=s.index('   local lineColor=C.Muted',a)
s=s[:a]+'''   -- Inspection always follows the pointer, including future time. Drawing magnets have
   -- their own target ring so snapping cannot pin the crosshair to the last candle.
   local cx=math.floor(x+0.5) local cy=math.floor(y+0.5) local n=Viewport.PriceAt(v,y/g.Height)
'''+s[b:]
s=s.replace('ctx.Root:SetAttribute("CrosshairX",cx);ctx.Root:SetAttribute("CrosshairSnapped",magnet and best~=nil)','ctx.Root:SetAttribute("CrosshairX",cx);ctx.Root:SetAttribute("CrosshairTime",t)')
s=s.replace('local stamp=(magnet and best)and best.Time or t','local stamp=t')
s=s.replace(' ctx.Root:SetAttribute("CrosshairTime",candle and candle.Time or nil)\n','')
s=s.replace('if self:CtrlDown()and not self.S.Magnet and not g.Mobile then','if (self.S.Magnet or self:CtrlDown())and not g.Mobile then')
s=s.replace('112,22,C.Raised,7);round(badge,11)','196,22,C.Raised,7);round(badge,11)')
s=s.replace('text(badge,"Label","Magnet · Ctrl",0,0,112,22,12,C.Text,ctx.B,CENTER,8)','text(badge,"Label",self:SnapBypassed()and"Free placement · Alt"or"Magnet · Hold Alt to bypass",0,0,196,22,12,C.Text,ctx.B,CENTER,8)')
a=s.index('   -- A slide keeps the rectangle')
b=s.index('   local Market=self.Ctx.Market',a)
s=s[:a]+'''   local pt=self:DrawingPointAt(x,y,d.Type==TOUCH)
   local origin=d.Anchor or d.StartPoint
'''+s[b:]
s=s.replace('Time=pt.Time-d.StartPoint.Time,Price=pt.Snap and pt.Price-d.StartPoint.Price or Market.Snap(pt.Price-d.StartPoint.Price,self.S.Contract)','Time=pt.Time-origin.Time,Price=pt.Snap and pt.Price-origin.Price or Market.Snap(pt.Price-origin.Price,self.S.Contract)')
s=s.replace('  self.Selected=d.Id;return','''  if hit.Part=="Move" or hit.Part=="Slide" then
   local anchors=Tools.Points(d)
   if d.Kind=="Line" then anchors={{Time=self.Drag.StartPoint.Time,Price=d.P1}} end
   local nearest=math.huge
   for _,pt in ipairs(anchors)do
    local dist=(g.X(pt.Time)-x)^2+(g.Y(pt.Price)-y)^2
    if dist<nearest then nearest=dist;self.Drag.Anchor=pt end
   end
  end
  self.Selected=d.Id;return''')
s=s.replace('self.Ctrl=true;self.Dirty=true;return false','self.Ctrl=true;self:ModifierChanged();return false')
s=s.replace(' local key=ev.KeyCode\n',' local key=ev.KeyCode\n if key==Enum.KeyCode.LeftAlt or key==Enum.KeyCode.RightAlt then self:ModifierChanged();return false end\n')
s=s.replace('self.Ctrl=UIS:IsKeyDown(Enum.KeyCode.LeftControl)or UIS:IsKeyDown(Enum.KeyCode.RightControl);self.Dirty=true','self.Ctrl=UIS:IsKeyDown(Enum.KeyCode.LeftControl)or UIS:IsKeyDown(Enum.KeyCode.RightControl);self:ModifierChanged()')
s=s.replace('function View:KeyEnded(ev)\n','function View:KeyEnded(ev)\n if ev.KeyCode==Enum.KeyCode.LeftAlt or ev.KeyCode==Enum.KeyCode.RightAlt then self:ModifierChanged() end\n')
a=s.index('-- Cancels the current gesture:')
s=s[:a]+'''-- Re-evaluate an active drag when the modifier changes, even without mouse motion.
function View:ModifierChanged()
 self.Dirty=true
 local d=self.Drag
 if d and d.Moved and d.Type~=TOUCH and self.Hover then
  self:Changed({UserInputType=MOVE,Position=self.Hover})
 end
end
'''+s[a:]
p.write_text(s,encoding='utf-8')
