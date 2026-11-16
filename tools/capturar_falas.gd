extends SceneTree
# Captura das falas com retrato no parque (antes: só o texto da pista; depois: a caixa C). Precisa de janela:
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_falas.gd -- capturas/falas

var out_dir := "capturas/falas"


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
	await _wait(8)
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("ok - ", name)


func _run() -> void:
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	await _wait(60)
	await _save("antes")  # sem nenhuma caixa
	room._inspect("balanco")
	await _wait(10)
	await _save("pista_texto")
	room._close_dialog()  # fecha o texto da pista; começam as falas
	for n in [1, 2, 3]:
		while room.caixa._texto.visible_characters != -1 or not room.caixa.visible:  # espera o texto terminar de aparecer
			await process_frame
		await _wait(3)
		await _save("fala_%d" % n)
		room.caixa._avanca()  # próxima fala (a última fecha a caixa)
		await _wait(2)
	await _wait(10)
	await _save("depois")  # tudo fechado, jogo livre
	quit(0)
