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


# Ações do rodapé no turno do jogador: [ícone, título, detalhe, ativa]. A arma secundária
# aparece apagada quando faltam PA para a troca.
func _action_slots() -> Array:
	var data := room.cfg.game_data
	var kit := data.get_entry("itens", "kit_primeiros_socorros")
	var id := str(room.player.weapon["id"])
	var slots := [[id, str(data.get_entry("armas", id).get("nome", id)), "Atacar · %d PA · clique no inimigo" % int(room.player.weapon["pa_cost"]), true]]
	var second := room._reserve_id()
	if second != "":
		slots.append([second, str(data.get_entry("armas", second).get("nome", second)), "Trocar arma · %d PA · tecla Q" % room.SWAP_PA, room.player.pa >= room.SWAP_PA])
	slots.append(["kit", "Kit de primeiros socorros", "Reanimar · %d PA · restam %d" % [int(kit["custo_pa_combate"]), room.inventory.count(room.KIT_ID)], room.inventory.count(room.KIT_ID) > 0])
	slots.append(["atrasar", "Atrasar", "Age depois na rodada · tecla D", true])
	return slots


# Posição do kit entre as casas da barra (depois da arma e da reserva, se houver).
func kit_index() -> int:
	return 2 if room._reserve_id() != "" else 1


func _bar_width(n: int) -> float:
	return BAR_PAD * 2 + n * BAR_SLOT + (n - 1) * BAR_GAP + BAR_DIVIDER + BAR_END_W


# Moldura inteira da barra, em pixels da tela.
func _bar_rect(n: int) -> Rect2:
	var h := BAR_SLOT + BAR_PAD * 2
	return Rect2(Vector2(roundf(480 - _bar_width(n) * 0.5), BAR_BOTTOM - h), Vector2(_bar_width(n), h))


func _action_rect(k: int, n: int) -> Rect2:
	var bar := _bar_rect(n)
	return Rect2(bar.position + Vector2(BAR_PAD + k * (BAR_SLOT + BAR_GAP), BAR_PAD), Vector2(BAR_SLOT, BAR_SLOT))


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
	var tip := -1
	for k in n:
		var screen := _action_rect(k, n)
		var hover := screen.has_point(mouse)
		if hover:
			tip = k
		_draw_slot(Rect2(to_world * screen.position, screen.size), slots[k], k == 0, hover)
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
func _draw_slot(r: Rect2, slot: Array, selected: bool, hover: bool) -> void:
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
