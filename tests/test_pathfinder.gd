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

	# Cache: a mesma rota entre os mesmos obstáculos sai igual; obstáculo novo muda o resultado.
	var again := pf.find_path(Vector2(50, 100), Vector2(200, 100), wall, radius)
	_check(again == around and pf.calls_total >= 3, "rota repetida vem igual do cache")
	var wall2: Array[Rect2] = [Rect2(100, 0, 20, 200), Rect2(150, 0, 20, 200)]
	_check(pf.find_path(Vector2(50, 100), Vector2(200, 100), wall2, radius).size() >= around.size(), "obstáculo novo refaz a rota")
	var walled: Array[Rect2] = [Rect2(100, -1000, 20, 2000)]
	_check(pf.find_path(Vector2(50, 100), Vector2(200, 100), walled, radius).size() >= around.size(), "o cache não reaproveita rota de outros obstáculos")

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

	# Contorno com vários obstáculos: a rota existe, não atravessa nenhum e é mais curta que um desvio longo.
	var many: Array[Rect2] = [Rect2(100, 0, 20, 200), Rect2(200, 100, 20, 200), Rect2(300, 0, 20, 200)]
	var zig := pf.find_path(Vector2(50, 50), Vector2(400, 50), many, radius)
	_check(zig.size() >= 4 and zig[zig.size() - 1] == Vector2(400, 50), "contorna vários obstáculos")
	var crosses := false
	for i in range(1, zig.size()):
		for o in many:
			if Pathfinder.segment_crosses_rect(zig[i - 1], zig[i], o.grow(radius)):
				crosses = true
	_check(not crosses, "a rota não atravessa obstáculos")
	_check(Pathfinder.is_free(Vector2(10, 10), many, radius) and not Pathfinder.is_free(Vector2(105, 50), many, radius), "is_free respeita o raio")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
