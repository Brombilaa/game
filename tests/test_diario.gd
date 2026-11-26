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
	# Dedução do grupo (22/11): essencial não examinada vira resumo; examinar depois troca pela pista de verdade.
	Missao1.reiniciar()
	_check(Diario.deduzir("BIBLIOTECA · 19h", "fichario", "O grupo deduz."), "dedução entra")
	_check(not Diario.deduzir("BIBLIOTECA · 19h", "fichario", "O grupo deduz."), "dedução não repete")
	_check(Missao1.diario[0]["titulo"].begins_with("Dedução"), "título marca a dedução")
	_check(Diario.anotar("BIBLIOTECA · 19h", "fichario", "Texto completo.", "") and Missao1.diario.size() == 1 and Missao1.diario[0]["id"] == "fichario", "examinar de verdade substitui a dedução")
	_check(not Diario.deduzir("BIBLIOTECA · 19h", "fichario", "O grupo deduz."), "pista já examinada não gera dedução")
	var ob := Objectives.from_data([{"texto": "Investigar", "pistas": ["caio"], "opcionais": ["a", "b"]}], ["caio", "a"], func(_m: String) -> bool: return false, false)
	_check(ob[0]["feito"] and ob[0]["detalhe"] == "1/1 · extras 1/2", "extras aparecem no HUD sem segurar o objetivo")
	Missao1.reiniciar()
	_regras()
	_relato()
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


# Aba DIÁRIO: o relato do Miguel só ganha página depois que o grupo esteve no lugar, e cada linha/desenho só
# aparece quando a pista ou a marca que ele pede existe.
func _relato() -> void:
	Missao1.reiniciar()
	_check(DiarioMiguel.secoes().is_empty(), "relato começa vazio")
	DiarioMiguel.esteve("parque")
	var s := DiarioMiguel.secoes()
	_check(s.size() == 1 and s[0]["id"] == "parque", "estar no parque abre a página do parque")
	var antes: int = s[0]["linhas"].size()
	var des: int = s[0]["desenhos"].size()
	Diario.anotar("PARQUE · 16h", "caio", "O Caio separa o equipamento do grupo.", "")
	s = DiarioMiguel.secoes()
	_check(s[0]["linhas"].size() == antes and s[0]["desenhos"].size() == des, "a pista do Caio, com ele vivo, não escreve a morte no relato")
	Missao1.marcar("caio_morreu")  # a morte só entra no caderno depois da cena
	s = DiarioMiguel.secoes()
	_check(s[0]["linhas"].size() == antes + 1 and s[0]["desenhos"].size() == des + 1, "depois da morte do Caio o relato ganha linha e desenho")
	DiarioMiguel.esteve("subsolo")
	s = DiarioMiguel.secoes()
	_check(s.size() == 2 and s[1]["id"] == "delegacia_21h", "o subsolo entra na página da delegacia de noite")
	_check(not DiarioMiguel.cumpre("marca:nao_existe") and DiarioMiguel.cumpre(""), "regra do 'requer'")
	_check(DiarioMiguel.cabecalho()["sub"].contains("primeira missão oficial"), "cabeçalho da primeira missão oficial")
	var d := DiarioMiguel.dados()
	for sec in d["secoes"]:
		for x in sec["desenhos"]:
			_check(DiarioMiguel.caminho(str(x["desenho"])) != "", "o desenho existe: " + str(x["desenho"]))
	for k in d["desenhos_pistas"]:
		_check(DiarioMiguel.desenho_pista(k) != "", "desenho da pista existe: " + k)
	for k in d["desenhos_criaturas"]:
		_check(DiarioMiguel.desenho_criatura(k) != "", "desenho da criatura existe: " + k)
	Missao1.reiniciar()


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
	_check(p.secao == "diario", "o caderno abre na aba DIÁRIO")
	p.trocar_secao("pistas")
	_check(p._lista.get_child_count() == 1 and p._texto.text == "Marcas.", "mostra a última descoberta")
	_check(p._obj.text.contains("PRÓXIMO OBJETIVO"), "o objetivo do HUD aparece no pé")
	p._escolher(0)
	p.alternar()
	_check(not p.open, "fecha de novo")
	p.fechar()
	room.dialog_layer.visible = true
	_check(not room.diario_pode_abrir(), "com a caixa de pista aberta o diário não abre")
	room.queue_free()
	await process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		return
	failures += 1
	print("FALHOU: " + what)
