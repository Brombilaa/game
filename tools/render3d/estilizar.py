"""Alinha os personagens 3D ao cenário: pixel mais grosso, paleta menor e contorno na cor do tecido.

Uso: python3 -I tools/render3d/estilizar.py <pasta com folhas> <pasta de saída> <fator> <cores> [contorno 0|1]

Cada folha é reduzida por blocos de `fator` pixels (média com alfa), pintada com uma paleta única do
conjunto (`cores` cores) e reampliada com o vizinho mais próximo ao tamanho original. Assim as folhas
mantêm as mesmas dimensões e nenhum código do jogo muda: só o tamanho do "pixel" na tela.
Com SCALE 0,5 no jogo, fator 4 dá pixels de 2 px na tela.
"""
import sys, glob, os
import numpy as np
from PIL import Image
from scipy import ndimage

def blocks(a, f):
    h, w = a.shape[:2]
    return a.reshape(h // f, f, w // f, f, -1).mean((1, 3))

def reduce_sheet(path, f):
    im = np.array(Image.open(path).convert("RGBA")).astype(float)
    h, w = im.shape[:2]
    im = np.pad(im, ((0, -h % f), (0, -w % f), (0, 0)))  # quadros que não dividem pelo fator
    al = im[..., 3:] / 255
    A = blocks(al, f)
    C = blocks(im[..., :3] * al, f) / np.maximum(A, 1e-3)
    return C, A[..., 0]

def build_palette(paths, f, n):
    px = []
    for p in paths[::2]:
        C, A = reduce_sheet(p, f)
        px.append(C[A > 0.5][::3])
    px = np.concatenate(px).astype(np.uint8)
    q = Image.fromarray(px[None]).quantize(n, method=Image.MEDIANCUT, dither=Image.NONE)
    return np.array(q.getpalette()[: n * 3]).reshape(-1, 3)[:n]

def paint(path, f, pal, outline):
    C, A = reduce_sheet(path, f)
    m = A > 0.5
    d = ((C[:, :, None, :] - pal[None, None]) ** 2).sum(-1)
    out = pal[d.argmin(-1)].astype(np.uint8)
    out = np.where(m[..., None], out, 0).astype(np.uint8)
    rgba = np.dstack([out, (m * 255).astype(np.uint8)])
    if outline:
        ring = ndimage.binary_dilation(m, structure=np.ones((3, 3))) & ~m
        idx = ndimage.distance_transform_edt(~m, return_distances=False, return_indices=True)
        nb = out[idx[0], idx[1]]
        rgba[ring] = np.dstack([(nb * 0.45).astype(np.uint8), np.full(m.shape, 255, np.uint8)])[ring]
    big = np.repeat(np.repeat(rgba, f, 0), f, 1)
    h, w = Image.open(path).size[1], Image.open(path).size[0]
    big = big[:h, :w]
    return Image.fromarray(big)

if __name__ == "__main__":
    src, dst, f, n = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    outline = len(sys.argv) < 6 or sys.argv[5] == "1"
    os.makedirs(dst, exist_ok=True)
    paths = sorted(glob.glob(os.path.join(src, "*.png")))
    pal = build_palette(paths, f, n)
    for p in paths:
        paint(p, f, pal, outline).save(os.path.join(dst, os.path.basename(p)), optimize=True)
        print(os.path.basename(p))
