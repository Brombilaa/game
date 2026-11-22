class_name Introducao
extends Control
# Introdução PROVISÓRIA da missão 1 (roteiro-missao1.md, seção 0; Claude, 22/11/2026). A introdução de verdade é uma
# animação 3D feita no Blender pelo Léo (20/11): van na estrada, briefing do Caio, pórtico de Aurora, Letícia na porta.
# Enquanto ela não existe, esta cena conta o mesmo com cartões e a caixa de falas sobre as luzes da estrada, e termina no
# bar (cena do bar). Os passos vêm de data/intro.json:
#   cartao   {"texto": "TÍTULO\nlinha", "tempo": s}   texto centrado sobre a estrada
#   legenda  {"texto": "...", "tempo": s}              frase embaixo, sem falante
#   dialogo  {"falas": [{"quem": id, "texto": "..."}]} caixa com retrato (CaixaFala), clique avança
# Esc pula tudo. Quando o vídeo do Blender existir, ele toca no lugar desta cena (trocar a chamada em tela_fichas.gd).

signal terminou

const ARQUIVO := "res://data/intro.json"
const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const TITULO := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")
const TELA := Vector2(960, 540)
const OURO := Color(0.82, 0.68, 0.4)

var passos: Array = []
var caixa: CaixaFala
var pulou := false
var comecou := false
var acabou := false  # os testes leem
var _cartao: Label
var _legenda: Label
var _t := 0.0
var _luz := 0.0  # 0..1: quanto a estrada aparece (some nos cartões da chegada)
var _velocidade := 1.0


static func carregar() -> Array:
	var f := FileAccess.open(ARQUIVO, FileAccess.READ)
	if f == null:
		return []
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d.get("passos", []) if d is Dictionary else []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	passos = carregar()
	_cartao = _rotulo(30, Color(0.93, 0.89, 0.8))
	_cartao.size = Vector2(TELA.x, 120)
	_cartao.position = Vector2(0, 150)
	_cartao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao.modulate.a = 0.0
	add_child(_cartao)
	_legenda = _rotulo(17, Color(0.93, 0.89, 0.8))
	_legenda.size = Vector2(TELA.x - 160, 60)
	_legenda.position = Vector2(80, 380)
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda.modulate.a = 0.0
	add_child(_legenda)
	caixa = CaixaFala.new()
	add_child(caixa)
	# Um quadro antes de começar, para a troca de cena terminar de assentar (o fade do SceneLoader).
	_sequencia.call_deferred()


func _process(delta: float) -> void:
	_t += delta * _velocidade
	queue_redraw()


# Estrada ao entardecer: céu que esfria, linha do horizonte e luzes que passam sempre iguais (a estrada que parece infinita).
func _draw() -> void:
	var horizonte := 250.0
	var topo := Color(0.05, 0.04, 0.07)
	var meio := Color(0.42, 0.2, 0.14)
	var n := 24
	for i in n:
		var k := float(i) / float(n)
		draw_rect(Rect2(0, horizonte * k, TELA.x, horizonte / n + 1.0), topo.lerp(meio, pow(k, 2.2)))
	draw_rect(Rect2(0, horizonte, TELA.x, TELA.y - horizonte), Color(0.03, 0.026, 0.025))
	# Pista: trapézio que converge para o ponto de fuga.
	var fuga := Vector2(TELA.x * 0.5, horizonte)
	draw_colored_polygon(PackedVector2Array([fuga + Vector2(-10, 0), fuga + Vector2(10, 0), Vector2(TELA.x * 0.9, TELA.y), Vector2(TELA.x * 0.1, TELA.y)]), Color(0.07, 0.065, 0.065))
	# Faixas do meio andando para a frente.
	for i in 9:
		var k := fmod(float(i) / 9.0 + _t * 0.35, 1.0)
		var kk := k * k
		var y := horizonte + (TELA.y - horizonte) * kk
		var w := 1.0 + 9.0 * kk
		var h := 2.0 + 30.0 * kk
		draw_rect(Rect2(fuga.x - w * 0.5, y, w, h), Color(0.78, 0.62, 0.3, 0.55 * _luz))
	# Postes dos dois lados: as luzes que se repetem.
	for lado in [-1.0, 1.0]:
		for i in 8:
			var k := fmod(float(i) / 8.0 + _t * 0.18, 1.0)
			var kk := k * k
			var y := horizonte + (TELA.y - horizonte) * kk * 0.95
			var x: float = fuga.x + lado * (40.0 + 380.0 * kk)
			var r := 1.5 + 5.0 * kk
			draw_circle(Vector2(x, y - 30.0 * kk), r * 3.0, Color(1.0, 0.72, 0.36, 0.10 * _luz))
			draw_circle(Vector2(x, y - 30.0 * kk), r, Color(1.0, 0.86, 0.55, 0.9 * _luz))
	# Vinheta.
	for i in 6:
		var a := 0.1 * float(6 - i)
		draw_rect(Rect2(0, i * 4.0, TELA.x, 4.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, TELA.y - (i + 1) * 4.0, TELA.x, 4.0), Color(0, 0, 0, a))


func _sequencia() -> void:
	comecou = true
	var t := create_tween()
	t.tween_property(self, "_luz", 1.0, 1.2)
	for p in passos:
		if pulou:
			break
		var passo: Dictionary = p
		match str(passo.get("faz", "")):
			"cartao":
				await _cartao_em(str(passo["texto"]), float(passo.get("tempo", 3.0)))
			"legenda":
				await _legenda_em(str(passo["texto"]), float(passo.get("tempo", 3.0)))
			"dialogo":
				for f in passo.get("falas", []):
					if pulou:
						break
					await caixa.falar(str(f.get("quem", "")), str(f.get("texto", "")))
	await _fim()


func _cartao_em(texto: String, tempo: float) -> void:
	var linhas := texto.split("\n")
	_cartao.text = linhas[0] + ("\n" + "\n".join(linhas.slice(1)) if linhas.size() > 1 else "")
	_cartao.add_theme_font_override("font", TITULO)
	_cartao.add_theme_font_size_override("font_size", 30)
	var t := create_tween()
	t.tween_property(_cartao, "modulate:a", 1.0, 0.7)
	t.tween_interval(maxf(tempo - 1.4, 0.2))
	t.tween_property(_cartao, "modulate:a", 0.0, 0.7)
	await _espera(t)


func _legenda_em(texto: String, tempo: float) -> void:
	_legenda.text = texto
	var t := create_tween()
	t.tween_property(_legenda, "modulate:a", 1.0, 0.5)
	t.tween_interval(maxf(tempo - 1.0, 0.2))
	t.tween_property(_legenda, "modulate:a", 0.0, 0.5)
	await _espera(t)


# Espera o tween terminar ou o jogador pular.
func _espera(t: Tween) -> void:
	if DisplayServer.get_name() == "headless":
		t.kill()
		return
	while t.is_valid() and t.is_running() and not pulou:
		await get_tree().process_frame
	if t.is_valid():
		t.kill()


func _fim() -> void:
	if acabou:
		return
	acabou = true
	caixa.parar()
	terminou.emit()
	# Depois da introdução, o bar. Em teste (sem a cena atual ser esta) só emite o sinal.
	Missao1.local = Missao1.PRIMEIRO_LUGAR
	Missao1.chegada = ""
	if is_inside_tree() and get_tree().current_scene == self:
		Scenes.go(get_tree(), Missao1.CENA_LOCAL)


func _unhandled_input(event: InputEvent) -> void:
	if acabou or not event.is_pressed():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		pulou = true
		get_viewport().set_input_as_handled()
		if caixa != null:
			caixa.parar()


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
