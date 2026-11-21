extends SceneTree
# Captura do inventário aberto no parque (mochila com itens, Miguel visto, um item escolhido).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_inventario.gd -- pasta
func _initialize() -> void:
	var pasta := OS.get_cmdline_user_args()[0]
	Missao1.reiniciar()
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png("%s/fundo.png" % pasta)
	var ip: InventoryPanel = room.inv_panel
	ip.toggle()
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png("%s/inv_vazio.png" % pasta)
	ip.sel = {"kind": "bag", "i": 1}
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/inv_sel.png" % pasta)
	print("ok")
	quit()
