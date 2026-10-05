-- Incremental view of the engine's supplied resting levels. Never generates liquidity.
local TweenService=game:GetService("TweenService")
local View={};View.__index=View
local C={Bg=Color3.fromRGB(3,25,65),Border=Color3.fromRGB(27,92,196),Cyan=Color3.fromRGB(0,220,255),
 Text=Color3.fromRGB(245,249,255),Muted=Color3.fromRGB(159,210,248),Red=Color3.fromRGB(255,81,127),Green=Color3.fromRGB(46,249,160)}
local function make(class,name,p,props)
 local o=Instance.new(class);o.Name=name;for k,v in pairs(props)do o[k]=v end;o.Parent=p;return o
end
local function label(p,name,value,x,y,w,h,size,color,align)
 return make("TextLabel",name,p,{Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
  Font=Enum.Font.FredokaOne,TextSize=size or 13,TextColor3=color or C.Text,TextXAlignment=align or Enum.TextXAlignment.Left,
  TextStrokeTransparency=.8,TextStrokeColor3=C.Bg,BorderSizePixel=0,ZIndex=p.ZIndex+2})
end
local function levels(side)
 if type(side)~="table"then return nil end
 local out={}
 for _,level in ipairs(side)do
  if type(level)=="table"and type(level.Price)=="number"and level.Price>0 and level.Price<math.huge
   and type(level.Quantity)=="number"and level.Quantity>0 and level.Quantity<math.huge then table.insert(out,level)end
 end
 return out
end
function View.new(ctx,parent,x,y,w)
 local self=setmetatable({Context=ctx,Width=w,Rows={Asks={},Bids={}},Tweens={}},View)
 local p=make("Frame","Level2",parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,40),BackgroundColor3=C.Bg,BorderSizePixel=0,ZIndex=parent.ZIndex+1})
 self.Root=p
 p:SetAttribute("StaticButtons",true)
 make("UICorner","Corners",p,{CornerRadius=UDim.new(0,12)})
 make("UIStroke","Border",p,{Color=C.Border,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.Header=ctx.gloss(ctx.button(p,"ToggleLevel2","",0,0,w,40,function()
  ctx.toggle();self:Update()
 end,C.Bg,C.Text,16,p.ZIndex+1),"Navy")
 self.Header:SetAttribute("StaticButtons",true);self.Header:SetAttribute("FixedGeometry",true)
 self.Title=label(self.Header,"Title","Level 2",12,0,w-80,40,17)
 self.Chevron=label(self.Header,"Chevron","−",w-40,0,28,40,20,C.Cyan,Enum.TextXAlignment.Center)
 self.Body=make("Frame","Body",p,{Position=UDim2.fromOffset(0,40),Size=UDim2.fromOffset(w,0),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=p.ZIndex})
 self.Body:SetAttribute("StaticButtons",true)
 self.Note=label(self.Body,"LiquiditySource","Simulated market liquidity\nNot other players' orders",10,4,w-20,32,12,C.Muted)
 self.Message=label(self.Body,"Status","",10,7,w-20,24,13,C.Muted)
 self.Unlock=ctx.gloss(ctx.button(self.Body,"UnlockL2","Unlock L2",10,35,w-20,40,ctx.openShop,C.Bg,C.Text,16,p.ZIndex+2),"Cyan")
 self.Unlock:SetAttribute("FixedGeometry",true)
 self.Columns=make("Frame","Columns",self.Body,{Position=UDim2.fromOffset(8,38),Size=UDim2.fromOffset(w-16,20),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=p.ZIndex})
 label(self.Columns,"Side","",0,0,56,20,12,C.Muted)
 label(self.Columns,"Price","Price",56,0,w-136,20,12,C.Muted,Enum.TextXAlignment.Right)
 label(self.Columns,"Quantity","Qty",w-74,0,56,20,12,C.Muted,Enum.TextXAlignment.Right)
 self.Spread=label(self.Body,"Spread","",10,0,w-20,26,13,C.Cyan,Enum.TextXAlignment.Center)
 self.EmptyAsks=label(self.Body,"EmptyAsks","",10,0,w-20,20,13,C.Muted)
 self.EmptyBids=label(self.Body,"EmptyBids","",10,0,w-20,20,13,C.Muted)
 self:Update();return self
end
function View:Row(side,index)
 local pool=self.Rows[side];if pool[index]then return pool[index]end
 local p=make("Frame",side..index,self.Body,{Size=UDim2.fromOffset(self.Width-16,20),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=self.Body.ZIndex})
 local color=side=="Asks"and C.Red or C.Green
 local bar=make("Frame","Liquidity",p,{AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromScale(0,1),
  BackgroundColor3=color,BackgroundTransparency=.82,BorderSizePixel=0,ZIndex=p.ZIndex})
 make("UICorner","Corners",bar,{CornerRadius=UDim.new(0,3)})
 local row={Root=p,Bar=bar,Side=label(p,"Side","",2,0,56,20,12,color),
  Price=label(p,"Price","",56,0,self.Width-136,20,13,C.Text,Enum.TextXAlignment.Right),
  Quantity=label(p,"Quantity","",self.Width-74,0,56,20,13,C.Text,Enum.TextXAlignment.Right)}
 pool[index]=row;return row
end
function View:SetHeight(height)
 self.Root.Size=UDim2.fromOffset(self.Width,height);self.Body.Size=UDim2.fromOffset(self.Width,math.max(0,height-40))
 if self.Height~=height then self.Height=height;if self.Context.resize then self.Context.resize(height)end end
end
function View:Update()
 if not self.Root.Parent then return end
 local ctx=self.Context;local expanded=ctx.expanded();local access,quote,fresh=ctx.data()
 self.Root:SetAttribute("Expanded",expanded);self.Body.Visible=expanded
 self.Chevron.Text=expanded and "−"or"+"
 if not expanded then self:SetHeight(40);return end
 local allowed=access and access.Allowed==true
 local state=access and access.State or "Checking"
 local depth=allowed and fresh and quote and quote.Depth
 local book=type(depth)=="table"
 self.Note.Visible=book;self.Columns.Visible=book;self.Spread.Visible=book
 self.Message.Visible=not book;self.Unlock.Visible=not allowed and state~="Checking"
 self.EmptyAsks.Visible=false;self.EmptyBids.Visible=false
 for _,pool in pairs(self.Rows)do for _,row in ipairs(pool)do row.Root.Visible=false end end
 if not book then
  self.Message.Text=not allowed and (state=="Checking"and "Checking L2 access…"or state=="Unavailable"and "Access check unavailable"or "Market Depth Pro · Locked")
   or fresh==false and "Depth paused · reconnecting…"or "Loading market depth…"
  if allowed and fresh and quote and quote.Depth==nil then self.Message.Text="Market depth unavailable"end
  self:SetHeight(self.Unlock.Visible and 124 or 80);return
 end
 local asks,bids=levels(depth.Asks),levels(depth.Bids)
 local maximum=0
 for _,side in ipairs({asks or{},bids or{}})do for _,l in ipairs(side)do maximum=math.max(maximum,l.Quantity)end end
 local yy=58
 for _,side in ipairs({"Asks","Bids"})do
  local data;if side=="Asks"then data=asks else data=bids end
  local empty=self["Empty"..side]
  if not data or #data==0 then
   empty.Visible=true;empty.Text=not data and (side.." unavailable")or (side=="Asks"and "No resting asks"or "No resting bids")
   empty.Position=UDim2.fromOffset(10,yy);yy+=20
  else
   for display=1,#data do
    local index=side=="Asks"and #data-display+1 or display;local l=data[index];local row=self:Row(side,display)
    row.Root.Visible=true;row.Root.Position=UDim2.fromOffset(8,yy);yy+=20
    row.Side.Text=index==1 and (side=="Asks"and "Best ask"or "Best bid")or ""
    row.Root:SetAttribute("Best",index==1);row.Root:SetAttribute("Price",l.Price);row.Root:SetAttribute("Quantity",l.Quantity)
    row.Price.Text=ctx.number(l.Price);row.Quantity.Text=ctx.quantity(l.Quantity)
    local ratio=maximum>0 and l.Quantity/maximum or 0
    if row.Ratio~=ratio then
     if self.Tweens[row]then self.Tweens[row]:Cancel()end
     if row.Ratio==nil then row.Bar.Size=UDim2.fromScale(ratio,1)
     else local tween=TweenService:Create(row.Bar,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(ratio,1)});self.Tweens[row]=tween;tween:Play()end
     row.Ratio=ratio
    end
   end
  end
  if side=="Asks"then
   self.Spread.Position=UDim2.fromOffset(10,yy)
   local spread=asks and asks[1]and bids and bids[1]and asks[1].Price-bids[1].Price
   self.Spread.Text=spread and ("Spread  "..ctx.number(spread))or "Spread unavailable"
   yy+=26
  end
 end
 self:SetHeight(40+yy+8)
end
function View:Destroy()
 for _,tween in pairs(self.Tweens)do tween:Cancel()end
 self.Tweens={};self.Root:Destroy()
end
return View
