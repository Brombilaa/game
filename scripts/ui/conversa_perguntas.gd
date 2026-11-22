class_name ConversaPerguntas
extends CanvasLayer
# Lista de perguntas de uma conversa (bar, Léo 20/11/2026): painel à direita com as perguntas em qualquer ordem, as já
# feitas em cinza escuro e, no fim, a saída ("Já perguntei o bastante"). Clique, setas + Enter ou os números escolhem.
# Emite `escolheu(id)` com o id da pergunta, ou "" quando o jogador encerra a conversa.

signal escolheu(id: String)

const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const OURO := Color(0.82, 0.68, 0.4)
const TEXTO := Color(0.94, 0.9, 0.83)
const FEITA := Color(0.34, 0.31, 0.29)  # cinza escuro: pergunta já feita (Léo, 22/11)
const TELA := Vector2(960, 540)
const PAINEL := Rect2(496, 78, 440, 308)

var conversa_id := ""
var dados := {}
var botoes: Array[Button] = []  # um por pergunta, mais o da saída no fim
var ids: Array[String] = []  # id de cada botão ("" = sair)
var _cabecalho: Label


func abrir(conversa_id_: String, dados_: Dictionary) -> void:
	conversa_id = conversa_id_
	dados = dados_
	layer = 97
	var fundo := Control.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)
	var placa := ColorRect.new()
	placa.color = Color(0.03, 0.022, 0.02, 0.92)
	placa.position = PAINEL.position
	placa.size = PAINEL.size
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(placa)
	var borda := ColorRect.new()
	borda.color = Color(OURO, 0.7)
	borda.position = PAINEL.position
	borda.size = Vector2(PAINEL.size.x, 1)
	borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(borda)
	_cabecalho = _rotulo(15, OURO)
	_cabecalho.text = str(dados.get("titulo", "PERGUNTAS")).to_upper()
	_cabecalho.position = PAINEL.position + Vector2(14, 8)
	fundo.add_child(_cabecalho)
	var lista := VBoxContainer.new()
	lista.position = PAINEL.position + Vector2(10, 34)
	lista.size = Vector2(PAINEL.size.x - 20, PAINEL.size.y - 40)
	lista.add_theme_constant_override("separation", 1)
	fundo.add_child(lista)
	var n := 1
	for p in dados.get("perguntas", []):
		var b := _botao("%d. %s" % [n, str(p["texto"])])
		lista.add_child(b)
		botoes.append(b)
		ids.append(str(p["id"]))
		var pid := str(p["id"])
		b.pressed.connect(func() -> void: escolher(pid))
		n += 1
	var sair := _botao("»  " + str(dados.get("sair", "Já perguntei o bastante.")))
	sair.add_theme_color_override("font_color", OURO)
	lista.add_child(sair)
	botoes.append(sair)
	ids.append("")
	sair.pressed.connect(func() -> void: escolher(""))
	atualizar()
	if not botoes.is_empty() and not CaixaFala.pular:
		botoes[0].grab_focus.call_deferred()


# Escolhe uma pergunta (ou "" para sair). Pergunta já feita pode ser repetida: a resposta toca de novo, sem nova entrada no diário.
func escolher(id: String) -> void:
	escolheu.emit(id)


# Repinta as perguntas já feitas (depois de cada resposta).
func atualizar() -> void:
	for i in range(ids.size()):
		if ids[i] == "":
			continue
		var ja := Conversa.feita(conversa_id, ids[i])
		var b: Button = botoes[i]
		b.add_theme_color_override("font_color", FEITA if ja else TEXTO)
		var perg := Conversa.pergunta(dados, ids[i])
		b.text = "%d. %s" % [i + 1, str(perg["texto"])]


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < ids.size() - 1:
		escolher(ids[k - KEY_1])
		get_viewport().set_input_as_handled()
	elif k == KEY_ESCAPE:
		escolher("")
		get_viewport().set_input_as_handled()


func _botao(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", OURO)
	b.add_theme_color_override("font_focus_color", OURO)
	b.add_theme_color_override("font_pressed_color", OURO)
	b.custom_minimum_size = Vector2(0, 28)
	var foco := StyleBoxFlat.new()
	foco.bg_color = Color(OURO, 0.14)
	foco.border_width_left = 2
	foco.border_color = OURO
	b.add_theme_stylebox_override("focus", foco)
	b.add_theme_stylebox_override("hover", foco)
	b.add_theme_stylebox_override("pressed", foco)
	return b


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
