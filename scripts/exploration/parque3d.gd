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
# Tons medidos contra a referência: folhas um pouco mais vivas; casaco com leve ajuste frio (o sol vem por trás
# dos personagens, então o tom depende quase só do céu/chão).
const TOM_FOLHAGEM := 1.1
# Multiplicador de cor por material do cenário (nome mN do glb), medido contra a referência JS (tools/calibrar_tons.py gera o arquivo).
const TONS_MATERIAIS := preload("res://assets/3d/parque/tons_materiais.gd")
# Personagem (shader facetado), medido contra a referência: multiplicador linear, contraste da textura em volta da cor
# do casaco e uma luz fria somada (o casaco na sombra sai cinza neutro no JS, não marrom).
const TOM_PERSONAGEM := Color(1.72, 1.95, 1.45)
const CONTRASTE_PERSONAGEM := Vector3(0.85, 0.72, 0.8)
const LUZ_FRIA_PERSONAGEM := Vector3(0.006, 0.024, 0.026)
const TOM_BOINA := Vector3(0.60, 0.52, 0.56)  # boina mais escura e menos vermelha, medida contra o JS (junto com o pivô media_boina)
const CONTRASTE_BOINA := Vector3(0.2, 0.2, 0.25)  # as manchas escuras do tecido quase somem no JS
const GRUPO := [Vector2(450, 690), Vector2(510, 660), Vector2(570, 625)]

# Luz ajustada à mão para casar com o render de referência do three.js (estilo PC antigo).
@export var luz_sol := 0.22
@export var luz_poste := 14.0
@export var queda_poste := 2.2
@export var forca_oclusao := 1.5
@export var raio_oclusao := 0.6
@export var luz_ceu := 0.07  # HemisphereLight do JS: diferença céu/chão (de cima positiva, de baixo negativa)
@export var luz_ambiente := 0.10  # média do céu e do chão; com luz_ceu, o chão plano recebe ~0,17 como antes
@export var um_andando := false  # liga o Nikolai do meio com esqueleto e a animação de andar
var camera: Camera3D
var mundo: SubViewport  # o 3D é desenhado a ~1000 px de altura com MSAA 4x e ampliado, como o protótipo
var agentes: Array[Node3D] = []


func _ready() -> void:
	_mundo()
	_ambiente()
	_cenario()
	_camera()
	_oclusao()
	_neblina()
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
	env.ambient_light_color = Color(0.72, 0.71, 0.76)  # média do céu e do chão do HemisphereLight
	env.ambient_light_energy = luz_ambiente
	env.fog_enabled = false  # a névoa é a do JS, feita em _neblina() (a curva do Godot é outra)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	# DirectionalLight(0xffdcb8) em (4, 6, 4.5) apontando para (10, 0, 7.5), sombra PCF suave de 2048.
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	# HemisphereLight = média constante + parte que cresce com a normal para cima.
	var ceu_luz := DirectionalLight3D.new()
	ceu_luz.light_color = Color(0.89, 0.87, 1.0)
	ceu_luz.light_energy = luz_ceu
	ceu_luz.shadow_enabled = false
	ceu_luz.light_specular = 0.0
	mundo.add_child(ceu_luz)
	ceu_luz.rotation_degrees = Vector3(-90, 0, 0)
	# Metade de baixo: a mesma luz vinda de baixo com energia negativa. Céu + chão + ambiente reproduzem o
	# HemisphereLight do JS (ambiente = média, e cada face clareia ou escurece conforme aponta para cima ou para baixo).
	var chao_luz := DirectionalLight3D.new()
	chao_luz.light_color = ceu_luz.light_color
	chao_luz.light_energy = -luz_ceu
	chao_luz.shadow_enabled = false
	chao_luz.light_specular = 0.0
	mundo.add_child(chao_luz)
	chao_luz.rotation_degrees = Vector3(90, 0, 0)
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
	# Postes: PointLight(0xffd694, 14, 14, decay 1,6) do protótipo. Energia, queda e um tom mais alaranjado
	# medidos contra a poça de luz da referência (a queda do Godot com 1,6 espalhava a luz demais).
	for l in cena.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		o.light_energy = luz_poste
		o.light_color = Color("ffd694") * Color(1.1, 0.86, 0.82)
		o.omni_range = 14.0
		o.omni_attenuation = queda_poste
	# Materiais: sem brilho especular (o protótipo usa Lambert) e, nas texturas grandes (chão, grama), mipmap linear com anisotropia.
	var copias := {}
	var tons: Dictionary = TONS_MATERIAIS.TONS
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				if not copias.has(mat):
					var novo := mat.duplicate() as BaseMaterial3D
					novo.metallic_specular = 0.0
					novo.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
					# Folhas (alphaTest do protótipo = recorte no Godot): tom da folhagem. As texturas com alfa misturado
					# são decalques (símbolo, marcas, terra, borda do chão) e ficam como estão.
					if novo.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
						novo.albedo_color = novo.albedo_color * Color(TOM_FOLHAGEM, TOM_FOLHAGEM, TOM_FOLHAGEM, 1.0)
					if tons.has(mat.resource_name):  # tom medido contra a referência JS, por material
						var t: Array = tons[mat.resource_name]
						novo.albedo_color = novo.albedo_color * Color(t[0], t[1], t[2], 1.0)
					if mat.albedo_texture and mat.albedo_texture.get_width() >= 512:
						novo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					copias[mat] = novo
				mi.set_surface_override_material(i, copias[mat])


# Oclusão de ambiente por shader (SSAO): um quadrado na frente da câmera multiplica a cena pela oclusão.
func _oclusao() -> void:
	if forca_oclusao <= 0.0:
		return
	var q := MeshInstance3D.new()
	var malha := QuadMesh.new()
	malha.size = Vector2(2, 2)
	q.mesh = malha
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/3d/oclusao.gdshader")
	m.set_shader_parameter("forca", forca_oclusao)
	m.set_shader_parameter("raio", raio_oclusao)
	q.material_override = m
	camera.add_child(q)
	q.position = Vector3(0, 0, -1)


# Névoa do JS (Fog 0x8c8f86, 41 a 81, smoothstep na profundidade): quadrado na frente da câmera, depois da oclusão.
func _neblina() -> void:
	var q := MeshInstance3D.new()
	var malha := QuadMesh.new()
	malha.size = Vector2(2, 2)
	q.mesh = malha
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/3d/neblina.gdshader")
	m.render_priority = 10
	q.material_override = m
	camera.add_child(q)
	q.position = Vector3(0, 0, -1)


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
	_facetar(corpo)
	_sombra_contato(corpo.position)
	return corpo


# Troca o material da malha estática pelo shader facetado (a luz do sol passa a modelar o corpo, como no JS).
func _facetar(corpo: Node3D) -> void:
	var sh := load("res://assets/3d/personagem_facetado.gdshader") as Shader
	for m in corpo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var novo := ShaderMaterial.new()
			novo.shader = sh
			if mat is StandardMaterial3D:
				var st := mat as StandardMaterial3D
				novo.set_shader_parameter("textura", st.albedo_texture)
				novo.set_shader_parameter("usa_textura", st.albedo_texture != null)
				novo.set_shader_parameter("cor", st.albedo_color * TOM_PERSONAGEM)
				novo.set_shader_parameter("contraste", CONTRASTE_PERSONAGEM)
				novo.set_shader_parameter("luz_fria", LUZ_FRIA_PERSONAGEM)
				var cx := mi.mesh.get_aabb()
				novo.set_shader_parameter("altura_min", cx.position.y)
				novo.set_shader_parameter("altura_max", cx.end.y)
				novo.set_shader_parameter("tom_boina", TOM_BOINA)
				novo.set_shader_parameter("contraste_boina", CONTRASTE_BOINA)
			mi.set_surface_override_material(s, novo)


# Sombra de contato: mancha suave sob os pés (o Compatibility não tem sombra de contato nem decal).
func _sombra_contato(pos: Vector3) -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, (y - 31.5) * 1.6).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.55))
	var plano := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(1.1, 1.1)
	plano.mesh = malha
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.disable_receive_shadows = true
	plano.material_override = m
	plano.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(plano)
	plano.position = Vector3(pos.x, 0.02, pos.z)
	plano.rotation.y = PI / 4.0


func _luz_personagem(corpo: Node3D) -> void:
	for m in corpo.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).get_active_material(0)
		if mat is StandardMaterial3D:
			var novo := mat.duplicate() as StandardMaterial3D
			novo.albedo_color = Color(0.6, 0.6, 0.6)
			novo.metallic_specular = 0.0
			(m as MeshInstance3D).set_surface_override_material(0, novo)


func _agente(px: Vector2, i: int) -> Node3D:
	if i != 1 or not um_andando:
		return _agente_estatico(px)
	var corpo: Node3D = (load(NIKOLAI) as PackedScene).instantiate()
	corpo.position = Vector3(px.x / 64.0, 0.0, px.y / 64.0)
	corpo.rotation.y = PI / 4.0
	corpo.scale = Vector3.ONE * ESCALA_FBX
	mundo.add_child(corpo)
	_luz_personagem(corpo)
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
