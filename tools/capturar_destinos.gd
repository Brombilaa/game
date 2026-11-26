extends SceneTree
# Captura do menu de destino que abre na saída da delegacia (e dos lugares livres), como aparece no jogo.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_destinos.gd -- saida.png [visitado ...]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Missao1.reiniciar()
	Missao1.local = "delegacia_17h"
	Missao1.marcar("delegacia17_chegada")
	for i in range(1, a.size()):
		Missao1.marcar("visitou_" + a[i])
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 30:
		await process_frame
	room._abrir_menu_destinos(Missao1.destinos_livres(), "")
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(a[0])
	print("ok ", a[0])
	quit()
