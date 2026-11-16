extends SceneTree
# Teste headless da tela das fichas (4 pontos por agente antes da campanha). Rodar com:
#   godot --headless --path . -s tests/test_tela_fichas.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Ficha.reiniciar()
	var tela: TelaFichas = load("res://scenes/menu/fichas.tscn").instantiate()
	root.add_child(tela)
	await process_frame
	await process_frame
	_check(tela.pronto(), "abre com a distribuição sugerida, já pronta")
	_check(tela.fichas["nikolai"]["AGI"] == 3, "Nikolai sugerido com AGI 3")
	tela.zerar()
	_check(not tela.pronto() and tela.restantes("fernando") == 4, "zerar devolve os 4 pontos de cada um")
	_check(not tela.comecar(), "não começa com pontos sobrando")
	await process_frame  # redesenha e remonta as áreas clicáveis
	# Clique de verdade: o "+" do Vigor do agente atual.
	var mais: Array = tela._hits.filter(func(h: Array) -> bool: return h[1] == "mais" and h[2] == "VIG")
	_check(mais.size() == 1, "botão + do Vigor está na tela")
	if mais.is_empty():
		quit(1)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = (mais[0][0] as Rect2).get_center()
	tela._gui_input(ev)
	_check(tela.fichas["fernando"]["VIG"] == 2, "clicar no + sobe o Vigor do Fernando")
	tela.ajustar("fernando", "VIG", 1)
	_check(not tela.ajustar("fernando", "VIG", 1), "não passa de 3")
	tela.trocar(1)
	_check(tela.atual == "nikolai", "Tab troca para o Nikolai")
	tela.sugestao()
	tela.fichas["miguel"] = {"VIG": 1, "FOR": 1, "INT": 3, "AGI": 1, "PRE": 3}
	_check(tela.pronto(), "com os 4 pontos gastos nos três, pode começar")
	_check(tela.comecar(), "começa a investigação")
	_check(Ficha.escolhas["miguel"]["PRE"] == 3 and Ficha.escolhas.size() == 3, "as escolhas ficam para a campanha")
	var cfg := CombatConfig.load_file()
	var m := cfg.make_agent("miguel", Vector2.ZERO)
	_check(m.max_san == 24 and m.max_pv == 13, "Miguel com PRE 3 e VIG 1: 24 SAN e 13 PV")
	Ficha.reiniciar()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
