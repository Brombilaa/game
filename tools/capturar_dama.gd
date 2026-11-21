extends SceneTree
# Captura da luta da Dama de Sangue (7 flores) na cripta com um dos 3 modelos visuais (DamaVisual.estilo).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_dama.gd -- saida.png A|B|C|antes [aviso|fase2|longe]
#   (sem extra): fase 1 com Selena devorada (Laranja aberta e vulnerável), Bruno salvo, Vermelha aberta e o Miasma no grupo;
#   aviso: no meio do aviso da flor que abre; fase2: no aviso da fase 2, com todas as flores abertas; longe: a arena inteira.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var estilo := a[1]
	DamaVisual.estilo = estilo if estilo != "antes" else "A"
	Progresso.autosave_ativo = false
	Missao1.reiniciar()
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4"]:
		Missao1.marcar(m)
	Missao1.local = "cripta"
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 6:
		await process_frame
	# Grupo na ponte sul; os cultistas do salão fora do quadro.
	var base := Vector2((31.5 + 8.0) * 64.0, (20.6 - 2.0) * 64.0)  # ponte sul (origem da sala em -8, 2 m)
	var offs := [Vector2(0, 0), Vector2(46, 40), Vector2(-46, 50)]
	for i in room.party.size():
		room.party[i].pos = base + offs[i]
	var roberto: Combatant = null
	for e in room.enemies:
		if e.name == "Roberto Ghular":
			roberto = e
		else:
			e.pv = 0
	room._start_combat()
	roberto.pv = 3
	room._show_attack(room.player, roberto, {"ok": true, "hit": true, "damage": 3, "crit": false, "blocked": false})
	var cd: ChefeDama = room.chefe_dama
	if estilo == "antes":
		for f in cd.flores:
			if f["unit"]:
				room.enemies.erase(f["unit"])
		for c in cd.corpos:
			room.enemies.erase(c["tentaculo"])
		room.chefe_dama = null
	else:
		cd.corpos[0]["estado"] = "devorado"
		cd._abrir(cd.flores[0], true)
		cd.corpos[1]["estado"] = "salvo"
		(cd.corpos[1]["tentaculo"] as Combatant).pv = 0
		if a.has("fase2"):
			cd.dama.pv = 50
	room.camera.zoom = Vector2(0.9, 0.9)
	room.player.pos = room.party[0].pos
	var dama: Combatant = room.enemies.filter(func(e: Combatant) -> bool: return e.name == "Dama de Sangue")[0]
	for i in 50:
		await process_frame
	room.camera.zoom = Vector2(0.8, 0.8)
	room.cam_pan = (room._iso(dama.pos) - room._iso(room.party[0].pos)) * 0.8
	if a.has("longe"):
		room.camera.zoom = Vector2(0.55, 0.55)
		room.cam_pan = (room._iso(dama.pos) - room._iso(room.party[0].pos)) * 0.95
	for i in 30:
		await process_frame
	Input.warp_mouse(Vector2(1900, 1060))  # o cursor no canto: sem a prévia de "Inacessível" no meio da tela
	room.popups.clear()
	room.combat_log.clear()
	await process_frame
	if room.chefe_dama and not a.has("longe"):
		if a.has("fase2"):
			cd.ao_impacto(cd.dama)
			await create_timer(1.0 if estilo != "C" else 1.6).timeout
		elif a.has("aviso"):
			var fd: Dictionary = cd.flores[0]["dados"]
			cd.visual.anunciar("FLOR LARANJA · VISÃO MACABRA", Color(fd["rgb"][0], fd["rgb"][1], fd["rgb"][2]), false)
			await create_timer(0.9 if estilo != "C" else 1.2).timeout
		else:
			cd.visual.zona(room.party[1].pos, 3.0 * 32.0, "chuva_sangue", 60.0)
			for i in 12:
				await process_frame
	root.get_texture().get_image().save_png(a[0])
	print("ok ", a[0])
	quit()
