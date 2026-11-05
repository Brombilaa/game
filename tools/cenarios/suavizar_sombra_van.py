"""Suaviza a sombra da van pintada nos fundos do parque (Léo, 05/11/2026: sombra sem forma, bokeh maior e mais limpo).
Uso: python3 tools/cenarios/suavizar_sombra_van.py   (roda uma vez sobre os PNG; guarde os originais antes)
Borra só uma elipse em volta do losango escuro sob o para-choque, sem espalhar o preto do para-choque nem o branco da van
(convolução normalizada com peso zero nesses pixels) e com borda esmaecida."""
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

DIR = "assets/sprites/cenario/parque/"
# centro e raios da elipse, em px da imagem estendida; o fundo normal é deslocado pelo canto (pos) do estendido
CENTER, RADII, SIGMA = (490.0, 440.0), (125.0, 62.0), 16.0
EXT_POS = (-84, 86)  # canto da imagem estendida em px do fundo


def soften(path, offset):
    img = Image.open(path)
    a = np.array(img).astype(float)
    rgb = a[..., :3]
    h, w = rgb.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = CENTER[0] + offset[0], CENTER[1] + offset[1]
    d = np.sqrt(((xx - cx) / RADII[0]) ** 2 + ((yy - cy) / RADII[1]) ** 2)
    mask = np.clip((1.0 - d) / 0.5, 0.0, 1.0)  # 1 no miolo, cai a 0 na borda
    lum = rgb.mean(2)
    weight = ((lum > 22) & (lum < 125)).astype(float)  # fora: preto do para-choque e branco da van
    num = np.stack([gaussian_filter(rgb[..., c] * weight, SIGMA) for c in range(3)], -1)
    den = np.maximum(gaussian_filter(weight, SIGMA), 1e-3)[..., None]
    soft = num / den
    m = (mask * weight)[..., None]
    a[..., :3] = rgb * (1 - m) + soft * m
    Image.fromarray(np.clip(a, 0, 255).astype("uint8"), img.mode).save(path)


soften(DIR + "fundo_estendido.png", (0, 0))
soften(DIR + "fundo.png", (EXT_POS[0], EXT_POS[1]))
