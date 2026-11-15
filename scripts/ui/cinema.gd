class_name Cinema
extends CanvasLayer
# Modo cinema das cutscenes dentro do jogo (Léo, 15/11/2026): barras pretas por cima do mundo, sem HUD, e uma legenda.
# O jogo é 16:9, então "16:9" já é a tela normal; o cinema usa uma janela mais estreita. Três enquadramentos para o
# Léo escolher (página de modelos); MODO_PADRAO é o provisório do Claude até ele escolher.

enum Modo { FAIXAS, VERTICAL, QUADRO }

const MODO_PADRAO := Modo.FAIXAS  # provisório: faixas 2,39:1 (cinemascope)
const PROPORCAO_FAIXAS := 2.39
const PROPORCAO_VERTICAL := 9.0 / 16.0
const ESCALA_QUADRO := 0.8  # a janela 16:9 do quadro ocupa 80% da tela
# Quanto afastar a câmera em cada modo, para a ação caber na janela (que fica menor que a tela).
const ZOOM_REL := {Modo.FAIXAS: 1.0, Modo.VERTICAL: 0.75, Modo.QUADRO: 0.85}

static var modo_global := MODO_PADRAO  # a captura de modelos troca por aqui

var modo := MODO_PADRAO
var progresso := 0.0:  # 0 = tela cheia, 1 = barras completas
	set(v):
		progresso = v
		if _desenho:
			_desenho.queue_redraw()
		_acertar_legenda()
var _desenho: Control
var _legenda: Label
var _legenda_alfa := 0.0:
	set(v):
		_legenda_alfa = v
		if _legenda:
			_legenda.modulate.a = v


# A janela que sobra de tela com as barras completas.
static func janela(m: Modo, tela: Vector2) -> Rect2:
	var tam := tela
	match m:
		Modo.FAIXAS:
			tam = Vector2(tela.x, minf(tela.x / PROPORCAO_FAIXAS, tela.y))
		Modo.VERTICAL:
			tam = Vector2(minf(tela.y * PROPORCAO_VERTICAL, tela.x), tela.y)
		Modo.QUADRO:
			tam = tela * ESCALA_QUADRO
	return Rect2((tela - tam) * 0.5, tam)


func _init(m := -1) -> void:
	modo = modo_global if m < 0 else m as Modo
	layer = 95
	_desenho = Control.new()
	_desenho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.draw.connect(_desenhar)
	add_child(_desenho)
	_legenda = Label.new()
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.add_theme_font_size_override("font_size", 28)
	_legenda.add_theme_color_override("font_color", Color(0.96, 0.92, 0.84))
	_legenda.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_legenda.add_theme_constant_override("outline_size", 6)
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda.modulate.a = 0.0
	_desenho.add_child(_legenda)


func _tela() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


# Janela atual (entre a tela cheia e a janela completa).
func janela_atual() -> Rect2:
	var t := _tela()
	var alvo := janela(modo, t)
	var k := smoothstep(0.0, 1.0, progresso)
	return Rect2(Rect2(Vector2.ZERO, t).position.lerp(alvo.position, k), t.lerp(alvo.size, k))


func _desenhar() -> void:
	var t := _tela()
	var j := janela_atual()
	var preto := Color(0, 0, 0)
	_desenho.draw_rect(Rect2(0, 0, t.x, j.position.y), preto)
	_desenho.draw_rect(Rect2(0, j.end.y, t.x, t.y - j.end.y), preto)
	_desenho.draw_rect(Rect2(0, j.position.y, j.position.x, j.size.y), preto)
	_desenho.draw_rect(Rect2(j.end.x, j.position.y, t.x - j.end.x, j.size.y), preto)
	if modo == Modo.QUADRO and progresso > 0.5:  # fio fino de moldura
		_desenho.draw_rect(j.grow(-1.0), Color(0.45, 0.08, 0.1, 0.8 * progresso), false, 2.0)


func _acertar_legenda() -> void:
	if _legenda == null:
		return
	var j := janela_atual()
	_legenda.size = Vector2(j.size.x * 0.9, 40.0)
	_legenda.position = Vector2(j.position.x + j.size.x * 0.05, j.end.y - 90.0)


func entrar(segundos := 0.9) -> void:
	var tw := create_tween()
	tw.tween_property(self, "progresso", 1.0, segundos).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func sair(segundos := 0.7) -> void:
	var tw := create_tween()
	tw.tween_property(self, "progresso", 0.0, segundos).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# Legenda na parte de baixo da janela: aparece, fica `segura` segundos e some.
func legenda(texto: String, segura := 2.5) -> void:
	_legenda.text = texto
	_acertar_legenda()
	var tw := create_tween()
	tw.tween_property(self, "_legenda_alfa", 1.0, 0.5)
	tw.tween_interval(segura)
	tw.tween_property(self, "_legenda_alfa", 0.0, 0.6)
	await tw.finished
