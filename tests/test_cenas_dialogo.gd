extends SceneTree
# Cenas de diálogo da missão 1 (22/11): chegada à biblioteca e às delegacias, o Ghular depois da agenda e o discurso do
# salão da cripta. Fica fora do test_local3d porque o CI dá 60 s por teste e aquele já usa quase todos.
# Rodar com:
#   godot --headless --path . -s tests/test_cenas_dialogo.gd

var failures := 0
const MARCAS_DAS_CENAS := ["delegacia17_chegada", "ghular_17h", "ghular_21h", "biblioteca_julia", "ligacao_juliana", "cripta_ghular"]


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	await _cenas_de_dialogo()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_cenas_dialogo")
	quit(1 if failures > 0 else 0)


func _abrir(id: String, chegada := "") -> Node:
	Missao1.local = id
	Missao1.chegada = chegada
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	return room


func _fechar(room: Node) -> void:
	room.queue_free()
	await process_frame


# Cenas de diálogo (22/11): ao chegar à biblioteca, à delegacia das 17h e das 21h toca a conversa e o controle volta;
# a agenda do Ghular chama o delegado (uma vez); o salão da cripta abre com o discurso antes de os cultistas acordarem.
func _cenas_de_dialogo() -> void:
	Engine.time_scale = 4.0
	for par in [["biblioteca", "biblioteca_julia"], ["delegacia_17h", "delegacia17_chegada"], ["delegacia_21h", "ghular_21h"]]:
		Missao1.reiniciar()
		var room = await _abrir(par[0])
		await _esperar_cena(room, par[1])
		_check(Missao1.tem(par[1]) and room.mode == room.Mode.EXPLORATION and not room.busy, "%s: a conversa de chegada toca e devolve o controle" % par[0])
		await _fechar(room)
	Missao1.reiniciar()
	Missao1.marcar("delegacia17_chegada")
	var room = await _abrir("delegacia_17h")
	room._inspect("agenda_ghular")
	room._close_dialog()
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and Missao1.tem("ghular_17h"), "depois da agenda o delegado Ghular chega (cena)")
	await _esperar_cena(room, "ghular_17h")
	for i in 1200:
		if room.mode == room.Mode.EXPLORATION:
			break
		await process_frame
	_check(room.mode == room.Mode.EXPLORATION, "a cena do Ghular devolve o controle")
	await _fechar(room)
	# Saída da biblioteca (roteiro, seção 3): a Ju sai de moto e a moto some do cenário; o grupo volta à delegacia.
	Missao1.reiniciar()
	Missao1.marcar("biblioteca_julia")
	room = await _abrir("biblioteca")
	_check(room.scenario.npcs.has("julia") and room.world3d.tem_estado("moto"), "biblioteca: a Ju e a moto estão no cenário")
	_check(room.scenario.clues.has("fotos_simbolo") and room.scenario.clues["fotos_simbolo"]["inspecao"] != "", "biblioteca: as fotos do símbolo são uma pista com imagem")
	_entrar_na_zona(room, "saida")
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and Missao1.tem("biblioteca_saida"), "biblioteca: ao sair toca a despedida da Ju")
	for i in 6000:
		if Missao1.tem("biblioteca_saida_fim"):
			break
		await process_frame
	_check(Missao1.tem("biblioteca_saida_fim") and room.npc_fora.has("julia"), "biblioteca: a Ju sai de cena")
	for n in room.world3d.estados["moto"]:
		_check(not (n as Node3D).visible, "biblioteca: a moto foi embora")
	await _fechar(room)
	Missao1.reiniciar()
	room = await _abrir("cripta")
	for n in [2, 3]:
		_entrar_na_zona(room, "trecho%d_0" % n)
	var antes: int = room.enemies.size()
	_entrar_na_zona(room, "trecho4_0")
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and room.enemies.size() == antes, "salão: o discurso toca antes de os cultistas acordarem")
	for i in 1800:
		if room.enemies.size() > antes:
			break
		await process_frame
	_check(room.enemies.size() == 9 and Missao1.tem("cripta_ghular"), "salão: depois do discurso os 7 do salão entram em cena")
	await _fechar(room)
	Engine.time_scale = 1.0


func _esperar_cena(room: Node, marca: String) -> void:
	for i in 1800:
		if Missao1.tem(marca) and room.mode != room.Mode.CUTSCENE:
			return
		await process_frame


func _entrar_na_zona(room, id: String) -> void:
	for z in room.dados["zonas"]:
		if z["id"] == id:
			room.player.pos = _ponto_livre(room, room._ret(z))
			room.dentro_de[id] = false
			room._zonas()


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

func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
