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
	"nikolai3d": {"modelo": "res://assets/3d/personagens/nikolai.glb", "boina": true},
	"fernando3d": {"modelo": "res://assets/3d/personagens/fernando.fbx"},
	"caio3d": {"modelo": "res://assets/3d/personagens/caio.fbx", "biblioteca": "res://assets/3d/animacoes/caio.res", "giro": PI},  # exportado em metros e de costas
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


static func tem_modelo(pasta: String) -> bool:
	return MODELOS.has(pasta)


func _init(pasta: String) -> void:
	var info: Dictionary = MODELOS[pasta]
	modelo = (load(info["modelo"]) as PackedScene).instantiate()
	add_child(modelo)
	for a in modelo.find_children("*", "AnimationPlayer", true, false):
		a.free()
	var esqueleto: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
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
