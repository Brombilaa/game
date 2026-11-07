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
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok   - ", what)
	else:
		failures += 1
		print("FALHA - ", what)
