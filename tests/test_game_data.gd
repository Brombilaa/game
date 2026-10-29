extends SceneTree
# Teste headless do carregador de data/. Rodar com:
#   godot --headless --path . -s tests/test_game_data.gd

const GameDataScript := preload("res://scripts/core/game_data.gd")
const TMP_DIR := "user://test_game_data"

var failures := 0


func _init() -> void:
	# Os arquivos reais de data/ carregam sem erros.
	var data := GameDataScript.new()
	_check(data.load_dir(), "data/ carrega sem erros")
	for e in data.errors:
		print("       ", e)
	_check(data.rule("pa_por_turno") == 3 and typeof(data.rule("pa_por_turno")) == TYPE_INT, "3 PA por turno, como inteiro")
	_check(is_equal_approx(data.rule("chance_acerto_min"), 0.05) and is_equal_approx(data.rule("chance_acerto_max"), 0.95), "acerto limitado a 5%–95%")
	_check(data.rule("metros_por_pa") == null and "regras.metros_por_pa" in data.pending, "metros por PA fica pendente")
	_check(data.ids("personagens").size() == 4, "quatro personagens")
	_check(data.get_entry("personagens", "fernando")["morte_roteirizada"], "Fernando tem morte roteirizada")
	_check(data.ids("condicoes").size() == 6, "seis condições")
	_check(data.ids("arvores").filter(func(id): return data.get_entry("arvores", id)["tipo"] == "compartilhada").size() == 5, "cinco árvores compartilhadas")
	var pistola := data.get_entry("armas", "pistola_teste")
	_check(pistola["dano"] == [8, 12] and typeof(pistola["dano"][0]) == TYPE_INT, "dano da pistola é faixa de inteiros")
	_check("armas.pistola_teste" in data.provisional, "arma de teste marcada como provisória")
	_check(data.get_entry("armas", "nao_existe").is_empty(), "id inexistente devolve vazio")

	# Erros de conteúdo: cada mudança abaixo precisa gerar o erro esperado.
	var base := _read_sources("res://data")
	_expect_error(base, func(s): s["armas"][0]["danno"] = [1, 2], "armas.pistola_teste.danno: campo desconhecido")
	_expect_error(base, func(s): s["armas"][0].erase("tipo"), "armas.pistola_teste.tipo: campo obrigatório ausente")
	_expect_error(base, func(s): s["armas"][0]["tipo"] = "laser", "armas.pistola_teste.tipo: \"laser\" não é um de")
	_expect_error(base, func(s): s["armas"][0]["carregador"] = "doze", "armas.pistola_teste.carregador: esperado inteiro")
	_expect_error(base, func(s): s["armas"][0]["carregador"] = 12.5, "armas.pistola_teste.carregador: esperado inteiro")
	_expect_error(base, func(s): s["armas"][0]["dano"] = [12, 8], "armas.pistola_teste.dano: mínimo maior que o máximo")
	_expect_error(base, func(s): s["armas"][0]["precisao_base"] = 1.5, "armas.pistola_teste.precisao_base: 1.5 é maior que o máximo")
	_expect_error(base, func(s): s["armas"][0]["nome"] = null, "armas.pistola_teste.nome: não pode ser null")
	_expect_error(base, func(s): s["armas"][0]["efeitos_criticos"] = ["congelado"], "\"congelado\" não existe em condicoes")
	_expect_error(base, func(s): s["armas"].append(s["armas"][0].duplicate()), "armas.pistola_teste: id repetido")
	_expect_error(base, func(s): s["personagens"][1]["classe"] = "mago", "\"mago\" não existe em classes")
	_expect_error(base, func(s): s["personagens"][1]["atributos"].erase("VIG"), "personagens.rafael.atributos.VIG: atributo ausente")
	_expect_error(base, func(s): s["personagens"][1]["atributos"]["SOR"] = 1, "personagens.rafael.atributos.SOR: atributo desconhecido")
	_expect_error(base, func(s): s["inimigos"][0]["ataques"] = ["bazuca"], "\"bazuca\" não existe em armas")
	_expect_error(base, func(s): s["arvores"][5]["personagem"] = null, "arvores.exclusiva_rafael: árvore exclusiva precisa de \"personagem\"")
	_expect_error(base, func(s): s["regras"]["chance_acerto_min"] = 0.99, "chance_acerto_min maior que chance_acerto_max")
	_expect_error(base, func(s): s["regras"] = [], "regras: esperado um objeto")
	_expect_error(base, func(s): s.erase("itens"), "itens: tabela ausente")

	# Comentários com "_" são ignorados e null em campo que aceita vira pendência, não erro.
	var with_comment := base.duplicate(true)
	with_comment["armas"][0]["_nota"] = "ajustar depois"
	with_comment["armas"][0]["alcance_maximo"] = null
	var d2 := GameDataScript.new()
	_check(d2.load_from(with_comment) and "armas.pistola_teste.alcance_maximo" in d2.pending, "comentário ignorado e null vira pendência")

	# Erros de arquivo: pasta sem arquivos e JSON quebrado.
	var empty := GameDataScript.new()
	_check(not empty.load_dir("res://pasta_que_nao_existe") and empty.errors.any(func(e): return "arquivo não encontrado" in e), "pasta vazia gera erro de arquivo")
	_write_copy("res://data", TMP_DIR)
	var f := FileAccess.open(TMP_DIR.path_join("armas.json"), FileAccess.WRITE)
	f.store_string("[ { \"id\": ")
	f.close()
	var broken := GameDataScript.new()
	_check(not broken.load_dir(TMP_DIR) and broken.errors.any(func(e): return "armas.json:" in e and "JSON inválido" in e), "JSON quebrado aponta arquivo e linha")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _expect_error(base: Dictionary, mutate: Callable, expected: String) -> void:
	var sources := base.duplicate(true)
	mutate.call(sources)
	var data := GameDataScript.new()
	var ok := data.load_from(sources)
	var found := data.errors.any(func(e): return expected in e)
	_check(not ok and found, "erro: " + expected)
	if not found:
		for e in data.errors:
			print("       ", e)


func _read_sources(dir: String) -> Dictionary:
	var out := {}
	for table in GameDataScript.Schema.TABLES:
		out[table] = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(table + ".json")))
	return out


func _write_copy(from_dir: String, to_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(to_dir)
	for table in GameDataScript.Schema.TABLES:
		var f := FileAccess.open(to_dir.path_join(table + ".json"), FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(from_dir.path_join(table + ".json")))
		f.close()


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
