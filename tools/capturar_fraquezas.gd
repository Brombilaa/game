extends SceneTree
# Captura das fraquezas no jogo: o diário com a descoberta (INIMIGOS) e os avisos FRAQUEZA/RESISTE no combate do parque.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_fraquezas.gd -- pasta
func _initialize() -> void:
	var pasta := OS.get_cmdline_user_args()[0]
	Missao1.reiniciar()
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	var gd: GameData = room.rules.cfg.game_data
	Diario.anotar("PARQUE · 16h", "banco_quebrado", room.scenario.clues["banco_quebrado"]["texto"], "")
	Fraquezas.ao_examinar(gd, "banco_quebrado")
	room.diario_panel.abrir()
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(pasta + "/fraquezas_diario.png")
	room.diario_panel.fechar()
	# Avisos de combate sobre uma Criatura e um cultista perto do grupo.
	var p: Vector2 = room.player.pos
	var cri: Combatant = room.cfg.make_enemy("criatura_sangue", p + Vector2(160, 120))
	var cul: Combatant = room.cfg.make_enemy("cultista", p + Vector2(-40, 200))
	room.enemies.append(cri)
	room.enemies.append(cul)
	room.camera.position = room._iso(p + Vector2(120, 160))
	for i in 90:
		await process_frame
	room.popups.clear()
	room.camera.position = room._iso(p + Vector2(120, 160))
	room.room_combat._popup(cri.pos, "-3", "damage")
	room.room_combat._afinidade(cri, {"afinidade": "resistencia", "tipo_dano": "balistico"})
	room.room_combat._popup(cul.pos, "-4", "damage")
	room.room_combat._afinidade(cul, {"afinidade": "resistencia", "tipo_dano": "ritual"})
	var ati: Combatant = room.cfg.make_enemy("atirador", p + Vector2(280, 230))
	room.enemies.append(ati)
	room.room_combat._popup(ati.pos, "-3", "damage")
	room.room_combat._afinidade(ati, {"afinidade": "fraqueza", "tipo_dano": "corpo_a_corpo"})
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(pasta + "/fraquezas_combate.png")
	print("ok")
	quit()
