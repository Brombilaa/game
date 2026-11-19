class_name ControlesCaderno
extends Control
# Mapa de controles nas Opções (Léo, 19/11/2026): só a visão do teclado e do mouse, numa página do caderno de campo
# (mesma placa escura, bronze, dourado e teclas do Diário e do inventário). Cada tecla usada mostra a função
# embaixo do rótulo e a cor diz o grupo. Só mostra; não remapeia.
# As teclas dos itens de combate vêm de RoomItems.KEY_LABELS e as dos rituais de RoomActionBar.RITUAL_KEYS, então
# o mapa acompanha qualquer troca feita no código. Quem mudar outra tecla do jogo deve atualizar `mapa()`.

const GOLD := Color(0.839, 0.678, 0.361)
const BRONZE := Color(0.353, 0.255, 0.149)
const PLATE := Color(0.05, 0.037, 0.03, 0.97)
const TEXT := Color(0.91, 0.87, 0.79)
const MUTED := Color(0.66, 0.6, 0.49)
const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const TEX_KEY := preload("res://assets/sprites/ui/inv/tecla.png")

# Grupos: cor da tecla e nome na legenda.
const CATS := {
	"mover": [Color(0.839, 0.678, 0.361), "Explorar"],
	"painel": [Color(0.45, 0.66, 0.78), "Painéis e sistema"],
	"combate": [Color(0.86, 0.32, 0.28), "Combate"],
	"uso": [Color(0.66, 0.5, 0.82), "Itens e rituais"],
}
const KEY := 40.0
const GAP := 3.0
const PAD := 18.0
const TITLE_H := 34.0
const PAGE_W := 840.0
const PAGE_H := 372.0

# Teclado: [rótulo, coluna (em teclas), linha, largura (em teclas)].
const LAYOUT := [
	["Esc", 0.0, 0, 1.0], ["F3", 2.0, 0, 1.0],
	["1", 0.0, 1, 1.0], ["2", 1.0, 1, 1.0], ["3", 2.0, 1, 1.0], ["4", 3.0, 1, 1.0], ["5", 4.0, 1, 1.0],
	["6", 5.0, 1, 1.0], ["7", 6.0, 1, 1.0], ["8", 7.0, 1, 1.0], ["9", 8.0, 1, 1.0], ["0", 9.0, 1, 1.0],
	["Tab", 0.0, 2, 1.5], ["Q", 1.5, 2, 1.0], ["W", 2.5, 2, 1.0], ["E", 3.5, 2, 1.0], ["R", 4.5, 2, 1.0],
	["T", 5.5, 2, 1.0], ["Y", 6.5, 2, 1.0], ["U", 7.5, 2, 1.0], ["I", 8.5, 2, 1.0], ["O", 9.5, 2, 1.0], ["P", 10.5, 2, 1.0],
	["A", 1.75, 3, 1.0], ["S", 2.75, 3, 1.0], ["D", 3.75, 3, 1.0], ["F", 4.75, 3, 1.0], ["G", 5.75, 3, 1.0],
	["H", 6.75, 3, 1.0], ["J", 7.75, 3, 1.0], ["K", 8.75, 3, 1.0], ["L", 9.75, 3, 1.0], ["Enter", 10.75, 3, 1.75],
	["Shift", 0.0, 4, 2.25], ["Z", 2.25, 4, 1.0], ["X", 3.25, 4, 1.0], ["C", 4.25, 4, 1.0], ["V", 5.25, 4, 1.0],
	["B", 6.25, 4, 1.0], ["N", 7.25, 4, 1.0], ["M", 8.25, 4, 1.0],
	["Espaço", 2.5, 5, 6.5],
	["Home", 13.25, 1, 1.0], ["Del", 14.25, 1, 1.0], ["↑", 13.75, 4, 1.0], ["↓", 13.75, 5, 1.0],
]

var mapped := {}  # rótulo -> [grupo, texto curto]


func _init() -> void:
	mapped = mapa()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PAGE_W, PAGE_H)


# Rótulo da tecla -> [grupo, função em poucas palavras]. Duas funções na mesma tecla viram "a · b".
static func mapa() -> Dictionary:
	var m := {}
	_add(m, "Esc", "painel", "pausa")
	_add(m, "F3", "painel", "perf.")
	_add(m, "B", "painel", "mochila")
	_add(m, "J", "painel", "diário")
	_add(m, "E", "painel", "equipar")
	_add(m, "Del", "painel", "descartar")
	_add(m, "Enter", "painel", "ligar pistas")
	_add(m, "↑", "painel", "diário")
	_add(m, "↓", "painel", "diário")
	_add(m, "L", "mover", "lanterna")
	_add(m, "Tab", "mover", "trocar")
	for n in ["1", "2", "3"]:
		_add(m, n, "mover", "escolher")
	_add(m, "C", "mover", "agachar")
	_add(m, "Home", "mover", "câmera")
	_add(m, "Espaço", "combate", "passar o turno")
	_add(m, "D", "combate", "atrasar")
	_add(m, "Q", "combate", "trocar arma")
	_add(m, "G", "combate", "recarga")
	_add(m, "F", "combate", "vigia")
	_add(m, "Shift", "combate", "acelerar inimigo")
	var itens := {"granada_luz": "granada", "sinalizador": "sinal"}
	for iid in RoomItems.KEY_LABELS:
		_add(m, RoomItems.KEY_LABELS[iid], "uso", itens.get(iid, str(iid)))
	var rit := RoomActionBar.RITUAL_KEYS
	var nomes := {"armadura_sangue": "armadura", "amaldicoar_arma": "maldição", "eletrocussao": "choque", "cicatrizacao": "curar"}
	for rid in rit:
		_add(m, rit[rid], "uso", nomes.get(rid, str(rid)))
	return m


static func _add(m: Dictionary, key: String, cat: String, text: String) -> void:
	if m.has(key):
		m[key] = [m[key][0], str(m[key][1]) + " · " + text]
	else:
		m[key] = [cat, text]


func _kx(col: float) -> float:
	return PAD + col * (KEY + GAP)


func _ky(row: int) -> float:
	return TITLE_H + 12.0 + row * (KEY + GAP) + (8.0 if row > 0 else 0.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PLATE)
	draw_rect(Rect2(Vector2.ZERO, size), BRONZE, false, 2.0)
	draw_string(FONT, Vector2(PAD, 22.0), "CADERNO DE CAMPO · CONTROLES", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
	draw_rect(Rect2(PAD, TITLE_H - 6.0, size.x - PAD * 2.0, 1.0), Color(BRONZE, 0.8))
	for k in LAYOUT:
		_draw_key(k)
	_draw_mouse(Vector2(size.x - 150.0, TITLE_H + 6.0))
	_draw_legend(Vector2(PAD, size.y - 34.0))


func _draw_key(k: Array) -> void:
	var label: String = k[0]
	var r := Rect2(_kx(k[1]), _ky(k[2]), k[3] * KEY + (k[3] - 1.0) * GAP, KEY)
	var use: Array = mapped.get(label, [])
	var tint: Color = CATS[use[0]][0] if not use.is_empty() else Color(0.3, 0.26, 0.22)
	draw_rect(r, Color(tint, 0.2 if not use.is_empty() else 0.1))
	draw_rect(r, Color(tint, 0.95 if not use.is_empty() else 0.45), false, 1.0)
	var big := label.length() <= 2 or label == "Home"
	draw_string(FONT, r.position + Vector2(0, 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11 if big else 9, TEXT if not use.is_empty() else MUTED)
	if not use.is_empty():
		var lines := _wrap(str(use[1]), r.size.x + 2.0, 7)
		for i in mini(lines.size(), 2):
			draw_string(FONT, r.position + Vector2(-1.0, 23.0 + i * 8.0), lines[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 2.0, 7, Color(tint.lightened(0.35), 1.0))


# Quebra o texto em linhas que cabem em `w` pixels (por palavras).
static func _wrap(text: String, w: float, fsize: int) -> Array:
	var lines: Array = []
	var cur := ""
	for word in text.split(" "):
		var next: String = word if cur == "" else cur + " " + word
		if FONT.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > w and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = next
	lines.append(cur)
	return lines


func _draw_mouse(at: Vector2) -> void:
	var body := Rect2(at + Vector2(25, 0), Vector2(70, 110))
	var edge := Color(BRONZE, 0.95)
	draw_rect(body, Color(0.1, 0.075, 0.06))
	draw_rect(body, edge, false, 1.5)
	var left := Rect2(body.position + Vector2(2, 2), Vector2(32, 40))
	var right := Rect2(body.position + Vector2(36, 2), Vector2(32, 40))
	var cm: Color = CATS["mover"][0]
	var cc: Color = CATS["combate"][0]
	draw_rect(left, Color(cm, 0.35))
	draw_rect(right, Color(CATS["painel"][0], 0.35))
	draw_rect(Rect2(body.position + Vector2(30, 10), Vector2(10, 22)), Color(cc, 0.5))
	draw_rect(Rect2(body.position + Vector2(30, 10), Vector2(10, 22)), edge, false, 1.0)
	draw_line(body.position + Vector2(35, 0), body.position + Vector2(35, 44), edge, 1.0)
	draw_line(body.position + Vector2(0, 44), body.position + Vector2(70, 44), edge, 1.0)
	var notes := [
		["Esq", "mover · atacar · examinar", cm],
		["Dir", "voltar nos menus", CATS["painel"][0]],
		["Meio", "arrastar: câmera (combate)", cc],
		["Roda", "zoom", GOLD],
	]
	for i in notes.size():
		var y := body.end.y + 18.0 + i * 24.0
		draw_string(FONT, Vector2(at.x - 8.0, y), "Mouse " + notes[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, notes[i][2])
		draw_string(FONT, Vector2(at.x - 8.0, y + 10.0), notes[i][1], HORIZONTAL_ALIGNMENT_LEFT, 130, 8, MUTED)


func _draw_legend(at: Vector2) -> void:
	var x := at.x
	for cat in CATS:
		draw_rect(Rect2(x, at.y + 2.0, 10, 10), Color(CATS[cat][0], 0.35))
		draw_rect(Rect2(x, at.y + 2.0, 10, 10), CATS[cat][0], false, 1.0)
		draw_string(FONT, Vector2(x + 15.0, at.y + 11.0), CATS[cat][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT)
		x += 24.0 + FONT.get_string_size(CATS[cat][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
	draw_string(FONT, Vector2(PAD, size.y - 8.0), "Só leitura: as teclas ainda não podem ser trocadas.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MUTED)
