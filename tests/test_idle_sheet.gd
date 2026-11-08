extends SceneTree
# Teste headless das folhas de parado do Caio (3D no estilo PC antigo). Rodar com:
#   godot --headless --path . -s tests/test_idle_sheet.gd

var failures := 0


func _init() -> void:
	for pair in [["caio3d", "caio3d"]]:
		var sheet := IdleSheet.new(pair[0], pair[1])
		_check(sheet.frame_count() == 32, "%s: 32 quadros" % pair[0])
		for d in ["se", "e", "ne", "s", "n"]:
			var tex: Texture2D = sheet.textures[d]
			_check(tex != null and tex.get_height() == IdleSheet.FRAME, "%s_%s: altura de %d px" % [pair[0], d, IdleSheet.FRAME])
			_check(tex != null and tex.get_width() == 32 * IdleSheet.FRAME, "%s_%s: largura de 32 quadros" % [pair[0], d])
		_check(sheet.frame_at(0) == 0, "%s: começa no quadro 0" % pair[0])
		_check(sheet.frame_at(1000000) >= 0 and sheet.frame_at(1000000) < 32, "%s: quadro sempre dentro da folha" % pair[0])
	if failures == 0:
		print("OK: folhas de parado")
	quit(failures)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FALHOU: " + what)
