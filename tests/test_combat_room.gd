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
	await _test_crouch_and_reload()
	await _test_gear()
	await _test_small_upgrades()
	await _test_enemy_roles()
	await _test_focus_limit()
	await _test_overwatch()
	await _test_san()
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 3
	root.add_child(room)
	await process_frame

	# Porta aberta e agente à vista da criatura: o combate começa na hora.
	room.player.initiative = 9  # fichas do GDD: o Nikolai (AGI 3) agiria antes; aqui o Fernando é o primeiro do grupo
	room.door_open = true
	room.player.pos = Vector2(650, 360)
	await process_frame
	_check(room.mode == room.Mode.COMBAT, "detecção inicia o combate")
	_check(room.turns.order.size() == room.party.size() + 2, "o grupo e todos os inimigos vivos entram no combate")
	_check(room.turns.current.side == Combatant.Side.ENEMY, "quem percebe pega o grupo desprevenido: inimigo age primeiro")
	for m in room.party:
		m.pv = 999
		m.max_pv = 999
	await _wait(func() -> bool: return room.turns.current != null and room.turns.current.side == Combatant.Side.PLAYER and not room.busy, 20.0)
	var enemies_first: bool = room.turns.order.slice(0, room.enemies.size()).all(func(u: Combatant) -> bool: return u.side == Combatant.Side.ENEMY)
	_check(enemies_first and room.turns.round_number == 1, "surpresa: todos os inimigos agem antes do grupo na rodada 1")
	room.player.pos = Vector2(650, 360)
	_check(room.turns.current == room.player and room.player.pa == 3, "depois da surpresa, o agente age com 3 PA")

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
	var fichas: Array = room.party.map(func(m: Combatant) -> Array: return [m.personagem, m.max_pv, m.max_san, m.initiative])
	_check(fichas == [["fernando", 23, 12, 2], ["nikolai", 18, 16, 3], ["miguel", 14, 22, 1]], "grupo nasce das fichas do GDD (classe + atributos sugeridos)")
	_check(room.party[2].weapon["id"] == "espada", "Miguel começa com a espada (arma inicial da ficha)")
	_check(room.inventory.size == int(room.cfg.regra("inventario_espacos")), "mochila com os espaços de regras.json")
	f.pv = 10
	room.inventory.add("curativo", 1)
	var cur: int = room.inventory.slots.find(room.inventory.slots.filter(func(x): return x.get("id", "") == "curativo")[0])
	room.gear_use(f, cur)
	_check(f.pv == 10 + floori(23 * 0.3) and room.inventory.count("curativo") == 0, "curativo recupera 30% do PV máximo")
	f.pv = f.max_pv

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
	lider.initiative = 9  # fichas do GDD: o Nikolai (AGI 3) agiria antes; aqui o líder age primeiro
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
	lider.pv = 999
	lider.max_pv = 999
	await _wait(func() -> bool: return room.turns.current == lider and not room.busy, 20.0)
	seguidor.take_damage(999)
	room.player = lider
	lider.pa = 3
	var pa_before: int = lider.pa
	room._revive(seguidor)
	_check(seguidor.pv == seguidor.max_pv / 2 and room.inventory.count(room.KIT_ID) == 0, "kit reanima com metade do PV")
	_check(lider.pa == pa_before - 2, "reanimar custa 2 PA")

	# Pelo ícone da barra: sem caído encostado recusa e não gasta o kit; encostado reanima.
	room.inventory.add(room.KIT_ID, 1)
	seguidor.take_damage(999)
	seguidor.pos = lider.pos + Vector2(200, 0)
	lider.pa = 3
	room._use_kit_button()
	_check(not seguidor.is_alive() and room.inventory.count(room.KIT_ID) == 1 and lider.pa == 3, "ícone do kit: longe não gasta kit nem PA")
	seguidor.pos = lider.pos + Vector2(0, 24)
	room._use_kit_button()
	_check(seguidor.is_alive() and room.inventory.count(room.KIT_ID) == 0 and lider.pa == 1, "ícone do kit reanima o caído encostado")
	_check(room.action_bar._action_slots()[room.action_bar.kit_index()][0] == "kit", "kit_index aponta para a casa do kit")
	room.queue_free()
	await process_frame


# Léo, 13/11: agachar em grupo e não atirar durante a recarga.
func _test_crouch_and_reload() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var lider: Combatant = room.party[0]
	var seguidor: Combatant = room.party[1]
	room._toggle_crouch()
	_check(lider.crouched and seguidor.crouched, "agachar: o grupo junto agacha todo")
	room._toggle_link(seguidor)  # solto da corrente
	room._toggle_crouch()
	_check(not lider.crouched and seguidor.crouched, "agachar: quem está solto da corrente não acompanha")
	room._toggle_link(seguidor)
	room._toggle_crouch()
	_check(lider.crouched and seguidor.crouched, "agachar: preso de volta, agacha junto")
	room.enemies[1].pv = 0
	lider.pos = Vector2(650, 360)
	seguidor.pos = Vector2(650, 384)
	await process_frame
	_check(room.mode == room.Mode.COMBAT and lider.crouched and seguidor.crouched, "o combate não levanta ninguém")
	room.player = lider
	room._toggle_crouch()
	_check(not lider.crouched and seguidor.crouched, "em combate a tecla C troca só a postura de quem está na vez")
	room.nikolai_clock[lider] = {"anim": "reload", "start": Time.get_ticks_msec()}
	_check(not room._reloading(lider) and room._attack_blocker(lider, room.enemies[0]) != "reloading", "em combate a animação de recarga não bloqueia o ataque (custa só 1 PA)")
	var modo_combate = room.mode
	room.mode = room.Mode.EXPLORATION
	_check(room._reloading(lider) and room._attack_blocker(lider, room.enemies[0]) == "reloading", "fora do combate a recarga em curso bloqueia o ataque")
	room.nikolai_clock[lider] = {"anim": "reload", "start": Time.get_ticks_msec() - 3000}
	_check(not room._reloading(lider), "terminada a recarga, o ataque volta")
	room.mode = modo_combate
	# Recarga em combate: 1 PA, sem espera, e depois já se atira.
	room.nikolai_clock.erase(lider)
	lider.mag["pistola"] = 2
	room.turns.current = lider  # a vez é dele (o teste não espera a rodada)
	room.busy = false
	lider.pa = 3
	var reserva: int = room.inventory.count("municao_pistola")
	room._reload()
	_check(lider.pa == 2 and int(lider.mag["pistola"]) == 12 and room.inventory.count("municao_pistola") == reserva - 10, "recarregar em combate: 1 PA, completa o carregador com a reserva")
	room._combat_click(room.enemies[0].pos)
	_check(lider.pa < 2, "logo depois de recarregar já dá para atirar")
	room.queue_free()
	await process_frame


func _test_enemy_roles() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var cultista: Combatant = room.enemies[0]
	var atirador: Combatant = room.enemies[1]
	_check(cultista.behavior == "cerca" and atirador.behavior == "atirador", "os papéis vêm do inimigos.json")
	var alvo: Combatant = room.party[0]
	alvo.pos = Vector2(200, 300)
	# Dois cultistas: cada um escolhe um lado diferente do alvo.
	var outro: Combatant = room.cfg.make_enemy("cultista", Vector2(700, 300))
	room.enemies.append(outro)
	cultista.pos = Vector2(700, 280)
	var a: Vector2 = room.ai.stand_point(cultista, alvo)
	var b: Vector2 = room.ai.stand_point(outro, alvo)
	_check(a.distance_to(b) > 20.0, "cultistas cercam o alvo por lados diferentes")
	# Atirador: ponto livre, e se não for o ponto de distância pura, tem cobertura parcial.
	atirador.pos = Vector2(900, 300)
	var stand: Vector2 = room.ai.stand_point(atirador, alvo)
	_check(stand.is_finite(), "atirador acha onde parar")
	var far := alvo.pos.move_toward(atirador.pos, alvo.radius + atirador.radius + 2.0 + float(atirador.weapon["max_range"]) * 0.85)
	if stand.distance_to(far) > 1.0:
		var probe := Combatant.new()
		probe.radius = atirador.radius
		probe.pos = stand
		var c: Cover = room.rules.cover_between(alvo.pos, probe, room.covers)
		_check(c != null and c.kind == "partial", "atirador que sai do ponto distante vai para uma cobertura parcial")
	else:
		_check(true, "atirador para a 85% do alcance")
	room.queue_free()
	await process_frame


# Léo, 13/11: nunca 3 inimigos no mesmo personagem enquanto houver 2 ou mais do grupo de pé por perto.
func _test_focus_limit() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var a: Combatant = room.party[0]
	var b: Combatant = room.party[1]
	for m in room.party:
		m.pos = Vector2(900, 900) if m != a and m != b else m.pos
	a.pos = Vector2(200, 300)
	b.pos = Vector2(200, 400)
	var e1: Combatant = room.cfg.make_enemy("atirador", Vector2(300, 300))
	var e2: Combatant = room.cfg.make_enemy("atirador", Vector2(300, 310))
	var e3: Combatant = room.cfg.make_enemy("atirador", Vector2(300, 320))
	_check(room.ai.pick_target(e3) == a, "sem ataques na rodada, o terceiro também prefere o mais perto")
	room.ai._note_attack(e1, a)
	room.ai._note_attack(e2, a)
	_check(room.ai.pick_target(e1) == a, "quem já atacou o alvo pode seguir nele")
	_check(room.ai.pick_target(e3) == b, "o terceiro inimigo procura outro alvo")
	b.take_damage(999)
	_check(room.ai.pick_target(e3) == a, "com só 1 de pé por perto, a regra não vale")
	room.queue_free()
	await process_frame


func _test_overwatch() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 5
	root.add_child(room)
	await process_frame
	var a: Combatant = room.party[0]
	for m in room.party:
		if m != a:
			m.pos = Vector2(80, 600)
	a.pos = Vector2(200, 300)
	var e: Combatant = room.cfg.make_enemy("atirador", Vector2(300, 300))
	e.max_pv = 999
	e.pv = 999
	room.enemies.append(e)
	room.mode = room.Mode.COMBAT
	room.turns = TurnManager.new()
	room.rules.units = [a, e]
	_check(not room._overwatch_fire(e), "sem vigia, o inimigo anda em paz")
	a.pa = 3
	a.overwatch = true
	_check(room._overwatch_fire(e), "inimigo que se move à vista leva o tiro de vigilância")
	_check(not a.overwatch and room.fx.active(), "a vigilância gasta-se e o tiro é encenado")
	_check(not room._overwatch_fire(e), "só o primeiro movimento é punido")
	a.overwatch = true  # o cone e o olho são desenhados sem erro
	room.queue_redraw()
	await process_frame
	await process_frame
	_check(room.action_bar._action_slots().any(func(sl: Array) -> bool: return sl[0] == "vigilancia"), "a barra de ações tem o botão de vigilância")
	room.mode = room.Mode.EXPLORATION
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


# SAN como medidor de terror: ver a Criatura no início do combate, ver um aliado cair e a loucura.
func _test_san() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 3
	root.add_child(room)
	await process_frame
	room.enemies[0].kind = "criatura_sangue"
	var terror := int(room.cfg.san("terror_ao_ver")["criatura_sangue"])
	var before: Array = room.party.map(func(m: Combatant) -> int: return m.san)
	room._start_combat()
	var all_lost := true
	for i in room.party.size():
		all_lost = all_lost and room.party[i].san == before[i] - terror
	_check(all_lost, "ver a Criatura no início do combate tira SAN do grupo")
	_check(room.popups.any(func(p: Dictionary) -> bool: return p.kind == "san"), "perda de SAN aparece como texto flutuante")
	var fallen: Combatant = room.party[1]
	var other: Combatant = room.party[0]
	var o_before: int = other.san
	fallen.pv = 0
	room._on_fx_impact({"target": fallen, "attacker": room.enemies[0], "r": {"hit": true, "crit": false, "damage": 5, "blocked": false}})
	_check(other.san == o_before - int(room.cfg.san("perdas")["aliado_caido"]), "ver um aliado cair tira SAN dos outros")
	var crazy: Combatant = room.party[2]
	crazy.san = 1
	room.san.lose(crazy, 1)
	_check(crazy.ruptured and room.turns.turn_pa(crazy) == 2, "ruptura no combate: -1 PA no turno")
	room.room_combat._san_report({crazy: room.san.lose(crazy, 1)}, "teste")
	_check(crazy.insane and crazy.dead and not crazy.is_alive(), "segunda vez a 0 no mesmo combate: enlouquece")
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
