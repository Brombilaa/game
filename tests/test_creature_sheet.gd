extends SceneTree
# Teste headless das folhas da Criatura de Sangue. Rodar com:
#   godot --headless --path . -s tests/test_creature_sheet.gd

var failures := 0


func _init() -> void:
	var sheet := CreatureSheet.new()
	for anim in CreatureSheet.NAMES:
		_check(CreatureSheet.FPS.has(anim), "%s: tem quadros por segundo" % anim)
		_check(sheet.frame_count(anim) >= 8, "%s: ao menos 8 quadros" % anim)
		for d in ["se", "e", "ne", "s", "n"]:
			var tex: Texture2D = sheet.textures[anim][d]
			var fs: int = CreatureSheet.FRAME[anim]
			_check(tex != null and tex.get_height() == fs, "%s_%s: altura de %d px" % [anim, d, fs])
			_check(tex != null and tex.get_width() == sheet.frame_count(anim) * fs, "%s_%s: largura é múltiplo do quadro" % [anim, d])
	var cfg := CombatConfig.load_file()
	var e := cfg.make_enemy("criatura_sangue", Vector2.ZERO)
	_check(e != null and e.max_pv == 20, "ficha da Criatura de Sangue existe")
	if failures == 0:
		print("OK: Criatura de Sangue")
	quit(failures)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FALHOU: " + what)
