extends SceneTree
# Captura a mira vermelha do ataque no parque (antes/depois). xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_mira.gd -- pasta prefixo
func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta: String = args[0] if args.size() > 0 else "capturas"
	var pre: String = args[1] if args.size() > 1 else "mira"
	DirAccess.make_dir_recursive_absolute(pasta)
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 5:
		await process_frame
	room._run_trigger(room.scenario.triggers["combate_arvore"])
	for i in 5:
		await process_frame
	var tgt: Combatant = room.enemies[0]
	var pl: Combatant = room.player
	room.rules.rng.seed = 3
	var r: Dictionary = {}
	for off in [Vector2(-230, -120), Vector2(-200, 120), Vector2(200, 160), Vector2(160, -200), Vector2(-120, 200), Vector2(250, 0), Vector2(-250, 0), Vector2(0, 220), Vector2(0, -220)]:
		pl.pos = tgt.pos + off
		if room.rules.attack_blocker(pl, tgt, room._sight_blockers(), room.covers) == "":
			r = room.rules.attack(pl, tgt, room._sight_blockers(), room.covers)
			break
	print("ataque: ", r.get("ok"), " pos ", pl.pos, " alvo ", tgt.pos)
	room._show_attack(pl, tgt, r)
	room.camera.position = (room._iso(pl.pos) + room._iso(tgt.pos)) * 0.5
	for p in [0.05, 0.5, 0.95]:
		for j in room.fx.jobs:
			j["aim"] = 1000.0
			j["time"] = p * 1000.0
		for i in 4:
			await process_frame
			for j in room.fx.jobs:
				j["time"] = p * 1000.0
		root.get_texture().get_image().save_png("%s/%s_%d.png" % [pasta, pre, int(p * 100)])
	quit()
