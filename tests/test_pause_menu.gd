extends SceneTree
# Teste headless do menu de pausa: Esc pausa, Salvar grava nos slots manuais (com confirmação ao
# substituir), não salva em combate, Esc volta camada por camada. Rodar com:
#   godot --headless --path . -s tests/test_pause_menu.gd

const DIR := "user://test_pausa"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_cleanup()
	Progresso.autosave_ativo = false
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	await process_frame

	_check(room.can_pause(), "em exploração dá para pausar")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	room._unhandled_input(esc)
	await process_frame
	_check(paused, "Esc pausa o jogo")
	var layer: Node = room.get_node_or_null("Pausa")
	_check(layer != null, "o menu de pausa abre por cima da sala")
	var menu: PauseMenu = layer.get_child(0)
	menu.save_dir = DIR
	_check(menu.title_label.text == "PAUSADO", "título PAUSADO")
	_check(menu.items.size() == PauseMenu.PAUSE_ITEMS.size(), "seis itens")
	_check(menu.version_label.text.begins_with("PARQUE"), "o rodapé diz onde o grupo está")
	_check(not _row(menu, "save").disabled, "Salvar livre em exploração")
	_check(not room.can_pause(), "não abre uma segunda pausa por cima")

	# Salvar num slot vazio grava direto.
	menu.activate("save")
	_check(menu.panel == "save" and menu.save_slots.size() == SaveSlots.MANUAL_COUNT, "Salvar mostra os 3 slots manuais")
	room.party[0].pv = 7
	menu.save_to(0)
	var d := SaveSlots.load_slot(SaveSlots.manual(1), DIR)
	_check(d.get("current_area") == "parque", "o save manual guarda o lugar")
	_check(int(d["grupo"][0]["pv"]) == 7, "o save manual guarda o PV de agora")
	_check(menu.last_saved == SaveSlots.manual(1) and menu.last_error == OK, "o painel avisa que salvou")
	# Slot ocupado pede confirmação; Não mantém o save antigo, Sim substitui.
	room.party[0].pv = 5
	menu.save_to(0)
	_check(menu.confirming == "overwrite", "slot ocupado pede confirmação")
	menu.confirm(false)
	_check(int(SaveSlots.load_slot(SaveSlots.manual(1), DIR)["grupo"][0]["pv"]) == 7, "Não mantém o save antigo")
	menu.save_to(0)
	menu.confirm(true)
	_check(int(SaveSlots.load_slot(SaveSlots.manual(1), DIR)["grupo"][0]["pv"]) == 5, "Sim substitui o save")
	_check(not SaveSlots.load_slot(SaveSlots.AUTO, DIR).size() > 0, "Salvar não mexe no automático")

	# Esc: fecha o painel, depois a pausa.
	menu._back()
	_check(menu.panel == "" and paused, "Esc fecha o painel e o jogo segue pausado")
	menu.activate("menu")
	_check(menu.confirming == "menu", "Voltar ao menu pede confirmação")
	menu._back()
	_check(menu.confirming == "" and paused, "Esc fecha a pergunta")
	menu.activate("opts")
	_check(menu.panel == "opts", "Opções abre na pausa")
	menu._back()
	menu._back()
	await process_frame
	_check(not paused, "Esc no menu fecha a pausa e o jogo volta")
	_check(room.get_node_or_null("Pausa") == null, "o menu de pausa some")

	# Em combate, Salvar fica bloqueado.
	paused = true
	room.mode = room.Mode.COMBAT
	var m2: PauseMenu = PauseMenu.open_on(room)
	m2.save_dir = DIR
	await process_frame
	_check(_row(m2, "save").disabled, "Salvar bloqueado no combate")
	_check(m2.version_label.text.contains("COMBATE"), "o rodapé explica que é combate")
	m2.activate("save")
	_check(m2.panel == "", "Salvar no combate não abre o painel")
	room.mode = room.Mode.EXPLORATION  # antes de soltar a pausa: a sala não tem combate de verdade
	m2.close_pause()
	await process_frame
	room.mode = room.Mode.GAME_OVER
	_check(not room.can_pause(), "no Game Over não pausa")
	room.mode = room.Mode.EXPLORATION

	room.queue_free()
	await process_frame
	_cleanup()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _row(menu: PauseMenu, id: String) -> MainMenu.MenuRow:
	for r in menu.menu_rows:
		if r.id == id:
			return r
	return null


func _cleanup() -> void:
	for slot in SaveSlots.ids():
		for suffix in ["", ".bak", ".tmp"]:
			var p: String = SaveSlots.path_for(slot, DIR) + suffix
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   - ", what)
	else:
		failures += 1
		print("FALHA - ", what)
