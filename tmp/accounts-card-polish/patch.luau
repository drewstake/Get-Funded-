-- Accounts card + Copy Trading popup polish (2026-09-30). Marker-based patch for TerminalUI source.
-- Each entry replaces From..(To, exclusive) with New; an empty To replaces From exactly.
local P={}
P[1]={From=[==[ if name=="BuyLong"or name=="SellShort"then b:SetAttribute("FixedGeometry",true)end]==],To=[==[]==],New=[==[ -- Buttons in a "StaticButtons" container (clipped lists) keep their geometry, so hover growth never clips.
 if name=="BuyLong"or name=="SellShort"or p:GetAttribute("StaticButtons")then b:SetAttribute("FixedGeometry",true)end]==]}
P[2]={From=[==[function UI.Mount(gui,options)]==],To=[==[]==],New=[==[-- Flat account rows (Accounts card and copy editor): one clean rim and a soft shine, no lower edge.
local ROW_LOOK={
 Purple={Color3.fromRGB(156,72,255),Color3.fromRGB(92,30,228),Color3.fromRGB(171,102,255)},
 Cyan={Color3.fromRGB(0,176,255),Color3.fromRGB(0,100,230),Color3.fromRGB(64,222,255)},
 Navy={Color3.fromRGB(6,48,122),Color3.fromRGB(3,29,82),Color3.fromRGB(26,88,186)},
}
local function rowSurface(b,variant,radius,edge)
 local look=ROW_LOOK[variant]or ROW_LOOK.Navy
 b.Corners.CornerRadius=UDim.new(0,radius)
 b.Border.Color=look[3];b.Border.Thickness=edge or 2
 tint(b,look[1],look[2])
 if variant~="Navy"and b.Size.Y.Offset>=30 then
  local shine=frame(b,"Shine",radius,4,b.Size.X.Offset-radius*2,2,Color3.new(1,1,1),b.ZIndex+1)
  shine.BackgroundTransparency=.65;round(shine,1)
 end
end
function UI.Mount(gui,options)]==]}
P[3]={From=[==[  -- Account selection stays separate from the header's copy-trading shortcut.]==],To=[==[  for i,d in ipairs({{"Equity",mobile and"EQUITY"or"ACCOUNT EQUITY",sum.Equity},]==],New=[==[  -- The whole Accounts card opens Copy Trading: header, rows and empty space share one action, and it
  -- never switches the trading account (the sidebar/header account switcher does that).
  local listW=mobile and math.floor((w-gap*2)*(w<340 and .5 or .47))or cw
  local restW=mobile and(w-gap*2-listW)/2 or cw
  do
   local pf=session.Portfolio
   local function openCopy()s.CopyDraft=nil;s.Overlay="Copy";refresh()end
   local tile=button(p,"AccountsCard","",0,0,listW,cardH,openCopy,Color3.new(1,1,1))
   summarySurface(tile,"Balance",mobile)
   local rows={};for _,row in ipairs(pf and pf.Accounts or{})do if row.State=="Active"and not row.Breached then table.insert(rows,row)end end
   tile:SetAttribute("AccountCount",#rows)
   local lp=mobile and 7 or 14;local headY=mobile and 3 or 10;local headH=mobile and 14 or 26
   local countW=mobile and 20 or 32;local countH=mobile and 14 or 24;local countX=listW-lp-countW
   if mobile then summaryText(tile,"Label","ACCOUNTS",lp,headY,countX-lp-6,headH,10,C.Text,true)
   else summaryIcon(tile,"Balance",lp,headY,headH);summaryText(tile,"Label","ACCOUNTS",lp+headH+8,headY,countX-lp-headH-16,headH,20)end
   local badge=frame(tile,"Count",countX,headY+(headH-countH)/2,countW,countH,SB.Navy,7)
   round(badge,countH/2);stroke(badge,C.Border).Thickness=mobile and 1 or 2
   local count=summaryText(badge,"Label",tostring(#rows),2,0,countW-4,countH,mobile and 10 or 16,C.Text,true);count.ZIndex=8;count.TextXAlignment=CENTER
   -- Whole rows only: 2 on phones, 3 on desktop, the rest scroll. The inset keeps row rims inside the clip.
   local edge=mobile and 1 or 2;local inset=edge+1
   local listY=headY+headH+(mobile and 2 or 10)
   local room=cardH-(mobile and 3 or 14)+inset-listY
   local visible=mobile and 2 or 3;local rowGap=mobile and 2 or 8
   local function fit()return math.floor((room-inset*2-(visible-1)*rowGap)/visible)end
   local rowH=fit()
   if not mobile and rowH<32 then rowGap=5;rowH=fit()end
   if not mobile then rowH=math.clamp(rowH,26,52)end
   local listH=visible*rowH+(visible-1)*rowGap+inset*2
   local total=math.max(0,#rows*(rowH+rowGap)-rowGap)+inset*2
   local overflow=total>listH
   local list=make("ScrollingFrame","AccountList",tile,{Position=UDim2.fromOffset(lp-inset,listY),Size=UDim2.fromOffset(listW-lp*2+inset*2,listH),
    CanvasSize=UDim2.fromOffset(0,total),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=overflow and(mobile and 2 or 5)or 0,
    ScrollBarImageColor3=Color3.fromRGB(163,228,255),ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=6})
   list:SetAttribute("StaticButtons",true)
   local lw=listW-lp*2-(overflow and(mobile and 5 or 10)or 0)
   -- The scrolling list would otherwise take clicks on its empty space away from the card.
   button(list,"ListHitArea","",0,0,list.Size.X.Offset,math.max(listH,total),openCopy,false,C.Text,12,6)
   if #rows==0 then summaryText(list,"Empty","No usable accounts",inset,inset,lw,rowH,mobile and 10 or 15,C.Text,mobile).ZIndex=7 end
   for i,row in ipairs(rows)do
    local current=pf.Active==row.Key;local role=copyRole(pf,row.Key)
    local b=button(list,"Account"..row.Key,"",inset,inset+(i-1)*(rowH+rowGap),lw,rowH,openCopy,Color3.new(1,1,1),C.Text,12,7)
    rowSurface(b,current and"Purple"or"Navy",mobile and 6 or 10,edge)
    b:SetAttribute("AccountKey",row.Key);b:SetAttribute("Selected",current);b:SetAttribute("Role",role)
    local nx=mobile and 5 or 12;local marker=mobile and 8 or 22
    if current then
     local size=mobile and 7 or 14
     local dot=frame(b,"Dot",nx+(marker-size)/2,(rowH-size)/2,size,size,Color3.fromRGB(93,255,83),9);round(dot,size/2);stroke(dot,SC.Ink).Thickness=mobile and 1 or 2
    else
     local cash=summaryIcon(b,"Balance",nx,(rowH-marker)/2,marker);cash.ZIndex=9
    end
    nx+=marker+(mobile and 4 or 10)
    local cue=role and(mobile and(lw<120 and 40 or 44)or 80)or(mobile and 10 or 20)
    local cx=lw-cue-(mobile and 4 or 10)
    local name=summaryText(b,"Name",row.Short,nx,1,cx-nx-(mobile and 3 or 8),rowH-2,mobile and 11 or(rowH>=36 and 18 or 15),C.Text,mobile);name.ZIndex=9
    if role then
     local color=role=="Leader"and Color3.fromRGB(255,222,40)or C.Cyan
     local ph=mobile and rowH-4 or math.min(26,rowH-10)
     local pill=frame(b,"Role",cx,math.floor((rowH-ph)/2),cue,ph,color:Lerp(SC.Ink,.72),9)
     round(pill,ph/2);stroke(pill,color).Thickness=mobile and 1 or 2
     local label=summaryText(pill,"Label",role,3,0,cue-6,ph,mobile and 9 or 14,color,true)
     label.ZIndex=10;label.TextXAlignment=CENTER;if mobile then label.TextOutline.Enabled=false end
    else
     local cy=(rowH-cue)/2;local t=mobile and 2 or 3
     if current then
      line(b,"Check",cx+cue*.12,cy+cue*.52,cx+cue*.4,cy+cue*.78,C.Text,t,10)
      line(b,"Check",cx+cue*.4,cy+cue*.78,cx+cue*.9,cy+cue*.24,C.Text,t,10)
     else
      line(b,"Chevron",cx+cue*.35,cy+cue*.2,cx+cue*.65,cy+cue*.5,C.Text,t,10)
      line(b,"Chevron",cx+cue*.65,cy+cue*.5,cx+cue*.35,cy+cue*.8,C.Text,t,10)
     end
    end
   end
  end
]==]}
P[4]={From=[==[    summaryText(tile,"Label",d[2],pad,4,tw-2*pad,16,10,C.Text,true)
    summaryText(tile,d[1].."Value",value,pad,21,tw-2*pad,23,w<370 and 12 or 14,accent,true)]==],To=[==[]==],New=[==[    -- Labels line up with the Accounts header; values sit centred in the space below.
    summaryText(tile,"Label",d[2],pad,3,tw-2*pad,14,10,C.Text,true)
    summaryText(tile,d[1].."Value",value,pad,17+math.floor((cardH-20-24)/2),tw-2*pad,24,w<370 and 12 or 14,accent,true)]==]}
P[5]={From=[==[ local function popupShell(w,h,pw,contentH,title,iconKind,subtitle)]==],To=[==[ -- A selectable row: purple (or cyan) glossy when selected, deep navy otherwise.]==],New=[==[ -- opts.Plain: concentric corners, no decorative stars and an evenly inset close button.
 local function popupShell(w,h,pw,contentH,title,iconKind,subtitle,opts)
  local plain=opts and opts.Plain
  local narrow=pw<380
  local headH=subtitle and(narrow and 76 or 84)or(narrow and 60 or 66)
  local top=headH+20
  local ph=top+contentH+10
  local viewH=math.min(ph,h-24)
  local shell=frame(canvas,"Dialog",(w-pw)/2,(h-viewH)/2,pw,viewH,Color3.new(1,1,1),41)
  round(shell,22);stroke(shell,Color3.fromRGB(4,221,255)).Thickness=4
  tint(shell,Color3.fromRGB(6,56,147),Color3.fromRGB(3,30,83))
  local rim=frame(shell,"InnerRim",5,5,pw-10,viewH-10,Color3.new(1,1,1),41);rim.BackgroundTransparency=1
  round(rim,plain and 17 or 18);stroke(rim,Color3.fromRGB(31,125,255)).Thickness=2
  local hero=frame(shell,"Header",9,9,pw-18,headH,Color3.new(1,1,1),42)
  round(hero,plain and 14 or 16);stroke(hero,Color3.fromRGB(168,100,255)).Thickness=3
  tint(hero,Color3.fromRGB(150,70,255),Color3.fromRGB(84,32,232));if not plain then panelStars(hero)end
  local iconSize=math.min(52,headH-16);local tx=16
  if iconKind=="Alert"then alertBadge(hero,14,math.floor((headH-iconSize*.8)/2),math.floor(iconSize*.8),45);tx=iconSize+14
  elseif iconKind then sidebarImage(hero,iconKind,plain and 12 or 10,(headH-iconSize)/2,iconSize);tx=iconSize+(plain and 24 or 20)end
  local closeSize=narrow and 38 or 42
  local closeInset=plain and math.floor((headH-closeSize)/2)or 10
  local tw=pw-18-tx-closeSize-22
  local t=sidebarText(hero,"Title",title,tx,subtitle and 8 or 0,tw,subtitle and 40 or headH,narrow and 22 or 27)
  t.ZIndex=45
  if subtitle then local sub=sidebarText(hero,"Subtitle",subtitle,tx,headH-34,tw,24,narrow and 11 or 13,Color3.fromRGB(236,227,255));sub.ZIndex=45 end
  dismissButton(hero,pw-18-closeSize-closeInset,(headH-closeSize)/2,closeSize,function()s.ProtectionDraft=nil;s.Overlay=nil;refresh()end,46)
  local content=make("ScrollingFrame","Content",shell,{Position=UDim2.fromOffset(0,top),Size=UDim2.fromOffset(pw,viewH-top-6),
   CanvasSize=UDim2.fromOffset(pw,contentH),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=C.Cyan,ZIndex=43})
  return shell,content
 end
]==]}
P[6]={From=[==[  elseif s.Overlay=="Copy"then]==],To=[==[  elseif s.Overlay=="CopyIntro"then]==],New=[==[  elseif s.Overlay=="Copy"then
   -- The same copy editor as the Accounts tab, opened from the Trade tab's Accounts card.
   if not pf then close();return end
   local on=pf.Copy and pf.Copy.Enabled==true
   local shell,p=popupShell(w,h,pw,500,"Copy Trading","Positions",nil,{Plain=true})
   local hero=shell.Header;local title=hero.Title
   -- The ON/OFF pill follows the title text instead of crowding the close button.
   local stateH=narrow and 24 or 28;local stateW=narrow and 56 or 66
   local textW=TextService:GetTextSize("Copy Trading",narrow and 22 or 27,Enum.Font.FredokaOne,Vector2.new(1000,100)).X
   local tw=math.min(math.ceil(textW)+4,title.Size.X.Offset-stateW-10)
   title.Size=UDim2.fromOffset(tw,title.Size.Y.Offset)
   local tone=on and C.Green or Color3.fromRGB(128,160,214)
   local state=frame(hero,"State",title.Position.X.Offset+tw+10,math.floor((hero.Size.Y.Offset-stateH)/2),stateW,stateH,on and Color3.fromRGB(2,48,58)or SB.Navy,45)
   round(state,stateH/2);stroke(state,tone).Thickness=2
   local dotSize=narrow and 7 or 8;local dx=narrow and 9 or 11
   local dot=frame(state,"Dot",dx,math.floor((stateH-dotSize)/2),dotSize,dotSize,tone,46);round(dot,dotSize/2)
   local lx=dx+dotSize+5
   local stateLabel=sidebarText(state,"Label",on and"ON"or"OFF",lx,0,stateW-lx-7,stateH,narrow and 13 or 15,on and C.Green or C.Muted);stateLabel.ZIndex=46
   local contentH=copyPanel(p,pad,0,iw,narrow,pf,p.Size.Y.Offset-6)+6
   local top=p.Position.Y.Offset;local viewH=math.min(top+contentH+10,h-24)
   shell.Position=UDim2.fromOffset((w-pw)/2,(h-viewH)/2);shell.Size=UDim2.fromOffset(pw,viewH);shell.InnerRim.Size=UDim2.fromOffset(pw-10,viewH-10)
   p.Size=UDim2.fromOffset(pw,viewH-top-6);p.CanvasSize=UDim2.fromOffset(pw,contentH)
]==]}
P[7]={From=[==[ -- Both entry points share a draft. Sizing remains unchanged; the editor only selects accounts.]==],To=[==[ local function copyCard(p,y,w,mobile,pf)]==],New=[==[ -- Both entry points share a draft. Sizing remains unchanged; the editor only selects accounts.
 copyPanel=function(p,x,y,w,mobile,pf,maxH)
  local copy=pf.Copy or{Followers={}}
  local z=p.ZIndex+1;local yy=y
  local usable,byKey={},{}
  for _,row in ipairs(pf.Accounts or{})do if row.State=="Active"and not row.Breached then table.insert(usable,row);byKey[row.Key]=row end end
  if not pf.CopyAvailable or #usable<2 then
   local t=text(p,"CopyUnavailable","Get a second account to start copying.",x,yy,w,48,15,C.Muted,M,nil,z)
   t.TextWrapped=true;return 54
  end
  local enabled=copy.Enabled==true
  local savedLeader=byKey[copy.Leader]and copy.Leader or nil
  local saved={};if savedLeader then for _,key in ipairs(copy.Followers or{})do if byKey[key]and key~=savedLeader then saved[key]=true end end end
  local draft=s.CopyDraft or{Leader=savedLeader,Followers=table.clone(saved),Sizing=copy.Sizing or"Same"}
  if draft.Leader and not byKey[draft.Leader]then draft.Leader=nil end
  local function edit()s.CopyDraft=draft;refresh()end
  -- One spacing scale for the editor; compact when the popup is height-limited (landscape phones).
  local compact=maxH and maxH<330
  local rowH=compact and 48 or mobile and 60 or 66
  local gap=compact and 6 or 10
  local labelH=compact and 22 or 26
  local arrowH=compact and 16 or 26
  local actionH=compact and 42 or 50
  local footerH=compact and 26 or 30
  local radius=compact and 12 or 14
  local margin=6 -- room inside scrolling lists for row rims and hover growth
  local function caption(name,value)
   sidebarText(p,name,value,x,yy,w,labelH,compact and 13 or 15,SB.Muted).ZIndex=z+1;yy+=labelH+4
  end
  local function accountRow(parent,name,row,py,rw,fn,variant,rightW)
   local b=button(parent,name,"",parent==p and x or margin,py,rw,rowH,fn,Color3.new(1,1,1),C.Text,14,parent.ZIndex+1)
   rowSurface(b,variant,radius,2);if fx then fx:Selected(b,variant~="Navy")end
   local iconSize=compact and 26 or mobile and 30 or 34;local nx=compact and 10 or 14
   -- The decorative icon is dropped on the narrowest rows to protect the account name.
   if rw-rightW>=210 then local cash=summaryIcon(b,"Balance",nx,(rowH-iconSize)/2,iconSize);cash.ZIndex=b.ZIndex+3;nx+=iconSize+(compact and 8 or 12)end
   local nw=rw-nx-rightW-10
   local nameSize=compact and 16 or mobile and 18 or 19;local detailSize=compact and 11 or 12
   local nameH=nameSize+4;local detailH=detailSize+4;local ty=math.floor((rowH-nameH-detailH)/2)
   sidebarText(b,"Name",row and row.Short or"Choose account",nx,ty,nw,nameH,nameSize).ZIndex=b.ZIndex+3
   local detail=row and("Balance "..Market.Money(row.Balance or 0))or"Trade this account"
   text(b,"Detail",detail,nx,ty+nameH,nw,detailH,detailSize,Color3.fromRGB(214,232,255),M,nil,b.ZIndex+3).TextTruncate=AtEnd
   if row then b:SetAttribute("AccountKey",row.Key)end
   return b
  end
  caption("LeaderLabel","COPY FROM")
  local lead=draft.Leader and byKey[draft.Leader]
  local cueW=compact and 92 or mobile and 96 or 112;local cueH=compact and 30 or 34
  local selector=accountRow(p,"LeaderSelector",lead,yy,w,function()if not s.PendingCopy then draft.Picking=not draft.Picking;edit()end end,lead and"Purple"or"Navy",cueW+12)
  selector:SetAttribute("Open",draft.Picking==true)
  local cue=frame(selector,"Change",w-cueW-12,math.floor((rowH-cueH)/2),cueW,cueH,Color3.new(1,1,1),selector.ZIndex+2)
  round(cue,10);stroke(cue,C.Cyan).Thickness=2;tint(cue,Color3.fromRGB(15,48,117),Color3.fromRGB(3,24,66))
  sidebarText(cue,"Label",lead and"Change"or"Choose",12,0,cueW-40,cueH,compact and 13 or mobile and 14 or 15).ZIndex=cue.ZIndex+2
  local up=draft.Picking==true
  local mx,my=cueW-19,math.floor(cueH/2)
  line(cue,"Chevron",mx-6,up and my+3 or my-3,mx,up and my-3 or my+3,C.Text,3,cue.ZIndex+2)
  line(cue,"Chevron",mx,up and my-3 or my+3,mx+6,up and my+3 or my-3,C.Text,3,cue.ZIndex+2)
  yy+=rowH+gap
  local pickerY=yy
  -- Flow arrow from the source down to its followers.
  local ax=x+w/2;local ay=yy+math.floor((arrowH-18)/2)
  line(p,"FlowArrow",ax,ay,ax,ay+16,C.Cyan,3,z+2)
  line(p,"FlowArrow",ax-6,ay+10,ax,ay+16,C.Cyan,3,z+2)
  line(p,"FlowArrow",ax,ay+16,ax+6,ay+10,C.Cyan,3,z+2)
  yy+=arrowH
  local followers={};local targets={}
  for _,row in ipairs(usable)do if row.Key~=draft.Leader then
   table.insert(targets,row);if draft.Followers[row.Key]then table.insert(followers,row.Key)end
  end end
  local selected=sidebarText(p,"SelectedCount",tostring(#followers).." selected",x+w-110,yy,110,labelH,compact and 12 or 13,SB.Muted)
  selected.TextXAlignment=RIGHT;selected.ZIndex=z+1
  caption("FollowLabel","COPY TO")
  -- At most three rows show; the list scrolls so the primary action below always stays in view.
  local step=rowH+gap
  local viewRows=math.min(#targets,3)*step-gap
  if maxH then viewRows=math.min(viewRows,math.max(rowH,maxH-(yy-y)-gap-actionH-gap-footerH))end
  local listTotal=#targets*step-gap+margin*2
  local listH=viewRows+margin*2
  local overflow=listTotal>listH+1
  local list=make("ScrollingFrame","FollowerList",p,{Position=UDim2.fromOffset(x-margin,yy-margin),Size=UDim2.fromOffset(w+margin*2,listH),
   CanvasSize=UDim2.fromOffset(0,listTotal),BackgroundTransparency=1,BorderSizePixel=0,
   ScrollBarThickness=overflow and 5 or 0,ScrollBarImageColor3=C.Cyan,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=z})
  local rw=w-(overflow and 10 or 0)
  list.CanvasPosition=Vector2.new(0,math.clamp(draft.Scroll or 0,0,math.max(0,listTotal-listH)))
  list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()draft.Scroll=list.CanvasPosition.Y end)
  local boxSize=compact and 26 or 30
  for i,row in ipairs(targets)do
   local on=draft.Followers[row.Key]==true
   local b=accountRow(list,"Follow"..row.Key,row,margin+(i-1)*step,rw,function()
    if s.PendingCopy then return end
    draft.Followers[row.Key]=(not on)or nil;edit()
   end,on and"Cyan"or"Navy",boxSize+14)
   b:SetAttribute("Checked",on)
   local box=frame(b,"Checkbox",rw-boxSize-14,math.floor((rowH-boxSize)/2),boxSize,boxSize,on and SC.Green or Color3.fromRGB(3,24,70),b.ZIndex+2)
   round(box,8);stroke(box,on and SC.Ink or Color3.fromRGB(120,170,240)).Thickness=2
   if on then
    local k=boxSize/30
    line(box,"Tick",7*k,15*k,12*k,21*k,SC.Ink,4,box.ZIndex+1);line(box,"Tick",12*k,21*k,23*k,9*k,SC.Ink,4,box.ZIndex+1)
   end
  end
  yy+=viewRows+gap
  local changed=draft.Leader~=savedLeader
  for _,row in ipairs(usable)do if row.Key~=draft.Leader and(draft.Followers[row.Key]==true)~=(saved[row.Key]==true)then changed=true end end
  local valid=lead~=nil and #followers>0
  local stopping=enabled and not changed
  local label=stopping and"Stop Copying"or enabled and"Save Changes"or"Start Copying"
  if s.PendingCopy then label="Saving…"
  elseif not stopping and not lead then label="Choose an account"
  elseif not stopping and #followers==0 then label="Select an account to copy to"end
  local can=not s.PendingCopy and(stopping or valid)
  local function submit(turnOn)
   if s.PendingCopy then return end
   local ok,message,_,id=session:Copy(turnOn,turnOn and draft.Leader or copy.Leader,turnOn and followers or(copy.Followers or{}),copy.Sizing or"Same")
   if not ok then fail(message);return end
   local request={Id=id};s.PendingCopy=request;s.CopyDraft=draft;refresh()
   task.delay(8,function()if alive and s.PendingCopy==request then s.PendingCopy=nil;refresh()end end)
  end
  -- Actions share the rows' corner radius. With an edited live setup, Stop stays available even if
  -- the draft is incomplete.
  local function action(b,variant)
   glossy(b,variant);b.Corners.CornerRadius=UDim.new(0,radius);b.Border.Thickness=3;b:SetAttribute("Debounce",1)
   return b
  end
  local stopW=enabled and changed and(mobile and 76 or 100)or 0
  local save=action(button(p,"SaveCopy",label,x,yy,w-(stopW>0 and stopW+10 or 0),actionH,function()if can then submit(not stopping)end end,C.Raised,C.Text,compact and 17 or mobile and 18 or 20,z),stopping and"Pink"or can and"Purple"or"Navy")
  save.Active=can;save:SetAttribute("Changed",changed)
  if not can then save.ControlLabel.TextColor3=C.Muted end
  if stopW>0 then
   local stop=action(button(p,"StopCopy","Stop",x+w-stopW,yy,stopW,actionH,function()submit(false)end,C.Raised,C.Text,mobile and 16 or 18,z),"Pink")
   stop.Active=not s.PendingCopy
  end
  yy+=actionH+gap
  local rules="Only new trades are copied. Each account uses its own funds and risk limits; copies may be skipped or rejected. Stopping copying never closes positions."
  local infoSize=22;local iy=yy+(compact and 1 or 2)
  local infoButton=button(p,"CopyInfo","i",x,iy,infoSize,infoSize,function()
   local tip=p:FindFirstChild("CopyRules");if tip then tip.Visible=not tip.Visible end
  end,SB.Navy,C.Cyan,14,z+2)
  infoButton.Corners.CornerRadius=UDim.new(0,infoSize/2);infoButton.Border.Color=C.Cyan;infoButton.Border.Thickness=2
  text(p,"CopyHint","Only new trades are copied.",x+infoSize+8,iy,w-infoSize-8,infoSize,compact and 12 or 13,C.Muted,M,nil,z+1).TextTruncate=AtEnd
  local tip=frame(p,"CopyRules",x,math.max(y,iy-96),w,90,SB.Navy,z+20);round(tip,12);stroke(tip,C.Cyan).Thickness=2;tip.Visible=false
  local detail=text(tip,"Text",rules,12,8,w-24,74,12,C.Text,M,nil,tip.ZIndex+1);detail.TextWrapped=true
  infoButton.MouseEnter:Connect(function()tip.Visible=true end)
  infoButton.MouseLeave:Connect(function()tip.Visible=false end)
  yy+=footerH
  if up then
   local itemH=compact and 42 or 46;local itemGap=6;local pm=6
   local pickTotal=#usable*(itemH+itemGap)-itemGap+pm*2
   local pickH=math.min(pickTotal,math.max(itemH+pm*2,yy-pickerY-actionH-footerH-gap*2))
   local scroll=pickTotal>pickH
   local picker=make("ScrollingFrame","LeaderChoices",p,{Position=UDim2.fromOffset(x,pickerY),Size=UDim2.fromOffset(w,pickH),
    CanvasSize=UDim2.fromOffset(0,pickTotal),BackgroundColor3=SB.Navy,BorderSizePixel=0,
    ScrollBarThickness=scroll and 5 or 0,ScrollBarImageColor3=C.Cyan,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=z+12})
   round(picker,radius);stroke(picker,C.Cyan).Thickness=2;picker:SetAttribute("StaticButtons",true)
   local pw2=w-pm*2-(scroll and 8 or 0)
   for i,row in ipairs(usable)do
    local on=row.Key==draft.Leader
    local b=button(picker,"ChooseLeader"..row.Key,"",pm,pm+(i-1)*(itemH+itemGap),pw2,itemH,function()
     if s.PendingCopy then return end
     draft.Leader=row.Key;draft.Followers[row.Key]=nil;draft.Picking=false;draft.Scroll=0;edit()
    end,Color3.new(1,1,1),C.Text,14,picker.ZIndex+1)
    rowSurface(b,on and"Purple"or"Navy",10,2);b:SetAttribute("AccountKey",row.Key)
    local ns=compact and 15 or 17;local ty=math.floor((itemH-ns-4-15)/2)
    sidebarText(b,"Name",row.Short,12,ty,pw2-24,ns+4,ns).ZIndex=b.ZIndex+3
    text(b,"Balance",Market.Money(row.Balance or 0),12,ty+ns+4,pw2-24,15,11,Color3.fromRGB(214,232,255),M,nil,b.ZIndex+3).TextTruncate=AtEnd
   end
  end
  return yy-y
 end
]==]}
P[8]={From=[==[   accountCards(12,head,cx,56,true)
   chart(12,head+64,cx,h-head-76,true,true,true)]==],To=[==[]==],New=[==[   accountCards(12,head,cx,64,true)
   chart(12,head+72,cx,h-head-84,true,true,true)]==]}
P[9]={From=[==[   accountCards(12,head,w-24,dense and 54 or 58,true)]==],To=[==[]==],New=[==[   accountCards(12,head,w-24,dense and 64 or 68,true)]==]}
P[10]={From=[==[   local cy=head+(dense and 62 or 68)]==],To=[==[]==],New=[==[   local cy=head+(dense and 72 or 78)]==]}
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
