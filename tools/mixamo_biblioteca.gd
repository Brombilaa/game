extends SceneTree
# Junta as animações do Mixamo (FBX sem pele, na pasta assets/3d/animacoes/fonte_mx/, fora do Git) numa
# biblioteca só, assets/3d/animacoes/mixamo.res, usada pelos modelos 3D do jogo (Agente3D).
#   godot --headless --path . -s tools/mixamo_biblioteca.gd
# Os nomes são os mesmos das folhas (AnimSheet.NAMES). O deslocamento horizontal do quadril é zerado
# (o jogo é quem move o personagem); a altura do quadril fica.
const FONTE := "res://assets/3d/animacoes/fonte_mx/mx_%s.fbx"
const SAIDA := "res://assets/3d/animacoes/mixamo.res"
const LACO := ["idle", "walk", "run", "crouch_walk", "crouch_idle", "pistol_idle", "pistol_walk"]
const NOMES := ["idle", "walk", "run", "crouch_walk", "crouch_idle", "pistol_idle", "pistol_walk", "pickup_object",
	"pistol_shoot", "rifle_fire", "punch", "kick", "hit", "death", "getup"]


func _initialize() -> void:
	var lib := AnimationLibrary.new()
	for nome in NOMES:
		var cena: Node = (load(FONTE % nome) as PackedScene).instantiate()
		var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation("mixamo_com").duplicate(true)
		cena.free()
		a.loop_mode = Animation.LOOP_LINEAR if nome in LACO else Animation.LOOP_NONE
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with(":mixamorig_Hips"):
				var p0: Vector3 = a.track_get_key_value(t, 0)
				for k in a.track_get_key_count(t):
					var p: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(p0.x, p.y, p0.z))
		lib.add_animation(nome, a)
		print("ok   - ", nome, " ", snappedf(a.length, 0.01), " s")
	var err := ResourceSaver.save(lib, SAIDA, ResourceSaver.FLAG_COMPRESS)
	print("salvo " if err == OK else "ERRO ", SAIDA)
	quit()
