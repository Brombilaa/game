extends SceneTree
# Captura do parque 3D (opção 3). xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_parque3d.gd -- saida.png [graus de giro da câmera]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "parque3d.png"
	var giro: float = float(args[1]) if args.size() > 1 else 0.0
	var cena: Node = load("res://scenes/exploration/parque3d.tscn").instantiate()
	root.add_child(cena)
	for i in 10:
		await process_frame
	if giro != 0.0:
		var c: Camera3D = cena.camera
		var alvo: Vector3 = cena.ALVO
		var rel := c.position - alvo
		rel = rel.rotated(Vector3.UP, deg_to_rad(giro))
		c.position = alvo + rel
		c.look_at(alvo, Vector3.UP)
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("ok ", saida)
	quit()
