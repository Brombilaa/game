extends SceneTree
# Mede o desempenho da exploração com o grupo andando: tempo por quadro, rotas dos seguidores, tempo do _draw
# e contadores do renderizador. Não inventa número: imprime o que mediu.
#   godot --headless --path . -s tools/medir_desempenho.gd -- parque [quadros=600]
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/medir_desempenho.gd -- delegacia_17h
# O primeiro argumento é "parque" ou o id de um cenário local3d (delegacia_17h, delegacia_21h, biblioteca, fazenda).


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var lugar: String = a[0] if a.size() > 0 else "parque"
	var quadros := 600
	for i in range(1, a.size()):
		if a[i].begins_with("quadros="):
			quadros = int(a[i].trim_prefix("quadros="))
	Progresso.autosave_ativo = false
	Missao1.reiniciar()
	var cena := Missao1.CENA_PARQUE
	if lugar != "parque":
		Missao1.local = lugar
		cena = Missao1.CENA_LOCAL
	var t0 := Time.get_ticks_usec()
	var room = load(cena).instantiate()
	root.add_child(room)
	for i in 5:
		await process_frame
	print("carga da cena: %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	room.perf_on = false
	# Sem inimigos percebendo: mede só a exploração.
	for e in room.enemies:
		e.perception = 0.0
	var pts := _percurso(room)
	var tempos: Array[float] = []
	var draw_us: Array[float] = []
	var mapa_us: Array[float] = []
	var rotas0: int = room.pathfinder.calls_total
	var usec0: int = room.pathfinder.usec_total
	var ponto := 0
	var anterior := Time.get_ticks_usec()
	for q in quadros:
		if room.path.is_empty() and room.moving_unit == null and room.mode == room.Mode.EXPLORATION:
			var destino: Vector2 = pts[ponto % pts.size()]
			ponto += 1
			var tr0 := Time.get_ticks_usec()
			var rota: PackedVector2Array = room.pathfinder.find_path(room.player.pos, destino, room._obstacles(room.player), room.player.radius)
			print("  rota do líder (clique): %.1f ms, %d pontos" % [(Time.get_ticks_usec() - tr0) / 1000.0, rota.size()])
			if rota.size() > 1:
				room._reset_follow_offsets(destino - room.player.pos)
				room._start_move(room.player, rota)
		await process_frame
		var agora := Time.get_ticks_usec()
		tempos.append((agora - anterior) / 1000.0)
		if (agora - anterior) > 20000:
			print("  engasgo no quadro %d: %.1f ms (draw %.1f ms, process %.1f ms, fisica %.1f ms, andando=%s, nós %d)" % [q, (agora - anterior) / 1000.0, room._draw_usec / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, room.moving_unit != null, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		anterior = agora
		draw_us.append(room._draw_usec / 1000.0)
		mapa_us.append(room._minimap_usec / 1000.0)
	if "micro" in a:  # com render (xvfb): custo isolado da prévia de pista sob o mouse e dos seguidores, com a câmera andando
		var hov: Array[float] = []
		var seg: Array[float] = []
		var primeiro := 0.0
		for q in 40:
			if room.path.is_empty() and room.moving_unit == null:
				var rota2: PackedVector2Array = room.pathfinder.find_path(room.player.pos, pts[(ponto + q) % pts.size()], room._obstacles(room.player), room.player.radius)
				if rota2.size() > 1:
					room._start_move(room.player, rota2)
			await process_frame
			var m: Vector2 = room.get_global_mouse_position()
			var h0 := Time.get_ticks_usec()
			room._clue_under(m)
			var h1 := Time.get_ticks_usec()
			room._update_followers(1.0 / 60.0)
			var h2 := Time.get_ticks_usec()
			if q == 0:
				primeiro = (h1 - h0) / 1000.0
			else:
				hov.append((h1 - h0) / 1000.0)
				seg.append((h2 - h1) / 1000.0)
		hov.sort()
		seg.sort()
		print("micro: _clue_under primeira chamada %.2f ms; depois p50 %.2f  p95 %.2f  max %.2f ms" % [primeiro, hov[hov.size() / 2], hov[int(hov.size() * 0.95)], hov[hov.size() - 1]])
		print("micro: _update_followers p50 %.2f  p95 %.2f  max %.2f ms" % [seg[seg.size() / 2], seg[int(seg.size() * 0.95)], seg[seg.size() - 1]])
	tempos.sort()
	draw_us.sort()
	mapa_us.sort()
	var soma := 0.0
	for t in tempos:
		soma += t
	print("lugar=%s quadros=%d" % [lugar, quadros])
	print("quadro ms: medio %.2f  p50 %.2f  p95 %.2f  p99 %.2f  max %.2f" % [soma / tempos.size(), tempos[tempos.size() / 2], tempos[int(tempos.size() * 0.95)], tempos[int(tempos.size() * 0.99)], tempos[tempos.size() - 1]])
	print("_draw ms: p50 %.2f  p95 %.2f  max %.2f" % [draw_us[draw_us.size() / 2], draw_us[int(draw_us.size() * 0.95)], draw_us[draw_us.size() - 1]])
	print("radar ms (dentro do _draw): p50 %.2f  p95 %.2f  max %.2f" % [mapa_us[mapa_us.size() / 2], mapa_us[int(mapa_us.size() * 0.95)], mapa_us[mapa_us.size() - 1]])
	var chamadas: int = room.pathfinder.calls_total - rotas0
	print("rotas: %d chamadas (%.1f por segundo simulado), %.1f ms no total, %.2f ms cada" % [chamadas, chamadas / (quadros / 60.0), (room.pathfinder.usec_total - usec0) / 1000.0, (room.pathfinder.usec_total - usec0) / 1000.0 / maxf(chamadas, 1)])
	print("nós: %d  objetos: %d  draw calls: %d  luzes omni: %d" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), get_nodes_in_group("") .size()])
	quit()


# Cantos livres do cenário para o líder cruzar de um lado a outro.
func _percurso(room) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var tam: Vector2 = room.scenario.size
	for f in [Vector2(0.5, 0.5), Vector2(0.2, 0.3), Vector2(0.8, 0.3), Vector2(0.8, 0.75), Vector2(0.2, 0.75)]:
		var alvo: Vector2 = room._nearest_free(tam * f) if room.has_method("_nearest_free") else tam * f
		out.append(alvo)
	return out
