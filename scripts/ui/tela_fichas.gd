class_name TelaFichas
extends Control
# Tela das fichas (modelo B "Ficha com a corrente"): antes da campanha o jogador reparte 4 pontos de
# atributo para cada agente (GDD #11). Fundo do menu (MenuFundoArvore), retratos em cartões Preto liso
# ligados pela corrente, à esquerda; à direita a ficha do agente escolhido, com os cinco atributos, o PV e
# a SAN calculados (Ficha) e a explicação do atributo sob o mouse. Começar só libera com os pontos gastos.
# Teclas: Esc volta ao menu; Tab troca de agente; Enter começa (se pronto).

const AGENTES := ["fernando", "nikolai", "miguel"]
const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const CENA_MENU := "res://scenes/menu/main_menu.tscn"

const INK := Color("ece3d2")
const MUTED := Color("a99d8b")
const GOLD := Color("d8b86a")
const BLOOD := Color("b3362b")
const PV_COLOR := Color("c4473c")
const SAN_COLOR := Color("4c7fc9")
const DISABLED := Color(0.42, 0.38, 0.35)
const PANEL := Color(0.07, 0.055, 0.05, 0.72)
const BAR_MAX := 26.0  # PV/SAN que enchem a barra (o maior valor possível no início é 23 PV / 24 SAN)

const NOMES := {"VIG": "Vigor", "FOR": "Força", "INT": "Intelecto", "AGI": "Agilidade", "PRE": "Presença"}
const EFEITOS := {
	"VIG": "Soma no PV máximo, agora e a cada nível.",
	"FOR": "+1 de dano por ponto acima de 1 no corpo a corpo e na escopeta.",
	"INT": "+1 no dano e na cura dos rituais por ponto acima de 1.",
	"AGI": "Quem tem mais age primeiro no combate. +2% de acerto por ponto acima de 1.",
	"PRE": "+2 de SAN por ponto acima de 1. Ajuda a resistir aos sustos.",
}

var data: GameData
var fichas := {}  # id do agente -> {atributo: valor}
var atual := "fernando"
var foco := "VIG"  # atributo explicado embaixo (o último sob o mouse)
var saindo := false
var background: Control
var _retratos := {}
var _hits: Array = []  # [Rect2, ação, argumento] montados a cada desenho


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	data = CombatConfig.load_file().game_data
	for id in AGENTES:
		fichas[id] = Ficha.atributos_de(data, id)
		var path := "res://assets/sprites/retratos/%s_128.png" % id
		if ResourceLoader.exists(path):
			_retratos[id] = load(path)
	background = MenuFundoArvore.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	add_child(background)


# --- Regras da tela (testáveis sem mouse) ------------------------------------------------

func ajustar(id: String, atributo: String, delta: int) -> bool:
	var ok := Ficha.ajustar(data, fichas[id], atributo, delta)
	if ok:
		queue_redraw()
	return ok


func restantes(id: String) -> int:
	return Ficha.pontos_restantes(data, fichas[id])


func pronto() -> bool:
	return AGENTES.all(func(id: String) -> bool: return Ficha.validar(data, fichas[id]) == "")


func sugestao() -> void:
	for id in AGENTES:
		fichas[id] = Ficha.sugeridos(data, id)
	queue_redraw()


func zerar() -> void:
	for id in AGENTES:
		fichas[id] = Ficha.em_branco(data)
	queue_redraw()


func trocar(delta: int) -> void:
	atual = AGENTES[(AGENTES.find(atual) + delta + AGENTES.size()) % AGENTES.size()]
	queue_redraw()


# Grava as escolhas e começa a missão pela introdução (que leva ao bar e depois ao parque). false se faltar ponto ou a troca já estiver em curso.
func comecar() -> bool:
	if saindo or not pronto():
		return false
	Ficha.escolhas = fichas.duplicate(true)
	saindo = true
	if not Scenes.go(get_tree(), Missao1.CENA_INTRO):
		saindo = false
		return false
	return true


func voltar() -> void:
	if not saindo:
		saindo = Scenes.go(get_tree(), CENA_MENU)


# --- Entrada ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for h in _hits:
			if h[1] == "foco" and (h[0] as Rect2).has_point(event.position) and foco != h[2]:
				foco = h[2]
				queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for h in _hits:
			if h[1] != "foco" and (h[0] as Rect2).has_point(event.position):
				_acao(h[1], h[2])
				accept_event()
				return


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			voltar()
		KEY_TAB:
			trocar(-1 if event.shift_pressed else 1)
		KEY_ENTER, KEY_KP_ENTER:
			comecar()


func _acao(acao: String, arg: Variant) -> void:
	match acao:
		"agente":
			atual = arg
			queue_redraw()
		"mais":
			ajustar(atual, arg, 1)
		"menos":
			ajustar(atual, arg, -1)
		"sugestao":
			sugestao()
		"zerar":
			zerar()
		"comecar":
			comecar()
		"voltar":
			voltar()


# --- Desenho (960×540) ---------------------------------------------------------------------

func _draw() -> void:
	_hits.clear()
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))  # escurece o fundo atrás da ficha
	_spaced(Vector2(38, 52), "FICHAS DOS AGENTES", 25, INK, 6.0)
	_spaced(Vector2(38, 72), "REPARTA 4 PONTOS EM CADA UM", 9, MUTED, 2.0)
	_draw_cards()
	_draw_sheet(Rect2(154, 91, w - 154 - 38, h - 91 - 72))
	_draw_footer(w, h)


func _draw_cards() -> void:
	var y := 91.0
	for i in AGENTES.size():
		var id: String = AGENTES[i]
		var r := Rect2(38, y, 86, 108)
		if i > 0:  # corrente entre os cartões
			for k in 4:
				draw_circle(Vector2(r.get_center().x, y - 11 + k * 3.0), 0.9, Color(0.55, 0.52, 0.48))
		draw_rect(r, Color("0d0b0b"))
		draw_rect(r.grow(1), Color(1, 1, 1, 0.12), false, 1.0)
		if id == atual:
			draw_rect(r.grow(1.5), Color.WHITE, false, 1.5)
		var foto := Rect2(r.position + Vector2(4, 4), Vector2(78, 78))
		if _retratos.has(id):
			draw_texture_rect(_retratos[id], foto, false)
		var nome := str(data.get_entry("personagens", id).get("nome", id)).to_upper()
		draw_string(FONT, Vector2(r.position.x + 4, r.end.y - 9), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
		var resto := restantes(id)
		draw_string(FONT, Vector2(r.position.x + 4, r.end.y - 9), str(resto) if resto != 0 else "ok", HORIZONTAL_ALIGNMENT_RIGHT, 78, 9, GOLD if resto == 0 else BLOOD)
		_hits.append([r, "agente", id])
		y += r.size.y + 22


func _draw_sheet(box: Rect2) -> void:
	draw_rect(box, PANEL)
	draw_rect(box, Color(0, 0, 0, 1), false, 1.0)
	draw_rect(box.grow(1), Color(1, 1, 1, 0.08), false, 1.0)
	var a: Dictionary = fichas[atual]
	var p := data.get_entry("personagens", atual)
	var classe := Ficha.classe_de(data, atual)
	var x := box.position.x + 26
	var y := box.position.y + 40
	_spaced(Vector2(x, y), str(p.get("nome", atual)).to_upper(), 21, INK, 3.0)
	var arma := "%s e %s" % [_arma(p.get("arma_inicial")), _arma(p.get("arma_secundaria")).to_lower()]
	_spaced(Vector2(x, y + 20), "%s · %s" % [str(data.get_entry("classes", classe).get("nome", classe)).to_upper(), arma.to_upper()], 9, MUTED, 1.5)
	var col_w := (box.size.x - 52) * 0.55
	var ry := y + 38
	for k in Ficha.ATRIBUTOS:
		var row := Rect2(x, ry, col_w, 48)
		_hits.append([row, "foco", k])
		draw_string(FONT, Vector2(x, ry + 20), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
		draw_string(FONT, Vector2(x, ry + 33), NOMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MUTED)
		for s in 3:  # segmentos: o 1 de base em tinta, os pontos gastos em sangue
			var seg := Rect2(x + 104 + s * 34, ry + 14, 31, 10)
			var cor := INK if s == 0 else (BLOOD if s < int(a[k]) else Color(1, 1, 1, 0.1))
			draw_rect(seg, cor)
		var bx := x + col_w - 62
		_button(Rect2(bx, ry + 9, 18, 18), "−", int(a[k]) > Ficha._inicial(data), "menos", k)
		draw_string(FONT, Vector2(bx + 18, ry + 24), str(a[k]), HORIZONTAL_ALIGNMENT_CENTER, 22, 14, INK)
		_button(Rect2(bx + 40, ry + 9, 18, 18), "+", int(a[k]) < int(Ficha._regra(data, "atributo_max_inicial", 3)) and restantes(atual) > 0, "mais", k)
		draw_line(Vector2(x, ry + 48), Vector2(x + col_w, ry + 48), Color(1, 1, 1, 0.07))
		ry += 50
	# Coluna da direita: pontos, PV, SAN, bônus e a explicação do atributo.
	var sx := x + col_w + 24
	var sw := box.end.x - 26 - sx
	var sy := y - 4
	draw_string(FONT, Vector2(sx, sy), "Pontos para repartir", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
	draw_string(FONT, Vector2(sx + 128, sy + 1), str(restantes(atual)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, BLOOD)
	var pv := Ficha.pv_max(data, classe, a)
	var san := Ficha.san_max(data, classe, a)
	sy += 30
	sy = _stat_bar(sx, sy, sw, "PV", pv, PV_COLOR)
	sy = _stat_bar(sx, sy, sw, "SAN", san, SAN_COLOR)
	var acerto := int(round((int(a["AGI"]) - 1) * 100.0 * 0.02))
	for linha in [["INICIATIVA", str(a["AGI"])], ["ACERTO EXTRA", "+%d%%" % acerto], ["DANO EXTRA (FOR)", "+%d" % Ficha.bonus_dano(data, a, {"melee": true})], ["RITUAL (INT)", "+%d" % Ficha.bonus_ritual(data, a)]]:
		_spaced(Vector2(sx, sy), linha[0], 8, MUTED, 1.2)
		draw_string(FONT, Vector2(sx, sy), linha[1], HORIZONTAL_ALIGNMENT_RIGHT, sw, 11, INK)
		sy += 26
	var help_y := box.end.y - 62
	draw_line(Vector2(sx, help_y), Vector2(sx + sw, help_y), Color(1, 1, 1, 0.08))
	draw_string(FONT, Vector2(sx, help_y + 20), NOMES[foco] + ".", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
	draw_multiline_string(FONT, Vector2(sx, help_y + 34), EFEITOS[foco], HORIZONTAL_ALIGNMENT_LEFT, sw, 9, 3, Color("cfc4b2"))


func _stat_bar(x: float, y: float, w: float, nome: String, valor: int, cor: Color) -> float:
	_spaced(Vector2(x, y), nome, 8, MUTED, 1.2)
	draw_string(FONT, Vector2(x, y), str(valor), HORIZONTAL_ALIGNMENT_RIGHT, w, 11, INK)
	draw_rect(Rect2(x, y + 6, w, 7), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(x, y + 6, w * clampf(valor / BAR_MAX, 0.0, 1.0), 7), cor)
	return y + 36


func _draw_footer(w: float, h: float) -> void:
	var faltam := AGENTES.filter(func(id: String) -> bool: return restantes(id) != 0).size()
	var txt := "Fichas prontas" if faltam == 0 else "Faltam pontos em %d agente%s" % [faltam, "s" if faltam > 1 else ""]
	draw_string(FONT, Vector2(38, h - 31), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
	var bx := 38.0 + FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12
	_button(Rect2(bx, h - 44, 58, 18), "sugestão", true, "sugestao", null)
	_button(Rect2(bx + 64, h - 44, 44, 18), "zerar", true, "zerar", null)
	_button(Rect2(bx + 114, h - 44, 50, 18), "voltar", true, "voltar", null)
	var go := "Começar a investigação"
	var gw := FONT.get_string_size(go, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var gx := w - 38 - gw
	var ok := pronto()
	draw_string(FONT, Vector2(gx - 20, h - 30), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, BLOOD if ok else Color("5a3a35"))
	draw_string(FONT, Vector2(gx, h - 30), go, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK if ok else DISABLED)
	if ok:
		_hits.append([Rect2(gx - 22, h - 48, gw + 24, 26), "comecar", null])


func _button(r: Rect2, texto: String, ativo: bool, acao: String, arg: Variant) -> void:
	var borda := Color("6d5f55") if ativo else Color(0.43, 0.37, 0.33, 0.3)
	draw_rect(r, Color(0, 0, 0, 0.35))
	draw_rect(r, borda, false, 1.0)
	draw_string(FONT, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 4), texto, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10 if texto.length() > 1 else 13, INK if ativo else Color(INK, 0.28))
	if ativo:
		_hits.append([r, acao, arg])


func _spaced(at: Vector2, texto: String, tamanho: int, cor: Color, espaco: float) -> void:
	var x := at.x
	for c in texto:
		draw_string(FONT, Vector2(x, at.y), c, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
		x += FONT.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + espaco


func _arma(id: Variant) -> String:
	if id == null:
		return "—"
	return str(data.get_entry("armas", str(id)).get("nome", id))
