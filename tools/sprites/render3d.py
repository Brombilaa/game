"""Converte as folhas renderizadas em 3D (pixel art, células de 176 px, 5 filas S, SE, E, NE, N)
em folhas do jogo: quadros de 192 px com os pés em (96, 179).

    python3 -I tools/sprites/render3d.py nikolai pasta_das_folhas assets/sprites/personagens

Sai `<prefixo>_<dir>.png` (8 quadros: 2 parado e 6 andando, a partir de idle e walk) e uma fila de quadros por
animação extra em `<prefixo>_anim_<nome>_<dir>.png`. Para se uma animação encosta na borda da célula (corte).
"""
import sys
from pathlib import Path
from PIL import Image

CELL = 176
FRAME = 192
OFFSET = ((FRAME - CELL) // 2, 27)  # pés da célula (linha 152) vão para a linha 179 do quadro
DIRS = ["s", "se", "e", "ne", "n"]
EXTRAS = ["pistol_shoot", "rifle_fire", "punch_cross", "kick", "hit", "death", "getup"]


def cells(sheet: Image.Image, row: int, n: int) -> list:
    return [sheet.crop((k * CELL, row * CELL, (k + 1) * CELL, (row + 1) * CELL)) for k in range(n)]


def to_frame(cell: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    out.paste(cell, OFFSET, cell)
    return out


def touches_border(cell: Image.Image) -> bool:
    a = cell.getchannel("A")
    w, h = a.size
    return any(a.crop(box).getbbox() for box in [(0, 0, w, 1), (0, h - 1, w, h), (0, 0, 1, h), (w - 1, 0, w, h)])


def row_sheet(frames: list) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sheet.paste(f, (k * FRAME, 0))
    return sheet


def main() -> None:
    prefix, src, dst = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    cut = []
    idle = Image.open(src / "idle_folha.png").convert("RGBA")
    walk = Image.open(src / "walk_folha.png").convert("RGBA")
    for r, d in enumerate(DIRS):
        picks = [cells(idle, r, 6)[i] for i in (0, 3)] + [cells(walk, r, 12)[i] for i in (0, 2, 4, 6, 8, 10)]
        row_sheet([to_frame(c) for c in picks]).save(dst / f"{prefix}_{d}.png")
    for anim in EXTRAS:
        sheet = Image.open(src / f"{anim}_folha.png").convert("RGBA")
        n = sheet.width // CELL
        for r, d in enumerate(DIRS):
            cs = cells(sheet, r, n)
            cut += [f"{anim} {d} quadro {k}" for k, c in enumerate(cs) if touches_border(c)]
            row_sheet([to_frame(c) for c in cs]).save(dst / f"{prefix}_anim_{anim}_{d}.png")
    print("quadros cortados:", cut if cut else "nenhum")


if __name__ == "__main__":
    main()
