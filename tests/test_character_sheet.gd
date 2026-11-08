extends SceneTree
# Teste headless das folhas de poses do Nikolai, do Miguel, do Fernando e do cultista. Rodar com:
#   godot --headless --path . -s tests/test_character_sheet.gd

var failures := 0


func _init() -> void:
	for who in ["nikolai", "miguel", "fernando", "cultista"]:
		_check_sheet(who)

	var D := CharacterSheet.Dir
	_check(CharacterSheet.dir_from_vector(Vector2(1, 0)) == D.E, "vetor (1,0) = leste")
	_check(CharacterSheet.dir_from_vector(Vector2(1, 1)) == D.SE, "vetor (1,1) = sudeste")
	_check(CharacterSheet.dir_from_vector(Vector2(0, 1)) == D.S, "vetor (0,1) = sul")
	_check(CharacterSheet.dir_from_vector(Vector2(-1, 1)) == D.SW, "vetor (-1,1) = sudoeste")
	_check(CharacterSheet.dir_from_vector(Vector2(-1, 0)) == D.W, "vetor (-1,0) = oeste")
	_check(CharacterSheet.dir_from_vector(Vector2(-1, -1)) == D.NW, "vetor (-1,-1) = noroeste")
	_check(CharacterSheet.dir_from_vector(Vector2(0, -1)) == D.N, "vetor (0,-1) = norte")
	_check(CharacterSheet.dir_from_vector(Vector2(1, -1)) == D.NE, "vetor (1,-1) = nordeste")
	_check(CharacterSheet.SHEET_OF[D.SW] == ["se", true] and CharacterSheet.SHEET_OF[D.W] == ["e", true] and CharacterSheet.SHEET_OF[D.NW] == ["ne", true], "SO, O e NO espelham SE, E e NE")

	_check(CharacterSheet.IDLE_FRAMES + CharacterSheet.WALK_FRAMES == [0, 1, 2, 3, 4, 5, 6, 7], "parado e andando cobrem os 8 quadros")

	for who in ["fernando", "miguel", "nikolai"]:
		var sheet := CharacterSheet.new("res://assets/sprites/personagens/legado_2d/" + who)
		_check(sheet.portrait != null and sheet.portrait.get_width() == 64 and sheet.portrait.get_height() == 64, "%s: retrato de 64 px" % who)
		var big := load("res://assets/sprites/retratos/%s_128.png" % who) as Texture2D
		_check(big != null and big.get_width() == 128, "%s: retrato de 128 px" % who)
		var img := sheet.portrait.get_image()
		_check(img.get_pixel(32, 40).a == 1.0, "%s: retrato opaco" % who)
		_check(sheet.portrait_hurt != null and sheet.portrait_hurt.get_width() == 64, "%s: retrato ferido de 64 px" % who)
		var bighurt := load("res://assets/sprites/retratos/%s_ferido_128.png" % who) as Texture2D
		_check(bighurt != null and bighurt.get_width() == 128, "%s: retrato ferido de 128 px" % who)
	_check(CharacterSheet.new("res://assets/sprites/personagens/legado_2d/cultista").portrait == null, "cultista segue sem retrato próprio")

	var cri := load("res://assets/sprites/retratos/criatura_64.png") as Texture2D
	_check(cri != null and cri.get_width() == 64, "criatura: retrato de 64 px")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)



func _check_sheet(who: String) -> void:
	var sheet := CharacterSheet.new("res://assets/sprites/personagens/legado_2d/" + who)
	_check(sheet.frame_count() == 8, "%s: 8 quadros na folha" % who)
	_check(sheet.textures["e"].get_height() == CharacterSheet.FRAME, "%s: folha de uma fila só" % who)

	var used := {}
	for name in sheet.textures:
		var tex: Texture2D = sheet.textures[name]
		_check(tex.get_width() == 8 * CharacterSheet.FRAME, "%s %s: 8 quadros" % [who, name])
		var img := tex.get_image()
		for f in sheet.frame_count():
			var feet_ok := false
			var top := -1
			for y in CharacterSheet.FRAME:
				for x in CharacterSheet.FRAME:
					var c := img.get_pixel(f * CharacterSheet.FRAME + x, y)
					if c.a > 0.0:
						if top < 0:
							top = y
						if y == int(CharacterSheet.PIVOT.y) and absi(x - int(CharacterSheet.PIVOT.x)) < 40:
							feet_ok = true
						used[c] = true
			_check(feet_ok, "%s %s: quadro %d tem os pés na linha do pivô" % [who, name, f])
			_check(top >= 0 and CharacterSheet.PIVOT.y - top <= CharacterSheet.HEIGHT, "%s %s: quadro %d cabe na altura declarada" % [who, name, f])
	_check(used.size() <= 32, "%s: paleta única de até 32 cores (%d)" % [who, used.size()])

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FALHOU: " + label)
