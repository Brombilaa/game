extends SceneTree
# Captura o personagem 3D na câmera do jogo em cenas dirigidas como o jogo as dirige (posição, troca de animação, giro,
# golpe), em cada nível de refinamento (Agente3D.refino), e salva os quadros para montar GIFs de antes e depois.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 480x480 -s tools/capturar_animacoes.gd -- pasta [personagem] [cena] [níveis, ex. 0,2]
# Cena vazia ("") = todas.
# Saída: pasta/<cena>_n<nível>_<quadro>.png (12 quadros por segundo, recortados em torno do personagem).
const VEL := 2.8
const FPS := 60
const SAIDA_FPS := 12

var ag: Agente3D
var cam: Camera3D
var pasta := ""
var cena := ""
var nivel := 0
var quem := "fernando3d"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	pasta = args[0] if args.size() > 0 else "/tmp/claude/work/cap"
	quem = args[1] if args.size() > 1 else "fernando3d"
	var so: String = args[2] if args.size() > 2 else ""
	var niveis := [0, 1, 2, 3]
	if args.size() > 3:
		niveis = Array(args[3].split(",")).map(func(x): return int(x))
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
	# chão com grade para a gente enxergar o pé deslizar
	var chao := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(60, 60)
	chao.mesh = pl
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.32, 0.3)
	chao.material_override = gm
	root.add_child(chao)
	for i in range(-12, 13):
		for eixo in 2:
			var linha := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(0.02, 0.01, 60) if eixo == 0 else Vector3(60, 0.01, 0.02)
			linha.mesh = bx
			linha.position = Vector3(i * 1.0 if eixo == 0 else 0, 0.006, i * 1.0 if eixo == 1 else 0)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(0.5, 0.52, 0.5)
			lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			linha.material_override = lm
			root.add_child(linha)
	ag = Agente3D.new(quem)
	root.add_child(ag)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.4
	var az := PI / 4.0
	var el: float = Agente3D.P3D.ELEV
	cam.set_meta("dir", Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * 20.0)
	for c in CENAS:
		if so != "" and so != c:
			continue
		for n in niveis:
			cena = c
			nivel = n
			await _rodar(c, n)
	quit()


# Cada cena é uma lista de trechos: [segundos, animação, yaw alvo (graus), velocidade u/s, extra]
# extra: "" | "combate" | "golpe:<anim>" | "dano" | "reload" | "morte"
const CENAS := ["partir_parar", "giro", "agachar_correr", "tiro", "dano", "recarga", "morte"]


func _trechos(c: String) -> Array:
	match c:
		"partir_parar":
			return [[0.6, "idle", 45, 0, ""], [1.9, "walk", 45, VEL, ""], [1.4, "idle", 45, 0, ""]]
		"giro":
			return [[0.5, "idle", 0, 0, ""], [0.5, "idle", 150, 0, ""], [0.9, "idle", 150, 0, ""], [0.4, "idle", -60, 0, ""], [0.8, "idle", -60, 0, ""]]
		"agachar_correr":
			return [[1.1, "walk", 45, VEL, ""], [1.0, "crouch_walk", 45, VEL * 0.55, ""], [1.0, "walk", 45, VEL, ""], [0.9, "run", 45, VEL * 1.6, ""], [0.7, "walk", 45, VEL, ""]]
		"tiro":
			return [[0.6, "idle", 45, 0, "combate"], [0.7, "pistol_shoot", 45, 0, "golpe"], [0.5, "idle", 45, 0, "combate"], [0.7, "pistol_shoot", 45, 0, "golpe"], [0.5, "idle", 45, 0, "combate"]]
		"dano":
			return [[0.5, "idle", 45, 0, "combate"], [1.2, "hit", 45, 0, "dano"], [0.5, "idle", 45, 0, "combate"]]
		"recarga":
			return [[0.4, "idle", 45, 0, "combate"], [2.0, "reload", 45, 0, "recarga"], [0.4, "idle", 45, 0, "combate"]]
		"morte":
			return [[0.5, "idle", 45, 0, "combate"], [2.2, "death", 45, 0, "morte"]]
	return []


func _rodar(c: String, n: int) -> void:
	Agente3D.refino = n
	Agente3D.relogio_teste = 100000
	ag.queue_free()
	ag = Agente3D.new(quem)
	root.add_child(ag)
	ag.position = Vector3(0, 0, 0)
	ag._ultimo_giro = -1
	var tr: Array = _trechos(c)
	ag.rotation.y = deg_to_rad(float(tr[0][2]))
	var quadro := 0
	var t := 0.0
	var passo := 1000.0 / FPS
	var por_saida := FPS / SAIDA_FPS
	var i := 0
	var cx := Vector3.ZERO
	for trecho in tr:
		var dur: float = trecho[0]
		var extra: String = trecho[4]
		var comb := extra in ["combate", "golpe", "dano", "recarga", "morte"]
		var te := 0.0
		for k in int(dur * FPS):
			Agente3D.relogio_teste += int(round(passo))
			t = te / dur
			var yaw := deg_to_rad(float(trecho[2]))
			ag.postura_combate = comb
			ag.virar(yaw)
			var frente := Vector3(sin(ag.rotation.y), 0, cos(ag.rotation.y))
			ag.position += frente * float(trecho[3]) / FPS
			var anim: String = trecho[1]
			var fase := 0.0
			var cont := false
			match extra:
				"golpe":
					var g := 0.6 if anim == "pistol_shoot" else 0.12
					fase = clampf(te / dur, 0.0, 0.85)
					cont = true
				"dano":
					if k == 0:
						ag.levar_dano(Vector3(0.5, 0, 1.0))  # vem de trás, à direita: empurra para a frente
					fase = clampf(te / 0.8, 0.0, 0.99)
					cont = true
				"recarga":
					fase = te / dur
				"morte":
					fase = clampf(te / dur, 0.0, 0.99)
					cont = true
			ag.pose(anim, fase, cont)
			te += 1.0 / FPS
			if i % por_saida == 0:
				var foco := ag.position + Vector3(0, 1.0, 0)
				cx = cx.lerp(foco, 1.0) if cena != "partir_parar" and cena != "agachar_correr" else cx.lerp(foco, 1.0)
				cam.look_at_from_position(foco + (cam.get_meta("dir") as Vector3), foco)
				await process_frame
				await process_frame
				var img := root.get_texture().get_image()
				img.save_png("%s/%s_n%d_%03d.png" % [pasta, c, n, quadro])
				quadro += 1
			i += 1
	print(c, " n", n, " ", quadro, " quadros")
