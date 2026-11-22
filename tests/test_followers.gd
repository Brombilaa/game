extends SceneTree
# Teste headless dos seguidores: ficam a distância fixa do líder, ninguém atravessa outro personagem,
# a rota é refeita poucas vezes por segundo e o lugar na formação nunca cai dentro de parede.
# Rodar com:
#   godot --headless --path . -s tests/test_followers.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	room.enemies.clear()

	# Lugares estáveis: um clique para o mesmo lado não embaralha o grupo; virar de costas refaz.
	room._reset_follow_offsets(Vector2.RIGHT)
	var antes := {}
	for m in room.party:
		if m != room.player:
			antes[m] = room.follow_offsets[m]
	room._reset_follow_offsets(Vector2(1, 0.4), true)
	var igual := true
	for m in antes:
		igual = igual and room.follow_offsets[m] == antes[m]
	_check(igual, "clique para o mesmo lado mantém os lugares dos seguidores")
	room._reset_follow_offsets(Vector2.LEFT, true)
	var mudou := false
	for m in antes:
		mudou = mudou or room.follow_offsets[m] != antes[m]
	_check(mudou, "virar de costas refaz os lugares")
	room._reset_follow_offsets(Vector2.RIGHT)
	var sorteio := {}
	for m in antes:
		sorteio[m] = room.follow_offsets[m]
	room._reset_follow_offsets(Vector2.RIGHT)
	var estavel := true
	for m in antes:
		estavel = estavel and room.follow_offsets[m].is_equal_approx(sorteio[m])
	_check(estavel, "a variação de cada seguidor é sorteada uma vez")

	# Leva o líder para longe, em linha reta, e confere separação e frequência de rotas a cada quadro.
	var obst: Array[Rect2] = room._obstacles(room.player, false)
	var origem: Vector2 = room.player.pos
	var destino := Vector2.INF
	for k in 16:
		var q: Vector2 = origem + Vector2.RIGHT.rotated(TAU * k / 16.0) * 260.0
		if room.pathfinder.find_path(origem, q, obst, room.player.radius).size() == 2:
			destino = q
			break
	_check(destino != Vector2.INF, "há um trecho livre para o líder andar")
	var rotas0: int = room.pathfinder.calls_total
	var menor := INF
	var quadros := 0
	var dt := 1.0 / 60.0
	room._reset_follow_offsets(destino - origem)
	for i in 240:
		room.player.pos = room.player.pos.move_toward(destino, 180.0 * dt)
		room._update_followers(dt)
		quadros += 1
		for a in room.party:
			for b in room.party:
				if a != b and a.get_instance_id() < b.get_instance_id():
					menor = minf(menor, a.pos.distance_to(b.pos) - (a.radius + b.radius) * 0.9)
	var rotas: int = room.pathfinder.calls_total - rotas0
	var seguidores: int = room.party.size() - 1
	_check(menor >= -0.5, "ninguém atravessa outro personagem andando (folga mínima %.1f px)" % menor)
	_check(rotas <= seguidores * 5.0 * (quadros * dt) + seguidores, "no máximo ~5 rotas por segundo por seguidor (%d rotas)" % rotas)

	# Parado o líder, cada seguidor termina perto do lugar dele, a distância do líder em torno de FOLLOW_DISTANCE.
	for i in 300:
		room._update_followers(dt)
	for m in room.party:
		if m == room.player:
			continue
		var d: float = m.pos.distance_to(room.player.pos)
		_check(d <= TestRoom.FOLLOW_DISTANCE + 30.0 and d >= m.radius, "%s para perto do líder (%.0f px)" % [m.name, d])
		_check(room.follow_paths.get(m, PackedVector2Array()).is_empty(), "%s para de andar ao chegar" % m.name)

	# Lugar dentro de parede: usa o ponto livre mais próximo, não fica parado nem atravessa.
	var parede: Rect2 = room.walls[0]
	var m1: Combatant = room.party[1]
	var slot: Vector2 = room.room_party._slot_livre(m1, parede.get_center())
	var ok := true
	for o in room._obstacles(m1, false):
		ok = ok and not (o as Rect2).grow(m1.radius).has_point(slot)
	_check(ok, "lugar dentro de parede vira ponto livre")

	# Caído no caminho: o seguidor não anda por cima dele.
	var caido: Combatant = room.party[2]
	var seg: Combatant = room.party[1]
	caido.pv = 0
	seg.pos = caido.pos - Vector2(60, 0)
	room.player.pos = caido.pos + Vector2(120, 0)
	room._reset_follow_offsets(Vector2.RIGHT)
	var dist_min := INF
	for i in 300:
		room._update_followers(dt)
		dist_min = minf(dist_min, seg.pos.distance_to(caido.pos) - (seg.radius + caido.radius) * 0.9)
	_check(dist_min >= -0.5, "seguidor contorna o caído em vez de atravessar (folga %.1f px)" % dist_min)

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
