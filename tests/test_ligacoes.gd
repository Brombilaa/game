extends SceneTree
# Teste headless da ligação de pistas: par com conclusão, ordem tanto faz, sem repetir, par sem ligação, pista que
# falta no diário, marca da missão, ida e volta no save e consistência de data/ligacoes.json com as pistas dos cenários.
# Rodar com:
#   godot --headless --path . -s tests/test_ligacoes.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Missao1.reiniciar()
	_regras()
	_dados()
	Missao1.reiniciar()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_ligacoes")
	quit(1 if failures > 0 else 0)


func _regras() -> void:
	Diario.anotar("PARQUE · 16h", "marcas_pneu", "Marcas.", "")
	var r := Ligacoes.tentar("marcas_pneu", "livro_faltando")
	_check(r["resultado"] == Ligacoes.Resultado.INVALIDA, "pista que ainda não está no diário não liga")
	_check(Missao1.diario.size() == 1, "ligação inválida não anota nada")
	Diario.anotar("DELEGACIA · 21h", "livro_faltando", "Livro.", "")
	_check(Ligacoes.disponiveis().size() == 1, "com as duas no diário a ligação fica disponível")
	r = Ligacoes.tentar("livro_faltando", "marcas_pneu")
	_check(r["resultado"] == Ligacoes.Resultado.NOVA, "a ordem do par não importa")
	_check(r["entrada"]["titulo"] == "O livro saiu de van" and r["entrada"]["lugar"] == Ligacoes.LUGAR, "a conclusão entra no diário com título e lugar")
	_check(Diario.recentes()[0]["id"] == "lig_van_levou_livro", "a conclusão é a entrada mais nova")
	_check(Missao1.tem("rastro_fazenda"), "a ligação marca o fato da missão")
	_check(Ligacoes.tentar("marcas_pneu", "livro_faltando")["resultado"] == Ligacoes.Resultado.JA_FEITA, "ligar de novo não repete")
	_check(Missao1.diario.size() == 3, "ligar de novo não duplica a entrada")
	_check(Ligacoes.feitas() == 1 and Ligacoes.disponiveis().is_empty(), "contagem de ligações feitas")
	Diario.anotar("PARQUE · 16h", "balanco", "Arranhões.", "")
	_check(Ligacoes.tentar("balanco", "marcas_pneu")["resultado"] == Ligacoes.Resultado.SEM_LIGACAO, "par sem ligação não conclui nada")
	_check(Ligacoes.tentar("balanco", "balanco")["resultado"] == Ligacoes.Resultado.INVALIDA, "a pista não liga com ela mesma")
	var salvo := JSON.parse_string(JSON.stringify(Missao1.diario)) as Array
	Missao1.reiniciar()
	Missao1.diario = Diario.ler(salvo)
	_check(Ligacoes.feitas() == 1, "a ligação feita volta do save junto com o diário")


func _dados() -> void:
	var ids := {}
	for f in DirAccess.get_files_at("res://data/cenarios"):
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cenarios/" + f))
		for c in d.get("pistas", []):
			ids[c["id"]] = true
	var vistos := {}
	for lig in Ligacoes.todas():
		_check(not vistos.has(lig["id"]), "id de ligação único: " + lig["id"])
		vistos[lig["id"]] = true
		_check(lig["pistas"].size() == 2 and lig["pistas"][0] != lig["pistas"][1], "par de duas pistas diferentes: " + lig["id"])
		for p in lig["pistas"]:
			_check(ids.has(p), "pista existe nos cenários: " + p)
		_check(str(lig["titulo"]) != "" and str(lig["texto"]) != "", "título e texto: " + lig["id"])
	_check(Ligacoes.todas().size() >= 5, "as ligações da missão 1 foram carregadas")


func _check(ok: bool, what: String) -> void:
	if ok:
		return
	failures += 1
	print("FALHOU: " + what)
