class_name ItemIcons
extends RefCounted
# Ícones dos itens e ações: arte pintada do Léo (ChatGPT, 30/10/2026, recortada em 64×64 por
# tools/sprites/icones_acoes.py) e, para quem ainda não tem arte, pixel art provisório.
# Usado pela barra de combate e pelo inventário.

const ART_SIZE := 32.0  # lado do ícone pintado em pixels da tela (os 64 px da arte na janela de 1920)
const PIXEL := 2.0  # cada pixel do pixel art vale 2 pixels da tela

# Ícones em pixel art, 16 colunas. o contorno, a/b/c metal claro, médio e escuro, w madeira,
# g ouro, r carmesim, y areia. Ponto é transparente; o desenho é centralizado na casa.
const ICON_COLORS := {
	"o": Color(0.05, 0.035, 0.03), "a": Color(0.8, 0.76, 0.68), "b": Color(0.52, 0.48, 0.43),
	"c": Color(0.3, 0.27, 0.24), "w": Color(0.47, 0.28, 0.15), "g": Color(0.84, 0.68, 0.36),
	"r": Color(0.74, 0.11, 0.13), "y": Color(0.88, 0.72, 0.42),
}
# Ícones pintados do Léo (ChatGPT, 30/10/2026), recortados em 64×64 por tools/sprites/icones_acoes.py.
# Quem não tem arte ainda (fuzil, soco) usa o pixel art de PIXEL_ROWS.
const ART := {
	"pistola": preload("res://assets/sprites/ui/acoes/pistola.png"),
	"escopeta": preload("res://assets/sprites/ui/acoes/escopeta.png"),
	"espada": preload("res://assets/sprites/ui/acoes/espada.png"),
	"kit": preload("res://assets/sprites/ui/acoes/kit.png"),
	"atrasar": preload("res://assets/sprites/ui/acoes/atrasar.png"),  # relógio de bolso
	"ampulheta": preload("res://assets/sprites/ui/acoes/ampulheta.png"),  # fim do turno
}
const PIXEL_ROWS := {
	"pistola": [
		"..oooooooooooo..",
		".oaaaaaaaaaabbo.",
		".obbbbbbbbbbbo..",
		"..oooocbbboooo..",
		".....ocbbo......",
		"....owwoo.......",
		"...owwwo........",
		"..owwwwo........",
		"..owwwo.........",
		"..oooo..........",
	],
	"escopeta": [
		"oooo............",
		"owwwoooooooooooo",
		"owwwwbbbbaaaaaao",
		".owwwbbbbbbbbbbo",
		"..oowoocbboooooo",
		"....o..occo.....",
		"........oo......",
	],
	"fuzil_precisao": [
		".....oooooo.....",
		".....oaaabo.....",
		"oooo..oooo......",
		"owwwoooooooooooo",
		"owwwwbbbbbbbaaao",
		".owwwbbbbbbbbbbo",
		"..oowoocbboooooo",
		"....o..occo.....",
		"........oo......",
	],
	"espada": [
		".............oo.",
		"............oao.",
		"...........oaco.",
		"..........oaco..",
		".........oaco...",
		"........oaco....",
		".......oaco.....",
		"..o...oaco......",
		"..oo.oaco.......",
		"...ogaco........",
		"....ogo.........",
		"...owogo........",
		"..owo.oo........",
		".owo............",
		".oo.............",
	],
	"soco": [
		"....oooooooo....",
		"...oaaoaaoaao...",
		"...oaaoaaoaao...",
		"..ooaaoaaoaao...",
		"..oaooooooooo...",
		"..oaaaaaaaaaco..",
		"..oaaaaaaaaaco..",
		"..obaaaaaaacco..",
		"...obbbbbbbco...",
		"....obbbbbco....",
		"....ooooooo.....",
	],
	"kit": [
		".....oooooo.....",
		".....o....o.....",
		"..oooooooooooo..",
		"..oaaaaaaaaaao..",
		"..oaaaarraaaao..",
		"..oaaaarraaaao..",
		"..oarrrrrrrrao..",
		"..oarrrrrrrrao..",
		"..oaaaarraaaao..",
		"..oaaaarraaaao..",
		"..obbbbbbbbbbo..",
		"..oooooooooooo..",
	],
	"atrasar": [
		"...gggggggggg...",
		"...oooooooooo...",
		"....oaaaaaao....",
		"....oyyyyyyo....",
		".....oyyyyo.....",
		"......oyyo......",
		".......oo.......",
		"......oaao......",
		".....oaaaao.....",
		"....oaayyaao....",
		"....oyyyyyyo....",
		"...oooooooooo...",
		"...gggggggggg...",
	],
	"bandagem": [
		"................",
		"...oooooooooo...",
		"..oaaaaaaaaaao..",
		"..oayyyyyyyyao..",
		"..oaarrrrrraao..",
		"..oayyyyyyyyao..",
		"..oaaaaaaaaaao..",
		"..obbbbbbbbbbo..",
		"...oooooooooo...",
	],
	"antidoto": [
		".....oooooo.....",
		".....obbbbo.....",
		".....oaaaao.....",
		"....oaaaaaao....",
		"...oayyyyyyao...",
		"...oayggggyao...",
		"...oayggggyao...",
		"...oayggggyao...",
		"...oayyyyyyao...",
		"....oaaaaaao....",
		".....oooooo.....",
	],
	"colete_leve": [
		"..ooo......ooo..",
		".obbbo....obbbo.",
		".obbbbooooobbbo.",
		".obbbbbbbbbbbbo.",
		".obbbbbbbbbbbbo.",
		"..obbcbbbbcbbo..",
		"..obbcbbbbcbbo..",
		"..obbbbbbbbbbo..",
		"..obbbbbbbbbbo..",
		"...oooooooooo...",
	],
	"colete_pesado": [
		"..ooo......ooo..",
		".occco....occco.",
		".occcccoooccccc.",
		".occcccccccccco.",
		".occgcccccccgco.",
		"..occccggcccco..",
		"..occcccccccco..",
		"..occcgcccgcco..",
		"..occcccccccco..",
		"...oooooooooo...",
	],
	"curativo": [
		"................",
		"..oooooooooooo..",
		".oyyyyyyyyyyyyo.",
		".oyyyrrrrrryyyo.",
		".oyyyrrrrrryyyo.",
		".oyyyyyyyyyyyyo.",
		"..oooooooooooo..",
	],
	"componente_ritual": [
		"......oooo......",
		".....orrrro.....",
		"....orrrrrro....",
		"...orraaaarro...",
		"...orraaaarro...",
		"....orrrrrro....",
		".....orrrro.....",
		"......oooo......",
	],
}


# Ids das tabelas de dados que usam o ícone de outro id.
const ALIASES := {"kit_primeiros_socorros": "kit", "colete": "colete_leve"}


static func has_icon(id: String) -> bool:
	id = ALIASES.get(id, id)
	return ART.has(id) or PIXEL_ROWS.has(id)


# Desenha o ícone `id` centralizado em `r`, em `canvas`. `size` só vale para a arte pintada.
# Indisponível: sem cor e escurecido. Id sem ícone: um quadrado de pixel art genérico.
static func draw(canvas: CanvasItem, r: Rect2, id: String, enabled := true, size := ART_SIZE) -> void:
	id = ALIASES.get(id, id)
	if ART.has(id):
		var at := (r.get_center() - Vector2(size, size) * 0.5).round()
		canvas.draw_texture_rect(ART[id], Rect2(at, Vector2(size, size)), false, Color.WHITE if enabled else Color(0.42, 0.4, 0.38, 0.8))
	else:
		draw_rows(canvas, r, PIXEL_ROWS.get(id, PIXEL_ROWS["soco"]), enabled)


# Um quadrado por pixel, alinhado à grade da tela para os contornos ficarem nítidos.
static func draw_rows(canvas: CanvasItem, r: Rect2, rows: Array, enabled: bool, swap := {}) -> void:
	var w := 0
	for row in rows:
		w = maxi(w, str(row).length())
	var origin := (r.get_center() - Vector2(w, rows.size()) * PIXEL * 0.5).round()
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var color: Color = swap.get(ch, ICON_COLORS[ch])
			if not enabled:
				var v := color.get_luminance() * 0.55
				color = Color(v, v * 0.95, v * 0.9)
			canvas.draw_rect(Rect2(origin + Vector2(x, y) * PIXEL, Vector2.ONE * PIXEL), color)
