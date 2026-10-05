from pathlib import Path
for name in ['ValidateTradeControls','ValidateTradingUIFixes']:
 p=Path('tools')/(name+'.luau');s=p.read_text(encoding='utf-8-sig')
 s=s.replace('Stop=req.StopTicks and c.Last-req.Direction*req.StopTicks*c.Tick,Target=req.TargetTicks and c.Last+req.Direction*req.TargetTicks*c.Tick', 'Stop=req.StopDollars and Market.Protection(c,req.Quantity,req.StopDollars,c.Last,req.Direction,"Stop").Price,Target=req.TargetDollars and Market.Protection(c,req.Quantity,req.TargetDollars,c.Last,req.Direction,"Target").Price')
 if name=='ValidateTradeControls':
  s=s.replace('StopTicks','StopDollars').replace('TargetTicks','TargetDollars').replace('↑ BUY LIMIT','↑ LIMIT BUY')
  s=s.replace('StopDollars==41','StopDollars==500.01').replace('TargetDollars==119','TargetDollars==1499.99').replace('StopDollars==42','StopDollars==500.02').replace('StopDollars==43','StopDollars==500.03')
  s=s.replace('Estimated risk  $2,050.00','Estimated total loss  $500.00').replace('Distance",10001','Distance",100000001')
  s=s.replace('StopDollars=10000,TargetDollars=10000','StopDollars=10000,TargetDollars=10000')
 p.write_text(s,encoding='utf-8')
