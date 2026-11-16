extends SceneTree
# Captura o aviso de SAN no combate do parque: antes (só texto), susto, ruptura e loucura (modelo C com B).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_san.gd -- pasta
func _initialize() -> void:
	_run()


func _shot(pasta: String, nome: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [pasta, nome])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta: String = args[0] if args.size() > 0 else "capturas"
	DirAccess.make_dir_recursive_absolute(pasta)
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	Missao1.marcar("caio_morreu")  # pula a cena da morte do Caio (já vista)
	room._run_trigger(room.scenario.triggers["combate_arvore"])
	var t0 := Time.get_ticks_msec()
	while (room.turns == null or room.mode != room.Mode.COMBAT or room.cena != null) and Time.get_ticks_msec() - t0 < 40000:
		await process_frame  # espera a cena da morte do Caio acabar e o combate começar
	for i in 20:
		await process_frame
	var fx: SanFx = room.san_fx
	fx.scare_t = 99.0
	fx.madness_t = 99.0
	for m in room.party:
		m.ruptured = false
		m.san = m.max_san
	room.popups.clear()
	for i in 4:
		await process_frame
	_shot(pasta, "san_antes")
	# Susto: o grupo vê a Criatura (-3 SAN).
	for m in room.party:
		m.san = m.max_san - 3
		room.room_combat._popup(m.pos, "-3 SAN", "san")
	fx.scare()
	for i in 6:
		fx.scare_t = 0.12
		await process_frame
	_shot(pasta, "san_susto")
	# Ruptura do líder: fantasma, frases no chão, olho rachado no cartão e fala sozinho.
	room.popups.clear()
	var lider: Combatant = room.player
	lider.san = 0
	lider.ruptured = true
	fx.scare_t = 99.0
	room._popup(lider.pos, "\"Isso não é real...\"", "fala")
	room.popups[-1]["time"] = 99.0
	room.popups[-1]["dur"] = 99.0
	for i in 8:
		await process_frame
	_shot(pasta, "san_ruptura")
	# Loucura: tela vermelha e depois cinza.
	room.popups.clear()
	fx.madness()
	for i in 6:
		fx.madness_t = 0.15
		fx.scare_t = 0.3
		await process_frame
	_shot(pasta, "san_loucura")
	quit()
