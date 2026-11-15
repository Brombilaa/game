extends SceneTree
# Grava em vídeo a cutscene do fim da missão 1 (tentáculo da Dama de Sangue atravessa o Fernando) como aparece no jogo.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 --write-movie fim.avi -s tools/gravar_fim.gd -- 0
#   (o argumento é o modo do cinema; o vídeo acaba quando a cutscene termina, na tela do FIM DO CAPÍTULO)
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var modo := int(a[0])
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
	room.iniciar_fim(dama)
	var cena: CenaTentaculo = null
	for c in room.get_children():
		if c is CenaTentaculo:
			cena = c
	await cena.terminou
	for i in 20:
		await process_frame
	quit()
