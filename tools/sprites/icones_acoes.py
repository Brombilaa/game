# Recorta a folha de ícones das ações (arte do Léo, fundo xadrez falso) em 64×64 transparentes.
# Uso: python3 tools/sprites/icones_acoes.py (ajuste o caminho da folha em `Image.open`).
from PIL import Image
import numpy as np
from scipy import ndimage
im=Image.open("/root/.claude/uploads/c878030f-2800-5494-8950-7d0b4d6f119f/c031e84c-image.png").convert("RGB")
a=np.array(im).astype(int)
mx=a.max(2); mn=a.min(2)
bgcand=(mn>=205)&((mx-mn)<=10)
lab,n=ndimage.label(bgcand)
border=set(lab[0,:])|set(lab[-1,:])|set(lab[:,0])|set(lab[:,-1]); border.discard(0)
sizes=ndimage.sum(np.ones_like(lab),lab,range(n+1))
big=[i for i in range(1,n+1) if sizes[i]>=150 or i in border]
bg=np.isin(lab,big)
fg=~bg
fg=ndimage.binary_opening(fg,iterations=1)
lab2,m=ndimage.label(ndimage.binary_dilation(fg,iterations=6))
objs=ndimage.find_objects(lab2)
rgba=np.dstack([a.astype(np.uint8),(fg*255).astype(np.uint8)])
full=Image.fromarray(rgba,"RGBA")
res=[]
for sl in objs:
    y,x=sl
    if (y.stop-y.start)*(x.stop-x.start)<20000: continue
    res.append((x.start,y.start,x.stop,y.stop))
res.sort(key=lambda b:(b[1]//400,b[0]))
print(len(res),res)
names=["pistola","escopeta","espada","kit","atrasar","ampulheta"]
for nme,b in zip(names,res):
    c=full.crop(b); c=c.crop(c.getbbox())
    s=64/max(c.size)
    c=c.resize((max(1,round(c.width*s)),max(1,round(c.height*s))),Image.LANCZOS)
    cv=Image.new("RGBA",(64,64),(0,0,0,0)); cv.paste(c,((64-c.width)//2,(64-c.height)//2)); cv.save(f"assets/sprites/ui/acoes/{nme}.png")
o=Image.new("RGBA",(192*6,192),(40,30,25,255))
for i,n in enumerate(names):
    t=Image.open(f"assets/sprites/ui/acoes/{n}.png").resize((192,192),Image.NEAREST); o.alpha_composite(t,(i*192,0))
o.save("/tmp/claude-0/-home-user-game/c878030f-2800-5494-8950-7d0b4d6f119f/scratchpad/icons.png")
