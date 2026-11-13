#!/usr/bin/env python3
"""Gera assets/3d/parque/marcas_pneu_contorno.png: um contorno branco suave em volta das marcas de pneu pintadas no chão
do parque (a textura do chão é parque_cenario_1.jpg, 64 px por metro). O recorte cobre x -3..9 m, z 3..12 m do mundo 3D (a imagem gravada começa em z = 3)
(ver "decalque" da pista marcas_pneu em data/cenarios/parque.json). Uso: python3 contorno_marcas_pneu.py"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CHAO = "assets/3d/parque/parque_cenario_1.jpg"
SAIDA = "assets/3d/parque/marcas_pneu_contorno.png"
CAIXA = (256, 640, 1024, 1216)  # recorte da textura (px): x -3..9 m, z 3..12 m
# Eixo de cada marca no recorte (px) e meia largura. As duas de cima são achadas pela cor; as de baixo, na terra, são
# claras demais para a cor e vão só pelo traço.
CIMA = [([(185, 0), (250, 110), (310, 205), (385, 315)], 26), ([(310, 70), (380, 140), (430, 215), (482, 288)], 24)]
BAIXO = [([(402, 338), (440, 400), (470, 450), (478, 475)], 15), ([(490, 305), (528, 375), (555, 445), (565, 478)], 15)]


def main() -> None:
    c = Image.open(CHAO).convert("RGB").crop(CAIXA)
    a = np.asarray(c).astype(int)
    r, g = a[..., 0], a[..., 1]
    br = a.mean(axis=2)
    cor = (r >= g - 2) & (br < 80) & (br > 20)
    corredor = Image.new("L", c.size, 0)
    d = ImageDraw.Draw(corredor)
    for pts, w in CIMA:
        d.line(pts, fill=255, width=2 * w)
    marca = Image.fromarray((cor & (np.asarray(corredor) > 0)).astype("uint8") * 255)
    d2 = ImageDraw.Draw(marca)
    for pts, w in BAIXO:
        d2.line(pts, fill=255, width=2 * w)
    marca = marca.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))  # fecha os furos da cor
    marca = marca.filter(ImageFilter.GaussianBlur(4)).point(lambda v: 255 if v > 110 else 0)
    fora = marca.filter(ImageFilter.MaxFilter(15))  # +7 px
    anel = np.clip(np.asarray(fora).astype(int) - np.asarray(marca.filter(ImageFilter.MaxFilter(5))).astype(int), 0, 255)
    anel_img = Image.fromarray(anel.astype("uint8")).filter(ImageFilter.GaussianBlur(2.2))
    alfa = np.asarray(anel_img).astype(float) / 255.0
    out = np.zeros((c.size[1], c.size[0], 4), dtype="uint8")
    out[..., :3] = 255
    out[..., 3] = np.clip(alfa * 1.6, 0, 1) * 255
    anel_rgba = Image.fromarray(out, "RGBA")
    # A textura do chão tem o topo em z = 12 m; o plano do contorno começa em z = 3 m: vira de cabeça para baixo.
    anel_rgba.transpose(Image.FLIP_TOP_BOTTOM).save(SAIDA)


if __name__ == "__main__":
    main()
