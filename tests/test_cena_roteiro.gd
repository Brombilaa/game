extends SceneTree
# Teste headless das cenas com roteiro (CenaRoteiro, data/cenas): todo roteiro usa passos e atores conhecidos, e a
# morte do Caio toca no parque inteira (modo cinema, sem HUD), marca a morte, some com o Caio e devolve o controle.
# Rodar com:
#   godot --headless --path . -s tests/test_cena_roteiro.gd

var failures := 0
const PASSOS := ["cinema", "camera", "andar", "olhar", "anim", "cair", "fala", "legenda", "esperar", "tremor", "flash",
	"sangue", "poca", "surgir", "sumir", "marca"]
const ATORES := ["caio", "leticia", "Fernando", "Nikolai", "Miguel", "lider"]


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
			for campo in ["quem", "em", "ate", "para"]:
				var v: Variant = p.get(campo)
				if v is String and not (campo == "quem" and p.get("faz") in ["fala"]):
					_check(ATORES.has(v) or surgidos.has(v), "%s: ator conhecido (%s)" % [cid, v])

	var room = load(Missao1.CENA_PARQUE).instantiate()
	root.add_child(room)
	await process_frame
	room.cena_depois = "morte_caio"
	_check(room.scenario.npcs.has("caio"), "o Caio está no parque")
	Engine.time_scale = 4.0  # a cena tem cerca de 30 s; o CI dá 60 s para cada teste
	var fim := [false]  # lambda captura por valor: o estado vai num array
	room.tocar_cena("morte_caio")
	var cena: CenaRoteiro = room.cena
	cena.terminou.connect(func() -> void: fim[0] = true)
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and room.busy, "a cena para o jogo")
	_check(not room.can_pause(), "sem pausa durante a cena")
	var cam0: Vector2 = room.camera.position
	var moveu := false
	for i in 60 * 60:
		await process_frame
		if room.camera.position.distance_to(cam0) > 200.0:
			moveu = true
		if fim[0]:
			break
	_check(fim[0], "a cena chega ao fim")
	_check(moveu, "a câmera é conduzida pela cena")
	await process_frame
	_check(Missao1.tem("caio_morreu"), "a cena marca a morte do Caio")
	_check(str(room.npc_pose.get("caio", {}).get("anim", "")) == "death", "o corpo do Caio fica no chão")
	_check(room.mode == room.Mode.EXPLORATION and not room.busy, "o controle volta ao jogador")
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
