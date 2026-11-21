extends SceneTree
# Teste headless dos rituais do Miguel na sala em combate (teclas, alvo automático, textos, fim da vez). Rodar com:
#   godot --headless --path . -s tests/test_ritual_room.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 5
	root.add_child(room)
	await process_frame
	var miguel: Combatant = room.party[2]
	_check(miguel.personagem == "miguel", "o terceiro do grupo é o Miguel")
	for m in room.party:
		m.pos = Vector2(80, 600)
	miguel.pos = Vector2(200, 300)
	room.player = miguel
	var e: Combatant = room.cfg.make_enemy("cultista", Vector2(260, 300))
	e.max_pv = 100
	e.pv = 100
	e.defense = 0.0
	room.enemies.clear()
	room.enemies.append(e)
	room.mode = room.Mode.COMBAT
	room.turns = TurnManager.new()
	room.turns.state = TurnManager.State.ACTIVE
	room.turns.current = miguel
	room.turns._by_initiative.assign([miguel, e, room.party[0]])  # senão o fim imediato encerra o combate de teste
	room.rules.units = [miguel, e]
	miguel.pa = 3

	var bar: RoomActionBar = room.action_bar
	var slots: Array = bar._action_slots()
	var n := slots.size()
	var start := bar.ritual_start(n)
	_check(n - start == 4 and slots[start][0] == "armadura_sangue" and slots[n - 1][0] == "cicatrizacao", "a barra do Miguel ganha 4 casas de ritual no fim")
	_check(slots[start][5]["pa"] == 1 and slots[start][5]["san"] == 2 and slots[start + 2][5]["pa"] == 2 and slots[start + 2][5]["san"] == 4, "cada casa traz o custo de PA e SAN")
	_check(slots[start][5]["elemento"] == "sangue" and int(slots[start][5]["tem"]) == room.rituals.components_available("armadura_sangue"), "e o elemento com os componentes da mochila")
	_check(bar._action_rect(start, n).position.x - bar._action_rect(start - 1, n).end.x > RoomActionBar.BAR_GAP, "vão entre as ações comuns e os rituais")
	_check(bar._bar_rect(n).encloses(bar._action_rect(n - 1, n)) and bar._action_rect(n - 1, n).end.x < bar._end_turn_rect(n).position.x, "as casas cabem na moldura antes do fim do turno")
	_check(room.rituals.inventory == room.inventory, "os rituais tiram componentes da mochila da sala")
	var sangue: int = room.inventory.count("sangue_coagulado")
	room.room_ritual.cast("armadura_sangue")
	_check(miguel.buffs.has("armadura_sangue") and miguel.pa == 2 and miguel.san == 20, "Z: Armadura de Sangue paga 1 PA e 2 SAN")
	_check(room.inventory.count("sangue_coagulado") == sangue - 1, "e gasta um sangue coagulado da mochila")
	_check(room.popups.any(func(p: Dictionary) -> bool: return p.text == "ARMADURA DE SANGUE"), "o nome do ritual sobe sobre o Miguel")
	_check(room.popups.any(func(p: Dictionary) -> bool: return p.text == "-2 SAN"), "o custo de SAN aparece")

	room.room_ritual.cast("eletrocussao")
	_check(e.pv < 100 and miguel.pa == 0 and miguel.san == 16, "T: Eletrocussão acha o inimigo sozinha e paga 2 PA e 4 SAN")

	_check(room.turns.current != miguel, "sem PA, a vez passa")
	room.turns.current = miguel
	miguel.pa = 3
	e.pos = Vector2(2000, 300)
	room.room_ritual.cast("eletrocussao")
	_check(miguel.pa == 3 and miguel.san == 16, "sem inimigo ao alcance, nada é gasto")

	var energia: int = room.inventory.count("bateria")
	var pv_antes: int = e.pv
	room.inventory.remove("bateria", energia)
	e.pos = Vector2(260, 300)
	room.room_ritual.cast("eletrocussao")
	_check(miguel.pa == 3 and miguel.san == 16 and e.pv == pv_antes, "sem componente de Energia, a Eletrocussão não sai e nada é gasto")
	_check(room.hud.notice_label.text.begins_with("Sem componente de Energia"), "o aviso diz o elemento que falta (%s)" % room.hud.notice_label.text)
	var bar_slots: Array = room.action_bar._action_slots()
	_check(not bar_slots[start + 2][3], "a casa da Eletrocussão fica apagada sem componente")
	room.inventory.add("bateria", energia)
	e.pos = Vector2(2000, 300)

	miguel.pv = 4
	room.room_ritual.cast("cicatrizacao")
	_check(miguel.pv > 4 and miguel.pa == 1, "Y: Cicatrização cura o Miguel (único ferido ao alcance)")

	var fernando: Combatant = room.party[0]
	fernando.pos = Vector2(200, 320)
	room.player = fernando
	room.turns.current = fernando
	fernando.pa = 3
	room.room_ritual.cast("armadura_sangue")
	_check(fernando.pa == 3 and not fernando.buffs.has("armadura_sangue"), "quem não é Ocultista não conjura")

	_check(room.action_bar.ritual_start(room.action_bar._action_slots().size()) == room.action_bar._action_slots().size(), "quem não é Ocultista não tem casas de ritual")

	room.mode = room.Mode.EXPLORATION
	room.queue_free()
	await process_frame
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok   - ", label)
	else:
		failures += 1
		print("FAIL - ", label)
