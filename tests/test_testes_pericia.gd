extends SceneTree
# Testes de perícia com d20 (Léo, 20/11): regra do dado, resultado salvo, o corpo do Tutu (Ocultismo DT 12) e o Geraldo
# (Diplomacia ou Intimidação DT 15; falhou = ele conta pouco).
# Rodar com:
#   godot --headless --path . -s tests/test_testes_pericia.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	TestePericia.animar = false  # a tela do dado tem teste próprio (test_testes_pericia)
	_regra()
	_classes()
	await _no_jogo()
	await _testes_novos()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_testes_pericia")
	quit(1 if failures > 0 else 0)


func _grupo() -> Array:
	return [{"nome": "Fernando", "atributos": {"INT": 1, "PRE": 1}, "ocultista": false},
		{"nome": "Miguel", "atributos": {"INT": 3, "PRE": 2}, "ocultista": true}]


func _regra() -> void:
	Missao1.reiniciar()
	var g := RandomNumberGenerator.new()
	var r := TestePericia.rolar(["ocultismo"], 12, _grupo(), g, 7)
	_check(r["quem"] == "Miguel" and r["bonus"] == 5 and r["total"] == 12 and r["passou"], "Ocultismo: o Ocultista soma INT + 2 e 7 + 5 = DT 12 passa")
	_check(not TestePericia.rolar(["ocultismo"], 12, _grupo(), g, 6)["passou"], "11 contra DT 12 falha")
	_check(TestePericia.rolar(["ocultismo"], 15, _grupo(), g, 20)["passou"], "20 natural sempre passa")
	var baixo := [{"nome": "Alguém", "atributos": {"PRE": 3}, "ocultista": false}]
	_check(not TestePericia.rolar(["diplomacia"], 4, baixo, g, 1)["passou"], "1 natural sempre falha")
	_check(TestePericia.melhor(["diplomacia", "intimidacao"], _grupo())["quem"] == "Miguel", "quem rola é o de maior bônus (PRE)")
	var a := TestePericia.tentar("x", ["ocultismo"], 12, _grupo(), g, 3)
	var b := TestePericia.tentar("x", ["ocultismo"], 12, _grupo(), g, 20)
	_check(not a["passou"] and not b["passou"] and b.get("salvo", false), "uma tentativa só por pista: o resultado fica salvo")
	_check(Missao1.tem("teste_x_falhou"), "o resultado vai nas marcas (e portanto no save)")
	_check(TestePericia.texto(a).contains("DT 12") and TestePericia.texto(a).contains("Falhou"), "o texto mostra a DT e o resultado")


func _abrir(id: String) -> Node:
	Missao1.local = id
	Missao1.chegada = ""
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	return room


# O jogador escolhe quem rola (Léo, 22/11): a tela abre antes do dado, lista os agentes com o bônus e rola quem foi escolhido.
func _escolha() -> void:
	Missao1.reiniciar()
	Missao1.marcar("necrotorio_chegada")
	var room = await _abrir("necrotorio")
	room._inspect("tutu_pescoco")
	await process_frame
	_check(room.menu_teste != null and room.busy, "necrotério: a tela de escolha abre antes do dado")
	var botoes: Array = room.menu_teste.find_children("*", "Button", true, false)
	var alvo: Button = null
	for b in botoes:
		if b.text.begins_with("Miguel"):
			alvo = b
	_check(botoes.size() == room.party.size() and alvo != null and alvo.text.contains("bônus"), "um botão por agente, com o bônus de cada um")
	alvo.pressed.emit()
	await process_frame
	_check(room.menu_teste == null and not room.busy and room.dialog_text.text.contains("Miguel: d20"), "rola quem o jogador escolheu e o texto mostra o dado")
	_check(TestePericia.feito("necrotorio_tutu_pescoco"), "o resultado fica salvo")
	room.queue_free()
	await process_frame


# A tela do d20 rolando (Léo, 22/11): o dado gira, para com o número sorteado virado para a frente, mostra a conta e só fecha
# com o clique depois do resultado.
func _tela_do_dado() -> void:
	var d := DadoD20.new()
	_check(d.faces.size() == 20 and d.verts.size() == 12, "o dado é um icosaedro: 20 faces e 12 vértices")
	var soma_ok := true
	for i in d.faces.size():
		for j in d.faces.size():
			if d.normais[i].dot(d.normais[j]) < -0.99 and d.numeros[i] + d.numeros[j] != 21:
				soma_ok = false
	var vistos := {}
	for n in d.numeros:
		vistos[n] = true
	_check(soma_ok and vistos.size() == 20, "faces opostas somam 21 e os números de 1 a 20 aparecem uma vez")
	for valor in [1, 7, 20]:
		d.parado(valor)
		var frente := -1
		var melhor := -2.0
		var b := Basis(d.q)
		for i in d.faces.size():
			var z := (b * d.normais[i]).z
			if z > melhor:
				melhor = z
				frente = i
		_check(d.numeros[frente] == valor and melhor > 0.99, "o dado para com o %d virado para a frente" % valor)
	var tela := TelaD20.new()
	root.add_child(tela)
	var r := {"pericia": "ocultismo", "quem": "Miguel", "dt": 12, "dado": 14, "bonus": 5, "total": 19, "passou": true}
	var fechou := [false]
	tela.fechada.connect(func(): fechou[0] = true)
	tela.montar(r, 0.4)
	var antes: Quaternion = tela.dado.q
	for i in 8:
		await process_frame
	_check(not tela.dado.q.is_equal_approx(antes), "o dado gira enquanto rola")
	tela._clique(_clique_mouse())
	_check(not fechou[0], "não fecha antes do resultado")
	await create_timer(1.3).timeout
	_check(tela._faixa.text == "SUCESSO" and tela._fichas.get_child_count() == 2, "mostra as fichas da conta e a faixa SUCESSO")
	tela._clique(_clique_mouse())
	await process_frame
	_check(fechou[0], "o clique depois do resultado fecha a tela")
	_check(TelaD20.resultado_texto({"dado": 1, "passou": false}) == "FALHA CRÍTICA" and TelaD20.resultado_texto({"dado": 20, "passou": true}) == "SUCESSO CRÍTICO", "20 e 1 naturais têm faixa de crítico")


func _clique_mouse() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.pressed = true
	e.button_index = MOUSE_BUTTON_LEFT
	return e


func _no_jogo() -> void:
	await _escolha()
	await _tela_do_dado()
	Missao1.reiniciar()
	Missao1.marcar("necrotorio_chegada")
	Missao1.marcar("teste_necrotorio_tutu_pescoco_passou")
	var room = await _abrir("necrotorio")
	room._inspect("tutu_pescoco")
	_check(room.dialog_text.text.contains("Ocultismo") and room.dialog_text.text.contains("DT 12") and room.dialog_text.text.contains("Sangue e de Morte"), "necrotério: passou no teste = texto completo dos pontos no pescoço")
	room.queue_free()
	await process_frame
	Missao1.reiniciar()
	Missao1.marcar("necrotorio_chegada")
	Missao1.marcar("teste_necrotorio_tutu_pescoco_falhou")
	room = await _abrir("necrotorio")
	room._inspect("tutu_pescoco")
	_check(room.dialog_text.text.contains("DT 12") and not room.dialog_text.text.contains("Sangue e de Morte") and room.dialog_text.text.contains("agulha"), "necrotério: falhou = só o que se vê")
	room.queue_free()
	await process_frame
	Engine.time_scale = 8.0
	for falhou in [true, false]:
		Missao1.reiniciar()
		Missao1.marcar("geraldo_chegada")
		Missao1.marcar("geraldo_conversa")
		Missao1.marcar("teste_casa_geraldo_geraldo_1977_%s" % ("falhou" if falhou else "passou"))
		room = await _abrir("casa_geraldo")
		room._inspect("geraldo_1977")
		room._close_dialog()
		for i in 600:
			await process_frame
			if room.dialog_layer.visible:
				room._close_dialog()
			if Missao1.tem("geraldo_1977") and room.mode == room.Mode.EXPLORATION and not room.busy:
				break
		_check(Missao1.tem("geraldo_1977") and room.mode == room.Mode.EXPLORATION, "Geraldo (%s): a conversa toca e devolve o controle" % ("falhou" if falhou else "passou"))
		room.queue_free()
		await process_frame
	Missao1.reiniciar()
	Missao1.marcar("geraldo_chegada")
	Missao1.marcar("geraldo_conversa")
	room = await _abrir("casa_geraldo")
	room._inspect("geraldo_1977")
	room._close_dialog()
	for i in 120:
		await process_frame
		if room.menu_teste != null:
			break
	_check(room.menu_teste != null and room.menu_teste.find_children("*", "Button", true, false).size() == room.party.size() * 2, "Geraldo: a escolha oferece cada agente com Diplomacia e Intimidação")
	room.menu_teste.find_children("*", "Button", true, false)[0].pressed.emit()
	for i in 600:
		await process_frame
		if room.dialog_layer.visible:
			room._close_dialog()
		if Missao1.tem("geraldo_1977") and room.mode == room.Mode.EXPLORATION and not room.busy and room.menu_teste == null:
			break
	_check(TestePericia.feito("casa_geraldo_geraldo_1977") and room.mode == room.Mode.EXPLORATION, "Geraldo: depois da escolha o dado rola e a conversa toca")
	room.queue_free()
	await process_frame
	Engine.time_scale = 1.0


# Diferença por classe (Léo, 26/11): cada classe soma +2 numa perícia, e o Miguel não é o melhor em tudo.
func _classes() -> void:
	var g := [{"nome": "Fernando", "atributos": {"INT": 1, "PRE": 1}, "classe": "combatente"},
		{"nome": "Miguel", "atributos": {"INT": 3, "PRE": 2}, "classe": "ocultista"},
		{"nome": "Nikolai", "atributos": {"INT": 2, "PRE": 1}, "classe": "especialista"}]
	_check(TestePericia.melhor(["intimidacao"], g)["quem"] == "Fernando" and TestePericia.melhor(["intimidacao"], g)["bonus"] == 3, "Combatente soma +2 em Intimidação e vence o Miguel")
	_check(TestePericia.melhor(["tecnologia"], g)["quem"] == "Nikolai" and TestePericia.melhor(["tecnologia"], g)["bonus"] == 4, "Especialista soma +2 em Tecnologia e vence o Miguel")
	_check(TestePericia.melhor(["ocultismo"], g)["quem"] == "Miguel" and TestePericia.melhor(["ocultismo"], g)["bonus"] == 5, "Ocultista soma +2 em Ocultismo")
	_check(TestePericia.bonus("ocultismo", {"INT": 2}, "combatente") == 2, "fora da perícia da classe só vale o atributo")


# Os testes do mapa de 20/11 que entraram no jogo (26/11): árvore (duas camadas), livro da cidade (duas camadas), computador,
# gravador, livro do subsolo e a JÃºlia (conversa: falhou = superficial ou negativo).
func _testes_novos() -> void:
	Missao1.reiniciar()
	var parque = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(parque)
	await process_frame
	Missao1.marcar("teste_%s_arvore_simbolo_rastros_passou" % Missao1.local)
	Missao1.marcar("teste_%s_arvore_simbolo_invocacao_falhou" % Missao1.local)
	parque.seen_clues.append("caio")  # a árvore só abre depois do Caio
	parque._inspect("arvore_simbolo")
	var t: String = parque.dialog_text.text
	_check(t.contains("giz e cinzas") and t.contains("DT 12") and t.contains("DT 15") and not t.contains("símbolos de Invocação"), "árvore: passou a primeira camada e falhou a segunda")
	parque.queue_free()
	await process_frame
	var casos := [
		["biblioteca", "mesa_leitura", ["beatificacao_passou", "padrao_passou"], "beata", "mesmo padrão"],
		["delegacia_17h", "computador_recepcao", ["passou"], "apagado", ""],
		["delegacia_21h", "gravador_ghular", ["passou"], "gravava a delegacia", ""],
		["subsolo", "livro_faltando", ["passou"], "sete sacrifícios", ""]]
	for caso in casos:
		for passou in [true, false]:
			Missao1.reiniciar()
			for m in caso[2]:
				var marca: String = m
				if not passou:
					marca = marca.replace("passou", "falhou")
				if marca == "passou" or marca == "falhou":
					marca = "teste_%s_%s_%s" % [caso[0], caso[1], marca]
				else:
					marca = "teste_%s_%s_%s" % [caso[0], caso[1], marca]
				Missao1.marcar(marca)
			var room = await _abrir(str(caso[0]))
			room._inspect(str(caso[1]))
			var txt: String = room.dialog_text.text
			if passou:
				_check(txt.contains(str(caso[3])) and (str(caso[4]) == "" or txt.contains(str(caso[4]))), "%s: passou = texto completo" % caso[1])
			else:
				_check(txt.contains("DT") and not txt.contains(str(caso[3])), "%s: falhou = só o superficial" % caso[1])
			room.queue_free()
			await process_frame
	# A JÃºlia: Intuição DT 8 e, pressionada, Diplomacia ou Intimidação DT 12; falhou = ela diz pouco ou se fecha.
	for cena in ["julia_aflita", "julia_aflita_nada", "julia_revela", "julia_revela_nada"]:
		_check(CenaRoteiro.existe(cena), "a cena %s existe" % cena)
	Missao1.reiniciar()
	var bib = await _abrir("biblioteca")
	bib._inspect("julia_pressionar")
	_check(bib.dialog_text.text.contains("começar por uma conversa"), "a JÃºlia: só dá para pressionar depois da conversa")
	bib.queue_free()
	await process_frame


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
