local P={}
P[1]={From=[==[    local nx=mobile and 5 or 12;local marker=mobile and 8 or 22
    if current then
     local size=mobile and 7 or 14]==],To=[==[]==],New=[==[    -- Narrow desktop cards (small windows) use tighter spacing so names and badges keep fitting.
    local tight=not mobile and lw<250
    local nx=mobile and 5 or tight and 8 or 12;local marker=mobile and 8 or tight and 14 or 22
    if current then
     local size=mobile and 7 or tight and 10 or 14]==]}
P[2]={From=[==[    nx+=marker+(mobile and 4 or 10)
    local cue=role and(mobile and(lw<120 and 40 or 44)or 80)or(mobile and 10 or 20)
    local cx=lw-cue-(mobile and 4 or 10)
    local name=summaryText(b,"Name",row.Short,nx,1,cx-nx-(mobile and 3 or 8),rowH-2,mobile and 11 or(rowH>=36 and 18 or 15),C.Text,mobile);name.ZIndex=9]==],To=[==[]==],New=[==[    nx+=marker+(mobile and 4 or tight and 6 or 10)
    local cue=role and(mobile and(lw<120 and 40 or 44)or tight and 52 or 80)or(mobile and 10 or tight and 14 or 20)
    local cx=lw-cue-(mobile and 4 or tight and 6 or 10)
    local name=summaryText(b,"Name",row.Short,nx,1,cx-nx-(mobile and 3 or tight and 4 or 8),rowH-2,mobile and 11 or tight and 13 or(rowH>=36 and 18 or 15),C.Text,mobile or tight);name.ZIndex=9]==]}
P[3]={From=[==[     local ph=mobile and rowH-4 or math.min(26,rowH-10)]==],To=[==[]==],New=[==[     local ph=mobile and rowH-4 or math.min(tight and 20 or 26,rowH-10)]==]}
P[4]={From=[==[     local label=summaryText(pill,"Label",role,3,0,cue-6,ph,mobile and 9 or 14,color,true)]==],To=[==[]==],New=[==[     local label=summaryText(pill,"Label",role,3,0,cue-6,ph,mobile and 9 or tight and 11 or 14,color,true)]==]}
P[5]={From=[==[     local cy=(rowH-cue)/2;local t=mobile and 2 or 3]==],To=[==[]==],New=[==[     local cy=(rowH-cue)/2;local t=(mobile or tight)and 2 or 3]==]}
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
