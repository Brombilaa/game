extends SceneTree
# Captura da cutscene do fim da missão 1 (tentáculo da Dama de Sangue atravessa o Fernando) como aparece no jogo.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 -s tools/capturar_fim.gd -- prefixo modo t1,t2,... [zoom=1.5]
#   modo: 0 faixas 2,39:1, 1 vertical 9:16, 2 quadro 16:9 reduzido; "antes" = só o jogo normal (combate com a Dama a 30%).
#   (--fixed-fps 30 deixa o tempo do jogo contar por quadro, não pelo relógio lento do render por software.)
#   t: segundos depois do começo da cutscene em que tirar cada captura (prefixo_<t>.png).
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var prefixo := a[0]
	var modo := int(a[1])
	var tempos: Array = []
	for s in str(a[2]).split(","):
		tempos.append(float(s))
	Cinema.modo_global = modo as Cinema.Modo
	Missao1.reiniciar()
	Missao1.local = "cripta"
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4", "dama_surgiu"]:
		Missao1.marcar(m)
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 6:
		await process_frame
	var dama: Combatant = null
	for e in room.enemies:
		if e.name == "Dama de Sangue":
			dama = e
	# O grupo à frente do altar, a Dama no altar.
	var base: Vector2 = dama.pos
	room.party[0].pos = base + Vector2(120, 330)  # Fernando
	room.party[1].pos = base + Vector2(-130, 330)
	room.party[2].pos = base + Vector2(330, 400)
	room.player = room.party[0]
	for m in room.party:
		room.follow_paths.erase(m)
	room.camera.position = room._iso(base + Vector2(100, 200))
	room.camera.zoom = Vector2(1.5, 1.5)
	for e in room.enemies:
		if e != dama:
			e.pv = 0
	dama.pv = int(dama.max_pv * 0.3)
	room._start_combat()
	for i in 50:
		await process_frame
	if a[1] == "antes":
		root.get_texture().get_image().save_png(prefixo + "_antes.png")
		quit()
		return
	room.iniciar_fim(dama)
	var quadro := 0
	for t in tempos:
		while quadro < int(t * 30.0):
			await process_frame
			quadro += 1
		root.get_texture().get_image().save_png("%s_%s.png" % [prefixo, str(t)])
		print("ok ", t)
	quit()
