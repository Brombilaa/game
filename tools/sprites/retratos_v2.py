#!/usr/bin/env python3
"""Converte os retratos v2 (3D PC antigo, fundo cinza opaco) em retratos do jogo.

Uso: python3 tools/sprites/retratos_v2.py <pasta com retrato_<nome>[_ferido]_v2.(png|jpg)> [saida]
Gera <saida>/<nome>_128.png e _64.png (e <nome>_ferido_128/_64.png), opacos, com filtro suave.
"""
import sys
from pathlib import Path

from PIL import Image

NOMES = ["fernando", "miguel", "nikolai"]
TAMANHOS = [128, 64]


def abrir(origem: Path, nome: str) -> Image.Image | None:
    for ext in ("png", "jpg"):
        p = origem / f"retrato_{nome}_v2.{ext}"
        if p.exists():
            return Image.open(p).convert("RGB")
    return None


def main() -> None:
    origem = Path(sys.argv[1])
    saida = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("assets/sprites/retratos")
    saida.mkdir(parents=True, exist_ok=True)
    for nome in NOMES:
        for sufixo in ("", "_ferido"):
            img = abrir(origem, nome + sufixo)
            if img is None:
                print("falta", nome + sufixo)
                continue
            for t in TAMANHOS:
                img.resize((t, t), Image.LANCZOS).save(saida / f"{nome}{sufixo}_{t}.png", optimize=True)
                print(nome + sufixo, t)


if __name__ == "__main__":
    main()
