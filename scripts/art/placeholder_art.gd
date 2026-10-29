class_name PlaceholderArt
extends RefCounted
# Arte provisória gerada por código, enquanto não há sprites desenhados.
# Segue docs/direcao-visual.md: vista 3/4 de cima, personagem em quadro de 32×48,
# tile de 16×16, 4 direções e paleta fechada e escura (DEC-2026-10-29-01..05).
# Gerar em código evita binários no Git LFS; troca por PNG quando houver arte final.

enum Dir { SOUTH, NORTH, EAST, WEST }

const FRAME_SIZE := Vector2i(32, 48)
const TILE_SIZE := 16
# Ponto do quadro que fica sobre a posição da unidade (meio dos pés).
const PIVOT := Vector2(16, 46)
# Quadros por direção: parado, passo com a perna esquerda, passo com a direita.
const FRAMES := 3

# Paleta de teste (DEC-2026-10-29-04). Cópia para editores em assets/palettes/paleta_teste.gpl.
const PALETTE := {
	"contorno": Color8(13, 11, 14),
	"camisa": Color8(20, 18, 22),
	"casaco_escuro": Color8(30, 26, 31),
	"casaco": Color8(44, 38, 48),
	"casaco_claro": Color8(59, 52, 64),
	"cabelo": Color8(42, 29, 22),
	"pele_sombra": Color8(138, 95, 72),
	"pele": Color8(185, 138, 106),
	"couro": Color8(90, 52, 32),
	"couro_claro": Color8(122, 74, 44),
	"metal": Color8(110, 106, 106),
	"chao_escuro": Color8(27, 23, 20),
	"chao": Color8(38, 32, 25),
	"chao_claro": Color8(49, 42, 33),
	"parede": Color8(42, 39, 48),
	"parede_topo": Color8(69, 64, 76),
	"sangue_escuro": Color8(74, 20, 22),
	"sangue": Color8(107, 29, 29),
	"sangue_claro": Color8(140, 42, 42),
	"destaque": Color8(201, 162, 74),
}

# Variantes trocam as cores do casaco: agente (preto), cultista (vermelho), atirador (cinza).
const VARIANTS := {
	"agente": {},
	"cultista": {"casaco_escuro": "sangue_escuro", "casaco": "sangue", "casaco_claro": "sangue_claro"},
	"atirador": {"casaco_escuro": "parede", "casaco": "parede_topo", "casaco_claro": "metal"},
}

static var _cache := {}


static func color(name: String) -> Color:
	return PALETTE[name]


static func dir_from_vector(v: Vector2) -> Dir:
	if absf(v.x) > absf(v.y):
		return Dir.EAST if v.x > 0.0 else Dir.WEST
	return Dir.SOUTH if v.y >= 0.0 else Dir.NORTH


static func character_texture(variant: String, dir: Dir, frame: int) -> Texture2D:
	var key := "%s:%d:%d" % [variant, dir, frame]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(character_image(variant, dir, frame))
	return _cache[key]


static func floor_texture() -> Texture2D:
	if not _cache.has("chao"):
		_cache["chao"] = ImageTexture.create_from_image(floor_image())
	return _cache["chao"]


static func character_image(variant: String, dir: Dir, frame: int) -> Image:
	var img := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	var p := _Painter.new(img, VARIANTS.get(variant, {}))
	if dir == Dir.WEST:
		_paint_side(p, frame)
		img.flip_x()
	elif dir == Dir.EAST:
		_paint_side(p, frame)
	else:
		_paint_front(p, frame, dir == Dir.NORTH)
	_outline(img)
	return img


# Tábuas de madeira escura com emendas alternadas.
static func floor_image() -> Image:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(color("chao"))
	for row in 4:
		var y := row * 4
		for x in TILE_SIZE:
			img.set_pixel(x, y, color("chao_escuro"))
		img.set_pixel(((row % 2) * 8 + 3) % TILE_SIZE, y + 1, color("chao_escuro"))
		img.set_pixel(((row % 2) * 8 + 3) % TILE_SIZE, y + 2, color("chao_escuro"))
		img.set_pixel((row * 5 + 10) % TILE_SIZE, y + 2, color("chao_claro"))
	return img


# Frente (sul) ou costas (norte). Luz vem de cima à esquerda.
static func _paint_front(p: _Painter, frame: int, back: bool) -> void:
	var lift_left := 2 if frame == 1 else 0
	var lift_right := 2 if frame == 2 else 0
	# Pernas com calça escura e sapatos.
	p.rect(11, 38, 4, 7 - lift_left, "camisa")
	p.rect(17, 38, 4, 7 - lift_right, "camisa")
	p.rect(10, 45 - lift_left, 5, 2, "contorno")
	p.rect(17, 45 - lift_right, 5, 2, "contorno")
	# Sobretudo: corpo, barra mais larga e ombros.
	p.rect(9, 16, 14, 22, "casaco")
	p.rect(8, 30, 16, 9, "casaco")
	p.rect(9, 16, 2, 22, "casaco_claro")
	p.rect(21, 16, 2, 23, "casaco_escuro")
	# Braços e mãos.
	p.rect(6, 18, 3, 14, "casaco_claro")
	p.rect(23, 18, 3, 14, "casaco_escuro")
	p.rect(6, 32, 3, 2, "pele_sombra" if back else "pele")
	p.rect(23, 32, 3, 2, "pele_sombra")
	if back:
		p.rect(15, 17, 2, 21, "casaco_escuro")  # costura das costas
		p.rect(12, 27, 8, 2, "casaco_escuro")  # meia-cinta
		p.rect(12, 27, 1, 1, "metal")
		p.rect(19, 27, 1, 1, "metal")
	else:
		p.rect(14, 16, 4, 11, "camisa")  # abertura do casaco
		p.rect(12, 16, 2, 4, "casaco_claro")  # gola
		p.rect(18, 16, 2, 4, "casaco_escuro")
		p.rect(10, 26, 12, 1, "contorno")  # cinto
		p.rect(15, 26, 2, 1, "metal")
		for i in 9:  # alça do coldre na diagonal
			p.rect(11 + i, 17 + i, 1, 1, "couro_claro")
		p.rect(19, 24, 3, 5, "couro")  # coldre
		p.rect(19, 24, 1, 5, "couro_claro")
	# Pescoço, cabeça e boina.
	p.rect(14, 15, 4, 1, "pele_sombra")
	if back:
		p.rect(11, 8, 10, 7, "cabelo")
	else:
		p.rect(11, 8, 10, 7, "pele")
		p.rect(19, 8, 2, 7, "pele_sombra")
		p.rect(11, 8, 1, 4, "cabelo")
		p.rect(20, 8, 1, 4, "cabelo")
		p.rect(13, 10, 2, 1, "contorno")  # olhos
		p.rect(17, 10, 2, 1, "contorno")
		p.rect(13, 12, 6, 1, "cabelo")  # bigode
	p.rect(10, 3, 12, 5, "casaco")
	p.rect(11, 2, 10, 1, "casaco")
	p.rect(10, 3, 4, 2, "casaco_claro")
	p.rect(9, 7, 14, 1, "casaco_escuro")  # aba


# Perfil voltado para leste; oeste é o espelho.
static func _paint_side(p: _Painter, frame: int) -> void:
	var stride := 0 if frame == 0 else (2 if frame == 1 else -2)
	# Perna de trás (mais escura) e da frente.
	p.rect(14 - stride, 38, 4, 7, "contorno")
	p.rect(14 - stride, 45, 6, 2, "contorno")
	p.rect(15 + stride, 38, 4, 7, "camisa")
	p.rect(15 + stride, 45, 6, 2, "contorno")
	# Sobretudo de lado.
	p.rect(11, 16, 10, 22, "casaco")
	p.rect(10, 30, 12, 9, "casaco")
	p.rect(11, 16, 2, 23, "casaco_claro")
	p.rect(19, 16, 2, 22, "casaco_escuro")
	p.rect(19, 18, 2, 9, "camisa")  # frente aberta
	p.rect(18, 24, 3, 5, "couro")  # coldre
	p.rect(18, 24, 1, 5, "couro_claro")
	# Braço na frente do corpo.
	p.rect(14, 18, 4, 14, "casaco_escuro")
	p.rect(15, 32, 3, 2, "pele")
	# Cabeça de perfil: nuca com cabelo, rosto à direita.
	p.rect(14, 15, 4, 1, "pele_sombra")
	p.rect(12, 8, 9, 7, "pele")
	p.rect(12, 8, 4, 7, "cabelo")
	p.rect(21, 11, 1, 2, "pele")  # nariz
	p.rect(18, 10, 2, 1, "contorno")
	p.rect(18, 12, 3, 1, "cabelo")
	p.rect(11, 3, 11, 5, "casaco")
	p.rect(12, 2, 8, 1, "casaco")
	p.rect(11, 3, 4, 2, "casaco_claro")
	p.rect(14, 7, 10, 1, "casaco_escuro")  # aba para a frente


# Contorno de 1 px em volta da silhueta, como na referência.
static func _outline(img: Image) -> void:
	var src := img.duplicate() as Image
	var edge := color("contorno")
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() and src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, edge)
					break


class _Painter:
	var img: Image
	var swaps: Dictionary

	func _init(target: Image, color_swaps: Dictionary) -> void:
		img = target
		swaps = color_swaps

	func rect(x: int, y: int, w: int, h: int, name: String) -> void:
		if w > 0 and h > 0:
			img.fill_rect(Rect2i(x, y, w, h), PlaceholderArt.color(swaps.get(name, name)))
