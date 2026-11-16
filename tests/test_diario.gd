extends SceneTree
# Teste headless do diário de pistas: anotar sem repetir, ir e voltar no save, objetivo atual e o painel (tecla J).
# Rodar com:
#   godot --headless --path . -s tests/test_diario.gd

const DIR := "user://test_diario"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.dir = DIR
	Progresso.autosave_ativo = true
	Missao1.reiniciar()
	_regras()
	await _salvo_e_painel()
	DirAccess.remove_absolute(DIR.path_join("auto.json"))
	print("Falhas: %d" % failures if failures > 0 else "OK: test_diario")
	quit(1 if failures > 0 else 0)


func _regras() -> void:
	_check(Diario.anotar("PARQUE · 16h", "balanco", "Arranhões.", ""), "anotar uma pista nova")
	_check(not Diario.anotar("PARQUE · 16h", "balanco", "Arranhões.", ""), "a mesma pista no mesmo lugar não repete")
	_check(Diario.anotar("DELEGACIA · 21h", "tapete", "Tapete torto.", ""), "pista de outro lugar entra")
	_check(Diario.recentes()[0]["id"] == "tapete", "a lista começa pela mais nova")
	_check(Diario.titulo("balanco") == "Balanço arranhado" and Diario.titulo("coisa_nova") == "Coisa nova", "título da lista, com fallback")
	var lista: Array[Dictionary] = [{"texto": "A", "feito": true, "atual": false, "detalhe": ""}, {"texto": "Investigar", "feito": false, "atual": true, "detalhe": "2/5"}]
	_check(Diario.objetivo_atual(lista) == "Investigar (2/5)", "o objetivo atual leva o andamento")
	_check(Diario.objetivo_atual([]) == "", "sem objetivo, vazio")
	Missao1.reiniciar()
	_check(Missao1.diario.is_empty(), "novo jogo esvazia o diário")


func _salvo_e_painel() -> void:
	var room = load(Progresso.CENA_PARQUE).instantiate()
	root.add_child(room)
	await process_frame
	Diario.anotar("PARQUE · 16h", "balanco", "Arranhões.", "")
	Diario.anotar("PARQUE · 16h", "arvore_simbolo", "Símbolo.", "res://assets/sprites/cenario/parque/inspecao_simbolo.png")
	var data := Progresso.capturar(room, room._area_id(), room._place_label())
	_check(JSON.parse_string(JSON.stringify(data)) is Dictionary, "o save com diário só tem tipos do JSON")
	var volta := JSON.parse_string(JSON.stringify(data)) as Dictionary
	Missao1.reiniciar()
	Progresso.preparar_missao(volta)
	_check(Missao1.diario.size() == 2 and Missao1.diario[1]["imagem"] != "", "o diário volta do save com texto e imagem")
	_check(Missao1.diario[0]["lugar"] == "PARQUE · 16h", "o lugar volta do save")
	Progresso.preparar_missao({"current_area": "parque", "missao": {"local": ""}})
	_check(Missao1.diario.is_empty(), "save antigo, sem diário, abre com o diário vazio")

	Diario.anotar("PARQUE · 16h", "marcas_pneu", "Marcas.", "")
	var p: DiarioPanel = room.diario_panel
	_check(p != null and not p.open, "a sala tem o painel e ele começa fechado")
	p.alternar()
	_check(p.open and p.visible, "o painel abre")
	_check(p._lista.get_child_count() == 1 and p._texto.text == "Marcas.", "mostra a última descoberta")
	_check(p._obj.text.contains("PRÓXIMO OBJETIVO"), "o objetivo do HUD aparece no pé")
	p._escolher(0)
	p.alternar()
	_check(not p.open, "fecha de novo")
	room.dialog_layer.visible = true
	_check(not room.diario_pode_abrir(), "com a caixa de pista aberta o diário não abre")
	room.queue_free()
	await process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		return
	failures += 1
	print("FALHOU: " + what)
