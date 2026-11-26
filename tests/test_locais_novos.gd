extends SceneTree
# Teste headless dos locais novos da missão 1 (necrotério e casa do Velho Geraldo): mesmas checagens de alcance, pistas e
# saída do test_local3d, em arquivo próprio para cada teste caber nos 60 s do CI.
# Rodar com:
#   godot --headless --path . -s tests/test_locais_novos.gd

const LOCAIS := ["necrotorio", "casa_geraldo"]
const MARCAS_DAS_CENAS := ["delegacia17_chegada", "ghular_17h", "ghular_21h", "biblioteca_julia", "ligacao_juliana", "delegacia_tulio_morte", "cripta_ghular", "necrotorio_chegada", "geraldo_chegada"]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	TestePericia.animar = false
	for id in LOCAIS:
		var s := Scenario.load_id(id)
		_check(s.ok(), id + ": dados válidos " + ", ".join(s.errors))
	for id in LOCAIS:
		await _local(id)
	await _investigacao_locais()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_locais_novos")
	quit(1 if failures > 0 else 0)


func _abrir(id: String, chegada := "", com_cenas := false) -> Node:
	if not com_cenas:
		for m in MARCAS_DAS_CENAS:
			Missao1.marcar(m)
	Missao1.local = id
	Missao1.chegada = chegada
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	return room


func _fechar(room: Node) -> void:
	room.queue_free()
	await process_frame


func _local(id: String) -> void:
	Missao1.reiniciar()
	Missao1.marcar("porta_escritorio_ghular")  # aqui o teste é de alcance; a porta trancada tem teste próprio
	var room = await _abrir(id)
	_check(room.scenario.id == id and room.world3d != null, id + ": abre com o cenário 3D")
	_check(room.world3d.mundo.get_node_or_null("cenario") != null, id + ": malhas carregadas")
	for m in room.party:
		_check(Pathfinder.is_free(m.pos, room._obstacles(m), m.radius), id + ": %s começa em ponto livre" % m.name)
	for z in room.dados.get("zonas", []):
		var alvo: Vector2 = _ponto_livre(room, room._ret(z))
		var t0 := Time.get_ticks_msec()
		var rota: PackedVector2Array = room.pathfinder.find_path(room.player.pos, alvo, room._obstacles(room.player), room.player.radius)
		_check(rota.size() > 1, id + ": a zona %s é alcançável" % z["id"])
		_check(Time.get_ticks_msec() - t0 < 1500, id + ": rota até %s em menos de 1,5 s (%d ms)" % [z["id"], Time.get_ticks_msec() - t0])
	for cid in room.scenario.clues:
		var c: Dictionary = room.scenario.clues[cid]
		var ok := false
		for k in 16:
			var spot: Vector2 = c.pos + Vector2.from_angle(TAU * k / 16.0) * c.raio * room.STAND_FACTOR
			if room.pathfinder.find_path(room.player.pos, spot, room._obstacles(room.player), room.player.radius).size() > 1:
				ok = true
				break
		_check(ok, id + ": dá para chegar perto da pista " + cid)
	for e in room.enemies:
		_check(Pathfinder.is_free(e.pos, room._obstacles(e), e.radius), id + ": inimigo nasce em ponto livre")
	# Saída: entrar na zona leva ao próximo lugar (sem esperar a transição).
	for z in room.dados.get("zonas", []):
		if z.has("requer") or str(z.get("acao", "")) != "ir":
			continue
		room.player.pos = room._ret(z).get_center()
		room._zonas()
		_check(room.indo_para == str(z["para"]), id + ": a zona %s leva a %s" % [z["id"], z["para"]])
		break
	await _fechar(room)


func _investigacao_locais() -> void:
	# Delegacia das 17h e biblioteca têm pistas: documentos, itens no chão e gavetas (textos provisórios).
	for id in ["necrotorio", "casa_geraldo"]:
		Missao1.reiniciar()
		var room = await _abrir(id)
		_check(room.scenario.clues.size() >= 5, id + ": tem pelo menos 5 pistas")
		for cid in room.scenario.clues:
			var c: Dictionary = room.scenario.clues[cid]
			_check(str(c.texto).length() > 20, id + ": a pista %s tem texto" % cid)
			_check(Pathfinder.is_free(c.pos, room._obstacles(room.player), room.player.radius), id + ": a pista %s fica em ponto livre" % cid)
		for m in ["necrotorio_depois", "geraldo_chegada", "geraldo_conversa", "geraldo_1977"]:
			Missao1.marcar(m)  # pistas que só abrem depois de uma cena (a Letícia, o Geraldo)
		var antes: int = room.inventory.count("kit_primeiros_socorros") + room.inventory.count("municao_pistola") + room.inventory.count("curativo")
		for cid in room.scenario.clues:
			room._inspect(cid)
			if room.menu_teste != null:  # pista com teste de perícia: o jogador escolhe quem rola (22/11)
				room.menu_teste.find_children("*", "Button", true, false)[0].pressed.emit()
				await process_frame
			room._close_dialog()
		_check(room.seen_clues.size() == room.scenario.clues.size(), id + ": todas as pistas podem ser lidas")
		var depois: int = room.inventory.count("kit_primeiros_socorros") + room.inventory.count("municao_pistola") + room.inventory.count("curativo")
		_check(depois > antes, id + ": achar itens nas pistas enche a mochila")
		await _fechar(room)


func _ponto_livre(room, r: Rect2) -> Vector2:
	var best := r.get_center()
	var best_d := INF
	for i in 9:
		for j in 9:
			var p := r.position + r.size * Vector2((i + 0.5) / 9.0, (j + 0.5) / 9.0)
			if Pathfinder.is_free(p, room._obstacles(room.player), room.player.radius) and p.distance_to(r.get_center()) < best_d:
				best = p
				best_d = p.distance_to(r.get_center())
	return best


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)
