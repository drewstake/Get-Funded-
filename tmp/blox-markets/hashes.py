# Normalized hashes of local src and expected Studio copies, for comparison with live Studio.
import os,hashlib,glob,sys
def nh(p):
    t=open(p,'rb').read().decode('utf-8').replace('\r','')
    lines=[l.rstrip() for l in t.split('\n')]
    return hashlib.sha256('\n'.join(l for l in lines if l!='').encode()).hexdigest()[:16]
for p in sorted(glob.glob(os.path.expanduser('~/studio-expected/*.luau'))):
    name=os.path.basename(p)[:-5];leaf=name.split('.')[-1]
    loc=[c for c in (f'src/{leaf}.luau',f'src/{leaf}.server.luau',f'src/{leaf}.client.luau') if os.path.exists(os.path.expanduser('~/mnt/Get Funded!/')+c)]
    lh=nh(os.path.expanduser('~/mnt/Get Funded!/')+loc[0]) if loc else '-'
    print(name,nh(p),lh,'same' if lh==nh(p) else 'DIFF')
