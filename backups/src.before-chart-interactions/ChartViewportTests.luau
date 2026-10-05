local V=require(script.Parent.ChartViewport)
return function()
 local candles={} for i=1,100 do candles[i]={Time=(i-1)*60,Open=100,High=102,Low=98,Close=101,Volume=1}end
 local state={} local live=V.Resolve(state,candles,"1m",0.25,false,{101})
 assert(live.Live and #live.Data<100,"Must show a navigable window")
 V.Pan(state,live,200,60,600,300)
 local history=V.Resolve(state,candles,"1m",0.25,false,{101})
 assert(history.Right<live.Right and history.Low>live.Low,"Drag must move time and price in the expected direction")
 local anchored=history.Right local low=history.Low
 table.insert(candles,{Time=6000,Open=102,High=105,Low=100,Close=104,Volume=3})
 local updated=V.Resolve(state,candles,"1m",0.25,false,{104})
 assert(updated.Right==anchored and updated.Low==low,"New trades must not snap a detached viewport")
 local anchor=V.TimeAt(updated,0.4)
 V.Zoom(state,updated,0.8,0.4)
 local zoom=V.Resolve(state,candles,"1m",0.25,false,{104})
 assert(math.abs(V.TimeAt(zoom,0.4)-anchor)<0.00001,"Wheel zoom must preserve the time under the pointer")
 assert(zoom.Bars<updated.Bars)
 V.GoLive(state)
 local resumed=V.Resolve(state,candles,"1m",0.25,false,{104})
 assert(resumed.Live and resumed.Right==6120 and state.Low==nil,"Go live must restore following and automatic scale")
 for _,size in ipairs({{390,300},{844,180}})do
  local s={} local f=V.Resolve(s,candles,"1m",0.25,true,{104})
  V.Pan(s,f,90,20,size[1],size[2]) assert(s.Right<f.Right and s.High>f.High)
 end
 local one=V.Resolve({},{{Time=0,Open=100,High=100,Low=100,Close=100,Volume=1}},"1D",0.25,false,{100})
 assert(one.High>one.Low and one.Right>one.Left and V.X(one,0,500)==V.X(one,0,500))
 V.Pan(state,resumed,1e8,0,600,300)
 local bounded=V.Resolve(state,candles,"1m",0.25,false,{104}) assert(bounded.Right>=bounded.Minimum)
 assert(candles[1].Time==0 and candles[1].Close==101,"Navigation must not mutate candles")
 return {Passed=true,Cases=8,Checks="Pan, price movement, update anchoring, pointer zoom, live reset, mobile geometry, single candle, history bounds"}
end
