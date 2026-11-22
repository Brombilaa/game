#!/usr/bin/env python3
"""Grava assets/3d/missao1/bar.json (luz, névoa, brilhos) do bar de Aurora. PROVISÓRIO do Claude (22/11/2026).
Roda depois de gerar_bar.gd (que grava o bar.glb): python3 tools/cenarios3d/missao1/gerar_bar_json.py"""
import json

info = {
    "hora": 15,
    "amb": {"h": 15, "noite": 0, "glow": 0.5, "pool": 0.5, "em": 0.8},
    "cfg": {"hemi": [0xe8d4b8, 0x6a5440, 1.35], "sol": [0xffb870, 1.8, [-4, 8, -3]], "nevoa": 0x6a5440, "fundo": 0x2a1d16,
            "noite": 0, "glow": 0.5, "pool": 0.5, "em": 0.8, "fk": 1},
    "vista": "bar",
    "luzes": [
        {"cor": "#ffd694", "i": 6, "d": 6.5, "q": 1.6, "pos": [5.2, 1.6, 4.5], "estado": ""},   # lâmpada do bilhar
        {"cor": "#ffc880", "i": 6, "d": 5.5, "q": 1.6, "pos": [8.0, 1.7, 1.55], "estado": ""},  # mesa do fundo
        {"cor": "#ffd9a0", "i": 4, "d": 6, "q": 1.6, "pos": [4.2, 1.9, 0.8], "estado": ""},     # janelas
        {"cor": "#ffb070", "i": 4, "d": 5, "q": 1.6, "pos": [1.0, 2.0, 3.5], "estado": ""},     # balcão
        {"cor": "#ff6a50", "i": 2, "d": 3, "q": 1.6, "pos": [0.5, 2.6, 3.5], "estado": ""},     # neon
        {"cor": "#ffd0a0", "i": 3, "d": 7, "q": 1.6, "pos": [8.0, 2.4, 5.5], "estado": ""},     # geral
    ],
    "brilhos": [
        {"pos": [5.2, 1.62, 4.5], "s": 2.0, "o": 0.45, "cor": "#ffe2a8", "estado": ""},
        {"pos": [8.0, 1.84, 1.55], "s": 1.4, "o": 0.45, "cor": "#ffe2a8", "estado": ""},
        {"pos": [0.12, 2.65, 3.5], "s": 1.6, "o": 0.4, "cor": "#ff6a50", "estado": ""},
        {"pos": [1.9, 1.2, 0.75], "s": 1.2, "o": 0.35, "cor": "#ffcf6a", "estado": ""},
    ],
    "sombras": [],
    "agentes": [],
    "hemi": {"ceu": "#e8d4b8", "chao": "#6a5440", "i": 1.35},
    "sol": {"cor": "#ffb870", "i": 0.9, "dir": [-4, 8, -3]},
    "nevoa": {"cor": "#6a5440"},
    "fundo": "#2a1d16",
    "colisao": {"area": [0, 0, 10, 7], "inicio": [9.0, 4.6], "gatilhos": []},
}
with open("assets/3d/missao1/bar.json", "w") as f:
    json.dump(info, f, indent=1)
print("ok bar.json")
