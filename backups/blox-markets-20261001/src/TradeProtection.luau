-- One dollar-to-tick calculation shared by the ticket and authoritative exchange.
-- Dollars are the estimated TOTAL for the requested quantity, excluding slippage.
local Protection={}
function Protection.Resolve(spec,quantity,dollars,entry,direction,field)
 if type(quantity)~="number" or quantity<1 or quantity%1~=0 then return nil,"Choose a positive whole quantity." end
 local unit=spec.Tick*spec.Multiplier*quantity
 if type(dollars)~="number" or dollars~=dollars or dollars<=0 or dollars==math.huge or dollars>unit*10000 then
  return nil,"Protection must be a positive dollar amount within 10,000 ticks for this quantity."
 end
 local ticks=math.max(1,math.round(dollars/unit))
 local result={Ticks=ticks,Dollars=ticks*unit,TickDollars=unit}
 if entry then
  local side=(field=="Stop" and -1 or 1)*(direction or 1)
  result.Price=math.round((entry+side*ticks*spec.Tick)/spec.Tick)*spec.Tick
  result.Dollars=math.abs(result.Price-entry)*spec.Multiplier*quantity
 end
 return result
end
return Protection
