#!/usr/bin/env python3
"""Imagens de pista do diário: fichas de desaparecidos e páginas rasgadas (Claude, 22/11/2026).
Uso: python3 tools/pistas_imagens/gerar.py <modelo A|B|C> <pasta de saída> [id ...]
Cada imagem é 720x720 com fundo transparente (o jogo mostra em 360x360 na caixa de pista e no diário)."""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

RAIZ = os.path.join(os.path.dirname(__file__), "..", "..")
MAQ = os.path.join(RAIZ, "assets/fonts/SpecialElite-Regular.ttf")
MAO = os.path.join(RAIZ, "assets/fonts/Caveat-Variable.ttf")
S = 720


def fonte(caminho, tam):
    return ImageFont.truetype(caminho, tam)


def ruido(img, forca, semente):
    r = random.Random(semente)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            d = int(r.gauss(0, forca))
            px[x, y] = (max(0, min(255, c[0] + d)), max(0, min(255, c[1] + d)), max(0, min(255, c[2] + d)), c[3])
    return img


def papel(w, h, base, forca=7, semente=1, veio=True):
    img = Image.new("RGBA", (w, h), base + (255,))
    ruido(img, forca, semente)
    if veio:  # manchas largas de envelhecimento
        r = random.Random(semente + 5)
        m = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(m)
        for _ in range(14):
            x, y, rr = r.randint(0, w), r.randint(0, h), r.randint(40, 170)
            d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=r.randint(10, 34))
        m = m.filter(ImageFilter.GaussianBlur(40))
        esc = Image.new("RGBA", (w, h), (92, 60, 24, 255))
        img = Image.composite(esc, img, m)
    return img


def _dente(t, semente):
    r = random.Random(semente * 7)
    f = [(r.uniform(11, 31), r.uniform(0, 6.3), r.uniform(0.3, 1)) for _ in range(3)]
    v = sum(a * abs(math.sin(t * k + ph)) for k, ph, a in f) / sum(a for _, _, a in f)
    return v


def borda_irregular(w, h, semente, rasgo=("baixo",), amp=9, fundo=26, passo=7):
    """Máscara do papel: bordas retas com leve tremor; os lados em `rasgo` ficam rasgados (dentes fundos)."""
    r = random.Random(semente)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    pts = []
    def lado(n, f):
        return [f(i / n, r.uniform(-1, 1)) for i in range(n + 1)]
    a = amp if "cima" in rasgo else 2.2
    pts += lado(w // passo, lambda t, j: (t * w, a + j * a * 0.6 + (math.sin(t * 40) * 3 if "cima" in rasgo else 0)))
    a = amp if "dir" in rasgo else 2.2
    pts += lado(h // passo, lambda t, j: (w - a - j * a * 0.6, t * h))
    a = amp if "baixo" in rasgo else 2.2
    pts += lado(w // passo, lambda t, j: ((1 - t) * w, h - a - j * a * 0.6 - (_dente(t, semente) * fundo if "baixo" in rasgo else 0)))
    a = amp if "esq" in rasgo else 2.2
    pts += lado(h // passo, lambda t, j: (a + j * a * 0.6, (1 - t) * h))
    d.polygon(pts, fill=255)
    return m


def recorta(img, mascara):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), ImageChops.multiply(img.getchannel("A"), mascara))
    return out


def sombra(folha, desloca=(9, 12), borra=9, alfa=130):
    a = folha.getchannel("A").point(lambda v: v * alfa // 255)
    sh = Image.new("RGBA", folha.size, (0, 0, 0, 0))
    sh.putalpha(a)
    sh = sh.filter(ImageFilter.GaussianBlur(borra))
    return ImageChops.offset(sh, *desloca)


def pousa(folha, graus, centro=(S // 2, S // 2), com_sombra=True):
    """Gira a folha e a coloca no quadro 720x720 com sombra suave."""
    f = folha.rotate(graus, resample=Image.BICUBIC, expand=True)
    quadro = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    x, y = centro[0] - f.width // 2, centro[1] - f.height // 2
    if com_sombra:
        quadro.alpha_composite(sombra(f), (x, y))
    quadro.alpha_composite(f, (x, y))
    return quadro


def quebra(txt, fnt, larg):
    linhas, atual = [], ""
    for palavra in txt.split():
        t = (atual + " " + palavra).strip()
        if fnt.getlength(t) <= larg:
            atual = t
        else:
            linhas.append(atual)
            atual = palavra
    if atual:
        linhas.append(atual)
    return linhas


def escreve(d, xy, txt, fnt, cor, larg=None, esp=1.25, jitter=0, semente=0):
    x, y = xy
    r = random.Random(semente)
    for ln in (quebra(txt, fnt, larg) if larg else [txt]):
        if jitter:
            cx = x
            for ch in ln:
                d.text((cx, y + r.uniform(-jitter, jitter)), ch, font=fnt, fill=cor)
                cx += fnt.getlength(ch)
        else:
            d.text((x, y), ln, font=fnt, fill=cor)
        y += int(fnt.size * esp)
    return y


def mancha_cafe(img, centro, raio, alfa=90, semente=3):
    r = random.Random(semente)
    m = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(m)
    for k in range(3):
        rr = raio - k * 2
        d.ellipse((centro[0] - rr, centro[1] - rr, centro[0] + rr, centro[1] + rr), outline=alfa - k * 20, width=5 - k)
    d.ellipse((centro[0] - raio + 6, centro[1] - raio + 6, centro[0] + raio - 6, centro[1] + raio - 6), fill=alfa // 4)
    m = m.filter(ImageFilter.GaussianBlur(1.6))
    cor = Image.new("RGBA", img.size, (96, 58, 22, 255))
    img.paste(cor, (0, 0), m)


def sangue(img, x, y, comp, larg=7, cor=(120, 14, 10), semente=1):
    r = random.Random(semente)
    d = ImageDraw.Draw(img)
    d.ellipse((x - larg, y - larg * 0.7, x + larg, y + larg * 0.7), fill=cor + (235,))
    d.rectangle((x - larg * 0.45, y, x + larg * 0.45, y + comp), fill=cor + (235,))
    d.ellipse((x - larg * 0.75, y + comp - larg * 0.5, x + larg * 0.75, y + comp + larg * 0.9), fill=cor + (235,))


def silhueta(d, box, fundo, cor):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=fundo)
    cx = (x0 + x1) // 2
    w = x1 - x0
    h = y1 - y0
    camada = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    c = ImageDraw.Draw(camada)
    c.ellipse((w / 2 - w * 0.2, h * 0.17, w / 2 + w * 0.2, h * 0.17 + w * 0.42), fill=cor)
    c.ellipse((w / 2 - w * 0.42, h * 0.62, w / 2 + w * 0.42, h + w * 0.5), fill=cor)
    d._image.alpha_composite(camada, (x0, y0))


def clipe(d, x, y, cor=(150, 150, 156)):
    d.rounded_rectangle((x, y, x + 20, y + 84), 10, outline=cor, width=4)
    d.rounded_rectangle((x + 6, y + 14, x + 14, y + 98), 4, outline=cor, width=3)


def fita(quadro, centro, graus, w=96, h=34, cor=(214, 200, 150, 190)):
    f = Image.new("RGBA", (w, h), cor)
    d = ImageDraw.Draw(f)
    for i in range(0, w, 7):
        d.line((i, 0, i - 5, h), fill=(255, 255, 255, 35), width=2)
    f = f.rotate(graus, expand=True, resample=Image.BICUBIC)
    quadro.alpha_composite(f, (centro[0] - f.width // 2, centro[1] - f.height // 2))


def carimbo(quadro, texto, centro, graus, cor, tam=54, larg=7):
    f = fonte(MAQ, tam)
    w = int(f.getlength(texto)) + 40
    h = tam + 34
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rounded_rectangle((3, 3, w - 4, h - 4), 8, outline=cor + (215,), width=larg - 2)
    d.text((20, 14), texto, font=f, fill=cor + (215,))
    ru = Image.new("L", c.size, 0)
    r = random.Random(7)
    pr = ru.load()
    for y in range(h):
        for x in range(w):
            pr[x, y] = 255 if r.random() > 0.2 else 120
    c.putalpha(ImageChops.multiply(c.getchannel("A"), ru))
    c = c.rotate(graus, expand=True, resample=Image.BICUBIC)
    quadro.alpha_composite(c, (centro[0] - c.width // 2, centro[1] - c.height // 2))


def orquidea(d, cx, cy, r, cor):
    """Orquídea vermelha estilizada (o símbolo do caso): 3 pétalas, 2 laterais e um labelo."""
    for ang in (-90, 30, 150):
        a = math.radians(ang)
        px, py = cx + math.cos(a) * r * 0.55, cy + math.sin(a) * r * 0.55
        d.ellipse((px - r * 0.38, py - r * 0.5, px + r * 0.38, py + r * 0.5), outline=cor, width=max(2, r // 9))
    d.ellipse((cx - r * 0.16, cy - r * 0.16, cx + r * 0.16, cy + r * 0.16), fill=cor)
    d.line((cx, cy + r * 0.2, cx + 4, cy + r * 1.5), fill=cor, width=max(2, r // 10))


# ---------------------------------------------------------------- conteúdo (textos do jogo, gerar_dados.py)
LISANDRA = [("NOME", "Lisandra de Sá"), ("IDADE", "38 anos"), ("PROFISSÃO", "Funcionária de farmácia"),
            ("ÚLTIMA VEZ", "Ontem à noite, perto da praça"), ("BAIRRO", "Centro")]
SETE = ["Sete fichas na mesma pasta.", "Nada liga uma à outra."]


# ================================================================= MODELO A: formulário datilografado da delegacia
def a_ficha():
    w, h = 560, 640
    f = papel(w, h, (224, 205, 160), 6, 11)
    d = ImageDraw.Draw(f)
    tinta = (46, 38, 30)
    d.rectangle((18, 18, w - 19, 74), outline=tinta, width=3)
    d.text((34, 24), "DELEGACIA DE AURORA", font=fonte(MAQ, 26), fill=tinta)
    d.text((34, 50), "PESSOA DESAPARECIDA · Nº 7/7", font=fonte(MAQ, 17), fill=tinta)
    silhueta(d, (36, 98, 206, 282), (164, 154, 134, 255), (96, 88, 76, 255))
    d.rectangle((36, 98, 206, 282), outline=tinta, width=3)
    y = 98
    for rot, val in LISANDRA[:4]:
        d.text((228, y), rot, font=fonte(MAQ, 15), fill=(120, 40, 30))
        y = escreve(d, (228, y + 17), val, fonte(MAQ, 20), tinta, larg=300, esp=1.15) + 8
    d.line((36, 312, w - 36, 312), fill=tinta, width=2)
    d.text((36, 326), "OBSERVAÇÕES", font=fonte(MAQ, 15), fill=(120, 40, 30))
    escreve(d, (36, 348), "Saiu do trabalho às 21h. Não chegou em casa. Celular desligado. Família não sabe de inimigos.", fonte(MAQ, 20), tinta, larg=490, esp=1.3)
    d.text((36, 448), "Sete fichas, nenhuma ligação.", font=fonte(MAQ, 17), fill=(120, 40, 30))
    d.line((36, 478, w - 36, 478), fill=tinta, width=2)
    for i, ln in enumerate(["Ficha 6: Bruno Teixeira, 52", "Ficha 5: Marcos Alves, 24", "Ficha 4: ..."]):
        d.text((36, 492 + i * 28), ln, font=fonte(MAQ, 17), fill=(86, 76, 62))
    mancha_cafe(f, (430, 520), 46, 80, 4)
    folha = recorta(f, borda_irregular(w, h, 3, rasgo=(), amp=2))
    q = pousa(folha, -3.5)
    clipe(ImageDraw.Draw(q), 118, 56)
    carimbo(q, "DESAPARECIDA", (440, 572), -7, (150, 24, 20), 28)
    return q


def a_pagina():
    w, h = 580, 640
    f = papel(w, h, (234, 224, 196), 5, 21)
    d = ImageDraw.Draw(f)
    tinta = (40, 36, 34)
    azul = (60, 70, 120)
    for yy in range(96, h, 34):
        d.line((20, yy, w - 20, yy), fill=(150, 170, 190, 255), width=1)
    d.line((84, 0, 84, h), fill=(190, 80, 80, 255), width=2)
    d.text((100, 30), "LIVRO DE OCORRÊNCIAS", font=fonte(MAQ, 26), fill=tinta)
    d.text((100, 62), "Delegacia de Aurora", font=fonte(MAQ, 17), fill=(90, 80, 70))
    regs = [("04/10", "Barulho na Fazenda Ghular."), ("11/10", "Barulho na Fazenda Ghular."), ("18/10", "Barulho na Fazenda Ghular."),
            ("19/10", "Viatura: nenhuma enviada."), ("25/10", "Barulho na Fazenda Ghular.")]
    for i, (dt, tx) in enumerate(regs):
        y = 106 + i * 68
        d.text((30, y), dt, font=fonte(MAQ, 17), fill=(100, 60, 50))
        d.text((100, y), tx, font=fonte(MAQ, 19), fill=tinta)
        d.text((100, y + 34), "Sem seguimento.", font=fonte(MAQ, 15), fill=azul)
    d.line((20, 460, w - 20, 460), fill=tinta, width=1)
    mancha_cafe(f, (110, 560), 52, 70, 8)
    m = borda_irregular(w, h, 5, rasgo=("esq", "baixo"), amp=14, fundo=70, passo=6)
    folha = recorta(f, m)
    q = pousa(folha, 2.5)
    return q


# ================================================================= MODELO B: manuscrito no papel pautado
def b_ficha():
    w, h = 560, 600
    f = papel(w, h, (236, 228, 205), 5, 31)
    d = ImageDraw.Draw(f)
    azul = (34, 44, 92)
    for yy in range(70, h, 38):
        d.line((0, yy, w, yy), fill=(156, 178, 200, 255), width=1)
    d.line((70, 0, 70, h), fill=(196, 96, 96, 255), width=2)
    h1 = fonte(MAO, 44)
    h2 = fonte(MAO, 33)
    d.text((86, 14), "Lisandra de Sá, 38", font=h1, fill=azul)
    y = 84
    for ln in ["funcionária de farmácia", "ontem à noite, perto da praça", "saiu do trabalho às 21h", "não chegou em casa", "celular desligado"]:
        d.text((86, y), ln, font=h2, fill=azul)
        y += 38
    d.text((86, y + 40), "sete fichas.", font=h1, fill=azul)
    d.text((86, y + 84), "nada liga uma à outra?", font=h2, fill=(140, 30, 24))
    d.line((86, y + 124, 380, y + 122), fill=(140, 30, 24), width=3)
    mancha_cafe(f, (440, 90), 44, 90, 6)
    folha = recorta(f, borda_irregular(w, h, 9, rasgo=(), amp=2))
    q = pousa(folha, -2.0, (S // 2, S // 2 + 30))
    # foto 3x4 presa com fita
    ft = Image.new("RGBA", (150, 190), (0, 0, 0, 0))
    dd = ImageDraw.Draw(ft)
    dd.rectangle((0, 0, 149, 189), fill=(236, 232, 222, 255))
    silhueta(dd, (10, 10, 139, 150), (150, 142, 126, 255), (84, 78, 68, 255))
    dd.text((14, 154), "Lisandra", font=fonte(MAO, 28), fill=(60, 50, 40))
    ft = pousa(ft, 7, (S // 2, S // 2), False)
    ft2 = ft.crop((S // 2 - 90, S // 2 - 110, S // 2 + 90, S // 2 + 110))
    q.alpha_composite(sombra(ft2, (4, 6), 5, 120), (470, 410))
    q.alpha_composite(ft2, (470, 410))
    fita(q, (560, 428), 25)
    return q


def b_pagina():
    w, h = 560, 620
    f = papel(w, h, (232, 222, 198), 5, 41)
    d = ImageDraw.Draw(f)
    azul = (34, 44, 92)
    for yy in range(80, h, 38):
        d.line((0, yy, w, yy), fill=(156, 178, 200, 255), width=1)
    d.line((70, 0, 70, h), fill=(196, 96, 96, 255), width=2)
    for yy in range(26, h, 52):  # furos da espiral rasgados
        d.ellipse((8, yy, 24, yy + 16), fill=(0, 0, 0, 0))
    g = fonte(MAO, 36)
    y = 30
    for ln in ["barulho na Fazenda Ghular", "barulho na Fazenda Ghular", "barulho na Fazenda Ghular", "nenhuma viatura enviada", "ninguém vai pra lá. por quê?"]:
        d.text((86, y), ln, font=g, fill=azul)
        y += 46
    d.text((86, y + 20), "última página arrancada", font=fonte(MAO, 36), fill=(140, 30, 24))
    mancha_cafe(f, (400, 470), 50, 80, 9)
    m = borda_irregular(w, h, 12, rasgo=("esq", "cima"), amp=16, fundo=40, passo=6)
    folha = recorta(f, m)
    return pousa(folha, -3)


# ================================================================= MODELO C: fotocópia e papel queimado, sangue
def c_ficha():
    w, h = 560, 640
    f = papel(w, h, (196, 192, 180), 11, 51)
    d = ImageDraw.Draw(f)
    tinta = (28, 26, 24)
    d.text((28, 22), "DESAPARECIDA", font=fonte(MAQ, 46), fill=tinta)
    d.line((28, 82, w - 28, 82), fill=tinta, width=4)
    silhueta(d, (34, 104, 264, 372), (60, 58, 56, 255), (22, 20, 20, 255))
    d.rectangle((34, 104, 264, 372), outline=tinta, width=4)
    y = 106
    for rot, val in LISANDRA[:3]:
        d.text((288, y), rot, font=fonte(MAQ, 15), fill=(110, 30, 24))
        y = escreve(d, (288, y + 18), val, fonte(MAQ, 22), tinta, larg=240, esp=1.12) + 10
    d.text((34, 396), "VISTA PELA ÚLTIMA VEZ", font=fonte(MAQ, 16), fill=(110, 30, 24))
    escreve(d, (34, 418), "Ontem à noite, perto da praça.", fonte(MAQ, 24), tinta, larg=490)
    # X de tinta vermelha sobre o rosto + orquídea
    vm = (150, 20, 16)
    d.line((60, 126, 238, 350), fill=vm + (230,), width=10)
    d.line((238, 126, 60, 350), fill=vm + (230,), width=10)
    orquidea(d, 440, 540, 58, vm + (235,))
    d.text((34, 480), "Nº 7 DE 7", font=fonte(MAQ, 26), fill=tinta)
    for k, x in enumerate((70, 150, 215)):
        sangue(f, x, 352 + k * 4, 10 + k * 9, 7, semente=k)
    m = borda_irregular(w, h, 17, rasgo=("dir", "cima", "baixo", "esq"), amp=10, fundo=0, passo=5)
    # queimado: escurece perto da borda
    esc = m.filter(ImageFilter.GaussianBlur(18)).point(lambda v: 255 - v)
    f = Image.composite(Image.new("RGBA", f.size, (30, 18, 8, 255)), f, esc.point(lambda v: min(255, v * 2)))
    folha = recorta(f, m)
    return pousa(folha, 3.5)


def c_pagina():
    w, h = 580, 640
    f = papel(w, h, (190, 176, 140), 9, 61)
    d = ImageDraw.Draw(f)
    tinta = (34, 28, 22)
    d.text((30, 28), "OCORRÊNCIAS", font=fonte(MAQ, 34), fill=tinta)
    for i, (dt, tx) in enumerate([("04/10", "Barulho na Fazenda Ghular."), ("11/10", "Barulho na Fazenda Ghular."), ("18/10", "Barulho na Fazenda Ghular."), ("25/10", "Barulho na Fazenda Ghular.")]):
        d.text((30, 100 + i * 66), dt, font=fonte(MAQ, 17), fill=(110, 40, 30))
        d.text((110, 100 + i * 66), tx, font=fonte(MAQ, 20), fill=tinta)
    vm = (150, 20, 16)
    d.text((30, 380), "a última página foi arrancada", font=fonte(MAO, 44), fill=vm + (240,))
    orquidea(d, 470, 280, 50, vm + (225,))
    for k, x in enumerate((420, 470, 505)):
        sangue(f, x, 450 + k * 8, 40 + k * 28, 8, semente=10 + k)
    d.ellipse((150, 520, 200, 580), fill=(120, 16, 12, 150))  # digital
    for r in range(8, 26, 4):
        d.arc((175 - r, 550 - r * 1.2, 175 + r, 550 + r * 1.2), 200, 340, fill=(60, 8, 6, 190), width=2)
    m = borda_irregular(w, h, 19, rasgo=("baixo", "dir"), amp=14, fundo=110, passo=6)
    esc = m.filter(ImageFilter.GaussianBlur(14)).point(lambda v: 255 - v)
    f = Image.composite(Image.new("RGBA", f.size, (38, 22, 10, 255)), f, esc.point(lambda v: min(255, v * 2)))
    return pousa(recorta(f, m), -2.5)


def pagina_generica(titulo, sub, linhas, aviso, semente, ruled=True):
    """Folha de arquivo rasgada em estilo A (datilografada, pautada): `linhas` = [(margem, texto)]."""
    w, h = 580, 640
    f = papel(w, h, (234, 224, 196), 5, semente)
    d = ImageDraw.Draw(f)
    tinta = (40, 36, 34)
    for yy in range(96, h, 34):
        d.line((20, yy, w - 20, yy), fill=(150, 170, 190, 255), width=1)
    d.line((84, 0, 84, h), fill=(190, 80, 80, 255), width=2)
    d.text((100, 28), titulo, font=fonte(MAQ, 24), fill=tinta)
    d.text((100, 60), sub, font=fonte(MAQ, 16), fill=(90, 80, 70))
    y = 108
    for mg, tx in linhas:
        d.text((24, y), mg, font=fonte(MAQ, 16), fill=(100, 60, 50))
        y = escreve(d, (100, y), tx, fonte(MAQ, 18), tinta, larg=440, esp=1.3) + 14
    d.text((100, 440), aviso, font=fonte(MAO, 34), fill=(130, 24, 18))
    mancha_cafe(f, (120, 560), 50, 70, semente)
    m = borda_irregular(w, h, semente, rasgo=("esq", "baixo"), amp=14, fundo=70, passo=6)
    return pousa(recorta(f, m), 2.5)


def a_fichario():
    return pagina_generica("FICHAS DE EMPRÉSTIMO", "Biblioteca Municipal de Aurora · acervo restrito",
                           [("1979", "\"Sanguis Orchid\". Doado por Geraldo Munch."), ("1987", "Retirado por F. Ghular. Devolvido."),
                            ("1997", "Retirado por F. Ghular. Devolvido."), ("recente", "Confiscado como evidência por Roberto Ghular.")],
                           "ficha arrancada", 71)


def a_diario_bibliotecaria():
    return pagina_generica("DIÁRIO DA JULIANA", "última página",
                           [("", "O delegado levou o Sanguis Orchid como evidência de um caso em aberto."),
                            ("", "Mas o caso não tem relatório, e eu sei o que esse livro diz."),
                            ("", "Preciso contar à Lari.")], "a letra termina aqui", 83)


def a_recorte():
    w, h = 560, 600
    f = papel(w, h, (204, 196, 172), 9, 91)
    d = ImageDraw.Draw(f)
    tinta = (36, 32, 28)
    d.text((24, 20), "A VOZ DE AURORA · 1977", font=fonte(MAQ, 20), fill=(90, 80, 70))
    d.line((24, 52, w - 24, 52), fill=tinta, width=3)
    escreve(d, (24, 66), "OS SETE DESAPARECIDOS", fonte(MAQ, 36), tinta, larg=510, esp=1.15)
    escreve(d, (24, 150), "O mistério que continua a assolar Aurora.", fonte(MAQ, 22), tinta, larg=510, esp=1.25)
    for i in range(9):
        d.line((24, 250 + i * 24, 270 if i < 8 else 180, 250 + i * 24), fill=(120, 112, 100, 255), width=3)
        d.line((300, 250 + i * 24, w - 24, 250 + i * 24), fill=(120, 112, 100, 255), width=3)
    d.text((24, 480), "Última desaparecida: Maria Cabral, nascida em 1º/06/1948.", font=fonte(MAQ, 15), fill=tinta)
    m = borda_irregular(w, h, 93, rasgo=("dir", "baixo", "esq", "cima"), amp=8, fundo=26, passo=7)
    return pousa(recorta(f, m), -2)


def a_livro_cidade():
    """Página do livro \"Aurora, a Cidade das Flores\" com a linha do tempo (roteiro, seção 3: 1817, 1917, 1970). Provisório."""
    w, h = 580, 640
    f = papel(w, h, (226, 214, 184), 6, 101)
    d = ImageDraw.Draw(f)
    tinta = (44, 38, 32)
    d.text((40, 26), "AURORA, A CIDADE DAS FLORES", font=fonte(MAQ, 22), fill=(90, 78, 64))
    d.line((40, 58, w - 40, 58), fill=tinta, width=2)
    y = 82
    for ano, tx in (("1817", "Fundada por imigrantes europeus em busca de uma vida melhor no Brasil."),
                    ("1917", "Recebe o título oficial de Cidade das Flores."),
                    ("1970", "Pede ao Vaticano que canonize Lygia Virgínia do Rosário como a Santa das Flores. O pedido é negado.")):
        d.text((40, y), ano, font=fonte(MAQ, 34), fill=(120, 40, 30))
        y = escreve(d, (150, y + 6), tx, fonte(MAQ, 20), tinta, larg=380, esp=1.3) + 34
    d.text((40, y + 8), "A cidade ficou decepcionada, mas continuou a se chamar", font=fonte(MAQ, 17), fill=tinta)
    d.text((40, y + 32), "Cidade das Flores, com a sua Santa reconhecida por todos.", font=fonte(MAQ, 17), fill=tinta)
    d.rectangle((52, 528, w - 60, 612), fill=(240, 234, 214, 255))  # tira de papel para a nota a lápis
    d.text((70, 538), "carne feita de sangue só se desfaz\ncom o próprio Outro Lado", font=fonte(MAO, 30), fill=(70, 70, 78))
    mancha_cafe(f, (470, 90), 40, 60, 5)
    m = borda_irregular(w, h, 103, rasgo=("esq",), amp=10, fundo=40, passo=6)
    return pousa(recorta(f, m), -1.5)


def a_fotos_simbolo():
    """Fotos da cena da praça que a Letícia levou para casa: o símbolo dentro da árvore sangrando (roteiro, seção 3). Provisório."""
    w, h = 600, 600
    mesa = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = random.Random(131)
    for i, (cx, cy, g, tam) in enumerate(((190, 200, -6, 300), (400, 360, 4, 300))):
        foto = Image.new("RGBA", (tam, int(tam * 0.82)), (46, 56, 48, 255))
        ruido(foto, 7, 40 + i)
        d = ImageDraw.Draw(foto)
        fw, fh = foto.size
        d.rectangle((0, int(fh * 0.7), fw, fh), fill=(34, 40, 30, 255))  # chão
        d.polygon([(fw * 0.44, fh * 0.9), (fw * 0.47, fh * 0.35), (fw * 0.55, fh * 0.35), (fw * 0.6, fh * 0.9)], fill=(24, 20, 18, 255))  # tronco
        d.ellipse((fw * 0.18, fh * 0.02, fw * 0.82, fh * 0.5), fill=(22, 34, 26, 255))  # copa
        zoom = i == 1
        if zoom:  # a segunda foto é um detalhe: o símbolo aberto no tronco
            d.rectangle((0, 0, fw, fh), fill=(26, 20, 18, 255))
            for k in range(0, fw, 22):
                d.line((k, 0, k + r.randint(-6, 6), fh), fill=(40, 32, 28, 255), width=5)
            orquidea(d, fw // 2, int(fh * 0.46), 62, (150, 20, 16, 255))
            for k in range(7):
                x = fw // 2 + r.randint(-70, 70)
                sangue(foto, x, int(fh * 0.5), r.randint(30, 90), 5, semente=k)
        else:
            orquidea(d, int(fw * 0.51), int(fh * 0.56), 22, (150, 20, 16, 255))
            sangue(foto, int(fw * 0.51), int(fh * 0.6), 80, 6, semente=2)
        quadro = Image.new("RGBA", (fw + 24, fh + 60), (232, 228, 216, 255))
        quadro.alpha_composite(foto, (12, 12))
        quadro = quadro.rotate(g, expand=True, resample=Image.BICUBIC)
        mesa.alpha_composite(sombra(quadro), (cx - quadro.width // 2, cy - quadro.height // 2)) if False else None
        mesa.alpha_composite(quadro, (cx - quadro.width // 2, cy - quadro.height // 2))
    d = ImageDraw.Draw(mesa)
    d.text((28, 520), "o símbolo está DENTRO da árvore", font=fonte(MAO, 36), fill=(130, 24, 18))
    return mesa


FUNCOES = {
    "A": {"ficha_desaparecidos": a_ficha, "livro_ocorrencias": a_pagina},
    "B": {"ficha_desaparecidos": b_ficha, "livro_ocorrencias": b_pagina},
    "C": {"ficha_desaparecidos": c_ficha, "livro_ocorrencias": c_pagina},
}

def gerar_jogo(pasta):
    """Imagens finais (modelo A escolhido pelo Léo em 22/11): livro_ocorrencias, fichario, diario_bibliotecaria, mapa_antigo."""
    os.makedirs(pasta, exist_ok=True)
    for nome, fn in (("livro_ocorrencias", a_pagina), ("fichario", a_fichario), ("diario_bibliotecaria", a_diario_bibliotecaria), ("mapa_antigo", a_recorte), ("livro_cidade", a_livro_cidade), ("fotos_simbolo", a_fotos_simbolo)):
        fn().save(os.path.join(pasta, nome + ".png"))
    print("ok jogo", pasta)


if __name__ == "__main__":
    if sys.argv[1] == "jogo":
        gerar_jogo(sys.argv[2])
        sys.exit()
    modelo, pasta = sys.argv[1], sys.argv[2]
    os.makedirs(pasta, exist_ok=True)
    ids = sys.argv[3:] or list(FUNCOES[modelo])
    for i in ids:
        FUNCOES[modelo][i]().save(os.path.join(pasta, f"{i}.png"))
        print("ok", modelo, i)
