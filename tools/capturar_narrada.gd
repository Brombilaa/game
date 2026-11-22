extends SceneTree
# Captura da narração da Dama (CenaNarrada) na cripta, por cima do salão, no jogo.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 -s tools/capturar_narrada.gd -- prefixo cena t1,t2,...
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var tempos: Array = []
	for s in str(a[2]).split(","):
		tempos.append(float(s))
	Missao1.reiniciar()
	Missao1.local = "cripta"
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 40:
		await process_frame
	CenaNarrada.tocar(room, str(a[1]))
	var quadro := 0
	for t in tempos:
		while quadro < int(t * 30.0):
			await process_frame
			quadro += 1
		root.get_texture().get_image().save_png("%s_%s.png" % [a[0], str(t)])
		print("ok ", t)
	quit()
