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
	var strokes := MainMenu.sigil_strokes()
	_check(strokes.size() > 10, "o símbolo tem vários traços")
	for s in strokes:
		_check(s["points"].size() >= 2, "cada traço tem pelo menos 2 pontos")
		_check(s["delay"] + MainMenu.DRAW_SECONDS <= MainMenu.INTRO_END + 0.1, "o traço termina dentro da abertura")
	_check(MainMenu.sigil_blots().size() > 0, "o símbolo tem manchas de tinta")

	var line := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	_check(MainMenu.partial(line, 0.0).is_empty(), "traço não começado não desenha nada")
	_check(MainMenu.partial(line, 0.25)[-1].is_equal_approx(Vector2(5, 0)), "um quarto do traço para no meio do primeiro trecho")
	_check(MainMenu.partial(line, 1.0)[-1].is_equal_approx(Vector2(10, 10)), "traço completo chega ao fim")

	_check(MainMenu.stroke_progress(0.0, 0.5) == 0.0, "traço espera a sua vez")
	_check(MainMenu.stroke_progress(10.0, 0.5) == 1.0, "traço termina")
	_check(MainMenu.letter_alpha(0.0, 0) == 0.0 and MainMenu.letter_alpha(MainMenu.INTRO_END, 13) == 1.0, "letras surgem durante a abertura")
	_check(MainMenu.letter_alpha(2.5, 0) > MainMenu.letter_alpha(2.5, 5), "letras surgem uma a uma, da esquerda para a direita")
	_check(MainMenu.menu_alpha(0.0) == 0.0 and MainMenu.menu_alpha(MainMenu.INTRO_END) == 1.0, "menu aparece no fim da abertura")

	var flame := MainMenu.flame_points(Vector2(10, 50), 6.0, 26.0, 1.0)
	_check(flame.size() == 20, "chama tem o contorno completo")
	_check(flame[0].y < 30.0 and flame[10].is_equal_approx(Vector2(10, 50)), "chama sobe a partir do pavio")
	_check(not Geometry2D.triangulate_polygon(flame).is_empty(), "contorno da chama é um polígono válido")

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
	_check(menu.bg_tex == null or ResourceLoader.exists(MainMenu.BG_IMAGE), "sem a arte do fundo, a mesa é desenhada por código")
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
	await process_frame
	menu.close_panel()

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
