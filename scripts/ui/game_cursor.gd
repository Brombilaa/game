class_name GameCursor
extends RefCounted
# Mouse do jogo em pixel art, desenhado por código (sem arquivo de imagem): seta dourada com contorno
# escuro e uma mira vermelha para quando o cursor está sobre um inimigo atacável.
# Cada pixel do desenho vale SCALE pixels reais, para acompanhar a ampliação 2x da tela interna.

enum Kind { ARROW, ATTACK }

const SCALE := 2
# '#' contorno, 'o' preenchimento, 'h' brilho, 'r' vermelho; '.' transparente.
const ARROW_ROWS := [
	"#...........",
	"##..........",
	"#o#.........",
	"#oo#........",
	"#ooo#.......",
	"#oooo#......",
	"#ooooo#.....",
	"#oooooo#....",
	"#ooooooo#...",
	"#oooooooo#..",
	"#ooooo#####.",
	"#oo#oo#.....",
	"#o#.#oo#....",
	"##..#oo#....",
	"#....#oo#...",
	".....#oo#...",
	"......##....",
]
const ARROW_HOTSPOT := Vector2i(0, 0)
# Mira: sem contorno no desenho; `texture` cerca os pixels vermelhos de escuro.
const ATTACK_ROWS := [
	"......r......",
	"......r......",
	"......r......",
	"......r......",
	".............",
	".............",
	"rrrr..r..rrrr",
	".............",
	".............",
	"......r......",
	"......r......",
	"......r......",
	"......r......",
]
const ATTACK_HOTSPOT := Vector2i(6, 6)
const COLORS := {
	"#": Color(0.07, 0.05, 0.04),
	"o": Color(0.85, 0.7, 0.33),
	"h": Color(1.0, 0.92, 0.6),
	"r": Color(0.86, 0.2, 0.2),
}

static var _cache := {}


static func texture(kind: Kind) -> ImageTexture:
	if not _cache.has(kind):
		var rows: Array = ATTACK_ROWS if kind == Kind.ATTACK else ARROW_ROWS
		var w: int = String(rows[0]).length()
		var img := Image.create(w * SCALE, rows.size() * SCALE, false, Image.FORMAT_RGBA8)
		var outline := kind == Kind.ATTACK
		for y in rows.size():
			for x in w:
				var ch := String(rows[y])[x]
				if outline and ch == "." and _touches(rows, x, y, "r"):
					ch = "#"
				if not COLORS.has(ch):
					continue
				var color: Color = COLORS[ch]
				if ch == "o" and y < 5:
					color = COLORS["h"]  # topo da seta mais claro: um brilho barato
				for dy in SCALE:
					for dx in SCALE:
						img.set_pixel(x * SCALE + dx, y * SCALE + dy, color)
		_cache[kind] = ImageTexture.create_from_image(img)
	return _cache[kind]


static func _touches(rows: Array, x: int, y: int, ch: String) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var yy := y + dy
			var xx := x + dx
			if yy >= 0 and yy < rows.size() and xx >= 0 and xx < String(rows[yy]).length() and String(rows[yy])[xx] == ch:
				return true
	return false


static func hotspot(kind: Kind) -> Vector2:
	return Vector2(ATTACK_HOTSPOT if kind == Kind.ATTACK else ARROW_HOTSPOT) * SCALE


static func apply(kind: Kind) -> void:
	Input.set_custom_mouse_cursor(texture(kind), Input.CURSOR_ARROW, hotspot(kind))
