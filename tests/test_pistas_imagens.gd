extends SceneTree
# Teste headless das imagens de pista (modelo A do Léo, 22/11/2026): toda `inspecao` e toda ficha de `inspecoes` dos
# cenários aponta para um arquivo que existe; a pista das fichas tem 7 (uma por desaparecido) e a última é a da pista.
# Rodar com:
#   godot --headless --path . -s tests/test_pistas_imagens.gd

var failures := 0


func _initialize() -> void:
	var com_imagem := 0
	for local in ["delegacia_17h", "delegacia_21h", "subsolo", "biblioteca", "fazenda", "cripta", "celeiro"]:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cenarios/%s.json" % local))
		for c in d["pistas"]:
			var caminhos: Array = []
			if str(c.get("inspecao", "")) != "":
				caminhos.append(str(c["inspecao"]))
			for f in c.get("inspecoes", []):
				caminhos.append(str(f["imagem"]))
				_check(str(f["titulo"]) != "" and str(f["texto"]) != "", "ficha com título e texto: " + str(c["id"]))
			for p in caminhos:
				_check(ResourceLoader.exists(p), "imagem existe: %s (%s)" % [p, c["id"]])
			if not caminhos.is_empty():
				com_imagem += 1
			if str(c["id"]) == "ficha_desaparecidos":
				_check(c["inspecoes"].size() == 7, "sete fichas, uma por desaparecido")
				_check(c["inspecao"] == c["inspecoes"][6]["imagem"], "a imagem da pista é a última ficha")
	_check(com_imagem >= 5, "pistas de documento com imagem: %d" % com_imagem)
	print("Falhas: %d" % failures if failures > 0 else "OK: test_pistas_imagens")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		return
	failures += 1
	print("FALHOU: " + what)
