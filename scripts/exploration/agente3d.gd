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
# Modelo de cada folha (pasta do AnimSheet) e se tem a correção da boina do Nikolai.
const MODELOS := {
	"nikolai3d": ["res://assets/3d/personagens/nikolai.glb", true],
	"fernando3d": ["res://assets/3d/personagens/fernando.fbx", false],
}
# Animações das folhas que ainda não existem no Mixamo: usam a mais próxima.
const TROCA := {"rifle_walk": "pistol_walk", "pickup": "pickup_object", "opening": "pickup_object", "pistol_aim_prov": "pistol_idle", "reload": "pistol_idle"}

static var _lib: AnimationLibrary
var modelo: Node3D
var player: AnimationPlayer
var atual := ""


static func tem_modelo(pasta: String) -> bool:
	return MODELOS.has(pasta)


func _init(pasta: String) -> void:
	var info: Array = MODELOS[pasta]
	modelo = (load(info[0]) as PackedScene).instantiate()
	add_child(modelo)
	for a in modelo.find_children("*", "AnimationPlayer", true, false):
		a.free()
	var esqueleto: Skeleton3D = modelo.find_children("*", "Skeleton3D", true, false)[0]
	if _lib == null:
		_lib = load(BIBLIOTECA)
	player = AnimationPlayer.new()
	esqueleto.get_parent().add_child(player)
	player.root_node = player.get_path_to(esqueleto.get_parent())
	player.add_animation_library("", _lib)
	# Altura e pés no chão pela caixa da malha em repouso.
	var caixa := AABB()
	var primeiro := true
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := modelo.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
		caixa = b if primeiro else caixa.merge(b)
		primeiro = false
	var k := ALTURA / maxf(caixa.size.y, 0.001)
	modelo.scale = Vector3.ONE * k
	modelo.position.y = -caixa.position.y * k
	_facetar(info[1])


# Mesmo material do Nikolai do parque3d (shader facetado, tons medidos contra o JS); sem boina, os tons da boina ficam neutros.
func _facetar(boina: bool) -> void:
	var sh := load(SHADER) as Shader
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var novo := ShaderMaterial.new()
			novo.shader = sh
			if mat is StandardMaterial3D:
				var st := mat as StandardMaterial3D
				novo.set_shader_parameter("textura", st.albedo_texture)
				novo.set_shader_parameter("usa_textura", st.albedo_texture != null)
				novo.set_shader_parameter("cor", st.albedo_color * P3D.TOM_PERSONAGEM)
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
	if anim != atual:
		player.play(anim)
		player.speed_scale = 0.0
		atual = anim
	var dur := player.get_animation(anim).length
	player.seek(clampf(fase, 0.0, 0.999) * dur, true)
