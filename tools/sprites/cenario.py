"""Converte folhas de cenário do ChatGPT (fundo magenta) em peças soltas do jogo.

Uso:
  python3 -I tools/sprites/cenario.py chao  saida/ folha.png --prefixo chao --ignorar 4
  python3 -I tools/sprites/cenario.py parede saida/ folha.png --prefixo parede --largura 96
  python3 -I tools/sprites/cenario.py movel saida/ folha.png --nomes estante,mesa,... --altura-heroi 128

Modos:
  chao    cada losango vira um tile exato de 96x48 (`--ignorar N` pula o N-ésimo, em ordem de leitura).
  parede  peças de parede com a mesma escala: a largura média vira `--largura`. Grava também
          `<prefixo>.json` com a âncora (meio da linha de base) de cada peça.
  movel   a primeira figura da folha é o herói de referência (`--altura-heroi` px); os móveis usam a
          mesma escala e saem como `<nome>.png`, com âncora no JSON.
Todos reduzem com média de área e trocam as cores por uma paleta única por folha.
"""
import argparse, json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("modo", choices=["chao", "parede", "movel"])
ap.add_argument("saida")
ap.add_argument("folha")
ap.add_argument("--prefixo", default="peca")
ap.add_argument("--cores", type=int, default=48)
ap.add_argument("--ignorar", type=int, nargs="*", default=[])
ap.add_argument("--largura", type=int, default=96)
ap.add_argument("--altura-heroi", type=int, default=128)
ap.add_argument("--nomes", default="")
ap.add_argument("--ajustes", default="", help="nome=fator, multiplica a escala de um móvel (a folha nem sempre guarda as proporções)")
ap.add_argument("--linhas", type=int, default=2, help="faixas horizontais para a ordem de leitura")
a = ap.parse_args()
os.makedirs(a.saida, exist_ok=True)

arr = np.array(Image.open(a.folha).convert("RGB")).astype(int)
r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
fg = ndimage.binary_opening((np.minimum(r, b) - g) < 40, iterations=1)
lab, k = ndimage.label(ndimage.binary_dilation(fg, iterations=5))
H = arr.shape[0]
figs = []
for i in range(1, k + 1):
    m = fg & (lab == i)
    if m.sum() < 800:
        continue
    ys, xs = np.where(m)
    figs.append({"m": m, "x0": xs.min(), "x1": xs.max(), "y0": ys.min(), "y1": ys.max()})
# Ordem de leitura: por faixa horizontal da folha, depois da esquerda para a direita.
figs.sort(key=lambda f: ((f["y0"] + f["y1"]) // 2 * a.linhas // H, f["x0"]))
print(f"{len(figs)} figuras encontradas")


def recortar(f, escala, tamanho=None):
    """RGBA da figura recortada. A cor sob o fundo vem da borda, para o magenta não vazar na média."""
    box = (f["x0"], f["y0"], f["x1"] + 1, f["y1"] + 1)
    rgb = arr[box[1]:box[3], box[0]:box[2]].astype(np.uint8)
    m = f["m"][box[1]:box[3], box[0]:box[2]]
    idx = ndimage.distance_transform_edt(~m, return_distances=False, return_indices=True)
    rgb = rgb[idx[0], idx[1]]
    w, h = rgb.shape[1], rgb.shape[0]
    novo = tamanho or (max(1, round(w * escala)), max(1, round(h * escala)))
    cor = Image.fromarray(rgb).resize(novo, Image.BOX)
    alfa = Image.fromarray((m * 255).astype(np.uint8)).resize(novo, Image.BOX)
    return np.dstack([np.array(cor), (np.array(alfa) > 127) * 255]).astype(np.uint8)


def quantizar(imgs):
    pix = np.concatenate([i[i[..., 3] > 0][:, :3] for i in imgs])
    pal = Image.fromarray(pix.reshape(-1, 1, 3)).quantize(colors=a.cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = []
    for i in imgs:
        q = np.array(Image.fromarray(i[..., :3]).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB"))
        rgba = np.dstack([q, i[..., 3]])
        rgba[i[..., 3] == 0] = 0
        out.append(rgba)
    return out


def base_y(rgba):
    """Linha de base de uma parede: média do ponto mais baixo nas pontas esquerda e direita."""
    al = rgba[..., 3] > 0
    w = al.shape[1]
    n = max(2, w // 8)
    ys = [np.where(al[:, cols].any(axis=1))[0].max() for cols in (slice(0, n), slice(w - n, w))]
    return float(np.mean(ys))


if a.modo == "chao":
    figs = [f for i, f in enumerate(figs) if i not in a.ignorar]
    imgs = quantizar([recortar(f, 0, (96, 48)) for f in figs])
    for i, im in enumerate(imgs):
        Image.fromarray(im, "RGBA").save(os.path.join(a.saida, f"{a.prefixo}_{i}.png"))
    print("pisos gravados:", len(imgs))
else:
    nomes = [n for n in a.nomes.split(",") if n]
    ancoras = {}
    if a.modo == "parede":
        escala = a.largura / np.mean([f["x1"] - f["x0"] + 1 for f in figs])
        nomes = nomes or [str(i) for i in range(len(figs))]
        itens = list(zip(nomes, figs))
    else:
        heroi, figs = figs[0], figs[1:]
        escala = a.altura_heroi / (heroi["y1"] - heroi["y0"] + 1)
        if len(nomes) != len(figs):
            sys.exit(f"{len(figs)} móveis na folha, mas {len(nomes)} nomes")
        itens = list(zip(nomes, figs))
    print(f"escala {escala:.4f}")
    fatores = {kv.split("=")[0]: float(kv.split("=")[1]) for kv in a.ajustes.split(",") if kv}
    imgs = quantizar([recortar(f, escala * fatores.get(n, 1.0)) for n, f in itens])
    for (nome, _), im in zip(itens, imgs):
        h, w = im.shape[:2]
        # Parede: meio da linha de base. Móvel: centro dos pés, um pouco acima da borda de baixo.
        ancoras[nome] = [w / 2, base_y(im) if a.modo == "parede" else h - h * 0.07]
        Image.fromarray(im, "RGBA").save(os.path.join(a.saida, f"{a.prefixo}_{nome}.png"))
        print(f"{nome}: {w}x{h}")
    with open(os.path.join(a.saida, f"{a.prefixo}.json"), "w") as fh:
        json.dump({n: [round(x, 1) for x in v] for n, v in ancoras.items()}, fh, indent=1)
