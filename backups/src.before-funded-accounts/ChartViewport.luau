-- Presentation-only chart navigation. Never modifies prices, candles or account state.
local Viewport={}
Viewport.Seconds={["1m"]=60,["5m"]=300,["15m"]=900,["1h"]=3600,["1D"]=86400}
function Viewport.Resolve(state,candles,timeframe,tick,mobile,levels)
 if #candles==0 then return nil end
 local interval=Viewport.Seconds[timeframe]
 state.Bars=math.clamp(state.Bars or math.min(#candles+2,mobile and 24 or 28),8,120)
 local latest,earliest=candles[#candles].Time,candles[1].Time
 local liveRight=latest+interval*2
 local minimum=math.min(liveRight,earliest+(state.Bars-1)*interval)
 local maximum=latest+state.Bars*interval*0.75
 local right=state.Right and math.clamp(state.Right,minimum,maximum) or liveRight
 if state.Right then state.Right=right end
 local left=right-state.Bars*interval
 local visible={} local low,high=math.huge,-math.huge
 for _,c in ipairs(candles) do
  if c.Time>=left and c.Time<=right then
   table.insert(visible,c) low=math.min(low,c.Low) high=math.max(high,c.High)
  end
 end
 if #visible==0 then low=candles[#candles].Low high=candles[#candles].High end
 if not state.Right then for _,price in ipairs(levels or {})do low=math.min(low,price) high=math.max(high,price) end end
 local padding=math.max(tick*2,(high-low)*0.1)
 low=state.Low or low-padding high=state.High or high+padding
 return {Left=left,Right=right,Low=low,High=math.max(low+tick,high),Bars=state.Bars,Interval=interval,Data=visible,
  Earliest=earliest,Latest=latest,Minimum=minimum,Maximum=maximum,Live=state.Right==nil and state.Low==nil}
end
function Viewport.TimeAt(view,fraction) return view.Left+(view.Right-view.Left)*fraction end
function Viewport.PriceAt(view,fraction) return view.High-(view.High-view.Low)*fraction end
function Viewport.X(view,time,width) return (time-view.Left)/(view.Right-view.Left)*width end
function Viewport.Y(view,price,height) return (view.High-price)/(view.High-view.Low)*height end
function Viewport.Pan(state,start,dx,dy,width,height)
 state.Right=math.clamp(start.Right-dx/math.max(1,width)*(start.Right-start.Left),start.Minimum,start.Maximum)
 local shift=dy/math.max(1,height)*(start.High-start.Low)
 state.Low=start.Low+shift state.High=start.High+shift
end
function Viewport.Zoom(state,view,factor,fraction)
 local bars=math.clamp(view.Bars*factor,8,120)
 local anchor=Viewport.TimeAt(view,math.clamp(fraction,0,1))
 state.Bars=bars state.Right=anchor+(1-math.clamp(fraction,0,1))*bars*view.Interval
end
function Viewport.GoLive(state) state.Right=nil state.Low=nil state.High=nil end
return Viewport
