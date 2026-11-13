extends SceneTree
# Captura o personagem 3D de frente (Léo, 13/11: braços do Miguel muito afastados do corpo) e mede a distância
# das mãos ao tronco. xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 900x700 -s tools/capturar_bracos.gd -- pasta prefixo [personagem]
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
	ag.virar(0.0)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 4.2)
	root.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.1, 0))
	cam.fov = 30
	Agente3D.relogio_teste = 0
	for anim in ["idle", "walk", "pistol_idle", "pistol_walk", "crouch_walk", "run"]:
		for f in [0.0, 0.25, 0.5, 0.75]:
			for i in 3:
				ag.pose(anim, f, true)
				Agente3D.relogio_teste += 100
				await process_frame
			var sk := ag.esqueleto
			var m := sk.global_transform
			var q := m * sk.get_bone_global_pose(sk.find_bone("mixamorig_Spine1"))
			var e := m * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftHand"))
			var d := m * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand"))
			var ec := m * sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftForeArm"))
			var dc := m * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightForeArm"))
			print("%s %.2f  z mao E %.2f D %.2f  mao E %.2f D %.2f | cotovelo E %.2f D %.2f (x do tronco %.2f)" % [anim, f, e.origin.z - q.origin.z, d.origin.z - q.origin.z, e.origin.x - q.origin.x, d.origin.x - q.origin.x, ec.origin.x - q.origin.x, dc.origin.x - q.origin.x, q.origin.x])
			root.get_texture().get_image().save_png("%s/%s_%s_%d.png" % [pasta, pre, anim, int(f * 100)])
	quit()
