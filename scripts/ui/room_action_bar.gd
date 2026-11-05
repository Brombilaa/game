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
const BAR_FILL := Color(0.035, 0.026, 0.022, 0.84)
const BAR_CRIMSON := Color(0.62, 0.09, 0.11)


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


# Moldura única: placa escura semitransparente, filete duplo de ouro velho, cantoneiras finas,
# remates góticos nas pontas e um divisor com losango carmesim antes do fim do turno.
func _draw_bar_frame(r: Rect2, end_x: float) -> void:
	room.draw_rect(r, BAR_FILL)
	room.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 0.85, 0.6, 0.06))
	room.draw_rect(r.grow(-0.5), room.party_hud.FRAME_OUTER, false, 1.0)
	room.draw_rect(r.grow(-3), Color(room.party_hud.FRAME_INNER, 0.8), false, 0.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o: Vector2 = r.position + corner * r.size
		var d := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
		room.draw_polyline(PackedVector2Array([o + Vector2(1.5, 9) * d, o + Vector2(1.5, 1.5) * d, o + Vector2(9, 1.5) * d]), room.party_hud.FRAME_ACCENT, 1.0)
		room.party_hud._draw_diamond(o + Vector2(5, 5) * d, 1.5, room.party_hud.FRAME_ACCENT)
	for side in [-1.0, 1.0]:  # remates: ponta de lança com o losango carmesim
		var c := Vector2(r.position.x if side < 0 else r.end.x, r.get_center().y)
		var tip := c + Vector2(side * 7, 0)
		room.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), tip, c + Vector2(0, 9)]), room.party_hud.FRAME_FILL)
		room.draw_polyline(PackedVector2Array([c + Vector2(0, -9), tip, c + Vector2(0, 9)]), room.party_hud.FRAME_OUTER, 1.0)
		room.party_hud._draw_diamond(c + Vector2(side * 2.5, 0), 2.5, BAR_CRIMSON)
	var x := end_x - BAR_DIVIDER * 0.5
	for dx in [-1.5, 1.5]:
		room.draw_line(Vector2(x + dx, r.position.y + 6), Vector2(x + dx, r.end.y - 6), Color(room.party_hud.FRAME_INNER, 0.9), 0.5)
	room.party_hud._draw_diamond(Vector2(x, r.get_center().y), 4.5, room.party_hud.FRAME_OUTER)
	room.party_hud._draw_diamond(Vector2(x, r.get_center().y), 3.0, BAR_CRIMSON)
	room.party_hud._draw_diamond(Vector2(x, r.position.y + 6), 1.5, room.party_hud.FRAME_ACCENT)
	room.party_hud._draw_diamond(Vector2(x, r.end.y - 6), 1.5, room.party_hud.FRAME_ACCENT)


# Faixa de PA sobre a borda de cima da barra: medalhão, trilho fino e uma gema lapidada por PA.
# Gema acesa = PA disponível; soquete escuro = PA gasto; a próxima a ser gasta pulsa de leve.
func _draw_pa_strip(at: Vector2, total: int, left: int) -> void:
	var step := 15.0
	var end_x := at.x + 22.0 + total * step
	room.draw_rect(Rect2(Vector2(at.x, at.y - 1.5), Vector2(end_x - at.x, 3)), Color(0.035, 0.026, 0.022))
	room.draw_line(Vector2(at.x, at.y - 1.5), Vector2(end_x, at.y - 1.5), room.party_hud.FRAME_INNER, 0.5)
	room.draw_line(Vector2(at.x, at.y + 1.5), Vector2(end_x, at.y + 1.5), room.party_hud.FRAME_INNER, 0.5)
	room.party_hud._draw_diamond(Vector2(end_x + 2, at.y), 2.0, room.party_hud.FRAME_OUTER)
	room.draw_circle(at, 7.5, Color(0.035, 0.026, 0.022))
	room.draw_arc(at, 7.0, 0, TAU, 24, room.party_hud.FRAME_OUTER, 1.0)
	room.draw_arc(at, 4.5, 0, TAU, 16, Color(room.party_hud.FRAME_INNER, 0.8), 0.5)
	room.party_hud._draw_diamond(at, 2.5, BAR_CRIMSON)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	for n in total:
		var c := Vector2(at.x + 20.0 + n * step, at.y)
		room.party_hud._draw_diamond(c, 6.5, Color(0.035, 0.026, 0.022))
		room.party_hud._draw_diamond(c, 5.5, room.party_hud.FRAME_OUTER if n < left else room.party_hud.FRAME_INNER)
		if n < left:
			if n == left - 1:
				room.party_hud._draw_diamond(c, 8.0 + pulse, Color(room.party_hud.FRAME_ACCENT, 0.12 + 0.1 * pulse))
			_draw_gem(c, 4.5)
		else:
			room.party_hud._draw_diamond(c, 4.5, Color(0.09, 0.05, 0.045))
			room.party_hud._draw_diamond(c, 1.5, Color(BAR_CRIMSON, 0.45))


# Gema dourada lapidada: faces claras em cima à esquerda, escuras embaixo, brilho no topo.
func _draw_gem(c: Vector2, r: float) -> void:
	var top := c + Vector2(0, -r)
	var right := c + Vector2(r, 0)
	var bottom := c + Vector2(0, r)
	var left := c + Vector2(-r, 0)
	var mid := c + Vector2(-0.6, -0.6)
	room.draw_colored_polygon(PackedVector2Array([top, mid, left]), Color(1.0, 0.9, 0.6))
	room.draw_colored_polygon(PackedVector2Array([top, right, mid]), room.party_hud.FRAME_ACCENT)
	room.draw_colored_polygon(PackedVector2Array([left, mid, bottom]), Color(0.72, 0.52, 0.22))
	room.draw_colored_polygon(PackedVector2Array([mid, right, bottom]), Color(0.5, 0.33, 0.13))
	room.draw_rect(Rect2(c + Vector2(-1.5, -2.5), Vector2(1, 1)), Color(1, 1, 0.9, 0.9))


# Casa de ação: fundo escuro, filete de ouro velho e o ícone em pixel art no centro.
# Selecionada: ouro forte com halo; sob o mouse: filete mais claro; indisponível: ícone apagado.
func _draw_slot(r: Rect2, slot: Array, selected: bool, hover: bool) -> void:
	var enabled: bool = slot[3]
	room.draw_rect(r, Color(0.055, 0.042, 0.035, 0.96))
	room.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, r.size.y * 0.45)), Color(1, 0.9, 0.7, 0.04))
	room.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 4), Vector2(r.size.x - 2, 3)), Color(0, 0, 0, 0.35))
	# Contornos: filete externo de 2 px da janela (1.0) e interno de 1 px (0.5), sempre nas mesmas
	# posições para as casas não parecerem de espessuras diferentes; a selecionada só muda de cor.
	if selected:
		room.draw_rect(r.grow(1.25), Color(room.party_hud.FRAME_ACCENT, 0.35), false, 0.5)
		room.draw_rect(r.grow(-0.5), Color(1.0, 0.85, 0.5), false, 1.0)
		room.draw_rect(r.grow(-2.75), Color(room.party_hud.FRAME_ACCENT, 0.6), false, 0.5)
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			room.party_hud._draw_diamond(r.position + corner * r.size, 1.75, Color(1.0, 0.85, 0.5))
	else:
		room.draw_rect(r.grow(-0.5), room.party_hud.FRAME_OUTER.lightened(0.25) if hover else Color(room.party_hud.FRAME_OUTER, 0.9), false, 1.0)
		room.draw_rect(r.grow(-2.75), Color(room.party_hud.FRAME_INNER, 0.6), false, 0.5)
	if hover:
		room.draw_rect(r.grow(-3), Color(1, 0.9, 0.7, 0.07))
	_draw_action_icon(r, slot[0], enabled)
	if not enabled:
		room.draw_rect(r.grow(-1), Color(0.02, 0.015, 0.012, 0.35))


# Fim do turno: placa carmesim com a ampulheta em pixel art. Estados: normal, sob o mouse,
# pressionado (desce 1 px e escurece) e indisponível (cinza).
func _draw_end_turn(font: Font, er: Rect2, hover: bool, pressed: bool, enabled: bool) -> void:
	var r := er
	if pressed:
		r.position.y += 1
	var fill := Color(0.24, 0.04, 0.05, 0.95)
	var edge := BAR_CRIMSON
	var ink := Color(0.96, 0.84, 0.72)
	if not enabled:
		fill = Color(0.1, 0.08, 0.07, 0.9)
		edge = Color(0.3, 0.26, 0.22)
		ink = Color(0.45, 0.4, 0.35)
	elif pressed:
		fill = Color(0.16, 0.025, 0.03, 0.95)
	elif hover:
		fill = Color(0.34, 0.06, 0.07, 0.95)
		edge = Color(0.86, 0.2, 0.2)
	room.draw_rect(r, fill)
	room.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, r.size.y * 0.45)), Color(1, 0.5, 0.4, 0.06 if not pressed else 0.0))
	room.draw_rect(r.grow(-0.5), edge, false, 1.0)
	room.draw_rect(r.grow(-2.5), Color(room.party_hud.FRAME_ACCENT, 0.45) if enabled else Color(edge, 0.5), false, 0.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		room.party_hud._draw_diamond(r.position + corner * r.size, 2.0, edge.lightened(0.2))
	var glass := ItemIcons.ART_SIZE  # a ampulheta da arte é estreita; o quadro é o mesmo dos outros ícones
	ItemIcons.draw(room, Rect2(r.position + Vector2(5, (r.size.y - glass) * 0.5), Vector2(glass, glass)), "ampulheta", enabled)
	room.draw_string(font, r.position + Vector2(glass + 8, 17), "FIM DO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - glass - 14, 11, ink)
	room.draw_string(font, r.position + Vector2(glass + 8, 30), "TURNO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - glass - 14, 11, ink)


func _draw_action_icon(r: Rect2, id: String, enabled: bool) -> void:
	ItemIcons.draw(room, r, id, enabled)
