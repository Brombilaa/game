extends SceneTree
# Teste headless das dicas da primeira vez. Rodar com:
#   godot --headless --path . -s tests/test_dicas.gd

var failures := 0


func _init() -> void:
	Dicas.reiniciar()
	_check(Dicas.atual(false)["id"] == "andar", "a primeira dica é andar")
	_check(Dicas.atual(true)["id"] == "atacar", "em combate a dica é atacar")
	Dicas.marcar("andar")
	_check(Dicas.atual(false)["id"] == "examinar", "andar feito: vem examinar")
	Dicas.marcar("examinar")
	_check(Dicas.atual(false)["id"] == "agachar", "examinar feito: vem agachar")
	Dicas.marcar("atacar")
	_check(Dicas.atual(true).is_empty(), "atacar feito: nada em combate")
	_check(Dicas.atual(false)["id"] == "agachar", "atacar não pula as dicas da exploração")
	Dicas.marcar("agachar")
	_check(Dicas.atual(false).is_empty(), "tudo feito: a faixa some")
	var salvo := Dicas.para_save()
	Dicas.reiniciar()
	_check(Dicas.atual(false)["id"] == "andar", "novo jogo volta ao começo")
	Dicas.do_save(salvo)
	_check(Dicas.feita("andar") and Dicas.feita("atacar") and Dicas.atual(false).is_empty(), "save restaura as dicas feitas")
	Dicas.do_save(null)
	_check(Dicas.atual(false)["id"] == "andar", "save sem o campo limpa sem quebrar")
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok   - ", what)
	else:
		failures += 1
		print("FALHA - ", what)
