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
	_regra()
	await _no_jogo()
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


func _no_jogo() -> void:
	await _escolha()
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


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
