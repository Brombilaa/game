#!/usr/bin/env python3
"""Estende o fundo do parque além do mapa jogável (Léo, 30/10/2026).

O render 3D só cobre o losango do mapa, e a câmera aproximada mostrava o vazio em volta. Este script
espelha o desenho do chão (plan_D.png) para fora do plano, mistura com um borrão leve das próprias
cores e apaga em névoa curta (borda arredondada, sem quinas). Dentro do mapa o fundo original fica
intacto; o que passa do contorno (como a van) também.

Uso: estender_fundo.py FUNDO.png PLAN_D.png SAIDA.png [PASTA_DOS_ARBUSTOS]   (imprime a posição da imagem em coordenadas do fundo)
"""
import os
import random
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ORIGEM = (760.0, 133.0)   # ponto (0, 0) da sala no fundo
ESCALA = (0.75, 0.2833)   # px por unidade do plano (x - y e x + y)
PLANO = (1280.0, 960.0)
FADE0, FADE1 = 1.22, 1.34  # névoa (norma 4 do plano normalizado)
CORTE0, CORTE1 = 1.30, 1.36  # a imagem some (alfa) aqui
BORRAO = 5
ESCURECE = 0.62
FORCA = 0.8


# Mata extra (Léo, 30/10): tufos de vários tamanhos e folhagens no canto da direita, onde o chão
# estendido ficava vazio. Posições em unidades do plano (fora do mapa); a base do sprite fica nelas.
MATA_ZONAS = [  # (x0, x1, y0, y1, passo)
    (1295, 1500, -90, 560, 44),
    (1150, 1500, -230, -10, 44),
]
SEMENTE = 11
# O parquinho e os pneus ficam livres (Léo): nenhuma mata nasce perto deles. (x, y, largura, altura, folga)
LIVRES = [
    (1130, 670, 130, 60, 210),   # balanço
    (905, 775, 110, 110, 160),   # carrossel
    (1170, 335, 90, 80, 140),    # pneus da árvore
    (610, 680, 110, 280, 120),   # pneus do oeste
]


def folhagem(rng):
    """Folhas finas de pixel art, em tons de verde da paleta dos arbustos."""
    w, h = 26, 30
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    tons = [(52, 86, 44), (70, 108, 54), (92, 134, 62), (110, 150, 72)]
    for _ in range(rng.randint(5, 8)):
        bx = rng.randint(8, w - 8)
        topo = rng.randint(2, 12)
        largura = rng.randint(2, 4)
        c = rng.choice(tons) + (255,)
        d.polygon([(bx - largura, h - 1), (bx + largura, h - 1), (bx + rng.randint(-8, 8), topo)], fill=c)
    return im


def camada_mata(base, x0, y0, sprites_dir, dentro):
    """Cola tufos e folhagens sobre `base` (RGB) só fora do mapa; devolve a nova imagem RGB."""
    rng = random.Random(SEMENTE)
    nomes = ["arbusto_1", "arbusto_2", "arbusto_3", "arbusto_4"]
    tufos = [Image.open(os.path.join(sprites_dir, n + ".png")).convert("RGBA") for n in nomes]
    itens = []
    for zx0, zx1, zy0, zy1, passo in MATA_ZONAS:
        x = zx0
        while x <= zx1:
            y = zy0
            while y <= zy1:
                px = x + rng.randint(-passo // 2, passo // 2)
                py = y + rng.randint(-passo // 2, passo // 2)
                livre = any(lx - f < px < lx + lw + f and ly - f < py < ly + lh + f for lx, ly, lw, lh, f in LIVRES)
                r = rng.random()
                if not livre:
                    itens.append((px, py, r))
                y += passo
            x += passo
    itens.sort(key=lambda t: t[0] + t[1])  # mais longe primeiro
    camada = Image.new("RGBA", base.size, (0, 0, 0, 0))
    for px, py, r in itens:
        bx = ORIGEM[0] + (px - py) * ESCALA[0] - x0
        by = ORIGEM[1] + (px + py) * ESCALA[1] - y0
        if r < 0.3:
            spr = folhagem(rng)
            esc = rng.choice([1, 1, 2])
        else:
            spr = rng.choice(tufos)
            esc = rng.choice([0.45, 0.6, 0.8, 1.0, 1.0, 1.25, 1.5])
        if esc != 1:
            spr = spr.resize((max(1, int(spr.width * esc)), max(1, int(spr.height * esc))), Image.NEAREST)
        if rng.random() < 0.5:
            spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
        longe = min(1.0, max(0.0, (px - 1280) / 260.0))
        rgb = ImageEnhance.Brightness(spr.convert("RGB")).enhance(1.0 - 0.3 * longe)
        spr = Image.merge("RGBA", (*rgb.split(), spr.split()[3]))
        camada.alpha_composite(spr, (int(bx - spr.width / 2), int(by - spr.height + 6)))
    arr = np.array(camada).astype(float)
    a = (arr[..., 3:4] / 255.0) * (~dentro)[..., None]  # nada por cima do que já é do render
    out = np.array(base).astype(float) * (1 - a) + arr[..., :3] * a
    return Image.fromarray(out.clip(0, 255).astype("uint8"))


def dobra(t, n):
    t = np.mod(t, 2 * n)
    return np.where(t > n, 2 * n - t, t)


def main(fundo_png, plano_png, saida, sprites_dir=""):
    fundo = np.array(Image.open(fundo_png).convert("RGBA")).astype(float)
    plano = np.array(Image.open(plano_png).convert("RGB")).astype(float)
    ih, iw = fundo.shape[:2]
    ph, pw = plano.shape[:2]
    # caixa da região até CORTE1, no espaço do fundo
    a = np.linspace(0, 2 * np.pi, 720)
    r = CORTE1
    u = np.sign(np.cos(a)) * np.abs(np.cos(a)) ** 0.5 * r
    v = np.sign(np.sin(a)) * np.abs(np.sin(a)) ** 0.5 * r
    x = PLANO[0] / 2 + u * PLANO[0] / 2
    y = PLANO[1] / 2 + v * PLANO[1] / 2
    bx_ = ORIGEM[0] + (x - y) * ESCALA[0]
    by_ = ORIGEM[1] + (x + y) * ESCALA[1]
    x0, x1 = int(np.floor(bx_.min())), int(np.ceil(bx_.max()))
    y0, y1 = int(np.floor(by_.min())), int(np.ceil(by_.max()))
    w, h = x1 - x0, y1 - y0
    bx, by = np.meshgrid(x0 + np.arange(w) + 0.5, y0 + np.arange(h) + 0.5)
    pa = (bx - ORIGEM[0]) / ESCALA[0]
    pb = (by - ORIGEM[1]) / ESCALA[1]
    px = (pa + pb) / 2
    py = (pb - pa) / 2
    gx = np.clip(dobra(px, PLANO[0]) * pw / PLANO[0], 0, pw - 1).astype(int)
    gy = np.clip(dobra(py, PLANO[1]) * ph / PLANO[1], 0, ph - 1).astype(int)
    chao = plano[gy, gx]
    ix = np.clip(bx.astype(int), 0, iw - 1)
    iy = np.clip(by.astype(int), 0, ih - 1)
    col = fundo[iy, ix]
    dentro = (col[..., 3] > 0) & (bx < iw) & (by < ih) & (bx >= 0) & (by >= 0)
    rgb = np.where(dentro[..., None], col[..., :3], chao)
    base = Image.fromarray(rgb.clip(0, 255).astype("uint8"))
    if sprites_dir:
        base = camada_mata(base, x0, y0, sprites_dir, dentro)
        rgb = np.array(base).astype(float)
    borrao = np.array(base.filter(ImageFilter.GaussianBlur(BORRAO))).astype(float) * ESCURECE
    nu = np.abs((px - PLANO[0] / 2) / (PLANO[0] / 2))
    nv = np.abs((py - PLANO[1] / 2) / (PLANO[1] / 2))
    e = (nu ** 4 + nv ** 4) ** 0.25
    t = np.clip((e - FADE0) / (FADE1 - FADE0), 0, 1)
    m = t * t * (3 - 2 * t) * FORCA
    m = np.where(dentro, 0.0, m)  # o que é do render original fica como está
    out = rgb * (1 - m[..., None]) + borrao * m[..., None]
    k = np.clip((e - CORTE0) / (CORTE1 - CORTE0), 0, 1)
    alfa = np.where(dentro, 255.0, 255.0 * (1 - k * k * (3 - 2 * k)))
    img = np.dstack([out.clip(0, 255), alfa]).astype("uint8")
    Image.fromarray(img, "RGBA").save(saida)
    print(x0, y0, w, h)


if __name__ == "__main__":
    main(*sys.argv[1:5])
