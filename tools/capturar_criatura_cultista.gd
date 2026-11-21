extends SceneTree
# Captura a Criatura de Sangue e o Cultista F em 3D (Léo, 21/11) na câmera do jogo: cada animação em 6 fases, de frente
# para a câmera (SE). Saída: pasta/<personagem>_<animação>_<fase>.png
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 360x360 -s tools/capturar_criatura_cultista.gd -- pasta
const FASES := [0.0, 0.2, 0.4, 0.6, 0.8, 0.98]
const ANIMS := {"criatura": ["idle", "transition", "walk", "attack", "death"], "cultista3d": ["idle", "walk", "attack", "death"]}


func _initialize() -> void:
	_run()


func _run() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 35, 0)
	root.add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.2, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	root.add_child(env)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.0
	var az := PI / 4.0
	var el: float = Agente3D.P3D.ELEV
	cam.look_at_from_position(Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * 20.0 + Vector3(0, 1.0, 0), Vector3(0, 1.0, 0))
	Agente3D.relogio_teste = 100000
	for quem in ANIMS:
		var ag := Agente3D.new(quem)
		root.add_child(ag)
		ag.virar(az)
		for anim in ANIMS[quem]:
			for f in FASES:
				for k in 8:  # a pose se mistura com a anterior com o relógio andando, como no jogo
					Agente3D.relogio_teste += 25
					ag.pose(anim, f)
					await process_frame
				root.get_viewport().get_texture().get_image().save_png("%s/%s_%s_%d.png" % [pasta, quem, anim, int(f * 100)])
		ag.queue_free()
	quit()
