class_name ControlesCaderno
extends Control
# Mapa de controles nas Opções (Léo, 19/11/2026): uma página do caderno de campo (mesma placa escura, bronze,
# dourado e teclas do Diário e do inventário) com todas as teclas e botões do jogo. Só mostra; não remapeia.
# A lista vem de `grupos()`: as teclas dos itens de combate são lidas de RoomItems.KEY_LABELS e as dos
# rituais de RoomActionBar.RITUAL_KEYS, então o mapa acompanha qualquer troca de tecla feita no código.
# Quem mudar uma tecla em outro lugar do jogo deve atualizar a linha correspondente aqui.

const GOLD := Color(0.839, 0.678, 0.361)
const BRONZE := Color(0.353, 0.255, 0.149)
const PLATE := Color(0.05, 0.037, 0.03, 0.97)
const TEXT := Color(0.91, 0.87, 0.79)
const MUTED := Color(0.66, 0.6, 0.49)
const CRIMSON := Color(0.62, 0.09, 0.11)
const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const TEX_KEY := preload("res://assets/sprites/ui/inv/tecla.png")
const TEX_KEY_WIDE := preload("res://assets/sprites/ui/inv/tecla_larga.png")

const PAD := 16.0
const COL_GAP := 22.0
const HEAD_H := 21.0
const ROW_H := 17.0
const GROUP_GAP := 8.0
const KEY_H := 17.0
const KEY_W := 17.0
const KEY_W_WIDE := 25.0
const TITLE_H := 34.0
const FOOT_H := 24.0
const TEXT_SIZE := 10
const KEYS_W := 92.0  # largura reservada às teclas de cada linha

const ITEM_NAMES := {"granada_luz": "Granada de luz (combate, 1 PA)", "sinalizador": "Sinalizador (combate, 1 PA)"}

var cols: Array = []  # [[grupo, ...], [grupo, ...]]
var page_w := 600.0


func _init() -> void:
	cols = columns()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(page_w, page_height())


# Cada grupo: [título, [[teclas, descrição], ...]]; "teclas" é uma lista de rótulos (cada um vira uma tecla)
# ou um texto de mouse (começa com "·").
static func grupos() -> Array:
	var itens: Array = []
	for iid in RoomItems.KEY_LABELS:
		itens.append([[RoomItems.KEY_LABELS[iid]], ITEM_NAMES.get(iid, str(iid))])
	itens.sort_custom(func(a: Array, b: Array) -> bool: return a[0][0] < b[0][0])
	var rit := RoomActionBar.RITUAL_KEYS
	return [
		["MOVER E EXPLORAR", [
			[["·Esq"], "Mover o grupo, examinar, abrir"],
			[["·Meio"], "Combate: arrastar move a câmera"],
			[["Home"], "Combate: recentrar a câmera"],
			[["·Roda"], "Zoom"],
			[["C"], "Agachar e levantar"],
			[["Tab"], "Trocar de personagem"],
			[["1", "2", "3"], "Escolher o personagem"],
			[["L"], "Lanterna (só à noite)"],
		]],
		["PAINÉIS E SISTEMA", [
			[["B"], "Inventário"],
			[["J"], "Diário de pistas"],
			[["Esc"], "Pausa; fecha painéis e menus"],
			[["·Dir"], "Voltar nos menus"],
			[["F3"], "Desempenho na tela"],
		]],
		["COMBATE", [
			[["·Esq"], "Mover, atacar, escolher alvo"],
			[["Espaço"], "Passar o turno"],
			[["D"], "Atrasar (age depois)"],
			[["Q"], "Trocar de arma"],
			[["G"], "Recarregar"],
			[["F"], "Vigilância"],
			[["Shift"], "Acelerar turno inimigo (segurar)"],
		]],
		["ITENS E RITUAIS", itens + [
			[[rit["armadura_sangue"]], "Armadura de Sangue (Miguel)"],
			[[rit["amaldicoar_arma"]], "Amaldiçoar Arma de Sangue"],
			[[rit["eletrocussao"]], "Eletrocussão"],
			[[rit["cicatrizacao"]], "Cicatrização"],
		]],
		["INVENTÁRIO E DIÁRIO", [
			[["E"], "Inventário: equipar ou usar"],
			[["Del"], "Inventário: descartar"],
			[["↑", "↓"], "Diário: percorrer pistas"],
			[["L"], "Diário: ligar pistas"],
			[["Enter"], "Diário: confirmar ligação"],
		]],
	]


# Duas colunas: [movimento, painéis, inventário] e [combate, itens e rituais].
static func columns() -> Array:
	var g := grupos()
	return [[g[0], g[1], g[4]], [g[2], g[3]]]


static func group_height(g: Array) -> float:
	return HEAD_H + g[1].size() * ROW_H + GROUP_GAP


static func page_height() -> float:
	var h := 0.0
	for col in columns():
		var ch := 0.0
		for g in col:
			ch += group_height(g)
		h = maxf(h, ch)
	return TITLE_H + h + FOOT_H + PAD


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, PLATE)
	draw_rect(r, BRONZE, false, 2.0)
	draw_rect(Rect2(PAD, TITLE_H - 6.0, size.x - PAD * 2.0, 1.0), Color(BRONZE, 0.8))
	draw_string(FONT, Vector2(PAD, 22.0), "CADERNO DE CAMPO · CONTROLES", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
	var col_w := (size.x - PAD * 2.0 - COL_GAP) / 2.0
	for c in cols.size():
		var x := PAD + c * (col_w + COL_GAP)
		var y := TITLE_H + 2.0
		for g in cols[c]:
			draw_string(FONT, Vector2(x, y + 13.0), g[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CRIMSON.lightened(0.35))
			draw_rect(Rect2(x, y + 17.0, col_w, 1.0), Color(BRONZE, 0.55))
			y += HEAD_H
			for row in g[1]:
				_draw_row(Vector2(x, y), row, col_w)
				y += ROW_H
			y += GROUP_GAP
	draw_string(FONT, Vector2(PAD, size.y - 9.0), "Só leitura: as teclas ainda não podem ser trocadas.", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)


func _draw_row(at: Vector2, row: Array, col_w: float) -> void:
	var x := at.x
	for k in row[0]:
		var label: String = k
		if label.begins_with("·"):  # botão do mouse: texto dourado, sem tecla
			var mouse := "Mouse " + label.substr(1)
			draw_string(FONT, at + Vector2(x - at.x, 13.0), mouse, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GOLD)
			x += FONT.get_string_size(mouse, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 4.0
			continue
		var w := KEY_W if label.length() == 1 else maxf(KEY_W_WIDE, FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 16.0)
		var kr := Rect2(Vector2(x, at.y + 1.0), Vector2(w, KEY_H))
		draw_texture_rect(TEX_KEY if label.length() == 1 else TEX_KEY_WIDE, kr, false)
		draw_string(FONT, kr.position + Vector2(0, 12.5), label, HORIZONTAL_ALIGNMENT_CENTER, w, 9, TEXT)
		x += w + 3.0
	draw_string(FONT, Vector2(at.x + KEYS_W, at.y + 13.0), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, col_w - KEYS_W, TEXT_SIZE, TEXT)
