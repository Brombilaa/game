#!/usr/bin/env python3
"""Gera assets/3d/missao1/biblioteca_moto.glb: a moto da Júlia, estacionada na calçada da biblioteca.

Refeita em 26/11/2026 pela referência que o Léo mandou (moto clássica: tanque vermelho, banco preto canelado, rodas
raiadas com disco, motor aletado com tampas cromadas, farol redondo, escapamento cromado, amortecedores com mola,
lanterna vermelha e descanso lateral). Baixa/média poligonal, sem textura, no acabamento "PC antigo" dos cenários.
É um estado do cenário da biblioteca (`estado "moto"`, ligado desde o início), que a cena de saída da Júlia desliza
para a rua e desliga. Em metros, 1 unidade = 1 m, origem no piso. Rodar da raiz:  python3 tools/cenarios3d/missao1/moto.py
"""
import json
import math
import os
import struct

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SAIDA = os.path.join(RAIZ, "assets", "3d", "missao1", "biblioteca_moto.glb")
POS = (7.6, 12.95)   # x, z no cenário da biblioteca (calçada da frente, junto da sarjeta)
GIRO = math.radians(194)  # giro em torno de Y: a moto aponta para -x e um pouco para a rua (por onde vai embora)
INCLINA = math.radians(5)  # apoiada no descanso lateral (lado -z)

# Cores sRGB (o importador espera linear; srgb_linear converte). Paleta da referência: vermelho, preto, cinza, cromo, couro.
CORES = {
    "pintura": (0.56, 0.07, 0.07), "preto": (0.07, 0.07, 0.08), "borracha": (0.11, 0.11, 0.12),
    "banco": (0.13, 0.11, 0.10), "cromo": (0.78, 0.78, 0.80), "aluminio": (0.55, 0.56, 0.58),
    "motor": (0.36, 0.37, 0.39), "couro": (0.30, 0.19, 0.11),
    "farol__unlit_semsombra": (1.0, 0.93, 0.70), "lanterna__unlit_semsombra": (0.95, 0.12, 0.08),
}
MALHAS = {k: [] for k in CORES}  # material -> [(p, n), ...] em trios (triângulos)


# ---------------------------------------------------------------- álgebra mínima
def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def norm(a):
    m = math.sqrt(dot(a, a)) or 1.0
    return (a[0] / m, a[1] / m, a[2] / m)


def base_ortogonal(eixo):
    e = norm(eixo)
    ref = (0, 1, 0) if abs(e[1]) < 0.9 else (1, 0, 0)
    u = norm(cross(e, ref))
    return e, u, cross(e, u)


def tri(mat, a, b, c, na=None, nb=None, nc=None):
    if na is None:
        n = norm(cross(sub(b, a), sub(c, a)))
        na = nb = nc = n
    MALHAS[mat] += [(a, na), (b, nb), (c, nc)]


def quad(mat, a, b, c, d, na=None, nb=None, nc=None, nd=None):
    tri(mat, a, b, c, na, nb, nc)
    tri(mat, a, c, d, na, nc, nd)


# ---------------------------------------------------------------- primitivas
def caixa(mat, centro, tam, giro_z=0.0):
    """Caixa centrada em `centro`, tamanho (x, y, z), inclinada `giro_z` rad em torno de Z."""
    cx, cy, cz = centro
    c, s = math.cos(giro_z), math.sin(giro_z)
    def v(dx, dy, dz):
        x, y, z = dx * tam[0] / 2, dy * tam[1] / 2, dz * tam[2] / 2
        return (cx + x * c - y * s, cy + x * s + y * c, cz + z)
    for f in (((-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)), ((1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)),
              ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)), ((-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)),
              ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)), ((1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1))):
        quad(mat, *(v(*k) for k in f))


def tubo(mat, a, b, raio, lados=8, tampas=True, raio_b=None):
    """Cilindro (ou tronco de cone, com `raio_b`) de `a` até `b`, normais suaves no corpo."""
    e, u, w = base_ortogonal(sub(b, a))
    rb = raio if raio_b is None else raio_b
    for i in range(lados):
        a0, a1 = 2 * math.pi * i / lados, 2 * math.pi * (i + 1) / lados
        d0 = add(mul(u, math.cos(a0)), mul(w, math.sin(a0)))
        d1 = add(mul(u, math.cos(a1)), mul(w, math.sin(a1)))
        p00, p01 = add(a, mul(d0, raio)), add(a, mul(d1, raio))
        p10, p11 = add(b, mul(d0, rb)), add(b, mul(d1, rb))
        quad(mat, p00, p10, p11, p01, d0, d0, d1, d1)
        if tampas:
            tri(mat, a, p01, p00, mul(e, -1), mul(e, -1), mul(e, -1))
            tri(mat, b, p10, p11, e, e, e)


def caminho(mat, pontos, raio, lados=8):
    """Tubo dobrado (quadro, escapamento) por uma lista de pontos; esferas pequenas fecham as dobras."""
    for a, b in zip(pontos, pontos[1:]):
        tubo(mat, a, b, raio, lados, tampas=False)
    for p in pontos:
        esfera(mat, p, (raio, raio, raio), 6, 4)


def esfera(mat, c, r, lon=14, lat=8, corte_y=-1.0):
    """Elipsoide de raios r = (rx, ry, rz); `corte_y` (-1..1) achata a parte de baixo (tanque)."""
    def ponto(i, j):
        th = 2 * math.pi * i / lon
        ph = math.pi * j / lat - math.pi / 2
        y = max(math.sin(ph), corte_y)
        k = math.cos(ph)
        p = (c[0] + r[0] * k * math.cos(th), c[1] + r[1] * y, c[2] + r[2] * k * math.sin(th))
        n = norm((k * math.cos(th) / r[0], y / r[1], k * math.sin(th) / r[2]))
        return p, n
    for i in range(lon):
        for j in range(lat):
            (a, na), (b, nb), (cc, nc), (d, nd) = ponto(i, j), ponto(i + 1, j), ponto(i + 1, j + 1), ponto(i, j + 1)
            quad(mat, a, d, cc, b, na, nd, nc, nb)


def toro(mat, c, raio, grossura, eixo=(0, 0, 1), lados=20, secao=8, de=0.0, ate=2 * math.pi):
    """Toro (pneu, aro, mola) em volta de `eixo`; `de`/`ate` fazem um arco."""
    e, u, w = base_ortogonal(eixo)
    def ponto(i, j):
        th = de + (ate - de) * i / lados
        ph = 2 * math.pi * j / secao
        radial = add(mul(u, math.cos(th)), mul(w, math.sin(th)))
        n = add(mul(radial, math.cos(ph)), mul(e, math.sin(ph)))
        return add(c, add(mul(radial, raio), mul(n, grossura))), n
    for i in range(lados):
        for j in range(secao):
            (a, na), (b, nb), (cc, nc), (d, nd) = ponto(i, j), ponto(i + 1, j), ponto(i + 1, j + 1), ponto(i, j + 1)
            quad(mat, a, b, cc, d, na, nb, nc, nd)


def faixa_arco(mat, c, raio, largura, grossura, de, ate, passos=10):
    """Para-lama: faixa curva em volta do eixo Z, de `de` a `ate` rad (0 = frente, +y = cima)."""
    for i in range(passos):
        a0, a1 = de + (ate - de) * i / passos, de + (ate - de) * (i + 1) / passos
        for r0, r1, z0, z1 in ((raio, raio, -largura / 2, largura / 2), (raio + grossura, raio + grossura, largura / 2, -largura / 2)):
            p = [(c[0] + r0 * math.cos(a0), c[1] + r0 * math.sin(a0), z0), (c[0] + r1 * math.cos(a1), c[1] + r1 * math.sin(a1), z0),
                 (c[0] + r1 * math.cos(a1), c[1] + r1 * math.sin(a1), z1), (c[0] + r0 * math.cos(a0), c[1] + r0 * math.sin(a0), z1)]
            quad(mat, *p)
        for z in (-largura / 2, largura / 2):
            s = 1 if z > 0 else -1
            p = [(c[0] + raio * math.cos(a0), c[1] + raio * math.sin(a0), z), (c[0] + raio * math.cos(a1), c[1] + raio * math.sin(a1), z),
                 (c[0] + (raio + grossura) * math.cos(a1), c[1] + (raio + grossura) * math.sin(a1), z), (c[0] + (raio + grossura) * math.cos(a0), c[1] + (raio + grossura) * math.sin(a0), z)]
            if s < 0:
                p.reverse()
            quad(mat, *p)


# ---------------------------------------------------------------- a moto (x = frente, y = cima, z = direita)
R_RODA = 0.33
FRENTE, TRAS = (0.70, R_RODA, 0.0), (-0.70, R_RODA, 0.0)


def roda(c, disco):
    toro("borracha", c, 0.268, 0.064, lados=28, secao=10)              # pneu (balão, 0,33 m de raio)
    for k in range(28):                                                    # sulcos rasos da banda de rodagem
        a = 2 * math.pi * (k + 0.5) / 28
        caixa("preto", (c[0] + 0.331 * math.cos(a), c[1] + 0.331 * math.sin(a), 0.02 if k % 2 else -0.02), (0.012, 0.006, 0.05), a)
    toro("cromo", c, 0.222, 0.014, lados=24, secao=5)                    # aro
    tubo("aluminio", add(c, (0, 0, -0.07)), add(c, (0, 0, 0.07)), 0.045, 10)  # cubo
    for k in range(18):                                                    # raios, cruzando dos dois lados do cubo
        a = 2 * math.pi * k / 18
        lado = 0.045 if k % 2 else -0.045
        tubo("cromo", add(c, (0.04 * math.cos(a + 0.6), 0.04 * math.sin(a + 0.6), lado)),
             add(c, (0.215 * math.cos(a), 0.215 * math.sin(a), 0)), 0.0045, 4, tampas=False)
    if disco:                                                              # disco de freio e pinça
        tubo("motor", add(c, (0, 0, -0.085)), add(c, (0, 0, -0.075)), 0.13, 16)
        caixa("preto", (c[0] - 0.08, c[1] + 0.10, -0.09), (0.07, 0.05, 0.04), 0.9)


def moto():
    roda(FRENTE, True)
    roda(TRAS, False)
    # Garfo dianteiro com caimento: bainhas cromadas por cima, tubos mais grossos embaixo.
    topo = (0.50, 0.97, 0.0)
    for z in (-0.095, 0.095):
        baixo, meio, cima = (FRENTE[0], FRENTE[1], z), (0.61, 0.66, z), (topo[0], topo[1], z)
        tubo("aluminio", baixo, meio, 0.026, 8)
        tubo("cromo", meio, cima, 0.019, 8)
    caixa("preto", (0.505, 0.93, 0), (0.07, 0.035, 0.25), -0.35)          # mesa inferior
    caixa("aluminio", (0.49, 0.985, 0), (0.07, 0.03, 0.25), -0.35)        # mesa superior
    tubo("preto", (FRENTE[0], FRENTE[1], -0.11), (FRENTE[0], FRENTE[1], 0.11), 0.012, 6)  # eixo
    faixa_arco("aluminio", FRENTE, 0.365, 0.07, 0.006, math.radians(45), math.radians(135))   # para-lama curto
    # Guidão, manoplas, manetes e retrovisores.
    caminho("cromo", [(0.43, 1.10, -0.36), (0.47, 1.04, -0.22), (0.49, 1.00, -0.06), (0.49, 1.00, 0.06), (0.47, 1.04, 0.22), (0.43, 1.10, 0.36)], 0.011)
    for z in (-1, 1):
        tubo("borracha", (0.43, 1.10, 0.33 * z), (0.415, 1.12, 0.44 * z), 0.017, 8)
        tubo("aluminio", (0.45, 1.09, 0.30 * z), (0.52, 1.07, 0.40 * z), 0.005, 4)
        tubo("cromo", (0.46, 1.06, 0.24 * z), (0.45, 1.19, 0.28 * z), 0.005, 4)
        tubo("preto", (0.455, 1.20, 0.285 * z), (0.435, 1.205, 0.285 * z), 0.038, 12)
    # Farol redondo cromado com vidro aceso, e os dois relógios.
    tubo("cromo", (0.565, 0.89, 0), (0.655, 0.89, 0), 0.088, 16, raio_b=0.095)
    tubo("farol__unlit_semsombra", (0.655, 0.89, 0), (0.664, 0.89, 0), 0.08, 16)
    tubo("preto", (0.54, 0.86, -0.06), (0.58, 0.88, -0.06), 0.012, 6)
    tubo("preto", (0.54, 0.86, 0.06), (0.58, 0.88, 0.06), 0.012, 6)
    for z in (-0.055, 0.055):
        tubo("preto", (0.47, 1.02, z), (0.455, 1.07, z), 0.038, 12)
        tubo("aluminio", (0.455, 1.07, z), (0.452, 1.078, z), 0.032, 12)
    # Quadro berço (preto): espinha, berço duplo por baixo do motor, trilhos do banco e traseira.
    cabeca = (0.47, 0.90, 0.0)
    tubo("preto", (0.45, 0.83, 0), (0.50, 0.98, 0), 0.032, 10)           # caixa de direção
    caminho("preto", [cabeca, (0.10, 0.84, 0), (-0.18, 0.79, 0)], 0.022)
    for z in (-0.085, 0.085):
        caminho("preto", [(0.46, 0.84, 0), (0.34, 0.50, z), (0.28, 0.22, z), (-0.20, 0.22, z), (-0.24, 0.40, z),
                          (-0.18, 0.76, z), (-0.80, 0.80, z)], 0.017)
        caminho("preto", [(-0.24, 0.40, z), (-0.60, 0.78, z)], 0.015)
    # Tanque em gota, vermelho, com joelheiras e tampa cromada.
    esfera("pintura", (0.17, 0.865, 0), (0.30, 0.115, 0.145), 18, 10, corte_y=-0.35)
    tubo("cromo", (0.25, 0.975, 0), (0.25, 0.99, 0), 0.035, 12)
    caixa("cromo", (0.19, 0.89, 0.143), (0.14, 0.01, 0.006))            # friso do tanque (como na referência)
    caixa("cromo", (0.19, 0.89, -0.143), (0.14, 0.01, 0.006))
    # Banco preto canelado em cima da base, com a costura marrom na borda.
    caixa("banco", (-0.44, 0.845, 0), (0.62, 0.07, 0.26))
    for i in range(10):                                                    # gomos do banco, encostados
        x = -0.165 - i * 0.061
        tubo("banco", (x, 0.88, -0.118), (x, 0.88, 0.118), 0.031, 10)
    caixa("couro", (-0.44, 0.812, 0), (0.625, 0.006, 0.262))
    # Tampas laterais vermelhas.
    for z in (-0.105, 0.105):
        caixa("pintura", (-0.10, 0.60, z), (0.24, 0.15, 0.02))
        caixa("cromo", (-0.10, 0.60, z * 1.12), (0.08, 0.02, 0.004))
    # Motor: cárter e caixa, cilindros inclinados com aletas, tampas cromadas dos dois lados, carburador e filtro.
    caixa("motor", (0.03, 0.36, 0), (0.42, 0.20, 0.24))
    tubo("aluminio", (0.12, 0.35, 0.12), (0.12, 0.35, 0.155), 0.10, 18)
    tubo("aluminio", (-0.08, 0.36, -0.12), (-0.08, 0.36, -0.155), 0.085, 18)
    tubo("cromo", (-0.08, 0.36, 0.12), (-0.08, 0.36, 0.145), 0.06, 14)
    inc = math.radians(-14)
    for i in range(9):                                                     # aletas de arrefecimento
        h = 0.48 + i * 0.026
        largura = 0.22 if i < 7 else 0.18
        caixa("aluminio", (0.12 + (h - 0.48) * math.tan(-inc), h, 0), (largura, 0.012, 0.25), inc)
    caixa("motor", (0.13, 0.58, 0), (0.15, 0.21, 0.19), inc)              # bloco dos cilindros por dentro das aletas
    caixa("aluminio", (0.18, 0.73, 0), (0.20, 0.05, 0.22), inc)           # cabeçote
    tubo("motor", (-0.04, 0.58, -0.06), (-0.13, 0.60, -0.06), 0.03, 8)  # carburadores
    tubo("motor", (-0.04, 0.58, 0.06), (-0.13, 0.60, 0.06), 0.03, 8)
    caixa("preto", (-0.18, 0.55, 0), (0.08, 0.14, 0.20))                  # filtro de ar
    # Escapamento cromado do lado direito: coletor descendo na frente do motor e ponteira longa até a traseira.
    for z in (0.05, 0.11):
        caminho("cromo", [(0.24, 0.62, z), (0.33, 0.45, z + 0.04), (0.34, 0.26, 0.17), (0.10, 0.20, 0.19)], 0.019)
    tubo("cromo", (0.10, 0.20, 0.19), (-0.30, 0.24, 0.20), 0.022, 10, tampas=False)
    tubo("cromo", (-0.30, 0.24, 0.20), (-0.86, 0.34, 0.20), 0.045, 14, raio_b=0.042)
    tubo("preto", (-0.86, 0.34, 0.20), (-0.875, 0.342, 0.20), 0.028, 10)
    # Balança traseira, eixo, corrente (faixa) e amortecedores com mola.
    for z in (-0.10, 0.10):
        tubo("preto", (-0.22, 0.33, z), (TRAS[0], TRAS[1], z), 0.022, 8)
        a, b = (-0.62, 0.38, z * 1.25), (-0.47, 0.76, z * 1.25)
        tubo("cromo", a, b, 0.015, 8)
        tubo("preto", a, add(a, mul(sub(b, a), 0.22)), 0.027, 8)
        for k in range(7):
            p = add(a, mul(sub(b, a), 0.28 + 0.09 * k))
            toro("cromo", p, 0.028, 0.006, eixo=sub(b, a), lados=10, secao=4)
    tubo("preto", (TRAS[0], TRAS[1], -0.12), (TRAS[0], TRAS[1], 0.12), 0.012, 6)
    caixa("preto", (-0.43, 0.34, -0.10), (0.52, 0.025, 0.012))
    # Para-lama traseiro, lanterna, placa e piscas.
    faixa_arco("preto", TRAS, 0.36, 0.14, 0.008, math.radians(55), math.radians(160))
    caixa("preto", (-0.86, 0.66, 0), (0.08, 0.06, 0.09), -0.5)
    caixa("lanterna__unlit_semsombra", (-0.89, 0.665, 0), (0.02, 0.045, 0.09), -0.5)
    caixa("aluminio", (-0.90, 0.58, 0), (0.008, 0.10, 0.17), -0.4)
    for z in (-0.11, 0.11):
        tubo("preto", (-0.82, 0.68, z * 0.6), (-0.84, 0.68, z * 1.6), 0.008, 4)
        esfera("lanterna__unlit_semsombra", (-0.84, 0.68, z * 1.7), (0.02, 0.016, 0.016), 8, 4)
        tubo("preto", (0.56, 0.84, z * 0.6), (0.56, 0.84, z * 1.6), 0.008, 4)  # piscas da frente
        esfera("couro", (0.56, 0.84, z * 1.7), (0.02, 0.016, 0.016), 8, 4)
    # Pedaleiras e descanso lateral (lado -z, onde a moto se apoia).
    for z in (-1, 1):
        tubo("borracha", (-0.06, 0.30, 0.10 * z), (-0.06, 0.30, 0.20 * z), 0.013, 6)
    tubo("preto", (-0.12, 0.24, -0.10), (-0.05, 0.0, -0.29), 0.012, 6)
    caixa("preto", (-0.05, 0.006, -0.29), (0.05, 0.012, 0.04))


# ---------------------------------------------------------------- posição no cenário e glb
def colocar(p, normal=False):
    x, y, z = p
    c, s = math.cos(INCLINA), math.sin(INCLINA)
    y, z = y * c + z * s, -y * s + z * c                   # rola em torno de X: o topo vai para -z (descanso)
    c, s = math.cos(GIRO), math.sin(GIRO)
    x, z = x * c + z * s, -x * s + z * c
    return (x, y, z) if normal else (POS[0] + x, y, POS[1] + z)


def srgb_linear(c):
    return [((k + 0.055) / 1.055) ** 2.4 if k > 0.04045 else k / 12.92 for k in c]


def main():
    moto()
    # a moto inclinada sobe as rodas; desce tudo até o pneu mais baixo tocar o chão
    ymin = min(colocar(p)[1] for v in MALHAS.values() for p, _ in v)
    binario = bytearray()
    views, accs, prims, mats = [], [], [], []
    for nome, verts in MALHAS.items():
        if not verts:
            continue
        pos = [add(colocar(p), (0, -ymin, 0)) for p, _ in verts]
        nor = [norm(colocar(n, True)) for _, n in verts]
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
        prims.append({"attributes": {"POSITION": len(accs) - 2, "NORMAL": len(accs) - 1}, "material": len(mats)})
        mats.append({"name": nome, "doubleSided": True,
                     "pbrMetallicRoughness": {"baseColorFactor": srgb_linear(CORES[nome]) + [1.0], "metallicFactor": 0.0, "roughnessFactor": 1.0}})
    gltf = {"asset": {"version": "2.0", "generator": "moto.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
            "nodes": [{"name": "moto_julia", "mesh": 0}], "meshes": [{"name": "moto_julia", "primitives": prims}],
            "materials": mats, "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(binario)}]}
    j = json.dumps(gltf, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    binario += b"\0" * (-len(binario) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(binario))
    out += struct.pack("<II", len(j), 0x4E4F534A) + j + struct.pack("<II", len(binario), 0x004E4942) + binario
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "wb") as f:
        f.write(out)
    print("moto:", sum(len(v) for v in MALHAS.values()) // 3, "triângulos,", len(out), "bytes em", SAIDA)


if __name__ == "__main__":
    main()
