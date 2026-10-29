extends SceneTree
# Teste headless da sala de teste em combate: detecção, turnos, ataque e fim do combate.
# Rodar com:
#   godot --headless --path . -s tests/test_combat_room.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await _test_stealth()
	await _test_game_over()
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
	_check(room.turns.current == room.player and room.player.pa == 3, "agente age primeiro (empate de AGI favorece o grupo) com 3 PA")

	# Ataque fora do turno do inimigo: clique em lugar nenhum não gasta PA.
	room._combat_click(Vector2(-50, -50))
	_check(room.player.pa == 3, "clique em destino inacessível não gasta PA")

	# Atacar a criatura gasta 1 PA.
	var criatura: Combatant = room.enemies[0]
	room._combat_click(criatura.pos)
	_check(room.player.pa == 3 - room.player.weapon.pa_cost, "ataque gasta o PA da arma")

	# Mover gasta PA proporcional e anda até o fim da rota.
	var pa_before: int = room.player.pa
	room._combat_click(room.player.pos + Vector2(0, -60))
	await _wait(func() -> bool: return not room.busy, 5.0)
	_check(room.player.pa == pa_before - 1 and room.player.pos.is_equal_approx(Vector2(650, 300)), "movimento de até 2 m gasta 1 PA e chega ao destino")

	# Agente resistente para o teste não depender da sorte dos inimigos.
	room.player.pv = 999
	room.player.max_pv = 999

	# Passar: os inimigos jogam e a vez volta ao agente na rodada 2.
	room._player_pass()
	await _wait(func() -> bool: return room.mode != room.Mode.COMBAT or (room.turns.current == room.player and not room.busy), 20.0)
	_check(room.mode != room.Mode.COMBAT or room.turns.round_number == 2, "inimigos agem e a rodada avança")

	# Derrubar todos os inimigos encerra o combate e volta à exploração.
	if room.mode == room.Mode.COMBAT:
		for e in room.enemies:
			e.pv = 1
		room.player.hit_bonus = 1.0
		var guard := 0
		while room.mode == room.Mode.COMBAT and guard < 5000:
			guard += 1
			if room.turns.is_turn_of(room.player) and not room.busy and room.player.pa < room.player.weapon.pa_cost:
				room._player_pass()  # sobrou PA só para andar
			elif room.turns.is_turn_of(room.player) and not room.busy:
				var alive: Array = room.enemies.filter(func(e: Combatant) -> bool: return e.is_alive())
				room.player.pos = alive[0].pos + Vector2(-25, 0)  # encosta no alvo para garantir alcance
				room._combat_click(alive[0].pos)
			await process_frame
	_check(room.mode == room.Mode.EXPLORATION, "sem inimigos vivos, volta à exploração")
	_check(room.turns.result == TurnManager.Result.VICTORY, "resultado é vitória")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


# Agachado, a percepção cai à metade; ataque furtivo que abate não inicia combate.
func _test_stealth() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 3
	root.add_child(room)
	await process_frame
	room.door_open = true
	var cultista: Combatant = room.enemies[0]
	room.enemies[1].pv = 0  # só o cultista na cena
	room.player.crouched = true
	room.player.pos = cultista.pos + Vector2(-200, 0)
	await process_frame
	_check(room.mode == room.Mode.EXPLORATION, "agachado a 200 px o cultista não percebe (300 / 2)")
	room.player.crouched = false
	room.player.pos = cultista.pos + Vector2(-200, 0)
	await process_frame
	_check(room.mode == room.Mode.COMBAT, "de pé a 200 px o cultista percebe")
	room.queue_free()

	var room2 = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room2)
	await process_frame
	room2.door_open = true
	room2.enemies[1].pv = 0
	var alvo: Combatant = room2.enemies[0]
	alvo.pv = 1
	room2.player.crouched = true
	room2.player.hit_bonus = 1.0
	room2.player.pos = alvo.pos + Vector2(-200, 0)
	await process_frame
	room2._stealth_attack(alvo)
	_check(not alvo.is_alive() and room2.mode == room2.Mode.EXPLORATION, "ataque furtivo que abate não inicia o combate")
	room2.queue_free()
	await process_frame


# Grupo todo caído: a tela escurece devagar, sem tela de Game Over.
func _test_game_over() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.door_open = true
	room.player.pos = Vector2(650, 360)
	await process_frame
	room.player.take_damage(999)
	room.turns.action_done()
	_check(room.mode == room.Mode.GAME_OVER, "agente caído encerra em Game Over")
	await _wait(func() -> bool: return room.fade.color.a > 0.2, 3.0)
	_check(room.fade.color.a > 0.2 and room.fade.color.a < 1.0, "a tela escurece aos poucos")
	room.queue_free()
	await process_frame


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
