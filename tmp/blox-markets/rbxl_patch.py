# Write a copy of a binary .rbxl with script Source strings replaced from a folder of <FullName>.luau files.
# Only PROP "Source" chunks are rebuilt (stored uncompressed); every other chunk is copied byte for byte.
import struct,sys,os
sys.path.insert(0,os.path.dirname(__file__))
from rbxl_dump import chunks,refs,strs
import zstandard
def raw_chunks(data):
    p=32
    while p<len(data):
        name=data[p:p+4];cl,ul,res=struct.unpack('<III',data[p+4:p+16]);start=p;p+=16
        body_raw=data[p:p+(cl or ul)];p+=(cl or ul)
        yield name,data[start:p],cl,ul
        if name==b'END\0':break
def main(src,folder,dest):
    data=open(src,'rb').read()
    # Pass 1: referents, names, parents (decoded).
    classes={};props={};parent={};inst={}
    for name,b in chunks(data):
        if name==b'INST':
            cid=struct.unpack('<I',b[:4])[0];l=struct.unpack('<I',b[4:8])[0];cn=b[8:8+l].decode();p=8+l+1
            n=struct.unpack('<I',b[p:p+4])[0];p+=4;r=refs(b[p:p+4*n],n);classes[cid]=(cn,r)
            for x in r:inst[x]=cn
        elif name==b'PROP':
            cid=struct.unpack('<I',b[:4])[0];l=struct.unpack('<I',b[4:8])[0];pn=b[8:8+l].decode();t=b[8+l]
            if pn=='Name' and t==1:
                vals,_=strs(b,9+l,len(classes[cid][1]))
                for x,v in zip(classes[cid][1],vals):props.setdefault(x,{})['Name']=v.decode('utf-8','replace')
        elif name==b'PRNT':
            n=struct.unpack('<I',b[1:5])[0];c=refs(b[5:5+4*n],n);pa=refs(b[5+4*n:5+8*n],n)
            for a,bb in zip(c,pa):parent[a]=bb
    def full(x):
        parts=[]
        while x is not None and x!=-1 and x in inst:
            parts.append(props.get(x,{}).get('Name','?'));x=parent.get(x)
        return '.'.join(reversed(parts))
    replacements={}
    for f in os.listdir(folder):
        if f.endswith('.luau'):replacements[f[:-5]]=open(os.path.join(folder,f),'rb').read()
    out=bytearray(data[:32]);changed=[]
    decoded=dict()
    for (name,b),(rname,rawbytes,cl,ul) in zip(chunks(data),raw_chunks(data)):
        if name==b'PROP':
            cid=struct.unpack('<I',b[:4])[0];l=struct.unpack('<I',b[4:8])[0];pn=b[8:8+l].decode();t=b[8+l]
            if pn=='Source' and t==1:
                r=classes[cid][1];vals,end=strs(b,9+l,len(r))
                body=bytearray(b[:9+l])
                for x,v in zip(r,vals):
                    nv=replacements.get(full(x),v)
                    if nv!=v:changed.append(full(x))
                    body+=struct.pack('<I',len(nv))+nv
                body+=b[end:]
                out+=name+struct.pack('<III',0,len(body),0)+body
                continue
        out+=rawbytes
    open(dest,'wb').write(bytes(out))
    return changed
if __name__=='__main__':
    ch=main(sys.argv[1],sys.argv[2],sys.argv[3])
    print(len(ch),'scripts replaced');print('\n'.join(sorted(ch)))
