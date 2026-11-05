extends SceneTree
# Teste headless das animações do Nikolai em 3D. Rodar com:
#   godot --headless --path . -s tests/test_anim_sheet.gd

var failures := 0


func _init() -> void:
	var sheet := AnimSheet.new()
	for anim in AnimSheet.NAMES:
		_check(AnimSheet.FPS.has(anim), "%s: tem quadros por segundo" % anim)
		_check(sheet.frame_count(anim) >= 8, "%s: ao menos 8 quadros" % anim)
		for d in ["se", "e", "ne", "s", "n"]:
			var tex: Texture2D = sheet.textures[anim][d]
			_check(tex != null and tex.get_height() == AnimSheet.frame_size(anim).y, "%s_%s: altura de %d px" % [anim, d, AnimSheet.frame_size(anim).y])
			_check(tex != null and tex.get_width() == sheet.frame_count(anim) * AnimSheet.frame_size(anim).x, "%s_%s: largura é múltiplo do quadro" % [anim, d])
	if failures == 0:
		print("OK: animações do Nikolai 3D")
	quit(failures)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FALHOU: " + what)
