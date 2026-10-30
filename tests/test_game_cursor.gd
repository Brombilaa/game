extends SceneTree
# Teste headless do mouse em pixel art. Rodar com:
#   godot --headless --path . -s tests/test_game_cursor.gd

var failures := 0


func _init() -> void:
	for kind in [GameCursor.Kind.ARROW, GameCursor.Kind.ATTACK]:
		var tex := GameCursor.texture(kind)
		var rows: Array = GameCursor.ARROW_ROWS if kind == GameCursor.Kind.ARROW else GameCursor.ATTACK_ROWS
		var w: int = String(rows[0]).length()
		for r in rows:
			_check(String(r).length() == w, "todas as linhas do desenho têm a mesma largura")
		_check(tex.get_width() == w * GameCursor.SCALE and tex.get_height() == rows.size() * GameCursor.SCALE, "textura ampliada pela escala")
		var h := GameCursor.hotspot(kind)
		_check(h.x < tex.get_width() and h.y < tex.get_height(), "ponto ativo dentro da imagem")
		_check(tex.get_width() <= 256 and tex.get_height() <= 256, "cabe no limite de cursor do Godot")
		var img := tex.get_image()
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		_check(opaque > 20, "o desenho tem pixels visíveis")
	_check(GameCursor.texture(GameCursor.Kind.ARROW) == GameCursor.texture(GameCursor.Kind.ARROW), "textura vem do cache")
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
