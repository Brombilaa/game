extends SceneTree
# Teste headless das dicas da primeira vez. Rodar com:
#   godot --headless --path . -s tests/test_dicas.gd

var failures := 0


func _init() -> void:
	Dicas.reiniciar()
	var expl := {"combate": false, "pista": false, "inimigo": false}
	var combate := {"combate": true}
	_check(Dicas.atual(expl)["id"] == "andar", "a primeira dica é andar")
	_check(Dicas.atual(combate)["id"] == "atacar", "em combate a dica é atacar")
	Dicas.marcar("andar")
	_check(Dicas.atual(expl).is_empty(), "longe de pista e de inimigo não há dica")
	_check(Dicas.atual({"pista": true})["id"] == "examinar", "perto de pista: examinar")
	_check(Dicas.atual({"inimigo": true})["id"] == "agachar", "perto de inimigo desprevenido: agachar")
	_check(Dicas.atual({"inimigo": true, "combate": true})["id"] == "atacar", "em combate só a de atacar")
	Dicas.marcar("examinar")
	_check(Dicas.atual({"pista": true}).is_empty(), "examinar feito não volta")
	Dicas.marcar("atacar")
	_check(Dicas.atual(combate).is_empty(), "atacar feito: nada em combate")
	_check(Dicas.atual({"inimigo": true})["id"] == "agachar", "atacar não apaga a de agachar")
	Dicas.marcar("agachar")
	_check(Dicas.atual({"pista": true, "inimigo": true}).is_empty(), "tudo feito: a faixa some")
	var salvo := Dicas.para_save()
	Dicas.reiniciar()
	_check(Dicas.atual(expl)["id"] == "andar", "novo jogo volta ao começo")
	Dicas.do_save(salvo)
	_check(Dicas.feita("andar") and Dicas.feita("atacar") and Dicas.atual({"pista": true, "inimigo": true}).is_empty(), "save restaura as dicas feitas")
	Dicas.do_save(null)
	_check(Dicas.atual(expl)["id"] == "andar", "save sem o campo limpa sem quebrar")
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok   - ", what)
	else:
		failures += 1
		print("FALHA - ", what)
