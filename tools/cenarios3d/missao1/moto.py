#!/usr/bin/env python3
"""Gera assets/3d/missao1/biblioteca_moto.glb: a moto da Júlia, estacionada na calçada da biblioteca (22/11/2026, provisório).

O cenário só tinha carros e a van; este glb é um estado do cenário da biblioteca (`estado "moto"`, ligado desde o início),
que a cena de saída da Júlia desliga quando ela vai embora. Peças simples (caixas e prismas) em metros, com a mesma
escala do protótipo three.js (1 unidade = 1 m, origem no piso). Rodar da raiz:  python3 tools/cenarios3d/missao1/moto.py
"""
import json
import math
import os
import struct

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "assets", "3d", "missao1", "biblioteca_moto.glb")
POS = (7.6, 12.95)   # x, z no cenário da biblioteca (calçada da frente, junto da sarjeta)
GIRO = math.radians(194)  # giro em torno de Y: a moto aponta para -x e um pouco para a rua (por onde vai embora)


def caixa(cx, cy, cz, sx, sy, sz, inclina=0.0):
    """Caixa centrada em (cx, cy, cz), inclinada `inclina` rad em torno de Z (garfo, para-lama)."""
    v = []
    for dx in (-1, 1):
        for dy in (-1, 1):
            for dz in (-1, 1):
                x, y, z = dx * sx / 2, dy * sy / 2, dz * sz / 2
                v.append((cx + x * math.cos(inclina) - y * math.sin(inclina), cy + x * math.sin(inclina) + y * math.cos(inclina), cz + z))
    idx = lambda dx, dy, dz: ((dx > 0) * 4 + (dy > 0) * 2 + (dz > 0))
    faces = [((-1, -1, -1), (-1, 1, -1), (-1, 1, 1), (-1, -1, 1)), ((1, -1, 1), (1, 1, 1), (1, 1, -1), (1, -1, -1)),
             ((-1, -1, -1), (-1, -1, 1), (1, -1, 1), (1, -1, -1)), ((-1, 1, 1), (-1, 1, -1), (1, 1, -1), (1, 1, 1)),
             ((-1, -1, 1), (-1, 1, 1), (1, 1, 1), (1, -1, 1)), ((1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, -1))]
    tris = []
    for f in faces:
        a, b, c, d = (v[idx(*k)] for k in f)
        tris += [(a, b, c), (a, c, d)]
    return tris


def roda(cx, cy, cz, raio, larg, lados=14):
    """Prisma com eixo em Z (a roda): lados + duas tampas."""
    tris = []
    for i in range(lados):
        a0, a1 = 2 * math.pi * i / lados, 2 * math.pi * (i + 1) / lados
        p = [(cx + raio * math.cos(a), cy + raio * math.sin(a)) for a in (a0, a1)]
        z0, z1 = cz - larg / 2, cz + larg / 2
        tris += [((p[0][0], p[0][1], z0), (p[1][0], p[1][1], z0), (p[1][0], p[1][1], z1)), ((p[0][0], p[0][1], z0), (p[1][0], p[1][1], z1), (p[0][0], p[0][1], z1))]
        tris += [((cx, cy, z1), (p[0][0], p[0][1], z1), (p[1][0], p[1][1], z1)), ((cx, cy, z0), (p[1][0], p[1][1], z0), (p[0][0], p[0][1], z0))]
    return tris


# (nome do material, cor sRGB, triângulos)
PECAS = [
    ("pneu", (0.13, 0.13, 0.15), roda(0.68, 0.33, 0, 0.33, 0.14) + roda(-0.68, 0.33, 0, 0.33, 0.16)),
    ("cubo", (0.55, 0.55, 0.58), roda(0.68, 0.33, 0, 0.14, 0.2) + roda(-0.68, 0.33, 0, 0.14, 0.22)),
    ("tanque", (0.78, 0.10, 0.10), caixa(0.22, 0.82, 0, 0.62, 0.26, 0.32) + caixa(-0.62, 0.74, 0, 0.5, 0.1, 0.26, -0.25)),
    ("banco", (0.20, 0.17, 0.16), caixa(-0.22, 0.82, 0, 0.62, 0.12, 0.3)),
    ("motor", (0.50, 0.51, 0.55), caixa(0.0, 0.46, 0, 0.5, 0.34, 0.28) + caixa(-0.1, 0.28, 0, 0.3, 0.1, 0.22)),
    ("garfo", (0.62, 0.62, 0.66), caixa(0.6, 0.7, 0.11, 0.05, 0.8, 0.05, 0.3) + caixa(0.6, 0.7, -0.11, 0.05, 0.8, 0.05, 0.3)
              + caixa(0.5, 1.1, 0, 0.06, 0.06, 0.62) + caixa(-0.34, 0.42, 0.13, 0.72, 0.06, 0.05, 0.17) + caixa(-0.34, 0.42, -0.13, 0.72, 0.06, 0.05, 0.17)),
    ("escape", (0.62, 0.62, 0.66), caixa(-0.5, 0.3, 0.2, 0.9, 0.11, 0.11, 0.06)),
    ("farol__unlit_semsombra", (1.0, 0.92, 0.6), caixa(0.78, 0.96, 0, 0.1, 0.16, 0.2)),
]


def girar(p):
    x, y, z = p
    c, s = math.cos(GIRO), math.sin(GIRO)
    return (POS[0] + x * c + z * s, y, POS[1] - x * s + z * c)


def normal(a, b, c):
    ux, uy, uz = (b[i] - a[i] for i in range(3))
    vx, vy, vz = (c[i] - a[i] for i in range(3))
    n = (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)
    m = math.sqrt(sum(k * k for k in n)) or 1.0
    return tuple(k / m for k in n)


def srgb_linear(c):
    return [((k + 0.055) / 1.055) ** 2.4 if k > 0.04045 else k / 12.92 for k in c]


def main():
    binario = bytearray()
    views, accs, prims, mats = [], [], [], []
    for i, (nome, cor, tris) in enumerate(PECAS):
        pos, nor = [], []
        for t in tris:
            t = [girar(p) for p in t]
            n = normal(*t)
            for p in t:
                pos.append(p)
                nor.append(n)
        for dados, tipo in ((pos, "p"), (nor, "n")):
            ini = len(binario)
            for v in dados:
                binario += struct.pack("<3f", *v)
            views.append({"buffer": 0, "byteOffset": ini, "byteLength": len(binario) - ini, "target": 34962})
            acc = {"bufferView": len(views) - 1, "componentType": 5126, "count": len(dados), "type": "VEC3"}
            if tipo == "p":
                acc["min"] = [min(p[k] for p in dados) for k in range(3)]
                acc["max"] = [max(p[k] for p in dados) for k in range(3)]
            accs.append(acc)
        prims.append({"attributes": {"POSITION": len(accs) - 2, "NORMAL": len(accs) - 1}, "material": i})
        mats.append({"name": nome, "pbrMetallicRoughness": {"baseColorFactor": srgb_linear(cor) + [1.0], "metallicFactor": 0.0, "roughnessFactor": 1.0}})
    gltf = {"asset": {"version": "2.0", "generator": "moto.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": [{"name": "moto_julia", "mesh": 0}], "meshes": [{"name": "moto_julia", "primitives": prims}],
            "materials": mats, "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(binario)}]}
    j = json.dumps(gltf, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    binario += b"\0" * (-len(binario) % 4)
    gltf_bytes = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(binario))
    gltf_bytes += struct.pack("<II", len(j), 0x4E4F534A) + j + struct.pack("<II", len(binario), 0x004E4942) + binario
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "wb") as f:
        f.write(gltf_bytes)
    print("moto:", len(gltf_bytes), "bytes em", SAIDA)


if __name__ == "__main__":
    main()
