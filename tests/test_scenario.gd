extends SceneTree
# Teste headless do cenário do parque em dados. Rodar com:
#   godot --headless --path . -s tests/test_scenario.gd

var failures := 0


func _init() -> void:
	var s := Scenario.load_id("parque")
	_check(s.ok(), "parque.json carrega sem erros: %s" % ", ".join(s.errors))
	_check(s.size == Vector2(1280, 960), "plano de 1280×960")
	_check(ResourceLoader.exists(s.backdrop_path), "fundo existe")
	_check(s.party_start.size() == 3, "três posições iniciais do grupo")

	# Projeção: os cantos do plano caem onde o fundo foi renderizado.
	_check(s.to_backdrop(Vector2.ZERO).is_equal_approx(Vector2(760, 133)), "origem do plano")
	_check(s.to_backdrop(Vector2(1280, 960)).distance_to(Vector2(1000, 767)) < 2.0, "canto sul do plano")
	for p in [Vector2(450, 690), Vector2(1130, 235)]:
		_check(s.from_backdrop(s.to_backdrop(p)).distance_to(p) < 0.01, "projeção ida e volta")

	# Ninguém começa dentro de uma colisão.
	for p in s.party_start + s.npcs.values():
		for r in s.collider_rects():
			_check(not r.has_point(p), "início %s fora das colisões" % str(p))
	for cid in s.clues:
		_check(s.clues[cid]["texto"] != "", "pista %s tem texto" % cid)

	# Ordem das pistas: a árvore só depois das outras.
	_check(not s.available_clues([]).has("arvore_simbolo"), "árvore bloqueada no início")
	var seen := []
	for cid in s.clues:
		if s.clues[cid]["ordem"] == 1:
			seen.append(cid)
	_check(s.available_clues(seen).has("arvore_simbolo"), "árvore liberada depois das outras pistas")
	_check(s.clue_at(Vector2(1130, 235)) == "arvore_simbolo", "pista da árvore ao alcance")
	_check(s.clue_at(Vector2(640, 20)) == "", "nenhuma pista no vazio")
	_check(s.triggers_after("arvore_simbolo").size() == 1, "a árvore dispara o combate")

	# Oclusão: um recorte por objeto, com a colisão de mesmo id, e a regra de quem fica na frente.
	_check(s.occluders.size() == 15, "15 recortes de oclusão")
	for o in s.occluders:
		_check(ResourceLoader.exists(o["arquivo"]), "recorte %s existe" % o["id"])
	var tree: Rect2 = s.colliders["arvore"]
	_check(not Scenario.in_front(Vector2(1130, 100), tree), "quem está ao norte da árvore fica atrás dela")
	_check(Scenario.in_front(Vector2(1130, 300), tree), "quem está ao sul da árvore fica na frente")
	_check(Scenario.in_front(Vector2(1300, 200), tree), "quem está a leste da árvore fica na frente")
	_check(not Scenario.in_front(Vector2(1000, 200), tree), "quem está a oeste da árvore fica atrás")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FALHOU: ", what)
