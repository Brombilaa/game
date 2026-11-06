extends SceneTree
# Captura do parque 3D (opção 3). xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_parque3d.gd -- saida.png [graus de giro da câmera] [luz do sol] [luz ambiente]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "parque3d.png"
	var sol: float = float(args[2]) if args.size() > 2 else 0.6
	var amb: float = float(args[3]) if args.size() > 3 else 0.03
	var giro: float = float(args[1]) if args.size() > 1 else 0.0
	var cena: Node = load("res://scenes/exploration/parque3d.tscn").instantiate()
	cena.luz_sol = sol
	cena.luz_ambiente = amb
	root.add_child(cena)
	for i in 10:
		await process_frame
	if args.size() > 4:
		var zoom: float = float(args[4])
		cena.camera.size = 5.54 / zoom
		cena.camera.position += Vector3(0, 0.6, 0)
	if args.size() > 6:  # desloca o alvo da câmera: x e z em unidades 3D
		cena.camera.position += Vector3(float(args[5]) - cena.ALVO.x, 0, float(args[6]) - cena.ALVO.z)
	if giro != 0.0:
		var c: Camera3D = cena.camera
		var alvo: Vector3 = cena.ALVO
		var rel := c.position - alvo
		rel = rel.rotated(Vector3.UP, deg_to_rad(giro))
		c.position = alvo + rel
		c.look_at(alvo, Vector3.UP)
	if OS.get_environment("SEMFX") != "":  # depuração: mostra o 3D cru, sem o filtro
		for c in cena.get_children():
			if c is CanvasLayer and c.layer == 100:
				c.visible = false
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("ok ", saida)
	quit()
