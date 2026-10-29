extends SceneTree
# Teste headless da sala de teste em combate: detecção, turnos, ataque e fim do combate.
# Rodar com:
#   godot --headless --path . -s tests/test_combat_room.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 3
	root.add_child(room)
	await process_frame

	# Porta aberta e agente à vista da criatura: o combate começa na hora.
	room.door_open = true
	room.player.pos = Vector2(650, 360)
	await process_frame
	_check(room.mode == room.Mode.COMBAT, "detecção inicia o combate")
	_check(room.turns.order.size() == 3, "todos os inimigos vivos entram no combate")
	_check(room.turns.current == room.player and room.player.pa == 3, "agente tem a maior iniciativa e 3 PA")

	# Ataque fora do turno do inimigo: clique em lugar nenhum não gasta PA.
	room._combat_click(Vector2(-50, -50))
	_check(room.player.pa == 3, "clique em destino inacessível não gasta PA")

	# Atacar a criatura gasta 1 PA.
	var criatura: Combatant = room.enemies[0]
	room._combat_click(criatura.pos)
	_check(room.player.pa == 2, "ataque gasta o PA da arma")

	# Mover gasta PA proporcional e anda até o fim da rota.
	room._combat_click(room.player.pos + Vector2(0, -100))
	await _wait(func() -> bool: return not room.busy, 5.0)
	_check(room.player.pa == 1 and room.player.pos.is_equal_approx(Vector2(650, 260)), "movimento gasta 1 PA e chega ao destino")

	# Passar: os inimigos jogam e a vez volta ao agente na rodada 2.
	room._player_pass()
	await _wait(func() -> bool: return room.mode != room.Mode.COMBAT or (room.turns.current == room.player and not room.busy), 20.0)
	_check(room.mode != room.Mode.COMBAT or room.turns.round_number == 2, "inimigos agem e a rodada avança")

	# Derrubar todos os inimigos encerra o combate e volta à exploração.
	if room.mode == room.Mode.COMBAT:
		for e in room.enemies:
			e.pv = 1
		room.player.precision = 100
		var guard := 0
		while room.mode == room.Mode.COMBAT and guard < 200:
			guard += 1
			if room.turns.is_turn_of(room.player) and not room.busy:
				var alive: Array = room.enemies.filter(func(e: Combatant) -> bool: return e.is_alive())
				room.player.pos = alive[0].pos + Vector2(-25, 0)  # encosta no alvo para garantir alcance
				room._combat_click(alive[0].pos)
			await process_frame
	_check(room.mode == room.Mode.EXPLORATION, "sem inimigos vivos, volta à exploração")
	_check(room.turns.result == TurnManager.Result.VICTORY, "resultado é vitória")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _wait(cond: Callable, seconds: float) -> void:
	var t := 0.0
	while not cond.call() and t < seconds:
		await process_frame
		t += 1.0 / 60.0


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
