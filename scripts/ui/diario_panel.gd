class_name DiarioPanel
extends CanvasLayer
# Diário do Miguel, modelo B1 "couro costurado" (Léo, 19/11/2026): um caderno de couro aberto em página dupla, com
# três abas de fita no topo. DIÁRIO é o relato da missão escrito pelo Miguel, um lugar por página, com desenhos a
# lápis (DiarioMiguel); PISTAS é a lista do que o grupo examinou, com a pista aberta na página da direita (ligar uma
# pista a outra é com o jogador, na cabeça: não há botão nem regra de ligação); CRIATURAS é o que o grupo sabe de cada inimigo (Fraquezas). Abre e fecha com J (Esc e
# o X também fecham), Tab troca de aba e as setas escolhem. Com o diário aberto o tempo para, como no inventário
# (GDD #23). Só desenha e lê mouse e teclado; os dados vêm de Diario/Missao1/DiarioMiguel/Fraquezas e o objetivo,
# de `room._objectives()`.

const MAO := preload("res://assets/fonts/Caveat-Variable.ttf")
const MAQ := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const COURO := preload("res://assets/sprites/diario/couro.jpg")
const PAPEL := preload("res://assets/sprites/diario/papel.jpg")
const CAFE := preload("res://assets/sprites/diario/cafe.png")
const SANGUE := preload("res://assets/sprites/diario/sangue.png")
const RABISCOS := "res://assets/sprites/diario/rabiscos/%s.png"

const CAPA := Rect2(128, 50, 704, 444)  # na tela interna 960x540
const BORDA := 11.0  # couro visível em volta das páginas
const TINTA := Color(0.243, 0.141, 0.078)
const VERMELHO := Color(0.557, 0.106, 0.071)
const APAGADO := Color(0.243, 0.141, 0.078, 0.6)
const FITA := Color(0.478, 0.078, 0.063)
const FITA_ON := Color(0.69, 0.125, 0.102)
const FITA_TEXTO := Color(0.95, 0.86, 0.69)
const LINHA := Color(0.84, 0.67, 0.43, 0.6)

var room: Node
var open := false
var secao := "diario"  # "diario", "pistas" ou "criaturas"
var sel := 0  # pista aberta (posição na lista de PISTAS)
var sel_pagina := 0  # lugar aberto no DIÁRIO
var sel_criatura := 0

var _raiz: Control
var _esq: Control  # página da esquerda (conteúdo refeito a cada atualizar)
var _dir: Control
var _abas: Dictionary = {}  # id -> Button
# Nós fixos da aba PISTAS (os testes leem estes).
var _lista: VBoxContainer
var _titulo_det: Label
var _lugar_det: Label
var _imagem: TextureRect
var _texto: Label
var _obj: Label
var _contagem: Label
var _vazio: Label
var _pg_pistas_esq: Control
var _pg_pistas_dir: Control
var _negrito: FontVariation
var _dica: Label
var _geracao := 0  # cada refresh do DIÁRIO invalida o _refluir anterior

const DICAS := {
	"diario": "J fecha · Tab troca de aba · ← → vira a página",
	"pistas": "J fecha · Tab troca de aba · ↑↓ escolhe · L liga duas pistas",
	"criaturas": "J fecha · Tab troca de aba · ← → troca de criatura",
}


func _init() -> void:
	layer = 21
	visible = false
	_negrito = FontVariation.new()
	_negrito.base_font = MAO
	_negrito.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(dim)
	_montar_capa()
	_montar_abas()
	var pw := (CAPA.size.x - BORDA * 2.0) / 2.0
	var ph := CAPA.size.y - BORDA * 2.0
	_esq = _pagina(Vector2(CAPA.position.x + BORDA, CAPA.position.y + BORDA), Vector2(pw, ph), true)
	_dir = _pagina(Vector2(CAPA.position.x + BORDA + pw, CAPA.position.y + BORDA), Vector2(pw, ph), false)
	_montar_pistas()
	var x := Button.new()
	x.text = "×"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_override("font", _negrito)
	x.add_theme_font_size_override("font_size", 26)
	x.add_theme_color_override("font_color", FITA_TEXTO)
	x.position = Vector2(CAPA.end.x - 26, CAPA.position.y - 30)
	x.pressed.connect(fechar)
	_raiz.add_child(x)
	_dica = _rotulo("", 10, Color(0.85, 0.79, 0.65), MAQ)
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.autowrap_mode = TextServer.AUTOWRAP_OFF
	var fundo := StyleBoxFlat.new()  # tampa as dicas do HUD que ficam atrás, no mesmo ponto da tela
	fundo.bg_color = Color(0.05, 0.035, 0.03, 0.92)
	fundo.set_corner_radius_all(3)
	fundo.content_margin_left = 10
	fundo.content_margin_right = 10
	fundo.content_margin_top = 2
	fundo.content_margin_bottom = 3
	_dica.add_theme_stylebox_override("normal", fundo)
	_dica.position = Vector2(CAPA.position.x + CAPA.size.x * 0.2, CAPA.end.y + 6)
	_dica.size = Vector2(CAPA.size.x * 0.6, 16)
	_raiz.add_child(_dica)


# --- Montagem fixa ---------------------------------------------------------------------------------

class Costura extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2(5, 5), size - Vector2(10, 10))
		var cantos := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for k in 4:
			var a: Vector2 = cantos[k]
			var b: Vector2 = cantos[k + 1]
			var n := int(a.distance_to(b) / 7.0)
			for i in n:
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, (i + 0.55) / n), Color(0.84, 0.67, 0.43, 0.55), 1.2)


class Dobra extends Control:  # sombra da lombada, escurecendo para o meio do caderno
	var esquerda := true
	func _draw() -> void:
		var w := 26.0
		for i in int(w):
			var t := 1.0 - float(i) / w
			var x := size.x - 1 - i if esquerda else float(i)
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.24, 0.12, 0.04, 0.42 * t * t), 1.0)


func _montar_capa() -> void:
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.45)
	sombra.position = CAPA.position + Vector2(4, 8)
	sombra.size = CAPA.size
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	var couro := TextureRect.new()
	couro.texture = COURO
	couro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	couro.stretch_mode = TextureRect.STRETCH_SCALE
	couro.position = CAPA.position
	couro.size = CAPA.size
	couro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(couro)
	var c := Costura.new()
	c.position = CAPA.position
	c.size = CAPA.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(c)


func _montar_abas() -> void:
	var x := CAPA.position.x + 56
	for par in [["diario", "DIÁRIO"], ["pistas", "PISTAS"], ["criaturas", "CRIATURAS"]]:
		var b := Button.new()
		b.text = par[1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", _negrito)
		b.add_theme_font_size_override("font_size", 15)
		b.position = Vector2(x, CAPA.position.y - 26)
		b.custom_minimum_size = Vector2(0, 30)
		b.pressed.connect(trocar_secao.bind(par[0]))
		_raiz.add_child(b)
		_abas[par[0]] = b
		x += 8 + b.get_combined_minimum_size().x + 20


func _estilo_abas() -> void:
	for id in _abas:
		var b: Button = _abas[id]
		var on: bool = id == secao
		var e := StyleBoxFlat.new()
		e.bg_color = FITA_ON if on else FITA
		e.content_margin_left = 10
		e.content_margin_right = 10
		e.content_margin_top = 10 if on else 4
		e.content_margin_bottom = 2
		e.shadow_color = Color(0, 0, 0, 0.35)
		e.shadow_size = 2
		for n in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(n, e)
		for n in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(n, FITA_TEXTO)
		b.position.y = CAPA.position.y - (32 if on else 24)


func _pagina(pos: Vector2, tam: Vector2, esquerda: bool) -> Control:
	var papel := TextureRect.new()
	papel.texture = PAPEL
	papel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	papel.stretch_mode = TextureRect.STRETCH_SCALE
	papel.flip_h = not esquerda
	papel.position = pos
	papel.size = tam
	papel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(papel)
	var dobra := Dobra.new()
	dobra.esquerda = esquerda
	dobra.position = pos
	dobra.size = tam
	dobra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(dobra)
	var conteudo := Control.new()
	conteudo.position = pos
	conteudo.size = tam
	conteudo.mouse_filter = Control.MOUSE_FILTER_PASS
	_raiz.add_child(conteudo)
	return conteudo


# Nós da aba PISTAS ficam montados o tempo todo (só aparecem nela).
func _montar_pistas() -> void:
	_pg_pistas_esq = _coluna(_esq)
	_pg_pistas_esq.get_parent().set_meta("fixo", true)  # as páginas de PISTAS ficam; _limpar só tira o resto
	_pg_pistas_esq.add_child(_titulo("Pistas"))
	_contagem = _rotulo("", 12, APAGADO)
	_contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pg_pistas_esq.add_child(_contagem)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 0)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista)
	_pg_pistas_esq.add_child(rolagem)
	_vazio = _rotulo("Nada anotado ainda.\nExamine o que parecer estranho.", 15, APAGADO)
	_vazio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pg_pistas_esq.add_child(_vazio)
	_obj = _rotulo("", 13, VERMELHO)
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj.rotation = deg_to_rad(-1.0)
	_pg_pistas_esq.add_child(_obj)

	_pg_pistas_dir = _coluna(_dir)
	_pg_pistas_dir.get_parent().set_meta("fixo", true)
	_titulo_det = _titulo("")
	_pg_pistas_dir.add_child(_titulo_det)
	_lugar_det = _rotulo("", 12, APAGADO)
	_lugar_det.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pg_pistas_dir.add_child(_lugar_det)
	_imagem = TextureRect.new()
	_imagem.custom_minimum_size = Vector2(250, 120)
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pg_pistas_dir.add_child(_imagem)
	_texto = _rotulo("", 15, TINTA)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pg_pistas_dir.add_child(_texto)
	var vao := Control.new()
	vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pg_pistas_dir.add_child(vao)


# --- Peças --------------------------------------------------------------------------------------------

func _rotulo(texto: String, tamanho: int, cor: Color, fonte: Font = null) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fonte if fonte != null else MAO)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _titulo(texto: String, tamanho := 26) -> Label:
	var l := _rotulo(texto, tamanho, VERMELHO, _negrito)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


# Linha manuscrita: BBCode ([s] riscado, [u], [color]) e um leve torto, diferente a cada linha.
func _linha(bb: String, tamanho := 15, centro := false, semente := 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", MAO)
	r.add_theme_font_override("bold_font", _negrito)
	r.add_theme_font_size_override("normal_font_size", tamanho)
	r.add_theme_font_size_override("bold_font_size", tamanho)
	r.add_theme_color_override("default_color", TINTA)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = ("[center]%s[/center]" % bb) if centro else bb
	var h := hash(bb) + semente
	r.rotation = deg_to_rad(float(h % 21 - 10) / 10.0)  # -1° a 1°
	return r


func _coluna(pagina: Control) -> VBoxContainer:
	var m := MarginContainer.new()
	m.position = Vector2.ZERO
	m.size = pagina.size
	for lado in ["left", "right"]:
		m.add_theme_constant_override("margin_" + lado, 26)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 14)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	pagina.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_child(v)
	return v


func _esboco(caminho: String, tam: Vector2, graus := 0.0) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # antes do tamanho, senão a textura impõe o dela
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load(caminho) if caminho != "" else null
	t.custom_minimum_size = tam
	t.size = tam
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.pivot_offset = tam / 2.0
	t.rotation = deg_to_rad(graus)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# Foto revelada (retrato ou imagem de inspeção) com legenda à mão.
func _foto(caminho: String, lado: float, legenda: String, graus: float) -> Control:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color(0.94, 0.9, 0.82)
	e.content_margin_left = 5
	e.content_margin_right = 5
	e.content_margin_top = 5
	e.content_margin_bottom = 2
	e.shadow_color = Color(0, 0, 0, 0.4)
	e.shadow_size = 3
	e.shadow_offset = Vector2(2, 3)
	p.add_theme_stylebox_override("panel", e)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var img := TextureRect.new()
	img.texture = load(caminho) if caminho != "" and ResourceLoader.exists(caminho) else null
	img.custom_minimum_size = Vector2(lado, lado)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	img.modulate = Color(1.0, 0.93, 0.82)
	v.add_child(img)
	var l := _rotulo(legenda, 12, TINTA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	p.rotation = deg_to_rad(graus)
	return p


func _mancha(pagina: Control, tex: Texture2D, pos: Vector2, lado: float, graus: float, alfa: float) -> void:
	var t := _esboco("", Vector2(lado, lado), graus)
	t.texture = tex
	t.position = pos
	t.modulate.a = alfa
	pagina.add_child(t)


func _limpar(pagina: Control) -> void:
	for f in pagina.get_children():
		if f.get_meta("fixo", false):
			continue
		pagina.remove_child(f)
		f.queue_free()


# --- Abrir, fechar, trocar ----------------------------------------------------------------------------

func abrir() -> void:
	if open:
		return
	open = true
	sel = 0  # a última descoberta
	sel_pagina = maxi(DiarioMiguel.secoes().size() - 1, 0)  # o relato abre no lugar mais recente
	var caixa: Variant = room.get("caixa") if room != null else null
	if caixa is CaixaFala and caixa.visible and caixa._solta:
		caixa.parar()  # fala solta de pista não fica por cima do caderno
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


func trocar_secao(id: String) -> void:
	secao = id
	atualizar()


func atualizar() -> void:
	_geracao += 1
	_estilo_abas()
	_dica.text = DICAS.get(secao, "")
	for pg in [_esq, _dir]:
		_limpar(pg)
	_pg_pistas_esq.get_parent().visible = secao == "pistas"
	_pg_pistas_dir.get_parent().visible = secao == "pistas"
	match secao:
		"diario":
			_atualizar_diario()
		"criaturas":
			_atualizar_criaturas()
		_:
			_atualizar_pistas()


# --- DIÁRIO: o relato do Miguel ------------------------------------------------------------------------

func _atualizar_diario() -> void:
	var ss := DiarioMiguel.secoes()
	_pautas(_esq, true)
	_pautas(_dir, false)
	var col := _coluna(_esq)
	if ss.is_empty():
		col.add_child(_titulo("Diário"))
		col.add_child(_linha("Ainda não escrevi nada.", 15, true))
		return
	sel_pagina = clampi(sel_pagina, 0, ss.size() - 1)
	var s: Dictionary = ss[sel_pagina]
	if sel_pagina == 0:
		var cab := DiarioMiguel.cabecalho()
		var t := _titulo(str(cab["titulo"]), 28)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(t)
		col.add_child(_rotulo(str(cab["sub"]), 12, APAGADO))
	var h := _rotulo(str(s["titulo"]), 19, VERMELHO, _negrito)
	col.add_child(h)
	# O texto corre pela página dupla (esquerda e depois direita) com os desenhos no meio dele, como num
	# caderno de verdade (modelo "corrido", Léo 19/11). Cada desenho entra depois de uma linha, espalhados por igual.
	var linhas: Array = s["linhas"]
	var desenhos: Array = s["desenhos"]
	var depois := {}  # índice da linha -> desenho que vem junto dela
	for i in desenhos.size():
		depois[clampi(int(round(float(i) * linhas.size() / desenhos.size())), 0, maxi(linhas.size() - 1, 0))] = i
	var cabe := _esq.size.y - 40.0  # o pé da direita fica para o "n de m"
	var fixos := col.get_child_count()
	for i in linhas.size():
		var l: Dictionary = linhas[i]
		var tam := 17 if l["maior"] else 15
		if depois.has(i):
			for bl in _bloco_desenho(desenhos[depois[i]], depois[i], str(l["t"]), tam, i):
				col.add_child(bl)
		else:
			col.add_child(_linha(str(l["t"]), tam, false, i))
	# Anotações soltas do Miguel no fim (lembretes, perguntas), cada uma com um rabisco do lado.
	for k in s["notas"].size():
		col.add_child(_nota(s["notas"][k], k))
	# Tudo entra primeiro na página da esquerda; depois do layout, _refluir passa o resto para a direita.
	var col_dir := _coluna(_dir)
	col.modulate.a = 0.0
	col_dir.modulate.a = 0.0
	_refluir(col, col_dir, fixos, cabe)
	_enfeites(sel_pagina)
	var pag := _rotulo("‹  %d de %d  ›" % [sel_pagina + 1, ss.size()], 14, APAGADO)
	pag.autowrap_mode = TextServer.AUTOWRAP_OFF
	pag.position = Vector2(_dir.size.x - 92, _dir.size.y - 26)
	_dir.add_child(pag)


# Depois do layout real (as alturas do texto manuscrito só existem aí): a esquerda fica com mais ou menos
# metade do lugar e o resto passa para a direita; o que não cabe na página dupla sai; papel sobrando
# embaixo ganha o mapa rabiscado do caminho.
func _refluir(col: VBoxContainer, col_dir: VBoxContainer, fixos: int, cabe: float) -> void:
	_geracao += 1
	var g := _geracao
	for i in 3:
		await get_tree().process_frame
	if g != _geracao or not is_instance_valid(col) or not is_instance_valid(col_dir):
		return
	var filhos := col.get_children()
	var fim := 0.0
	for c in filhos:
		fim = maxf(fim, c.position.y + c.size.y)
	var alvo := clampf(fim * 0.62, 120.0, cabe)
	if fim > cabe * 1.3:
		alvo = cabe  # lugar cheio: a esquerda vai até o fim
	var passou := false
	for i in range(fixos, filhos.size()):
		var c: Control = filhos[i]
		if passou or c.position.y + c.size.y > alvo:
			passou = true
			col.remove_child(c)
			col_dir.add_child(c)
	for i in 3:
		await get_tree().process_frame
	if g != _geracao or not is_instance_valid(col_dir):
		return
	var resto := 0.0
	for c in col_dir.get_children():
		if c.position.y + c.size.y > cabe - 6.0:
			c.queue_free()  # não cabe mais nada na página dupla
		else:
			resto = c.position.y + c.size.y
	var resto_esq := 0.0
	for c in col.get_children():
		resto_esq = maxf(resto_esq, c.position.y + c.size.y)
	# Papel sobrando: o mapa rabiscado do caminho vai na página mais vazia e um rabisco grande na outra.
	var livre := {col: cabe - resto_esq, col_dir: cabe - resto}
	var mais := col if livre[col] > livre[col_dir] else col_dir
	var menos := col_dir if mais == col else col
	if livre[mais] > 150.0:
		var lado := minf(200.0, (livre[mais] - 40.0) * 1.33)
		mais.add_child(_centro(_figura(RABISCOS % "mapa", Vector2(lado, lado * 0.75), "o caminho até aqui", 3.0, false)))
	if livre[menos] > 70.0:
		var nome: String = ["olho", "espiral", "estrela"][sel_pagina % 3]
		var q := minf(84.0, livre[menos] - 20.0)
		var r := _esboco(RABISCOS % nome, Vector2(q, q), -10.0 + sel_pagina * 7.0)
		r.modulate.a = 0.6
		menos.add_child(_centro(r))
	col.modulate.a = 1.0
	col_dir.modulate.a = 1.0


func _centro(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


# Pauta de caderno: linhas finas e, na página da esquerda, a margem vermelha.
class Pautas extends Control:
	var esquerda := true

	func _draw() -> void:
		var y := 52.0
		while y < size.y - 10.0:
			draw_line(Vector2(10, y), Vector2(size.x - 10, y), Color(0.42, 0.5, 0.6, 0.13), 1.0)
			y += 19.0
		if esquerda:
			draw_line(Vector2(20, 6), Vector2(20, size.y - 6), Color(0.7, 0.2, 0.16, 0.22), 1.0)
		else:
			draw_line(Vector2(size.x - 20, 6), Vector2(size.x - 20, size.y - 6), Color(0.7, 0.2, 0.16, 0.22), 1.0)


func _pautas(pagina: Control, esquerda: bool) -> void:
	var p := Pautas.new()
	p.esquerda = esquerda
	p.size = pagina.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pagina.add_child(p)


# Manchas e rabiscos soltos nas margens, num arranjo que muda de um lugar para outro.
func _enfeites(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + n * 31
	var pequenos := ["estrela", "espiral", "olho", "x", "seta"]
	for i in 2:
		var t: Texture2D = load(RABISCOS % pequenos[(n + i * 2) % pequenos.size()])
		var r := _esboco("", Vector2(17, 17), rng.randf_range(-25, 25))
		r.texture = t
		r.modulate.a = 0.75
		r.position = Vector2(1, 90 + i * 170 + rng.randf_range(0, 60))
		_esq.add_child(r)
	var t2: Texture2D = load(RABISCOS % pequenos[(n + 1) % pequenos.size()])
	var r2 := _esboco("", Vector2(17, 17), rng.randf_range(-25, 25))
	r2.texture = t2
	r2.modulate.a = 0.75
	r2.position = Vector2(_dir.size.x - 19, 120 + rng.randf_range(0, 160))
	_dir.add_child(r2)
	_mancha(_esq, CAFE, Vector2(_esq.size.x - 150 - rng.randf_range(0, 60), _esq.size.y - 140), 120, rng.randf_range(0, 90), 0.45)
	_mancha(_dir, SANGUE, Vector2(_dir.size.x - 92, _dir.size.y - 96 - rng.randf_range(0, 200)), 70, rng.randf_range(0, 90), 0.35)


# Anotação solta: rabisco + frase curta em vermelho ou a lápis, meio torta.
func _nota(nota: Dictionary, k: int) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := _esboco(RABISCOS % str(nota.get("rabisco", "seta")), Vector2(22, 22), -8.0 + k * 9.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var t := str(nota["t"])
	var l := _linha(("[color=#8e1b12]%s[/color]" % t) if k % 2 == 0 else t, 14, false, 40 + k)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.rotation = deg_to_rad(-1.5 if k % 2 == 0 else 1.2)
	hb.add_child(l)
	return hb


func _bloco_desenho(d: Dictionary, n: int, texto: String, tam: int, semente: int) -> Array[Control]:
	var cam := DiarioMiguel.caminho(str(d["desenho"]))
	var leg := str(d["legenda"])
	var tex: Texture2D = load(cam) if cam != "" else null
	var asp := float(tex.get_height()) / tex.get_width() if tex != null else 0.6
	var frase := _linha(texto, tam, false, semente)
	if n % 3 != 1:  # 1º e 3º ao lado de uma frase (direita, depois esquerda), o 2º no meio do texto
		var dir := n % 3 == 0
		var larg := 112.0
		var fig := _figura(cam, Vector2(larg, minf(larg * asp, 112.0)), leg, 4.0 if dir else -4.0, n == 0)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if dir:
			hb.add_child(frase)
			hb.add_child(fig)
		else:
			hb.add_child(fig)
			hb.add_child(frase)
		return [hb]
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h2 := minf(200.0 * asp, 116.0)
	cc.add_child(_figura(cam, Vector2(h2 / asp, h2), leg, -2.0, false, 190.0))
	return [frase, cc]


# Desenho com a legenda embaixo e, às vezes, um pedaço de fita prendendo no papel.
func _figura(cam: String, tam: Vector2, leg: String, graus: float, fita := false, leg_min := 118.0) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_esboco(cam, tam, 0.0))
	var l := _rotulo(leg, 12, VERMELHO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var larg_leg := maxf(tam.x, leg_min)
	l.custom_minimum_size.x = larg_leg
	v.add_child(l)
	var c := Control.new()  # a rotação fica no filho; o container só vê o tamanho
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(larg_leg + 8, tam.y + 22)
	c.add_child(v)
	v.pivot_offset = c.custom_minimum_size / 2.0
	v.rotation = deg_to_rad(graus)
	if fita:
		for lado in [-1, 1]:
			var f := ColorRect.new()  # fita adesiva amarelada nos cantos de cima
			f.color = Color(0.88, 0.82, 0.62, 0.6)
			f.size = Vector2(30, 9)
			f.pivot_offset = f.size / 2.0
			f.position = Vector2(c.custom_minimum_size.x / 2.0 + lado * tam.x * 0.42 - 15, -2)
			f.rotation = deg_to_rad(lado * 32.0)
			f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.add_child(f)
	return c


# --- PISTAS ----------------------------------------------------------------------------------------------

# Pistas e conclusões (as descobertas sobre inimigos ficam na aba CRIATURAS).
func _itens() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in Diario.recentes():
		if str(e["lugar"]) != Fraquezas.LUGAR:
			out.append(e)
	return out


func _atualizar_pistas() -> void:
	for f in _lista.get_children():
		_lista.remove_child(f)
		f.queue_free()
	var itens := _itens()
	sel = clampi(sel, 0, maxi(itens.size() - 1, 0))
	_contagem.text = "%d %s" % [itens.size(), "anotada" if itens.size() == 1 else "anotadas"]
	_vazio.visible = itens.is_empty()
	for i in itens.size():
		_lista.add_child(_botao(i, itens[i]))
	var tem := not itens.is_empty()
	_titulo_det.visible = tem
	_lugar_det.visible = tem
	_texto.visible = tem
	_imagem.visible = false
	if tem:
		var e: Dictionary = itens[sel]
		_titulo_det.text = e["titulo"]
		_lugar_det.text = str(e["lugar"]).to_lower()
		_texto.text = e["texto"]
		var esb := DiarioMiguel.desenho_pista(str(e["id"]))
		var ins := str(e["imagem"])
		_imagem.custom_minimum_size = Vector2(250, 120)
		if ins != "" and ResourceLoader.exists(ins):  # a imagem da própria pista (ficha, página) vale mais que o esboço do lugar
			_imagem.texture = load(ins)
			_imagem.custom_minimum_size = Vector2(250, 200)
			_imagem.visible = true
		elif esb != "":
			_imagem.texture = load(esb)
			_imagem.visible = true
	var obj := Diario.objetivo_atual(room._objectives()) if room != null else ""
	_obj.text = "PRÓXIMO OBJETIVO: " + obj if obj != "" else "Sem objetivo no momento."
	_mancha(_dir, SANGUE, Vector2(_dir.size.x - 88, 8), 60, 70.0, 0.45)


func _botao(i: int, e: Dictionary) -> Button:
	var b := Button.new()
	b.text = "✓  %s" % e["titulo"]
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var aberta: bool = i == sel
	b.add_theme_font_override("font", _negrito if aberta else MAO)
	b.add_theme_font_size_override("font_size", 16)
	for n in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(n, VERMELHO if aberta else TINTA)
	b.add_theme_constant_override("h_separation", 0)
	var vazio := StyleBoxEmpty.new()
	for n in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(n, vazio)
	b.rotation = deg_to_rad(float(hash(str(e["id"])) % 13 - 6) / 10.0)
	b.pressed.connect(_escolher.bind(i))
	return b


func _escolher(i: int) -> void:
	sel = i
	atualizar()


# Teclas de cima e de baixo: movem o cursor da lista.
func _cursor(i: int) -> void:
	sel = clampi(i, 0, maxi(_itens().size() - 1, 0))
	atualizar()


func _posicao(id: String) -> int:
	var itens := _itens()
	for k in itens.size():
		if itens[k]["id"] == id:
			return k
	return 0


func _titulo_de(id: String) -> String:
	for e in Missao1.diario:
		if e["id"] == id:
			return str(e["titulo"])
	return id


# --- CRIATURAS -------------------------------------------------------------------------------------------

func _atualizar_criaturas() -> void:
	var gd: GameData = room.rules.cfg.game_data if room != null and "rules" in room else null
	var cs := Fraquezas.criaturas(gd)
	var esq := _coluna(_esq)
	var dir := _coluna(_dir)
	if cs.is_empty():
		esq.add_child(_titulo("Criaturas"))
		esq.add_child(_linha("Nada anotado ainda. [s]Tomara[/s] Tomara que continue assim.", 15, true))
		return
	sel_criatura = clampi(sel_criatura, 0, cs.size() - 1)
	var c: Dictionary = cs[sel_criatura]
	var retrato := "res://assets/sprites/retratos/%s_128.png" % c["retrato"] if str(c["retrato"]) != "" else ""
	esq.add_child(_titulo(str(c["nome"])))
	var sub := _rotulo("anotado por Miguel", 12, APAGADO)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esq.add_child(sub)
	var esb := DiarioMiguel.desenho_criatura(str(c["kind"]))
	if esb != "":
		var img := _esboco(esb, Vector2(250, 190), -2.0)
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		esq.add_child(img)
	elif retrato != "":
		var f := _foto(retrato, 120, str(c["nome"]).to_lower(), -3.0)
		f.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		esq.add_child(f)
	var vao := Control.new()
	vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	esq.add_child(vao)
	# As outras criaturas anotadas, como fotos pequenas que se clicam.
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	for i in cs.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = ("» " if i == sel_criatura else "") + str(cs[i]["nome"]).split(" ")[0].to_lower()
		b.add_theme_font_override("font", _negrito if i == sel_criatura else MAO)
		b.add_theme_font_size_override("font_size", 15)
		for n in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(n, VERMELHO if i == sel_criatura else TINTA)
		var vazio := StyleBoxEmpty.new()
		for n in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(n, vazio)
		b.pressed.connect(func() -> void:
			sel_criatura = i
			atualizar())
		fila.add_child(b)
	esq.add_child(fila)

	dir.add_child(_titulo("O que eu sei", 22))
	for a in c["afinidades"]:
		if a["conhecida"]:
			var como := "fraqueza" if a["afinidade"] == "fraqueza" else "resiste"
			dir.add_child(_linha("[color=#8e1b12]✓[/color] [b]%s: %s[/b]" % [como, a["nome_tipo"]], 16, true))
			dir.add_child(_linha(str(a["miguel"]), 14, true))
		else:
			dir.add_child(_linha("? ........ [s]será que[/s] ainda não sei", 15, true))
	var h := _titulo("primeira impressão", 17)
	dir.add_child(h)
	dir.add_child(_linha(str(c["nota"]), 14, true))
	if esb != "" and retrato != "":
		var vao2 := Control.new()
		vao2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dir.add_child(vao2)
		var f := _foto(retrato, 64, "", 4.0)
		f.size_flags_horizontal = Control.SIZE_SHRINK_END
		dir.add_child(f)
	_mancha(_esq, CAFE, Vector2(-30, _esq.size.y - 130), 120, 0.0, 0.6)


# --- Teclado ---------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_J:
		alternar()
		get_viewport().set_input_as_handled()
	elif open:
		var k: int = event.keycode
		if k == KEY_ESCAPE:
			fechar()
		elif k == KEY_TAB:
			var ordem := ["diario", "pistas", "criaturas"]
			trocar_secao(ordem[(ordem.find(secao) + (2 if event.shift_pressed else 1)) % 3])
		elif secao == "diario" and k in [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
			sel_pagina += -1 if k in [KEY_UP, KEY_LEFT] else 1
			atualizar()
		elif secao == "criaturas" and k in [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
			sel_criatura += -1 if k in [KEY_UP, KEY_LEFT] else 1
			atualizar()
		elif secao == "pistas":
			if k == KEY_UP:
				_cursor(sel - 1)
			elif k == KEY_DOWN:
				_cursor(sel + 1)
		get_viewport().set_input_as_handled()  # com o diário aberto o mundo não recebe nada
