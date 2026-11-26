extends SceneTree
# Saída da biblioteca (roteiro, seção 3): a Ju tranca a porta e vai embora de moto, a moto some do cenário e as fotos
# do símbolo são uma pista. Fica fora do test_cenas_dialogo porque o CI dá 60 s por teste e aquele já usa quase todos.
# Rodar com:
#   godot --headless --path . -s tests/test_biblioteca_saida.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	Engine.time_scale = 4.0
	Missao1.reiniciar()
	Missao1.marcar("biblioteca_julia")
	Missao1.local = "biblioteca"
	Missao1.chegada = ""
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
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
	Engine.time_scale = 1.0
	print("Falhas: %d" % failures if failures > 0 else "OK: test_biblioteca_saida")
	quit(1 if failures > 0 else 0)


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
