class_name InventoryPanel
extends Node2D
# Inventário em painel lateral (Léo, 30/10/2026, sobre o conceito do ChatGPT): abre com a tecla B
# (ou fecha com B e com o X), desliza da direita em ~0,2 s enquanto o cenário escurece um pouco e
# deixa o grupo visível à esquerda. Mostra a mochila compartilhada (20 espaços), os três
# personagens para ver o equipamento de cada um, o detalhe do item e os 4 espaços de equipamento.
# Só desenha e lê o mouse e o teclado; as regras de equipar, usar e descartar ficam em `room`
# (gear_equip, gear_unequip, gear_use e gear_discard) e a mochila em `room.inventory`.

const PW := 480.0
const PH := 516.0
const MARGIN := Vector2(16, 12)  # folga até a borda direita e a de cima
const PORTRAIT := 55.0  # 48 + 15% (pedido do Léo, 30/10/2026)
const CELL := 40.0
const GAP := 3.0
const COLS := 5
const OPEN_SECONDS := 0.2
const DIM := 0.38
const GOLD := Color(0.839, 0.678, 0.361)
const BRONZE := Color(0.612, 0.455, 0.22)
const BRONZE_DARK := Color(0.353, 0.255, 0.149)
const PLATE := Color(0.05, 0.037, 0.03, 0.97)
const SLOT_FILL := Color(0.055, 0.042, 0.035, 0.96)
const MUTED := Color(0.66, 0.6, 0.49)
const TEXT := Color(0.91, 0.87, 0.79)
const CRIMSON := Color(0.62, 0.09, 0.11)

# Armas que o jogo trata como de curta distância (pedido do Léo, 30/10/2026): mostram só a faixa Curto.
const SHORT_RANGE := ["pistola"]

# Moldura pintada pelo Léo (ChatGPT, 30/10/2026): 1278x1230, centro transparente. Desenhada em faixas
# (cantos fixos, trechos retos esticados) um pouco maior que a área do conteúdo.
const FRAME_TEX := preload("res://assets/sprites/ui/inv/moldura.png")
const FRAME_SCALE := 0.33
const FRAME_PAD := Vector2(16, 0)  # quanto a moldura sai do conteúdo à esquerda e em cima
const FRAME_SIZE := Vector2(506, 516)

# Peças pintadas pelo Léo (30/10/2026), já em tamanho nativo; a tela interna é ampliada 2x.
const INV_ART := "res://assets/sprites/ui/inv/"
const TEX_TAB := preload(INV_ART + "aba.png")
const TEX_TAB_GLOW := preload(INV_ART + "aba_brilho.png")
const TEX_EQUIP_FRAME := preload(INV_ART + "quadro_equipamento.png")
const TEX_CELL := preload(INV_ART + "casa.png")
const TEX_CELL_GLOW := preload(INV_ART + "casa_brilho.png")
const TEX_PORTRAIT := preload(INV_ART + "retrato.png")
const TEX_PORTRAIT_GLOW := preload(INV_ART + "retrato_brilho.png")
const TEX_EQUIP := preload(INV_ART + "equip.png")
const TEX_EQUIP_GLOW := preload(INV_ART + "equip_brilho.png")
const TEX_KEY := preload(INV_ART + "tecla.png")
const TEX_KEY_WIDE := preload(INV_ART + "tecla_larga.png")
const TEX_DETAIL := preload(INV_ART + "detalhe.png")
const GLOW_PAD := 4.0  # 8 px nativos de halo em volta das peças brilhantes

const TABS := ["TUDO", "ARMAS", "ITENS", "COLETES"]
const EQUIP_SLOTS := ["principal", "secundaria", "colete", "acessorio"]
const EQUIP_LABELS := {"principal": "ARMA PRINCIPAL", "secundaria": "ARMA SECUNDÁRIA", "colete": "COLETE", "acessorio": "ACESSÓRIO"}

# Textos provisórios dos itens (o GDD ainda não os define).
const BLURBS := {
	"pistola": "Arma curta de uso comum. Confiável à curta distância.",
	"escopeta": "Dano alto à queima-roupa, gasta 2 PA por disparo.",
	"espada": "Lâmina de corpo a corpo, forte nas mãos de quem aceita o risco.",
	"fuzil_precisao": "Tiro longo e preciso, sem penalidade de distância até 18 m.",
	"soco": "Sem arma: golpe de mão fechada.",
	"kit_primeiros_socorros": "Reanima um aliado caído, que volta com metade do PV.",
	"bandagem": "Estanca o sangramento de quem a usa.",
	"antidoto": "Neutraliza o veneno em quem o toma.",
	"curativo": "Cobre ferimentos leves.",
	"componente_ritual": "Material usado nos rituais.",
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
var close_glow := 0.0  # 0..1, acende e apaga suavemente com o mouse sobre o X


func toggle() -> void:
	if open:
		close()
	elif room.inventory_can_open():
		open = true
		viewed = maxi(room.party.find(room.player), 0)
		sel = {}
		toast = ""
		set_process(true)


func close() -> void:
	open = false
	room.queue_redraw()


func _process(delta: float) -> void:
	var goal := 1.0 if open else 0.0
	t = move_toward(t, goal, delta / OPEN_SECONDS)
	toast_time = maxf(toast_time - delta, 0.0)
	var over := open and _close_rect().has_point(get_viewport().get_mouse_position())
	close_glow = move_toward(close_glow, 1.0 if over else 0.0, delta / 0.15)
	queue_redraw()
	if t == 0.0 and not open:
		set_process(false)


# Posição do painel; durante a animação ele entra deslizando pela direita.
func _origin() -> Vector2:
	var e := 1.0 - pow(1.0 - t, 3.0)
	return Vector2(960.0 - PW - MARGIN.x + (1.0 - e) * (PW + 30.0), MARGIN.y)


# --- Áreas clicáveis (as mesmas do desenho) ---------------------------------

func _frame_rect() -> Rect2:
	return Rect2(_origin() - FRAME_PAD, FRAME_SIZE)


# O X vem pintado na moldura (canto superior direito).
func _close_rect() -> Rect2:
	var f := _frame_rect()
	return Rect2(f.end.x - 41, f.position.y + 20, 24, 24)


func _portrait_rect(i: int) -> Rect2:
	return Rect2(_origin() + Vector2(14, 64 + i * 78), Vector2(PORTRAIT, PORTRAIT))


func _tab_rect(k: int) -> Rect2:
	return Rect2(_origin() + Vector2(PW - 16 - TABS.size() * 50 + k * 50, 64), Vector2(46, 24))


func _grid_rect(i: int) -> Rect2:
	return Rect2(_origin() + Vector2(76, 104) + Vector2(i % COLS, i / COLS) * (CELL + GAP), Vector2(CELL, CELL))


func _detail_rect() -> Rect2:
	return Rect2(_origin() + Vector2(300, 96), Vector2(164, 204))


func _equip_rect(k: int) -> Rect2:
	return Rect2(_origin() + Vector2(98 + k * 92, 356), Vector2(56, 56))


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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(get_viewport().get_mouse_position())
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
			return
	for i in Inventory.SIZE:
		if _grid_rect(i).has_point(p):
			if not room.inventory.slots[i].is_empty():
				# clicar de novo no item já escolhido equipa ou usa (atalho do E)
				var again: bool = sel.get("kind") == "bag" and sel.get("i") == i
				sel = {"kind": "bag", "i": i}
				if again:
					_act()
			else:
				sel = {}
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
		if room.gear_is_equippable(id):
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
	return {"nome": it["nome"], "tipo": str(it["categoria"]).capitalize(), "texto": BLURBS.get(id, ""), "linhas": lines}


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
	_backdrop(_frame_rect())
	var f := _frame_rect()
	draw_string(font, Vector2(f.position.x, f.position.y + 36), "%d / %d" % [room.inventory.used(), Inventory.SIZE], HORIZONTAL_ALIGNMENT_RIGHT, FRAME_SIZE.x - 62, 12, MUTED)
	_draw_close()
	for i in room.party.size():
		_draw_portrait(font, i)
	_draw_tabs(font)
	_draw_grid(font)
	_draw_detail(font)
	_draw_equipment(font)
	_draw_hints(font)


# Fundo escuro com a moldura pintada por cima.
func _backdrop(r: Rect2) -> void:
	draw_rect(r.grow(-6.0), PLATE)
	_vignette(r.grow(-6.0), Color(0, 0, 0, 0.5))
	var sc := FRAME_SCALE
	# faixas da imagem (px): x e y de corte; destino em tela interna
	var w := 1278.0
	var h := 1230.0
	var xl := 400.0  # no topo, o canto esquerdo leva o título
	var xr := 1150.0  # e o direito leva o X
	var bl := 130.0  # embaixo, os cantos levam os medalhões
	var br := 1148.0
	var side := 65.0
	var top := 160.0
	var bot := 1160.0
	var dl := xl * sc
	var dr := (w - xr) * sc
	var dt := top * sc
	var db := (h - bot) * sc
	var ds := side * sc
	_part(Rect2(xl, 0, xr - xl, top), Rect2(r.position.x + dl, r.position.y, r.size.x - dl - dr, dt))
	_part(Rect2(0, 0, xl, top), Rect2(r.position.x, r.position.y, dl, dt))
	_part(Rect2(xr, 0, w - xr, top), Rect2(r.end.x - dr, r.position.y, dr, dt))
	_part(Rect2(0, top, side, bot - top), Rect2(r.position.x, r.position.y + dt, ds, r.size.y - dt - db))
	_part(Rect2(w - side, top, side, bot - top), Rect2(r.end.x - ds, r.position.y + dt, ds, r.size.y - dt - db))
	_part(Rect2(bl, bot, br - bl, h - bot), Rect2(r.position.x + bl * sc, r.end.y - db, r.size.x - (bl + w - br) * sc, db))
	_part(Rect2(0, bot, bl, h - bot), Rect2(r.position.x, r.end.y - db, bl * sc, db))
	_part(Rect2(br, bot, w - br, h - bot), Rect2(r.end.x - (w - br) * sc, r.end.y - db, (w - br) * sc, db))


func _part(src: Rect2, dst: Rect2) -> void:
	draw_texture_rect_region(FRAME_TEX, dst, src)


func _vignette(r: Rect2, color: Color) -> void:
	for i in 14:
		draw_rect(r.grow(-i * 2.0), Color(color, color.a * pow(1.0 - i / 14.0, 2.0) * 0.5), false, 2.0)


# Moldura como a do HUD: placa escura, filete duplo de bronze, cantoneiras e losango.
func _frame(r: Rect2, accent := GOLD, thin := false) -> void:
	draw_rect(r, Color(PLATE, 0.62))
	var lit := thin and r.has_point(get_viewport().get_mouse_position())
	draw_rect(r.grow(-0.5), GOLD if lit else BRONZE, false, 1.0)
	if lit:
		_glow(r, 0.35)
	draw_rect(r.grow(-3.0 if thin else -4.0), Color(BRONZE_DARK, 0.8), false, 0.5)
	if thin:
		return
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var c: Vector2 = r.position + corner * r.size
		var d := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
		draw_polyline(PackedVector2Array([c + Vector2(1.5, 11) * d, c + Vector2(1.5, 1.5) * d, c + Vector2(11, 1.5) * d]), accent, 1.0)
		_diamond(c + Vector2(6, 6) * d, 1.8, accent)
	_diamond(Vector2(r.get_center().x, r.position.y + 0.5), 3.0, accent)
	_diamond(Vector2(r.get_center().x, r.end.y - 0.5), 3.0, accent)


# Brilho dourado na borda: anéis cada vez mais fracos para fora e uma luz suave por dentro.
func _glow(r: Rect2, strength: float) -> void:
	for i in 5:
		draw_rect(r.grow(0.5 + i * 1.1), Color(GOLD, (0.34 - i * 0.065) * strength), false, 1.0)
	draw_rect(r.grow(-1.5), Color(GOLD, 0.1 * strength), false, 2.0)


func _diamond(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


func _draw_close() -> void:
	if close_glow <= 0.0:
		return
	var r := _close_rect()
	var e := close_glow * close_glow * (3.0 - 2.0 * close_glow)
	draw_rect(r, Color(1.0, 0.45, 0.3, 0.16 * e))
	_glow(r, 0.9 * e)


func _draw_portrait(font: Font, i: int) -> void:
	var r := _portrait_rect(i)
	var m: Combatant = room.party[i]
	var on := i == viewed
	draw_rect(r, Color(0.16, 0.12, 0.09))
	room.agent_sheets[room.looks.get(m, 0)].draw_portrait(self, r.grow(-3))
	if not m.is_alive():
		draw_rect(r, Color(0.4, 0, 0, 0.5))
	var hover := r.has_point(get_viewport().get_mouse_position())
	if on or hover:
		draw_texture_rect(TEX_PORTRAIT_GLOW, r.grow(GLOW_PAD), false, Color(1, 1, 1, 1.0 if on else 0.75))
	else:
		draw_texture_rect(TEX_PORTRAIT, r, false)
	draw_string(font, r.position + Vector2(0, PORTRAIT + 11), m.name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9, GOLD if on else MUTED)


func _draw_tabs(font: Font) -> void:
	var o := _origin()
	var m := _member()
	draw_string(font, o + Vector2(76, 82), m.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)
	draw_string(font, o + Vector2(76, 96), "PV %d/%d  ·  SAN %d/%d" % [m.pv, m.max_pv, m.san, m.max_san], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MUTED)
	for k in TABS.size():
		var r := _tab_rect(k)
		var on := k == tab
		var hover := r.has_point(get_viewport().get_mouse_position())
		draw_rect(r.grow(-3.0), Color(0.2, 0.05, 0.05) if on else (Color(0.12, 0.09, 0.06) if hover else SLOT_FILL))
		if on or hover:
			draw_texture_rect(TEX_TAB_GLOW, r.grow(GLOW_PAD), false, Color(1, 1, 1, 1.0 if on else 0.7))
		else:
			draw_texture_rect(TEX_TAB, r, false)
		draw_string(font, r.position + Vector2(0, 16), TABS[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, TEXT if on else MUTED)


func _slot(font: Font, r: Rect2, id: String, qty: int, selected: bool, dim: bool) -> void:
	draw_rect(r, SLOT_FILL)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, r.size.y * 0.45)), Color(1, 0.9, 0.7, 0.04))
	var hover := r.has_point(get_viewport().get_mouse_position())
	var big := r.size.x > 50.0
	if selected or hover:
		draw_rect(r.grow(-3), Color(1, 0.9, 0.7, 0.07))
		draw_texture_rect(TEX_EQUIP_GLOW if big else TEX_CELL_GLOW, r.grow(GLOW_PAD), false, Color(1, 1, 1, 1.0 if selected else 0.7))
	else:
		draw_texture_rect(TEX_EQUIP if big else TEX_CELL, r, false)
	if id == "":
		return
	var side := roundf(r.size.x * 0.62)  # folga em volta do ícone, longe da moldura
	ItemIcons.draw(self, r, id, not dim, side)
	if qty > 1:
		draw_string(font, r.position + Vector2(0, r.size.y - 6), "%d" % qty, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 6, 9, GOLD)


func _draw_grid(font: Font) -> void:
	for i in Inventory.SIZE:
		var s: Dictionary = room.inventory.slots[i]
		var id := "" if s.is_empty() else str(s["id"])
		_slot(font, _grid_rect(i), id, 0 if s.is_empty() else int(s["qty"]), sel.get("kind") == "bag" and sel.get("i") == i, not _tab_match(id))


func _draw_detail(font: Font) -> void:
	var r := _detail_rect()
	draw_rect(r.grow(-5.0), Color(PLATE, 0.8))
	draw_texture_rect(TEX_DETAIL, r, false)
	var id := _item_id(sel)
	if id == "":
		draw_string(font, r.position + Vector2(0, 100), "Escolha um item", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, MUTED)
		return
	var d := _describe(id)
	if d.is_empty():
		return
	ItemIcons.draw(self, Rect2(r.position + Vector2(13, 14), Vector2(39, 37)), id, true, 28.0)
	draw_string(font, r.position + Vector2(58, 31), str(d["nome"]), HORIZONTAL_ALIGNMENT_LEFT, 92, 12, TEXT)
	draw_string(font, r.position + Vector2(58, 43), str(d["tipo"]), HORIZONTAL_ALIGNMENT_LEFT, 92, 8, MUTED)
	var y := 68.0
	for line in str(d["texto"]).split("\n"):
		y = _wrap(font, line, r.position + Vector2(18, y), 128.0, 9) - r.position.y + 3.0
	var faixas: Array = d.get("faixas", [])
	var fy := 148.0 - 11.0 * faixas.size() - 4.0
	for row in faixas:
		draw_string(font, r.position + Vector2(18, fy), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD)
		draw_string(font, r.position + Vector2(18, fy), str(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, 128.0, 8, MUTED)
		fy += 11.0
	var rows: Array = d["linhas"]
	var base := [158.0, 173.5, 188.0]
	for k in mini(rows.size(), 3):
		draw_string(font, r.position + Vector2(17, base[k]), str(rows[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GOLD)
		draw_string(font, r.position + Vector2(17, base[k]), str(rows[k][1]), HORIZONTAL_ALIGNMENT_RIGHT, 130.0, 9, TEXT)


# Quebra `text` em linhas de até `width`; devolve o y da linha seguinte.
func _wrap(font: Font, text: String, at: Vector2, width: float, size: int) -> float:
	var line := ""
	var y := at.y
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			draw_string(font, Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, MUTED.lightened(0.15))
			y += size + 3.0
			line = word
		else:
			line = next
	draw_string(font, Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, MUTED.lightened(0.15))
	return y + size


func _draw_equipment(font: Font) -> void:
	var o := _origin()
	var fr := Rect2(o + Vector2(72, 296), Vector2(392, 140))
	draw_rect(fr.grow(-4.0), Color(PLATE, 0.62))
	draw_texture_rect(TEX_EQUIP_FRAME, fr, false)
	draw_string(font, o + Vector2(100, 330), "EQUIPAMENTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	for k in EQUIP_SLOTS.size():
		var slot: String = EQUIP_SLOTS[k]
		var r := _equip_rect(k)
		draw_string(font, r.position + Vector2(-18, -5), EQUIP_LABELS[slot], HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 36, 7, MUTED)
		_slot(font, r, room.gear_slot_id(_member(), slot), 0, sel.get("kind") == "eq" and sel.get("slot") == slot, false)


func _draw_hints(font: Font) -> void:
	var o := _origin()
	var keys := [["E", "Equipar / usar / trocar"], ["Del", "Descartar"], ["B", "Fechar"]]
	var x := 76.0
	for kv in keys:
		var w := 22.0 if kv[0].length() == 1 else 30.0
		var kr := Rect2(o + Vector2(x, 466), Vector2(w, 22))
		draw_texture_rect(TEX_KEY if kv[0].length() == 1 else TEX_KEY_WIDE, kr, false)
		draw_string(font, kr.position + Vector2(0, 15), kv[0], HORIZONTAL_ALIGNMENT_CENTER, w, 10, TEXT)
		draw_string(font, kr.position + Vector2(w + 6, 15), kv[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
		x += w + 18.0 + font.get_string_size(kv[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	if toast_time > 0.0 and toast != "":
		draw_string(font, o + Vector2(24, PH - 14), toast, HORIZONTAL_ALIGNMENT_CENTER, PW - 48, 10, Color(1, 0.8, 0.5, minf(toast_time, 1.0)))
