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
	# Pistas: só a bolinha acima do objeto é clicável, e a da árvore só aparece depois das outras.
	_check(room._clue_under(room._dot_pos("balanco")) == "balanco", "clicar na bolinha escolhe a pista")
	_check(room._clue_under(room._dot_pos("balanco") + Vector2(40, 0)) == "", "fora da bolinha não é pista")
	_check(room._clue_under(room._iso(room.scenario.clues["balanco"].pos)) == "", "o objeto em si não é mais o clique")
	_check(room._clue_under(room._dot_pos("arvore_simbolo")) == "arvore_simbolo", "a bolinha da árvore já é clicável (só avisa antes das outras)")
	var tree_foot: Vector2 = room._iso(room.scenario.clues["arvore_simbolo"].pos)
	_check(room._clue_under(tree_foot + Vector2(29, -250)) == "arvore_simbolo", "clicar na copa da árvore escolhe a pista")
	_check(room._clue_under(tree_foot + Vector2(20, -70)) == "arvore_simbolo", "clicar no tronco escolhe a pista")
	_check(room._clue_under(tree_foot + Vector2(400, -70)) == "", "longe da árvore não é pista")
	var z0: float = room.camera.zoom.x
	room._zoom_by(100.0)
	_check(room.camera.zoom.x == room.ZOOM_MAX and z0 < room.ZOOM_MAX, "a roda aproxima até o zoom máximo")
	room._zoom_by(0.0001)
	_check(is_equal_approx(room.camera.zoom.x, room._zoom_min()), "a roda afasta até o zoom mínimo")
	room.camera.zoom = Vector2(room.CAMERA_ZOOM, room.CAMERA_ZOOM)  # volta ao zoom inicial para os testes seguintes
	var tree_rect: Rect2 = room.scenario.colliders["arvore"]
	var near: Vector2 = room._nearest_free(tree_rect.get_center())
	_check(not tree_rect.has_point(near) and room.pathfinder.find_path(room.player.pos, near, room._obstacles(room.player), room.player.radius).size() > 1, "clicar dentro de um obstáculo leva ao ponto livre mais próximo")
	# Os inimigos do gatilho nascem em ponto livre e com caminho até o grupo (nada preso atrás da árvore).
	for spec in room.scenario.triggers["combate_arvore"]["inimigos"]:
		var spawn := Vector2(spec["pos"][0], spec["pos"][1])
		var route: PackedVector2Array = room.pathfinder.find_path(spawn, room.player.pos, room._obstacles(room.player), room.player.radius)
		_check(Pathfinder.is_free(spawn, room._obstacles(room.player), room.player.radius) and route.size() > 1, "inimigo nasce livre e alcança o grupo: " + str(spec["origem"]))
	_check(room.party[0].pos == room.scenario.party_start[0], "o grupo começa na entrada")
	_check(room._iso(Vector2.ZERO).is_equal_approx(Vector2.ZERO), "a origem do plano fica na origem da tela")
	var p := Vector2(500, 500)
	_check(room._uniso(room._iso(p)).distance_to(p) < 0.01, "projeção de ida e volta")

	# Colisão: não há rota para dentro da van.
	var into_van: PackedVector2Array = room.pathfinder.find_path(room.player.pos, Vector2(200, 900), room._obstacles(room.player), room.player.radius)
	_check(into_van.is_empty(), "o caminho não entra na van")
	# Van, sebes e o arbusto da árvore são paredes: bloqueiam o caminho e a visão.
	for cid in ["van", "mata_1", "mata_2", "arbusto_4"]:
		_check(room.walls.has(room.scenario.colliders[cid]), cid + " é parede")
		var center: Vector2 = room.scenario.colliders[cid].get_center()
		_check(not Pathfinder.has_line_of_sight(center + Vector2(-300, 0), center + Vector2(300, 0), room._sight_blockers()), cid + " bloqueia a visão")

	# A árvore, os arbustos e os pneus mantêm o grupo afastado (Léo, 30/10): ninguém chega colado no tronco.
	var near_tree: PackedVector2Array = room.pathfinder.find_path(room.player.pos, Vector2(1130, 250), room._obstacles(room.player), room.player.radius)
	_check(near_tree.is_empty(), "não há rota até o pé da árvore")
	var by_tree: PackedVector2Array = room.pathfinder.find_path(room.player.pos, Vector2(1130, 285), room._obstacles(room.player), room.player.radius)
	_check(by_tree.size() > 1, "há rota até a frente da árvore, a pista continua alcançável")

	# Todas as pistas continuam alcançáveis a pé (há ponto livre dentro do raio com rota até lá).
	for cid in room.scenario.clues:
		var clue: Dictionary = room.scenario.clues[cid]
		var reached := false
		for angle in 16:
			var goal: Vector2 = clue["pos"] + Vector2.RIGHT.rotated(TAU * angle / 16.0) * (float(clue["raio"]) - 4.0)
			if Rect2(Vector2.ZERO, room.scenario.size).has_point(goal) and room.pathfinder.find_path(room.player.pos, goal, room._obstacles(room.player), room.player.radius).size() > 1:
				reached = true
				break
		_check(reached, "pista alcançável a pé: " + cid)

	# Os pés da armação do balanço bloqueiam o caminho e, desde 8/11 (Léo: colisão do parquinho pequena), o vão entre eles também.
	for i in range(1, 5):
		var foot: Rect2 = room.scenario.colliders["balanco_pe_%d" % i]
		_check(not Pathfinder.is_free(foot.get_center(), room._obstacles(room.player), room.player.radius), "pé %d do balanço é sólido" % i)
	_check(not Pathfinder.is_free(Vector2(1197, 640), room._obstacles(room.player), room.player.radius), "o vão do balanço é sólido")
	_check(not Pathfinder.is_free(Vector2(960, 830), room._obstacles(room.player), room.player.radius), "o centro do carrossel é sólido")
	_check(not Pathfinder.is_free(Vector2(895, 830), room._obstacles(room.player), room.player.radius), "o aro do carrossel é sólido")
	# Os pneus ficam onde estão no desenho: o do meio é sólido e o chão da areia ao lado, livre.
	_check(not Pathfinder.is_free(Vector2(610, 765), room._obstacles(room.player), room.player.radius), "pneus a oeste são sólidos")
	_check(Pathfinder.is_free(Vector2(700, 800), room._obstacles(room.player), room.player.radius), "a areia ao lado dos pneus é livre")

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

	# Iluminação: vinheta transparente no centro e escura nas bordas.
	var img: Image = room.vignette.get_image()
	var mid: int = room.VIGNETTE_SIZE / 2
	_check(img.get_pixel(mid, mid).a < 0.01, "o centro da vinheta fica livre")
	_check(img.get_pixel(0, 0).a > 0.3, "a borda da vinheta escurece")

	# Câmera aproximada com fundo estendido: o mapa inteiro fica dentro dos limites da câmera.
	_check(room.camera.zoom.is_equal_approx(Vector2(1.5, 1.5)), "câmera em 1,5x")
	_check(room.extended != null, "o fundo estendido carrega")
	var limits := Rect2(room.camera.limit_left, room.camera.limit_top, room.camera.limit_right - room.camera.limit_left, room.camera.limit_bottom - room.camera.limit_top)
	for corner in [Vector2.ZERO, Vector2(room.scenario.size.x, 0), Vector2(0, room.scenario.size.y), room.scenario.size]:
		_check(limits.has_point(room._iso(corner)), "o canto do mapa fica dentro dos limites da câmera")
	_check(limits.size.x > 1700 and limits.size.y > 650, "os limites cobrem o fundo estendido")
	var hud_origin: Vector2 = room._hud_to_world() * Vector2.ZERO
	_check(hud_origin.is_equal_approx(-room.get_canvas_transform().origin), "o HUD parte da origem do canvas, sem o zoom")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FALHOU: ", what)
