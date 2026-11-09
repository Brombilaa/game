extends SceneTree
# Teste headless do HUD fosco: placas de vidro só no combate, ordem dos turnos centrada e texto do canto.
# Rodar com:
#   godot --headless --path . -s tests/test_hud_fosco.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	_check(room._hud_blur_rects().is_empty(), "na exploração não há placa de vidro fosco")
	room._start_combat()
	await process_frame
	var rects: Array[Rect2] = room._hud_blur_rects()
	_check(rects.size() >= 1, "no combate a ordem dos turnos ganha vidro fosco")
	var turn: Rect2 = room.party_hud.turn_order_rect()
	_check(is_equal_approx(turn.get_center().x, 480.0), "a ordem dos turnos fica centrada na tela")
	_check(turn.position.y > 0.0 and turn.end.y < 90.0, "a ordem dos turnos fica no topo")
	if room._player_ready():
		var bar: Rect2 = room.action_bar._bar_rect(room.action_bar._action_slots().size())
		_check(rects.has(bar), "a barra de ações também ganha vidro fosco")
	_check(room._under_hud_panel(room.get_canvas_transform().affine_inverse() * turn.get_center()), "ponto sob a placa conta como coberto")
	_check(not room._under_hud_panel(room.get_canvas_transform().affine_inverse() * Vector2(480, 300)), "ponto livre não conta como coberto")
	_check(room.objectives_hud.RIGHT <= 952.0 and room.minimap.RADAR_CENTER.x + room.minimap.RADAR_RADIUS + 4.0 <= 952.0, "objetivos e minimapa ficam alinhados ao canto da direita")
	room.queue_free()
	await process_frame
	print("falhas: ", failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
