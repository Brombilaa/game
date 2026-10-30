"""Corta as molduras pintadas pelo Léo (fundo magenta) e gera as peças do inventário em tamanho nativo (1920x1080).

Uso: python3 -I tools/sprites/molduras_inventario.py aba quadro_equip moldura casa_equip casa_lisa detalhe
Cada argumento é um PNG. Saída em assets/sprites/ui/inv/.
"""
import sys
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

OUT = "assets/sprites/ui/inv/"


def key(path, terco=False):
    src = Image.open(path).convert("RGB")
    if terco:  # a casa de equipamento veio em três variantes lado a lado: usa a primeira
        src = src.crop((0, 0, src.width // 3, src.height))
    im = np.array(src).astype(float)
    d = np.sqrt(((im - np.array([252, 3, 252])) ** 2).sum(2))
    a = np.clip((d - 110) / 90, 0, 1)
    mag = np.minimum(im[..., 0], im[..., 2]) - im[..., 1]
    a[mag > 35] = 0
    out = np.dstack([im, a * 255]).astype("uint8")
    m = (a > 0) & (a < 1)
    out[..., 0][m] = np.minimum(out[..., 0][m], out[..., 1][m] * 2 + 20)
    out[..., 2][m] = np.minimum(out[..., 2][m], out[..., 1][m] * 2 + 20)
    img = Image.fromarray(out, "RGBA")
    return img.crop(img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox())


def glow(img, pad):
    """Versão brilhando: ouro mais vivo e halo dourado ao redor."""
    w, h = img.size
    base = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    bright = ImageEnhance.Brightness(img).enhance(1.3)
    bright = ImageEnhance.Color(bright).enhance(1.15)
    halo = Image.new("RGBA", base.size, (255, 200, 90, 0))
    alpha = Image.new("L", base.size, 0)
    alpha.paste(img.getchannel("A"), (pad, pad))
    blur = alpha.filter(ImageFilter.GaussianBlur(pad / 2.2)).point(lambda v: min(255, int(v * 1.6)))
    halo.putalpha(blur)
    base.alpha_composite(halo)
    base.alpha_composite(bright, (pad, pad))
    return base


def fit(img, size):
    return img.resize(size, Image.LANCZOS)


aba, quadro, mold = [key(p) for p in sys.argv[1:4]]
casa = key(sys.argv[4], terco=True)  # moldura ornamentada (já não usada nas casas)
simples = key(sys.argv[5], terco=True)  # moldura lisa das casas da mochila e do equipamento

# aba: tampas esquerda e direita mais um miolo com o losango central, na altura de 48 px
s = 48 / aba.height
t = fit(aba, (round(aba.width * s), 48))
cap, mid = 30, 32
tab = Image.new("RGBA", (92, 48))
tab.paste(t.crop((0, 0, cap, 48)), (0, 0))
tab.paste(t.crop((t.width // 2 - mid // 2, 0, t.width // 2 + mid // 2, 48)), (cap, 0))
tab.paste(t.crop((t.width - cap, 0, t.width, 48)), (cap + mid, 0))
tab.save(OUT + "aba.png")
glow(tab, 8).save(OUT + "aba_brilho.png")

fit(quadro, (784, 248)).save(OUT + "quadro_equipamento.png")

for nome, src, lado in (("casa", simples, 80), ("retrato", mold, 110), ("equip", simples, 112)):
    a = fit(src, (lado, lado))
    a.save(OUT + nome + ".png")
    glow(a, 8).save(OUT + nome + "_brilho.png")

# quadro de detalhe do item (ícone, nome, descrição e três linhas de dados), 328x408
if len(sys.argv) > 6:
    det = key(sys.argv[6])
    print("detalhe", det.size)
    fit(det, (328, 408)).save(OUT + "detalhe.png")
