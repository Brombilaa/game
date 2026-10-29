extends SceneTree
# Teste headless do Pathfinder. Rodar com:
#   godot --headless --path . -s tests/test_pathfinder.gd

var failures := 0


func _init() -> void:
	var pf := Pathfinder.new()
	var wall: Array[Rect2] = [Rect2(100, 0, 20, 200)]
	var radius := 5.0

	# Sem obstáculo no caminho: rota reta.
	var direct := pf.find_path(Vector2(10, 300), Vector2(300, 300), wall, radius)
	_check(direct.size() == 2, "rota livre tem 2 pontos")

	# Parede no meio: a rota contorna pela ponta da parede.
	var around := pf.find_path(Vector2(50, 100), Vector2(200, 100), wall, radius)
	_check(around.size() >= 3, "contorna a parede")
	_check(around.size() > 0 and around[around.size() - 1] == Vector2(200, 100), "termina no destino")

	# Destino dentro da parede: inacessível.
	_check(pf.find_path(Vector2(50, 100), Vector2(110, 100), wall, radius).is_empty(), "destino na parede é inacessível")

	# Destino cercado por quatro paredes: sem caminho.
	var box: Array[Rect2] = [
		Rect2(150, 50, 10, 100), Rect2(240, 50, 10, 100),
		Rect2(150, 50, 100, 10), Rect2(150, 140, 100, 10),
	]
	_check(pf.find_path(Vector2(10, 100), Vector2(200, 100), box, radius).is_empty(), "destino cercado é inacessível")

	# Linha de visão: parede entre os pontos bloqueia; sem parede, livre.
	_check(not Pathfinder.has_line_of_sight(Vector2(50, 100), Vector2(200, 100), wall), "parede bloqueia a visão")
	_check(Pathfinder.has_line_of_sight(Vector2(50, 300), Vector2(200, 300), wall), "sem parede a visão é livre")
	_check(Pathfinder.has_line_of_sight(Vector2(50, 100), Vector2(100, 100), wall), "encostar na borda não bloqueia")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
