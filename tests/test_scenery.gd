extends SceneTree
# Teste headless das peças de cenário isométricas. Rodar com:
#   godot --headless --path . -s tests/test_scenery.gd

var failures := 0


func _init() -> void:
	var s := Scenery.new()

	_check(s.floors.size() == Scenery.FLOOR_COUNT, "todos os pisos carregam")
	for tex in s.floors:
		_check(tex.get_size() == Vector2(96, 48), "piso é um losango de 96×48")

	var seen := {}
	for ty in 40:
		for tx in 40:
			seen[s.floor_texture(tx, ty)] = true
			_check(s.floor_texture(tx, ty) == s.floor_texture(tx, ty), "o sorteio do piso é fixo")
	_check(seen.size() == Scenery.FLOOR_COUNT, "as %d variações aparecem na sala" % Scenery.FLOOR_COUNT)

	for kind in ["x", "y"]:
		for v in ["lisa", "janela", "vao", "quebrada"]:
			var nome := "parede_%s_%s" % [kind, v]
			_check(s.pieces.has(nome), nome + " existe")
			var tex: Texture2D = s.pieces[nome]
			_check(absf(tex.get_size().x - 96.0) <= 1.0, nome + " tem ~96 px de largura (2 losangos)")
			_check(s.anchors[nome].y < tex.get_size().y and s.anchors[nome].y > tex.get_size().y * 0.7, nome + " tem a âncora na base")
	for nome in ["caixote", "estante", "guarda_roupa", "porta"]:
		_check(s.pieces.has("movel_" + nome), "movel_" + nome + " existe")
	_check(Scenery.wall_variant(0) == "lisa" and Scenery.wall_variant(1) == "janela", "variação das paredes alterna")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FALHOU: ", what)
