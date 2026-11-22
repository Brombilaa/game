extends SceneTree
# Necrotério e casa do Velho Geraldo (22/11): a cena do Tutu e o zumbi, as conversas do Geraldo e a escolha do destino
# depois da delegacia. Fica fora do test_local3d e do test_cenas_dialogo porque o CI dá 60 s por teste.
# Rodar com:
#   godot --headless --path . -s tests/test_necroterio_geraldo.gd

var failures := 0
const MARCAS_DAS_CENAS := ["delegacia17_chegada", "ghular_17h", "ghular_21h", "biblioteca_julia", "ligacao_juliana", "cripta_ghular", "necrotorio_chegada", "geraldo_chegada"]


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	await _chegadas()
	await _necroterio_e_geraldo()
	await _destinos()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_necroterio_geraldo")
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
func _chegadas() -> void:
	Engine.time_scale = 8.0
	for par in [["necrotorio", "necrotorio_chegada"], ["casa_geraldo", "geraldo_chegada"]]:
		Missao1.reiniciar()
		var room = await _abrir(par[0])
		await _esperar_cena(room, par[1])
		_check(Missao1.tem(par[1]) and room.mode == room.Mode.EXPLORATION and not room.busy, "%s: a conversa de chegada toca e devolve o controle" % par[0])
		await _fechar(room)
	Engine.time_scale = 1.0


# Necrotério (22/11): ao entrar na sala de autópsia toca a cena do Tutu, a gaveta arrebenta e só então o zumbi entra em cena;
# vencido o combate, o grupo comenta e a Letícia pede que continuem. Casa do Geraldo: a conversa sobe em duas etapas.
func _necroterio_e_geraldo() -> void:
	Engine.time_scale = 8.0
	Missao1.reiniciar()
	Missao1.marcar("necrotorio_chegada")
	var room = await _abrir("necrotorio")
	_check(room.enemies.is_empty() and room.adormecidos.has(2), "necrotério: o zumbi espera escondido até a cena da gaveta")
	_entrar_na_zona(room, "sala_autopsia")
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and room.enemies.is_empty(), "necrotério: a cena do Tutu toca antes de o zumbi aparecer")
	for i in 2400:
		if room.enemies.size() > 0:
			break
		await process_frame
	_check(room.enemies.size() == 1 and room.enemies[0].name == "Criatura de Sangue", "necrotério: depois da gaveta entra 1 zumbi de sangue (combate 2)")
	_check(Missao1.tem("necrotorio_trecho2") and Missao1.tem("necrotorio_tutu"), "necrotério: a cena fica marcada")
	room.enemies[0].pv = 0
	room.enemies[0].dead = true
	room._on_combat_ended(TurnManager.Result.VICTORY)
	for i in 2400:
		if Missao1.tem("necrotorio_depois") and room.mode != room.Mode.CUTSCENE:
			break
		await process_frame
	_check(Missao1.tem("necrotorio_depois") and Missao1.tem("necrotorio_vencido"), "necrotério: vencido o zumbi, o grupo comenta e o grupo fica marcado como vencido")
	await _fechar(room)
	Missao1.reiniciar()
	Missao1.marcar("geraldo_chegada")
	room = await _abrir("casa_geraldo")
	room._inspect("geraldo_1977")
	room._close_dialog()
	_check(not room.seen_clues.has("geraldo_1977"), "casa do Geraldo: ele só fala de 1977 depois da primeira conversa")
	room._inspect("geraldo_conversa")
	room._close_dialog()
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and Missao1.tem("geraldo_conversa"), "casa do Geraldo: a primeira conversa toca (atitude sobe)")
	await _esperar_cena(room, "geraldo_conversa")
	for i in 1200:
		if room.mode == room.Mode.EXPLORATION:
			break
		await process_frame
	room._inspect("geraldo_1977")
	room._close_dialog()
	await process_frame
	_check(Missao1.tem("geraldo_1977"), "casa do Geraldo: depois da conversa ele conta o caso de 1977")
	await _fechar(room)
	Engine.time_scale = 1.0


# Escolha do destino (Léo, 20/11): da delegacia das 17h o grupo vai à biblioteca, ao necrotério ou à casa do Geraldo, em
# qualquer ordem; com os três vistos, a saída volta à delegacia das 21h.
func _destinos() -> void:
	Missao1.reiniciar()
	Missao1.marcar("delegacia17_chegada")
	var room = await _abrir("delegacia_17h")
	_check(Missao1.destinos_livres().size() == 3, "destinos: os três lugares começam livres")
	_entrar_na_zona(room, "saida")
	_check(room.menu_destinos != null and room.indo_para == "", "destinos: a saída abre a escolha, sem sair ainda")
	room._escolher_destino(Missao1.DESTINOS_LIVRES[1])
	_check(room.indo_para == "necrotorio" and room.menu_destinos == null, "destinos: escolher o necrotério leva ao necrotério")
	await _fechar(room)
	Missao1.reiniciar()
	Missao1.marcar("delegacia17_chegada")
	Missao1.marcar("visitou_necrotorio")
	Missao1.marcar("visitou_biblioteca")
	room = await _abrir("delegacia_17h")
	_entrar_na_zona(room, "saida")
	_check(room.indo_para == "casa_geraldo" and room.menu_destinos == null, "destinos: com um só restante vai direto")
	await _fechar(room)
	Missao1.reiniciar()
	Missao1.marcar("delegacia17_chegada")
	for d in Missao1.DESTINOS_LIVRES:
		Missao1.marcar("visitou_" + str(d["id"]))
	room = await _abrir("delegacia_17h")
	_entrar_na_zona(room, "saida")
	_check(room.indo_para == "delegacia_21h", "destinos: depois dos três a saída volta à delegacia (21h)")
	await _fechar(room)
	for id in ["biblioteca", "necrotorio", "casa_geraldo"]:
		Missao1.reiniciar()
		Missao1.marcar("geraldo_chegada")
		Missao1.marcar("necrotorio_chegada")
		Missao1.marcar("biblioteca_julia")
		Missao1.marcar("necrotorio_despedida")
		Missao1.marcar("geraldo_despedida")
		room = await _abrir(id)
		_check(Missao1.tem("visitou_" + id), "destinos: chegar em %s marca a visita" % id)
		await _fechar(room)


func _esperar_cena(room: Node, marca: String) -> void:
	for i in 4200:
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
