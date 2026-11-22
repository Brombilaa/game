extends SceneTree
# Captura a aba PISTAS do caderno com as fichas dos desaparecidos e a página do livro de ocorrências anotadas.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_diario_fichas.gd -- saida.png [pista]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	Missao1.reiniciar()
	Missao1.local = "delegacia_17h"
	Missao1.marcar("delegacia17_chegada")
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 10:
		await process_frame
	DiarioMiguel.esteve("delegacia_17h")
	for cid in ["livro_ocorrencias", "ficha_desaparecidos"]:
		var c: Dictionary = room.scenario.clues[cid]
		room.dialog_clue = cid
		room.seen_clues.erase(cid)
		room._close_dialog()
	var dp: DiarioPanel = room.diario_panel
	dp.abrir()
	dp.trocar_secao("pistas")
	if a.size() > 1:
		var itens: Array = dp._itens()
		for i in itens.size():
			if str(itens[i]["id"]) == a[1]:
				dp.sel = i
		dp.atualizar()
	for i in 14:
		await process_frame
	root.get_texture().get_image().save_png(a[0])
	print("ok ", a[0])
	quit()
