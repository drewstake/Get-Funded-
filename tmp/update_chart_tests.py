from pathlib import Path
p=Path('src/ChartViewportTests.luau');s=p.read_text(encoding='utf-8-sig')
s=s.replace('1 px per candle','7 px per candle').replace('maxBars==math.ceil(700*1.15)+5','maxBars==math.floor(1266/7)').replace('wide==1266','wide==math.floor(1266/7)').replace('narrow==500','narrow==math.floor(500/7)').replace('one candle per pixel','readable spacing').replace('#live.Data>=#candles-2','#live.Data<=maxBars+3 and live.Interval==60')
s=s.replace('reaches the whole history','respects readable spacing').replace('Fully zoomed out, the extra room shows history rather than empty future','Zoom keeps real one-minute candles and a bounded readable count')
p.write_text(s,encoding='utf-8')
p=Path('src/ChartToolsTests.luau');s=p.read_text(encoding='utf-8-sig')
s=s.replace('6,8,nil,1000).Part=="Extend","Extension handle hit on an unselected rectangle"','6,8,nil,1000).Part=="Slide","Unselected rectangle has no extension hit area"')
s=s.replace(' local copyR=T.Copy(original)',' check(T.HitTest(elist,X,Y,ex+2,ey-1,6,8,ext.Id,1000).Part=="Extend","Selected rectangle extension is hittable")\n local copyR=T.Copy(original)')
p.write_text(s,encoding='utf-8')
