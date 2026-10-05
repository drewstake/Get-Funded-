# Apply a JSON edit list to local src (CRLF-tolerant) and to the expected-Studio copies.
# Each edit: {"target": "<Studio path, e.g. ServerScriptService.MarketReign.MarketEngine>", "old": "...", "new": "...", "all": false}
# Local file is derived from the Studio path's leaf name (src/<Leaf>.luau or src/<Leaf>.server.luau).
import json,sys,os,hashlib,re
ROOT=os.path.expanduser('~/mnt/Get Funded!')
EXP=os.path.expanduser('~/studio-expected')
def local_path(target):
    leaf=target.split('.')[-1]
    for cand in (f'src/{leaf}.luau',f'src/{leaf}.server.luau',f'src/{leaf}.client.luau'):
        if os.path.exists(os.path.join(ROOT,cand)):return os.path.join(ROOT,cand)
    return os.path.join(ROOT,f'src/{leaf}.luau')
def apply(text,e,where):
    old,new=e['old'],e['new']
    if old=='':return new
    # Local mirrors sometimes carry an extra blank line after each line; tolerate blank lines between lines.
    pat=re.compile('\n(?:[ \t]*\n)*'.join(re.escape(l) for l in old.split('\n')))
    n=len(pat.findall(text))
    if n==0:raise SystemExit(f'NOT FOUND in {where}: {old[:80]!r}')
    if n>1 and not e.get('all'):raise SystemExit(f'AMBIGUOUS ({n}) in {where}: {old[:80]!r}')
    return pat.sub(lambda m:new,text,count=0 if e.get('all') else 1)
def norm_hash(t):
    lines=[l.rstrip() for l in t.replace('\r','').split('\n')]
    return hashlib.sha256('\n'.join(l for l in lines if l!='').encode()).hexdigest()[:16]
def parse(path):
    # Block format (no escaping):  "@@ <target> [all]" / old lines / "@@==" / new lines / "@@end"
    if path.endswith('.json'):return json.load(open(path,encoding='utf-8'))
    edits=[];cur=None;mode=None
    for line in open(path,encoding='utf-8').read().replace('\r','').split('\n'):
        if line.startswith('@@ '):
            parts=line[3:].split();cur={'target':parts[0],'all':'all' in parts[1:],'old':[],'new':[]};mode='old'
        elif line=='@@==':mode='new'
        elif line=='@@end':
            cur['old']='\n'.join(cur['old']);cur['new']='\n'.join(cur['new']);edits.append(cur);cur=None
        elif cur is not None:cur[mode].append(line)
    return edits
def main(path,mode):
    edits=parse(path)
    touched={}
    for e in edits:
        t=e['target']
        skip_local=e.get('studioOnly');skip_studio=e.get('localOnly')
        if not skip_local and mode in('both','local'):
            lp=local_path(t)
            if lp not in touched:
                raw=open(lp,'rb').read().decode('utf-8') if os.path.exists(lp) else ''
                touched[lp]=('crlf' if raw.count('\r\n')*2>raw.count('\n') else 'lf',raw.replace('\r',''))
            style,txt=touched[lp];touched[lp]=(style,apply(txt,e,lp))
        if not skip_studio and mode in('both','studio'):
            sp=os.path.join(EXP,t+'.luau')
            if sp not in touched:
                raw=open(sp,'rb').read().decode('utf-8') if os.path.exists(sp) else ''
                touched[sp]=('lf',raw.replace('\r',''))
            style,txt=touched[sp];touched[sp]=(style,apply(txt,e,sp))
    for p,(style,txt) in touched.items():
        out=txt.replace('\n','\r\n') if style=='crlf' else txt
        open(p,'wb').write(out.encode('utf-8'))
        print('wrote',os.path.relpath(p,os.path.expanduser('~')),norm_hash(txt))
if __name__=='__main__':main(sys.argv[1],sys.argv[2] if len(sys.argv)>2 else 'both')
