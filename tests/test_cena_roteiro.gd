extends SceneTree
# Teste headless das cenas com roteiro (CenaRoteiro, data/cenas): todo roteiro usa passos e atores conhecidos, e a
# morte do Caio toca no parque inteira antes do combate da árvore (modo cinema, sem HUD), marca a morte e abre o combate.
# Rodar com:
#   godot --headless --path . -s tests/test_cena_roteiro.gd

var failures := 0
const PASSOS := ["cinema", "camera", "andar", "olhar", "anim", "cair", "fala", "legenda", "esperar", "tremor", "flash", "saltar", "choque",
	"sangue", "poca", "surgir", "sumir", "marca", "dialogo", "estado", "acordar"]
const ATORES := ["caio", "leticia", "Fernando", "Nikolai", "Miguel", "lider", "inimigo:0", "inimigo:1", "tristan", "mark", "julia", "medico", "geraldo"]


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	Missao1.reiniciar()
	# Roteiros: passos e atores conhecidos.
	var ids := []
	for f in DirAccess.get_files_at(CenaRoteiro.PASTA):
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	_check(ids.has("morte_caio"), "a cena da morte do Caio existe")
	for cid in ids:
		var passos := CenaRoteiro.carregar(cid)
		_check(not passos.is_empty(), "%s: roteiro carrega" % cid)
		var surgidos := []
		for p in passos:
			_check(PASSOS.has(str(p.get("faz", ""))), "%s: passo conhecido (%s)" % [cid, p.get("faz", "")])
			if p.get("faz", "") == "surgir":
				surgidos.append(str(p["id"]))
			for campo in ["quem", "em", "ate", "para", "sobre"]:
				var v: Variant = p.get(campo)
				if v is String and not (campo == "quem" and p.get("faz") in ["fala"]):
					_check(ATORES.has(v) or surgidos.has(v), "%s: ator conhecido (%s)" % [cid, v])

	var room = load(Missao1.CENA_PARQUE).instantiate()
	root.add_child(room)
	await process_frame
	_check(room.scenario.npcs.has("caio"), "o Caio está no parque")
	var gatilho: Dictionary = room.scenario.triggers_after("arvore_simbolo")[0]
	_check(str(gatilho.get("cutscene_antes", "")) == "morte_caio", "a árvore abre o combate com a morte do Caio")
	Engine.time_scale = 4.0  # a cena tem uns 15 s; o CI dá 60 s para cada teste
	room.pista_gatilho = "arvore_simbolo"
	room._run_trigger(gatilho)
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and room.busy, "a cena para o jogo antes do combate")
	_check(not room.can_pause(), "sem pausa durante a cena")
	_check(room.enemies.size() == 2, "as duas criaturas já estão no mapa durante a cena")
	var criatura: Combatant = room.enemies[1]
	var de: Vector2 = criatura.pos
	var caio: Vector2 = room.scenario.npcs["caio"]
	var cam0: Vector2 = room.camera.position
	var moveu := false
	for i in 60 * 60:
		await process_frame
		if room.camera.position.distance_to(cam0) > 40.0:
			moveu = true
		if room.mode != room.Mode.CUTSCENE:
			break
	_check(room.mode == room.Mode.COMBAT, "depois da cena começa o combate")
	_check(moveu, "a câmera é conduzida pela cena")
	_check(criatura.pos.distance_to(caio) < 30.0 and de.distance_to(caio) > 60.0, "a criatura salta de perto da van em cima do Caio")
	_check(Missao1.tem("caio_morreu"), "a cena marca a morte do Caio")
	_check(str(room.npc_pose.get("caio", {}).get("anim", "")) == "death", "o corpo do Caio fica no chão")
	_check(room.npc_choque.has("leticia"), "a Letícia fica em choque")
	_check(room.scenario.npcs["leticia"].distance_to(Vector2(500, 630)) < 2.0, "a Letícia recua de costas")
	_check(room.cena == null, "a cena sai da sala")
	Engine.time_scale = 1.0
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("ok   ", label)
	else:
		failures += 1
		print("FAIL ", label)
