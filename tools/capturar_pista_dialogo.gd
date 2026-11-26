extends SceneTree
# Captura a caixa de pista de um lugar da missão 1, com ou sem a imagem da pista (png fora do projeto também serve).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_pista_dialogo.gd -- saida.png local id_da_pista [imagem.png]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Missao1.reiniciar()
	Missao1.local = a[1]
	Missao1.marcar("delegacia17_chegada")
	Missao1.marcar("biblioteca_julia")
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 10:
		await process_frame
	var c: Dictionary = room.scenario.clues[a[2]]
	room._show_dialog(c.inspecao, c.texto, a[2])
	if a.size() > 4:
		room.dialog_pg = int(a[4])
		room._pagina_dialogo()
	elif a.size() > 3:
		room.dialog_image.texture = ImageTexture.create_from_image(Image.load_from_file(a[3]))
		room.dialog_image.visible = true
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(a[0])
	print("ok ", a[0])
	quit()
