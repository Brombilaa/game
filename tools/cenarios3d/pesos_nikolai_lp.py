import json,struct,io,numpy as np
from scipy.spatial import cKDTree
def read(f):
    b=open(f,'rb').read();l=struct.unpack('<I',b[12:16])[0];j=json.loads(b[20:20+l]);o=20+l+8
    bl=struct.unpack('<I',b[20+l:24+l])[0];return j,b[o:o+bl]
def acc(j,bin_,i):
    a=j['accessors'][i];bv=j['bufferViews'][a['bufferView']]
    ct={5126:'f4',5125:'u4',5123:'u2',5121:'u1'}[a['componentType']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    off=bv.get('byteOffset',0)+a.get('byteOffset',0);stride=bv.get('byteStride')
    dt=np.dtype(ct);
    if stride and stride!=dt.itemsize*n:
        raw=np.frombuffer(bin_,dtype='u1',count=a['count']*stride,offset=off).reshape(a['count'],stride)[:,:dt.itemsize*n].copy()
        return raw.view(dt).reshape(a['count'],n)
    return np.frombuffer(bin_,dtype=dt,count=a['count']*n,offset=off).reshape(a['count'],n)
jl,bl=read('/mnt/project-files/arte/estilo-pc-antigo/ni_lp.glb')
p=jl['meshes'][0]['primitives'][0]
P=acc(jl,bl,p['attributes']['POSITION']).astype(np.float64);UV=acc(jl,bl,p['attributes']['TEXCOORD_0']).astype(np.float32);IDX=acc(jl,bl,p['indices'])[:,0].astype(np.int64)
# nós do ni_lp podem ter transform
print('ni_lp',P.shape,IDX.shape,P.min(0),P.max(0),jl['nodes'])
img=jl['images'][0];bv=jl['bufferViews'][img['bufferView']];png=bl[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
js,bs=read('n3.glb')
sp=js['meshes'][0]['primitives'][0]
Q=acc(js,bs,sp['attributes']['POSITION']).astype(np.float64);J0=acc(js,bs,sp['attributes']['JOINTS_0']).astype(np.uint16);W0=acc(js,bs,sp['attributes']['WEIGHTS_0']).astype(np.float64)
J1=acc(js,bs,sp['attributes']['JOINTS_1']).astype(np.uint16);W1=acc(js,bs,sp['attributes']['WEIGHTS_1']).astype(np.float64)
print('n3',Q.shape,Q.min(0),Q.max(0))
# alinha: mesma altura, pés em y=min, centro xz (bbox)
def norm(V):
    mn,mx=V.min(0),V.max(0);return (V-[(mn[0]+mx[0])/2,mn[1],(mn[2]+mx[2])/2])/(mx[1]-mn[1])
Pn=norm(P);Qn=norm(Q)
tree=cKDTree(Qn);d,ii=tree.query(Pn,k=4)
print('dist médio',d[:,0].mean(),'max',d[:,0].max())
# junta influências dos 4 vizinhos (peso 1/d) e fica com as 4 maiores por vértice
Jall=np.concatenate([J0,J1],1);Wall=np.concatenate([W0,W1],1)
Jn=np.zeros((len(P),4),np.uint16);Wn=np.zeros((len(P),4),np.float32)
for v in range(len(P)):
    acc_={}
    ws=1/(d[v]+1e-6);ws/=ws.sum()
    for k in range(4):
        for jj,ww in zip(Jall[ii[v,k]],Wall[ii[v,k]]):
            if ww>0: acc_[int(jj)]=acc_.get(int(jj),0)+ww*ws[k]
    top=sorted(acc_.items(),key=lambda t:-t[1])[:4];s=sum(w for _,w in top)
    for q,(jj,ww) in enumerate(top): Jn[v,q]=jj;Wn[v,q]=ww/s
# escala para o espaço do n3 (altura do bbox original) e posição: inverso de norm usando Q
mn,mx=Q.min(0),Q.max(0);H=mx[1]-mn[1]
Pw=Pn*H+[(mn[0]+mx[0])/2,mn[1],(mn[2]+mx[2])/2]
# normais planas: desfaz índices
F=IDX.reshape(-1,3);tri=Pw[F]  # (n,3,3)
nrm=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);nrm/=np.linalg.norm(nrm,axis=1,keepdims=True)+1e-20
pos=tri.reshape(-1,3).astype(np.float32);nor=np.repeat(nrm,3,axis=0).astype(np.float32)
uv=UV[F.reshape(-1)];jo=Jn[F.reshape(-1)];we=Wn[F.reshape(-1)]
# monta novo glb a partir do n3
blob=bytearray(bs)
def add(data,comp,typ,target=34962,minmax=False):
    global blob
    while len(blob)%4: blob.append(0)
    off=len(blob);blob+=data.tobytes()
    bvi=len(js['bufferViews']);js['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':data.nbytes,'target':target})
    a={'bufferView':bvi,'componentType':comp,'count':int(len(data)),'type':typ}
    if minmax: a['min']=data.min(0).tolist();a['max']=data.max(0).tolist()
    js['accessors'].append(a);return len(js['accessors'])-1
sp['attributes']={'POSITION':add(pos,5126,'VEC3',minmax=True),'NORMAL':add(nor,5126,'VEC3'),'TEXCOORD_0':add(uv,5126,'VEC2'),'JOINTS_0':add(jo.astype(np.uint16),5123,'VEC4'),'WEIGHTS_0':add(we,5126,'VEC4')}
sp.pop('indices',None)
# textura do ni_lp
while len(blob)%4: blob.append(0)
off=len(blob);blob+=png
bvi=len(js['bufferViews']);js['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(png)})
js['images'][0]={'bufferView':bvi,'mimeType':'image/png'}
js['buffers'][0]['byteLength']=len(blob)
jb=json.dumps(js,separators=(',',':')).encode()
while len(jb)%4: jb+=b' '
while len(blob)%4: blob.append(0)
out=b'glTF'+struct.pack('<II',2,12+8+len(jb)+8+len(blob))+struct.pack('<I',len(jb))+b'JSON'+jb+struct.pack('<I',len(blob))+b'BIN\x00'+bytes(blob)
open('ni_lp_skin.glb','wb').write(out);print('ok',len(out)//1024,'KB',len(pos)//3,'tris')
