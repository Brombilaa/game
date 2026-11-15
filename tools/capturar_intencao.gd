extends SceneTree
# Captura dos 3 modelos da intenção do inimigo (sugestão 11) no 1º combate do parque.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_intencao.gd -- pasta
func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta: String = args[0] if args.size() > 0 else "capturas"
	DirAccess.make_dir_recursive_absolute(pasta)
	var lugar: String = args[1] if args.size() > 1 else "parque"
	var room
	if lugar == "parque":
		room = load("res://scenes/exploration/parque.tscn").instantiate()
		root.add_child(room)
		for i in 8:
			await process_frame
		room._run_trigger(room.scenario.triggers["combate_arvore"])
	else:  # invasão da delegacia às 21h: 3 atiradores pela porta da frente
		Missao1.reiniciar()
		Missao1.local = "delegacia_21h"
		Missao1.marcar("subsolo_visitado")
		room = load(Missao1.CENA_LOCAL).instantiate()
		root.add_child(room)
		for i in 8:
			await process_frame
		var spots := [Vector2(700, 1000), Vector2(640, 960), Vector2(780, 950)]
		for i in room.party.size():
			room.party[i].pos = spots[i % 3]
		room._invasao(room.dados["invasao"])
	for m in room.party:
		m.max_pv = 999
		m.pv = 999
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		await process_frame
		if room.turns and room.turns.current and room.turns.current.side == Combatant.Side.PLAYER and not room.busy:
			break
	for m in room.party:
		m.max_pv = 30
		m.pv = 22
	var intent: EnemyIntent = room.enemy_intent
	var c := Vector2.ZERO
	for u in room.party + room.enemies:
		c += u.pos
	c /= room.party.size() + room.enemies.size()
	room.camera.position = room._iso(c)
	room.camera.zoom *= float(args[2]) if args.size() > 2 else 0.75
	Input.warp_mouse(Vector2(672, 958))  # mouse fora do cenário: sem a prévia de mira do jogador
	for i in 10:
		await process_frame
	intent.mostrar = false
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("%s/antes.png" % pasta)
	intent.mostrar = true
	for it in room.ai.predict_intents():
		print(it.unit.name, " -> ", it.target.name, " ", it.acao)
	for e in ["A", "B", "C"]:
		intent.estilo = e
		intent.foco = null
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [pasta, e])
		intent.foco = _perto(room)
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_alcance.png" % [pasta, e])
	quit()


func _perto(room) -> Combatant:
	var best: Combatant = null
	for e in room.enemies:
		if e.is_alive() and (best == null or e.pos.distance_to(room.player.pos) < best.pos.distance_to(room.player.pos)):
			best = e
	return best
