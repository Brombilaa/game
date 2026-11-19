class_name CartaoCapitulo
extends CanvasLayer
# Cartão de título do capítulo (Léo, 16/11/2026, modelo A "Horizonte"): quadro 2,39:1, céu escuro, última luz
# vermelha no horizonte e o nome AURORA grande. Entra em fade, fica `duracao` s e sai; qualquer tecla ou clique
# adianta a saída. A legenda "CAPÍTULO 1" é apoio e pode ser tirada (`legenda`).

signal terminou

const FONTE := "res://assets/fonts/CinzelDecorative-Bold.ttf"
const PROPORCAO := 2.39

var titulo := "AURORA"
var legenda := "CAPÍTULO 1"
var duracao := 5.0
var fade := 1.2
var _t := 0.0
var _saindo := false
var _desenho: Control
var _nome: Control


static func tocar(pai: Node, titulo_ := "AURORA", legenda_ := "CAPÍTULO 1", duracao_ := 5.0) -> CartaoCapitulo:
	var c := CartaoCapitulo.new()
	c.titulo = titulo_
	c.legenda = legenda_
	c.duracao = duracao_
	pai.add_child(c)
	return c


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_desenho = Control.new()
	_desenho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.draw.connect(_desenhar)
	add_child(_desenho)
	# O nome vai num controle à parte, por cima do céu.
	_nome = Control.new()
	_nome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nome.draw.connect(_desenhar_nome)
	add_child(_nome)


func alfa() -> float:
	if _saindo:
		return clampf(1.0 - (_t - duracao) / fade, 0.0, 1.0)
	return clampf(_t / fade, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if not _saindo and _t >= duracao:
		_saindo = true
	if _saindo and _t >= duracao + fade:
		terminou.emit()
		queue_free()
		return
	_desenho.queue_redraw()
	_nome.queue_redraw()


func _input(event: InputEvent) -> void:
	var pressionou: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if pressionou and not _saindo and _t > 0.5:
		get_viewport().set_input_as_handled()
		_saindo = true
		_t = duracao  # começa a sair já


func _desenhar() -> void:
	var tela := _desenho.size
	var a := alfa()
	var h := minf(tela.x / PROPORCAO, tela.y)
	var quadro := Rect2(0, (tela.y - h) * 0.5, tela.x, h)
	_desenho.draw_rect(Rect2(Vector2.ZERO, tela), Color(0, 0, 0, a))
	# céu em degradê e luz do horizonte a 62% da altura do quadro
	var topo := Color(0.02, 0.025, 0.04, a)
	var meio := Color(0.055, 0.07, 0.095, a)
	var brasa := Color(0.17, 0.08, 0.065, a)
	var horizonte := quadro.position.y + quadro.size.y * 0.62
	var faixas := 24
	for i in faixas:
		var y0 := quadro.position.y + quadro.size.y * 0.62 * i / faixas
		var f := float(i) / (faixas - 1)
		var c := topo.lerp(meio, minf(f / 0.7, 1.0)) if f < 0.7 else meio.lerp(brasa, (f - 0.7) / 0.3)
		_desenho.draw_rect(Rect2(quadro.position.x, y0, quadro.size.x, quadro.size.y * 0.62 / faixas + 1), c)
	for i in 8:  # brilho vermelho baixo, mais forte junto da linha do horizonte
		var al := 0.05 * (i + 1) * a
		_desenho.draw_rect(Rect2(quadro.position.x, horizonte - quadro.size.y * 0.1 + quadro.size.y * 0.0125 * i, quadro.size.x, quadro.size.y * 0.0125 + 1), Color(0.48, 0.16, 0.11, al))
	_desenho.draw_rect(Rect2(quadro.position.x, horizonte, quadro.size.x, quadro.end.y - horizonte), Color(0.03, 0.024, 0.024, a))


# Letras desse tamanho, redesenhadas a cada quadro, saíam como blocos cheios no renderizador de compatibilidade
# (cache de glifos grandes). Com campo de distância (MSDF) cada glifo é gerado uma vez e só é ampliado.
static var _msdf: FontFile


static func _fonte_msdf() -> FontFile:
	if _msdf == null:
		_msdf = (load(FONTE) as FontFile).duplicate()
		_msdf.multichannel_signed_distance_field = true
		_msdf.msdf_size = 64
		_msdf.msdf_pixel_range = 8
	return _msdf


func _desenhar_nome() -> void:
	var tela := _nome.size
	var a := alfa()
	var h := minf(tela.x / PROPORCAO, tela.y)
	var quadro := Rect2(0, (tela.y - h) * 0.5, tela.x, h)
	var fonte := _fonte_msdf()
	var tam_t := int(quadro.size.y * 0.3)
	var larg := fonte.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_t).x + tam_t * 0.32 * titulo.length()
	var x := quadro.position.x + (quadro.size.x - larg) * 0.5
	var y := quadro.position.y + quadro.size.y * 0.52
	for ch in titulo:  # espaçamento largo entre as letras
		var s := str(ch)
		_nome.draw_string(fonte, Vector2(x + 3, y + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_t, Color(0, 0, 0, a))
		_nome.draw_string(fonte, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_t, Color(0.92, 0.87, 0.82, a))
		x += fonte.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_t).x + tam_t * 0.32
	if legenda != "":
		var tam_l := int(quadro.size.y * 0.055)
		var fl: Font = load("res://assets/fonts/SpecialElite-Regular.ttf")
		var wl := fl.get_string_size(legenda, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_l).x
		_nome.draw_string(fl, Vector2(quadro.position.x + (quadro.size.x - wl) * 0.5, y + quadro.size.y * 0.12), legenda, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_l, Color(0.66, 0.6, 0.55, a))
