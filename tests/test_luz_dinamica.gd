extends SceneTree
# Teste headless da luz dinâmica (lanterna do líder e luzes vivas): só nas cenas noturnas há lanterna,
# L liga e desliga, o ambiente escurece e volta, as luzes do cenário tremem e o clarão de disparo some sozinho.
# Rodar com:
#   godot --headless --path . -s tests/test_luz_dinamica.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	await _noite()
	await _dia()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_luz_dinamica")
	quit(1 if failures > 0 else 0)


func _abrir(id: String) -> Node:
	Missao1.reiniciar()
	Missao1.local = id
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 6:
		await process_frame
	return room


func _noite() -> void:
	var room := await _abrir("delegacia_21h")
	var luz: LuzDinamica = room.luz_dinamica
	_check(luz != null and luz.noturno, "21h: cena noturna com luz dinâmica")
	_check(luz._spot != null and luz._spot.visible, "21h: lanterna acesa no início")
	var amb: Environment = luz._ambientes[0]
	var base: float = luz._ambiente_base[amb]
	for i in 10:
		await process_frame
	_check(amb.ambient_light_energy < base * 0.99, "21h: ambiente escurece com a lanterna")
	luz.alternar()
	for i in 60:
		await process_frame
	_check(not luz._spot.visible, "L apaga a lanterna")
	_check(is_equal_approx(amb.ambient_light_energy, base), "ambiente volta ao normal sem lanterna")
	luz.alternar()
	for i in 60:
		await process_frame
	_check(luz._spot.visible, "L acende de novo")
	var o: OmniLight3D = luz._omnis[0]
	var vistos := {}
	for i in 30:
		await process_frame
		vistos[snappedf(o.light_energy, 0.001)] = true
	_check(vistos.size() > 3, "as luzes do cenário tremem")
	var antes := luz._mundo.find_children("*", "OmniLight3D", true, false).size()
	luz.clarao(Vector3(1, 1, 1))
	_check(luz._mundo.find_children("*", "OmniLight3D", true, false).size() == antes + 1, "disparo acende um clarão")
	await create_timer(0.3).timeout
	await process_frame
	await process_frame
	_check(luz._claroes.is_empty(), "o clarão some em instantes")
	room.queue_free()
	await process_frame


func _dia() -> void:
	var room := await _abrir("delegacia_17h")
	var luz: LuzDinamica = room.luz_dinamica
	_check(luz != null and not luz.noturno and luz._spot == null, "17h: sem lanterna nem escurecimento")
	room.queue_free()
	await process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + msg)
