"""Converte uma folha de sprites do ChatGPT (fundo magenta) em quadros do jogo.

Uso: python3 -I convert.py entrada.png saida_dir --altura 64 --cores 24
Passos: remove o magenta, separa as figuras, alinha os pés, reduz com média de área,
troca as cores por uma paleta única e grava os quadros e uma folha horizontal.
"""
import argparse, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("entrada"); ap.add_argument("saida")
ap.add_argument("--altura", type=int, default=64)
ap.add_argument("--cores", type=int, default=24)
ap.add_argument("--quadro", type=int, default=96)
ap.add_argument("--colunas", type=int, default=4)
ap.add_argument("--linhas", type=int, default=2)
a = ap.parse_args()
os.makedirs(a.saida, exist_ok=True)

img = Image.open(a.entrada).convert("RGB")
arr = np.array(img).astype(int)
r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
magenta = np.minimum(r, b) - g
fg = magenta < 40  # personagem nunca tem min(r,b) bem acima de g
fg = ndimage.binary_opening(fg, iterations=1)
lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=6))
H, W = fg.shape
cw, ch = W // a.colunas, H // a.linhas

# Uma figura por célula da grade: junta os pedaços da célula e ignora ruído pequeno.
figs = []
for row in range(a.linhas):
    for col in range(a.colunas):
        m = np.zeros_like(fg)
        m[row * ch:(row + 1) * ch, col * cw:(col + 1) * cw] = True
        cell = fg & m
        l2, k = ndimage.label(ndimage.binary_dilation(cell, iterations=6))
        if k == 0:
            sys.exit(f"célula {row},{col} vazia")
        sizes = ndimage.sum(cell, l2, range(1, k + 1))
        keep = np.isin(l2, [i + 1 for i, s in enumerate(sizes) if s > 400])
        mask = cell & keep
        ys, xs = np.where(mask)
        figs.append((mask, ys.min(), ys.max(), xs.min(), xs.max()))

heights = [f[2] - f[1] + 1 for f in figs]
ref_h = float(np.median(heights))
scale = a.altura / ref_h
print("alturas de origem:", [int(h) for h in heights], "-> escala", round(scale, 4))

frames = []
for mask, y0, y1, x0, x1 in figs:
    # Âncora horizontal: centro do tronco (metade de cima), estável mesmo com o casaco balançando.
    top = mask[y0:y0 + (y1 - y0) // 2, :]
    cx = np.where(top)[1].mean()
    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[..., :3] = arr.astype(np.uint8)
    rgba[..., 3] = (mask * 255).astype(np.uint8)
    # Cola numa tela do tamanho do quadro de origem, com pés e centro nos pontos fixos.
    S = a.quadro / scale
    src_w = int(round(S)); src_h = int(round(S))
    canvas = Image.new("RGBA", (src_w, src_h), (0, 0, 0, 0))
    full = Image.fromarray(rgba)
    ox = int(round(src_w / 2 - cx)); oy = int(round(src_h - 8 / scale - 1 - y1))
    canvas.paste(full, (ox, oy))
    # Redução por média de área; o alfa é cortado depois (borda dura, sem meio-transparente).
    small = canvas.resize((a.quadro, a.quadro), Image.BOX)
    frames.append(small)

# Paleta única para todos os quadros: só pixels opacos entram.
pix = np.concatenate([np.array(f)[np.array(f)[..., 3] > 127][:, :3] for f in frames])
pal_src = Image.fromarray(pix.reshape(-1, 1, 3).astype(np.uint8))
pal_img = pal_src.quantize(colors=a.cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
out = []
for i, f in enumerate(frames):
    fa = np.array(f)
    alpha = fa[..., 3] > 127
    q = Image.fromarray(fa[..., :3]).quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")
    qa = np.array(q)
    rgba = np.dstack([qa, (alpha * 255).astype(np.uint8)])
    rgba[~alpha] = 0
    im = Image.fromarray(rgba, "RGBA")
    im.save(os.path.join(a.saida, f"quadro_{i}.png"))
    out.append(im)

sheet = Image.new("RGBA", (a.quadro * len(out), a.quadro), (0, 0, 0, 0))
for i, im in enumerate(out):
    sheet.paste(im, (i * a.quadro, 0))
sheet.save(os.path.join(a.saida, "folha.png"))
print("cores na paleta:", len(set(map(tuple, np.array(sheet).reshape(-1, 4)[np.array(sheet)[..., 3].reshape(-1) > 0][:, :3]))))
