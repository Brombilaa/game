extends SceneTree
# Captura dos 3 modelos da seção CRIATURAS do diário (caderno do Miguel), com a Criatura de Sangue meio descoberta.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_criaturas.gd -- pasta [criatura]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var pasta := a[0]
	var alvo := a[1] if a.size() > 1 else "criatura_sangue"
	Missao1.reiniciar()
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	var gd: GameData = room.rules.cfg.game_data
	for k in ["cultista", "criatura_sangue", "atirador"]:
		Fraquezas.ver(k)
	Fraquezas.ao_examinar(gd, "banco_quebrado")  # Criatura: resiste a bala (a fraqueza a ritual fica ???)
	Fraquezas.ao_examinar(gd, "cela_arranhoes")
	var dp: DiarioPanel = room.diario_panel
	dp.abrir()
	dp.trocar_secao("criaturas")
	var cs := Fraquezas.criaturas(gd)
	for i in cs.size():
		if cs[i]["kind"] == alvo:
			dp.sel_criatura = i
	for m in ["A", "B", "C"]:
		dp.modelo_criaturas = m
		dp.atualizar()
		for i in 12:
			await process_frame
		root.get_texture().get_image().save_png("%s/criaturas_%s_%s.png" % [pasta, m, alvo])
	dp.trocar_secao("pistas")
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png("%s/criaturas_antes.png" % pasta)
	print("ok")
	quit()
