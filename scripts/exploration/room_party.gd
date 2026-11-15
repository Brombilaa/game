class_name RoomParty
extends RefCounted
# Grupo da sala (extraído de test_room.gd): troca do controlado, agachar junto, seguidores espalhados
# atrás do líder, corrente do grupo (soltar/prender) e cliques nas fichas do HUD.

var room: TestRoom  # a sala de teste (test_room.gd) ou uma área derivada (parque, local3d)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Agachar (tecla C). Léo, 13/11: se o time está junto, todos agacham e levantam juntos. "Junto" = o líder e os
# seguidores presos na corrente; quem foi solto da corrente (`unlinked`) mantém a postura própria. Em combate
# a postura continua valendo e a tecla C troca a de quem está na vez (grátis, sem PA; provisório).
func _toggle_crouch() -> void:
	var stance := not room.player.crouched
	room.player.crouched = stance
	if room.mode == TestRoom.Mode.EXPLORATION:
		for m in room.party:
			if m != room.player and m.is_alive() and not room.unlinked.has(m):
				m.crouched = stance
	room.queue_redraw()


# Troca o personagem controlado (só na exploração; no combate manda a ordem dos turnos).
func _switch_to(m: Combatant) -> void:
	if room.mode != TestRoom.Mode.EXPLORATION or m == room.player or m.dead or not m.is_alive():
		return
	if room.moving_unit == room.player:
		room.path = PackedVector2Array()
		room.moving_unit = null
	room.pending_door = false
	room.follow_paths.erase(m)
	room.unlinked.erase(m)  # o novo líder volta à corrente
	room.player = m
	_reset_follow_offsets(Vector2.RIGHT)
	room.queue_redraw()


# Sorteia a posição de cada seguidor: atrás do líder (oposto ao rumo), a distância fixa,
# com ângulo variando para não formar fila rígida.
func _reset_follow_offsets(heading: Vector2) -> void:
	var back := -heading.normalized() if heading.length() > 0.1 else Vector2.LEFT
	var k := 0
	for m in room.party:
		if m == room.player:
			continue
		var side := (k % 2) * 2 - 1  # alterna os lados
		var angle := side * 0.35 * (k + 1) + room.follow_rng.randf_range(-TestRoom.FOLLOW_SPREAD, TestRoom.FOLLOW_SPREAD) * 0.5
		room.follow_offsets[m] = back.rotated(angle) * TestRoom.FOLLOW_DISTANCE
		k += 1


# Solta o seguidor da corrente (ele para de acompanhar o líder) ou o prende de volta.
func _toggle_link(m: Combatant) -> void:
	if m == room.player:
		return
	if room.unlinked.has(m):
		room.unlinked.erase(m)
	else:
		room.unlinked[m] = true
		room.follow_paths.erase(m)
	room.queue_redraw()


# Índice do elo (entre o cartão i e o i + 1) sob o ponto da tela, ou -1.
func _link_at(screen: Vector2) -> int:
	for i in room.party.size() - 1:
		if room.party_hud.link_rect(i).has_point(screen):
			return i
	return -1


func _update_followers(delta: float) -> void:
	for m in room.party:
		if m == room.player or not m.is_alive() or room.unlinked.has(m):
			continue
		var goal: Vector2 = room.player.pos + room.follow_offsets.get(m, Vector2.LEFT * TestRoom.FOLLOW_DISTANCE)
		var route: PackedVector2Array = room.follow_paths.get(m, PackedVector2Array())
		var stale := route.is_empty() or route[route.size() - 1].distance_to(goal) > 24.0
		if stale and m.pos.distance_to(goal) > 12.0:
			route = room.pathfinder.find_path(m.pos, goal, room._obstacles(m), m.radius)
			if route.is_empty():
				# Dois seguidores se encostaram e um ficou dentro do obstáculo do outro: sem esta rota
				# de reserva (só paredes e coberturas) ele ficaria parado para sempre.
				route = room.pathfinder.find_path(m.pos, goal, room._obstacles(m, false), m.radius)
			if route.is_empty():
				# Ainda sem rota: ele está dentro de uma colisão do cenário (Léo, 08/11: "Miguel tá travado", nasceu
				# dentro dos pneus). Sai para o ponto livre mais próximo e tenta de novo no próximo quadro.
				var livre := _ponto_livre_perto(m)
				if livre != m.pos:
					m.pos = livre
					room.queue_redraw()
					continue
			if not route.is_empty():
				route.remove_at(0)
		if route.is_empty():
			room.follow_paths.erase(m)
			continue
		var step := room._iso(route[0]) - room._iso(m.pos)
		room.facing8[m] = CharacterSheet.dir_from_vector(step)
		var before := room._iso(m.pos)
		m.pos = m.pos.move_toward(route[0], TestRoom.SPEED * delta)
		room.walk_dist[m] = room.walk_dist.get(m, 0.0) + before.distance_to(room._iso(m.pos))
		if m.pos.is_equal_approx(route[0]):
			route.remove_at(0)
		room.follow_paths[m] = route
		room.queue_redraw()


# Ponto mais próximo de `m` fora das colisões do cenário (anéis de 8 em 8 px, até 96 px); sem nenhum, a própria posição.
func _ponto_livre_perto(m: Combatant) -> Vector2:
	for raio in range(8, 97, 8):
		for k in 16:
			var q := m.pos + Vector2.RIGHT.rotated(TAU * k / 16.0) * raio
			var livre := true
			for o in room._obstacles(m, false):
				if (o as Rect2).grow(m.radius).has_point(q):
					livre = false
					break
			if livre:
				return q
	return m.pos


# Medida do desenho em tamanho cheio -> pixels da ficha na escala atual.
func _k(v: float) -> float:
	return v * room.party_hud.SHEET_SCALE


func _fs(size: int) -> int:
	return maxi(roundi(size * room.party_hud.SHEET_SCALE), 8)


func _portrait_rect(i: int) -> Rect2:
	return room.party_hud.card_rect(i)


# Mouse sobre uma ficha ou sobre o rodapé de ações: sem prévia de movimento ou ataque.
func _mouse_on_hud(screen: Vector2) -> bool:
	if _portrait_at(screen) or _link_at(screen) >= 0:
		return true
	if room.mode != TestRoom.Mode.COMBAT or not room._player_ready():
		return false
	return room.action_bar._bar_rect(room.action_bar._action_slots().size()).grow(8).has_point(screen)  # a barra inteira e a faixa de PA


func _portrait_at(screen: Vector2) -> Combatant:
	for i in room.party.size():
		if _portrait_rect(i).has_point(screen):
			return room.party[i]
	return null
