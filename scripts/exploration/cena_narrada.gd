class_name CenaNarrada
extends CanvasLayer
# Cena narrada com o jogo CONGELADO (Léo, 22/11/2026): os textos da transformação e da morte da Dama de Sangue
# (roteiro 5b e 5d). Diferente da CenaRoteiro, não mexe em câmera nem em personagens: pausa a árvore, põe as faixas do
# cinema, mostra a narração em blocos (como o Léo escreveu) e as falas do grupo, e devolve o jogo exatamente como estava.
# Por isso serve no meio do combate (a Dama surge no meio de um golpe) e também depois dele.
#
# Passos de data/cenas_narradas/<id>.json (mesmo formato da CenaRoteiro, só um subconjunto, mais "narrar"):
#   cinema   {"estado": "entrar" | "sair", "tempo": s}
#   narrar   {"texto": "...", "tempo": s, "tremor": px, "flash": 0..1}   bloco de narração; clique/espaço avança
#   dialogo  {"falas": [{"quem": id, "texto": "..."}, ...]}               nome em dourado + fala; clique avança
#   esperar  {"tempo": s}
#   marca    {"id": nome}
#
#   await CenaNarrada.tocar(sala, "dama_transformacao")

signal terminou

const PASTA := "res://data/cenas_narradas/"  # fora de data/cenas: os passos daqui (narrar) não são da CenaRoteiro
const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const OURO := Color(0.82, 0.68, 0.4)
const TEXTO := Color(0.96, 0.92, 0.84)
const MINIMO_ANTES_DE_PULAR := 0.7  # o clique que dispara o golpe não pode pular o primeiro bloco
# Sem janela (testes headless) a cena passa direto, como a CaixaFala.
static var pular := DisplayServer.get_name() == "headless"

var passos: Array = []
var _cinema: Cinema
var _bloco: Control
var _nome: Label
var _texto: Label
var _dica: Label
var _vermelho: ColorRect
var _avancou := false
var _tremor := 0.0
var _tremor_forca := 0.0
var _pausado_antes := false


static func carregar(cena_id: String) -> Array:
	var f := FileAccess.open(PASTA + cena_id + ".json", FileAccess.READ)
	if f == null:
		return []
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d.get("passos", []) if d is Dictionary else []


static func tocar(sala: Node, cena_id: String) -> void:
	var lista := carregar(cena_id)
	if lista.is_empty() or pular:
		return
	var c := CenaNarrada.new()
	c.passos = lista
	sala.add_child(c)
	await c.rodar()
	c.queue_free()


func _init() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS  # roda com o jogo pausado
	_vermelho = ColorRect.new()
	_vermelho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vermelho.color = Color(0.55, 0.02, 0.05, 0.0)
	_vermelho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vermelho)
	_bloco = Control.new()
	_bloco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.modulate.a = 0.0
	add_child(_bloco)
	_nome = _rotulo(24, OURO)
	_texto = _rotulo(24, TEXTO)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica = _rotulo(16, Color(0.7, 0.65, 0.58, 0.8))
	_dica.text = "clique para continuar"
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _rotulo(tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(l)
	return l


func rodar() -> void:
	_pausado_antes = get_tree().paused
	get_tree().paused = true
	_cinema = Cinema.new()
	_cinema.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(_cinema)
	for p in passos:
		await _executar(p)
	if _cinema.progresso > 0.0:
		await _cinema.sair(0.5)
	_cinema.queue_free()
	get_tree().paused = _pausado_antes
	terminou.emit()


func _executar(p: Dictionary) -> void:
	match str(p.get("faz", "")):
		"cinema":
			if p.get("estado", "entrar") == "entrar":
				await _cinema.entrar(float(p.get("tempo", 0.8)))
			else:
				await _cinema.sair(float(p.get("tempo", 0.6)))
		"narrar":
			_efeitos(p)
			await _mostrar("", str(p["texto"]), float(p.get("tempo", _tempo_leitura(str(p["texto"])))))
		"dialogo":
			for f in p.get("falas", []):
				var quem := str(f.get("quem", ""))
				await _mostrar(str(CaixaFala.NOMES.get(quem, quem.capitalize())), str(f["texto"]), _tempo_leitura(str(f["texto"])) + 3.0)
		"esperar":
			await _esperar(float(p.get("tempo", 1.0)))
		"marca":
			Missao1.marcar(str(p["id"]))


# Tempo de leitura por texto: ~16 letras por segundo e um fôlego de 1,2 s (sempre dá para pular com o clique).
func _tempo_leitura(t: String) -> float:
	return clampf(t.length() / 16.0 + 1.2, 2.5, 9.0)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _efeitos(p: Dictionary) -> void:
	if p.has("tremor"):
		_tremor = 0.7
		_tremor_forca = float(p["tremor"])
	if p.has("flash"):
		_vermelho.color.a = float(p["flash"])
		var tw := create_tween()
		tw.tween_property(_vermelho, "color:a", 0.0, 1.1)


func _process(delta: float) -> void:
	if _tremor > 0.0:
		_tremor -= delta
		_bloco.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _tremor_forca * clampf(_tremor / 0.7, 0.0, 1.0)
	else:
		_bloco.position = Vector2.ZERO


func _input(event: InputEvent) -> void:
	var clique: bool = event is InputEventMouseButton and event.pressed
	var tecla: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if clique or tecla:
		_avancou = true
		get_viewport().set_input_as_handled()


# Um bloco: aparece, fica até o tempo ou o clique (depois de um mínimo) e some.
func _mostrar(nome: String, texto: String, tempo: float) -> void:
	var j := _cinema.janela_atual()
	var larg := j.size.x * 0.72
	var x := j.position.x + (j.size.x - larg) * 0.5
	_nome.text = nome
	_nome.visible = nome != ""
	_nome.position = Vector2(x, j.end.y - 150.0)
	_nome.size = Vector2(larg, 30)
	_texto.text = texto
	_texto.position = Vector2(x, j.end.y - (118.0 if nome != "" else 130.0))
	_texto.size = Vector2(larg, 100)
	_dica.position = Vector2(j.end.x - 260.0, j.end.y - 26.0)
	_dica.size = Vector2(240, 20)
	_avancou = false
	var tw := create_tween()
	tw.tween_property(_bloco, "modulate:a", 1.0, 0.45)
	await tw.finished
	var t := 0.0
	while t < tempo and not (_avancou and t > MINIMO_ANTES_DE_PULAR):
		await get_tree().process_frame
		t += get_process_delta_time()
	var sai := create_tween()
	sai.tween_property(_bloco, "modulate:a", 0.0, 0.4)
	await sai.finished
