extends SceneTree
# Morte do Túlio (22/11): ao voltar do subsolo a cena toca antes da flashbang e só depois entram os atiradores.
# Fica fora do test_cenas_dialogo porque o CI dá 60 s por teste.
# Rodar com:
#   godot --headless --path . -s tests/test_morte_tulio.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	Engine.time_scale = 4.0
	Missao1.reiniciar()
	for m in ["ghular_21h", "alcapao", "subsolo_visitado"]:
		Missao1.marcar(m)
	Missao1.local = "delegacia_21h"
	Missao1.chegada = ""
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	_entrar_na_zona(room, "invasao")
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and room.enemies.is_empty(), "a morte do Túlio toca antes de os atiradores entrarem")
	for i in 9000:
		if not room.enemies.is_empty():
			break
		await process_frame
	_check(Missao1.tem("tulio_morreu") and not room.enemies.is_empty(), "depois da morte do Túlio vem a invasão")
	Engine.time_scale = 1.0
	print("Falhas: %d" % failures if failures > 0 else "OK: test_morte_tulio")
	quit(1 if failures > 0 else 0)


func _entrar_na_zona(room, id: String) -> void:
	for z in room.dados["zonas"]:
		if z["id"] == id:
			room.player.pos = _ponto_livre(room, room._ret(z))
			room.dentro_de[id] = false
			room._zonas()


func _ponto_livre(room, r: Rect2) -> Vector2:
	var best := r.get_center()
	var best_d := INF
	for i in 9:
		for j in 9:
			var p := r.position + r.size * Vector2((i + 0.5) / 9.0, (j + 0.5) / 9.0)
			if Pathfinder.is_free(p, room._obstacles(room.player), room.player.radius) and p.distance_to(r.get_center()) < best_d:
				best = p
				best_d = p.distance_to(r.get_center())
	return best

func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
