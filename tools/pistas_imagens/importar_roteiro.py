#!/usr/bin/env python3
"""Imagens de pista do Apêndice B do roteiro (Léo): as 6 fichas dos desaparecidos e as 4 páginas rasgadas do livro de
orquídeas, reduzidas para o jogo, mais a ficha da Lisandra de Sá (a sétima, que o Léo não mandou), refeita no mesmo
formato das outras a partir da ficha do Bruno com os textos trocados (provisório, Claude 22/11/2026).
Uso: python3 tools/pistas_imagens/importar_roteiro.py <pasta historia> <pasta de saída>
Saída: ficha_01..07.png (ordem do roteiro; a 07 é a Lisandra) e pagina_*.png, com 1400 px de largura."""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
import numpy as np

LARG = 1400
FICHAS = ["bruno_rouxinol", "jurema_couto", "marcos_paixao", "ramiro_turi", "ruth_santos", "selena_schaefer"]
PAGINAS = {"caladenia_purpura": "purpura", "caladenia_viridis": "viridis", "caladenia_flavum": "flavum", "parasitagem": "parasitagem"}
SERIFA = "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf"

# Lisandra de Sá (provisório): idade e aniversário do roteiro (38 anos, nascida em 1987, 1º de junho como a Maria
# Cabral); o resto (pele, olhos, cabelo, altura, peso) é do Claude. Sem revelar o culpado.
LISANDRA = dict(nome="Lisandra de Sá", pele="Parda", sexo="Feminino", nasc="01/06/1987", olhos="Castanhos",
                cabelos="Ruivo - Ombros", altura="1.68", peso="64kg", obs="Sardas",
                visto="Praça de Aurora, 21h45",
                info="Lisandra trabalhava numa farmácia da cidade e voltava a pé do trabalho, cruzando a praça vazia. Não chegou em casa. Perto do banco da praça, a polícia achou manchas de sangue e sinais de luta.")


def reduzir(im):
    return im.convert("RGBA").resize((LARG, round(LARG * im.height / im.width)), Image.LANCZOS)


def apagar(img, caixa, tam=23):
    """Apaga o texto escuro de uma região (caixa em px de um quadro de 900 de largura) refazendo o papel, com o brilho
    do papel em volta e a borda esmaecida."""
    k = img.width / 900.0
    x0, y0, x1, y1 = [int(v * k) for v in caixa]
    reg = img.crop((x0, y0, x1, y1)).convert("RGB")
    claro = reg.filter(ImageFilter.MaxFilter(tam | 1)).filter(ImageFilter.GaussianBlur(2 * k))
    em_volta = np.asarray(img.crop((x0 - 14, y0 - 14, x1 + 14, y1 + 14)).convert("L")).astype(float)
    papel = em_volta[(em_volta > 120) & (em_volta < 235)]
    arr = np.asarray(claro).astype(float)
    arr *= np.median(papel) / max(np.median(arr.mean(axis=2)), 1.0)
    arr += np.random.RandomState(7).normal(0, 2.2, (y1 - y0, x1 - x0, 1))
    novo = Image.fromarray(np.clip(arr, 0, 255).astype("uint8")).convert("RGBA")
    m = Image.new("L", novo.size, 0)
    ImageDraw.Draw(m).rectangle((0, 0, novo.width, novo.height), fill=255)
    img.paste(novo, (x0, y0), m)


def escrever(img, x, y, txt, tam, cor=(58, 56, 54, 255)):
    k = img.width / 900.0
    d = ImageDraw.Draw(img)
    d.text((x * k, y * k), txt, font=ImageFont.truetype(SERIFA, int(tam * k)), fill=cor)


def quebra(txt, fnt, larg):
    out, at = [], ""
    for p in txt.split():
        t = (at + " " + p).strip()
        if fnt.getlength(t) <= larg:
            at = t
        else:
            out.append(at)
            at = p
    return out + [at] if at else out


def lisandra(bruno):
    img = bruno.copy()
    for caixa in [(70, 146, 372, 178), (396, 146, 520, 178), (544, 146, 676, 178), (684, 146, 842, 178),
                  (70, 234, 220, 264), (216, 234, 480, 264), (492, 234, 572, 264), (590, 234, 660, 264), (684, 234, 842, 264),
                  (70, 302, 840, 332), (72, 372, 854, 458)]:
        apagar(img, caixa)
    L = LISANDRA
    escrever(img, 82, 148, L["nome"], 20)
    escrever(img, 410, 148, L["pele"], 20)
    escrever(img, 553, 148, L["sexo"], 20)
    escrever(img, 692, 148, L["nasc"], 20)
    escrever(img, 82, 236, L["olhos"], 20)
    escrever(img, 225, 236, L["cabelos"], 20)
    escrever(img, 505, 236, L["altura"], 20)
    escrever(img, 600, 236, L["peso"], 20)
    escrever(img, 695, 236, L["obs"], 20)
    escrever(img, 82, 304, L["visto"], 20)
    k = img.width / 900.0
    fnt = ImageFont.truetype(SERIFA, int(19 * k))
    y = 376
    for ln in quebra(L["info"], fnt, 740 * k):
        escrever(img, 86, y, ln, 19)
        y += 23
    return img


if __name__ == "__main__":
    origem, saida = sys.argv[1], sys.argv[2]
    os.makedirs(saida, exist_ok=True)
    fichas = []
    for i, nome in enumerate(FICHAS, 1):
        im = reduzir(Image.open(os.path.join(origem, "fichas-desaparecidos", f"ficha_{nome}.png")))
        fichas.append(im)
        im.save(os.path.join(saida, f"ficha_{i:02d}.png"), optimize=True)
    lisandra(fichas[0]).save(os.path.join(saida, "ficha_07.png"), optimize=True)
    for nome, curto in PAGINAS.items():
        reduzir(Image.open(os.path.join(origem, "paginas-rasgadas", f"pagina_{nome}.png"))).save(os.path.join(saida, f"pagina_{curto}.png"), optimize=True)
    print("ok", saida)
