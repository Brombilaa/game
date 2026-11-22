extends SceneTree
# Textos da transformação e da morte da Dama de Sangue (22/11): os dois arquivos de cena existem, só usam passos que a
# CenaNarrada conhece, as falas têm nome, a narração do Léo está inteira e os dados da cripta apontam para as cenas.
# Rodar com:
#   godot --headless --path . -s tests/test_cena_narrada.gd

var failures := 0
const PASSOS := ["cinema", "narrar", "dialogo", "esperar", "marca"]


func _initialize() -> void:
	_run()


func _run() -> void:
	for id in ["dama_transformacao", "dama_morte"]:
		var passos := CenaNarrada.carregar(id)
		_check(passos.size() > 5, "%s: cena carregada (%d passos)" % [id, passos.size()])
		var texto := ""
		for p in passos:
			_check(PASSOS.has(str(p.get("faz", ""))), "%s: passo conhecido (%s)" % [id, p.get("faz", "")])
			if p.get("faz") == "narrar":
				texto += str(p["texto"]) + " "
			for f in p.get("falas", []):
				_check(CaixaFala.NOMES.has(str(f["quem"])), "%s: %s tem nome" % [id, f["quem"]])
		if id == "dama_transformacao":
			for trecho in ["enorme vinha rompe", "flor com dentes afiados", "Sete longas vinhas", "grito terrível"]:
				_check(texto.contains(trecho), "transformação: narração do Léo inteira (%s)" % trecho)
		else:
			for trecho in ["massa de dor e agonia", "restos mortais desfigurados", "O silêncio é um alívio. Vocês venceram."]:
				_check(texto.contains(trecho), "morte: narração do Léo inteira (%s)" % trecho)
	var cripta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cenarios/cripta.json"))
	_check(cripta["chefe"]["cena"] == "dama_transformacao" and CenaNarrada.carregar("dama_transformacao").size() > 0, "cripta: a transformação aponta para a cena")
	_check(cripta["fim"]["cena_morte"] == "dama_morte" and CenaNarrada.carregar("dama_morte").size() > 0, "cripta: a morte aponta para a cena")
	# Sem janela a cena passa direto e não deixa o jogo pausado.
	await CenaNarrada.tocar(root, "dama_morte")
	_check(not paused, "sem janela: a cena passa direto, sem pausar")
	print("Falhas: %d" % failures if failures > 0 else "OK: test_cena_narrada")
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("FALHOU: " + msg)
