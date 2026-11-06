"""Calibra o tom de cada material do parque 3D contra a referência em JS.

Uso: python3 tools/calibrar_tons.py SAIDA.gd REF1 GODOT1 ID1 [REF2 GODOT2 ID2 ...]
- REF: captura da página do JS já com o filtro CSS (saturate .84, contrast 1.06).
- GODOT: captura do Godot na mesma câmera (tools/capturar_parque3d.gd).
- ID: a mesma câmera com IDMAT=1 (cada material pintado com 64 + 2 x índice).
O fator novo é o fator atual (lido de SAIDA.gd, se existir) vezes a razão das médias em linear.
"""
import re, sys
import numpy as np
from PIL import Image
from scipy.ndimage import maximum_filter, minimum_filter

saida = sys.argv[1]
trios = [sys.argv[i:i + 3] for i in range(2, len(sys.argv), 3)]
atual = {}
try:
    for k, r, g, b in re.findall(r'"(m\d+)": \[([\d.]+), ([\d.]+), ([\d.]+)\]', open(saida).read()):
        atual[k] = np.array([float(r), float(g), float(b)])
except FileNotFoundError:
    pass

soma = {}
for rf, gf, idf in trios:
    ref = np.asarray(Image.open(rf).convert("RGB")).astype(float)
    god = np.asarray(Image.open(gf).convert("RGB")).astype(float)
    bruto = np.asarray(Image.open(idf).convert("RGB"))[..., 0].astype(int)
    ids = np.where((bruto >= 64) & (bruto < 250) & (bruto % 2 == 0), (bruto - 64) // 2, -1)
    firme = minimum_filter(ids, 5) == maximum_filter(ids, 5)  # longe das bordas
    for k in np.unique(ids[firme]):
        if k < 0:
            continue
        m = firme & (ids == k)
        s = soma.setdefault(int(k), [0, [], []])
        s[0] += m.sum(); s[1].append(ref[m]); s[2].append(god[m])

novo = dict(atual)
for k, (n, sr, sg) in soma.items():
    if n < 3000:
        continue
    # média dos pixels (é o que a diferença média mede) e cor limitada a ±15% em volta do brilho
    mr = np.concatenate(sr).mean(0); mg = np.concatenate(sg).mean(0)
    razao = ((mr + 1) / (mg + 1)) ** 2.2
    media = razao.mean()
    razao = media * np.clip(razao / media, 0.85, 1.15)
    nome = "m%d" % k
    novo[nome] = np.clip(atual.get(nome, np.ones(3)) * razao, 0.4, 2.5)

linhas = ['# Gerado por tools/calibrar_tons.py: multiplicador de cor por material do parque 3D (nome mN do glb),', '# medido contra a referência em JS. Não editar à mão.', 'const TONS := {']
for nome in sorted(novo, key=lambda x: int(x[1:])):
    r, g, b = novo[nome]
    linhas.append('\t"%s": [%.3f, %.3f, %.3f],' % (nome, r, g, b))
linhas.append('}')
open(saida, 'w').write('\n'.join(linhas) + '\n')
print('materiais calibrados:', len(novo))
