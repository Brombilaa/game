class_name InventoryPanel
extends Node2D
# Inventário no vidro fosco (Léo, 19/11/2026, modelo N2 "cartões de item"): abre com a tecla B (ou fecha com B,
# Esc e o X); o cenário escurece um pouco e fica desfocado atrás da placa (o desfoque vem de HudBlur, que lê
# `panel_rect()` por `room._hud_blur_rects()`). À esquerda os três cartões do grupo e os 4 espaços de
# equipamento do personagem escolhido; no meio a mochila compartilhada (20 espaços) como cartões de item, só os
# espaços ocupados, com a roda do mouse para rolar; à direita o detalhe do item escolhido, com os botões Equipar e
# Descartar. Os 20 espaços aparecem como uma barra de marcas. Só desenha e lê o mouse e o teclado; as regras de
# equipar, usar e descartar ficam em `room` (gear_equip, gear_unequip, gear_use e gear_discard) e a mochila em
# `room.inventory`. O tempo para com o inventário aberto (GDD #23).

const PW := 790.0
const PH := 492.0
const PANEL_POS := Vector2(150, 24)
const OPEN_SECONDS := 0.2
const DIM := 0.3
const ROW_H := 50.0
const ROW_STEP := 56.0
const VISIBLE_ROWS := 6
const COL_X := [190.0, 390.0]
const CARD_W := 190.0
const CARD_H := 66.0
const CARD_STEP := 75.0
const SLOT := 65.0
const PLATE := Color(0.04, 0.035, 0.03, 0.62)
const SLOT_FILL := Color(0, 0, 0, 0.42)
const HAIR := Color(1, 1, 1, 0.2)
const MUTED := Color(0.66, 0.6, 0.49)
const TEXT := Color(0.91, 0.87, 0.79)
const WHITE_SOFT := Color(0.85, 0.81, 0.74)
const BAR_PV := Color(0.82, 0.23, 0.27)
const BAR_SAN := Color(0.31, 0.56, 0.88)

# Armas que o jogo trata como de curta distância (pedido do Léo, 30/10/2026): mostram só a faixa Curto.
const SHORT_RANGE := ["pistola"]

# Acessórios cujo bônus o jogo não anuncia: o item mostra só a descrição (matriz da missão 1, 20/11).
const HIDDEN_BONUS := ["pulseira_amizade"]

const TIPOS := {"missao": "Item de missão", "consumivel": "Consumível", "equipamento": "Equipamento", "componente": "Componente", "recurso": "Recurso"}

const TABS := ["Tudo", "Armas", "Itens", "Coletes"]
const EQUIP_SLOTS := ["principal", "secundaria", "colete", "acessorio"]
const EQUIP_LABELS := {"principal": "ARMA", "secundaria": "RESERVA", "colete": "COLETE", "acessorio": "ACESSÓRIO"}
const GHOSTS := {"principal": "arma", "secundaria": "arma", "colete": "colete", "acessorio": "anel"}

# Textos provisórios dos itens (o GDD ainda não os define).
const BLURBS := {
	"pulseira_amizade": "Acessório: miçangas coloridas que amarram a mente ao que o Caio deixou.",
	"livro_sanguis_orchid": "Livro do culto Sanguis Orchid, de páginas rasgadas.",
	"fertilizante": "Saco de fertilizante tirado do celeiro.",
	"agrotoxico": "Veneno de lavoura guardado no celeiro.",
	"balde": "Balde do poço, serve para carregar água.",
	"garrafa_agua": "Garrafa de água da delegacia.",
	"coquetel": "Garrafa com pavio e líquido inflamável. Uso ainda a definir.",
	"plaqueta_identificacao": "Acessório: a plaqueta de um agente antigo lembra que dá para aguentar mais um pouco.",
	"pistola": "Arma curta de uso comum. Confiável à curta distância.",
	"escopeta": "Dano alto à queima-roupa, gasta 2 PA por disparo.",
	"espada": "Lâmina de corpo a corpo, forte nas mãos de quem aceita o risco.",
	"fuzil_precisao": "Tiro longo e preciso, sem penalidade de distância até 18 m.",
	"soco": "Sem arma: golpe de mão fechada.",
	"kit_primeiros_socorros": "Reanima um aliado caído, que volta com metade do PV.",
	"bandagem": "Estanca o sangramento de quem a usa.",
	"antidoto": "Neutraliza o veneno em quem o toma.",
	"curativo": "Cobre ferimentos leves.",
	"granada_luz": "Clarão que atordoa os inimigos perto do ponto onde cai. Só em combate.",
	"sinalizador": "Luz vermelha no chão por alguns turnos: o grupo acerta melhor quem está nela. Só em combate.",
	"componente_ritual": "Material usado nos rituais.",
	"sangue_coagulado": "Componente de Sangue. Tirado da Criatura de Sangue.",
	"prego_enferrujado": "Componente de Sangue: a ferrugem lembra o sangue.",
	"frasco_orgao": "Componente de Sangue.",
	"bateria": "Componente de Energia.",
	"maco_fios": "Componente de Energia.",
	"celular_quebrado": "Componente de Energia.",
	"ossos_pequenos": "Componente de Morte.",
	"cinzas": "Componente de Morte.",
	"relogio_quebrado": "Componente de Morte: o tempo parado.",
	"anel_ouro": "Componente de Conhecimento.",
	"tomo_antigo": "Componente de Conhecimento.",
	"colete": "Protege reduzindo o dano recebido.",
	"colete_leve": "Reduz o dano recebido em 10%.",
	"colete_pesado": "Reduz o dano recebido em 20%, mas deixa o personagem mais lento.",
}

var room: Node2D  # a sala: fornece grupo, mochila e as regras de equipar
var open := false
var t := 0.0  # 0 fechado, 1 aberto (animação)
var viewed := 0  # personagem cujo equipamento aparece
var tab := 0
var sel := {}  # {"kind": "bag", "i": n} ou {"kind": "eq", "slot": nome}
var toast := ""
var toast_time := 0.0
var scroll := 0  # primeira fileira de cartões visível
var _meta := {}  # id -> {nome, tipo}, cache dos textos fixos dos cartões


func toggle() -> void:
	if open:
		close()
	elif room.inventory_can_open():
		open = true
		viewed = maxi(room.party.find(room.player), 0)
		sel = {}
		toast = ""
		scroll = 0
		set_process(true)


func close() -> void:
	open = false
	room.queue_redraw()


func _process(delta: float) -> void:
	var goal := 1.0 if open else 0.0
	var before := t
	t = move_toward(t, goal, delta / OPEN_SECONDS)
	if t != before:
		room.queue_redraw()  # a sala não redesenha sozinha com o tempo parado: o radar e os objetivos somem/voltam
	toast_time = maxf(toast_time - delta, 0.0)
	modulate.a = _ease()
	queue_redraw()
	if t == 0.0 and not open:
		set_process(false)


func _ease() -> float:
	return 1.0 - pow(1.0 - t, 3.0)


# Posição da placa; ao abrir ela sobe de leve enquanto aparece.
func _origin() -> Vector2:
	return PANEL_POS + Vector2(0, (1.0 - _ease()) * 14.0)


# Placa em pixels da tela (vazia com o inventário fechado): HudBlur desfoca o mundo por trás dela.
func panel_rect() -> Rect2:
	if t <= 0.0:
		return Rect2()
	return Rect2(_origin(), Vector2(PW, PH))


# --- Áreas clicáveis (as mesmas do desenho) ---------------------------------

func _close_rect() -> Rect2:
	return Rect2(_origin() + Vector2(PW - 28, 8), Vector2(18, 18))


func _portrait_rect(i: int) -> Rect2:  # o cartão do personagem inteiro
	return Rect2(_origin() + Vector2(15, 21 + i * CARD_STEP), Vector2(150, CARD_H))


func _tab_rect(k: int) -> Rect2:
	return Rect2(_origin() + Vector2(350 + k * 58, 14), Vector2(54, 20))


func _equip_rect(k: int) -> Rect2:
	return Rect2(_origin() + Vector2(15 + (k % 2) * 75, 271 + (k / 2) * 90), Vector2(SLOT, SLOT))


# Espaços ocupados que passam pelo filtro da aba, na ordem da mochila.
func _visible_slots() -> Array[int]:
	var out: Array[int] = []
	for i in room.inventory.size:
		var s: Dictionary = room.inventory.slots[i]
		if not s.is_empty() and _tab_match(str(s["id"])):
			out.append(i)
	return out


func _max_scroll() -> int:
	return maxi(ceili(_visible_slots().size() / 2.0) - VISIBLE_ROWS, 0)


# Cartão da posição `n` da lista visível (já descontada a rolagem), ou vazio fora da janela.
func _row_rect(n: int) -> Rect2:
	var row := n / 2 - scroll
	if row < 0 or row >= VISIBLE_ROWS:
		return Rect2()
	return Rect2(_origin() + Vector2(COL_X[n % 2], 48 + row * ROW_STEP), Vector2(CARD_W, ROW_H))


func _detail_rect() -> Rect2:
	return Rect2(_origin() + Vector2(595, 48), Vector2(180, 340))


func _button_rect(k: int) -> Rect2:
	var d := _detail_rect()
	return Rect2(d.position + Vector2(12 + k * 80, d.size.y - 34), Vector2(74 if k == 0 else 82, 22))


func _member() -> Combatant:
	return room.party[viewed]


# --- Entrada ----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle()
			get_viewport().set_input_as_handled()
		elif open:
			if event.keycode == KEY_ESCAPE:
				close()
			elif event.keycode == KEY_E:
				_act()
			elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
				_discard()
			get_viewport().set_input_as_handled()  # com o inventário aberto o mundo não recebe nada
		return
	if not open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click(get_viewport().get_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = mini(scroll + 1, _max_scroll())
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = maxi(scroll - 1, 0)
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _click(p: Vector2) -> void:
	if _close_rect().has_point(p):
		close()
		return
	for i in room.party.size():
		if _portrait_rect(i).has_point(p):
			viewed = i
			sel = {}
			return
	for k in TABS.size():
		if _tab_rect(k).has_point(p):
			tab = k
			scroll = 0
			return
	var slots := _visible_slots()
	for n in slots.size():
		if _row_rect(n).has_point(p):
			var i := slots[n]
			# clicar de novo no item já escolhido equipa ou usa (atalho do E)
			var again: bool = sel.get("kind") == "bag" and sel.get("i") == i
			sel = {"kind": "bag", "i": i}
			if again:
				_act()
			return
	if _button_rect(0).has_point(p):
		_act()
		return
	if _button_rect(1).has_point(p):
		_discard()
		return
	for k in EQUIP_SLOTS.size():
		if _equip_rect(k).has_point(p):
			var slot: String = EQUIP_SLOTS[k]
			if sel.get("kind") == "bag":
				_say(room.gear_equip(_member(), slot, int(sel["i"])))
			elif sel.get("kind") == "eq" and sel.get("slot") != slot and slot in ["principal", "secundaria"] and sel.get("slot") in ["principal", "secundaria"]:
				_say(room.gear_swap_weapons(_member()))  # com uma arma escolhida, clicar na outra troca as duas
			sel = {"kind": "eq", "slot": slot}
			return


# E: equipa o item da mochila (arma principal, colete), usa um consumível ou, em um espaço
# de equipamento, guarda o item de volta na mochila.
func _act() -> void:
	if sel.get("kind") == "bag":
		var id := str(room.inventory.slots[int(sel["i"])]["id"])
		if _is_story(id):
			_say("Item de missão: sem uso por enquanto.")
		elif room.gear_is_equippable(id):
			var slot := "colete" if room.gear_item_kind(id) == "colete" else "principal"
			_say(room.gear_equip(_member(), slot, int(sel["i"])))
			sel = {"kind": "eq", "slot": slot}
		else:
			_say(room.gear_use(_member(), int(sel["i"])))
	elif sel.get("kind") == "eq":
		var slot := str(sel["slot"])
		var m := _member()
		var other := "secundaria" if slot == "principal" else "principal"
		if slot in ["principal", "secundaria"] and (room.gear_slot_id(m, other) != "" or slot == "secundaria"):
			_say(room.gear_swap_weapons(m))  # E numa arma equipada troca principal e secundária
			sel = {"kind": "eq", "slot": other}
		else:
			_say(room.gear_unequip(m, slot))
			sel = {}


func _discard() -> void:
	if sel.get("kind") == "bag":
		_say(room.gear_discard(int(sel["i"])))
		sel = {}


func _say(msg: String) -> void:
	if msg != "":
		toast = msg
		toast_time = 2.2


# --- Dados mostrados ----------------------------------------------------------

func _item_id(s: Dictionary) -> String:
	if s.get("kind") == "bag":
		var slot: Dictionary = room.inventory.slots[int(s["i"])]
		return "" if slot.is_empty() else str(slot["id"])
	if s.get("kind") == "eq":
		return room.gear_slot_id(_member(), str(s["slot"]))
	return ""


func _tab_match(id: String) -> bool:
	if tab == 0 or id == "":
		return true
	var kind: String = room.gear_item_kind(id)
	return (tab == 1 and kind == "arma") or (tab == 2 and kind == "item") or (tab == 3 and kind == "colete")


# {nome, tipo, texto, linhas: [[rótulo, valor]]} do item `id`.
func _describe(id: String) -> Dictionary:
	var data: GameData = room.cfg.game_data
	var w := data.get_entry("armas", id)
	if not w.is_empty():
		var dano = w.get("dano")
		var wp: Dictionary = room.cfg.weapon(id)
		var ppm: float = room.cfg.value("pixels_per_meter")
		var max_m := float(wp["max_range"]) / ppm
		var dist := "Corpo a corpo"
		if not wp["melee"]:
			dist = "Curta · até %d m" % roundi(max_m) if id in SHORT_RANGE else ("Média" if max_m <= 14.0 else "Longa") + " · até %d m" % roundi(max_m)
		var lines := [["Dano", "%d - %d" % [dano[0], dano[1]] if dano else "—"], ["Distância", dist], ["Custo", "%d PA" % int(wp["pa_cost"])]]
		var tipo := "Corpo a corpo" if w["tipo"] == "corpo_a_corpo" else "Arma de fogo"
		return {"nome": w["nome"], "tipo": tipo, "texto": BLURBS.get(id, ""), "linhas": lines, "faixas": _range_lines(wp, id in SHORT_RANGE)}
	var it := data.get_entry("itens", id)
	if it.is_empty():
		return {}
	var lines := []
	if it.get("custo_pa_combate") != null:
		lines.append(["Em combate", "%d PA" % int(it["custo_pa_combate"])])
	if it.get("efeito") == "defesa" and it.get("valor") != null:
		lines.append(["Defesa", "%d%%" % roundi(float(it["valor"]) * 100.0)])
	if it.get("efeito") == "san_max" and it.get("valor") != null and id not in HIDDEN_BONUS:
		lines.append(["SAN máxima", "+%d" % int(it["valor"])])
	if it.get("efeito") == "pv_max" and it.get("valor") != null:
		lines.append(["PV máximo", "+%d" % int(it["valor"])])
	if it.get("elemento") != null:
		lines.append(["Elemento", RitualRules.element_name(str(it["elemento"]))])
	return {"nome": it["nome"], "tipo": TIPOS.get(str(it["categoria"]), str(it["categoria"]).capitalize()), "texto": BLURBS.get(id, ""), "linhas": lines}


# Curto, médio e longo a partir da regra de acerto (−5% a cada 2 m além da distância ideal):
# curto = sem penalidade, médio = até −15%, longo = daí até o alcance máximo da arma.
# Os limites em metros são provisórios do Claude (o GDD só define a perda por distância).
func _range_lines(wp: Dictionary, short_only := false) -> Array:
	var ppm: float = room.cfg.value("pixels_per_meter")
	var max_m: float = float(wp["max_range"]) / ppm
	var free_m: float = float(wp["free_range"]) / ppm
	var base: float = float(wp["base_chance"])
	var lo: float = room.cfg.value("hit_chance_min")
	var step: float = room.cfg.value("range_falloff_per_2m")
	if wp["melee"]:
		return [["Curto", "até %d m · %d%%" % [roundi(max_m), roundi(base * 100.0)]]]
	var cuts := [minf(free_m + 2.0, max_m), minf(free_m + 8.0, max_m), max_m]
	if short_only:  # arma de curta distância: uma faixa só, do tiro à queima-roupa até onde ainda é confiável
		var edge: float = cuts[1]
		var far := clampf(base - floorf(maxf(edge - free_m, 0.0) / 2.0) * step, lo, 0.95)
		return [["Curto", "0–%d m · %d%%–%d%%" % [roundi(edge), roundi(base * 100.0), roundi(far * 100.0)]]]
	var names := ["Curto", "Médio", "Longo"]
	var out := []
	var from := 0.0
	for k in 3:
		if cuts[k] <= from:
			continue
		var chance := clampf(base - floorf(maxf(cuts[k] - free_m, 0.0) / 2.0) * step, lo, 0.95)
		if k == 0:
			chance = base
		out.append([names[k], "%d–%d m · %d%%" % [roundi(from), roundi(cuts[k]), roundi(chance * 100.0)]])
		from = cuts[k]
	return out


# --- Desenho -------------------------------------------------------------------

func _draw() -> void:
	if t <= 0.0:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color(0, 0, 0, DIM * t))
	var o := _origin()
	_fosco(Rect2(o, Vector2(PW, PH)))
	for i in room.party.size():
		_draw_card(font, i)
	_draw_equipment(font)
	draw_string(font, o + Vector2(190, 30), "MOCHILA", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color.WHITE)
	_draw_tabs(font)
	_draw_close()
	_draw_rows(font)
	_draw_pips(font)
	_draw_detail(font)
	_draw_hints(font)


# Placa de vidro fosco: o desfoque vem de HudBlur; aqui ficam a tinta, o contorno preto, a linha clara e os cantos.
func _fosco(r: Rect2) -> void:
	for k in 3:
		draw_rect(Rect2(r.position + Vector2(0, 2), r.size).grow(2.0 + k * 2.0), Color(0, 0, 0, 0.08), false, 2.0)
	draw_rect(r, PLATE)
	draw_rect(r.grow(1.0), Color.BLACK, false, 1.0)
	draw_rect(r.grow(-0.5), HAIR, false, 0.5)
	draw_line(r.position + Vector2(1, 1.0), Vector2(r.end.x - 1, r.position.y + 1.0), Color(1, 1, 1, 0.16), 0.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var c: Vector2 = r.position + corner * r.size
		var d := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
		draw_polyline(PackedVector2Array([c + Vector2(2.5, 6.5) * d, c + Vector2(2.5, 2.5) * d, c + Vector2(6.5, 2.5) * d]), Color(1, 1, 1, 0.5), 0.5)


# Casa escura com contorno preto e fio claro; anel branco (entre dois pretos) quando escolhida.
func _cell(r: Rect2, selected := false, hover := false, fill := SLOT_FILL) -> void:
	draw_rect(r, Color(fill, minf(fill.a + (0.18 if hover else 0.0) + (0.12 if selected else 0.0), 0.9)))
	draw_rect(r.grow(1.0), Color.BLACK, false, 1.0)
	draw_rect(r.grow(-0.5), Color(1, 1, 1, 0.12), false, 0.5)
	if selected:
		draw_rect(r.grow(3.0), Color.BLACK, false, 1.0)
		draw_rect(r.grow(2.0), Color.WHITE, false, 1.0)
		draw_rect(r.grow(1.0), Color.BLACK, false, 1.0)


func _hover(r: Rect2) -> bool:
	return r.has_point(get_viewport().get_mouse_position())


func _draw_card(font: Font, i: int) -> void:
	var r := _portrait_rect(i)
	var m: Combatant = room.party[i]
	var on := i == viewed
	_cell(r, on, _hover(r), Color(0, 0, 0, 0.5))
	var face := Rect2(r.position + Vector2(5, 5), Vector2(CARD_H - 10, CARD_H - 10))
	draw_rect(face, Color(0.16, 0.12, 0.09))
	room.agent_sheets[room.looks.get(m, 0)].draw_portrait(self, face, m.is_alive() and float(m.pv) / maxf(1.0, float(m.max_pv)) <= CharacterSheet.HURT_BELOW)
	if not m.is_alive():
		draw_rect(face, Color(0.4, 0, 0, 0.5))
	draw_rect(face.grow(0.5), Color.BLACK, false, 1.0)
	var x := face.end.x + 7.0
	var w := r.end.x - x - 6.0
	draw_string(font, Vector2(x, r.position.y + 15), m.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 11, Color.WHITE if on else Color(0.8, 0.75, 0.66))
	_bar(font, Rect2(x, r.position.y + 22, w, 11), m.pv, m.max_pv, BAR_PV)
	_bar(font, Rect2(x, r.position.y + 36, w, 11), m.san, m.max_san, BAR_SAN)
	var status := "caído" if not m.is_alive() else ("líder" if m == room.player else "seguindo")
	draw_string(font, Vector2(x, r.end.y - 6), status, HORIZONTAL_ALIGNMENT_LEFT, w, 8, MUTED)


func _bar(font: Font, r: Rect2, v: int, vmax: int, color: Color) -> void:
	draw_rect(r.grow(1.0), Color.BLACK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(float(v) / maxf(1.0, float(vmax)), 0.0, 1.0), r.size.y)), color)
	draw_string(font, r.position + Vector2(0, 8.5), "%d/%d" % [v, vmax], HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 3.0, 8, Color.WHITE)


func _draw_tabs(font: Font) -> void:
	for k in TABS.size():
		var r := _tab_rect(k)
		var on := k == tab
		draw_rect(r, Color.WHITE if on else Color(0, 0, 0, 0.35))
		draw_rect(r.grow(1.0), Color.BLACK, false, 1.0)
		if not on:
			draw_rect(r.grow(-0.5), Color(1, 1, 1, 0.14 + (0.16 if _hover(r) else 0.0)), false, 0.5)
		draw_string(font, r.position + Vector2(0, 14), TABS[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color.BLACK if on else MUTED.lightened(0.15))


func _draw_close() -> void:
	var r := _close_rect()
	var col := Color.WHITE if _hover(r) else MUTED
	draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), col, 1.5)
	draw_line(Vector2(r.end.x - 4, r.position.y + 4), Vector2(r.position.x + 4, r.end.y - 4), col, 1.5)


func _draw_equipment(font: Font) -> void:
	var o := _origin()
	draw_string(font, o + Vector2(15, 262), "EQUIPAMENTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
	for k in EQUIP_SLOTS.size():
		var slot: String = EQUIP_SLOTS[k]
		var r := _equip_rect(k)
		var id: String = room.gear_slot_id(_member(), slot)
		_cell(r, sel.get("kind") == "eq" and sel.get("slot") == slot, _hover(r))
		if id != "":
			ItemIcons.draw(self, r, id, true, 46.0)
		else:
			_ghost(r.grow(-15.0), str(GHOSTS[slot]))
		draw_string(font, r.position + Vector2(-6, SLOT + 12), EQUIP_LABELS[slot], HORIZONTAL_ALIGNMENT_CENTER, SLOT + 12, 8, MUTED)


# Silhueta fraca do que cabe no espaço vazio.
func _ghost(r: Rect2, kind: String) -> void:
	var col := Color(1, 1, 1, 0.28)
	var pts: Array = []
	match kind:
		"arma":
			pts = [Vector2(0.05, 0.3), Vector2(0.85, 0.3), Vector2(0.85, 0.5), Vector2(0.55, 0.5), Vector2(0.48, 0.9), Vector2(0.3, 0.9), Vector2(0.36, 0.5), Vector2(0.05, 0.5)]
		"colete":
			pts = [Vector2(0.18, 0.1), Vector2(0.38, 0.2), Vector2(0.62, 0.2), Vector2(0.82, 0.1), Vector2(0.96, 0.34), Vector2(0.8, 0.46), Vector2(0.8, 0.92), Vector2(0.2, 0.92), Vector2(0.2, 0.46), Vector2(0.04, 0.34)]
		_:
			var c := r.position + r.size * Vector2(0.5, 0.64)
			var ring := PackedVector2Array()
			for k in 25:
				ring.append(c + Vector2(cos(TAU * k / 24.0), sin(TAU * k / 24.0)) * r.size.x * 0.3)
			draw_polyline(ring, col, 1.0)
			draw_polyline(PackedVector2Array([r.position + r.size * Vector2(0.38, 0.14), r.position + r.size * Vector2(0.62, 0.14), r.position + r.size * Vector2(0.7, 0.3), r.position + r.size * Vector2(0.3, 0.3), r.position + r.size * Vector2(0.38, 0.14)]), col, 1.0)
			return
	var out := PackedVector2Array()
	for p in pts:
		out.append(r.position + r.size * p)
	out.append(out[0])
	draw_polyline(out, col, 1.0)


# Nome e tipo de cada item (dados fixos, guardados para não refazer a conta a cada quadro).
func _meta_of(id: String) -> Dictionary:
	if not _meta.has(id):
		var d := _describe(id)
		_meta[id] = {"nome": str(d.get("nome", id)), "tipo": str(d.get("tipo", ""))}
	return _meta[id]


func _draw_rows(font: Font) -> void:
	var slots := _visible_slots()
	if slots.is_empty():
		draw_string(font, _origin() + Vector2(190, 120), "Nada nesta aba.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		return
	for n in slots.size():
		var r := _row_rect(n)
		if r.size == Vector2.ZERO:
			continue
		var i := slots[n]
		var slot: Dictionary = room.inventory.slots[i]
		var id := str(slot["id"])
		var chosen: bool = sel.get("kind") == "bag" and sel.get("i") == i
		_cell(r, chosen, _hover(r), Color(0, 0, 0, 0.38))
		ItemIcons.draw(self, Rect2(r.position + Vector2(6, 7), Vector2(36, 36)), id, true, 32.0)
		var meta := _meta_of(id)
		var size := 11
		while size > 8 and font.get_string_size(meta["nome"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > r.size.x - 58.0:
			size -= 1  # nome comprido encolhe para caber no cartão
		draw_string(font, r.position + Vector2(52, 21), meta["nome"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 58.0, size, Color.WHITE)
		draw_string(font, r.position + Vector2(52, 36), meta["tipo"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 58.0, 8, MUTED)
		if int(slot["qty"]) > 1:
			draw_string(font, r.position + Vector2(0, r.size.y - 6), "x%d" % int(slot["qty"]), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 7.0, 12, Color.WHITE)
	if _max_scroll() > 0:  # barra de rolagem fina ao lado dos cartões
		var top := _origin().y + 48.0
		var track := VISIBLE_ROWS * ROW_STEP - 6.0
		var rows := ceili(slots.size() / 2.0)
		var h := track * float(VISIBLE_ROWS) / float(rows)
		var x := _origin().x + COL_X[1] + CARD_W + 5.0
		draw_rect(Rect2(x, top, 2, track), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(x, top + (track - h) * float(scroll) / float(_max_scroll()), 2, h), Color(1, 1, 1, 0.5))


# Os 20 espaços da mochila como marcas: cheias para as ocupadas.
func _draw_pips(font: Font) -> void:
	var o := _origin()
	for i in room.inventory.size:
		var r := Rect2(o + Vector2(190 + i * 17, 394), Vector2(14, 13))
		draw_rect(r, WHITE_SOFT if i < room.inventory.used() else Color(1, 1, 1, 0.09))
		draw_rect(r.grow(0.5), Color.BLACK, false, 1.0)
	var free: int = room.inventory.size - room.inventory.used()
	draw_string(font, o + Vector2(190, 426), "%d espaço%s livre%s" % [free, "" if free == 1 else "s", "" if free == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)


func _draw_detail(font: Font) -> void:
	var r := _detail_rect()
	_cell(r, false, false, Color(0, 0, 0, 0.5))
	var id := _item_id(sel)
	if id == "":
		draw_string(font, r.position + Vector2(0, 110), "Escolha um item", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, MUTED)
	else:
		var d := _describe(id)
		if not d.is_empty():
			ItemIcons.draw(self, Rect2(r.position + Vector2(r.size.x * 0.5 - 35, 12), Vector2(70, 70)), id, true, 56.0)
			draw_string(font, r.position + Vector2(0, 102), str(d["nome"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color.WHITE)
			draw_string(font, r.position + Vector2(0, 117), str(d["tipo"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, MUTED)
			var y := 136.0
			for line in str(d["texto"]).split("\n"):
				y = _wrap(font, line, r.position + Vector2(12, y), r.size.x - 24.0, 9) - r.position.y + 3.0
			y = maxf(y + 10.0, 150.0)
			draw_line(r.position + Vector2(12, y - 6), r.position + Vector2(r.size.x - 12, y - 6), Color(1, 1, 1, 0.18), 0.5)
			var rows: Array = []
			rows.append_array(d.get("faixas", []))
			rows.append_array(d["linhas"])
			for row in rows:
				if y > r.size.y - 44.0:
					break
				draw_string(font, r.position + Vector2(12, y + 4), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
				draw_string(font, r.position + Vector2(12, y + 4), str(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24.0, 9, Color.WHITE)
				y += 13.0
	_draw_button(font, 0, "E  " + _act_label(), id != "" and not _is_story(id))
	_draw_button(font, 1, "Del  Descartar", sel.get("kind") == "bag")


func _is_story(id: String) -> bool:
	return str(room.cfg.game_data.get_entry("itens", id).get("categoria", "")) == "missao"


# O que o E faz com o item escolhido.
func _act_label() -> String:
	if sel.get("kind") == "eq":
		return "Guardar"
	var id := _item_id(sel)
	if id != "" and not room.gear_is_equippable(id):
		return "Usar"
	return "Equipar"


func _draw_button(font: Font, k: int, label: String, enabled: bool) -> void:
	var r := _button_rect(k)
	var on := k == 0
	draw_rect(r, (Color.WHITE if enabled else Color(1, 1, 1, 0.3)) if on else Color(0, 0, 0, 0.35))
	draw_rect(r.grow(1.0), Color.BLACK, false, 1.0)
	if not on:
		draw_rect(r.grow(-0.5), Color(1, 1, 1, 0.2 if enabled else 0.08), false, 0.5)
	var col := Color.BLACK if on else (Color(0.9, 0.86, 0.78) if enabled else Color(0.5, 0.46, 0.4))
	draw_string(font, r.position + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, col)


# Quebra `text` em linhas de até `width`; devolve o y da linha seguinte.
func _wrap(font: Font, text: String, at: Vector2, width: float, size: int) -> float:
	var line := ""
	var y := at.y
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			draw_string(font, Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.84, 0.79, 0.68))
			y += size + 3.0
			line = word
		else:
			line = next
	draw_string(font, Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.84, 0.79, 0.68))
	return y + size


func _draw_hints(font: Font) -> void:
	var o := _origin()
	var x := 190.0
	for kv in [["E", "Equipar / usar / trocar"], ["Del", "Descartar"], ["B", "Fechar"]]:
		var w := 14.0 if kv[0].length() == 1 else 22.0
		var kr := Rect2(o + Vector2(x, 462), Vector2(w, 14))
		draw_rect(kr, Color(0, 0, 0, 0.4))
		draw_rect(kr.grow(0.5), Color(1, 1, 1, 0.3), false, 0.5)
		draw_string(font, kr.position + Vector2(0, 10.5), kv[0], HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color.WHITE)
		draw_string(font, kr.position + Vector2(w + 5, 10.5), kv[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.75, 0.7, 0.6))
		x += w + 16.0 + font.get_string_size(kv[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	if toast_time > 0.0 and toast != "":
		draw_string(font, o + Vector2(190, 446), toast, HORIZONTAL_ALIGNMENT_LEFT, 380, 10, Color(1, 0.8, 0.5, minf(toast_time, 1.0)))
