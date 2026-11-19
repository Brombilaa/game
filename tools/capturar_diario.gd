extends SceneTree
# Captura das 3 abas do caderno do Miguel (DIÁRIO, PISTAS, CRIATURAS) no parque, com o grupo tendo passado pelo
# parque e pela delegacia e algumas pistas e descobertas anotadas.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_diario.gd -- pasta
func _initialize() -> void:
	var pasta := OS.get_cmdline_user_args()[0]
	Missao1.reiniciar()
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	var gd: GameData = room.rules.cfg.game_data
	DiarioMiguel.esteve("parque")
	DiarioMiguel.esteve("delegacia_17h")
	var pistas := [
		["PARQUE · 16h", "arvore_simbolo", "Um símbolo pintado em vermelho no tronco. Parece sangrar."],
		["PARQUE · 16h", "caio", "O Caio não se mexe mais."],
		["PARQUE · 16h", "banco_quebrado", "Garras abriram as tábuas do banco. Há sangue seco na madeira."],
		["PARQUE · 16h", "marcas_pneu", "Marcas largas de pneu. Vão da terra central até a entrada."],
		["DELEGACIA · 17h", "livro_ocorrencias", "Três semanas de reclamações de barulho na Fazenda Ghular."],
		["DELEGACIA · 17h", "cela_arranhoes", "O símbolo do parque arranhado na parede da cela."],
	]
	for p in pistas:
		Diario.anotar(p[0], p[1], p[2], "")
		Fraquezas.ao_examinar(gd, p[1])
	for k in ["cultista", "criatura_sangue"]:
		Fraquezas.ver(k)
	var dp: DiarioPanel = room.diario_panel
	dp.abrir()
	for aba in ["diario", "pistas", "criaturas"]:
		dp.trocar_secao(aba)
		if aba == "diario":
			for n in 2:
				dp.sel_pagina = n
				dp.atualizar()
				for i in 12:
					await process_frame
				root.get_texture().get_image().save_png("%s/diario_%d.png" % [pasta, n])
			continue
		for i in 12:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [pasta, aba])
		if aba == "criaturas":
			dp.sel_criatura = 1
			dp.atualizar()
			for i in 12:
				await process_frame
			root.get_texture().get_image().save_png("%s/criaturas_1.png" % pasta)
	print("ok")
	quit()
