extends SceneTree
# Teste headless das animações do Nikolai em 3D. Rodar com:
#   godot --headless --path . -s tests/test_anim_sheet.gd

var failures := 0


func _init() -> void:
	for who in [["nikolai3d", "Nikolai"], ["fernando3d", "Fernando"]]:
		_check_sheet(AnimSheet.new(who[0], who[0]), who[1])
	if failures == 0:
		print("OK: animações do Nikolai e do Fernando em 3D")
	quit(failures)


func _check_sheet(sheet: AnimSheet, who: String) -> void:
	for anim in AnimSheet.NAMES:
		_check(AnimSheet.FPS.has(anim), "%s %s: tem quadros por segundo" % [who, anim])
		_check(sheet.frame_count(anim) >= 8, "%s %s: ao menos 8 quadros" % [who, anim])
		for d in ["se", "e", "ne", "s", "n"]:
			var tex: Texture2D = sheet.textures[anim][d]
			_check(tex != null and tex.get_height() == AnimSheet.frame_size(anim).y, "%s %s_%s: altura de %d px" % [who, anim, d, AnimSheet.frame_size(anim).y])
			_check(tex != null and tex.get_width() == sheet.frame_count(anim) * AnimSheet.frame_size(anim).x, "%s %s_%s: largura é múltiplo do quadro" % [who, anim, d])


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FALHOU: " + what)
