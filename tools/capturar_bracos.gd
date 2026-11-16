extends SceneTree
# Captura um personagem 3D em três vistas (frente, lado e a câmera do jogo) em várias fases de cada animação, e mede
# onde ficam as mãos em relação ao tronco (Léo, 13/11: braços do Miguel afastados, depois "muito na frente").
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/capturar_bracos.gd -- pasta prefixo [personagem] [animação]
# Com uma animação no fim, só ela, em 16 fases (para montar um GIF).
# Saída: pasta/prefixo_<anim>_<vista>_<fase>.png. Medidas: x = para o lado (+ esquerda do personagem), z = para a frente.
const ANIMS := ["idle", "walk", "run", "crouch_walk", "pistol_idle", "pistol_walk"]
const FASES := [0.0, 0.25, 0.5, 0.75]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta: String = args[0] if args.size() > 0 else "capturas"
	var pre: String = args[1] if args.size() > 1 else "bracos"
	var quem: String = args[2] if args.size() > 2 else "miguel3d"
	DirAccess.make_dir_recursive_absolute(pasta)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 20, 0)
	root.add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.37, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var ag := Agente3D.new(quem)
	root.add_child(ag)
	ag.rotation.y = 0.0  # olhando para +Z
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var az := PI / 4.0
	var el: float = Agente3D.P3D.ELEV
	var vistas := {
		"frente": [Vector3(0, 1.1, 6.0), false],
		"lado": [Vector3(6.0, 1.1, 0), false],
		"jogo": [Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * 20.0 + Vector3(0, 1.1, 0), true],
	}
	Agente3D.relogio_teste = 0
	var anims: Array = [args[3]] if args.size() > 3 else ANIMS
	var fases: Array = FASES
	if args.size() > 3:
		fases = []
		for i in 16:
			fases.append(i / 16.0)
	for anim in anims:
		for f in fases:
			for i in 3:
				ag.pose(anim, f, true)
				Agente3D.relogio_teste += 100
				await process_frame
			_medir(ag, anim, f)
			for v in vistas:
				var pos: Vector3 = vistas[v][0]
				cam.projection = Camera3D.PROJECTION_ORTHOGONAL if vistas[v][1] else Camera3D.PROJECTION_PERSPECTIVE
				cam.size = 2.6
				cam.fov = 24
				cam.look_at_from_position(pos, Vector3(0, 1.1, 0))
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png("%s/%s_%s_%s_%d.png" % [pasta, pre, anim, v, roundi(f * 100)])
	quit()


func _medir(ag: Agente3D, anim: String, f: float) -> void:
	var sk := ag.esqueleto
	var m := sk.global_transform
	var q := (m * sk.get_bone_global_pose(sk.find_bone("mixamorig_Spine1"))).origin
	var txt := "%-12s %.2f" % [anim, f]
	for lado in ["Left", "Right"]:
		var mao := (m * sk.get_bone_global_pose(sk.find_bone("mixamorig_%sHand" % lado))).origin - q
		var cot := (m * sk.get_bone_global_pose(sk.find_bone("mixamorig_%sForeArm" % lado))).origin - q
		txt += "  %s mão x %+.2f z %+.2f, cotovelo x %+.2f z %+.2f" % ["E" if lado == "Left" else "D", mao.x, mao.z, cot.x, cot.z]
	print(txt)
