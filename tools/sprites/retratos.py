#!/usr/bin/env python3
"""Converte os retratos gerados no ChatGPT (fundo magenta) em retratos do jogo.

Uso: python3 tools/sprites/retratos.py <pasta com retrato_<nome>_raw.png> [saida]
Gera <saida>/<nome>_128.png (diálogos e fichas) e <saida>/<nome>_64.png (HUD), com fundo transparente.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

NOMES = ["fernando", "miguel", "nikolai"]
TAMANHOS = [128, 64]


def tirar_magenta(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # Quanto o pixel é magenta: vermelho e azul altos, verde baixo.
    magenta = np.clip(np.minimum(r, b) - g - 60, 0, 255) / 120.0
    alpha = (1.0 - np.clip(magenta, 0, 1)) * 255
    rgba = np.dstack([a, alpha]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def limpar_borda(img: Image.Image) -> Image.Image:
    """Alfa só 0 ou 255 (pixel art) e tira o resto de rosa dos pixels da borda."""
    a = np.asarray(img).astype(np.int16)
    solido = a[..., 3] >= 128
    # Pixels de borda ainda rosados: puxa o vermelho e o azul para perto do verde.
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    rosa = np.minimum(r, b) - g
    for c in (0, 2):
        a[..., c] = np.where(solido & (rosa > 20), np.minimum(a[..., c], g + 20), a[..., c])
    a[..., 3] = np.where(solido, 255, 0)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main() -> None:
    origem = Path(sys.argv[1])
    saida = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("assets/sprites/retratos")
    saida.mkdir(parents=True, exist_ok=True)
    for nome in NOMES:
        img = tirar_magenta(Image.open(origem / f"retrato_{nome}_raw.png"))
        for t in TAMANHOS:
            # BOX tira a média de cada bloco: as cores ficam fiéis; o alfa volta a 0/255 depois.
            pequeno = img.resize((t, t), Image.BOX)
            limpar_borda(pequeno).save(saida / f"{nome}_{t}.png", optimize=True)
            print(nome, t)


if __name__ == "__main__":
    main()
