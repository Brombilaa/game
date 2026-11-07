extends SceneTree
# Garante que todo caminho "res://assets/..." escrito no código e nos dados existe de verdade.
# Protege a organização da arte (docs/convencoes-arte.md). Rodar com:
#   godot --headless --path . -s tests/test_art_layout.gd

var failures := 0
const IGNORAR := ["res://assets/audio/nao_existe.ogg"]  # usado de propósito em test_audio_director


func _init() -> void:
	var rx := RegEx.new()
	rx.compile("res://assets/[A-Za-z0-9_./-]+\\.[A-Za-z0-9]+")
	var arquivos: Array[String] = []
	for pasta in ["res://scripts", "res://data", "res://tests"]:
		_coletar(pasta, arquivos)
	var vistos := 0
	for arq in arquivos:
		var texto := FileAccess.get_file_as_string(arq)
		for m in rx.search_all(texto):
			var caminho := m.get_string()
			if caminho in IGNORAR or arq.ends_with("test_art_layout.gd"):
				continue
			vistos += 1
			_check(FileAccess.file_exists(caminho) or ResourceLoader.exists(caminho), "%s -> %s existe" % [arq, caminho])
	_check(vistos > 20, "caminhos de arte encontrados (%d)" % vistos)
	# Pastas legadas só podem conter o que o nome diz.
	_check(DirAccess.dir_exists_absolute("res://assets/sprites/personagens/legado_2d"), "pasta legado_2d existe")
	_check(not FileAccess.file_exists("res://assets/sprites/ui/inventario_moldura.png"), "moldura do inventário fica em ui/inv/")
	print("Falhas: %d" % failures if failures > 0 else "OK: layout de arte")
	quit(1 if failures > 0 else 0)


func _coletar(pasta: String, saida: Array[String]) -> void:
	var d := DirAccess.open(pasta)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() in ["gd", "json"]:
			saida.append(pasta + "/" + f)
	for sub in d.get_directories():
		_coletar(pasta + "/" + sub, saida)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)
