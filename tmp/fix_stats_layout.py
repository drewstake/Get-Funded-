exec((__import__('pathlib').Path(__file__).parent/'fix_chart_ui.py').read_text().split("s=read('ChartViewport.luau')")[0])
s=read('StatsView.luau')
s=s.replace('narrow and 12 or 14','15').replace('narrow and 12 or 13','15').replace('narrow and 11 or 12','15')
s=replace(s,'narrow and 10 or 12','14')
s=replace(s,'local yy=narrow and 60 or 72','local yy=narrow and 70 or 80')
s=replace(s,'cw,18,14','cw,24,14')
s=replace(s,'local bh=12+20+6+dh+(coverage and chH+6 or 0)+12','local eh=measure(eyebrow,14,bw)+6\n local bh=12+eh+6+dh+(coverage and chH+6 or 0)+12')
s=replace(s,'bw,20,15).TextXAlignment=LEFT','bw,eh,14).TextWrapped=true')
s=replace(s,'describe,16,38,bw','describe,16,18+eh,bw')
s=replace(s,'coverage,16,44+dh,bw','coverage,16,24+eh+dh,bw')
s=replace(s,'local kc=narrow and 2 or 4','local kc=narrow and 1 or 4')
s=replace(s,'local kh=mobile and 88 or 110','local kh=144')
start=s.index(' for i,k in ipairs(kpis)');end=s.index(' yy+=math.ceil(#kpis/kc)',start)
chunk=s[start:end]
chunk=chunk.replace('mobile and 8 or 12','12').replace('kw-24,18,mobile and 11 or 13','kw-24,24,16').replace('mobile and 28 or 34','42').replace('mobile and 30 or 38','38').replace('mobile and 22 or 32','32')
chunk=chunk.replace('mobile and 60 or 78','88').replace('mobile and 20 or 18','44').replace('mobile and 9 or 11','14').replace('cap.TextTruncate=AtEnd','cap.TextWrapped=true')
s=s[:start]+chunk+s[end:]
s=replace(s,'math.floor((cw+gap)/200)','math.floor((cw+gap)/250)')
s=replace(s,'local mh=mobile and 84 or 100','local mh=150')
start=s.index(' for i,m in ipairs(items)');end=s.index(' yy+=math.ceil(#items/mc)',start)
chunk=s[start:end]
chunk=chunk.replace('mobile and 8 or 10','10').replace('mw-24,16,mobile and 10 or 12,ctx.Muted','mw-24,36,14,C.Text').replace('l.TextTruncate=AtEnd','l.TextWrapped=true')
chunk=chunk.replace('mobile and 26 or 30','48').replace('mobile and 28 or 34','34').replace('mobile and 20 or 26','mobile and 23 or 28')
chunk=chunk.replace('mobile and 56 or 68','90').replace('mobile and 22 or 24','50').replace('mobile and 9 or 10','14').replace('cap.TextTruncate=AtEnd','cap.TextTruncate=Enum.TextTruncate.None')
s=s[:start]+chunk+s[end:]
s=replace(s,'local rh=narrow and 66 or 58','local rh=narrow and 90 or 70')
s=replace(s,'14,34,cw-28,22,10','14,38,cw-28,44,14').replace('dt.TextTruncate=AtEnd','dt.TextWrapped=true')
s=replace(s,'local ns=15','local ns=15')
s=replace(s,'mobile and 32 or 20,10','mobile and 48 or 24,14').replace('yy+=mobile and 40 or 28','yy+=mobile and 56 or 32')
write('StatsView.luau',s)


