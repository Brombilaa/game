class_name SaveGame
extends RefCounted
# Formato do arquivo de save: JSON com envelope de versão.
#   { "version": 1, "saved_at": <unix>, "data": { ... } }
# "data" só aceita tipos JSON (Dictionary, Array, String, número, bool, null).
# JSON não distingue int de float: ao ler, todo número volta como float.
# A política (automático/manual, slots, checkpoints) ainda está PENDENTE no GDD;
# este módulo só grava e lê um arquivo, sem decidir quando nem quantos.

const FORMAT_VERSION := 1


static func to_json(data: Dictionary) -> String:
	return JSON.stringify({
		"version": FORMAT_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"data": data,
	}, "\t")


# Devolve o conteúdo de "data", ou {} se o texto for inválido ou de versão
# desconhecida (save mais novo que o jogo).
static func from_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed = json.data
	if not parsed is Dictionary:
		return {}
	if not parsed.get("version") is float or not parsed.get("data") is Dictionary:
		return {}
	var version := int(parsed["version"])
	if version < 1 or version > FORMAT_VERSION:
		return {}
	return _migrate(parsed["data"], version)


# Gravação atômica: escreve em .tmp e só então substitui o arquivo. O save
# anterior fica como .bak, para o caso de o principal corromper.
static func write(path: String, data: Dictionary) -> Error:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json(data))
	file.close()
	if FileAccess.file_exists(path):
		var err := DirAccess.rename_absolute(path, path + ".bak")
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp, path)


# Lê o save; se o principal faltar ou estiver corrompido, tenta o .bak.
# Devolve {} quando não há save utilizável.
static func read(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data := from_json(FileAccess.get_file_as_string(candidate))
		if not data.is_empty():
			return data
	return {}


# Converte saves antigos para o formato atual, uma versão por vez.
static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Ainda só existe a versão 1. Ao criar a 2: if from_version < 2: ...
	return data
