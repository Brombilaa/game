extends SceneTree
# Teste headless do parque (sala inicial): colisões, pistas em ordem e o combate depois da árvore.
# Rodar com:
#   godot --headless --path . -s tests/test_parque.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	await process_frame

	_check(room.mode == room.Mode.EXPLORATION and room.enemies.is_empty(), "começa em exploração, sem inimigos")
	_check(room.door_open, "não há porta fechada escondendo nada")
	_check(room.party[0].pos == room.scenario.party_start[0], "o grupo começa na entrada")
	_check(room._iso(Vector2.ZERO).is_equal_approx(Vector2.ZERO), "a origem do plano fica na origem da tela")
	var p := Vector2(500, 500)
	_check(room._uniso(room._iso(p)).distance_to(p) < 0.01, "projeção de ida e volta")

	# Colisão: não há rota para dentro da van.
	var into_van: PackedVector2Array = room.pathfinder.find_path(room.player.pos, Vector2(200, 900), room._obstacles(room.player), room.player.radius)
	_check(into_van.is_empty(), "o caminho não entra na van")

	# A árvore só abre depois das outras pistas.
	room._inspect("arvore_simbolo")
	_check(room.dialog_layer.visible and room.dialog_clue == "", "a árvore bloqueada só avisa")
	room._close_dialog()
	_check(room.mode == room.Mode.EXPLORATION and room.seen_clues.is_empty(), "o aviso não conta como pista vista")

	for cid in room.scenario.clues:
		if room.scenario.clues[cid]["ordem"] == 1:
			room._inspect(cid)
			room._close_dialog()
	_check(room.mode == room.Mode.EXPLORATION, "as pistas iniciais não disparam combate")

	room._inspect("arvore_simbolo")
	_check(room.dialog_clue == "arvore_simbolo" and room.dialog_image.visible, "a árvore abre a inspeção com imagem")
	room._close_dialog()
	_check(room.mode == room.Mode.COMBAT, "depois da árvore o combate começa")
	_check(room.enemies.size() == 2, "dois cultistas entram")
	for e in room.enemies:
		for w in room.walls:
			_check(not w.has_point(e.pos), "cultista fora das paredes")
	_check(room.turns.order.size() == room.party.size() + 2, "o grupo e os dois cultistas entram na ordem de turnos")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FALHOU: ", what)
