"""Corta folhas de ícones do Léo com fundo magenta (30/10/2026) em PNGs 64x64 transparentes.

Uso: python3 -I tools/sprites/icones_magenta.py acoes.png condicoes.png
 - acoes.png: fuzil e soco lado a lado -> assets/sprites/ui/acoes/{fuzil_precisao,soco}.png
 - condicoes.png: sangrando, atordoado (em cima), em_chamas, envenenado (embaixo) -> assets/sprites/ui/condicoes/
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def key(path):
    im = np.array(Image.open(path).convert("RGB")).astype(float)
    d = np.sqrt(((im - np.array([252, 3, 252])) ** 2).sum(2))
    a = np.clip((d - 110) / 90, 0, 1)
    mag = np.minimum(im[..., 0], im[..., 2]) - im[..., 1]
    a[mag > 60] = 0
    out = np.dstack([im, a * 255]).astype("uint8")
    m = (a > 0) & (a < 1)
    out[..., 0][m] = np.minimum(out[..., 0][m], out[..., 1][m] * 2 + 20)
    out[..., 2][m] = np.minimum(out[..., 2][m], out[..., 1][m] * 2 + 20)
    return Image.fromarray(out, "RGBA")


def pecas(img, n):
    """As n maiores peças (com os respingos próximos juntos), na ordem linha a linha."""
    a = np.array(img.getchannel("A")) > 40
    lab, k = ndimage.label(ndimage.binary_dilation(a, iterations=14))
    objs = ndimage.find_objects(lab)
    caixas = []
    for i, sl in enumerate(objs):
        sub = a[sl] & (lab[sl] == i + 1)
        if sub.sum() < 400:
            continue
        ys, xs = np.nonzero(sub)
        caixas.append((sl[1].start + xs.min(), sl[0].start + ys.min(), sl[1].start + xs.max() + 1, sl[0].start + ys.max() + 1))
    caixas.sort(key=lambda b: (b[1] // (img.height // 2) if n > 2 else 0, b[0]))
    return caixas[:n]


def salvar(img, caixa, destino):
    c = img.crop(caixa)
    s = 60 / max(c.size)
    c = c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS)
    cv = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    cv.paste(c, ((64 - c.width) // 2, (64 - c.height) // 2))
    cv.save(destino)


acoes = key(sys.argv[1])
for nome, cx in zip(["fuzil_precisao", "soco"], pecas(acoes, 2)):
    salvar(acoes, cx, f"assets/sprites/ui/acoes/{nome}.png")
cond = key(sys.argv[2])
for nome, cx in zip(["sangrando", "atordoado", "em_chamas", "envenenado"], pecas(cond, 4)):
    salvar(cond, cx, f"assets/sprites/ui/condicoes/{nome}.png")
