"""Converte folhas de poses do ChatGPT (fundo magenta) em folhas de sprites do jogo.

Uso:
  python3 -I tools/sprites/converter.py saida/ se=nikolai_se_raw.png e=nikolai_e_raw.png ... \
      --prefixo nikolai --altura 128 --quadro 192 --pes 12 --cores 32

Cada entrada é `direcao=arquivo.png`. Para cada uma grava `<prefixo>_<direcao>.png` com os
8 quadros em fila (2 parado, 6 andando). Passos: remove o magenta, separa as figuras, alinha
os pés, reduz com média de área e troca as cores por UMA paleta compartilhada por todas as
direções. A escala também é única: a altura do quadro parado (média dos dois primeiros) de
todas as direções vira `--altura`, para o personagem não mudar de tamanho ao girar.
"""
import argparse, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("saida")
ap.add_argument("entradas", nargs="+", help="direcao=arquivo.png")
ap.add_argument("--prefixo", required=True)
ap.add_argument("--altura", type=int, default=96)
ap.add_argument("--cores", type=int, default=32)
ap.add_argument("--quadro", type=int, default=144)
ap.add_argument("--pes", type=int, default=8, help="folga entre os pés e a borda de baixo do quadro")
ap.add_argument("--colunas", type=int, default=4)
ap.add_argument("--linhas", type=int, default=2)
a = ap.parse_args()
os.makedirs(a.saida, exist_ok=True)


def separar(caminho):
    """Devolve as figuras da folha: máscara, topo, base e centro do tronco, em ordem de leitura."""
    arr = np.array(Image.open(caminho).convert("RGB")).astype(int)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    fg = (np.minimum(r, b) - g) < 40  # o personagem nunca tem min(r,b) bem acima de g
    fg = ndimage.binary_opening(fg, iterations=1)
    H, W = fg.shape
    cw, ch = W // a.colunas, H // a.linhas
    figs = []
    for row in range(a.linhas):
        for col in range(a.colunas):
            cell = np.zeros_like(fg)
            cell[row * ch:(row + 1) * ch, col * cw:(col + 1) * cw] = True
            cell &= fg
            lab, k = ndimage.label(ndimage.binary_dilation(cell, iterations=6))
            if k == 0:
                sys.exit(f"{caminho}: célula {row},{col} vazia")
            sizes = ndimage.sum(cell, lab, range(1, k + 1))
            mask = cell & np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 400])
            ys, xs = np.where(mask)
            y0, y1 = ys.min(), ys.max()
            # Âncora horizontal: centro da metade de cima, estável mesmo com o casaco balançando.
            cx = np.where(mask[y0:y0 + (y1 - y0) // 2, :])[1].mean()
            figs.append((mask, y0, y1, cx))
    return arr, figs


folhas = {}
for e in a.entradas:
    nome, _, caminho = e.partition("=")
    folhas[nome] = separar(caminho)

# Escala única: altura de origem do quadro parado, média entre todas as direções.
idle = [np.mean([f[2] - f[1] + 1 for f in figs[:2]]) for _, figs in folhas.values()]
for nome, h in zip(folhas, idle):
    print(f"{nome}: altura parado na origem {h:.0f}px")
ref_h = float(np.mean(idle))
if max(idle) / min(idle) > 1.08:
    print("aviso: o ChatGPT desenhou direções em escalas diferentes; usei a média", file=sys.stderr)
escala = a.altura / ref_h
print(f"escala {escala:.4f} (altura de origem {ref_h:.0f}px -> {a.altura}px)")

quadros = {}
for nome, (arr, figs) in folhas.items():
    lst = []
    for mask, y0, y1, cx in figs:
        rgba = np.zeros(mask.shape + (4,), np.uint8)
        rgba[..., :3] = arr.astype(np.uint8)
        rgba[..., 3] = (mask * 255).astype(np.uint8)
        lado = int(round(a.quadro / escala))
        tela = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
        ox = int(round(lado / 2 - cx))
        oy = int(round(lado - a.pes / escala - 1 - y1))  # pés `--pes` px acima da borda de baixo
        tela.paste(Image.fromarray(rgba), (ox, oy))
        lst.append(tela.resize((a.quadro, a.quadro), Image.BOX))  # média de área
    quadros[nome] = lst

# Paleta única de todas as direções: só pixels opacos entram.
pix = np.concatenate([np.array(f)[np.array(f)[..., 3] > 127][:, :3] for lst in quadros.values() for f in lst])
pal = Image.fromarray(pix.reshape(-1, 1, 3).astype(np.uint8)).quantize(
    colors=a.cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)

usadas = set()
for nome, lst in quadros.items():
    folha = Image.new("RGBA", (a.quadro * len(lst), a.quadro), (0, 0, 0, 0))
    for i, f in enumerate(lst):
        fa = np.array(f)
        alfa = fa[..., 3] > 127
        q = np.array(Image.fromarray(fa[..., :3]).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB"))
        rgba = np.dstack([q, (alfa * 255).astype(np.uint8)])
        rgba[~alfa] = 0
        usadas |= set(map(tuple, rgba[alfa][:, :3]))
        folha.paste(Image.fromarray(rgba, "RGBA"), (i * a.quadro, 0))
    destino = os.path.join(a.saida, f"{a.prefixo}_{nome}.png")
    folha.save(destino)
    print("gravado", destino)
print("cores na paleta:", len(usadas))
