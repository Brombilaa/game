class_name DiarioCriaturas
extends RefCounted
# Página de uma criatura na seção CRIATURAS do diário, escrita como o caderno do Miguel (Léo, 19/11/2026).
# Três modelos para o Léo escolher (regra dos 3 modelos): "A" folha de caderno, "B" ficha do ocultista,
# "C" página manchada. Os dados vêm de Fraquezas.criaturas(); aqui só se monta a tela.

const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const GOLD := Color(0.839, 0.678, 0.361)
const TEXT := Color(0.91, 0.87, 0.79)
const MUTED := Color(0.66, 0.6, 0.49)
const CRIMSON := Color(0.62, 0.09, 0.11)
const PAPEL := Color(0.86, 0.8, 0.66)
const TINTA := Color(0.16, 0.12, 0.1)
const TINTA_VERMELHA := Color(0.55, 0.07, 0.07)
const TINTA_AZUL := Color(0.18, 0.24, 0.36)


static func pagina(modelo: String, c: Dictionary) -> Control:
	match modelo:
		"B":
			return _ficha(c)
		"C":
			return _manchada(c)
	return _caderno(c)


static func _rotulo(texto: String, tamanho: int, cor: Color, quebra := true) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _retrato(c: Dictionary, lado: float) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(lado, lado)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/sprites/retratos/%s_128.png" % c["retrato"]
	if str(c["retrato"]) != "" and ResourceLoader.exists(path):
		t.texture = load(path)
	return t


static func _caixa(fundo: Color, borda: Color, largura := 0, margem := 10) -> PanelContainer:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = fundo
	e.set_border_width_all(largura)
	e.border_color = borda
	e.set_content_margin_all(margem)
	p.add_theme_stylebox_override("panel", e)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func _como(a: Dictionary) -> String:
	return ("Fraqueza: " if a["afinidade"] == "fraqueza" else "Resistência: ") + str(a["nome_tipo"])


# --- A: folha de caderno -----------------------------------------------------------------------------
# Papel claro pautado, tinta escura, retrato colado torto no canto, e cada descoberta riscada à mão.

class Pauta extends Control:
	func _draw() -> void:
		for y in range(46, int(size.y), 19):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.45, 0.55, 0.7, 0.22), 1.0)
		draw_line(Vector2(26, 0), Vector2(26, size.y), Color(0.7, 0.2, 0.2, 0.35), 1.0)


static func _caderno(c: Dictionary) -> Control:
	var folha := _caixa(PAPEL, Color(0.5, 0.42, 0.3), 1, 0)
	var pauta := Pauta.new()
	pauta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	folha.add_child(pauta)
	var m := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lado, 10)
	m.add_theme_constant_override("margin_left", 34)
	folha.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	m.add_child(col)
	var topo := HBoxContainer.new()
	var nomes := VBoxContainer.new()
	nomes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nomes.add_child(_rotulo(str(c["nome"]), 18, TINTA_VERMELHA, false))
	nomes.add_child(_rotulo("caderno do Miguel", 10, Color(0.35, 0.3, 0.25), false))
	var nota := _rotulo(str(c["nota"]), 12, TINTA)
	nomes.add_child(nota)
	topo.add_child(nomes)
	var foto := Control.new()
	foto.custom_minimum_size = Vector2(80, 84)
	var moldura := _caixa(Color(0.95, 0.93, 0.88), Color(0.95, 0.93, 0.88), 0, 3)
	moldura.position = Vector2(4, 4)
	moldura.rotation = deg_to_rad(4.0)
	moldura.add_child(_retrato(c, 68))
	foto.add_child(moldura)
	var fita := ColorRect.new()
	fita.color = Color(0.9, 0.85, 0.6, 0.75)
	fita.size = Vector2(34, 10)
	fita.position = Vector2(24, -2)
	fita.rotation = deg_to_rad(-6.0)
	foto.add_child(fita)
	topo.add_child(foto)
	col.add_child(topo)
	col.add_child(_rotulo("O que eu sei:", 12, TINTA, false))
	for a in c["afinidades"]:
		if a["conhecida"]:
			var cor := TINTA_VERMELHA if a["afinidade"] == "fraqueza" else TINTA_AZUL
			col.add_child(_rotulo("✓ " + _como(a) + ". " + str(a["miguel"]), 11, cor))
		else:
			col.add_child(_rotulo("? ........ ainda não sei.", 11, Color(0.4, 0.35, 0.3), false))
	return folha


# --- B: ficha do ocultista ---------------------------------------------------------------------------
# Fundo escuro do diário, retrato com borda carmim, selos FRACO e RESISTE, a nota do Miguel assinada embaixo.

static func _selo(texto: String, fundo: Color, cor: Color) -> PanelContainer:
	var p := _caixa(fundo, cor, 1, 4)
	p.add_child(_rotulo(texto, 11, cor, false))
	return p


static func _ficha(c: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	var foto := _caixa(Color(0.08, 0.04, 0.04), CRIMSON, 2, 2)
	foto.add_child(_retrato(c, 84))
	topo.add_child(foto)
	var lado := VBoxContainer.new()
	lado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lado.add_theme_constant_override("separation", 5)
	lado.add_child(_rotulo(str(c["nome"]).to_upper(), 17, GOLD, false))
	lado.add_child(_rotulo("FICHA DO OCULTISTA · MIGUEL", 10, MUTED, false))
	var selos := HFlowContainer.new()
	selos.add_theme_constant_override("h_separation", 5)
	selos.add_theme_constant_override("v_separation", 5)
	for a in c["afinidades"]:
		if not a["conhecida"]:
			selos.add_child(_selo("???", Color(0.1, 0.08, 0.07), Color(0.4, 0.36, 0.3)))
		elif a["afinidade"] == "fraqueza":
			selos.add_child(_selo("FRAQUEZA: " + str(a["nome_tipo"]).to_upper(), Color(0.25, 0.04, 0.05), Color(1.0, 0.55, 0.5)))
		else:
			selos.add_child(_selo("RESISTÊNCIA: " + str(a["nome_tipo"]).to_upper(), Color(0.1, 0.12, 0.15), Color(0.68, 0.76, 0.86)))
	lado.add_child(selos)
	topo.add_child(lado)
	col.add_child(topo)
	col.add_child(_rotulo("\"" + str(c["nota"]) + "\"", 12, TEXT))
	for a in c["afinidades"]:
		if a["conhecida"] and str(a["miguel"]) != "":
			col.add_child(_rotulo("· " + str(a["miguel"]), 11, MUTED))
	var assinatura := _rotulo("— M.", 12, GOLD, false)
	assinatura.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(assinatura)
	return col


# --- C: página manchada ------------------------------------------------------------------------------
# Pergaminho escuro com mancha de sangue, retrato em sépia, e o que falta descobrir riscado.

class Mancha extends Control:
	func _draw() -> void:
		var base := Vector2(size.x - 40, 26)
		draw_circle(base, 22, Color(0.45, 0.04, 0.05, 0.55))
		draw_circle(base + Vector2(-20, 14), 9, Color(0.45, 0.04, 0.05, 0.5))
		draw_circle(base + Vector2(12, 24), 6, Color(0.45, 0.04, 0.05, 0.45))
		draw_circle(base + Vector2(-34, -2), 4, Color(0.45, 0.04, 0.05, 0.4))
		draw_circle(Vector2(18, size.y - 18), 12, Color(0.3, 0.2, 0.12, 0.35))


static func _manchada(c: Dictionary) -> Control:
	var folha := _caixa(Color(0.2, 0.15, 0.1), Color(0.33, 0.24, 0.15), 1, 0)
	var mancha := Mancha.new()
	mancha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	folha.add_child(mancha)
	var m := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lado, 12)
	folha.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	m.add_child(col)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 10)
	var foto := _retrato(c, 78)
	foto.modulate = Color(1.0, 0.86, 0.66)  # sépia
	var moldura := _caixa(Color(0.1, 0.07, 0.05), Color(0.55, 0.45, 0.3), 1, 3)
	moldura.add_child(foto)
	topo.add_child(moldura)
	var lado := VBoxContainer.new()
	lado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lado.add_child(_rotulo(str(c["nome"]), 18, Color(0.93, 0.85, 0.7), false))
	lado.add_child(_rotulo("anotado por Miguel", 10, Color(0.6, 0.5, 0.38), false))
	lado.add_child(_rotulo(str(c["nota"]), 12, Color(0.86, 0.79, 0.66)))
	topo.add_child(lado)
	col.add_child(topo)
	for a in c["afinidades"]:
		if a["conhecida"]:
			var cor := Color(0.95, 0.45, 0.4) if a["afinidade"] == "fraqueza" else Color(0.7, 0.75, 0.8)
			col.add_child(_rotulo("» " + _como(a).to_upper(), 12, cor, false))
			col.add_child(_rotulo(str(a["miguel"]), 11, Color(0.82, 0.75, 0.62)))
		else:
			col.add_child(_rotulo("» ~~~~~~~~~~  (falta descobrir)", 12, Color(0.5, 0.42, 0.32), false))
	return folha
