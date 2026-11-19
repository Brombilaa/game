extends SceneTree
# Confere que as teclas copiadas em Atalhos (usadas pelo mapa de controles) batem com as do jogo. Os scripts da sala
# são lidos a partir da sala já carregada (não por nome de classe), para o teste não depender da ordem de carga
# dos scripts. Rodar com:
#   godot --headless --path . -s tests/test_atalhos.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var items: Dictionary = room.room_items.get_script().get_script_constant_map()
	var bar: Dictionary = room.action_bar.get_script().get_script_constant_map()
	var rituals: Dictionary = room.room_ritual.get_script().get_script_constant_map()
	_check(Atalhos.ITEM_KEYS == items["KEY_LABELS"], "as teclas dos itens em Atalhos batem com RoomItems.KEY_LABELS")
	_check(Atalhos.RITUAL_KEYS == bar["RITUAL_KEYS"], "as teclas dos rituais em Atalhos batem com RoomActionBar.RITUAL_KEYS")
	_check(Atalhos.ITEM_TIPS == bar["ITEM_TIPS"], "as dicas dos itens em Atalhos batem com RoomActionBar.ITEM_TIPS")
	for k in rituals["KEYS"]:
		_check(Atalhos.RITUAL_KEYS.values().has(OS.get_keycode_string(k)), "a tecla de ritual %s está no mapa" % OS.get_keycode_string(k))
	for k in items["KEYS"]:
		_check(Atalhos.ITEM_KEYS.values().has(OS.get_keycode_string(k)), "a tecla de item %s está no mapa" % OS.get_keycode_string(k))
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok    - " + label)
	else:
		failures += 1
		print("FALHA - " + label)
