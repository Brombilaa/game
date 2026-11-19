extends SceneTree
# Captura do pós-combate da missão 1 no celeiro: a conversa com a Ordem (data/cenas/celeiro_ordem.json) e o fim do
# capítulo (cartão AURORA). Cada fala nova da caixa vira uma captura; a fala avança sozinha depois de ~1,5 s.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 -s tools/capturar_celeiro.gd -- prefixo [max]
#   prefixo "antes": o mesmo lugar (fazenda) sem a Ordem, como era antes desta cena.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var prefixo := a[0]
	var maximo := int(a[1]) if a.size() > 1 else 20
	Missao1.reiniciar()
	for m in ["cripta_vencida", "fernando_morreu", "leticia_acordou"]:
		Missao1.marcar(m)
	Missao1.local = "celeiro"
	Missao1.chegada = "poco"
	if prefixo.ends_with("antes"):
		Missao1.local = "fazenda"
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	if prefixo.ends_with("antes"):
		for i in 10:
			await process_frame
		var pts := [Vector2(768, 825.6), Vector2(806.4, 857.6), Vector2(844.8, 825.6)]
		for i in 3:
			room.party[i].pos = pts[i]
		room.enemies.clear()
		room.camera.position = room._iso(room.party[1].pos) + Vector2(0, -70)
		room.camera.zoom = Vector2(1.35, 1.35)
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png("%s_0.png" % prefixo)
		quit()
		return
	var n := 0
	var ultimo := ""
	var desde := 0
	var quadro := 0
	while n < maximo and quadro < 30 * 120:
		await process_frame
		quadro += 1
		desde += 1
		if quadro == 45:
			root.get_texture().get_image().save_png("%s_%02d.png" % [prefixo, n])
			n += 1
		var caixa: CaixaFala = room.caixa
		if caixa.visible and caixa._texto.text != ultimo:
			ultimo = caixa._texto.text
			desde = 0
		if caixa.visible and desde == 80:
			root.get_texture().get_image().save_png("%s_%02d.png" % [prefixo, n])
			print("fala ", n, " ", ultimo)
			n += 1
			caixa._avanca()
		if room.fim_capitulo != null and room.fim_capitulo.cartao != null and room.fim_capitulo.cartao._t > 2.5:
			root.get_texture().get_image().save_png("%s_%02d.png" % [prefixo, n])
			print("cartão")
			break
	quit()
