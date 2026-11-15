extends SceneTree
# Captura da luta da Dama de Sangue na cripta com um dos 3 modelos visuais (ChefeDama.estilo).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_dama.gd -- saida.png A|B|C|antes [aviso] [quebrado]
#   aviso: captura no meio do aviso da fase 2; quebrado: um símbolo já quebrado.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var estilo := a[1]
	var aviso := a.has("aviso")
	ChefeDama.estilo = estilo if estilo != "antes" else "A"
	Progresso.autosave_ativo = false
	Missao1.reiniciar()
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4"]:
		Missao1.marcar(m)
	Missao1.local = "cripta"
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 6:
		await process_frame
	# Grupo na ponte sul, perto do símbolo do sudoeste; os cultistas do salão fora do quadro.
	var base := Vector2((31.0 + 8.0) * 64.0, (22.4 - 2.0) * 64.0)
	var offs := [Vector2(0, 0), Vector2(70, 30), Vector2(-60, 60)]
	for i in room.party.size():
		room.party[i].pos = base + offs[i]
	var roberto: Combatant = null
	for e in room.enemies:
		if e.name == "Roberto Ghular":
			roberto = e
		elif e.pos.distance_to(base) < 900.0:
			e.pos += Vector2(0, -2000) if e.pos.y > 700 else Vector2.ZERO
	room._start_combat()
	roberto.pv = 3
	room._show_attack(room.player, roberto, {"ok": true, "hit": true, "damage": 3, "crit": false, "blocked": false})
	var cd: ChefeDama = room.chefe_dama
	if estilo == "antes":
		cd.encerrar()
		for s in cd.nos:
			cd.nos[s].queue_free()
		room.chefe_dama = null
	else:
		if a.has("quebrado"):
			cd.simbolos[1].pv = 0
			cd.ao_impacto(cd.simbolos[1])
		cd.carga = {"centro": room.party[0].pos + Vector2(12, 8), "raio": cd.raio_mare()}
		cd._mostrar_zona()
	room.camera.zoom = Vector2(0.9, 0.9)
	room.player.pos = room.party[0].pos
	var dama: Combatant = room.enemies.filter(func(e: Combatant) -> bool: return e.name == "Dama de Sangue")[0]
	for i in 50:
		await process_frame
	room.cam_pan = (room._iso(dama.pos) - room._iso(room.party[0].pos)) * 0.6
	if a.has("longe"):
		room.camera.zoom = Vector2(0.6, 0.6)
	for i in 20:
		await process_frame
	Input.warp_mouse(Vector2(1900, 1060))  # o cursor no canto: sem a prévia de "Inacessível" no meio da tela
	room.popups.clear()
	room.combat_log.clear()
	await process_frame
	if aviso and room.chefe_dama:
		cd.dama.pv = 60
		cd.ao_impacto(cd.dama)
		await create_timer(1.0 if estilo != "C" else 1.6).timeout
	root.get_texture().get_image().save_png(a[0])
	print("ok ", a[0])
	quit()
