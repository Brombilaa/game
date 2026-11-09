class_name RoomObjectivesHud
extends RefCounted
# Objetivos do HUD: texto solto no canto de cima da direita, sem placa, com uma sombra bem leve e
# alinhado à direita com o aro do minimapa (Léo, 09/11/2026). Só desenha; o conteúdo vem de
# `Objectives.build` e a sala fornece a lista em `_objectives()`. Pixels da tela (960×540).

const RIGHT := 950.0  # borda direita do texto (a mesma do aro do minimapa)
const TOP := 112.0
const WIDTH := 170.0
const ROW_H := 14.0
const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.58, 0.57, 0.55)
const ENEMY := Color(0.86, 0.26, 0.29)

var room: TestRoom


func _init(owner_room: TestRoom) -> void:
	room = owner_room


func _draw_objectives(font: Font, to_world: Transform2D, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var hud := room.party_hud
	var pos := to_world * Vector2(RIGHT - WIDTH, TOP)
	var combat := room.mode == room.Mode.COMBAT
	hud._draw_soft_text(font, pos + Vector2(0, 6), "OBJETIVOS", HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, 6, DIM)
	for i in 8:  # fio que some para a esquerda
		var x0 := pos.x + WIDTH - 60.0 + i * 7.5
		room.draw_line(Vector2(x0, pos.y + 10), Vector2(x0 + 7.5, pos.y + 10), Color(1, 1, 1, 0.05 + 0.2 * i / 7.0), 0.5)
	for k in items.size():
		var it: Dictionary = items[k]
		var y := pos.y + 14 + k * ROW_H
		var done: bool = it["feito"]
		var current: bool = it["atual"]
		var color: Color = DIM if done or it["texto"] == Objectives.LOCKED_TEXT else INK
		var text: String = it["texto"]
		if it["detalhe"] != "":
			text += "  " + str(it["detalhe"])
		var mark := Vector2(pos.x + WIDTH - 2.5, y + 5.5)
		if current:  # bolinha cheia; vermelha no combate
			var dot := ENEMY if combat else Color.WHITE
			room.draw_circle(mark, 3.2, Color(dot, 0.25))
			room.draw_circle(mark, 2.0, dot)
		elif done:
			room.draw_circle(mark, 1.6, DIM)
		else:
			room.draw_arc(mark, 2.0, 0.0, TAU, 12, DIM, 0.75)
		hud._draw_soft_text(font, Vector2(pos.x, y + 8), text, HORIZONTAL_ALIGNMENT_RIGHT, WIDTH - 10.0, 8, color)
		if done:  # risco sobre o texto concluído
			var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, WIDTH - 10.0)
			room.draw_line(Vector2(pos.x + WIDTH - 10.0 - w, y + 5.5), Vector2(pos.x + WIDTH - 10.0, y + 5.5), DIM, 0.5)
