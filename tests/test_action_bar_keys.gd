extends SceneTree
# Teste headless dos atalhos da barra de combate (Léo, 19/11): as casas usam as teclas 1 a 9 em ordem, sem letras.
#   godot --headless --path . -s tests/test_action_bar_keys.gd

var failures := 0


func _initialize() -> void:
	_run()


func _key(room, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = keycode
	room._unhandled_input(ev)


func _run() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 5
	root.add_child(room)
	await process_frame
	var miguel: Combatant = room.party[2]
	for m in room.party:
		m.pos = Vector2(80, 600)
	miguel.pos = Vector2(200, 300)
	room.player = miguel
	var e: Combatant = room.cfg.make_enemy("cultista", Vector2(260, 300))
	room.enemies.clear()
	room.enemies.append(e)
	room.mode = room.Mode.COMBAT
	room.turns = TurnManager.new()
	room.turns.state = TurnManager.State.ACTIVE
	room.turns.current = miguel
	room.turns._by_initiative.assign([miguel, e, room.party[0]])
	room.rules.units = [miguel, e]
	miguel.pa = 3

	_check(RoomActionBar.slot_for_key(KEY_1) == 0 and RoomActionBar.slot_for_key(KEY_9) == 8 and RoomActionBar.slot_for_key(KEY_0) == 9, "1 a 9 e depois 0, em ordem")
	_check(RoomActionBar.slot_for_key(KEY_KP_3) == 2, "o teclado numérico também vale")
	_check(RoomActionBar.slot_for_key(KEY_H) == -1 and RoomActionBar.slot_for_key(KEY_Z) == -1, "letras não são atalho da barra")

	var bar: RoomActionBar = room.action_bar
	var slots: Array = bar._action_slots()
	var n := slots.size()
	for k in n:
		var tip := str(slots[k][2])
		if k > 0 and k < 10:
			_check(tip.contains("tecla %s" % RoomActionBar.key_label(k)), "a dica da casa %d mostra a tecla %s" % [k + 1, RoomActionBar.key_label(k)])
		for letra in ["tecla Q", "tecla F", "tecla D", "tecla Z", "tecla X", "tecla T", "tecla Y", "tecla H", "tecla U", "G recarrega"]:
			if tip.contains(letra):
				_check(false, "a casa %d ainda fala em %s" % [k + 1, letra])

	var start := bar.ritual_start(n)
	_key(room, KEY_Z)
	_check(not miguel.buffs.has("armadura_sangue") and miguel.pa == 3, "Z não conjura mais a Armadura de Sangue")
	_key(room, RoomActionBar.SLOT_KEYS[start])
	_check(miguel.buffs.has("armadura_sangue") and miguel.pa == 2, "a tecla da casa (%s) conjura a Armadura de Sangue" % RoomActionBar.key_label(start))

	var atrasar := bar.kit_index() + 2
	_check(slots[atrasar][0] == "atrasar", "a casa de Atrasar vem depois do kit e da vigilância")
	room.turns._queue.assign([e])
	room.turns._acted.clear()  # quem já agiu não pode atrasar; aqui só importa que a tecla chega à ação
	_key(room, RoomActionBar.SLOT_KEYS[atrasar])
	_check(room.turns._delayed.has(miguel), "a tecla %s atrasa a vez" % RoomActionBar.key_label(atrasar))

	room.mode = room.Mode.EXPLORATION
	_key(room, KEY_1)
	_check(room.player == room.party[0], "fora do combate o 1 ainda troca o controlado")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("ok    ", label)
	else:
		failures += 1
		print("FALHA ", label)
