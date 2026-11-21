extends SceneTree
# Prepara o modelo de um personagem novo (Léo, 21/11: Criatura de Sangue e Cultista F): pega um FBX With Skin do
# Mixamo (fonte, fora do Git) e salva só malha e esqueleto em assets/3d/personagens/<nome>.scn, sem animações nem
# texturas embutidas (a textura vem do PNG de 512 px, estilo PC antigo, pela chave "textura" do Agente3D).
#   godot --headless --path . -s tools/preparar_modelo.gd -- res://.../cr_idle.fbx res://assets/3d/personagens/criatura.scn
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cena: Node = (load(args[0]) as PackedScene).instantiate()
	for a in cena.find_children("*", "AnimationPlayer", true, false):
		a.free()
	var vazio := StandardMaterial3D.new()
	for m in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var im := mi.mesh.duplicate() as Mesh
		for s in im.get_surface_count():
			im.surface_set_material(s, vazio)
		mi.mesh = im
	_dono(cena, cena)
	var emb := PackedScene.new()
	emb.pack(cena)
	var err := ResourceSaver.save(emb, args[1], ResourceSaver.FLAG_COMPRESS)
	print("salvo " if err == OK else "ERRO ", args[1])
	quit()


func _dono(n: Node, raiz: Node) -> void:
	for c in n.get_children():
		c.owner = raiz
		_dono(c, raiz)
