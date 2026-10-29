extends SceneTree
# Teste headless do SaveGame. Rodar com:
#   godot --headless --path . -s tests/test_save_game.gd

var failures := 0


func _init() -> void:
	var data := {
		"current_area": "test_room",
		"areas": {"test_room": {"doors": {"porta_central": true}}},
		"party": {"rafael": {"pv": 12, "san": 8}},
	}

	# Ida e volta pelo texto preserva os dados (números voltam como float).
	var back := SaveGame.from_json(SaveGame.to_json(data))
	_check(back.get("current_area") == "test_room", "ida e volta mantém texto")
	_check(back["areas"]["test_room"]["doors"]["porta_central"] == true, "ida e volta mantém porta aberta")
	_check(back["party"]["rafael"]["pv"] == 12.0, "número volta como float")

	# Texto inválido, sem envelope ou de versão futura: sem save.
	_check(SaveGame.from_json("isso não é json").is_empty(), "json inválido é ignorado")
	_check(SaveGame.from_json("{\"data\": {}}").is_empty(), "sem versão é ignorado")
	_check(SaveGame.from_json(JSON.stringify({"version": SaveGame.FORMAT_VERSION + 1, "data": {"a": 1}})).is_empty(), "versão futura é ignorada")

	# Gravar e ler do disco.
	var path := "user://test_save_game.json"
	_cleanup(path)
	_check(SaveGame.read(path).is_empty(), "sem arquivo não há save")
	_check(SaveGame.write(path, data) == OK, "grava o save")
	_check(SaveGame.read(path).get("current_area") == "test_room", "lê o save gravado")
	_check(not FileAccess.file_exists(path + ".tmp"), "não sobra arquivo temporário")

	# Segunda gravação guarda a anterior como .bak.
	_check(SaveGame.write(path, {"current_area": "roma"}) == OK, "regrava o save")
	_check(SaveGame.read(path).get("current_area") == "roma", "lê a versão nova")

	# Principal corrompido: cai no .bak.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{corrompido")
	f.close()
	_check(SaveGame.read(path).get("current_area") == "test_room", "save corrompido usa o .bak")
	_cleanup(path)

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _cleanup(path: String) -> void:
	for p in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
