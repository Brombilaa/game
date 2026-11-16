extends SceneTree
# Teste headless da caixa de fala com retrato e dos dados das falas. Rodar com:
#   godot --headless --path . -s tests/test_caixa_fala.gd

var failures := 0


func _init() -> void:
	CaixaFala.pular = false  # aqui a caixa roda de verdade, mesmo sem janela
	_check(CaixaFala.nome_de("leticia") == "Letícia", "id vira nome com acento")
	_check(CaixaFala.nome_de("Letícia") == "Letícia", "nome também serve")
	_check(CaixaFala.tem_retrato("fernando"), "Fernando tem retrato")
	# Todas as falas do arquivo: 2 a 4 por pista, texto não vazio, personagem conhecido.
	var f := FileAccess.open(CaixaFala.ARQUIVO_FALAS, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for chave in d:
		if str(chave).begins_with("_"):
			continue
		var partes := str(chave).split("/")
		var sc := Scenario.load_id(partes[0])
		_check(sc != null and sc.clues.has(partes[1]), "%s: a pista existe no cenário" % chave)
		var falas: Array = CaixaFala.falas_da_pista(partes[0], partes[1])
		_check(falas.size() >= 2 and falas.size() <= 4, "%s: de 2 a 4 falas" % chave)
		for fala in falas:
			_check(str(fala["texto"]).length() > 0 and str(fala["texto"]).length() <= 120, "%s: texto curto" % chave)
			_check(CaixaFala.NOMES.has(str(fala["quem"])), "%s: personagem %s conhecido" % [chave, fala["quem"]])
	_check(CaixaFala.falas_da_pista("parque", "nao_existe").is_empty(), "pista sem falas devolve lista vazia")
	_rodar()


func _rodar() -> void:
	await process_frame  # a árvore só fica pronta depois do _init
	var caixa := CaixaFala.new()
	root.add_child(caixa)
	var feitas := [0]
	var corrida := func():
		await caixa.sequencia([{"quem": "caio", "texto": "Oi."}, {"quem": "miguel", "texto": "Olá."}])
		feitas[0] = 1
	corrida.call()
	await process_frame
	_check(caixa.ocupada and caixa.visible, "a caixa aparece ao falar")
	for i in 40:  # dois avanços por fala: completa o texto e passa
		await process_frame
		caixa._avanca()
	for i in 10:
		await process_frame
	_check(feitas[0] == 1 and not caixa.ocupada and not caixa.visible, "a sequência termina e a caixa some")
	# Fala solta: some sozinha, sem clique.
	var solta := [0]
	var corrida2 := func():
		await caixa.falar("fernando", "Vamos.", true)
		solta[0] = 1
	corrida2.call()
	await create_timer(CaixaFala.TEMPO_MINIMO_SOLTA + 1.0).timeout
	_check(solta[0] == 1 and not caixa.visible, "fala solta some sozinha")
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
