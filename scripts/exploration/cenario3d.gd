extends Node3D
# Cenário 3D genérico da missão 1 (delegacia, subsolo, biblioteca, Fazenda Ghular), no mesmo estilo PC antigo
# do parque (parque3d.gd). O cenário nasce nos protótipos three.js (tools/cenarios3d/missao1) e chega em dois
# arquivos: `assets/3d/missao1/<id>.glb` (malhas) e `<id>.json` (hora, luzes, brilhos, caixas que só fazem
# sombra, névoa). Partes que mudam durante o jogo vêm em glbs separados (`<id>_<estado>.glb`) e são ligadas
# e desligadas com `estado()`.
# Coordenadas: 1 unidade 3D = 64 px do plano do cenário (x = px/64, z = py/64), como no parque.

const PASTA := "res://assets/3d/missao1/"
const ELEV := 0.38719  # atan(17.3 / 42.4), a câmera do parque
const DIST := 47.0
# Conversão das luzes do three.js (r160) para o Godot Compatibility. O three.js divide o difuso por pi e o Godot
# não, então tudo vale perto de 1/pi (0,34 medido). Conferido renderizando cada tipo de luz sozinho nos dois lados, sem filtro
# (tools/cenarios3d/missao1). Atenção: o SubViewport do Compatibility entrega a imagem já em sRGB, não linear;
# o filtro pc_antigo recebe `entrada_srgb` para desfazer isso antes de aplicar a receita do protótipo.
const K_SOL := 0.34
const K_AMBIENTE := 0.34
const K_CEU := 0.34
const K_PONTO := 0.34

@export var id := "delegacia_17h"
@export var embutido := false  # dentro do jogo: o filtro PC antigo cobre só o 3D, não o HUD
@export var alvo := Vector3(7.2, 1.2, 8.0)  # só para a vista solta (capturas)
@export var vista := 15.5  # altura da vista em unidades 3D, como `vista` das tomadas do protótipo
@export var k_sol := 1.0  # ajustes finos por cena, multiplicam as conversões acima
@export var k_ambiente := 1.0
@export var k_ceu := 1.0
@export var k_ponto := 1.0
@export var albedo_ref := 0.1  # cor média do chão usada na correção do sol (ver _ambiente)
@export var queda_ponto := 0.0  # 0 = usa a queda de cada luz do protótipo (a fórmula do Godot é a mesma do three.js)
@export var k_brilho := 1.0
@export var k_emissao := 1.0
@export var forca_oclusao := 0.0  # os protótipos destes cenários não têm oclusão; a sombra de canto vem pintada no piso
@export var raio_oclusao := 0.6
@export var nevoa_forca := 1.0
@export var nevoa_baixa := 0.0
@export var deslocamento := Vector3.ZERO  # no jogo: leva o canto da área do cenário à origem do plano da sala
@export var expoente_sobreposto := 0.7  # alfa^x das camadas claras sem luz (névoa rasteira, teias); 1 = mistura do Compatibility

const POCA_ACIMA := 0.012
var info := {}
var camada_mundo: CanvasLayer
var camera: Camera3D
var mundo: SubViewport
var raiz: Node3D  # malhas, luzes e caixas de sombra do cenário (deslocadas por `deslocamento`)
var neblina: ShaderMaterial
var estados := {}  # nome -> Array de nós (malhas, luzes, brilhos, sombras)
var _brilho_tex: Texture2D


func _ready() -> void:
	info = JSON.parse_string(FileAccess.get_file_as_string(PASTA + id + ".json"))
	_mundo()
	raiz = Node3D.new()
	raiz.name = "cenario"
	raiz.position = deslocamento
	mundo.add_child(raiz)
	_ambiente()
	_cenario()
	_luzes()
	_camera()
	_oclusao()
	_neblina()
	_efeito_pc_antigo()


# Liga ou desliga uma parte do cenário (ex.: "tapete", "alcapao").
func estado(nome: String, ligado: bool) -> void:
	for n in estados.get(nome, []):
		(n as Node3D).visible = ligado


func tem_estado(nome: String) -> bool:
	return estados.has(nome)


func _registrar(nome: String, n: Node3D) -> void:
	if nome == "":
		return
	if not estados.has(nome):
		estados[nome] = []
	estados[nome].append(n)


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
	camada_mundo = CanvasLayer.new()
	camada_mundo.layer = -1
	camada_mundo.add_child(tr)
	add_child(camada_mundo)
	_ajustar_resolucao()
	get_viewport().size_changed.connect(_ajustar_resolucao)


func _ajustar_resolucao() -> void:
	var real := DisplayServer.window_get_size()
	var kk := minf(1.0, 1000.0 / float(real.y))
	mundo.size = Vector2i(maxi(2, roundi(real.x * kk)), maxi(2, roundi(real.y * kk)))


static func _srgb(v: float) -> float:
	return v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _linear(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)


static func _cor_linear(v: Vector3) -> Color:
	return Color(maxf(v.x, 0.0), maxf(v.y, 0.0), maxf(v.z, 0.0)).linear_to_srgb()


func _ambiente() -> void:
	var hemi: Dictionary = info["hemi"]
	var ceu := _linear(Color(str(hemi["ceu"])))
	var chao := _linear(Color(str(hemi["chao"])))
	var forca := float(hemi["i"])
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(str(info["fundo"]))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# HemisphereLight do JS = média do céu e do chão (ambiente) + metade da diferença vinda de cima e, negativa, de baixo.
	var media := (ceu + chao) * 0.5
	var maior := maxf(maxf(media.x, media.y), maxf(media.z, 0.0001))
	env.ambient_light_color = _cor_linear(media / maior)
	env.ambient_light_energy = maior * forca * K_AMBIENTE * k_ambiente
	env.fog_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	mundo.add_child(we)
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	var dif := (ceu - chao) * 0.5
	var md := maxf(maxf(dif.x, dif.y), maxf(dif.z, 0.0001))
	for sinal in [1.0, -1.0]:
		var l := DirectionalLight3D.new()
		l.light_color = _cor_linear(dif / md)
		l.light_energy = sinal * md * forca * K_CEU * k_ceu
		l.shadow_enabled = false
		l.light_specular = 0.0
		mundo.add_child(l)
		l.rotation_degrees = Vector3(-90.0 * sinal, 0, 0)
	var s: Dictionary = info["sol"]
	var d: Array = s["dir"]
	var dir := Vector3(d[0], d[1], d[2]).normalized()
	# O sol tem sombra, e no Compatibility a luz com sombra é somada num passe à parte, com a imagem já em sRGB: a
	# soma sai clara demais. Corrige-se o sol para que, num chão de cor média (ALBEDO_REF), céu + sol dê o valor certo:
	# sol' = linear(srgb(a·(céu + sol)) - srgb(a·céu)) / a, canal a canal.
	var chao_ceu := ceu * forca * K_CEU * k_ceu
	var chao_sol := _linear(Color(str(s["cor"]))) * float(s["i"]) * K_SOL * k_sol * maxf(dir.y, 0.05)
	var corrigido := Vector3.ZERO
	for i in 3:
		var soma := _srgb(albedo_ref * (chao_ceu[i] + chao_sol[i])) - _srgb(albedo_ref * chao_ceu[i])
		corrigido[i] = _lin(maxf(soma, 0.0)) / albedo_ref / maxf(dir.y, 0.05)
	var ms := maxf(maxf(corrigido.x, corrigido.y), maxf(corrigido.z, 0.000001))
	var sol := DirectionalLight3D.new()
	sol.light_color = _cor_linear(corrigido / ms)
	sol.light_energy = ms
	sol.shadow_enabled = true
	sol.shadow_blur = 2.0
	sol.shadow_bias = 0.03
	sol.shadow_normal_bias = 1.0
	sol.light_specular = 0.0
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sol.directional_shadow_max_distance = 75.0
	mundo.add_child(sol)
	sol.position = dir * 10.0
	sol.look_at(Vector3.ZERO, Vector3.UP)


func _cenario() -> void:
	_malhas(PASTA + id + ".glb", "")
	var base := id + "_"
	for arq in DirAccess.get_files_at(PASTA):
		var nome := arq.trim_suffix(".import").trim_suffix(".remap")
		if nome.begins_with(base) and nome.ends_with(".glb"):
			var est := nome.trim_prefix(base).trim_suffix(".glb")
			if not estados.has(est) or estados[est].is_empty() or not (estados[est][0] is Node3D and (estados[est][0] as Node3D).name == "glb_" + est):
				_malhas(PASTA + nome, est)
	for sdic in info.get("sombras", []):  # caixas invisíveis que só fazem sombra (paredes cortadas, telhado)
		var t: Array = sdic["tam"]
		var p: Array = sdic["pos"]
		var r: Array = sdic["rot"]
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(t[0], t[1], t[2])
		mi.mesh = b
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		raiz.add_child(mi)
		mi.quaternion = Quaternion(r[0], r[1], r[2], r[3])
		mi.position = Vector3(p[0], p[1], p[2])
		_registrar(str(sdic.get("estado", "")), mi)


# Materiais: sem brilho especular (o protótipo usa Lambert); as marcas no nome (k12__add_unlit...) dizem o resto.
func _malhas(caminho: String, est: String) -> void:
	var cena: Node3D = (load(caminho) as PackedScene).instantiate()
	cena.name = "glb_" + (est if est != "" else "base")
	raiz.add_child(cena)
	_registrar(est, cena)
	var copias := {}
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var faz_sombra := false
		var soma := false
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if not (mat is BaseMaterial3D):
				continue
			var marcas := _marcas(mat.resource_name)
			if marcas.has("add"):
				soma = true
			if not marcas.has("semsombra"):
				faz_sombra = true
			if not copias.has(mat):
				copias[mat] = _material(mat as BaseMaterial3D, marcas)
			mi.set_surface_override_material(i, copias[mat])
		if not faz_sombra:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Poças de luz pintadas no chão (Léo, 13/11: "iluminação estranha ao andar"): no protótipo ficam a 3 cm, na
		# mesma altura do piso, e no Godot a disputa de profundidade com o piso acendia e apagava cada poça conforme
		# a câmera andava. Plano deitado que soma luz sobe POCA_ACIMA.
		if soma and (mi.global_transform * mi.get_aabb()).size.y < 0.001:
			mi.global_position.y += POCA_ACIMA


static func _marcas(nome: String) -> PackedStringArray:
	var p := nome.find("__")
	return PackedStringArray() if p < 0 else nome.substr(p + 2).split("_")


func _material(mat: BaseMaterial3D, marcas: PackedStringArray) -> Material:
	if marcas.has("unlit") and not marcas.has("add") and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		var s := ShaderMaterial.new()
		s.shader = load("res://assets/3d/shaders/sobreposto.gdshader")
		s.set_shader_parameter("cor", mat.albedo_color)
		s.set_shader_parameter("tem_textura", mat.albedo_texture != null)
		s.set_shader_parameter("textura", mat.albedo_texture)
		s.set_shader_parameter("expoente", expoente_sobreposto)
		s.render_priority = 11
		return s
	var novo := mat.duplicate() as BaseMaterial3D
	novo.metallic_specular = 0.0
	novo.metallic = 0.0
	novo.roughness = 1.0
	novo.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	if marcas.has("unlit"):
		novo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if marcas.has("add"):
		novo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		novo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		novo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		novo.albedo_color.a = minf(novo.albedo_color.a * 1.3 * k_brilho, 1.0)  # a mistura do Compatibility é em sRGB e sai mais fraca
	if marcas.has("semnevoa"):
		novo.disable_fog = true
	if marcas.has("dentro"):
		novo.cull_mode = BaseMaterial3D.CULL_FRONT
	if novo.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:  # o importador usa pré-passe; no protótipo os decalques não escrevem profundidade
		novo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if novo.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		novo.disable_receive_shadows = true
		novo.render_priority = 11  # depois do quadro da névoa, que só enxerga o que é opaco
	elif marcas.has("semnevoa"):  # opaco que a névoa não cobre (janela acesa, céu): desenhado depois dela
		novo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		novo.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		novo.render_priority = 11
	if novo.emission_enabled:
		novo.emission_energy_multiplier *= k_emissao
	if mat.albedo_texture and mat.albedo_texture.get_width() >= 512 and novo.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
		novo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return novo


func _luzes() -> void:
	for l in info.get("luzes", []):
		var o := OmniLight3D.new()
		o.light_color = Color(str(l["cor"]))
		o.light_energy = float(l["i"]) * K_PONTO * k_ponto
		o.omni_range = float(l["d"]) if float(l["d"]) > 0.0 else 30.0
		o.omni_attenuation = queda_ponto if queda_ponto > 0.0 else float(l.get("q", 1.6))
		o.shadow_enabled = false
		o.light_specular = 0.0
		var p: Array = l["pos"]
		raiz.add_child(o)
		o.position = Vector3(p[0], p[1], p[2])
		_registrar(str(l.get("estado", "")), o)
	for b in info.get("brilhos", []):
		var q := MeshInstance3D.new()
		var malha := QuadMesh.new()
		var s := float(b["s"])
		malha.size = Vector2(s, s)
		q.mesh = malha
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = _textura_brilho()
		var c := Color(str(b["cor"]))
		c.a = minf(float(b["o"]) * 2.2 * k_brilho, 4.0)  # idem: halo mais fraco na mistura em sRGB
		m.albedo_color = Color(c.r * maxf(c.a, 1.0), c.g * maxf(c.a, 1.0), c.b * maxf(c.a, 1.0), minf(c.a, 1.0))
		m.disable_fog = true
		m.no_depth_test = false
		m.render_priority = 12
		q.material_override = m
		var p: Array = b["pos"]
		raiz.add_child(q)
		q.position = Vector3(p[0], p[1], p[2])
		_registrar(str(b.get("estado", "")), q)


# Mesmo degradê do `glowT` do kit (centro quase branco, halo amarelo que some).
func _textura_brilho() -> Texture2D:
	if _brilho_tex:
		return _brilho_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var pontos := [[0.0, Color(1, 0.925, 0.667, 1)], [0.1, Color(1, 0.863, 0.51, 0.5)], [0.3, Color(1, 0.816, 0.431, 0.14)], [0.6, Color(1, 0.784, 0.353, 0.04)], [1.0, Color(1, 0.784, 0.353, 0)]]
	for y in 64:
		for x in 64:
			var d := minf(Vector2(x - 31.5, y - 31.5).length() / 32.0, 1.0)
			var c: Color = pontos[4][1]
			for k in 4:
				if d <= pontos[k + 1][0]:
					c = (pontos[k][1] as Color).lerp(pontos[k + 1][1], (d - pontos[k][0]) / (pontos[k + 1][0] - pontos[k][0]))
					break
			img.set_pixel(x, y, c)
	_brilho_tex = ImageTexture.create_from_image(img)
	return _brilho_tex


func _camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = vista
	camera.near = 0.5
	camera.far = 200.0
	mundo.add_child(camera)
	olhar(alvo, vista)
	camera.make_current()


func olhar(ponto: Vector3, altura_vista: float) -> void:
	var az := PI / 4.0
	camera.size = altura_vista
	camera.position = ponto + Vector3(cos(ELEV) * sin(az), sin(ELEV), cos(ELEV) * cos(az)) * DIST
	camera.look_at(ponto, Vector3.UP)
	_ajustar_nevoa()


func _quadro(shader: String, prioridade: int) -> ShaderMaterial:
	var q := MeshInstance3D.new()
	var malha := QuadMesh.new()
	malha.size = Vector2(2, 2)
	q.mesh = malha
	q.extra_cull_margin = 16384.0
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = prioridade
	q.material_override = m
	camera.add_child(q)
	q.position = Vector3(0, 0, -1)
	return m


func _oclusao() -> void:
	if forca_oclusao <= 0.0:
		return
	var m := _quadro("res://assets/3d/shaders/oclusao.gdshader", 0)
	m.set_shader_parameter("forca", forca_oclusao)
	m.set_shader_parameter("raio", raio_oclusao)


# Névoa do kit: Fog(cor da hora, D0 - 6·k·nk, D0 + 34·k·fk), com k = max(1, vista / 9,2).
func _neblina() -> void:
	neblina = _quadro("res://assets/3d/shaders/neblina_exata.gdshader", 10)
	var c := _linear(Color(str(info["nevoa"]["cor"])))
	neblina.set_shader_parameter("cor", c)
	neblina.set_shader_parameter("cor_baixa", c * 1.6 + Vector3(0.01, 0.012, 0.016))
	neblina.set_shader_parameter("forca", nevoa_forca)
	neblina.set_shader_parameter("baixa", nevoa_baixa)
	_ajustar_nevoa()


func _ajustar_nevoa() -> void:
	if neblina == null or camera == null:
		return
	var cfg = info.get("cfg")
	var fk := 1.0
	var nk := 1.0
	if cfg is Dictionary:
		fk = float(cfg.get("fk", 1.0))
		nk = float(cfg.get("nk", 1.0))
	var k := maxf(1.0, camera.size / 9.2)
	neblina.set_shader_parameter("perto", DIST - 6.0 * k * nk)
	neblina.set_shader_parameter("longe", DIST + 34.0 * k * fk)


func _efeito_pc_antigo() -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/3d/shaders/pc_antigo.gdshader")
	# As correções de cor do parque (saturação 1,17 e ganho) foram medidas para aquela cena; aqui a luz já é a do protótipo.
	m.set_shader_parameter("corr_saturacao", 1.0)
	m.set_shader_parameter("entrada_srgb", true)
	m.set_shader_parameter("corr_ganho", Vector3.ONE)
	r.material = m
	if embutido:
		camada_mundo.add_child(r)
		return
	var camada := CanvasLayer.new()
	camada.layer = 100
	camada.add_child(r)
	add_child(camada)


# --- Destaque de pistas (Léo, 13/11): contorno branco e brilho ao redor do objeto -------------------------------

var _destaques := {}  # chave -> {"nos": Array[MeshInstance3D], "contorno": Material, "brilho": Material}


# Malhas visíveis do estado `estado` (ex.: "tapete") cujo retângulo no chão contém o ponto `p` (px / 64, como o mundo).
func malhas_em(p: Vector3, estado: String) -> Array:
	var r: Array = []
	for no in estados.get(estado, []):
		for m in (no as Node3D).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var bb: AABB = mi.global_transform * mi.get_aabb()
			if p.x >= bb.position.x and p.x <= bb.end.x and p.z >= bb.position.z and p.z <= bb.end.z and bb.size.x < 6.0 and bb.size.z < 6.0:
				r.append(mi)
	return r


# `contorno` e `brilho` vão de 0 a 1. Cria as cópias na primeira vez e depois só muda a opacidade.
func destacar(chave: String, malhas: Array, contorno: float, brilho: float) -> void:
	if not _destaques.has(chave):
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.cull_mode = BaseMaterial3D.CULL_FRONT
		var cp := cm.duplicate() as StandardMaterial3D
		cp.cull_mode = BaseMaterial3D.CULL_DISABLED
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.render_priority = 12  # depois do quadro da névoa, como os outros materiais com alfa
		bm.disable_fog = true
		bm.disable_receive_shadows = true
		var nos: Array = []
		for m in malhas:
			var mi := m as MeshInstance3D
			var bb: AABB = mi.global_transform * mi.get_aabb()
			var plano := bb.size.y < 0.05
			var c := bb.get_center()
			var borda := 0.05
			var s := Vector3(1.0 + 2.0 * borda / maxf(bb.size.x, 0.05), 1.0 if plano else 1.0 + 2.0 * borda / maxf(bb.size.y, 0.05), 1.0 + 2.0 * borda / maxf(bb.size.z, 0.05))
			var xf := Transform3D(Basis.from_scale(s), c) * Transform3D(Basis.IDENTITY, -c) * mi.global_transform
			var o := MeshInstance3D.new()
			o.mesh = mi.mesh
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			o.material_override = cp if plano else cm
			raiz.add_child(o)
			o.global_transform = xf
			if plano:
				o.global_position.y -= 0.004
			o.set_meta("tipo", "contorno")
			var g := MeshInstance3D.new()
			g.mesh = mi.mesh
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.material_override = bm
			raiz.add_child(g)
			g.global_transform = mi.global_transform
			g.global_position.y += 0.006 if plano else 0.0
			g.set_meta("tipo", "brilho")
			nos.append(o)
			nos.append(g)
		_destaques[chave] = {"nos": nos, "contorno": [cm, cp], "brilho": bm}
	var d: Dictionary = _destaques[chave]
	for mat in d["contorno"]:
		(mat as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 1.0, contorno)
	(d["brilho"] as StandardMaterial3D).albedo_color = Color(0.95, 0.72, 0.36, brilho * 0.6)
	for n in d["nos"]:
		var t := str(n.get_meta("tipo"))
		(n as Node3D).visible = (t == "contorno" and contorno > 0.01) or (t == "brilho" and brilho > 0.01)
