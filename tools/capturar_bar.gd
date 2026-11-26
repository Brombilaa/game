extends SceneTree
# Capturas do bar com render de verdade (o roteiro roda em tempo real; as falas avançam sozinhas).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_bar.gd -- saida.png estado
# estado: bar_chegando | bar_fala | bar_perguntas | bar_resposta | bar_livre

var estado := ""
var respondeu := false
var t0 := -1.0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var saida := a[0]
	estado = a[1]
	Progresso.autosave_ativo = false
	Missao1.reiniciar()
	Missao1.local = "bar"
	if estado == "bar_livre":
		Missao1.marcar("bar_conversou")
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await _ate(func() -> bool: return _passo_do_bar(room))
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("ok ", saida)
	quit(0)


func _ate(cond: Callable) -> void:
	for i in 60 * 150:
		await process_frame
		if cond.call():
			return


func _digitou(cx: CaixaFala, nome: String) -> bool:
	return cx.ocupada and cx._nome.text == nome and cx._texto.visible_characters == -1


func _passo_do_bar(room) -> bool:
	var cx: CaixaFala = room.caixa
	if estado == "bar_livre":
		return true
	if estado == "bar_chegando":
		if t0 < 0.0 and room.cena != null:
			t0 = Time.get_ticks_msec() / 1000.0
		return t0 >= 0.0 and Time.get_ticks_msec() / 1000.0 - t0 >= 2.6
	if estado == "bar_fala":
		return _digitou(cx, "CAIO")
	var painel: ConversaPerguntas = null
	for n in room.get_children():
		if n is ConversaPerguntas:
			painel = n
	if painel != null:
		if estado == "bar_perguntas":
			return true
		if not respondeu:
			respondeu = true
			painel.escolher("ordo")
		elif _digitou(cx, "LETÍCIA"):
			return true
		elif cx.ocupada and cx._texto.visible_characters == -1:
			cx._avancou = true  # a pergunta dita pelo controlado
		return false
	if cx.ocupada and cx._texto.visible_characters == -1:
		cx._avancou = true
	return false
