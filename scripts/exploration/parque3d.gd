extends Node3D
# Parque como cena 3D de verdade (opção 3 do Léo, 06/11/2026): cenário v16 exportado do three.js
# (tools/cenarios3d) e personagem 3D animado, com o estilo PC antigo da direção B.
# Primeira etapa: cena de visualização com Nikolai parado e andando. O jogo (parque.tscn) ainda usa o fundo assado.
# Coordenadas: 1 unidade 3D = 64 px do plano do parque (x = px/64, z = py/64).

const CENARIO := "res://assets/3d/parque/parque_cenario.glb"
const NIKOLAI := "res://assets/3d/personagens/nikolai.glb"
const NIKOLAI_ESTATICO := "res://assets/3d/personagens/nikolai_estatico.glb"
const ANIM_ANDAR := "res://assets/3d/animacoes/nikolai_andar.fbx"
const ANIM_PARADO := "res://assets/3d/animacoes/nikolai_parado.fbx"
# Câmera ortográfica fixa, mesma do fundo assado: elevação atan(17,3/42,4), azimute 45°.
const ELEV := 0.38719  # atan(17.3 / 42.4)
const DIST := 47.0
const PX_POR_UNIDADE := 67.88  # 48 / sqrt(0.5), px do fundo por unidade
const ZOOM := 1.5
const ALVO := Vector3(8.2, 0.0, 10.2)
# O FBX do Mixamo chega em centímetros (0,01); 2,2 unidades de altura = herói de 128 px (memória do projeto).
const ESCALA_FBX := 2.2 / 0.01779
const EMISSAO_PERSONAGEM := 0.0
const GRUPO := [Vector2(450, 690), Vector2(510, 660), Vector2(570, 625)]

# Luz ajustada à mão para casar com o render de referência do three.js (estilo PC antigo).
@export var luz_sol := 0.6
@export var luz_poste := 4.0
@export var luz_ambiente := 0.03
@export var um_andando := false  # liga o Nikolai do meio com esqueleto e a animação de andar
var camera: Camera3D
var mundo: SubViewport  # o 3D é desenhado a ~1000 px de altura com MSAA 4x e ampliado, como o protótipo
var agentes: Array[Node3D] = []


func _ready() -> void:
	_mundo()
	_ambiente()
	_cenario()
	_camera()
	for i in GRUPO.size():
		agentes.append(_agente(GRUPO[i], i))
	_efeito_pc_antigo()


func _mundo() -> void:
	mundo = SubViewport.new()
	mundo.msaa_3d = Viewport.MSAA_4X
	mundo.own_world_3d = true
	mundo.transparent_bg = false
	mundo.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mundo)
	var tr := TextureRect.new()
	tr.texture = mundo.get_texture()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var camada := CanvasLayer.new()
	camada.layer = -1
	camada.add_child(tr)
	add_child(camada)
	_ajustar_resolucao()
	get_viewport().size_changed.connect(_ajustar_resolucao)


# pcSize() do protótipo: altura de renderização min(altura da janela, 1000 px).
func _ajustar_resolucao() -> void:
	var janela := get_viewport().get_visible_rect().size
	var k := minf(1.0, 1000.0 / janela.y)
	var real := DisplayServer.window_get_size()
	var kk := minf(1.0, 1000.0 / float(real.y))
	mundo.size = Vector2i(maxi(2, roundi(real.x * kk)), maxi(2, roundi(real.y * kk)))


func _ambiente() -> void:
	# HemisphereLight(0xe8e4f4, 0x6a6a70) do protótipo: céu claro em cima, chão cinza embaixo.
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = Color("e8e4f4")
	ceu.sky_horizon_color = Color("b9b7bd")
	ceu.ground_horizon_color = Color("b9b7bd")
	ceu.ground_bottom_color = Color("6a6a70")
	ceu.sky_curve = 0.5
	ceu.ground_curve = 0.5
	var sky := Sky.new()
	sky.sky_material = ceu
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8c8f86")
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.74)  # média do HemisphereLight do protótipo, sem o azul
	env.ambient_light_energy = luz_ambiente
	# Fog(0x8c8f86, 41, 81) do protótipo (smoothstep, aproximada por uma curva quadrática de 41 a 68), cor convertida para linear como no three.js.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("8c8f86").srgb_to_linear()
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_depth_begin = 41.0
	env.fog_depth_end = 68.0
	env.fog_depth_curve = 2.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	# DirectionalLight(0xffdcb8) em (4, 6, 4.5) apontando para (10, 0, 7.5), sombra PCF suave de 2048.
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color("ffdcb8")
	sol.light_energy = luz_sol
	sol.shadow_enabled = true
	sol.shadow_blur = 2.0
	sol.shadow_bias = 0.03
	sol.shadow_normal_bias = 1.0
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sol.directional_shadow_max_distance = 75.0
	mundo.add_child(sol)
	sol.position = Vector3(4, 6, 4.5)
	sol.look_at(Vector3(10, 0, 7.5), Vector3.UP)


func _cenario() -> void:
	var cena: Node = (load(CENARIO) as PackedScene).instantiate()
	mundo.add_child(cena)
	# Postes: PointLight(0xffd694, 14, 14, decay 1,6) do protótipo.
	for l in cena.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		o.light_energy = luz_poste
		o.omni_range = 14.0
		o.omni_attenuation = 1.6
	# Materiais: sem brilho especular (o protótipo usa Lambert) e, nas texturas grandes (chão, grama), mipmap linear com anisotropia.
	var copias := {}
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				if not copias.has(mat):
					var novo := mat.duplicate() as BaseMaterial3D
					novo.metallic_specular = 0.0
					if mat.albedo_texture and mat.albedo_texture.get_width() >= 512:
						novo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					copias[mat] = novo
				mi.set_surface_override_material(i, copias[mat])


func _camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 5.54  # 1080 px / 195 px por unidade: mesmo enquadramento do render de referência
	camera.near = 0.5
	camera.far = 200.0
	mundo.add_child(camera)
	var az := PI / 4.0
	camera.position = ALVO + Vector3(cos(ELEV) * sin(az), sin(ELEV), cos(ELEV) * cos(az)) * DIST
	camera.look_at(ALVO, Vector3.UP)
	camera.make_current()


# Mesma malha estática da referência em JS (pose de repouso do protótipo), com a altura de 2,2 unidades.
func _agente_estatico(px: Vector2) -> Node3D:
	var corpo: Node3D = (load(NIKOLAI_ESTATICO) as PackedScene).instantiate()
	mundo.add_child(corpo)
	var caixa := AABB()
	var primeiro := true
	for m in corpo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		caixa = b if primeiro else caixa.merge(b)
		primeiro = false
	var k := 2.2 / caixa.size.y
	corpo.scale = Vector3.ONE * k
	corpo.position = Vector3(px.x / 64.0, -caixa.position.y * k, px.y / 64.0)
	corpo.rotation.y = PI / 4.0
	_luz_personagem(corpo)
	return corpo


func _luz_personagem(corpo: Node3D) -> void:
	for m in corpo.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).get_active_material(0)
		if mat is StandardMaterial3D:
			var novo := mat.duplicate() as StandardMaterial3D
			novo.emission_enabled = true
			novo.emission_texture = novo.albedo_texture
			novo.emission_energy_multiplier = EMISSAO_PERSONAGEM
			(m as MeshInstance3D).set_surface_override_material(0, novo)


func _agente(px: Vector2, i: int) -> Node3D:
	if i != 1 or not um_andando:
		return _agente_estatico(px)
	var corpo: Node3D = (load(NIKOLAI) as PackedScene).instantiate()
	corpo.position = Vector3(px.x / 64.0, 0.0, px.y / 64.0)
	corpo.rotation.y = PI / 4.0
	corpo.scale = Vector3.ONE * ESCALA_FBX
	mundo.add_child(corpo)
	# No three.js o material padrão ainda recebe luz especular e ambiente que o Godot não repete, então o casaco preto
	# saía mais escuro. Um pouco de emissão da própria textura levanta os pretos sem lavar as cores.
	for m in corpo.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).get_active_material(0)
		if mat is StandardMaterial3D:
			var novo := mat.duplicate() as StandardMaterial3D
			novo.emission_enabled = true
			novo.emission_texture = novo.albedo_texture
			novo.emission_energy_multiplier = EMISSAO_PERSONAGEM
			(m as MeshInstance3D).set_surface_override_material(0, novo)
	var raiz: Node = corpo.get_node("ni_skin")  # as trilhas do Mixamo começam em "Skeleton3D:..."
	var respirar: Animation = null  # o próprio modelo traz o Breathing Idle do Mixamo
	for a in corpo.find_children("*", "AnimationPlayer", true, false):
		if a is AnimationPlayer and a.has_animation("mixamo_com"):
			respirar = (a as AnimationPlayer).get_animation("mixamo_com").duplicate()
			respirar.loop_mode = Animation.LOOP_LINEAR
			for t in respirar.get_track_count():  # trilhas vêm como "ni_skin/Skeleton3D:..."; o player já parte de ni_skin
				respirar.track_set_path(t, NodePath(String(respirar.track_get_path(t)).trim_prefix("ni_skin/")))
		a.free()
	var player := AnimationPlayer.new()
	corpo.add_child(player)
	player.root_node = player.get_path_to(raiz)
	var lib := AnimationLibrary.new()
	lib.add_animation("parado", respirar if respirar else _animacao(ANIM_PARADO, true))
	lib.add_animation("andar", _animacao(ANIM_ANDAR, true))
	player.add_animation_library("", lib)
	player.play("andar" if i == 1 else "parado")
	return corpo


# Animação do Mixamo (FBX só com esqueleto): pega a faixa "mixamo_com" e deixa em laço.
func _animacao(caminho: String, laco: bool) -> Animation:
	var cena: Node = (load(caminho) as PackedScene).instantiate()
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	var a: Animation = ap.get_animation("mixamo_com").duplicate()
	a.loop_mode = Animation.LOOP_LINEAR if laco else Animation.LOOP_NONE
	cena.free()
	return a


# Efeito de tela PC antigo (direção B): cor levemente lavada e 16 bits com dithering.
func _efeito_pc_antigo() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 100
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/3d/pc_antigo.gdshader")
	r.material = m
	camada.add_child(r)
	add_child(camada)
