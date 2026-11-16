class_name DiarioPanel
extends CanvasLayer
# Diário de pistas, modelo A "caderno de campo" (Léo, 15/11/2026): abre com a tecla J (ou fecha com J, Esc e o X).
# Lista à esquerda com tudo o que o grupo examinou (da mais nova para a mais antiga), a pista escolhida à direita com
# imagem e texto, e o próximo objetivo no pé. Com o diário aberto o tempo para, como no inventário (GDD #23).
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

var _lista: VBoxContainer
var _titulo_det: Label
var _lugar_det: Label
var _imagem: TextureRect
var _texto: Label
var _obj: Label
var _contagem: Label
var _vazio: Label
var _raiz: Control


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
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
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
	_obj = _rotulo("", 13, OBJ_TEXT)
	caixa.add_child(_obj)
	return caixa


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
	sel = 0  # a última descoberta
	visible = true
	atualizar()


func fechar() -> void:
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
	_imagem.visible = tem and str(itens[sel]["imagem"]) != ""
	if tem:
		var e: Dictionary = itens[sel]
		_titulo_det.text = e["titulo"]
		_lugar_det.text = str(e["lugar"]).to_upper()
		_texto.text = e["texto"]
		_imagem.texture = load(e["imagem"]) if _imagem.visible and ResourceLoader.exists(e["imagem"]) else null
	var obj := Diario.objetivo_atual(room._objectives()) if room != null else ""
	_obj.text = "PRÓXIMO OBJETIVO   " + obj if obj != "" else "Sem objetivo no momento."


func _botao(i: int, e: Dictionary) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [e["titulo"], str(e["lugar"]).to_upper()]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", TEXT if i == sel else MUTED)
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
	sel = i
	atualizar()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_J:
		alternar()
		get_viewport().set_input_as_handled()
	elif open:
		if event.keycode == KEY_ESCAPE:
			fechar()
		elif event.keycode == KEY_UP:
			_escolher(maxi(sel - 1, 0))
		elif event.keycode == KEY_DOWN:
			_escolher(mini(sel + 1, Missao1.diario.size() - 1))
		get_viewport().set_input_as_handled()  # com o diário aberto o mundo não recebe nada
