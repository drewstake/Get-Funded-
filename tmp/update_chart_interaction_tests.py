from pathlib import Path
p=Path('src/ChartToolsTests.luau');s=p.read_text();s=s.replace('check(T.Snap(candles,X,Y,X(600)+40,Y(110),14)==nil,"No snap outside the radius")','''local far=T.Snap(candles,X,Y,900,-300)
 check(far and far.Time==660,"Strong snap has no distance limit, including future space")
 check(T.Snap({},X,Y,900,-300)==nil,"No candles leaves snapping empty")
 for _,field in ipairs({"Open","High","Low","Close"})do
  local hit=T.Snap({candles[1]},X,Y,X(600),Y(candles[1][field]))
  check(hit and hit.Price==candles[1][field],"Every OHLC target: "..field)
 end
 local pixels=T.Snap({{Time=0,Open=0,High=0,Low=0,Close=0},{Time=100,Open=90,High=90,Low=90,Close=90}},function(t)return t end,function(p)return p end,0,90)
 check(pixels.Time==0,"Screen-space distance beats price-only distance")
 pixels=T.Snap({{Time=0,Open=0,High=0,Low=0,Close=0},{Time=10,Open=90,High=90,Low=90,Close=90}},function(t)return t end,function(p)return p end,0,90)
 check(pixels.Time==10,"Screen-space distance beats nearest candle in time")''');p.write_text(s)
