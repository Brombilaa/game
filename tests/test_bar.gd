extends SceneTree
# Teste headless do bar (Claude, 22/11/2026; roteiro-missao1.md, seções 0 e "BAR"): os dados são válidos,
# a introdução (vídeo do Blender) virá antes, a cena do bar toca inteira (chegada, perguntas à Letícia, despedida), cada pergunta vira
# uma entrada do diário uma única vez e o bar leva à praça (parque). Rodar com:
#   godot --headless --path . -s tests/test_bar.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	_dados()
	_conversa_regras()
	await _cena_do_bar()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_bar")
	quit(1 if failures > 0 else 0)


func _dados() -> void:
	var s := Scenario.load_id("bar")
	_check(s.ok(), "bar: dados válidos " + ", ".join(s.errors))
	_check(s.npcs.has("leticia") and s.npcs.has("caio"), "bar: Letícia e Caio no cenário")
	_check(s.party_start.size() == 3, "bar: os três recrutas começam na entrada")
	for arq in ["bar.glb", "bar.json"]:
		_check(FileAccess.file_exists(Cenario3D_PASTA + arq) or ResourceLoader.exists(Cenario3D_PASTA + arq), "bar: " + arq + " existe")
	var c := Conversa.carregar("bar_leticia")
	_check(c.get("perguntas", []).size() == 3, "bar: só as perguntas 2, 4 e 6 (Léo, 22/11)")
	var vistos := {}
	for p in c.get("perguntas", []):
		_check(not vistos.has(p["id"]), "bar: id único (%s)" % p["id"])
		vistos[p["id"]] = true
		_check(not p.get("respostas", []).is_empty() and not str(p.get("diario", {}).get("texto", "")).is_empty(), "bar: %s tem resposta e entrada de diário" % p["id"])
	for id in ["responsavel", "ordo", "chamou"]:
		_check(vistos.has(id), "bar: pergunta do roteiro do Léo (%s)" % id)
	var passos := CenaRoteiro.carregar("bar_chegada")
	_check(not passos.is_empty(), "bar: a cena carrega")
	var faz := passos.map(func(p: Dictionary) -> String: return str(p["faz"]))
	_check(faz.has("perguntas") and faz.find("perguntas") < faz.find("ir"), "bar: as perguntas vêm antes da ida à praça")
	_check(str(passos[faz.find("ir")]["para"]) == "parque", "bar: termina indo ao parque")


const Cenario3D_PASTA := "res://assets/3d/missao1/"


func _conversa_regras() -> void:
	Missao1.reiniciar()
	var c := Conversa.carregar("bar_leticia")
	_check(Conversa.registrar("bar_leticia", c, "responsavel", "BAR · 15h"), "a primeira pergunta registra")
	_check(not Conversa.registrar("bar_leticia", c, "responsavel", "BAR · 15h"), "repetir a pergunta não duplica")
	_check(Missao1.diario.size() == 1 and Missao1.diario[0]["lugar"] == "BAR · 15h", "a resposta vira entrada do diário no lugar do bar")
	_check(Conversa.feita("bar_leticia", "responsavel") and not Conversa.feita("bar_leticia", "ordo"), "a lista sabe quais já foram feitas")
	_check(Conversa.total_feitas("bar_leticia", c) == 1, "contagem de perguntas feitas")
	Missao1.reiniciar()


func _cena_do_bar() -> void:
	Missao1.reiniciar()
	Missao1.local = "bar"
	Engine.time_scale = 4.0  # a cena anda a 150 px/s; o CI dá 60 s para cada teste
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and room.busy, "a cena do bar toca ao chegar")
	_check(Missao1.tem("bar_visitado"), "chegar marca o bar visitado")
	# Espera a lista de perguntas abrir.
	var painel: ConversaPerguntas = null
	for i in 60 * 40:
		await process_frame
		for n in room.get_children():
			if n is ConversaPerguntas:
				painel = n
		if painel != null:
			break
	_check(painel != null, "depois da fala da Letícia abrem as perguntas")
	if painel == null:
		Engine.time_scale = 1.0
		return
	_check(painel.ids.size() == Conversa.carregar("bar_leticia")["perguntas"].size() + 1 and painel.ids[-1] == "", "a lista termina com a saída")
	painel.escolher("responsavel")
	await process_frame
	await process_frame
	painel.escolher("ordo")
	await process_frame
	await process_frame
	painel.escolher("ordo")  # repetir não duplica
	await process_frame
	await process_frame
	_check(Missao1.diario.size() == 2, "duas perguntas diferentes, duas entradas no diário")
	_check(Missao1.tem("perg_bar_leticia_ordo") and Missao1.tem("perg_bar_leticia_responsavel"), "as perguntas feitas ficam marcadas (vão no save)")
	painel.escolher("")
	for i in 60 * 30:
		await process_frame
		if Missao1.tem("bar_conversou"):
			break
	_check(Missao1.tem("bar_conversou"), "a cena termina marcando a conversa")
	for i in 60 * 10:
		await process_frame
		if Missao1.local == "":
			break
	_check(room.indo_para == "parque" and Missao1.local == "", "o bar leva ao parque (praça)")
	Engine.time_scale = 1.0
	room.queue_free()
	await process_frame


func _check(cond: bool, label: String) -> void:
	if cond:
		print("ok   ", label)
	else:
		failures += 1
		print("FAIL ", label)
