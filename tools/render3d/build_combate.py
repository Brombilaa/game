"""Pixeliza as animações de combate do Nikolai em D3 (quadro 384, selout) e grava as folhas do jogo.

Uso: python3 -I build_combate.py <pasta dos renders r/> <pasta de saída>
Cada animação precisa de r/<nome>/d<0..4>_f<NN>_<c|n>.png (render2.html + frames2.js, hp=12 lift=16).
A paleta vem de r/walk, r/idle e r/run, como nas folhas de andar e parado.
"""
import os, sys, importlib.util
import numpy as np
from PIL import Image

os.environ.update(F='3', SELOUT='1', GAIN='1.0', ET='170', EF='0.8', BLUR='0.01', NC='32')
spec = importlib.util.spec_from_file_location('px', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'pixelize.py'))
px = importlib.util.module_from_spec(spec)
spec.loader.exec_module(px)

R, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
FEET = 368  # linha dos pés no quadro de 384 (mesma das folhas de andar e parado)
NAMES = ['s', 'se', 'e', 'ne', 'n']
# animação -> (renderização, quadros). Soco, chute, morte e levantar são renderizados com w=1728 e saem em
# quadros de 576x512 (morte 704x512) (o corpo deitado ou no lance do soco não cabe no quadro de 384).
A = {
    'pistol_shoot': ('pistol_shoot', 8), 'rifle_fire': ('rifle_fire', 8), 'punch': ('punch', 8),
    'kick': ('kick', 8), 'hit': ('hit', 8), 'death': ('death', 12), 'getup': ('getup', 12),
}
BIG = {'punch', 'kick', 'death', 'getup'}
WIDTH = {'death': 704}  # o corpo deitado é mais comprido que o quadro de 576
FH = 512
px.init_palette([f'{R}/walk', f'{R}/idle', f'{R}/run'], 40)
for anim, (src, n) in A.items():
    FS = WIDTH.get(anim, 576 if anim in BIG else 384)
    os.environ['FSZ'] = str(FS * 3)
    S = px.sheet(f'{R}/{src}', n, range(5))
    # pés alinhados pelo quadro de pé (primeiro; no levantar, o último), igual para as 5 direções
    mx = 0
    for k in range(5):
        i0 = (n - 1) * FS if anim == 'getup' else 0  # levantar termina de pé: alinha pelo último quadro
        al = np.array(S[k].crop((i0, 0, i0 + FS, FS)))[..., 3] > 0
        mx = max(mx, np.where(al.any(1))[0].max())
    dy = FEET - 1 - mx
    for k in range(5):
        s = Image.new('RGBA', S[k].size, (0, 0, 0, 0))
        s.paste(S[k], (0, dy))
        if anim in BIG:
            assert not np.array(s)[FH:, :, 3].any(), f'{anim} {NAMES[k]}: quadro passa de {FH} px de altura'
            s = s.crop((0, 0, s.width, FH))
        s.save(f'{OUT}/nikolai3d_{anim}_{NAMES[k]}.png')
    print(anim, n, 'dy', dy)
