class_name GameData
extends RefCounted
# Carrega e valida os dados de balanceamento de data/ (um JSON por tabela, ver data/README.md).
# Valores null são PENDENTES no GDD: são aceitos, mas listados em `pending` para revisão.
# Uso:
#   var data := GameData.new()
#   if not data.load_dir():
#       push_error("\n".join(data.errors))
#   var pistola := data.get_entry("armas", "pistola_teste")

const Schema := preload("res://scripts/core/data_schema.gd")

var errors: Array[String] = []
var pending: Array[String] = []      # "tabela.id.campo" com valor null
var provisional: Array[String] = []  # "tabela.id" marcados com "provisorio": true
var rules := {}
var _tables := {}  # tabela -> {id: entrada}


# Lê cada <tabela>.json de `dir` e valida tudo. Retorna true se não houver erros.
func load_dir(dir: String = "res://data") -> bool:
	var sources := {}
	var read_errors: Array[String] = []
	for table in Schema.TABLES:
		var path := dir.path_join(table + ".json")
		if not FileAccess.file_exists(path):
			read_errors.append("%s: arquivo não encontrado" % path)
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			read_errors.append("%s:%d: JSON inválido: %s" % [path, json.get_error_line(), json.get_error_message()])
			continue
		sources[table] = json.data
	load_from(sources)
	read_errors.append_array(errors)
	errors = read_errors
	return errors.is_empty()


# Valida dados já lidos: {tabela: conteúdo do JSON}. Tabelas ausentes viram erro.
func load_from(sources: Dictionary) -> bool:
	errors.clear()
	pending.clear()
	provisional.clear()
	rules = {}
	_tables = {}
	for table in Schema.TABLES:
		if not sources.has(table):
			errors.append("%s: tabela ausente" % table)
		elif table == "regras":
			rules = _read_rules(sources[table])
		else:
			_tables[table] = _read_table(table, sources[table])
	_check_refs()
	return errors.is_empty()


func get_entry(table: String, id: String) -> Dictionary:
	return _tables.get(table, {}).get(id, {})


func has_entry(table: String, id: String) -> bool:
	return _tables.get(table, {}).has(id)


func ids(table: String) -> Array:
	return _tables.get(table, {}).keys()


func rule(key: String) -> Variant:
	return rules.get(key)


func _read_rules(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("regras: esperado um objeto")
		return {}
	return _read_fields("regras", raw, Schema.FIELDS["regras"], {})


func _read_table(table: String, raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_ARRAY:
		errors.append("%s: esperado uma lista de entradas" % table)
		return out
	for i in raw.size():
		var entry: Variant = raw[i]
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("id")) != TYPE_STRING or entry["id"] == "":
			errors.append("%s[%d]: entrada sem \"id\" de texto" % [table, i])
			continue
		var where := "%s.%s" % [table, entry["id"]]
		if out.has(entry["id"]):
			errors.append("%s: id repetido" % where)
			continue
		var fields := _read_fields(where, entry, Schema.FIELDS[table], Schema.OPTIONAL)
		if fields.get("provisorio", false):
			provisional.append(where)
		out[entry["id"]] = fields
	return out


# Confere campos obrigatórios, desconhecidos e tipos. Chaves começando com "_" são comentários.
func _read_fields(where: String, raw: Dictionary, spec: Dictionary, optional: Dictionary) -> Dictionary:
	var out := {}
	for key in raw:
		if str(key).begins_with("_"):
			continue
		if not spec.has(key) and not optional.has(key):
			errors.append("%s.%s: campo desconhecido" % [where, key])
	for key in spec:
		if not raw.has(key):
			errors.append("%s.%s: campo obrigatório ausente" % [where, key])
			continue
		out[key] = _read_value("%s.%s" % [where, key], raw[key], spec[key])
	for key in optional:
		if raw.has(key):
			out[key] = _read_value("%s.%s" % [where, key], raw[key], optional[key])
	return out


func _read_value(where: String, v: Variant, f: Dictionary) -> Variant:
	if v == null:
		if f["nulo"]:
			pending.append(where)
		else:
			errors.append("%s: não pode ser null" % where)
		return null
	match f["t"]:
		"int":
			if not _is_int(v):
				return _bad(where, "inteiro", v)
			_check_limits(where, v, f)
			return int(v)
		"num":
			if not _is_num(v):
				return _bad(where, "número", v)
			_check_limits(where, v, f)
			return float(v)
		"texto":
			if typeof(v) != TYPE_STRING:
				return _bad(where, "texto", v)
			if f.has("valores") and not v in f["valores"]:
				errors.append("%s: \"%s\" não é um de %s" % [where, v, f["valores"]])
			return v
		"bool":
			if typeof(v) != TYPE_BOOL:
				return _bad(where, "true/false", v)
			return v
		"faixa":
			var whole: bool = f.get("inteiro", false)
			if typeof(v) != TYPE_ARRAY or v.size() != 2 or not (_is_int(v[0]) if whole else _is_num(v[0])) \
					or not (_is_int(v[1]) if whole else _is_num(v[1])):
				return _bad(where, "[min, max]" + (" inteiros" if whole else ""), v)
			if v[0] > v[1]:
				errors.append("%s: mínimo maior que o máximo" % where)
			return [int(v[0]), int(v[1])] if whole else [float(v[0]), float(v[1])]
		"tamanho":
			if typeof(v) != TYPE_ARRAY or v.size() != 2 or not _is_int(v[0]) or not _is_int(v[1]) or v[0] < 1 or v[1] < 1:
				return _bad(where, "[largura, altura] inteiros positivos", v)
			return [int(v[0]), int(v[1])]
		"lista":
			if typeof(v) != TYPE_ARRAY or v.any(func(x): return typeof(x) != TYPE_STRING):
				return _bad(where, "lista de textos", v)
			return v
		"dict_lista":
			if typeof(v) != TYPE_ARRAY or v.any(func(x): return typeof(x) != TYPE_DICTIONARY):
				return _bad(where, "lista de objetos", v)
			return v
		"atributos":
			if typeof(v) != TYPE_DICTIONARY:
				return _bad(where, "objeto de atributos", v)
			var out := {}
			for key in v:
				out[key] = _read_value("%s.%s" % [where, key], v[key], {"t": "int", "nulo": true})
			return out
	errors.append("%s: tipo de esquema desconhecido \"%s\"" % [where, f["t"]])
	return null


# Ids referenciados (classe, arma, condição etc.) precisam existir na tabela indicada.
func _check_refs() -> void:
	for table in _tables:
		var spec: Dictionary = Schema.FIELDS[table]
		for id in _tables[table]:
			var entry: Dictionary = _tables[table][id]
			for key in spec:
				var value: Variant = entry.get(key)
				if value == null:
					continue
				if spec[key]["t"] == "atributos":
					_check_attribute_keys("%s.%s.%s" % [table, id, key], value)
				elif spec[key].has("ref"):
					for target in (value if value is Array else [value]):
						if not has_entry(spec[key]["ref"], target):
							errors.append("%s.%s.%s: \"%s\" não existe em %s" % [table, id, key, target, spec[key]["ref"]])
	for id in ids("arvores"):
		var tree := get_entry("arvores", id)
		if tree["tipo"] == "exclusiva" and tree["personagem"] == null:
			errors.append("arvores.%s: árvore exclusiva precisa de \"personagem\"" % id)


func _check_attribute_keys(where: String, value: Dictionary) -> void:
	for key in value:
		if not has_entry("atributos", key):
			errors.append("%s.%s: atributo desconhecido" % [where, key])
	for key in ids("atributos"):
		if not value.has(key):
			errors.append("%s.%s: atributo ausente" % [where, key])


func _check_limits(where: String, v: float, f: Dictionary) -> void:
	if f.has("min") and v < f["min"]:
		errors.append("%s: %s é menor que o mínimo %s" % [where, v, f["min"]])
	if f.has("max") and v > f["max"]:
		errors.append("%s: %s é maior que o máximo %s" % [where, v, f["max"]])


func _bad(where: String, expected: String, v: Variant) -> Variant:
	errors.append("%s: esperado %s, veio %s" % [where, expected, JSON.stringify(v)])
	return null


# O JSON da Godot lê todo número como float; inteiro é float sem parte fracionária.
static func _is_int(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v))


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
