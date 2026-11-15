extends SceneTree
# Teste headless da luz e furtividade (modelo C): à noite a luz sobre o agente muda o alcance de percepção
# dos inimigos (sombra ×0,5, luz ×1,5), a lanterna acesa denuncia quem a carrega e de dia nada muda.
# Rodar com:
#   godot --headless --path . -s tests/test_luz_furtividade.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	_regra()
	await _noite()
	await _dia()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_luz_furtividade")
	quit(1 if failures > 0 else 0)


func _abrir(id: String) -> Node:
	Missao1.reiniciar()
	Missao1.local = id
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	return room


func _regra() -> void:
	var rules := CombatRules.new(CombatConfig.load_file())
	var e := Combatant.new()
	e.perception = 300.0
	var a := Combatant.new()
	_check(is_equal_approx(rules.perception_range(e, a), 300.0), "sem luz na regra (dia): 300 px")
	a.iluminacao = 0.0
	_check(is_equal_approx(rules.perception_range(e, a), 150.0), "sombra total: metade")
	a.iluminacao = 1.0
	_check(is_equal_approx(rules.perception_range(e, a), 450.0), "luz cheia: uma vez e meia")
	a.iluminacao = 0.0
	a.crouched = true
	_check(is_equal_approx(rules.perception_range(e, a), 75.0), "sombra e agachado: um quarto")
	_check(LuzFurtividade.estado_de(0.1) == LuzFurtividade.Estado.ESCONDIDO, "pouca luz = escondido")
	_check(LuzFurtividade.estado_de(0.9) == LuzFurtividade.Estado.VISIVEL, "muita luz = visível")
	_check(LuzFurtividade.estado_de(-1.0) == LuzFurtividade.Estado.DIA, "-1 = dia")
	_check(LuzFurtividade.queda(1.0, 8.0, 1.6) > LuzFurtividade.queda(4.0, 8.0, 1.6), "luz cai com a distância")
	_check(LuzFurtividade.queda(8.0, 8.0, 1.6) == 0.0, "fora do alcance não ilumina")


func _noite() -> void:
	var room := await _abrir("fazenda")
	var luz: LuzDinamica = room.luz_dinamica
	_check(luz.furtividade != null, "fazenda 23h: furtividade ligada")
	_check(is_equal_approx(room.player.iluminacao, 1.0), "lanterna acesa denuncia o líder")
	luz.alternar()
	room.player.pos = Vector2(-60.0, -60.0) * 64.0  # longe de qualquer luz do cenário
	await process_frame
	await process_frame
	_check(room.player.iluminacao >= 0.0 and room.player.iluminacao < LuzFurtividade.ESCONDIDO_ATE, "lanterna apagada no escuro: escondido")
	var e := Combatant.new()
	e.perception = 300.0
	_check(room.rules.perception_range(e, room.player) < 200.0, "no escuro o inimigo percebe de mais perto")
	var l: OmniLight3D = luz._omnis[0]
	room.player.pos = Vector2(l.global_position.x, l.global_position.z) * 64.0
	await process_frame
	await process_frame
	_check(room.player.iluminacao > LuzFurtividade.VISIVEL_DESDE, "sob uma lâmpada: visível (%.2f)" % room.player.iluminacao)
	room.queue_free()
	await process_frame


func _dia() -> void:
	var room := await _abrir("delegacia_17h")
	_check(room.luz_dinamica.furtividade == null, "17h: sem furtividade por luz")
	_check(room.player.iluminacao < 0.0, "17h: a luz não conta")
	room.queue_free()
	await process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + msg)
