extends SceneTree
# Junta as animações do Mixamo (FBX sem pele, na pasta assets/3d/animacoes/fonte_mx/, fora do Git) numa
# biblioteca só, assets/3d/animacoes/mixamo.res, usada pelos modelos 3D do jogo (Agente3D).
#   godot --headless --path . -s tools/mixamo_biblioteca.gd
# A Criatura de Sangue tem animações próprias (fonte_criatura/cr_<nome>.fbx, With Skin do Mixamo) e vira
# assets/3d/animacoes/criatura.res com os nomes da CreatureSheet:
#   godot --headless --path . -s tools/mixamo_biblioteca.gd -- criatura
# O Caio foi exportado em metros (os outros em centésimos): as mesmas animações, com as posições na escala dele:
#   godot --headless --path . -s tools/mixamo_biblioteca.gd -- caio
# Os nomes são os mesmos das folhas (AnimSheet.NAMES). O deslocamento horizontal do quadril é zerado
# (o jogo é quem move o personagem); a altura do quadril fica.
const FONTE := "res://assets/3d/animacoes/fonte_mx/mx_%s.fbx"
const SAIDA := "res://assets/3d/animacoes/mixamo.res"
const LACO := ["idle", "walk", "run", "crouch_walk", "crouch_idle", "pistol_idle", "pistol_walk"]
const NOMES := ["idle", "walk", "run", "crouch_walk", "crouch_idle", "pistol_idle", "pistol_walk", "pickup_object",
	"pistol_shoot", "rifle_fire", "punch", "kick", "hit", "death", "getup"]


const FONTE_CRIATURA := "res://assets/3d/animacoes/fonte_criatura/cr_%s.fbx"
const SAIDA_CRIATURA := "res://assets/3d/animacoes/criatura.res"
const NOMES_CRIATURA := ["idle", "transition", "walk", "attack", "death"]
const LACO_CRIATURA := ["idle", "walk"]
const SAIDA_CAIO := "res://assets/3d/animacoes/caio.res"
const MODELO_CAIO := "res://assets/3d/personagens/caio.fbx"


# Altura do quadril em repouso do modelo dividida pela da animação (primeira chave).
func _escala(modelo: String, a: Animation) -> float:
	var cena: Node = (load(modelo) as PackedScene).instantiate()
	var sk: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var y := sk.get_bone_rest(sk.find_bone("mixamorig_Hips")).origin.y
	cena.free()
	var t := a.find_track(NodePath("Skeleton3D:mixamorig_Hips"), Animation.TYPE_POSITION_3D)
	return y / (a.track_get_key_value(t, 0) as Vector3).y


func _initialize() -> void:
	var criatura := "criatura" in OS.get_cmdline_user_args()
	var caio := "caio" in OS.get_cmdline_user_args()
	var fonte := FONTE_CRIATURA if criatura else FONTE
	var saida := SAIDA_CRIATURA if criatura else (SAIDA_CAIO if caio else SAIDA)
	var escala := 1.0  # posições (quadril) na unidade do esqueleto do modelo
	var laco: Array = LACO_CRIATURA if criatura else LACO
	var lib := AnimationLibrary.new()
	for nome in (NOMES_CRIATURA if criatura else NOMES):
		var cena: Node = (load(fonte % nome) as PackedScene).instantiate()
		var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation("mixamo_com").duplicate(true)
		cena.free()
		a.loop_mode = Animation.LOOP_LINEAR if nome in laco else Animation.LOOP_NONE
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with(":mixamorig_Hips"):
				var p0: Vector3 = a.track_get_key_value(t, 0)
				for k in a.track_get_key_count(t):
					var p: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(p0.x, p.y, p0.z))
		if caio:
			if escala == 1.0:
				escala = _escala(MODELO_CAIO, a)
			for t in a.get_track_count():
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * escala)
		lib.add_animation(nome, a)
		print("ok   - ", nome, " ", snappedf(a.length, 0.01), " s")
	var err := ResourceSaver.save(lib, saida, ResourceSaver.FLAG_COMPRESS)
	print("salvo " if err == OK else "ERRO ", saida, " escala ", escala)
	quit()
