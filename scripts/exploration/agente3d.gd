class_name Agente3D
extends Node3D
# Personagem 3D de verdade dentro do parque (Léo, 08/11/2026: os cartões com as folhas ficavam com menos
# resolução que o cenário). Modelo com esqueleto do Mixamo + a biblioteca de animações (tools/mixamo_biblioteca.gd),
# com o mesmo sombreamento facetado do parque3d. O jogo continua mandando a animação e o quadro como fazia com
# as folhas (AnimSheet): aqui o quadro vira a fase da animação, então o tempo de cada golpe segue igual.

const BIBLIOTECA := "res://assets/3d/animacoes/mixamo.res"
const SHADER := "res://assets/3d/shaders/personagem_facetado.gdshader"
const P3D := preload("res://scripts/exploration/parque3d.gd")
const ALTURA := 2.2  # unidades 3D (herói de 128 px)
# Modelo de cada folha (pasta do AnimSheet/IdleSheet, "criatura" para a CreatureSheet). Opcionais: boina (correção de
# tom da boina do Nikolai), biblioteca (animações próprias), textura (quando o FBX não traz embutida), altura e giro
# (modelo exportado olhando para trás).
const MODELOS := {
	"nikolai3d": {"modelo": "res://assets/3d/personagens/nikolai.glb", "boina": true, "armas": true},
	"fernando3d": {"modelo": "res://assets/3d/personagens/fernando.fbx", "armas": true},
	# Caio: o Léo vai remodelar (08/11, "ficou péssimo"); até lá ele volta a ser o cartão da folha de parado.
	# "caio3d": {"modelo": "res://assets/3d/personagens/caio.fbx", "biblioteca": "res://assets/3d/animacoes/caio.res", "giro": PI},  # exportado em metros e de costas
	# Léo, 08/11: Criatura e Caio no mesmo nível do Nikolai e do Fernando. Textura A (aprovada em 05/11); 2,0 m contra 1,8 m dos agentes.
	"criatura": {"modelo": "res://assets/3d/personagens/criatura.fbx", "biblioteca": "res://assets/3d/animacoes/criatura.res",
		"textura": "res://assets/3d/personagens/criatura_textura.png", "altura": 2.45},
}
# Animações das folhas que ainda não existem no Mixamo: usam a mais próxima.
const TROCA := {"rifle_walk": "pistol_walk", "pickup": "pickup_object", "opening": "pickup_object", "pistol_aim_prov": "pistol_idle", "reload": "pistol_idle"}

static var _libs := {}  # caminho -> AnimationLibrary, carregada uma vez
var modelo: Node3D
var player: AnimationPlayer
var atual := ""
var esqueleto: Skeleton3D
var pistola: Node3D  # arma na mão direita (só os agentes; aparece nas animações de pistola)
var espingarda: Node3D  # escopeta/fuzil (animações de rifle)
var _mao := -1
var _ultimo_giro := -1


static func tem_modelo(pasta: String) -> bool:
	return MODELOS.has(pasta)


func _init(pasta: String) -> void:
	var info: Dictionary = MODELOS[pasta]
	modelo = (load(info["modelo"]) as PackedScene).instantiate()
	add_child(modelo)
	for a in modelo.find_children("*", "AnimationPlayer", true, false):
		a.free()
	esqueleto = modelo.find_children("*", "Skeleton3D", true, false)[0]
	_mao = esqueleto.find_bone("mixamorig_RightHand")
	var caminho: String = info.get("biblioteca", BIBLIOTECA)
	if not _libs.has(caminho):
		_libs[caminho] = load(caminho)
	player = AnimationPlayer.new()
	esqueleto.get_parent().add_child(player)
	player.root_node = player.get_path_to(esqueleto.get_parent())
	player.add_animation_library("", _libs[caminho])
	# Altura e pés no chão pela caixa da malha em repouso.
	var caixa := AABB()
	var primeiro := true
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := modelo.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
		caixa = b if primeiro else caixa.merge(b)
		primeiro = false
	var k: float = info.get("altura", ALTURA) / maxf(caixa.size.y, 0.000001)
	modelo.scale = Vector3.ONE * k
	modelo.position.y = -caixa.position.y * k
	modelo.rotation.y = info.get("giro", 0.0)
	_facetar(info.get("boina", false), load(info["textura"]) if info.has("textura") else null)
	if info.get("armas", false):
		_armar(caixa.size.y / 1.8)


# Mesmo material do Nikolai do parque3d (shader facetado, tons medidos contra o JS); sem boina, os tons da boina ficam neutros.
func _facetar(boina: bool, textura: Texture2D) -> void:
	var sh := load(SHADER) as Shader
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var novo := ShaderMaterial.new()
			novo.shader = sh
			if mat is StandardMaterial3D:
				var st := mat as StandardMaterial3D
				var tex: Texture2D = textura if textura else st.albedo_texture
				novo.set_shader_parameter("textura", tex)
				novo.set_shader_parameter("usa_textura", tex != null)
				novo.set_shader_parameter("cor", (Color.WHITE if textura else st.albedo_color) * P3D.TOM_PERSONAGEM)
			novo.set_shader_parameter("tom_sol", P3D.SOL_PERSONAGEM)
			novo.set_shader_parameter("contraste", P3D.CONTRASTE_PERSONAGEM)
			novo.set_shader_parameter("luz_fria", P3D.LUZ_FRIA_PERSONAGEM)
			var cx := mi.mesh.get_aabb()
			novo.set_shader_parameter("altura_min", cx.position.y)
			novo.set_shader_parameter("altura_max", cx.end.y)
			if boina:
				novo.set_shader_parameter("tom_sol_boina", P3D.SOL_BOINA)
				novo.set_shader_parameter("tom_boina", P3D.TOM_BOINA)
				novo.set_shader_parameter("contraste_boina", P3D.CONTRASTE_BOINA)
			else:
				novo.set_shader_parameter("boina_inicio", 2.0)  # nunca
			mi.set_surface_override_material(s, novo)


# Põe o corpo na animação `anim`, na fase `fase` (0 a 1) do ciclo.
func pose(anim: String, fase: float) -> void:
	if pistola:  # sem arma na mão, a animação de tiro parecia um gesto qualquer (Léo, 08/11: "animações estranhas")
		pistola.visible = anim.begins_with("pistol")
		espingarda.visible = anim.begins_with("rifle")
	anim = TROCA.get(anim, anim)
	if not player.has_animation(anim):
		anim = "idle"
	if not player.has_animation(anim):
		return
	if anim != atual:
		player.play(anim)
		player.speed_scale = 0.0
		atual = anim
	var dur := player.get_animation(anim).length
	player.seek(clampf(fase, 0.0, 0.999) * dur, true)


# Gira suavemente para `yaw` (o jogo só tem 8 direções; no 3D a troca seca de direção parecia um salto).
func virar(yaw: float) -> void:
	var agora := Time.get_ticks_msec()
	if _ultimo_giro < 0:
		rotation.y = yaw
	else:
		var dt := (agora - _ultimo_giro) / 1000.0
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-14.0 * dt))
	_ultimo_giro = agora


# Ponta do cano da arma em uso (ou a mão, sem arma): de onde sai o clarão do tiro.
func boca_arma() -> Vector3:
	if pistola and pistola.visible:
		return pistola.global_transform * Vector3(0.01, 0.085, 0.25)
	if espingarda and espingarda.visible:
		return espingarda.global_transform * Vector3(0.01, 0.09, 0.87)
	return mao_direita()


# Posição da mão direita no mundo.
func mao_direita() -> Vector3:
	if _mao < 0:
		return global_position + Vector3(0, ALTURA * 0.6, 0)
	return (esqueleto.global_transform * esqueleto.get_bone_global_pose(_mao)).origin


# Direção do cano (frente do personagem) e do topo da arma no espaço da mão direita, medidas no quadro do disparo
# das animações do Mixamo (iguais no Nikolai e no Fernando, que têm o mesmo esqueleto).
const CANO_PISTOLA := Vector3(-0.5455, 0.8153, 0.1942)
const TOPO_PISTOLA := Vector3(0.6112, 0.5456, -0.5734)
const CANO_RIFLE := Vector3(-0.0890, 0.9953, 0.0384)
const TOPO_RIFLE := Vector3(0.6924, 0.0895, -0.7159)


# Armas simples (caixas escuras) presas à mão: `metro` é quanto vale 1 m nas unidades do modelo.
func _armar(metro: float) -> void:
	var mao := BoneAttachment3D.new()
	mao.bone_name = "mixamorig_RightHand"
	esqueleto.add_child(mao)
	var aco := StandardMaterial3D.new()
	aco.albedo_color = Color(0.16, 0.16, 0.17)  # um pouco mais claro que a roupa escura, para a arma aparecer
	aco.roughness = 0.45
	aco.metallic = 0.6
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color(0.22, 0.13, 0.07)
	madeira.roughness = 0.8
	# O osso da mão fica no pulso; a palma está ~5 cm à frente e ~3,5 cm acima (medido no Fernando). As mãos dos
	# modelos são grandes, então as armas são ~1,4x o tamanho real para não sumirem dentro dos dedos.
	pistola = _arma(mao, CANO_PISTOLA, TOPO_PISTOLA, metro, [
		[Vector3(0.03, 0.045, 0.26), Vector3(0.01, 0.085, 0.12), aco],  # ferrolho e cano
		[Vector3(0.035, 0.13, 0.05), Vector3(0.01, 0.03, 0.05), aco],  # coronha (na palma)
	])
	espingarda = _arma(mao, CANO_RIFLE, TOPO_RIFLE, metro, [
		[Vector3(0.035, 0.035, 0.85), Vector3(0.01, 0.09, 0.45), aco],  # cano
		[Vector3(0.055, 0.07, 0.32), Vector3(0.01, 0.07, 0.25), madeira],  # telha
		[Vector3(0.055, 0.12, 0.4), Vector3(0.01, 0.03, -0.15), madeira],  # coronha
	])


func _arma(mao: Node3D, cano: Vector3, topo: Vector3, metro: float, pecas: Array) -> Node3D:
	var arma := Node3D.new()
	var z := cano.normalized()
	var x := topo.cross(z).normalized()
	var y := z.cross(x)
	arma.transform = Transform3D(Basis(x, y, z), Vector3.ZERO)
	arma.scale = Vector3.ONE * metro
	for p in pecas:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = p[0]
		m.mesh = b
		m.position = p[1]
		m.material_override = p[2]
		arma.add_child(m)
	arma.visible = false
	mao.add_child(arma)
	return arma


var _clarao := 0.0
# Pisca branco ao levar o golpe (0 a 1).
func clarao(a: float) -> void:
	if is_equal_approx(a, _clarao):
		return
	_clarao = a
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			var mat := mi.get_surface_override_material(s)
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter("clarao", a)
