class_name SaveGame
extends RefCounted
# Formato do arquivo de save: JSON com envelope de versão.
#   { "version": 1, "saved_at": <unix>, "data": { ... } }
# "data" só aceita tipos JSON (Dictionary, Array, String, número, bool, null).
# JSON não distingue int de float: ao ler, todo número volta como float.
# Este módulo só grava e lê um arquivo; slots ficam em SaveSlots e o conteúdo em Progresso.

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
	var envelope := _parse(text)
	return envelope.get("data", {})


# Envelope completo (version, saved_at, data) já migrado, ou {} se inválido.
static func _parse(text: String) -> Dictionary:
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
	parsed["data"] = _migrate(parsed["data"], version)
	return parsed


# Estado de um save, para o menu avisar em vez de só mostrar "Vazio":
#   OK (o principal ou o .bak lê), EMPTY (nenhum arquivo), NEWER (feito por uma versão mais nova do jogo),
#   CORRUPT (existe, mas nem o principal nem o .bak leem).
const OK_STATUS := "ok"
const EMPTY := "vazio"
const NEWER := "versao_nova"
const CORRUPT := "corrompido"


static func status(path: String) -> String:
	var found := false
	var newer := false
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		found = true
		var text := FileAccess.get_file_as_string(candidate)
		if not _parse(text).is_empty():
			return OK_STATUS
		var json := JSON.new()  # JSON.new().parse não suja o console como JSON.parse_string
		var parsed = json.data if json.parse(text) == OK else null
		if parsed is Dictionary and parsed.get("version") is float and int(parsed["version"]) > FORMAT_VERSION:
			newer = true
	if not found:
		return EMPTY
	return NEWER if newer else CORRUPT


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
	return read_envelope(path).get("data", {})


# Como read(), mas devolve o envelope inteiro (útil para mostrar saved_at).
static func read_envelope(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var envelope := _parse(FileAccess.get_file_as_string(candidate))
		if not envelope.is_empty():
			return envelope
	return {}


# Converte saves antigos para o formato atual, uma versão por vez.
static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Ainda só existe a versão 1. Ao criar a 2: if from_version < 2: ...
	return data
