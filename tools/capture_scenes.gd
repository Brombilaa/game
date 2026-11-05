extends SceneTree
# Captura de tela das cenas principais (M2). Precisa de janela de verdade (não é headless):
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capture_scenes.gd -- capturas
# O último argumento é a pasta de saída (padrão: capturas). O CI roda isto e guarda os PNG como artefato.

const FRAMES := 20  # quadros esperados antes de cada captura (a cena termina de se montar e desenhar)

var out_dir := "capturas"
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	await _shot_scene("menu_inicial", "res://scenes/menu/main_menu.tscn")
	await _shot_scene("parque", "res://scenes/exploration/parque.tscn")
	await _shot_scene("sala_exploracao", "res://scenes/exploration/test_room.tscn")
	await _shot_combat()
	print("Capturas: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _wait(frames := FRAMES) -> void:
	for i in frames:
		await process_frame


func _save(name: String) -> void:
	await _wait()
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		failures += 1
		push_error("captura vazia: " + name)
		return
	var path := "%s/%s.png" % [out_dir, name]
	var err := img.save_png(path)
	if err != OK:
		failures += 1
		push_error("não gravou " + path)
	else:
		print("ok   - ", path, " ", img.get_size())


func _shot_scene(name: String, scene: String) -> void:
	var node: Node = load(scene).instantiate()
	root.add_child(node)
	await _save(name)
	node.queue_free()
	await process_frame


# Mesmo cenário do teste de combate: porta aberta e o agente à vista dos inimigos.
func _shot_combat() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	room.rules.rng.seed = 3
	root.add_child(room)
	await process_frame
	room.door_open = true
	room.player.pos = Vector2(650, 360)
	await _save("sala_combate")
	room.queue_free()
	await process_frame
