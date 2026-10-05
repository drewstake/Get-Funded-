import re,sys
spec=open(sys.argv[1],encoding='utf-8').read()
entries=re.findall(r'P\[(\d+)\]=\{From=\[==\[(.*?)\]==\],To=\[==\[(.*?)\]==\],New=\[==\[(.*?)\]==\]\}',spec,re.S)
def ls(s): return s[1:] if s.startswith('\n') else s
path=sys.argv[2]
src=open(path,encoding='utf-8',newline='').read()
for i,f,t,n in entries:
    f,t,n=ls(f),ls(t),ls(n)
    a=src.find(f); assert a>=0,f"patch {i}: From not found"
    assert src.find(f,a+1)<0,f"patch {i}: From not unique"
    b=a+len(f) if t=="" else src.find(t,a+len(f)); assert b>=0,f"patch {i}: To not found"
    src=src[:a]+n+src[b:]
open(path,'w',encoding='utf-8',newline='').write(src)
print(len(entries),"patches applied",len(src.encode('utf-8')))
