class_name RoomDicasHud
extends RefCounted
# Faixa de dica da primeira vez (modelo A): plaquinha escura no centro de baixo, uma dica por vez, no
# estilo do HUD fosco (linha clara fina). Em combate sobe para ficar acima da barra de ações. Pixels da tela.

const WIDTH := 400.0
const HEIGHT := 34.0
const BOTTOM := 524.0  # borda de baixo na exploração
const BOTTOM_COMBAT := 462.0  # acima da barra de ações
const FONT := 10
const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.58, 0.57, 0.55)

var room: TestRoom


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# A faixa fica escondida com a caixa de texto aberta, o inventário aberto ou o jogador sem a vez.
func visivel() -> bool:
	if room.inv_panel and room.inv_panel.open:
		return false
	var dialogo = room.get("dialog_layer")
	if dialogo != null and dialogo.visible:
		return false
	if room.mode == TestRoom.Mode.COMBAT:
		return room._player_ready()
	return true


func _draw_dica(font: Font, to_world: Transform2D) -> void:
	var p := Dicas.atual(room.mode == TestRoom.Mode.COMBAT)
	if p.is_empty() or not visivel():
		return
	var bottom := BOTTOM_COMBAT if room.mode == TestRoom.Mode.COMBAT else BOTTOM
	var rect := Rect2(480.0 - WIDTH * 0.5, bottom - HEIGHT, WIDTH, HEIGHT)
	var pos := to_world * rect.position
	var box := Rect2(pos, rect.size)
	room.draw_rect(box, Color(0.05, 0.045, 0.045, 0.8))
	room.draw_rect(box, Color(1, 1, 1, 0.22), false, 0.5)
	var y := rect.position.y + HEIGHT * 0.5 + 3.5
	var antes: String = p["antes"]
	var tecla: String = p["tecla"]
	var depois: String = p["depois"]
	var wa := font.get_string_size(antes, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x
	var wk := 0.0 if tecla == "" else font.get_string_size(tecla, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x + 8.0
	var wd := 0.0 if depois == "" else font.get_string_size(depois, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x
	var gap := 4.0
	var total := wa + (gap + wk if tecla != "" else 0.0) + (gap + wd if depois != "" else 0.0)
	var x := 480.0 - total * 0.5
	room.party_hud._draw_soft_text(font, to_world * Vector2(x, y), antes, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, INK)
	x += wa + gap
	if tecla != "":
		var chip := Rect2(to_world * Vector2(x, y - 11.0), Vector2(wk, 14.0))
		room.draw_rect(chip, Color(0.14, 0.12, 0.11, 0.95))
		room.draw_rect(chip, Color(1, 1, 1, 0.55), false, 0.5)
		room.party_hud._draw_soft_text(font, to_world * Vector2(x + 4.0, y - 0.5), tecla, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, INK)
		x += wk + gap
	if depois != "":
		room.party_hud._draw_soft_text(font, to_world * Vector2(x, y), depois, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, INK)
