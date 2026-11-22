extends SceneTree
# Teste headless da lista de objetivos. Rodar com:
#   godot --headless --path . -s tests/test_objectives.gd

var failures := 0


func _init() -> void:
	var clues := {"a": {"ordem": 1}, "b": {"ordem": 1}, "t": {"ordem": 2}}
	var o := Objectives.build(clues, [], false)
	_check(o.size() == 2, "investigar + símbolo")
	_check(o[0]["atual"] and o[0]["detalhe"] == "0/2", "investigar é o atual, 0/2")
	_check(o[1]["texto"] == Objectives.LOCKED_TEXT and not o[1]["atual"], "símbolo bloqueado")
	o = Objectives.build(clues, ["a"], false)
	_check(o[0]["detalhe"] == "1/2" and not o[0]["feito"], "progresso 1/2")
	o = Objectives.build(clues, ["a", "b"], false)
	_check(o[0]["feito"] and not o[0]["atual"], "primeiro concluído")
	_check(o[1]["atual"] and o[1]["texto"] != Objectives.LOCKED_TEXT, "símbolo liberado e atual")
	o = Objectives.build(clues, ["a", "b", "t"], true)
	_check(o[1]["feito"] and o[2]["texto"] == Objectives.COMBAT_TEXT and o[2]["atual"], "combate vira o atual")
	# Formato único dos dados (parque.json e os outros lugares).
	var marcas := {"alcapao": true}
	var tem := func(m: String) -> bool: return marcas.has(m)
	var lista := [
		{"texto": "Investigar", "pistas": ["a", "b"]},
		{"texto": "Símbolo", "pista": "t", "trancado": true},
		{"texto": "Descer", "marca": "desceu", "requer": "alcapao"},
		{"texto": "Escondido", "requer": "nunca"},
	]
	o = Objectives.from_data(lista, ["a"], tem, false)
	_check(o.size() == 3 and o[0]["detalhe"] == "1/2" and o[0]["atual"], "pistas contam x/y; requer sem a marca esconde")
	_check(o[1]["texto"] == Objectives.LOCKED_TEXT, "trancado mostra ??? até os anteriores")
	o = Objectives.from_data(lista, ["a", "b"], tem, false)
	_check(o[1]["texto"] == "Símbolo" and o[1]["atual"], "trancado abre depois dos anteriores")
	marcas["desceu"] = true
	o = Objectives.from_data(lista, ["a", "b", "t"], tem, true)
	_check(o[2]["feito"] and o[3]["texto"] == Objectives.COMBAT_TEXT and o[3]["atual"], "marca conclui; em combate o atual é sobreviver")
	var parque := Scenario.load_id("parque")
	_check(parque.objetivos.size() == 2, "parque.json tem os objetivos no formato comum")
	var sem_saque := parque.clues.duplicate()
	sem_saque.erase("mochila_piquenique")  # esconderijo opcional (16/11): fora dos objetivos e do caminho antigo
	var antigo := Objectives.build(sem_saque, ["caio"], false)
	var novo := Objectives.from_data(parque.objetivos, ["caio"], tem, false)
	_check(antigo.size() == novo.size() and novo[0]["feito"] and novo[0]["detalhe"] == "1/1 · extras 0/4", "parque: só o Caio é essencial, os 4 extras são opcionais (%s)" % str(novo))
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok   - ", what)
	else:
		failures += 1
		print("FALHA - ", what)
