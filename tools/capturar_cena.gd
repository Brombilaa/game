extends SceneTree
# Captura de uma cena com roteiro (CenaRoteiro) no parque, como aparece no jogo: o grupo junto da árvore, logo depois de
# ver o símbolo, e o gatilho do combate com a cena data/cenas/<id>.json tocando antes dele.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 -s tools/capturar_cena.gd -- prefixo cena t1,t2,...
#   cena "antes" = como era: o combate começa direto, com a segunda criatura atrás do grupo ([450, 800]).
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
	# O grupo junto da árvore, como fica ao ver o símbolo.
	room.party[0].pos = Vector2(1060, 330)
	room.party[1].pos = Vector2(1000, 300)
	room.party[2].pos = Vector2(1010, 370)
	room.player = room.party[0]
	for m in room.party:
		room.follow_paths.erase(m)
		room.facing8[m] = CharacterSheet.Dir.NE
	room.camera.position = room._iso(room.player.pos)
	room.camera.zoom = Vector2(1.5, 1.5)
	for i in 40:
		await process_frame
	var gatilho: Dictionary = room.scenario.triggers_after("arvore_simbolo")[0].duplicate(true)
	if cena_id == "antes":
		gatilho.erase("cutscene_antes")
		gatilho["inimigos"][1]["pos"] = [450, 800]
	else:
		gatilho["cutscene_antes"] = cena_id
	room.pista_gatilho = "arvore_simbolo"
	room._run_trigger(gatilho)
	var quadro := 0
	for t in tempos:
		while quadro < int(t * 30.0):
			await process_frame
			quadro += 1
		root.get_texture().get_image().save_png("%s_%s.png" % [prefixo, str(t)])
		print("ok ", t)
	quit()
