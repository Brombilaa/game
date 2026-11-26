extends SceneTree
# Captura da cena da transformação da Dama (CenaTransformacao) na cripta, com um dos 3 modelos.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 -s tools/capturar_transformacao.gd -- prefixo A|B|C|antes t1,t2,...
#   t: segundos depois do golpe em que tirar cada captura (prefixo_<estilo>_<t>.png). "antes" = como era: a Dama surge na hora.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var estilo := a[1]
	CenaTransformacao.estilo = estilo if estilo != "antes" else "A"
	var tempos: Array = []
	for s in str(a[2]).split(","):
		tempos.append(float(s))
	Progresso.autosave_ativo = false
	Missao1.reiniciar()
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4"]:
		Missao1.marcar(m)
	Missao1.local = "cripta"
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 6:
		await process_frame
	var base := Vector2((31.5 + 8.0) * 64.0, (20.6 - 2.0) * 64.0)
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
	room.camera.zoom = Vector2(0.9, 0.9)
	for i in 30:
		await process_frame
	if estilo == "antes":
		CenaTransformacao.pular = true  # a Dama surge na hora, como antes
	room._show_attack(room.player, roberto, {"ok": true, "hit": true, "damage": 3, "crit": false, "blocked": false})
	if room.turns.current != null and not room.party.has(room.turns.current):
		room.turns.end_turn.call_deferred()  # na luta, quem acerta é do grupo e o turno dele acaba logo
	var quadro := 0
	for t in tempos:
		while quadro < int(t * 30.0):
			await process_frame
			quadro += 1
		root.get_texture().get_image().save_png("%s_%s_%s.png" % [a[0], estilo, str(t)])
		print("ok ", t)
	quit()
