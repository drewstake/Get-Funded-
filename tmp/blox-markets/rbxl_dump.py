# Extract script sources from a binary .rbxl (ZSTD/LZ4 chunks) into a folder: <FullName>.luau
import struct,sys,os,zstandard
def lz4(src,size):
    out=bytearray();i=0
    while i<len(src):
        t=src[i];i+=1;l=t>>4
        if l==15:
            while True:
                b=src[i];i+=1;l+=b
                if b!=255:break
        out+=src[i:i+l];i+=l
        if i>=len(src):break
        off=src[i]|src[i+1]<<8;i+=2;m=t&15
        if m==15:
            while True:
                b=src[i];i+=1;m+=b
                if b!=255:break
        m+=4;s=len(out)-off
        for k in range(m):out.append(out[s+k])
    return bytes(out)
def chunks(data):
    p=32
    while p<len(data):
        name=data[p:p+4];cl,ul=struct.unpack('<II',data[p+4:p+12]);p+=16
        if cl==0:body=data[p:p+ul];p+=ul
        else:
            raw=data[p:p+cl];p+=cl
            body=zstandard.ZstdDecompressor().decompress(raw,max_output_size=ul) if raw[:4]==b'\x28\xb5\x2f\xfd' else lz4(raw,ul)
        yield name,body
        if name==b'END\0':break
def ints(b,n):
    vals=[]
    for k in range(n):
        v=(b[k]<<24)|(b[n+k]<<16)|(b[2*n+k]<<8)|b[3*n+k]
        vals.append((v>>1)^-(v&1))
    return vals
def refs(b,n):
    v=ints(b,n);acc=0;out=[]
    for x in v:acc+=x;out.append(acc)
    return out
def strs(b,p,n):
    out=[]
    for _ in range(n):
        l=struct.unpack('<I',b[p:p+4])[0];p+=4;out.append(b[p:p+l]);p+=l
    return out,p
def load(path):
    data=open(path,'rb').read();classes={};inst={};parent={};props={}
    for name,b in chunks(data):
        if name==b'INST':
            cid=struct.unpack('<I',b[:4])[0];l=struct.unpack('<I',b[4:8])[0];cn=b[8:8+l].decode();p=8+l+1
            n=struct.unpack('<I',b[p:p+4])[0];p+=4;r=refs(b[p:p+4*n],n);classes[cid]=(cn,r)
            for x in r:inst[x]=cn
        elif name==b'PROP':
            cid=struct.unpack('<I',b[:4])[0];l=struct.unpack('<I',b[4:8])[0];pn=b[8:8+l].decode();p=8+l;t=b[p];p+=1
            if pn in('Name','Source') and t==1:
                r=classes[cid][1];vals,_=strs(b,p,len(r))
                for x,v in zip(r,vals):props.setdefault(x,{})[pn]=v
        elif name==b'PRNT':
            n=struct.unpack('<I',b[1:5])[0];c=refs(b[5:5+4*n],n);pa=refs(b[5+4*n:5+8*n],n)
            for a,bb in zip(c,pa):parent[a]=bb
    def full(x):
        parts=[]
        while x is not None and x!=-1 and x in inst:
            parts.append(props.get(x,{}).get('Name',b'?').decode('utf-8','replace'));x=parent.get(x)
        return '.'.join(reversed(parts))
    return {full(x):(inst[x],v['Source']) for x,v in props.items() if 'Source' in v}
if __name__=='__main__':
    src,dest=sys.argv[1],sys.argv[2];os.makedirs(dest,exist_ok=True)
    for name,(cls,s) in sorted(load(src).items()):
        open(os.path.join(dest,name+'.luau'),'wb').write(s);print(cls,name,len(s))
