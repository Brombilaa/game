extends SceneTree
# Teste headless do SaveSlots. Rodar com:
#   godot --headless --path . -s tests/test_save_slots.gd

const DIR := "user://test_save_slots"

var failures := 0


func _init() -> void:
	_cleanup()

	_check(SaveSlots.ids() == ["auto", "manual_1", "manual_2", "manual_3"], "um automático e 3 manuais")
	_check(SaveSlots.can_save_manual(false), "salva manual fora de combate")
	_check(not SaveSlots.can_save_manual(true), "não salva manual em combate")

	# Slot inexistente é recusado.
	_check(SaveSlots.save("manual_4", {"current_area": "x"}, DIR) == ERR_INVALID_PARAMETER, "recusa quarto slot manual")
	_check(SaveSlots.load_slot("manual_4", DIR).is_empty(), "slot inválido não carrega")

	# Tudo vazio no começo.
	var empty := SaveSlots.list(DIR)
	_check(empty.size() == 4 and empty.all(func(s): return s["empty"]), "slots começam vazios")

	# Automático e manual são independentes.
	_check(SaveSlots.save(SaveSlots.AUTO, {"current_area": "test_room"}, DIR) == OK, "grava o automático")
	_check(SaveSlots.save(SaveSlots.manual(2), {"current_area": "roma"}, DIR) == OK, "grava o manual 2")
	_check(SaveSlots.load_slot(SaveSlots.AUTO, DIR).get("current_area") == "test_room", "carrega o automático")
	_check(SaveSlots.load_slot(SaveSlots.manual(2), DIR).get("current_area") == "roma", "carrega o manual 2")

	var listed := SaveSlots.list(DIR)
	_check(not listed[0]["empty"] and listed[0]["area"] == "test_room", "lista mostra a área do automático")
	_check(listed[0]["saved_at"] > 0, "lista mostra quando salvou")
	_check(listed[1]["empty"] and listed[3]["empty"], "manuais 1 e 3 seguem vazios")
	_check(listed[2]["area"] == "roma", "lista mostra a área do manual 2")

	_check(listed[0]["status"] == SaveGame.OK_STATUS and listed[1]["status"] == SaveGame.EMPTY, "estado do slot: ok e vazio")
	_check(SaveSlots.latest(DIR) != "", "há um slot mais recente para o Continuar")

	# Novo autosave substitui o anterior.
	SaveSlots.save(SaveSlots.AUTO, {"current_area": "bunker"}, DIR)
	_check(SaveSlots.load_slot(SaveSlots.AUTO, DIR).get("current_area") == "bunker", "autosave novo substitui")

	_cleanup()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _cleanup() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(DIR)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
