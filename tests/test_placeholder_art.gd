extends SceneTree
# Teste headless da arte provisória. Rodar com:
#   godot --headless --path . -s tests/test_placeholder_art.gd

var failures := 0


func _init() -> void:
	var palette: Array = PlaceholderArt.PALETTE.values()

	# Quadro de 32×48 em 4 direções e 3 quadros, só com cores da paleta.
	var only_palette := true
	for variant in PlaceholderArt.VARIANTS:
		for dir in 4:
			for frame in PlaceholderArt.FRAMES:
				var img := PlaceholderArt.character_image(variant, dir, frame)
				_check(img.get_size() == PlaceholderArt.FRAME_SIZE, "%s %d/%d tem 32×48" % [variant, dir, frame])
				only_palette = only_palette and _uses_only(img, palette)
	_check(only_palette, "personagens usam só cores da paleta")

	# Oeste é o espelho de leste.
	var east := PlaceholderArt.character_image("agente", PlaceholderArt.Dir.EAST, 0)
	east.flip_x()
	var west := PlaceholderArt.character_image("agente", PlaceholderArt.Dir.WEST, 0)
	_check(east.get_data() == west.get_data(), "oeste espelha leste")

	# Passo muda o desenho; variante troca a cor do casaco.
	var idle := PlaceholderArt.character_image("agente", PlaceholderArt.Dir.SOUTH, 0)
	_check(idle.get_data() != PlaceholderArt.character_image("agente", PlaceholderArt.Dir.SOUTH, 1).get_data(), "quadro de passo difere do parado")
	_check(idle.get_data() != PlaceholderArt.character_image("cultista", PlaceholderArt.Dir.SOUTH, 0).get_data(), "cultista tem outra cor")

	# Pés no pivô: a linha do pivô tem pixel opaco e não há nada abaixo do quadro útil.
	var feet_row := int(PlaceholderArt.PIVOT.y)
	var has_feet := false
	for x in PlaceholderArt.FRAME_SIZE.x:
		has_feet = has_feet or idle.get_pixel(x, feet_row).a > 0.0
	_check(has_feet, "pés na linha do pivô")

	var tile := PlaceholderArt.floor_image()
	_check(tile.get_size() == Vector2i(16, 16), "tile tem 16×16")
	_check(_uses_only(tile, palette), "chão usa só cores da paleta")

	# Direção pelo vetor de movimento.
	_check(PlaceholderArt.dir_from_vector(Vector2(5, 1)) == PlaceholderArt.Dir.EAST, "direita é leste")
	_check(PlaceholderArt.dir_from_vector(Vector2(-5, 1)) == PlaceholderArt.Dir.WEST, "esquerda é oeste")
	_check(PlaceholderArt.dir_from_vector(Vector2(1, -5)) == PlaceholderArt.Dir.NORTH, "cima é norte")
	_check(PlaceholderArt.dir_from_vector(Vector2(1, 5)) == PlaceholderArt.Dir.SOUTH, "baixo é sul")

	# A paleta para editores (.gpl) tem as mesmas cores do código.
	var gpl := FileAccess.get_file_as_string("res://assets/palettes/paleta_teste.gpl")
	var gpl_count := 0
	for line in gpl.split("\n"):
		var parts := line.strip_edges().split_floats(" ", false)
		if line.contains("\t") and parts.size() >= 3:
			gpl_count += 1
			_check(palette.has(Color8(int(parts[0]), int(parts[1]), int(parts[2]))), "cor do .gpl existe no código: " + line)
	_check(gpl_count == palette.size(), "o .gpl tem todas as cores da paleta")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _uses_only(img: Image, palette: Array) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and not palette.has(c):
				return false
	return true


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FALHOU: " + label)
