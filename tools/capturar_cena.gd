extends SceneTree
# Captura de uma cena com roteiro (CenaRoteiro) no parque, como aparece no jogo: o grupo logo depois do combate da
# árvore, perto do Caio e da Letícia, e a cena data/cenas/<id>.json tocando.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 -s tools/capturar_cena.gd -- prefixo cena t1,t2,...
#   cena "antes" = só o parque, sem cena (como era: vitória e direto para a delegacia).
#   t: segundos depois do começo da cena em que tirar cada captura (prefixo_<t>.png).
#   (--fixed-fps 30 deixa o tempo do jogo contar por quadro, não pelo relógio lento do render por software.)
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var prefixo := a[0]
	var cena_id := a[1]
	var tempos: Array = []
	for s in str(a[2]).split(","):
		tempos.append(float(s))
	Missao1.reiniciar()
	var room = load(Missao1.CENA_PARQUE).instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	# Fim do combate da árvore: o grupo entre o meio do parque e os NPCs.
	room.party[0].pos = Vector2(560, 660)
	room.party[1].pos = Vector2(620, 600)
	room.party[2].pos = Vector2(640, 700)
	room.player = room.party[0]
	for m in room.party:
		room.follow_paths.erase(m)
		room.facing8[m] = CharacterSheet.Dir.SW
	room.camera.position = room._iso(Vector2(470, 690))
	room.camera.zoom = Vector2(1.5, 1.5)
	for i in 40:
		await process_frame
	if cena_id == "antes":
		root.get_texture().get_image().save_png(prefixo + "_antes.png")
		quit()
		return
	room.tocar_cena(cena_id)
	var quadro := 0
	for t in tempos:
		while quadro < int(t * 30.0):
			await process_frame
			quadro += 1
		root.get_texture().get_image().save_png("%s_%s.png" % [prefixo, str(t)])
		print("ok ", t)
	quit()
