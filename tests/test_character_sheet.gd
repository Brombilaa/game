extends SceneTree
# Teste headless da folha de poses do Nikolai. Rodar com:
#   godot --headless --path . -s tests/test_character_sheet.gd

var failures := 0


func _init() -> void:
	var sheet := CharacterSheet.new("res://assets/sprites/personagens/nikolai_e.png")
	_check(sheet.frame_count() == 8, "8 quadros na folha")
	_check(sheet.texture.get_height() == CharacterSheet.FRAME, "folha de uma fila só")

	var img := sheet.texture.get_image()
	var used := {}
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
		_check(feet_ok, "quadro %d tem os pés na linha do pivô" % f)
		_check(top >= 0 and CharacterSheet.PIVOT.y - top <= CharacterSheet.HEIGHT, "quadro %d cabe na altura declarada" % f)
	_check(used.size() <= 24, "paleta única de até 24 cores (%d)" % used.size())

	_check(CharacterSheet.IDLE_FRAMES + CharacterSheet.WALK_FRAMES == [0, 1, 2, 3, 4, 5, 6, 7], "parado e andando cobrem os 8 quadros")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FALHOU: " + label)
