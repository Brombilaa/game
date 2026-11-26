class_name CaixaFala
extends CanvasLayer
# Caixa de fala com retrato (modelo C "Retrato grande", escolhido pelo Léo em 15/11/2026): retrato grande no canto
# esmaecendo para uma faixa escura, nome em dourado e o texto ao lado. Formato único para os diálogos curtos das
# pistas e para as falas soltas do grupo.
#
#   await caixa.falar("leticia", "Texto...")            # diálogo: pausa o clique do mundo, clique/espaço/Enter avança
#   await caixa.falar("fernando", "Texto...", true)     # solta: não bloqueia, some sozinha (por tempo)
#   await caixa.sequencia([{"quem": "...", "texto": "..."}, ...])
#
# `quem` é o id do personagem (retrato em assets/sprites/retratos/<id>_128.png); sem retrato aparece a inicial.

signal terminou

const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const TELA := Vector2(960, 540)
const ALTURA_FAIXA := 150.0
const RETRATO := 160.0
const OURO := Color(0.82, 0.68, 0.4)
const TEXTO := Color(0.94, 0.9, 0.83)
const LETRAS_POR_SEGUNDO := 55.0
const TEMPO_MINIMO_SOLTA := 2.2
const TEMPO_POR_LETRA_SOLTA := 0.045
const NOMES := {
	"fernando": "Fernando", "nikolai": "Nikolai", "miguel": "Miguel",
	"leticia": "Letícia", "caio": "Caio",
	# Celeiro, depois da Dama (Léo, 19/11): Tristan, sub-líder da Ordem; Mark, que sela o poço; Júlia, namorada da Letícia
	"tristan": "Tristan", "mark": "Mark", "julia": "Júlia", "medico": "Socorrista",
	# Delegacia (roteiro da missão 1, 20/11): o delegado Roberto Ghular e o escrivão Túlio (sem retrato: aparece a inicial)
	"ghular": "Ghular", "tulio": "Túlio",
	# Roberto Ghular de manto (cripta, retrato v2 de 22/11); o de farda é "ghular"
	"ghular_manto": "Ghular",
	# Velho Geraldo Munch (casa do Geraldo, roteiro 3c; retrato v2 de 22/11)
	"geraldo": "Geraldo",
}
const ARQUIVO_FALAS := "res://data/falas.json"

static var _falas_cache: Dictionary = {}
# Sem janela (testes headless) as falas passam direto: quem chama continua no mesmo quadro, sem esperar clique.
static var pular := DisplayServer.get_name() == "headless"

var ocupada := false  # há uma fala na tela
var _fundo: TextureRect
var _retrato: TextureRect
var _inicial: Label
var _nome: Label
var _texto: Label
var _dica: Label
var _pegador: Control  # captura o clique no modo diálogo
var _solta := false
var _fim_digitacao := true
var _avancou := false


func _init() -> void:
	layer = 26
	visible = false
	_pegador = Control.new()
	_pegador.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pegador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pegador.gui_input.connect(_on_gui_input)
	add_child(_pegador)
	_fundo = TextureRect.new()
	_fundo.texture = _gradiente()
	_fundo.position = Vector2(0, TELA.y - ALTURA_FAIXA)
	_fundo.size = Vector2(TELA.x, ALTURA_FAIXA)
	_fundo.stretch_mode = TextureRect.STRETCH_SCALE
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pegador.add_child(_fundo)
	_retrato = TextureRect.new()
	_retrato.position = Vector2(26, TELA.y - RETRATO)
	_retrato.size = Vector2(RETRATO, RETRATO)
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato.material = _mascara_retrato()
	_pegador.add_child(_retrato)
	_inicial = _rotulo(72, Color(0.55, 0.48, 0.35))
	_inicial.position = _retrato.position
	_inicial.size = _retrato.size
	_inicial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inicial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pegador.add_child(_inicial)
	_nome = _rotulo(15, OURO)
	_nome.position = Vector2(208, TELA.y - 118)
	_pegador.add_child(_nome)
	var linha := ColorRect.new()
	linha.color = Color(OURO, 0.8)
	linha.position = Vector2(208, TELA.y - 96)
	linha.size = Vector2(TELA.x - 208 - 48, 1)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pegador.add_child(linha)
	_texto = _rotulo(17, TEXTO)
	_texto.position = Vector2(208, TELA.y - 88)
	_texto.size = Vector2(TELA.x - 208 - 48, 70)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pegador.add_child(_texto)
	_dica = _rotulo(11, Color(OURO, 0.85))
	_dica.text = "clique ▼"
	_dica.position = Vector2(TELA.x - 90, TELA.y - 20)
	_pegador.add_child(_dica)


# Nome de exibição a partir do id (ou do próprio texto, se já for um nome).
static func nome_de(quem: String) -> String:
	return NOMES.get(_id_de(quem), quem)


static func _id_de(quem: String) -> String:
	return quem.to_lower().replace("í", "i").replace("é", "e").replace("á", "a").replace("ó", "o")


static func caminho_retrato(quem: String) -> String:
	return "res://assets/sprites/retratos/%s_128.png" % _id_de(quem)


static func tem_retrato(quem: String) -> bool:
	return ResourceLoader.exists(caminho_retrato(quem))


# Falas da pista (lista de {"quem", "texto"}) ou lista vazia.
static func falas_da_pista(cenario: String, pista: String) -> Array:
	if _falas_cache.is_empty():
		var f := FileAccess.open(ARQUIVO_FALAS, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_falas_cache = d
		if _falas_cache.is_empty():
			_falas_cache = {"_vazio": true}
	return _falas_cache.get("%s/%s" % [cenario, pista], [])


func falar(quem: String, texto: String, solta := false) -> void:
	if pular:
		return
	ocupada = true
	_solta = solta
	_avancou = false
	_nome.text = nome_de(quem).to_upper()
	_texto.text = texto
	_texto.visible_characters = 0
	_dica.visible = not solta
	var tex: Texture2D = load(caminho_retrato(quem)) if tem_retrato(quem) else null
	_retrato.texture = tex
	_retrato.visible = tex != null
	_inicial.visible = tex == null
	_inicial.text = nome_de(quem).left(1)
	_pegador.mouse_filter = Control.MOUSE_FILTER_IGNORE if solta else Control.MOUSE_FILTER_STOP
	visible = true
	var total := texto.length()
	_fim_digitacao = false
	var t := 0.0
	while not _fim_digitacao:
		t += get_process_delta_time()
		var n := mini(total, int(t * LETRAS_POR_SEGUNDO))
		_texto.visible_characters = n
		if n >= total or _avancou:
			_fim_digitacao = true
		else:
			await get_tree().process_frame
	_texto.visible_characters = -1
	_avancou = false
	if solta:
		var espera := maxf(TEMPO_MINIMO_SOLTA, total * TEMPO_POR_LETRA_SOLTA)
		await get_tree().create_timer(espera).timeout
	else:
		while not _avancou:
			await get_tree().process_frame
	visible = false
	ocupada = false
	terminou.emit()


func sequencia(falas: Array, solta := false) -> void:
	for f in falas:
		await falar(str(f.get("quem", "")), str(f.get("texto", "")), solta)


# Cancela o que estiver na tela (troca de cena, combate).
func parar() -> void:
	_avancou = true
	_fim_digitacao = true
	visible = false
	ocupada = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and not _solta and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_avanca()
		get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if not _solta and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_avanca()


# Primeiro avanço completa o texto que está digitando; o segundo passa para a próxima fala.
func _avanca() -> void:
	_avancou = true


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# Faixa escura que some para cima (95% embaixo, 0% no topo).
static func _gradiente() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.016, 0.016, 0.0), Color(0.02, 0.016, 0.016, 0.95), Color(0.02, 0.016, 0.016, 0.95)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	return t


# O retrato esmaece nas bordas, principalmente na base, como no modelo C.
static func _mascara_retrato() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); c.a *= smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.7, 1.0, UV.y)) * smoothstep(0.0, 0.1, UV.x) * (1.0 - smoothstep(0.9, 1.0, UV.x)); COLOR = c; }"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
