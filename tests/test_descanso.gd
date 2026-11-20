extends SceneTree
# Teste headless do ponto de descanso (zona segura): aviso, tecla F, descansar, preparar rituais e save. Rodar com:
#   godot --headless --path . -s tests/test_descanso.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.dir = "user://test_descanso"
	Progresso.autosave_ativo = true
	Missao1.reiniciar()
	var room = load(Progresso.CENA_PARQUE).instantiate()
	room.rules.rng.seed = 5
	root.add_child(room)
	await process_frame
	var fernando: Combatant = room.party[0]
	var miguel: Combatant = room.party[2]
	_check(miguel.personagem == "miguel", "o terceiro do grupo é o Miguel")

	# A Van do parque é o ponto de descanso (Léo, 20/11)
	_check(room.room_descanso.points.size() == 1 and room.room_descanso.points[0]["id"] == "van", "o parque tem a Van como ponto de descanso")
	room.mode = room.Mode.EXPLORATION
	room.player = miguel
	miguel.pos = Vector2(900, 300)
	_check(not room.room_descanso.try_open(), "longe da Van a tecla F não abre")
	miguel.pos = Vector2(200, 740)
	_check(not room.room_descanso.point_here().is_empty(), "perto da Van o controlado está no ponto")
	miguel.pos = Vector2(900, 300)
	room.room_descanso.load_points([{"id": "teste", "nome": "Sala segura", "ret": [0, 0, 100000, 100000]}])
	_check(room.room_descanso.points.size() == 1 and not room.room_descanso.point_here().is_empty(), "ponto carregado dos dados")
	room.room_descanso.tick()
	_check(room.room_descanso._inside == "teste", "o aviso dispara ao entrar na área")

	# Abre o painel
	room.mode = room.Mode.EXPLORATION
	_check(room.room_descanso.try_open() and room.descanso_panel.open, "perto do ponto, F abre o painel")
	_check(not room.diario_pode_abrir(), "o diário não abre por cima")
	room.descanso_panel.atualizar()
	_check(_buttons(room.descanso_panel).any(func(b: Button) -> bool: return b.text == "DESCANSAR"), "o painel tem o botão DESCANSAR")
	_check(_buttons(room.descanso_panel).filter(func(b: Button) -> bool: return b.text == "PREPARAR").size() == 4, "um PREPARAR por ritual do Miguel")

	# Descansar
	fernando.pv = 5
	miguel.san = 2
	miguel.ruptured = true
	room.player = miguel
	var got: Dictionary = room.room_descanso.rest()
	_check(fernando.pv == fernando.max_pv and miguel.san == miguel.max_san and not miguel.ruptured, "descansar cura PV, SAN e ruptura")
	_check(got.has(fernando.name) and got.has(miguel.name), "o resumo lista quem recuperou algo")
	var caido: Combatant = room.party[1]
	caido.dead = true
	caido.pv = 0
	room.room_descanso.rest()
	_check(caido.dead and caido.pv == 0, "quem morreu não volta com o descanso")
	caido.dead = false
	caido.pv = caido.max_pv
	_check(DirAccess.dir_exists_absolute(Progresso.dir), "descansar salva o jogo (a pasta de saves existe)")

	# Preparar
	room.inventory = Inventory.new(room.cfg.game_data)
	room.inventory.add("sangue_coagulado", 2)
	room.inventory.add("bateria", 1)
	_check(room.rituals.inventory == room.inventory, "as regras usam a mochila da sala")
	var out: Dictionary = room.room_descanso.prepare(miguel, "armadura_sangue")
	_check(out.ok and miguel.prepared.get("armadura_sangue", 0) == 1, "o Miguel prepara pelo ponto")
	_check(room.inventory.count("sangue_coagulado") == 1 and room.inventory.count("bateria") == 0, "gastou sangue e a bateria (outro elemento)")
	var out2: Dictionary = room.room_descanso.prepare(miguel, "armadura_sangue")
	_check(not out2.ok and out2.reason == "no_extra", "sem outro elemento não prepara de novo")
	room.descanso_panel.atualizar()
	_check(not _buttons(room.descanso_panel).filter(func(b: Button) -> bool: return b.text == "PREPARAR")[0].disabled == false, "botão desligado quando não dá")

	# Save e volta
	var data := Progresso.capturar(room, "parque", "Parque")
	var salvo: Dictionary = (data["grupo"][2] as Dictionary)
	_check(salvo.get("preparados") is Dictionary and int(salvo["preparados"].get("armadura_sangue", 0)) == 1, "o save guarda as cargas preparadas")
	miguel.prepared.clear()
	Progresso.aplicar(room, data)
	_check(miguel.prepared.get("armadura_sangue", 0) == 1, "carregar devolve as cargas")
	var antigo := data.duplicate(true)
	(antigo["grupo"][2] as Dictionary).erase("preparados")
	Progresso.aplicar(room, antigo)
	_check(miguel.prepared.is_empty(), "save sem o campo: sem cargas")

	# Fechar com Esc
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	room.descanso_panel._input(ev)
	_check(not room.descanso_panel.open, "Esc fecha o painel")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _buttons(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_buttons(c))
	return out


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok  " + label)
	else:
		failures += 1
		print("  FALHOU  " + label)
