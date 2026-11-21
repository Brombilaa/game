extends SceneTree
# Captura das Opções com o mapa de controles (antes: só as Opções; depois: botão Controles e a página).
# Precisa de janela:
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_controles.gd -- capturas/controles

var out_dir := "capturas/controles"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	await _wait(25)
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("ok - ", name)


func _run() -> void:
	var menu: MainMenu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _wait(10)
	menu.skip_intro()
	menu._open("opts")
	await _save("opcoes")
	if menu.has_method("_layout_controls"):
		menu._open("controls")
		await _save("controles")
		var caderno: ControlesCaderno = menu.panel_body.get_child(0)
		caderno.selected = "2"
		caderno.queue_redraw()
		await _save("controles_ficha")
		caderno.selected = "1"
		caderno.filter = "combate"
		caderno.queue_redraw()
		await _save("controles_combate")
	quit()
