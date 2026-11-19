extends SceneTree
# Confere que as teclas copiadas em Atalhos (usadas pelo mapa de controles) batem com as do jogo. Rodar com:
#   godot --headless --path . -s tests/test_atalhos.gd

var failures := 0


func _init() -> void:
	_check(Atalhos.ITEM_KEYS == RoomItems.KEY_LABELS, "as teclas dos itens em Atalhos batem com RoomItems.KEY_LABELS")
	_check(Atalhos.RITUAL_KEYS == RoomActionBar.RITUAL_KEYS, "as teclas dos rituais em Atalhos batem com RoomActionBar.RITUAL_KEYS")
	_check(Atalhos.ITEM_TIPS == RoomActionBar.ITEM_TIPS, "as dicas dos itens em Atalhos batem com RoomActionBar.ITEM_TIPS")
	for k in RoomRitual.KEYS:
		_check(RoomActionBar.RITUAL_KEYS.values().has(OS.get_keycode_string(k)), "a tecla de ritual %s está no mapa" % OS.get_keycode_string(k))
	for k in RoomItems.KEYS:
		_check(RoomItems.KEY_LABELS.values().has(OS.get_keycode_string(k)), "a tecla de item %s está no mapa" % OS.get_keycode_string(k))
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok    - " + label)
	else:
		failures += 1
		print("FALHA - " + label)
