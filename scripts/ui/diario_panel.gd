class_name DiarioPanel
extends CanvasLayer
# Diário de pistas, modelo A "caderno de campo" (Léo, 15/11/2026): abre com a tecla J (ou fecha com J, Esc e o X).
# Lista à esquerda com tudo o que o grupo examinou (da mais nova para a mais antiga), a pista escolhida à direita com
# imagem e texto, e o próximo objetivo no pé. No pé também fica o botão LIGAR (tecla L, modelo A do Léo, 16/11): a
# pista aberta vira a primeira, ele escolhe a segunda na lista e, se as duas se completam, nasce uma conclusão (Ligacoes). Com o diário aberto o tempo para, como no inventário (GDD #23).
# Só desenha e lê o mouse e o teclado; os dados vêm de Diario/Missao1 e o objetivo, de `room._objectives()`.

const PW := 640.0
const PH := 400.0
const GOLD := Color(0.839, 0.678, 0.361)
const BRONZE := Color(0.353, 0.255, 0.149)
const PLATE := Color(0.05, 0.037, 0.03, 0.97)
const TEXT := Color(0.91, 0.87, 0.79)
const MUTED := Color(0.66, 0.6, 0.49)
const CRIMSON := Color(0.62, 0.09, 0.11)
const OBJ_BG := Color(0.17, 0.07, 0.08)
const OBJ_TEXT := Color(0.95, 0.79, 0.81)
const SEL_BG := Color(0.17, 0.115, 0.1)

var room: Node
var open := false
var sel := 0  # posição na lista de recentes
var ligando := false  # modo ligar: a pista de `_a` espera a segunda
var _a := ""  # id da primeira pista do modo ligar
var _aviso := ""  # resultado da última tentativa de ligar, mostrado no pé até o próximo refresh
var secao := "pistas"  # "pistas" ou "criaturas" (caderno do Miguel; Tab ou clique na aba troca)
var modelo_criaturas := "A"  # visual da página da criatura: A, B ou C (DiarioCriaturas), até o Léo escolher
var sel_criatura := 0

var _lista: VBoxContainer
var _titulo_det: Label
var _lugar_det: Label
var _imagem: TextureRect
var _texto: Label
var _obj: Label
var _ligar: Button
var _contagem: Label
var _vazio: Label
var _raiz: Control
var _det: MarginContainer  # página da pista (seção PISTAS)
var _pagina: ScrollContainer  # página da criatura (seção CRIATURAS)
var _aba_pistas: Button
var _aba_criaturas: Button


func _init() -> void:
	layer = 21
	visible = false
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(dim)
	var painel := PanelContainer.new()
	painel.position = Vector2(960 - PW, 540 - PH) / 2.0
	painel.size = Vector2(PW, PH)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = PLATE
	estilo.set_border_width_all(2)
	estilo.border_color = BRONZE
	estilo.set_content_margin_all(0)
	painel.add_theme_stylebox_override("panel", estilo)
	_raiz.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 0)
	painel.add_child(coluna)
	coluna.add_child(_cabecalho())
	coluna.add_child(_corpo())
	coluna.add_child(_rodape())


func _cabecalho() -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 30)
	var t := _rotulo("  DIÁRIO", 16, GOLD)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	_aba_pistas = _aba("PISTAS", "pistas")
	h.add_child(_aba_pistas)
	_aba_criaturas = _aba("CRIATURAS", "criaturas")
	h.add_child(_aba_criaturas)
	var vao := Control.new()
	vao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vao)
	_contagem = _rotulo("", 12, MUTED)
	_contagem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_contagem)
	var x := Button.new()
	x.text = "X"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_color_override("font_color", GOLD)
	x.pressed.connect(fechar)
	h.add_child(x)
	return h


func _corpo() -> Control:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 0)
	linha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	linha.custom_minimum_size = Vector2(0, 300)
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(PW * 0.38, 0)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 0)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista)
	linha.add_child(rolagem)
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_constant_override("separation", 6)
	var margem := MarginContainer.new()
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 12)
	margem.add_child(det)
	linha.add_child(margem)
	_det = margem
	_pagina = ScrollContainer.new()
	_pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pagina.visible = false
	linha.add_child(_pagina)
	_titulo_det = _rotulo("", 18, GOLD)
	det.add_child(_titulo_det)
	_lugar_det = _rotulo("", 11, MUTED)
	det.add_child(_lugar_det)
	_imagem = TextureRect.new()
	_imagem.custom_minimum_size = Vector2(150, 150)
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_imagem.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	det.add_child(_imagem)
	_texto = _rotulo("", 14, TEXT)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(_texto)
	_vazio = _rotulo("Nenhuma pista examinada ainda.\nExamine objetos no cenário e o que você descobrir fica aqui.", 13, MUTED)
	_vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(_vazio)
	return linha


func _rodape() -> Control:
	var caixa := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = OBJ_BG
	e.set_border_width_all(1)
	e.border_color = CRIMSON
	e.set_content_margin_all(8)
	caixa.add_theme_stylebox_override("panel", e)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	caixa.add_child(linha)
	_obj = _rotulo("", 13, OBJ_TEXT)
	_obj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linha.add_child(_obj)
	_ligar = Button.new()
	_ligar.focus_mode = Control.FOCUS_NONE
	_ligar.add_theme_font_size_override("font_size", 12)
	_ligar.add_theme_color_override("font_color", Color(1, 1, 1))
	var e2 := StyleBoxFlat.new()
	e2.bg_color = CRIMSON
	e2.set_content_margin_all(4)
	for n in ["normal", "hover", "pressed"]:
		_ligar.add_theme_stylebox_override(n, e2)
	_ligar.pressed.connect(alternar_ligar)
	linha.add_child(_ligar)
	return caixa


func _aba(texto: String, id: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(trocar_secao.bind(id))
	return b


func _estilo_aba(b: Button, ativa: bool) -> void:
	var e := StyleBoxFlat.new()
	e.bg_color = SEL_BG if ativa else Color(0, 0, 0, 0)
	e.border_width_bottom = 2 if ativa else 0
	e.border_color = CRIMSON
	e.content_margin_left = 8
	e.content_margin_right = 8
	for n in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(n, e)
	b.add_theme_color_override("font_color", GOLD if ativa else MUTED)
	b.add_theme_color_override("font_hover_color", GOLD)


# Troca entre PISTAS e CRIATURAS (sai do modo ligar).
func trocar_secao(id: String) -> void:
	secao = id
	ligando = false
	_aviso = ""
	atualizar()


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func abrir() -> void:
	if open:
		return
	open = true
	ligando = false
	_aviso = ""
	sel = 0  # a última descoberta
	visible = true
	atualizar()


func fechar() -> void:
	ligando = false
	open = false
	visible = false


func alternar() -> void:
	if open:
		fechar()
	elif room == null or room.diario_pode_abrir():
		abrir()


# Refaz a lista, a pista escolhida e o objetivo a partir do diário e do estado da sala.
func atualizar() -> void:
	for f in _lista.get_children():
		_lista.remove_child(f)
		f.queue_free()
	_estilo_aba(_aba_pistas, secao == "pistas")
	_estilo_aba(_aba_criaturas, secao == "criaturas")
	_det.visible = secao == "pistas"
	_pagina.visible = secao == "criaturas"
	if secao == "criaturas":
		_atualizar_criaturas()
		return
	var itens := Diario.recentes()
	sel = clampi(sel, 0, maxi(itens.size() - 1, 0))
	_contagem.text = "%d %s  " % [itens.size(), "pista" if itens.size() == 1 else "pistas"]
	_vazio.visible = itens.is_empty()
	for i in itens.size():
		_lista.add_child(_botao(i, itens[i]))
	var tem := not itens.is_empty()
	_titulo_det.visible = tem
	_lugar_det.visible = tem
	_texto.visible = tem
	_imagem.visible = tem and not ligando and str(itens[sel]["imagem"]) != ""
	if tem and ligando:
		_titulo_det.text = "Ligar duas pistas"
		_lugar_det.text = "ESCOLHA A SEGUNDA NA LISTA"
		_texto.text = "1) %s\n2) %s" % [_titulo_de(_a), str(itens[sel]["titulo"]) if str(itens[sel]["id"]) != _a else "…"]
		_imagem.texture = null
	elif tem:
		var e: Dictionary = itens[sel]
		_titulo_det.text = e["titulo"]
		_lugar_det.text = str(e["lugar"]).to_upper()
		_texto.text = e["texto"]
		_imagem.texture = load(e["imagem"]) if _imagem.visible and ResourceLoader.exists(e["imagem"]) else null
	var obj := Diario.objetivo_atual(room._objectives()) if room != null else ""
	_obj.text = "PRÓXIMO OBJETIVO   " + obj if obj != "" else "Sem objetivo no momento."
	if ligando:
		_obj.text = "Clique na segunda pista (ou Enter). Esc cancela."
	if _aviso != "":
		_obj.text = _aviso
	_ligar.visible = Missao1.diario.size() >= 2
	_ligar.text = "CANCELAR (L)" if ligando else "LIGAR (L)"


func _botao(i: int, e: Dictionary) -> Button:
	var b := Button.new()
	b.text = "%s%s\n%s" % ["① " if ligando and e["id"] == _a else "", e["titulo"], str(e["lugar"]).to_upper()]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", TEXT if i == sel or (ligando and e["id"] == _a) else MUTED)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = SEL_BG if i == sel else Color(0, 0, 0, 0)
	estilo.border_width_left = 3 if i == sel else 0
	estilo.border_color = CRIMSON
	estilo.set_content_margin_all(7)
	for n in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(n, estilo)
	b.pressed.connect(_escolher.bind(i))
	return b


func _escolher(i: int) -> void:
	if ligando:
		_confirmar(i)
		return
	sel = i
	atualizar()


# Teclas de cima e de baixo: só movem o cursor (no modo ligar não ligam nada até o Enter).
func _cursor(i: int) -> void:
	sel = clampi(i, 0, maxi(Missao1.diario.size() - 1, 0))
	_aviso = ""
	atualizar()


# Liga L: abre o modo ligar com a pista aberta como primeira, ou cancela.
func alternar_ligar() -> void:
	if not open:
		return
	_aviso = ""
	if ligando:
		ligando = false
	elif Missao1.diario.size() >= 2:
		var itens := Diario.recentes()
		_a = str(itens[sel]["id"])
		ligando = true
		sel = sel + 1 if sel + 1 < itens.size() else sel - 1  # o cursor sai da primeira pista
	atualizar()


func _confirmar(i: int) -> void:
	var itens := Diario.recentes()
	i = clampi(i, 0, itens.size() - 1)
	var b := str(itens[i]["id"])
	if b == _a:
		_aviso = "Escolha uma pista diferente da primeira."
		atualizar()
		return
	var r := Ligacoes.tentar(_a, b)
	match r["resultado"]:
		Ligacoes.Resultado.NOVA:
			ligando = false
			sel = 0  # a conclusão é a entrada mais nova
			_aviso = "Conclusão nova: " + str(r["entrada"]["titulo"])
		Ligacoes.Resultado.JA_FEITA:
			ligando = false
			sel = _posicao(str(r["entrada"]["id"]))
			_aviso = "Você já ligou essas duas pistas."
		_:
			_aviso = "Essas pistas não parecem se ligar."
	atualizar()


func _posicao(id: String) -> int:
	var itens := Diario.recentes()
	for k in itens.size():
		if itens[k]["id"] == id:
			return k
	return 0


func _titulo_de(id: String) -> String:
	for e in Missao1.diario:
		if e["id"] == id:
			return str(e["titulo"])
	return id


# Seção CRIATURAS: lista das criaturas encontradas e a página do caderno do Miguel (modelo A, B ou C).
func _atualizar_criaturas() -> void:
	var cs := Fraquezas.criaturas(room.rules.cfg.game_data if room != null and "rules" in room else null)
	sel_criatura = clampi(sel_criatura, 0, maxi(cs.size() - 1, 0))
	_contagem.text = "%d %s  " % [cs.size(), "criatura" if cs.size() == 1 else "criaturas"]
	for f in _pagina.get_children():
		_pagina.remove_child(f)
		f.queue_free()
	for i in cs.size():
		var sabe := 0
		for a in cs[i]["afinidades"]:
			sabe += 1 if a["conhecida"] else 0
		_lista.add_child(_botao_criatura(i, cs[i]["nome"], "anotado: %d de %d" % [sabe, cs[i]["afinidades"].size()]))
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lado in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lado, 10)
	_pagina.add_child(m)
	if cs.is_empty():
		var v := _rotulo("Miguel ainda não anotou nenhuma criatura.\nEnfrente ou investigue o que está em Aurora.", 13, MUTED)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.add_child(v)
	else:
		var p := DiarioCriaturas.pagina(modelo_criaturas, cs[sel_criatura])
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.add_child(p)
	_obj.text = "Caderno do Miguel: o que o grupo sabe de cada criatura. Tab volta às pistas."
	_ligar.visible = false


func _botao_criatura(i: int, nome: String, sub: String) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [nome, sub.to_upper()]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", TEXT if i == sel_criatura else MUTED)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = SEL_BG if i == sel_criatura else Color(0, 0, 0, 0)
	estilo.border_width_left = 3 if i == sel_criatura else 0
	estilo.border_color = CRIMSON
	estilo.set_content_margin_all(7)
	for n in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(n, estilo)
	b.pressed.connect(func() -> void:
		sel_criatura = i
		atualizar())
	return b


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_J:
		alternar()
		get_viewport().set_input_as_handled()
	elif open:
		if event.keycode == KEY_ESCAPE:
			if ligando:
				alternar_ligar()
			else:
				fechar()
		elif event.keycode == KEY_TAB:
			trocar_secao("criaturas" if secao == "pistas" else "pistas")
		elif secao == "criaturas" and (event.keycode == KEY_UP or event.keycode == KEY_DOWN):
			sel_criatura += -1 if event.keycode == KEY_UP else 1
			atualizar()
		elif secao == "criaturas":
			pass
		elif event.keycode == KEY_L:
			alternar_ligar()
		elif event.keycode == KEY_UP:
			_cursor(sel - 1)
		elif event.keycode == KEY_DOWN:
			_cursor(sel + 1)
		elif ligando and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
			_confirmar(sel)
		get_viewport().set_input_as_handled()  # com o diário aberto o mundo não recebe nada
