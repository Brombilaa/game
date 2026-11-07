class_name RoomObjectivesHud
extends RefCounted
# Painel "OBJETIVOS" do HUD, abaixo da placa do radar (moldura A). Só desenha; o conteúdo vem
# de `Objectives.build` e a sala fornece a lista em `_objectives()`. Pixels da tela (960×540).

const PANEL_POS := Vector2(768, 208)
const PANEL_W := 184.0
const ROW_H := 17.0
const INK := Color(0.93, 0.89, 0.8)
const DIM := Color(0.5, 0.45, 0.37)

var room: TestRoom


func _init(owner_room: TestRoom) -> void:
	room = owner_room


func _draw_objectives(font: Font, to_world: Transform2D, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var hud := room.party_hud
	var pos := to_world * PANEL_POS
	var panel := Rect2(pos, Vector2(PANEL_W, 26 + items.size() * ROW_H + 6))
	var combat := room.mode == room.Mode.COMBAT
	hud._draw_frame(panel, combat)
	room.draw_string(font, pos + Vector2(0, 17), "OBJETIVOS", HORIZONTAL_ALIGNMENT_CENTER, PANEL_W, 9, hud.FRAME_ENEMY.lightened(0.3) if combat else Color(0.73, 0.65, 0.52))
	room.draw_line(pos + Vector2(14, 22), pos + Vector2(PANEL_W - 14, 22), hud.FRAME_INNER, 0.5)
	for k in items.size():
		var it: Dictionary = items[k]
		var y := pos.y + 26 + k * ROW_H
		var mark := Vector2(pos.x + 15, y + 8)
		var accent: Color = hud.FRAME_ENEMY.lightened(0.3) if combat and it["atual"] else hud.FRAME_ACCENT
		if it["feito"]:  # losango cheio dourado e texto apagado
			hud._draw_diamond(mark, 3.5, hud.FRAME_INNER)
		elif it["atual"]:  # losango vazado em destaque
			hud._draw_diamond(mark, 4.2, accent)
			hud._draw_diamond(mark, 2.0, hud.FRAME_FILL)
		else:
			hud._draw_diamond(mark, 3.0, DIM)
			hud._draw_diamond(mark, 1.4, hud.FRAME_FILL)
		var color: Color = DIM if it["feito"] or it["texto"] == Objectives.LOCKED_TEXT else (INK if it["atual"] else Color(0.72, 0.65, 0.52))
		room.draw_string(font, Vector2(pos.x + 26, y + 12), it["texto"], HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 60, 9, color)
		if it["feito"]:  # risco sobre o texto concluído
			var w := font.get_string_size(it["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			room.draw_line(Vector2(pos.x + 26, y + 8.5), Vector2(pos.x + 26 + minf(w, PANEL_W - 60), y + 8.5), DIM, 0.5)
		if it["detalhe"] != "":
			room.draw_string(font, Vector2(pos.x + PANEL_W - 38, y + 12), it["detalhe"], HORIZONTAL_ALIGNMENT_RIGHT, 28, 9, accent if it["atual"] else DIM)
