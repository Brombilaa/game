extends SceneTree
# Teste headless do menu inicial e das opções. Rodar com:
#   godot --headless --path . -s tests/test_main_menu.gd

const DIR := "user://test_main_menu"
const OPTIONS_PATH := "user://test_opcoes.cfg"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_cleanup()
	_test_intro()
	_test_options()
	await _test_sem_save()
	await _test_scene()
	_cleanup()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _test_intro() -> void:
	_check(MainMenu.item_alpha(0.0, 0) == 0.0, "os itens começam escondidos")
	_check(MainMenu.item_alpha(MainMenu.INTRO_END, MainMenu.ITEMS.size()) == 1.0, "todos os itens aparecem até o fim da abertura")
	_check(MainMenu.item_alpha(1.6, 0) > MainMenu.item_alpha(1.6, 3), "os itens entram um depois do outro")
	_check(MainMenu.ease_out(0.5) > 0.5, "a entrada desacelera no fim")
	var fundo := MenuFundoArvore.new()
	fundo.animate = false
	root.add_child(fundo)
	fundo._tree_rng = 31
	var a1 := fundo._tr()
	fundo._tree_rng = 31
	_check(is_equal_approx(fundo._tr(), a1), "a árvore do fundo tem sempre a mesma forma")
	var x0: float = fundo._crows[0]["x"]
	fundo.t = 1.0
	fundo._step(0.5)
	_check(fundo._crows[0]["x"] > x0, "os corvos atravessam o céu")
	fundo.queue_free()

	_check(MainMenu.area_label("test_room") == "Sala de teste", "nome amigável da área")
	_check(MainMenu.area_label("") != "", "área vazia ainda tem texto")
	_check(MainMenu.slot_label({"rotulo": "FAZENDA GHULAR · 23h"}) == "Fazenda Ghular · 23h", "rótulo do lugar fica legível")
	_check(MainMenu.slot_label({"area": "parque"}) == "Parque", "sem rótulo, usa o nome da área")
	_check(MainMenu.slot_detail({"slot": "auto", "status": "ok", "saved_at": 0}).begins_with("Automático"), "o automático diz que é automático")
	_check(MainMenu.slot_detail({"slot": "manual_1", "status": SaveGame.NEWER}).contains("mais nova"), "save de versão mais nova avisa")
	_check(MainMenu.date_label(0) == "", "sem data quando o slot não tem horário")
	_check(MainMenu.date_label(1_800_000_000).begins_with("Salvo em "), "data do save formatada")


func _test_options() -> void:
	var o := GameOptions.load_from(OPTIONS_PATH)
	_check(is_equal_approx(o.volume("master"), GameOptions.DEFAULTS["master"]), "sem arquivo usa o padrão")
	o.set_volume("music", 1.7)
	_check(o.volume("music") == 1.0, "volume não passa de 100%")
	o.set_volume("sfx", -0.3)
	_check(o.volume("sfx") == 0.0, "volume não fica negativo")
	o.values["fullscreen"] = true
	_check(o.save(OPTIONS_PATH) == OK, "grava as opções")
	var back := GameOptions.load_from(OPTIONS_PATH)
	_check(back.volume("music") == 1.0 and back.volume("sfx") == 0.0 and back.values["fullscreen"] == true, "opções voltam iguais")
	back.apply()  # headless: só mexe no áudio


func _test_scene() -> void:
	SaveSlots.save(SaveSlots.manual(2), {"current_area": "test_room"}, DIR)
	SaveSlots.save(SaveSlots.AUTO, {"current_area": "test_room"}, DIR)
	var menu: MainMenu = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.save_dir = DIR
	menu.options_path = OPTIONS_PATH
	root.add_child(menu)
	await process_frame
	await process_frame
	_check(not menu.intro_done(), "começa na abertura")
	_check(menu.background != null and menu.curtain.color.a > 0.5, "a abertura começa no escuro, com o fundo da árvore")
	menu.skip_intro()
	_check(menu.intro_done(), "clique ou tecla pula a abertura")

	_check(menu.items[0][0] == "continue", "com save, Continuar é o primeiro item")
	_check(menu.continue_slot != "", "Continuar aponta para um slot")
	menu.activate("load")
	_check(menu.panel == "load", "Carregar abre o painel")
	_check(menu.slots.size() == 4, "mostra o automático e os 3 manuais")
	_check(menu.slots[0]["slot"] == "auto" and not menu.slots[0]["empty"], "o automático aparece primeiro")
	_check(menu.slots[1]["empty"] and not menu.slots[2]["empty"] and menu.slots[3]["empty"], "dos manuais, só o 2 está ocupado")
	_check(not menu.load_slot(1), "slot vazio não carrega")
	_check(not menu.load_slot(2) and not menu.starting, "save sem a missão não abre o jogo e o menu continua usável")
	var corrupt := FileAccess.open(SaveSlots.path_for(SaveSlots.manual(3), DIR), FileAccess.WRITE)
	corrupt.store_string("{ quebrado")
	corrupt.close()
	menu.refresh_slots()
	_check(menu.slots[3]["empty"] and menu.slots[3]["status"] == SaveGame.CORRUPT, "save corrompido é marcado como corrompido")
	_check(MainMenu.slot_detail(menu.slots[3]).contains("corrompido"), "o slot corrompido avisa em vez de dizer Vazio")
	await process_frame
	await process_frame
	menu.close_panel()
	_check(menu.panel == "", "Fechar volta ao menu")

	menu.activate("opts")
	_check(menu.panel == "opts", "Opções abre o painel")
	_check(menu.panel_rows.size() == MainMenu.OPTION_ROWS.size() + 1, "uma linha por opção, mais Fechar")
	var vs: bool = menu.options.values["vsync"]
	menu.change_option("vsync", 0.0)
	_check(menu.options.values["vsync"] != vs, "sincronia vertical liga e desliga")
	_check(GameOptions.load_from(OPTIONS_PATH).values["vsync"] == menu.options.values["vsync"], "a opção é gravada na hora")
	menu.change_option("vsync", 0.0)
	await process_frame
	menu._back()
	_check(menu.panel == "", "Esc ou botão direito fecham o painel")

	menu.activate("credits")
	_check(menu.panel == "credits", "Créditos abre o painel")
	await process_frame
	menu.close_panel()

	# Novo jogo com save pede confirmação; Não volta ao menu sem começar.
	menu.activate("new")
	_check(menu.confirming == "new" and menu.dialog.visible and not menu.starting, "Novo jogo com save pede confirmação")
	menu.confirm(false)
	_check(menu.confirming == "" and not menu.dialog.visible and not menu.starting, "Não cancela o novo jogo")
	menu.activate("quit")
	_check(menu.confirming == "quit", "Sair pede confirmação")
	menu._back()
	_check(menu.confirming == "", "Esc fecha a confirmação")

	# A tela desenha sem erro com o painel aberto e fechado.
	menu.activate("load")
	await process_frame
	menu.close_panel()
	await process_frame
	menu.queue_free()
	await process_frame


func _test_sem_save() -> void:
	var menu: MainMenu = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.save_dir = DIR
	menu.options_path = OPTIONS_PATH
	root.add_child(menu)
	await process_frame
	_check(menu.items[0][0] == "new" and menu.continue_slot == "", "sem save, não há Continuar")
	menu.queue_free()
	await process_frame


func _cleanup() -> void:
	DirAccess.remove_absolute(OPTIONS_PATH)
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(DIR)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok    - " + label)
	else:
		failures += 1
		print("FALHA - " + label)
