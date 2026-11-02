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
	await _test_party()
	await _test_gear()
	await _test_small_upgrades()
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 3
	root.add_child(room)
	await process_frame

	# Porta aberta e agente à vista da criatura: o combate começa na hora.
	room.door_open = true
	room.player.pos = Vector2(650, 360)
	await process_frame
	_check(room.mode == room.Mode.COMBAT, "detecção inicia o combate")
	_check(room.turns.order.size() == room.party.size() + 2, "o grupo e todos os inimigos vivos entram no combate")
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
	_check(room.player.pa == pa_before and room.player.pos.is_equal_approx(Vector2(650, 300)) and is_equal_approx(room.player.moved_px, 60.0), "movimento de até 5 m não gasta PA, chega ao destino e conta os metros andados")

	# Agente resistente para o teste não depender da sorte dos inimigos.
	for m in room.party:
		m.pv = 999
		m.max_pv = 999

	# Passar: o resto do grupo e os inimigos jogam e a vez volta ao grupo na rodada 2.
	var first: Combatant = room.player
	room._player_pass()
	await _wait(func() -> bool: return room.turns.is_turn_of(room.player) and not room.busy, 20.0)
	for _i in room.party.size() - 1:
		if room.mode == room.Mode.COMBAT and room.player != first:
			room._player_pass()  # os outros membros do grupo também passam
			await _wait(func() -> bool: return room.turns.is_turn_of(room.player) and not room.busy, 20.0)
	await _wait(func() -> bool: return room.mode != room.Mode.COMBAT or (room.turns.current == first and not room.busy), 20.0)
	_check(room.mode != room.Mode.COMBAT or room.turns.round_number == 2, "inimigos agem e a rodada avança")

	# Derrubar todos os inimigos encerra o combate e volta à exploração.
	if room.mode == room.Mode.COMBAT:
		for e in room.enemies:
			e.pv = 1
		for m in room.party:
			m.hit_bonus = 1.0
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
	room2.rules.rng.seed = 3  # acerto máximo é 95%: semente fixa evita o erro raro
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
	for m in room.party:
		m.take_damage(999)
	room.turns.action_done()
	_check(room.mode == room.Mode.GAME_OVER, "grupo todo caído encerra em Game Over")
	await _wait(func() -> bool: return room.fade.color.a > 0.2, 3.0)
	_check(room.fade.color.a > 0.2 and room.fade.color.a < 1.0, "a tela escurece aos poucos")
	room.queue_free()
	await process_frame


# Grupo: seguidor anda atrás do líder, troca de controlado e reanimação com kit.
# Inventário e equipamento: equipar arma e colete, guardar, descartar e trocar a reserva.
func _test_gear() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var f: Combatant = room.party[0]
	_check(room.gear[f]["principal"] == "pistola" and room.gear[f]["secundaria"] == "escopeta", "Fernando começa com pistola e escopeta")
	_check(room.inventory.count("colete_leve") == 1, "mochila inicial tem um colete leve")

	var vest: int = 0
	for i in 20:
		if not room.inventory.slots[i].is_empty() and room.inventory.slots[i]["id"] == "colete_leve":
			vest = i
	_check(room.gear_equip(f, "colete", vest) != "" and f.defense == 0.1, "colete leve reduz 10% do dano")
	_check(room.gear[f]["colete"] == "colete_leve" and room.inventory.count("colete_leve") == 0, "o colete sai da mochila")

	room.gear_unequip(f, "colete")
	_check(f.defense == 0.0 and room.inventory.count("colete_leve") == 1, "guardar o colete zera a defesa e devolve à mochila")

	room._swap_weapon()
	_check(room.gear[f]["principal"] == "escopeta" and f.weapon["id"] == "escopeta" and room.gear[f]["secundaria"] == "pistola", "Q troca principal e reserva")

	var bag := -1
	for i in 20:
		if not room.inventory.slots[i].is_empty() and room.inventory.slots[i]["id"] == "bandagem":
			bag = i
	f.conditions["sangrando"] = {"stacks": 1, "rounds": -1}
	room.gear_use(f, bag)
	_check(not f.has_condition("sangrando") and room.inventory.count("bandagem") == 1, "bandagem tira o sangramento e gasta 1")
	_check(room.gear_use(f, bag) == "Fernando não precisa" and room.inventory.count("bandagem") == 1, "sem sangramento a bandagem não é gasta")

	room.gear_discard(bag)
	_check(room.inventory.count("bandagem") == 0, "descartar tira o item")
	room.queue_free()


func _test_party() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var lider: Combatant = room.party[0]
	var seguidor: Combatant = room.party[1]
	room._order_move(Vector2(400, 360))
	await _wait(func() -> bool: return room.moving_unit == null and room.follow_paths.is_empty(), 6.0)
	var d: float = seguidor.pos.distance_to(lider.pos)
	_check(absf(d - room.FOLLOW_DISTANCE) < 14.0, "seguidor para a distância fixa do líder (%.0f)" % d)
	room._switch_to(seguidor)
	_check(room.player == seguidor, "troca o personagem controlado")
	room._switch_to(lider)
	_check(room.discovered.keys() == [0], "minimapa: só o lado do grupo é descoberto com a porta fechada")
	room.door_open = true
	await process_frame
	_check(room.discovered.has(0) and room.discovered.has(1), "minimapa: abrir a porta descobre o outro lado")

	room.enemies[1].pv = 0
	lider.pos = Vector2(650, 360)
	seguidor.pos = Vector2(650, 384)
	await process_frame
	_check(room.mode == room.Mode.COMBAT, "combate começa com o grupo")
	seguidor.take_damage(999)
	room.player = lider
	lider.pa = 3
	var pa_before: int = lider.pa
	room._revive(seguidor)
	_check(seguidor.pv == seguidor.max_pv / 2 and room.inventory.count(room.KIT_ID) == 0, "kit reanima com metade do PV")
	_check(lider.pa == pa_before - 2, "reanimar custa 2 PA")
	room.queue_free()
	await process_frame


func _test_small_upgrades() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var cultista: Combatant = room.enemies[0]
	# P8: o inimigo prefere o ferido, mesmo que o outro esteja um pouco mais perto.
	var a: Combatant = room.party[0]
	var b: Combatant = room.party[1]
	a.pos = cultista.pos + Vector2(100, 0)
	b.pos = cultista.pos + Vector2(140, 0)
	a.pv = a.max_pv
	b.pv = maxi(b.max_pv / 2, 1)
	_check(room._enemy_target(cultista) == b, "o inimigo prefere o alvo ferido")
	b.pv = b.max_pv
	_check(room._enemy_target(cultista) == a, "sem ferido, o mais perto")
	# P3: o log guarda no máximo 4 linhas.
	for i in 6:
		room._log("linha %d" % i)
	_check(room.combat_log.size() == room.LOG_MAX, "o log guarda só as últimas linhas")
	# P4: SAN cheia não tinge a tela; SAN zero sim.
	room.player.max_san = 12
	room.player.san = 12
	_check(is_equal_approx(room._san_ratio(), 1.0), "SAN cheia não muda a tela")
	room.player.san = 0
	_check(is_equal_approx(room._san_ratio(), 0.0), "SAN zero: tela sem cor")
	# P7: combate rápido dobra o tempo só no combate.
	room.options.values["fast_combat"] = true
	room._start_combat()
	_check(is_equal_approx(Engine.time_scale, 2.0), "combate rápido: tempo em 2x")
	room.queue_free()
	await process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "ao sair da sala o tempo volta a 1x")


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
