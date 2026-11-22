class_name TelaD20
extends CanvasLayer
# Tela do teste de perícia (Léo, 22/11: modelo B "anel da sorte" com o dado em formato de d20 se embaralhando): mostra a
# perícia e a DT, o d20 girando até parar, a conta (dado + bônus = total) em fichas e a faixa SUCESSO ou FALHA.
# Termina com `fechada` quando o jogador clica (ou aperta Enter/Espaço) depois do resultado.

signal fechada

const OURO := Color(0.78, 0.64, 0.38)
const VERDE := Color(0.45, 0.86, 0.58)
const VERMELHO := Color(0.93, 0.38, 0.33)
const PAPEL := Color(0.93, 0.88, 0.76)

var dado: DadoD20
var _r: Dictionary
var _fundo: ColorRect
var _anel: Control
var _fichas: HBoxContainer
var _faixa: Label
var _dica: Label
var _pronto := false
var _cor_anel := OURO


static func resultado_texto(r: Dictionary) -> String:
	if int(r.get("dado", 0)) == 20:
		return "SUCESSO CRÍTICO"
	if int(r.get("dado", 0)) == 1:
		return "FALHA CRÍTICA"
	return "SUCESSO" if r.get("passou", false) else "FALHA"


func montar(r: Dictionary, duracao := 2.6) -> void:
	_r = r
	layer = 87
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.0)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_fundo.gui_input.connect(_clique)
	add_child(_fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.add_child(centro)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(col)
	var p: Dictionary = TestePericia.PERICIAS.get(str(r.get("pericia", "")), {"nome": "", "atr": ""})
	col.add_child(_rotulo("%s (%s)" % [p["nome"], p["atr"]], 26, PAPEL))
	col.add_child(_rotulo("%s rola o d20" % str(r.get("quem", "")), 16, Color(0.8, 0.75, 0.64)))
	_anel = Control.new()
	_anel.custom_minimum_size = Vector2(300, 300)
	_anel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anel.draw.connect(_desenhar_anel)
	col.add_child(_anel)
	dado = DadoD20.new()
	dado.custom_minimum_size = Vector2.ZERO
	dado.position = Vector2(30, 30)
	dado.size = Vector2(240, 240)
	dado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anel.add_child(dado)
	_fichas = HBoxContainer.new()
	_fichas.alignment = BoxContainer.ALIGNMENT_CENTER
	_fichas.add_theme_constant_override("separation", 14)
	_fichas.modulate.a = 0.0
	_fichas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_fichas)
	_faixa = _rotulo("", 34, PAPEL)
	_faixa.modulate.a = 0.0
	col.add_child(_faixa)
	_dica = _rotulo("clique para continuar", 13, Color(0.7, 0.66, 0.56))
	_dica.modulate.a = 0.0
	col.add_child(_dica)
	var t := create_tween()
	t.tween_property(_fundo, "color:a", 0.78, 0.25)
	dado.parou.connect(_revelar)
	dado.lancar(int(r["dado"]), duracao)


func _rotulo(texto: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _desenhar_anel() -> void:
	var c := _anel.size * 0.5
	var r := minf(_anel.size.x, _anel.size.y) * 0.5 - 6.0
	_anel.draw_arc(c, r, 0, TAU, 96, Color(_cor_anel.r, _cor_anel.g, _cor_anel.b, 0.9), 4.0, true)
	_anel.draw_arc(c, r - 9.0, 0, TAU, 96, Color(_cor_anel.r, _cor_anel.g, _cor_anel.b, 0.35), 1.5, true)
	for i in 20:  # vinte marcas, uma por face: a da DT é a que o dado precisa alcançar
		var a := -PI * 0.5 + TAU * float(i) / 20.0
		var fora := c + Vector2(cos(a), sin(a)) * r
		var dentro := c + Vector2(cos(a), sin(a)) * (r - (14.0 if i + 1 == int(_r["dt"]) else 7.0))
		var cor := OURO if i + 1 != int(_r["dt"]) else PAPEL
		_anel.draw_line(dentro, fora, Color(cor.r, cor.g, cor.b, 0.85 if i + 1 == int(_r["dt"]) else 0.4), 3.0 if i + 1 == int(_r["dt"]) else 1.5)
	var fonte := ThemeDB.fallback_font
	var txt := "DT %d" % int(_r["dt"])
	var m := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var caixa := Rect2(c.x - m.x * 0.5 - 12.0, -8.0, m.x + 24.0, 30.0)
	_anel.draw_rect(caixa, Color(0.28, 0.22, 0.12), true)
	_anel.draw_rect(caixa, OURO, false, 2.0)
	_anel.draw_string(fonte, Vector2(caixa.position.x + 12.0, caixa.position.y + 21.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PAPEL)


func _revelar() -> void:
	var passou: bool = _r["passou"]
	_cor_anel = VERDE if passou else VERMELHO
	dado.brilho = Color(_cor_anel.r, _cor_anel.g, _cor_anel.b, 0.9)
	dado.queue_redraw()
	_anel.queue_redraw()
	for texto in ["d20  %d" % int(_r["dado"]), "+ %d" % int(_r["bonus"]), "= %d" % int(_r["total"])]:
		var f := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.08, 0.06, 0.9)
		sb.border_color = OURO
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		f.add_theme_stylebox_override("panel", sb)
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.add_child(_rotulo(texto, 20, PAPEL))
		_fichas.add_child(f)
	_faixa.text = resultado_texto(_r)
	_faixa.add_theme_color_override("font_color", _cor_anel)
	_faixa.pivot_offset = _faixa.size * 0.5
	_faixa.scale = Vector2(1.5, 1.5)
	var t := create_tween().set_parallel(true)
	t.tween_property(_fichas, "modulate:a", 1.0, 0.3)
	t.tween_property(_faixa, "modulate:a", 1.0, 0.25).set_delay(0.2)
	t.tween_property(_faixa, "scale", Vector2.ONE, 0.35).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_dica, "modulate:a", 1.0, 0.4).set_delay(0.9)
	await get_tree().create_timer(0.5).timeout
	_pronto = true


func _clique(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_fechar()


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_ENTER or ev.keycode == KEY_SPACE or ev.keycode == KEY_KP_ENTER):
		_fechar()
		get_viewport().set_input_as_handled()


func _fechar() -> void:
	if not _pronto:
		return
	_pronto = false
	fechada.emit()
	queue_free()
