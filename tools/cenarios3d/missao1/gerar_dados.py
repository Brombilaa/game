#!/usr/bin/env python3
"""Gera data/cenarios/<id>.json dos cenários 3D da missão 1 (delegacia 17h e 21h, subsolo, biblioteca, fazenda, cripta).

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


def cenario(cid, glb, col, hora, rotulo, grupo, extras, limite=None):
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
    # Limite do lugar (Léo, 13/11: "não tem um quadrado limitando as paredes de cada lugar"): fora dele é sólido,
    # então o grupo não dá a volta no prédio pela rua. Só fica a calçada da frente, onde o grupo chega e sai.
    if limite:
        lx0, lz0, lx1, lz1 = limite
        for i, r in enumerate([(x0, z0, x1 - x0, lz0 - z0), (x0, lz1, x1 - x0, z1 - lz1),
                               (x0, lz0, lx0 - x0, lz1 - lz0), (lx1, lz0, x1 - lx1, lz1 - lz0)]):
            rr = ret(*r)
            if rr[2] > 0 and rr[3] > 0:
                colisoes.append({"id": "limite%d" % i, "rect": rr})
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
    if col.get("pontos"):
        dados["_pontos"] = col["pontos"]
        dados["inicio"]["grupo"] = [p(*g) for g in col["pontos"]["grupo"]]
    if col.get("visao"):  # cripta: o que barra a visão é menos do que o que barra o passo (parapeito, fosso, altar)
        dados["visao"] = [rr for rr in (ret(*r) for r in col["visao"]) if rr[2] > 0 and rr[3] > 0]
    extras(dados, p, ret)
    dados.pop("_pontos", None)
    return dados


def _pt(d):
    """Pontos de jogo da delegacia já na planta ampliada (13/11), exportados por delegacia.js (PONTOS) via col.js."""
    return d["_pontos"]


def _ret4(ret, r):  # [x0, z0, x1, z1] em metros -> retângulo da sala
    return ret(r[0], r[1], r[2] - r[0], r[3] - r[1])


def _pista(d, p, cid, x, z, texto, da=None, raio=75, bolinha=(0, -30), chave=None, trancado=None, trecho=None):
    """Pista de investigação (documento, gaveta, item no chão). Textos, posições e itens são provisórios (Claude, 15/11).
    Baú ou esconderijo com saque (16/11): `da` é o saque; `chave` (um item) o deixa trancado até o grupo ter a chave na
    mochila, com `trancado` como aviso; `trecho` o esconde até esse trecho da cripta ser revelado."""
    c = {"id": cid, "pos": p(x, z), "raio": raio, "ordem": 1, "bolinha": list(bolinha), "texto": texto, "provisorio": True}
    if da:  # componentes de ritual (19/11, provisório) entram no mesmo saque
        c["da"] = [{"item": i, "qtd": q} for i, q in da]
    if chave:
        c["chave"] = chave
        c["texto_trancado"] = trancado or "Trancado. Falta a chave."
    if trecho:
        c["trecho"] = trecho
    d["pistas"].append(c)


def delegacia17(d, p, ret):
    P = _pt(d)
    d["objetivos"] = [{"texto": "Ler o livro de ocorrências", "pista": "livro_ocorrencias", "provisorio": True},
                      {"texto": "Procurar pistas no escritório do Ghular", "pista": "agenda_ghular", "provisorio": True},
                      {"texto": "Seguir para a biblioteca", "provisorio": True}]
    d["cena3d"]["estados"] = {"tapete": True, "alcapao": False}
    _pista(d, p, "livro_ocorrencias", 12.6, 14.6,
           "O livro de ocorrências está aberto no balcão. Nas últimas três semanas, a mesma anotação: \"Barulho na Fazenda Ghular\". Nenhuma viatura foi enviada. A última página foi arrancada.")
    _pista(d, p, "agenda_ghular", 14.0, 3.4,
           "Na agenda do delegado Ghular, sete datas do último mês estão circuladas, cada uma com uma orquídea vermelha desenhada a caneta. A sétima é de ontem. Na margem de todo sábado, a mesma anotação seca: \"treino\".")
    _pista(d, p, "gaveta_provas", 14.8, 9.8,
           "A gaveta da sala de provas foi forçada. Dentro, entre papéis manchados, ainda restam algumas balas soltas e um celular de tela rachada, num saco de provas.",
           da=[("municao_pistola", 6), ("celular_quebrado", 1)])
    _pista(d, p, "ficha_desaparecidos", 2.7, 4.8,
           "No arquivo, uma pasta com sete fichas de desaparecidos de Aurora. Nada liga uma à outra: idades, bairros e lugares do sumiço são todos diferentes. A mais recente é de ontem à noite: Lisandra de Sá, 38 anos, funcionária de farmácia, vista pela última vez perto da praça.")
    _pista(d, p, "cela_arranhoes", 1.5, 8.2,
           "As paredes da cela estão marcadas por arranhões fundos, feitos de dentro para fora. Desenhado com o que parece sangue, o mesmo símbolo da árvore do parque.")
    # Porta trancada (GDD #19: só abre com a chave achada no cenário; com a chave no grupo abre sozinha ao chegar).
    d["portas"] = [{"id": "escritorio_ghular", "ret": ret(11.7, 5.7, 1.7, 0.45), "chave": "chave_escritorio",
                    "texto": "Trancada. A porta do escritório do Ghular precisa de uma chave.", "provisorio": True}]
    _pista(d, p, "chaveiro_recepcao", 7.4, 15.0,
           "O chaveiro da recepção está quase vazio. Sobrou uma chave presa com uma etiqueta: \"Escritório do Delegado\".",
           da=[("chave_escritorio", 1)])
    d["objetivos"].insert(1, {"texto": "Achar a chave do escritório", "pista": "chaveiro_recepcao", "provisorio": True})
    # Cofre do delegado, dentro do escritório trancado: o saque é a razão de achar a chave (provisório, 16/11).
    _pista(d, p, "cofre_ghular", 12.2, 1.4,
           "Atrás da estante do escritório há um cofre de parede. A combinação está colada por baixo da gaveta da escrivaninha, e dentro ficam um colete, munição e duas baterias de rádio guardados pelo delegado.",
           da=[("colete_leve", 1), ("municao_pistola", 6), ("bateria", 2)])
    # Garrafa de água (Léo, 20/11: material da flor Verde, junto com o balde do poço). Posição e texto provisórios.
    _pista(d, p, "bebedouro_recepcao", 5.0, 15.0,
           "Ao lado do bebedouro da recepção, uma garrafa de água fechada. Pode servir.",
           da=[("garrafa_agua", 1)])
    _pista(d, p, "kit_recepcao", 3.0, 15.0,
           "Debaixo de um banco da recepção, esquecido por alguém com pressa, há um kit com curativos e uma bandagem.",
           da=[("curativo", 1), ("bandagem", 1)])
    # Cenas com roteiro (22/11, roteiro da missão 1): a chegada (o bilhete da Letícia) e, depois da agenda no escritório,
    # a chegada do delegado Ghular, simpático, e a mensagem da Letícia na caixa postal. Falas provisórias.
    d["cena_ao_chegar"] = {"cena": "delegacia_17h_chegada", "marca": "delegacia17_chegada"}
    d["gatilhos"].append({"id": "ghular_chega", "apos": "agenda_ghular", "tipo": "cena", "cena": "ghular_17h", "marca": "ghular_17h"})
    d["zonas"].append({"id": "saida", "ret": _ret4(ret, P["saida"]), "acao": "ir", "para": "biblioteca",
                       "texto": "O grupo segue para a biblioteca.", "provisorio": True})


def delegacia21(d, p, ret):
    P = _pt(d)
    d["objetivos"] = [{"texto": "Examinar o escritório do Ghular", "pista": "tapete"},
                      {"texto": "Descer pelo alçapão", "marca": "subsolo_visitado", "requer": "alcapao"},
                      {"texto": "Seguir para a Fazenda Ghular", "requer": "invasao_vencida"}]
    d["cena3d"]["estados"] = {"tapete": True, "alcapao": False}
    d["pistas"].append({"id": "tapete", "pos": p(*P["tapete"]), "raio": 80, "ordem": 1, "bolinha": [0, -20],
                        "destaque": {"estado": "tapete"},
                        "texto": "O tapete do canto está torto, como se alguém o tivesse puxado às pressas. Embaixo dele há um alçapão.",
                        "provisorio": True})
    d["gatilhos"].append({"id": "revelar_alcapao", "apos": "tapete", "tipo": "estado", "estados": {"tapete": False, "alcapao": True},
                          "marca": "alcapao"})
    d["zonas"].append({"id": "alcapao", "ret": _ret4(ret, P["alcapao"]), "acao": "ir", "para": "subsolo", "requer": "alcapao",
                       "texto": "O grupo desce pelo alçapão."})
    d["zonas"].append({"id": "saida", "ret": _ret4(ret, P["saida"]), "acao": "ir", "para": "fazenda", "requer": "invasao_vencida",
                       "texto": "O grupo segue para a Fazenda Ghular.", "provisorio": True})
    d["chegadas"] = {"subsolo": [p(*c) for c in P["chegadas_subsolo"]]}
    # Invasão (Léo, 13/11): depois do subsolo, ao entrar na recepção vindo do corredor, uma flashbang estoura pela
    # porta da frente e os inimigos entram; todos atiradores. Faixa da zona e posições = provisórios.
    d["zonas"].append({"id": "invasao", "ret": _ret4(ret, [5.6, 13.3, 13.8, 15.0]), "acao": "invasao",
                       "requer": "subsolo_visitado", "provisorio": True})
    d["cena_ao_chegar"] = {"cena": "delegacia_ghular_21h", "marca": "ghular_21h"}  # Túlio, o Ghular "aliado" e o motivo de olhar a sala dele
    d["invasao"] = {"quando": "zona", "marca": "invasao_vencida", "cena_depois": "ligacao_juliana", "flashbang": p(9.75, 18.2), "inimigos": [
        {"tipo": "atirador", "pos": p(*c), "provisorio": True} for c in [(9.75, 17.4), (7.7, 17.7), (11.8, 17.6)]]}


def subsolo(d, p, ret):
    d["marca_ao_chegar"] = "subsolo_visitado"
    d["objetivos"] = [{"texto": "Investigar o subsolo", "pista": "livro_faltando"}, {"texto": "Voltar ao escritório"}]
    d["pistas"].append({"id": "livro_faltando", "pos": p(1.0, 3.4), "raio": 70, "ordem": 1, "bolinha": [0, -40],
                        "destaque": {"nomes": ["Mesh33"]},  # a mesa (tampo) onde fica o retângulo limpo
                        "texto": "Sobre a mesa do subsolo, aberto, está o livro Sanguis Orchid: capa vermelha, uma orquídea dourada. Foi deixado ali de propósito. Sob ele, um mapa antigo da região com uma fazenda a leste marcada com uma orquídea vermelha e a anotação \"Ghular\".",
                        "provisorio": True})
    d["zonas"].append({"id": "escada", "ret": ret(4.2, 0.13, 1.27, 0.9), "acao": "ir", "para": "delegacia_21h", "chegada": "subsolo",
                       "texto": "O grupo sobe de volta para o escritório."})


def biblioteca(d, p, ret):
    d["objetivos"] = [{"texto": "Descobrir o que o Ghular pesquisava", "pista": "fichario", "provisorio": True},
                      {"texto": "Voltar para a delegacia", "provisorio": True}]
    _pista(d, p, "fichario", 11.4, 6.3,
           "Nas fichas de empréstimo, dois livros chamam a atenção. \"Sanguis Orchid\": doado em 1979 por Geraldo Munch, retirado só em 1987 e em 1997, as duas vezes por Frederico Ghular. Na última linha, em letra recente: confiscado como evidência por Roberto Ghular, há poucos dias.")
    _pista(d, p, "mesa_leitura", 2.6, 5.6,
           "O livro \"Aurora, a Cidade das Flores\" está aberto na mesa de leitura. Um parágrafo foi sublinhado: em 1970 a cidade pediu ao Vaticano que canonizasse Lygia Virgínia do Rosário como a Santa das Flores, e o pedido foi negado. Na margem, a lápis: \"carne feita de sangue só se desfaz com o próprio Outro Lado\".")
    _pista(d, p, "mapa_antigo", 12.7, 6.2,
           "Um recorte de jornal de 1977: \"Os Sete Desaparecidos, o mistério que continua a assolar Aurora\". Sete moradores sumiram ao longo de um mês; o investigador do caso era o jovem Geraldo Munch. A última desaparecida foi Maria Cabral, nascida em 1º de junho de 1948.")
    _pista(d, p, "diario_bibliotecaria", 15.3, 3.4,
           "O diário da Juliana termina de repente: \"O delegado levou o Sanguis Orchid como evidência de um caso em aberto. Mas o caso não tem relatório, e eu sei o que esse livro diz. Preciso contar à Lari.\"")
    _pista(d, p, "caixa_arquivo", 17.2, 6.4,
           "Uma caixa de arquivo morto foi deixada no canto. Dentro, escondido sob relatórios velhos, há um kit de primeiros socorros.",
           da=[("kit_primeiros_socorros", 1)])
    # Acervo restrito (16/11, provisório): a chave está na gaveta do balcão de empréstimos.
    _pista(d, p, "gaveta_balcao", 12.4, 9.0,
           "Na gaveta do balcão de empréstimos, junto de carimbos secos, há uma chave pequena com uma etiqueta: \"Acervo restrito\".",
           da=[("chave_acervo", 1)])
    _pista(d, p, "armario_acervo", 15.7, 8.5,
           "A chave gira no armário do acervo restrito. Entre livros embrulhados em plástico, a bibliotecária guardava suprimentos de emergência e um relógio de bolso parado à meia-noite.",
           da=[("bandagem", 2), ("antidoto", 1), ("municao_escopeta", 4), ("relogio_quebrado", 1)],
           chave="chave_acervo", trancado="Trancado. O armário do acervo restrito precisa de uma chave.")
    d["cena_ao_chegar"] = {"cena": "biblioteca_julia", "marca": "biblioteca_julia"}  # a Ju recebe o grupo (22/11)
    d["zonas"].append({"id": "saida", "ret": ret(-1.5, 12.4, 22.5, 2.1), "acao": "ir", "para": "delegacia_21h",
                       "texto": "O grupo volta para a delegacia.", "provisorio": True})


def fazenda(d, p, ret):
    d["objetivos"] = [{"texto": "Investigar o celeiro", "pista": "poco"}]
    d["pistas"].append({"id": "poco", "pos": p(6.2, 8.1), "raio": 90, "ordem": 1, "bolinha": [0, -30],
                        "destaque": {"raio": 1.6, "max": 3.2, "sem": ["unlit", "add"]},  # pedras da boca do poço
                        "texto": "O poço antigo desce para o escuro. Uma corda presa na borda some lá embaixo.", "provisorio": True})
    # Esconderijos e baú trancado (16/11, provisório): a chave do baú do celeiro fica pendurada fora, perto de onde o grupo chega.
    _pista(d, p, "prego_mourao", 4.9, 16.0,
           "Pendurada num prego do mourão, uma chave de cadeado com a etiqueta \"Celeiro\", enferrujada, mas inteira.",
           da=[("chave_celeiro", 1)])
    _pista(d, p, "caixote_ferramentas", 8.06, 1.69,
           "Atrás de um fardo de feno, um caixote de ferramentas arrombado. Sobraram um curativo, algumas balas, pregos enferrujados e um maço de fios.",
           da=[("curativo", 1), ("municao_pistola", 4), ("prego_enferrujado", 2), ("maco_fios", 1)])
    # Materiais das flores da Dama (Léo, 20/11): fertilizante e agrotóxico no celeiro; balde de água no poço. Posições e textos provisórios.
    _pista(d, p, "prateleira_insumos", 5.6, 1.69,
           "Na prateleira do celeiro, entre ferramentas, sacos de fertilizante abertos e um frasco de agrotóxico com a caveira no rótulo. As mesmas marcas das pétalas da praça.",
           da=[("fertilizante", 1), ("agrotoxico", 1)])
    _pista(d, p, "balde_poco", 7.2, 8.7,
           "Um balde amarrado na manivela do poço. A água lá de baixo corre fria; o grupo enche o balde.",
           da=[("balde", 1)])
    _pista(d, p, "bau_celeiro", 3.69, 10.75,
           "O cadeado do baú do celeiro cede. Dentro, enrolado num pano, um kit de primeiros socorros, cartuchos de escopeta e um saquinho de ossos de passarinho.",
           da=[("kit_primeiros_socorros", 1), ("municao_escopeta", 6), ("ossos_pequenos", 2)],
           chave="chave_celeiro", trancado="Trancado. O baú do celeiro tem um cadeado, e a chave deve estar por perto.")
    # Cripta (Léo, 14/11): depois de examinar o poço, o grupo desce pela corda.
    d["gatilhos"].append({"id": "descer_poco", "apos": "poco", "tipo": "ir", "para": "cripta",
                          "texto": "O grupo desce pela corda do poço."})
    # Grupo chega um pouco antes do portão, fora do alcance de quem está lá dentro (o atirador vê a 7 m: a chegada
    # recuou 2 m em 13/11).
    # Inimigos no celeiro (Léo, 12/11). Posições = centro das zonas marcadas no protótipo; eles percebem o grupo
    # pelo alcance normal (furtividade do GDD) e o combate começa.
    # Todos atiradores (Léo, 13/11).
    for (x, z) in [(2.0, 5.8), (10.4, 7.0), (8.2, 10.6)]:
        d["inimigos"].append({"tipo": "atirador", "pos": p(x, z), "provisorio": True})


def cripta(d, p, ret):
    """Cripta sob o poço da Fazenda Ghular, modelo C (Fosso de sangue) escolhido pelo Léo em 14/11.
    Tudo o que o Léo não ditou (números, textos, faixas dos gatilhos) vai marcado como provisório."""
    P = _pt(d)
    x0, z0 = d["cena3d"]["origem"]
    # Revelação por trechos (Léo: "o cenário não é revelado de primeira"): cada trecho é um glb à parte, desligado
    # até o líder pisar numa das faixas abaixo. A marca guarda a revelação no save.
    d["cena3d"]["estados"] = {"trecho2": False, "trecho3": False, "trecho4": False}
    faixas = {2: [[7.5, 40.0, 13.0, 43.4]],
              3: [[15.0, 34.0, 17.2, 38.6], [11.6, 33.0, 16.0, 35.0]],
              4: [[27.5, 24.0, 34.5, 29.6], [11.6, 12.0, 16.2, 24.0], [38.8, 22.0, 41.4, 28.2]]}
    for n in sorted(faixas):
        for i, f in enumerate(faixas[n]):
            z = {"id": "trecho%d_%d" % (n, i), "ret": _ret4(ret, f), "acao": "estado",
                 "estados": {"trecho%d" % n: True}, "trecho": n, "marca": "cripta_trecho%d" % n, "provisorio": True}
            if n == 4:  # o salão abre com o discurso do Ghular (data/cenas/cripta_ghular.json) antes de os cultistas e a luta
                z["cena"] = "cripta_ghular"
            d["zonas"].append(z)
    # Minimapa: só o que já foi revelado conta como visto.
    d["trechos"] = {
        "1": [_ret4(ret, r) for r in [[-6.8, 50.2, 12.6, 56.4], [7.6, 42.0, 12.8, 56.4]]],
        "2": [_ret4(ret, [7.6, 33.6, 16.4, 42.4])],
        "3": [_ret4(ret, r) for r in [[11.2, 12.4, 19.4, 34.0], [16.0, 33.6, 34.6, 38.8], [27.6, 25.6, 34.4, 34.0], [34.0, 24.0, 41.6, 33.2]]],
        "4": [_ret4(ret, [16.8, 3.6, 45.4, 26.4])],
    }
    # Área elevada (1,5 m): só muda a altura em que cada um é desenhado; o passo já está no mapa de colisão
    # (alto e chão só se ligam pelas escadas). Retângulos e arcos de elipse, em unidades da sala.
    for n in P["niveis"]:
        e = {"h": n["h"], "rampa": n["n"] == 2}
        if "r" in n:
            e["ret"] = _ret4(ret, n["r"])
            if n["n"] == 2:
                e["dir"] = n["dir"]
        else:
            cx, cz, a, b, t0, t1 = n["arc"]
            e["arco"] = [round((cx - x0) * U, 1), round((cz - z0) * U, 1), a * U, b * U, t0, t1, n["larg"] * U]
            if n["n"] == 2:
                e["de"], e["ate"] = n["de"], n["ate"]
        d.setdefault("niveis", []).append(e)
    # Inimigos (Léo): 2 nos primeiros corredores, de costas, que podem ser pegos desprevenidos; no salão, 7 contando
    # Roberto Ghular. Os de um trecho ainda escondido só entram em cena quando ele é revelado.
    for i in P["inimigos"]:
        e = {"tipo": i["tipo"], "pos": p(*i["pos"]), "trecho": i["trecho"], "grupo": "corredor" if i["trecho"] == 1 else "salao",
             "olha": [round(math.sin(i["ry"]), 3), round(math.cos(i["ry"]), 3)], "provisorio": True}
        if i["desprevenido"]:
            e["percepcao_fator"] = 0.5  # de costas: percebe a metade da distância (provisório)
        if e["grupo"] == "salao":
            e["ritual"] = True  # Léo (19/11): focados no ritual, só lutam se forem atacados
        d["inimigos"].append(e)
    d["inimigos"].append({"tipo": "roberto_ghular", "pos": p(*P["roberto"]), "trecho": 4, "grupo": "salao"})
    # Roberto se mata com pouca vida e a Dama de Sangue surge dele (Léo). O limite de 50% é provisório
    # (passada de balanceamento de 19/11; era 25%).
    d["chefe"] = {"tipo": "roberto_ghular", "limite": 0.5, "vira": "dama_sangue", "marca": "dama_surgiu",
                  "texto": "Roberto Ghular crava a adaga no próprio peito. Do sangue dele se ergue a Dama de Sangue.", "provisorio": True,
                  # Os seis pendurados vivos (Léo, 20/11; ChefeDama), na ordem em que ela devora (do mais jovem ao mais velho):
                  # fora do fosso, aos pares entre as três pontes, a 9,5 x 8,5 m do centro do altar. Posições provisórias.
                  "corpos": [p(31 + 9.5 * math.cos(math.radians(a)), 15 + 8.5 * math.sin(math.radians(a))) for a in (6, 46, 126, 166, 242, 282)]}
    # Fim da missão 1 (Léo, 15/11): com a Dama em ~20% de vida toca a cutscene do tentáculo que atravessa o Fernando,
    # e a morte dele; o combate continua (Dama, Letícia, celeiro e cutscene de fim de capítulo vêm depois). Limite e legenda são provisórios do Claude.
    # Passada de balanceamento (19/11): 20% em vez de 30%, para Nikolai e Miguel não ficarem com 36 PV de Dama sozinhos.
    # Léo (20/11): a morte do Fernando dispara com a Dama em 15% de PV ou menos, logo depois do turno dele, sempre.
    d["fim"] = {"limite": 0.15, "legenda": "Fernando não se levanta.", "provisorio": True}
    d["grupos"] = {"corredor": {"marca": "cripta_corredor_limpo"}, "salao": {"marca": "cripta_vencida", "requer": "dama_surgiu"}}
    # Letícia ferida e desmaiada no altar: só acorda ao interagir depois do combate com a Dama (Léo). Textos provisórios.
    alt = [g for g in P["gatilhos"] if g["nome"].startswith("altar")][0]["ret"]
    d["pistas"].append({"id": "leticia", "pos": p((alt[0] + alt[2]) / 2, (alt[1] + alt[3]) / 2), "raio": 150, "ordem": 1, "bolinha": [0, -96],
                        "requer": "cripta_vencida", "texto_antes": "Letícia está sobre o altar, ferida e desmaiada. Não dá para chegar até ela agora.",
                        "texto": "Letícia abre os olhos devagar. Está ferida, mas viva.", "provisorio": True})
    # Saque da cripta (16/11, provisório): no fundo do poço, a mochila de um desaparecido com a chave do ossuário; o
    # ossuário fica no salão (trecho 4, escondido até ser revelado) e guarda o melhor saque da missão.
    _pista(d, p, "mochila_desaparecido", 3.0, 54.5,
           "Ao pé da corda há uma mochila encharcada, de alguém dos fichários da delegacia. Dentro: um curativo e uma chave de ferro com um osso entalhado no cabo.",
           da=[("curativo", 1), ("chave_ossuario", 1)])
    _pista(d, p, "ossuario", 24.0, 12.56,
           "A chave de osso abre a tampa do ossuário. Entre restos que ninguém deveria ter mexido, ficaram suprimentos de quem veio antes, um punhado de cinzas e um frasco com um órgão boiando.",
           da=[("kit_primeiros_socorros", 1), ("curativo", 2), ("municao_pistola", 6), ("cinzas", 2), ("frasco_orgao", 1)], raio=90,
           chave="chave_ossuario", trancado="Trancado. A tampa do ossuário tem uma fechadura de ferro.", trecho=4)
    # Bulbo de Bravo Purpulis (Léo, 20/11: a planta roxa na pedra do cenário alimenta a flor Roxa da Dama). Posição e texto provisórios.
    _pista(d, p, "pedra_bravo_purpulis", 31 + 7.6 * math.cos(math.radians(320)), 15 + 6.6 * math.sin(math.radians(320)),
           "Entre as pedras escuras do salão nasce uma planta roxa, rasteira, de bulbo inchado. Bravo Purpulis, como no livro de botânica. O grupo arranca um bulbo.",
           da=[("bulbo_bravo_purpulis", 1)], trecho=4)
    d["gatilhos"].append({"id": "leticia_acorda", "apos": "leticia", "tipo": "estado", "estados": {}, "marca": "leticia_acordou"})
    # Pós-combate (Léo, 15/11): com a Letícia acordada o grupo sobe pelo poço e encontra a Ordem no celeiro. Texto provisório.
    d["gatilhos"].append({"id": "subir_celeiro", "apos": "leticia", "tipo": "ir", "para": "celeiro", "chegada": "poco",
                          "texto": "O grupo sobe pelo poço carregando a Letícia. Há luzes no celeiro.", "provisorio": True})
    d["objetivos"] = [{"texto": "Explorar a cripta", "marca": "cripta_trecho4", "provisorio": True},
                      {"texto": "Derrotar Roberto Ghular", "marca": "dama_surgiu", "requer": "cripta_trecho4"},
                      {"texto": "Derrotar a Dama de Sangue", "marca": "cripta_vencida", "requer": "dama_surgiu"},
                      {"texto": "Acordar a Letícia", "pista": "leticia", "requer": "cripta_vencida"}]


def celeiro(d, p, ret):
    """Pós-combate da missão 1 (Léo, 15/11): a Dama morta e a Letícia salva, o grupo sobe pelo poço e encontra a equipe
    de campo da Ordem (do bem) dentro do celeiro da Fazenda Ghular. Mesma cena 3D e mesmas colisões da fazenda, sem
    inimigos. Ao chegar toca a conversa (data/cenas/celeiro_ordem.json) e depois o fim do capítulo: a cutscene feita
    fora do jogo (se o vídeo existir; sem ele, a cena da igreja na Itália feita no jogo) e o cartão AURORA (modelo A,
    Léo 16/11). Posições, hora, textos e o caminho do vídeo são provisórios do Claude."""
    # Elenco (Léo, 19/11): Tristan, sub-líder da Ordem; Mark, que sela o poço e conhece o Miguel de anos atrás;
    # Júlia, namorada da Letícia e bibliotecária da cidade, que chega pela porta; a equipe médica cuida da Letícia.
    d["inicio"]["npcs"] = [{"id": "leticia", "pos": p(5.4, 10.4)}, {"id": "medico", "pos": p(4.6, 10.9)},
                           {"id": "tristan", "pos": p(8.2, 10.9)}, {"id": "mark", "pos": p(8.8, 9.8)},
                           {"id": "julia", "pos": p(6.0, 13.0)}]
    d["chegadas"] = {"poco": [p(6.0, 9.9), p(6.6, 10.4), p(7.2, 9.9)]}
    d["objetivos"] = [{"texto": "Falar com a Ordem", "marca": "celeiro_conversa", "provisorio": True}]
    d["cena_ao_chegar"] = {"cena": "celeiro_ordem", "marca": "celeiro_conversa"}
    d["fim_capitulo"] = {"video": "fim_capitulo1", "titulo": "AURORA", "legenda": "CAPÍTULO 1",
                         "marca": "capitulo1_fim", "provisorio": True}


# Pistas essenciais por lugar (Léo, 22/11: a investigação não é obrigatória). Só elas contam no HUD; as demais são extras.
# "resumo": o que o grupo deduz (entra no diário como dedução) se sair do lugar sem examinar a pista. Provisório.
ESSENCIAIS = {
    "delegacia_17h": {
        "chaveiro_recepcao": "Sem tempo para revirar a recepção, o grupo deduz que a chave do escritório do Ghular deve estar no chaveiro, e que a sala foi trancada de propósito.",
        "agenda_ghular": "O grupo deduz que o delegado marcava datas e sábados em segredo: o sumiço dos sete segue um calendário.",
    },
    "biblioteca": {"fichario": "O grupo deduz que o livro Sanguis Orchid passou pela biblioteca, que um Ghular o retirou e que agora está com Roberto Ghular."},
    "subsolo": {"livro_faltando": "O grupo deduz que o livro foi deixado de propósito no subsolo, junto de um mapa que aponta a Fazenda Ghular, a leste."},
    "fazenda": {"poco": "O grupo deduz que o poço antigo é a entrada: uma corda desce para o escuro."},
}


def marcar_essenciais(cid, dados):
    for p in dados.get("pistas", []):
        resumo = ESSENCIAIS.get(cid, {}).get(p["id"])
        if resumo:
            p["essencial"] = True
            p["resumo"] = resumo


def main():
    lista = [
        ("delegacia_17h", "delegacia_17h", "delegacia_17h", 17, "DELEGACIA", [(7.2, 15.5), (6.5, 16.0), (7.9, 16.1)], delegacia17, (-0.15, -0.15, 19.45, 22.25)),
        ("delegacia_21h", "delegacia_21h", "delegacia_21h", 21, "DELEGACIA", [(7.2, 15.5), (6.5, 16.0), (7.9, 16.1)], delegacia21, (-0.15, -0.15, 19.45, 22.25)),
        ("subsolo", "subsolo", "subsolo", 21, "SUBSOLO", [(3.4, 2.6), (2.7, 2.9), (3.9, 3.3)], subsolo, None),
        ("biblioteca", "biblioteca", "biblioteca", 19, "BIBLIOTECA", [(12.7, 11.2), (12.0, 11.7), (13.4, 11.7)], biblioteca, (-0.15, -0.15, 18.15, 13.2)),
        ("fazenda", "fazenda", "fazenda", 23, "FAZENDA GHULAR", [(6.2, 17.8), (5.5, 18.3), (6.9, 18.4)], fazenda, (-3.5, -2.5, 16.0, 19.0)),
        ("cripta", "cripta", "cripta", 23, "CRIPTA", [(-1.2, 53.8), (-2.8, 53.0), (-2.9, 54.7)], cripta, None),
        ("celeiro", "fazenda", "fazenda", 1, "CELEIRO", [(6.0, 9.9), (6.6, 10.4), (7.2, 9.9)], celeiro, (-3.5, -2.5, 16.0, 19.0)),
    ]
    for cid, glb, col, hora, rotulo, grupo, extras, limite in lista:
        dados = cenario(cid, glb, carregar(col), hora, rotulo, grupo, extras, limite)
        marcar_essenciais(cid, dados)
        with open(os.path.join(RAIZ, "data", "cenarios", cid + ".json"), "w") as f:
            json.dump(dados, f, ensure_ascii=False, indent=1)
        print(cid, len(dados["colisoes"]), "colisões")


if __name__ == "__main__":
    main()
