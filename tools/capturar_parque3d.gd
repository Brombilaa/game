extends SceneTree
# Captura do parque 3D (opção 3). xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_parque3d.gd -- saida.png [graus de giro da câmera] [luz do sol] [luz ambiente] [zoom] [alvo x] [alvo z]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "parque3d.png"
	var sol: float = float(args[2]) if args.size() > 2 else 0.22
	var amb: float = float(args[3]) if args.size() > 3 else 0.10
	var giro: float = float(args[1]) if args.size() > 1 else 0.0
	var cena: Node = load("res://scenes/exploration/parque3d.tscn").instantiate()
	cena.luz_sol = sol
	cena.luz_ambiente = amb
	if OS.get_environment("AO") != "":
		cena.forca_oclusao = float(OS.get_environment("AO"))
	if OS.get_environment("POSTE") != "":
		cena.luz_poste = float(OS.get_environment("POSTE"))
	if OS.get_environment("QUEDA") != "":
		cena.queda_poste = float(OS.get_environment("QUEDA"))
	if OS.get_environment("CEU") != "":
		cena.luz_ceu = float(OS.get_environment("CEU"))
	root.add_child(cena)
	for i in 10:
		await process_frame
	if args.size() > 4:
		var zoom: float = float(args[4])
		cena.camera.size = 5.54 / zoom
		if zoom != 1.0:
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
	if OS.get_environment("IDMAT") != "":  # calibragem: cada material do cenário vira uma cor sólida (id = índice no nome mN)
		cena.mundo.msaa_3d = Viewport.MSAA_DISABLED
		for c in cena.camera.get_children():
			c.visible = false
		for m in cena.mundo.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if not mi.visible or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				var id := 255
				if mat and mat.resource_name.begins_with("m") and mat.resource_name.substr(1).is_valid_int():
					id = int(mat.resource_name.substr(1))
				var u := ShaderMaterial.new()
				u.shader = load("res://tools/id_material.gdshader")
				var nivel := 252 if id == 255 else 64 + 2 * id  # faixa onde a saída sai exata (abaixo de ~60 ela entorta)
				u.set_shader_parameter("cor", Vector3(nivel / 255.0, 0.0, 0.0))
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					var b := mat as BaseMaterial3D
					u.set_shader_parameter("usa_alfa", true)
					u.set_shader_parameter("tex", b.albedo_texture)
					u.set_shader_parameter("escala", b.uv1_scale)
					u.set_shader_parameter("desloc", b.uv1_offset)
				mi.set_surface_override_material(i, u)
		cena.get_viewport().world_3d.environment = null
	if OS.get_environment("SEMFX") != "" or OS.get_environment("IDMAT") != "":  # depuração: mostra o 3D cru, sem o filtro
		for c in cena.get_children():
			if c is CanvasLayer and c.layer == 100:
				c.visible = false
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("ok ", saida)
	quit()
