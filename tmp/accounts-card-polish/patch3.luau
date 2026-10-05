local P={}
P[1]={From=[==[  local tw=pw-18-tx-closeSize-(plain and 14 or 22)]==],To=[==[]==],New=[==[  local tw=pw-18-tx-closeSize-closeInset-12]==]}
P[2]={From=[==[  if maxH then viewRows=math.min(viewRows,math.max(rowH,maxH-(yy-y)-actionGap-actionH-gap-footerH))end]==],To=[==[]==],New=[==[  -- Height-limited popups show whole rows only (a sliver of a row reads as a stray line).
  if maxH then
   local fitRows=math.max(1,math.floor((maxH-(yy-y)-actionGap-actionH-gap-footerH+gap)/step))
   viewRows=math.min(viewRows,fitRows*step-gap)
  end]==]}
local function apply(src)
 for i,p in ipairs(P)do
  local a=string.find(src,p.From,1,true);assert(a,"patch "..i..": From not found")
  assert(not string.find(src,p.From,a+1,true),"patch "..i..": From not unique")
  local b
  if p.To==""then b=a+#p.From else b=string.find(src,p.To,a+#p.From,true);assert(b,"patch "..i..": To not found")end
  src=string.sub(src,1,a-1)..p.New..string.sub(src,b)
 end
 return src
end
return apply
