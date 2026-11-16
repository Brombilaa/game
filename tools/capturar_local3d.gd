extends SceneTree
# Captura de um lugar 3D da missão 1 como aparece no jogo (grupo, HUD, cenário).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_local3d.gd -- saida.png id [chegada] [marca ...] [zoom=1.5] [olhar=x,y] [espera=quadros] [semluz] [lanterna] [tiro] [cegos]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Missao1.reiniciar()
	Missao1.local = a[1]
	var zoom := 0.0
	var olhar := Vector2.INF
	var espera := 40
	var sem_luz := false
	var tiro := false
	var lanterna := false
	var cegos := false
	for i in range(2, a.size()):
		if a[i].begins_with("zoom="):
			zoom = float(a[i].trim_prefix("zoom="))
		elif a[i].begins_with("olhar="):
			var v := a[i].trim_prefix("olhar=").split(",")
			olhar = Vector2(float(v[0]), float(v[1]))
		elif a[i].begins_with("espera="):
			espera = int(a[i].trim_prefix("espera="))
		elif a[i] == "semluz":
			sem_luz = true
		elif a[i] == "lanterna":
			lanterna = true
		elif a[i] == "cegos":  # inimigos sem percepção (para mostrar a exploração com a lanterna acesa)
			cegos = true
		elif a[i] == "tiro":
			tiro = true
		elif a[i].begins_with("chegada="):
			Missao1.chegada = a[i].trim_prefix("chegada=")
		else:
			Missao1.marcar(a[i])
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	if cegos:  # antes do primeiro quadro: a detecção roda já no _process
		room.set_process(false)
	for i in 6:
		await process_frame
	if cegos:
		for e in room.enemies:
			e.perception = 0.0
		room.set_process(true)
	if zoom > 0.0:
		room.camera.zoom = Vector2(zoom, zoom)
	if olhar != Vector2.INF:
		room.player.pos = olhar
	if lanterna:
		room.luz_dinamica.ligada = true
	if sem_luz:
		room.luz_dinamica.ligada = false
		room.luz_dinamica.intensidade = 0.0
	for i in espera:
		await process_frame
	if tiro:  # clarão de disparo na arma do líder, um quadro antes da captura
		room.luz_dinamica.clarao(Vector3(room.player.pos.x / 64.0 + 0.6, 1.3, room.player.pos.y / 64.0))
		await process_frame
	root.get_texture().get_image().save_png(a[0])
	print("ok ", a[0])
	quit()
