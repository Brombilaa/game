import sys,glob,os,numpy as np
from PIL import Image
from scipy import ndimage
F=int(os.environ.get('F','6'))
def palette(n=28):
    ims=[np.array(Image.open(p).convert('RGBA')) for p in glob.glob('/home/user/game/assets/sprites/personagens/legado_2d/nikolai_*.png')]
    px=np.concatenate([i[i[...,3]>200][:,:3] for i in ims])
    q=Image.fromarray(px[None,:,:].astype(np.uint8)).quantize(n,method=Image.MEDIANCUT,dither=Image.NONE)
    pal=np.array(q.getpalette()[:n*3]).reshape(-1,3)
    return pal
def box(a):
    h,w=a.shape[:2];return a.reshape(h//F,F,w//F,F,-1).mean((1,3))
def self_palette(dirs,n):
    import glob
    px=[]
    for d in dirs:
        for p in sorted(glob.glob(d+'/d*_f*_c.png'))[::3]:
            c=np.array(Image.open(p).convert('RGBA')).astype(float);al=c[...,3]/255
            A=box(al[...,None])[...,0];C=box(c[...,:3]*al[...,None])/np.maximum(A[...,None],1e-3)
            C=np.clip((C-float(os.environ.get('LO','0')))/(float(os.environ.get('HI','255'))-float(os.environ.get('LO','0'))),0,1)**float(os.environ.get('GAMMA','1.0'))*255*float(os.environ.get('GAIN','1.0'))
            px.append(np.clip(C[A>0.5],0,255))
    px=np.concatenate(px).astype(np.uint8)
    q=Image.fromarray(px[None,:,:]).quantize(n,method=Image.MEDIANCUT,dither=Image.NONE)
    return np.array(q.getpalette()[:n*3]).reshape(-1,3)
def _box_defined(): pass
PAL=None
def conv(cp,np_):
    c=np.array(Image.open(cp).convert('RGBA')).astype(float);n=np.array(Image.open(np_).convert('RGBA')).astype(float)
    al=c[...,3]/255
    prem=c[...,:3]*al[...,None]
    A=box(al[...,None])[...,0];C=box(prem)/np.maximum(A[...,None],1e-3)
    N=box(n[...,:3]*al[...,None])/np.maximum(A[...,None],1e-3)
    return C,A,N
def toPal(C):
    d=((C[:,:,None,:]-PAL[None,None])**2).sum(-1);return PAL[d.argmin(-1)]
def frame(cp,np_,gain=float(os.environ.get('GAIN','1.0'))):
    C,A,N=conv(cp,np_)
    C=np.stack([ndimage.gaussian_filter(C[...,k],float(os.environ.get("BLUR","0.6"))) for k in range(3)],-1);lo,hi=float(os.environ.get('LO','0')),float(os.environ.get('HI','255'));C=np.clip((C-lo)/(hi-lo),0,1)**float(os.environ.get('GAMMA','1.0'))*255*gain if False else np.clip(((C-lo)/(hi-lo)),0,1)**float(os.environ.get('GAMMA','1.0'))*255*gain;C=np.clip(C,0,255)
    m=A>0.5
    out=toPal(C).astype(np.uint8)
    # arestas internas por normais
    gy=np.abs(np.diff(N,axis=0,prepend=N[:1])).sum(-1);gx=np.abs(np.diff(N,axis=1,prepend=N[:,:1])).sum(-1)
    edge=((gx+gy)>float(os.environ.get('ET','90')))&m
    edge&=ndimage.binary_erosion(m,iterations=1)
    dark=PAL[PAL.sum(1).argmin()]
    res=out.copy()
    res[edge]=(out[edge]*float(os.environ.get("EF","0.75"))).astype(np.uint8)
    # contorno externo
    ring=ndimage.binary_dilation(m,structure=np.ones((3,3)))&~m
    res=np.where(m[...,None],res,0).astype(np.uint8)
    rgba=np.dstack([res,(m*255).astype(np.uint8)])
    if os.environ.get('SELOUT'):
        # cor do vizinho mais proximo x0.42
        idx=ndimage.distance_transform_edt(~m,return_distances=False,return_indices=True)
        nb=res[idx[0],idx[1]]
        rgba[ring]=np.dstack([(nb*0.42).astype(np.uint8),np.full(m.shape,255,np.uint8)])[ring]
    else:
        ol=np.zeros_like(rgba);ol[ring]=[*(dark//2+8),255]
        rgba[ring]=ol[ring]
    return Image.fromarray(rgba)
def init_palette(dirs,n):
    global PAL
    PAL=self_palette(dirs,n)
    ex=os.environ.get('EXTRA')
    if ex:
        add=np.array([[int(h[i:i+2],16) for i in (0,2,4)] for h in ex.split(',')])
        PAL=np.concatenate([PAL,add])
def sheet(d,n,dirs):
    out={}
    for k in dirs:
        fr=[frame(f'{d}/d{k}_f{i:02d}_c.png',f'{d}/d{k}_f{i:02d}_n.png') for i in range(n)]
        s=Image.new('RGBA',(int(os.environ.get('FSZ','1152'))//F*n,int(os.environ.get('FSZ','1152'))//F));[s.paste(f,(int(os.environ.get('FSZ','1152'))//F*i,0)) for i,f in enumerate(fr)];out[k]=s
    return out
if __name__=='__main__':
    d,n,o=sys.argv[1],int(sys.argv[2]),sys.argv[3]
    os.makedirs(o,exist_ok=True)
    for k,s in sheet(d,n,range(5)).items(): s.save(f'{o}/d{k}.png')
