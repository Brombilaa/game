class_name CenaItalia
extends Control
# Cliffhanger do fim do capítulo 1 (Léo, 19/11/2026): corta do celeiro para um plano distante de uma igreja na Itália,
# à noite, com cantos ao fundo; uma explosão, gritos, e parte da igreja cai sem que se veja (a poeira e o escuro
# cobrem). Depois, preto e o cartão AURORA. Feita no jogo, desenhada à mão, até existir a cutscene externa.
# Som: toca `cantos_igreja`, `explosao` e `gritos` de assets/audio quando existirem; sem eles, legendas entre colchetes.
# Tempos, cores, legendas e o desenho são provisórios do Claude. Qualquer tecla ou clique pula a cena.

signal terminou

const DURACAO := 13.0  # s da cena inteira (provisório)
const T_EXPLOSAO := 6.0  # s até a explosão
const T_APAGA := 10.6  # s em que a tela começa a escurecer de vez
const PASTA_SOM := "res://assets/audio/"
const FONTE := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const PROPORCAO := 2.39  # mesmo quadro de cinema do resto das cenas

var t := 0.0
var _acabou := false
var _explodiu := false
var _poeira: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _sons := {}  # nome -> AudioStreamPlayer (só os que existem)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 19
	for nome in ["cantos_igreja", "explosao", "gritos"]:
		var caminho: String = PASTA_SOM + str(nome) + ".ogg"
		if ResourceLoader.exists(caminho):
			var p := AudioStreamPlayer.new()
			p.stream = load(caminho)
			add_child(p)
			_sons[nome] = p
	_tocar_som("cantos_igreja")


func _tocar_som(nome: String) -> void:
	if _sons.has(nome):
		_sons[nome].play()


func tem_som(nome: String) -> bool:
	return _sons.has(nome)


func _process(delta: float) -> void:
	if _acabou:
		return
	t += delta
	if not _explodiu and t >= T_EXPLOSAO:
		_explodir()
	for p in _poeira:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 1.0 - 0.35 * delta
		p["r"] += p["cresce"] * delta
	if t >= DURACAO:
		_fim()
	queue_redraw()


func _explodir() -> void:
	_explodiu = true
	_tocar_som("explosao")
	_tocar_som("gritos")
	if _sons.has("cantos_igreja"):
		create_tween().tween_property(_sons["cantos_igreja"], "volume_db", -60.0, 0.4)
	for i in 70:  # poeira que sobe da nave e cobre a torre que cai
		var ang := _rng.randf_range(PI * 1.05, PI * 1.95)
		_poeira.append({"pos": Vector2(_rng.randf_range(-0.06, 0.08), _rng.randf_range(-0.02, 0.02)),
			"vel": Vector2(cos(ang), sin(ang)) * _rng.randf_range(0.02, 0.09), "r": _rng.randf_range(0.01, 0.025),
			"cresce": _rng.randf_range(0.006, 0.02), "tom": _rng.randf_range(0.55, 0.8)})


func _fim() -> void:
	if _acabou:
		return
	_acabou = true
	for s in _sons.values():
		s.stop()
	terminou.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and t > 0.5:
		accept_event()
		_fim()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and t > 0.5:
		get_viewport().set_input_as_handled()
		_fim()


# Alfa geral: entra do preto, e no fim volta ao preto.
func alfa() -> float:
	var entra := clampf(t / 1.6, 0.0, 1.0)
	var sai := 1.0 - clampf((t - T_APAGA) / 1.6, 0.0, 1.0)
	return minf(entra, sai)


func _draw() -> void:
	var tela := size
	if tela.y < 10.0:  # ainda sem tamanho (primeiro quadro, testes sem janela)
		return
	draw_rect(Rect2(Vector2.ZERO, tela), Color.BLACK)
	var h := minf(tela.x / PROPORCAO, tela.y)
	var q := Rect2(0, (tela.y - h) * 0.5, tela.x, h)
	var a := alfa()
	var explosao := clampf((t - T_EXPLOSAO) / 0.25, 0.0, 1.0) * (1.0 - clampf((t - T_EXPLOSAO - 0.25) / 2.8, 0.0, 1.0)) if _explodiu else 0.0
	var tremor := Vector2.ZERO
	if _explodiu and t - T_EXPLOSAO < 1.6:
		var k := 1.0 - (t - T_EXPLOSAO) / 1.6
		tremor = Vector2(sin(t * 61.0), cos(t * 47.0)) * 4.0 * k
	# céu noturno, mais claro perto do horizonte
	var faixas := 20
	for i in faixas:
		var f := float(i) / (faixas - 1)
		var c := Color(0.02, 0.025, 0.05).lerp(Color(0.07, 0.075, 0.11), f)
		c = c.lerp(Color(0.55, 0.22, 0.08), explosao * f * 0.6)
		draw_rect(Rect2(q.position.x, q.position.y + q.size.y * 0.7 * i / faixas, q.size.x, q.size.y * 0.7 / faixas + 1), Color(c, a))
	for i in 40:  # estrelas fixas
		var sx := fmod(i * 137.5, 1.0 * q.size.x)
		var sy := fmod(i * 59.3, q.size.y * 0.45)
		draw_rect(Rect2(q.position + Vector2(sx, sy), Vector2(1, 1)), Color(0.8, 0.8, 0.9, a * 0.5))
	var base := q.position + Vector2(q.size.x * 0.58, q.size.y * 0.66) + tremor  # pé da igreja, no alto da colina
	var u := q.size.y  # tudo da igreja em fração da altura do quadro
	# colinas ao longe
	var colina := PackedVector2Array([Vector2(q.position.x, q.end.y), Vector2(q.position.x, q.position.y + u * 0.74),
		Vector2(q.position.x + q.size.x * 0.3, q.position.y + u * 0.7), base + Vector2(-u * 0.32, u * 0.01),
		base + Vector2(u * 0.34, u * 0.0), Vector2(q.end.x, q.position.y + u * 0.72), Vector2(q.end.x, q.end.y)])
	draw_colored_polygon(colina, Color(0.015, 0.015, 0.02, a))
	# a igreja: nave, telhado, torre do sino com cruz e janelas acesas (a torre some na poeira depois da explosão)
	var pedra := Color(0.035, 0.032, 0.04, a)
	var nave := Rect2(base + Vector2(-u * 0.14, -u * 0.09), Vector2(u * 0.24, u * 0.09))
	draw_rect(nave, pedra)
	draw_colored_polygon(PackedVector2Array([nave.position, nave.position + Vector2(nave.size.x, 0), nave.position + Vector2(nave.size.x * 0.5, -u * 0.05)]), pedra)
	var torre_queda := clampf((t - T_EXPLOSAO - 0.4) / 2.5, 0.0, 1.0) if _explodiu else 0.0
	var torre := Rect2(base + Vector2(u * 0.1, -u * 0.2 + u * 0.06 * torre_queda), Vector2(u * 0.05, u * 0.2 - u * 0.06 * torre_queda))
	draw_rect(torre, pedra)
	draw_colored_polygon(PackedVector2Array([torre.position, torre.position + Vector2(torre.size.x, 0), torre.position + Vector2(torre.size.x * 0.5, -u * 0.04)]), pedra)
	var cruz := torre.position + Vector2(torre.size.x * 0.5, -u * 0.04)
	draw_rect(Rect2(cruz + Vector2(-1, -u * 0.03), Vector2(2, u * 0.03)), pedra)
	draw_rect(Rect2(cruz + Vector2(-u * 0.008, -u * 0.022), Vector2(u * 0.016, 2)), pedra)
	var luz := Color(0.95, 0.68, 0.32, a * (0.85 - 0.75 * clampf((t - T_EXPLOSAO) / 0.5, 0.0, 1.0) if _explodiu else 0.85))
	for i in 4:  # janelas da nave, quentes por dentro: há gente rezando
		draw_rect(Rect2(nave.position + Vector2(nave.size.x * (0.14 + 0.2 * i), nave.size.y * 0.3), Vector2(u * 0.01, u * 0.03)), luz)
	draw_rect(Rect2(torre.position + Vector2(torre.size.x * 0.38, torre.size.y * 0.25), Vector2(u * 0.012, u * 0.025)), luz)
	# explosão: clarão por dentro da nave, depois só brasa e poeira
	if _explodiu:
		var centro := nave.get_center() + Vector2(u * 0.02, 0)
		for i in 6:
			var r := u * (0.05 + 0.06 * i) * (0.6 + explosao)
			draw_circle(centro, r, Color(1.0, 0.55 - 0.06 * i, 0.15, a * explosao * (0.35 - 0.05 * i)))
		var brasa := clampf(1.0 - (t - T_EXPLOSAO) / 6.0, 0.25, 1.0)
		draw_rect(Rect2(nave.position + Vector2(0, nave.size.y * 0.6), Vector2(nave.size.x, nave.size.y * 0.4)), Color(0.8, 0.25, 0.06, a * 0.45 * brasa))
		for p in _poeira:
			var pp: Vector2 = centro + (p["pos"] as Vector2) * u * 2.2
			var cor := Color(0.12, 0.1, 0.1).lerp(Color(0.5, 0.22, 0.1), explosao * 0.6)
			draw_circle(pp, float(p["r"]) * u * 1.6, Color(cor * float(p["tom"]), a * 0.55))
	# legenda do lugar e do som (sem os arquivos de som, entre colchetes)
	var pequeno := int(u * 0.045)
	draw_string(FONTE, q.position + Vector2(u * 0.08, u * 0.12), "ITÁLIA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(u * 0.06), Color(0.85, 0.8, 0.72, a * clampf((t - 0.8) / 1.0, 0.0, 1.0)))
	var linha := ""
	if not _explodiu and t > 1.6 and not tem_som("cantos_igreja"):
		linha = "[cantos ao longe]"
	elif _explodiu and t - T_EXPLOSAO < 3.5 and not tem_som("explosao"):
		linha = "[explosão]  [gritos]"
	if linha != "":
		var w := FONTE.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, pequeno).x
		draw_string(FONTE, Vector2(q.position.x + (q.size.x - w) * 0.5, q.end.y - u * 0.08), linha, HORIZONTAL_ALIGNMENT_LEFT, -1, pequeno, Color(0.85, 0.8, 0.72, a * 0.9))
	# clarão branco na tela no instante da explosão
	if _explodiu and t - T_EXPLOSAO < 0.5:
		draw_rect(Rect2(Vector2.ZERO, tela), Color(1, 0.9, 0.75, a * 0.35 * (1.0 - (t - T_EXPLOSAO) / 0.5)))
