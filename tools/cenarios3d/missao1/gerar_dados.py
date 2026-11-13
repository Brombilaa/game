#!/usr/bin/env python3
"""Gera data/cenarios/<id>.json dos cenários 3D da missão 1 (delegacia 17h e 21h, subsolo, biblioteca, fazenda).

Entrada: os mapas de colisão tirados das próprias cenas do protótipo (colisao/<id>.json, gerados por col.js:
corte horizontal entre 35 cm e 1,75 m do piso, visto de cima; retângulos [x, z, largura, profundidade] em metros).
Saída: o formato de `Scenario` (unidades da sala, 64 por metro, origem no canto da área) mais as chaves que só a
cena `local3d` lê: `cena3d` (qual glb, deslocamento e estados) e `zonas` (áreas que levam a outro lugar ou disparam algo).

Rodar da raiz do repositório:  python3 tools/cenarios3d/missao1/gerar_dados.py
Valores marcados com "provisorio" são escolhas do Claude que ainda não passaram pelo Léo.
"""
import json
import math
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
U = 64.0  # unidades da sala por metro (1 unidade 3D do cenário = 1 losango)


def carregar(nome):
    with open(os.path.join(AQUI, "colisao", nome + ".json")) as f:
        return json.load(f)


def cenario(cid, glb, col, hora, rotulo, grupo, extras):
    x0, z0, x1, z1 = col["area"]
    w, h = (x1 - x0) * U, (z1 - z0) * U

    def p(x, z):
        return [round((x - x0) * U, 1), round((z - z0) * U, 1)]

    def ret(x, z, rw, rh):  # metros -> retângulo da sala, recortado ao plano
        a, b = max(0.0, (x - x0) * U), max(0.0, (z - z0) * U)
        c, d = min(w, (x + rw - x0) * U), min(h, (z + rh - z0) * U)
        a, b = round(a, 1), round(b, 1)
        return [a, b, math.floor((c - a) * 10) / 10, math.floor((d - b) * 10) / 10]

    colisoes = []
    for i, r in enumerate(col["retangulos"]):
        rr = ret(*r)
        if rr[2] > 0 and rr[3] > 0:
            colisoes.append({"id": "c%d" % i, "rect": rr})
    dados = {
        "_comentario": "Gerado por tools/cenarios3d/missao1/gerar_dados.py a partir do mapa de colisão da cena 3D (não editar à mão).",
        "id": cid,
        "rotulo": rotulo,
        "hora": hora,
        "tamanho": [math.ceil(w * 10) / 10, math.ceil(h * 10) / 10],
        "fundo": {"escala_tela": [48.0, 18.13], "_nota": "sem imagem: o fundo é a cena 3D; a escala é a da câmera do parque"},
        "cena3d": {"id": glb, "origem": [x0, z0]},
        "inicio": {"grupo": [p(*g) for g in grupo]},
        "colisoes": colisoes,
        "pistas": [],
        "gatilhos": [],
        "zonas": [],
        "inimigos": [],
        "objetivos": [],
    }
    extras(dados, p, ret)
    return dados


def delegacia17(d, p, ret):
    d["objetivos"] = [{"texto": "Seguir para a biblioteca", "provisorio": True}]
    d["cena3d"]["estados"] = {"tapete": True, "alcapao": False}
    d["zonas"].append({"id": "saida", "ret": ret(-1.5, 16.6, 19.0, 2.4), "acao": "ir", "para": "biblioteca",
                       "texto": "O grupo segue para a biblioteca.", "provisorio": True})


def delegacia21(d, p, ret):
    d["objetivos"] = [{"texto": "Examinar o escritório do Ghular", "pista": "tapete"},
                      {"texto": "Descer pelo alçapão", "marca": "subsolo_visitado", "requer": "alcapao"},
                      {"texto": "Seguir para a Fazenda Ghular", "requer": "invasao_vencida"}]
    d["cena3d"]["estados"] = {"tapete": True, "alcapao": False}
    d["pistas"].append({"id": "tapete", "pos": p(8.95, 0.95), "raio": 80, "ordem": 1, "bolinha": [0, -20],
                        "texto": "O tapete do canto está torto, como se alguém o tivesse puxado às pressas. Embaixo dele há um alçapão.",
                        "provisorio": True})
    d["gatilhos"].append({"id": "revelar_alcapao", "apos": "tapete", "tipo": "estado", "estados": {"tapete": False, "alcapao": True},
                          "marca": "alcapao"})
    d["zonas"].append({"id": "alcapao", "ret": ret(7.95, 0.3, 2.0, 1.25), "acao": "ir", "para": "subsolo", "requer": "alcapao",
                       "texto": "O grupo desce pelo alçapão."})
    d["zonas"].append({"id": "saida", "ret": ret(-1.5, 16.6, 19.0, 2.4), "acao": "ir", "para": "fazenda", "requer": "invasao_vencida",
                       "texto": "O grupo segue para a Fazenda Ghular.", "provisorio": True})
    d["chegadas"] = {"subsolo": [p(8.9, 2.2), p(9.7, 2.5), p(8.2, 2.6)]}
    # Invasão (Léo, 12/11): na saída do subsolo os inimigos entram pela porta da frente (porta da frente = provisório).
    d["invasao"] = {"quando": "chegada_subsolo", "marca": "invasao_vencida", "inimigos": [
        {"tipo": "cultista", "pos": p(7.2, 13.0)}, {"tipo": "cultista", "pos": p(6.3, 15.0)}, {"tipo": "cultista", "pos": p(8.2, 15.2)}]}


def subsolo(d, p, ret):
    d["marca_ao_chegar"] = "subsolo_visitado"
    d["objetivos"] = [{"texto": "Investigar o subsolo", "pista": "livro_faltando"}, {"texto": "Voltar ao escritório"}]
    d["pistas"].append({"id": "livro_faltando", "pos": p(1.0, 3.4), "raio": 70, "ordem": 1, "bolinha": [0, -40],
                        "texto": "Pó em toda a mesa, menos num retângulo limpo: um livro grosso ficava aqui até pouco tempo.",
                        "provisorio": True})
    d["zonas"].append({"id": "escada", "ret": ret(4.2, 0.13, 1.27, 0.9), "acao": "ir", "para": "delegacia_21h", "chegada": "subsolo",
                       "texto": "O grupo sobe de volta para o escritório."})


def biblioteca(d, p, ret):
    d["objetivos"] = [{"texto": "Voltar para a delegacia", "provisorio": True}]
    d["zonas"].append({"id": "saida", "ret": ret(-1.5, 12.4, 22.5, 2.1), "acao": "ir", "para": "delegacia_21h",
                       "texto": "O grupo volta para a delegacia.", "provisorio": True})


def fazenda(d, p, ret):
    d["objetivos"] = [{"texto": "Investigar o celeiro", "pista": "poco"}]
    d["pistas"].append({"id": "poco", "pos": p(6.2, 8.1), "raio": 90, "ordem": 1, "bolinha": [0, -30],
                        "texto": "O poço antigo desce para o escuro. Lá embaixo ficam as ruínas.", "provisorio": True})
    # Grupo chega um pouco antes do portão, fora do alcance de quem está lá dentro.
    # Inimigos no celeiro (Léo, 12/11). Posições = centro das zonas marcadas no protótipo; eles percebem o grupo
    # pelo alcance normal (furtividade do GDD) e o combate começa.
    for (x, z) in [(2.0, 5.8), (10.4, 7.0), (8.2, 10.6)]:
        d["inimigos"].append({"tipo": "cultista", "pos": p(x, z), "provisorio": True})


def main():
    lista = [
        ("delegacia_17h", "delegacia_17h", "delegacia_17h", 17, "DELEGACIA", [(7.2, 15.5), (6.5, 16.0), (7.9, 16.1)], delegacia17),
        ("delegacia_21h", "delegacia_21h", "delegacia_21h", 21, "DELEGACIA", [(7.2, 15.5), (6.5, 16.0), (7.9, 16.1)], delegacia21),
        ("subsolo", "subsolo", "subsolo", 21, "SUBSOLO", [(3.4, 2.6), (2.7, 2.9), (3.9, 3.3)], subsolo),
        ("biblioteca", "biblioteca", "biblioteca", 19, "BIBLIOTECA", [(12.7, 11.2), (12.0, 11.7), (13.4, 11.7)], biblioteca),
        ("fazenda", "fazenda", "fazenda", 23, "FAZENDA GHULAR", [(6.2, 15.8), (5.5, 16.4), (6.9, 16.5)], fazenda),
    ]
    for cid, glb, col, hora, rotulo, grupo, extras in lista:
        dados = cenario(cid, glb, carregar(col), hora, rotulo, grupo, extras)
        with open(os.path.join(RAIZ, "data", "cenarios", cid + ".json"), "w") as f:
            json.dump(dados, f, ensure_ascii=False, indent=1)
        print(cid, len(dados["colisoes"]), "colisões")


if __name__ == "__main__":
    main()
