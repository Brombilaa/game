#!/usr/bin/env python3
"""Estende o fundo do parque além do mapa jogável (Léo, 30/10/2026).

O render 3D só cobre o losango do mapa, e a câmera aproximada mostrava o vazio em volta. Este script
espelha o desenho do chão (plan_D.png) para fora do plano, mistura com um borrão leve das próprias
cores e apaga em névoa curta (borda arredondada, sem quinas). Dentro do mapa o fundo original fica
intacto; o que passa do contorno (como a van) também.

Uso: estender_fundo.py FUNDO.png PLAN_D.png SAIDA.png   (imprime a posição da imagem em coordenadas do fundo)
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

ORIGEM = (760.0, 133.0)   # ponto (0, 0) da sala no fundo
ESCALA = (0.75, 0.2833)   # px por unidade do plano (x - y e x + y)
PLANO = (1280.0, 960.0)
FADE0, FADE1 = 1.22, 1.34  # névoa (norma 4 do plano normalizado)
CORTE0, CORTE1 = 1.30, 1.36  # a imagem some (alfa) aqui
BORRAO = 5
ESCURECE = 0.62
FORCA = 0.8


def dobra(t, n):
    t = np.mod(t, 2 * n)
    return np.where(t > n, 2 * n - t, t)


def main(fundo_png, plano_png, saida):
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
    main(*sys.argv[1:4])
