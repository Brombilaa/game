class_name RoomActionBar
extends RefCounted
# Barra de ações do rodapé no turno do jogador: casas de arma, dicas, PA e botão de fim do turno
# (extraído de test_room.gd, M5). A sala guarda o estado; aqui ficam a geometria e o desenho.

var room: TestRoom  # a sala de teste (test_room.gd)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Barra de combate (pedido do Léo, 30/10/2026, sobre a referência do ChatGPT): uma moldura única,
# compacta e semitransparente no rodapé, com as casas de ação à esquerda, um divisor gótico e o
# fim do turno em carmesim à direita; os PA ficam numa faixa de gemas sobre a borda de cima.
# Só o desenho mudou: as casas e o botão continuam sendo os retângulos de _action_rect e _end_turn_rect.
const BAR_SLOT := 38.0  # lado de uma casa, pixels da tela
const BAR_GAP := 4.0
const BAR_PAD := 7.0  # da moldura até as casas
const BAR_DIVIDER := 16.0  # vão entre as casas e o fim do turno
const BAR_END_W := 92.0
const BAR_BOTTOM := 532.0
const RITUAL_GAP := 10.0  # vão (com um fio) entre as ações comuns e as casas de ritual (modelo A, Léo 16/11)
# Dica curta dos itens de combate na barra (valores provisórios em combat.json, itens_combate).
const ITEM_TIPS := {
	"coquetel": "fogo onde cai: 12 a 16 de dano e Em chamas (só o Fernando)",
	"sinalizador": "luz no chão: +acerto contra quem está nela",
}
# Atalhos da barra em combate (Léo, 19/11): as casas usam as teclas numéricas em ordem, da esquerda para a
# direita (1 a 9, depois 0, - e =), e não letras. A casa k (contando de 0) usa SLOT_KEYS[k].
const SLOT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]
const SLOT_KEYS_PAD := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_0]
const SLOT_LABELS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]


# Casa da barra ligada à tecla, ou -1.
static func slot_for_key(keycode: int) -> int:
	var k := SLOT_KEYS.find(keycode)
	return k if k >= 0 else SLOT_KEYS_PAD.find(keycode)


static func key_label(k: int) -> String:
	return SLOT_LABELS[k] if k >= 0 and k < SLOT_LABELS.size() else ""


# Texto da tecla da casa `k` para as dicas ("tecla 3"), ou "" se a casa não tem tecla.
static func key_text(k: int) -> String:
	return "tecla %s" % key_label(k) if key_label(k) != "" else "só pelo clique"


# Ações do rodapé no turno do jogador: [ícone, título, detalhe, ativa]. A arma secundária
# aparece apagada quando faltam PA para a troca.
func _action_slots() -> Array:
	var data := room.cfg.game_data
	var kit := data.get_entry("itens", "kit_primeiros_socorros")
	var id := str(room.player.weapon["id"])
	var ammo := room.ammo_of(room.player)  # [carregador, reserva] ou [] se a arma não usa munição
	var attack := "Atacar · %d PA · clique no inimigo" % int(room.player.weapon["pa_cost"])
	if not ammo.is_empty():
		attack = "Atacar · %d PA · clique no inimigo · tecla 1 ou clique aqui recarrega (%d PA)" % [int(room.player.weapon["pa_cost"]), int(room.cfg.regra("custo_recarga_pa", 1))]
	var slots := [[id, str(data.get_entry("armas", id).get("nome", id)), attack, true, ammo]]
	var second := room._reserve_id()
	if second != "":
		var second_ammo := []
		if int(room.cfg.weapon(second)["mag_size"]) > 0:
			second_ammo = [int(room.player.mag.get(second, 0)), room.inventory.count(room.ammo_item(second))]
		slots.append([second, str(data.get_entry("armas", second).get("nome", second)), "Trocar arma · %d PA · tecla 2" % int(room.cfg.regra("custo_trocar_arma_pa", 1)), room.player.pa >= int(room.cfg.regra("custo_trocar_arma_pa", 1)), second_ammo])
	slots.append(["kit", "Kit de primeiros socorros", "Reanimar · %d PA · %s · restam %d" % [int(kit["custo_pa_combate"]), key_text(slots.size()), room.inventory.count(room.KIT_ID)], room.inventory.count(room.KIT_ID) > 0])
	slots.append(["vigilancia", "Vigilância", "%d PA · %s · atira no 1º inimigo que se mover no cone" % [int(room.player.weapon["pa_cost"]), key_text(slots.size())], room.rules.overwatch_blocker(room.player) == "" or room.player.overwatch])
	slots.append(["atrasar", "Atrasar", "Age depois na rodada · %s" % key_text(slots.size()), true])
	for iid in room.room_items.available():  # itens de combate na mochila (coquetel, só do Fernando, e sinalizador)
		var cost := room.item_rules.cost(iid)
		var it := data.get_entry("itens", iid)
		slots.append([iid, str(it["nome"]), "%d PA · %s · %s" % [cost, key_text(slots.size()), ITEM_TIPS.get(iid, "")],
			room.player.is_alive() and room.player.pa >= cost, [], {}, room.inventory.count(iid)])
	for rid in _rituals():  # rituais do controlado (Miguel): uma casa por ritual, com etiqueta de PA e SAN
		var r := room.rituals.ritual(rid)
		var pa := int(r["custo_pa"])
		var san := int(r["custo_san"])
		var need := room.rituals.cost_components(rid)
		var have := room.rituals.components_available(rid)
		var elem := RitualRules.element_name(room.rituals.element(rid))
		slots.append([rid, str(r["nome"]), "%d PA · %d SAN · %d de %s (tem %d) · %s · %s" % [pa, san, need, elem, have, key_text(slots.size()), str(r["descricao"])],
			room.player.is_alive() and room.player.pa >= pa and room.player.san >= san and have >= need, [], {"pa": pa, "san": san, "elemento": room.rituals.element(rid), "tem": have}])
	return slots


# Rituais que o controlado conhece (vazio para quem não é Ocultista).
func _rituals() -> Array[String]:
	return room.rituals.known(room.player)


# Índice da primeira casa de ritual (igual ao número de casas se não houver nenhuma).
func ritual_start(n: int) -> int:
	return n - _rituals().size()


# Ritual na casa `k` da barra, ou "" se a casa não é de ritual.
func ritual_at(k: int, n: int) -> String:
	var list := _rituals()
	var i := k - (n - list.size())
	return list[i] if i >= 0 and i < list.size() else ""


# Índice da primeira casa de item de combate (depois de kit, vigilância e atrasar).
func item_start() -> int:
	return kit_index() + 3


# Item de combate na casa `k` da barra, ou "" se a casa não é de item.
func item_at(k: int) -> String:
	var list := room.room_items.available()
	var i := k - item_start()
	return list[i] if i >= 0 and i < list.size() else ""


# Posição do kit entre as casas da barra (depois da arma e da reserva, se houver).
func kit_index() -> int:
	return 2 if room._reserve_id() != "" else 1


func _bar_width(n: int) -> float:
	return BAR_PAD * 2 + n * BAR_SLOT + (n - 1) * BAR_GAP + BAR_DIVIDER + BAR_END_W + (RITUAL_GAP if not _rituals().is_empty() else 0.0)


# Moldura inteira da barra, em pixels da tela.
func _bar_rect(n: int) -> Rect2:
	var h := BAR_SLOT + BAR_PAD * 2
	return Rect2(Vector2(roundf(480 - _bar_width(n) * 0.5), BAR_BOTTOM - h), Vector2(_bar_width(n), h))


func _action_rect(k: int, n: int) -> Rect2:
	var bar := _bar_rect(n)
	var shift := RITUAL_GAP if ritual_at(k, n) != "" else 0.0
	return Rect2(bar.position + Vector2(BAR_PAD + k * (BAR_SLOT + BAR_GAP) + shift, BAR_PAD), Vector2(BAR_SLOT, BAR_SLOT))


func _end_turn_rect(n: int) -> Rect2:
	var bar := _bar_rect(n)
	return Rect2(Vector2(bar.end.x - BAR_PAD - BAR_END_W, bar.position.y + BAR_PAD), Vector2(BAR_END_W, BAR_SLOT))


# Rodapé: gemas de PA, ícones das ações (dica ao passar o mouse) e o botão de fim do turno.
func _draw_actions(font: Font, to_world: Transform2D) -> void:
	var slots := _action_slots()
	var n := slots.size()
	var mouse := room.get_viewport().get_mouse_position()
	var bar := _bar_rect(n)
	var br := Rect2(to_world * bar.position, bar.size)
	_draw_bar_frame(br, (to_world * _end_turn_rect(n).position).x)
	_draw_pa_strip(br.position + Vector2(14, 0), room.turns.turn_pa(room.player), room.player.pa)
	if ritual_start(n) < n:  # fio vertical entre as ações comuns e os rituais
		var gap_x := (to_world * _action_rect(ritual_start(n), n).position).x - RITUAL_GAP * 0.5 - BAR_GAP * 0.5
		room.draw_line(Vector2(gap_x, br.position.y + 8.0), Vector2(gap_x, br.end.y - 8.0), Color(1, 1, 1, 0.22), 0.5)
	var tip := -1
	for k in n:
		var screen := _action_rect(k, n)
		var hover := screen.has_point(mouse)
		if hover:
			tip = k
		_draw_slot(font, Rect2(to_world * screen.position, screen.size), slots[k], k == 0, hover)
		_draw_key_tag(font, Rect2(to_world * screen.position, screen.size), k)
	var end := _end_turn_rect(n)
	var er := Rect2(to_world * end.position, end.size)
	var over_end := end.has_point(mouse)
	_draw_end_turn(font, er, over_end, over_end and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), room._player_ready())
	if tip >= 0:
		var r := Rect2(to_world * _action_rect(tip, n).position, Vector2(BAR_SLOT, BAR_SLOT))
		room.party_hud._draw_tooltip(font, Vector2(r.get_center().x, r.position.y - 64), slots[tip][1], slots[tip][2])
	elif over_end:
		room.party_hud._draw_tooltip(font, Vector2(er.get_center().x, er.position.y - 42), "Fim do turno", "Barra de espaço", true)


# Moldura da barra: vidro fosco (o desfoque vem de HudBlur) e um fio claro antes do fim do turno.
func _draw_bar_frame(r: Rect2, end_x: float) -> void:
	room.party_hud._draw_fosco(r)
	var x := end_x - BAR_DIVIDER * 0.5
	for k in 8:  # fio vertical que some nas pontas
		var y0 := r.position.y + 6.0 + k * (r.size.y - 12.0) / 8.0
		room.draw_line(Vector2(x, y0), Vector2(x, y0 + (r.size.y - 12.0) / 8.0), Color(1, 1, 1, 0.22 * sin(PI * (k + 0.5) / 8.0)), 0.5)


# PA sobre a borda de cima da barra: uma pílula chapada por PA. Branca = disponível, apagada = gasta;
# a próxima a ser gasta pulsa de leve.
func _draw_pa_strip(at: Vector2, total: int, left: int) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	for n in total:
		var pill := Rect2(Vector2(at.x + n * 14.0, at.y - 9.0), Vector2(11.0, 3.0))
		room.draw_rect(pill.grow(1.0), Color.BLACK, false, 1.0)
		if n < left:
			room.draw_rect(pill, Color(1, 1, 1, 0.9 if n < left - 1 else 0.75 + 0.25 * pulse))
		else:
			room.draw_rect(pill, Color(1, 1, 1, 0.18))


# Casa de ação: fundo escuro, contorno preto, linha clara fina; a selecionada leva o anel branco
# entre dois pretos (como os cartões do grupo); sob o mouse clareia; indisponível apaga o ícone.
func _draw_slot(font: Font, r: Rect2, slot: Array, selected: bool, hover: bool) -> void:
	var enabled: bool = slot[3]
	room.draw_rect(r, Color(0.075, 0.062, 0.052, 0.96))
	room.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.6), Vector2(r.size.x, r.size.y * 0.4)), Color(0, 0, 0, 0.22))
	_draw_action_icon(r, slot[0], enabled)
	if not enabled:
		room.draw_rect(r, Color(0.02, 0.015, 0.012, 0.4))
	room.draw_rect(r.grow(1.0), Color.BLACK, false, 1.0)
	if selected:
		room.draw_rect(r.grow(3.5), Color.BLACK, false, 1.0)
		room.draw_rect(r.grow(2.5), Color.WHITE, false, 1.0)
		room.draw_rect(r.grow(1.5), Color.BLACK, false, 1.0)
	else:
		room.draw_rect(r.grow(-0.5), Color(1, 1, 1, 0.5 if hover else 0.2), false, 0.5)
	if hover:
		room.draw_rect(r, Color(1, 1, 1, 0.08))
	if slot.size() > 5 and not slot[5].is_empty():
		_draw_cost_tag(font, r, int(slot[5]["pa"]), int(slot[5]["san"]), enabled)
		if slot[5].has("elemento"):
			_draw_component_tag(font, r, str(slot[5]["elemento"]), int(slot[5]["tem"]))
	if slot.size() > 6:
		_draw_qty_tag(font, r, int(slot[6]))
	if slot.size() > 4 and not slot[4].is_empty():
		_draw_ammo_tag(font, r, int(slot[4][0]), int(slot[4][1]), int(room.cfg.weapon(str(slot[0]))["mag_size"]))


# Etiqueta de munição no canto de baixo da casa da arma (modelo A do Léo): balas no carregador em
# destaque e a reserva da mochila menor. Vermelha com 25% ou menos do carregador (mínimo 2).
func _draw_ammo_tag(font: Font, r: Rect2, mag: int, reserve: int, mag_size: int) -> void:
	var low := mag <= maxi(2, mag_size / 4)
	var tag := Rect2(Vector2(r.end.x - 29.0 - 1.0, r.end.y - 12.0 - 1.0), Vector2(29.0, 12.0))
	room.draw_rect(tag.grow(1.0), Color.BLACK)
	room.draw_rect(tag, Color(0.075, 0.062, 0.052, 0.94))
	room.draw_rect(tag.grow(-0.5), Color(1, 1, 1, 0.2), false, 0.5)
	var ink := Color(0.91, 0.38, 0.33) if low else Color(0.94, 0.91, 0.84)
	room.draw_string(font, tag.position + Vector2(3.0, 9.0), str(mag), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ink)
	room.draw_string(font, tag.position + Vector2(0, 9.0), "/%d" % reserve, HORIZONTAL_ALIGNMENT_RIGHT, tag.size.x - 2.5, 6, Color(0.67, 0.63, 0.56))


# Número da tecla no canto de cima, à esquerda, de cada casa (Léo, 19/11: atalhos em ordem numérica).
func _draw_key_tag(font: Font, r: Rect2, k: int) -> void:
	var label := key_label(k)
	if label == "":
		return
	var tag := Rect2(r.position + Vector2(1.0, 1.0), Vector2(9.0, 10.0))
	room.draw_rect(tag, Color(0, 0, 0, 0.72))
	room.draw_string(font, tag.position + Vector2(0, 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 8, Color(0.94, 0.91, 0.84))


# Ação da casa `k` (contando de 0), a mesma do clique: arma atual = recarregar, arma de reserva = trocar,
# kit, vigilância, atrasar, itens de combate e rituais. Retorna false se não existe casa `k`.
func activate(k: int) -> bool:
	var n := _action_slots().size()
	if k < 0 or k >= n:
		return false
	var rid := ritual_at(k, n)
	var iid := item_at(k)
	if rid != "":
		room.room_ritual.cast(rid)
	elif iid != "":
		room.room_items.use(iid)
	elif k == 0:
		room._reload()
	elif k == 1 and room._reserve_id() != "":
		room._swap_weapon()
	elif k == kit_index():
		room._use_kit_button()
	elif k == kit_index() + 1:
		room._overwatch()
	elif k == kit_index() + 2:
		room._player_delay()
	return true


# Quantidade na mochila no canto de baixo da casa dos itens de combate.
func _draw_qty_tag(font: Font, r: Rect2, qty: int) -> void:
	var tag := Rect2(Vector2(r.end.x - 15.0 - 1.0, r.end.y - 12.0 - 1.0), Vector2(15.0, 12.0))
	room.draw_rect(tag.grow(1.0), Color.BLACK)
	room.draw_rect(tag, Color(0.075, 0.062, 0.052, 0.94))
	room.draw_rect(tag.grow(-0.5), Color(1, 1, 1, 0.2), false, 0.5)
	room.draw_string(font, tag.position + Vector2(0, 9.0), "x%d" % qty, HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 8, Color(0.94, 0.91, 0.84))


# Etiqueta de custo dos rituais no canto de baixo da casa (modelo A do Léo): PA em branco, SAN em roxo.
func _draw_cost_tag(font: Font, r: Rect2, pa: int, san: int, enabled: bool) -> void:
	var tag := Rect2(Vector2(r.end.x - 21.0 - 1.0, r.end.y - 12.0 - 1.0), Vector2(21.0, 12.0))
	room.draw_rect(tag.grow(1.0), Color.BLACK)
	room.draw_rect(tag, Color(0.075, 0.062, 0.052, 0.94))
	room.draw_rect(tag.grow(-0.5), Color(1, 1, 1, 0.2), false, 0.5)
	var dim := 1.0 if enabled else 0.55
	room.draw_string(font, tag.position + Vector2(3.0, 9.0), str(pa), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.94, 0.91, 0.84, dim))
	room.draw_string(font, tag.position + Vector2(10.0, 9.0), str(san), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.66, 0.5, 0.92, dim))


# Componentes do ritual na mochila, no canto de baixo à esquerda: o número na cor do elemento, vermelho no zero.
const ELEMENT_INK := {"sangue": Color(0.86, 0.24, 0.24), "energia": Color(0.95, 0.8, 0.3), "morte": Color(0.78, 0.78, 0.74), "conhecimento": Color(0.55, 0.75, 0.95)}


func _draw_component_tag(font: Font, r: Rect2, elemento: String, have: int) -> void:
	var tag := Rect2(Vector2(r.position.x + 1.0, r.end.y - 12.0 - 1.0), Vector2(12.0, 12.0))
	room.draw_rect(tag.grow(1.0), Color.BLACK)
	room.draw_rect(tag, Color(0.075, 0.062, 0.052, 0.94))
	room.draw_rect(Rect2(tag.position, Vector2(tag.size.x, 2.0)), ELEMENT_INK.get(elemento, Color.WHITE))
	var ink: Color = Color(0.91, 0.38, 0.33) if have <= 0 else Color(0.94, 0.91, 0.84)
	room.draw_string(font, tag.position + Vector2(0, 10.0), str(mini(have, 9)), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 8, ink)


# Fim do turno: botão carmesim chapado com a ampulheta. Estados: normal, sob o mouse (mais claro),
# pressionado (desce 1 px e escurece) e indisponível (cinza).
func _draw_end_turn(font: Font, er: Rect2, hover: bool, pressed: bool, enabled: bool) -> void:
	var r := er
	if pressed:
		r.position.y += 1
	var top := Color(0.75, 0.2, 0.23)
	var bottom := Color(0.47, 0.09, 0.12)
	var ink := Color(1, 1, 1)
	if not enabled:
		top = Color(0.2, 0.19, 0.2)
		bottom = Color(0.12, 0.11, 0.12)
		ink = Color(0.5, 0.49, 0.5)
	elif pressed:
		top = top.darkened(0.25)
		bottom = bottom.darkened(0.25)
	elif hover:
		top = top.lightened(0.15)
		bottom = bottom.lightened(0.12)
	room.draw_rect(r, bottom)
	room.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55)), top)
	room.draw_line(r.position + Vector2(1, 0.75), Vector2(r.end.x - 1, r.position.y + 0.75), Color(1, 1, 1, 0.28 if enabled else 0.08), 0.5)
	room.draw_rect(r.grow(1.0), Color.BLACK, false, 1.0)
	var glass := ItemIcons.ART_SIZE  # a ampulheta da arte é estreita; o quadro é o mesmo dos outros ícones
	ItemIcons.draw(room, Rect2(r.position + Vector2(5, (r.size.y - glass) * 0.5), Vector2(glass, glass)), "ampulheta", enabled)
	room.draw_string(font, r.position + Vector2(glass + 8, 17), "FIM DO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - glass - 14, 11, ink)
	room.draw_string(font, r.position + Vector2(glass + 8, 30), "TURNO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - glass - 14, 11, ink)


func _draw_action_icon(r: Rect2, id: String, enabled: bool) -> void:
	ItemIcons.draw(room, r, id, enabled)
