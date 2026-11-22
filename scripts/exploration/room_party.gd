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
	Dicas.marcar("agachar")
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


# Posição de cada seguidor: atrás do líder (oposto ao rumo), a distância fixa, com ângulo variando para não formar
# fila rígida. A variação é sorteada uma vez por seguidor (antes mudava a cada clique e o grupo embaralhava). Com
# `suave` (clique para andar), um rumo a menos de 90° do anterior mantém os lugares: ninguém dá a volta no líder à toa.
func _reset_follow_offsets(heading: Vector2, suave := false) -> void:
	var rumo := heading.normalized() if heading.length() > 0.1 else Vector2.RIGHT
	if suave and _rumo_formacao != Vector2.ZERO and rumo.dot(_rumo_formacao) > 0.0 and _formacao_completa():
		return
	_rumo_formacao = rumo
	var back := -rumo
	var k := 0
	for m in room.party:
		if m == room.player:
			continue
		if not _jitter.has(m):
			_jitter[m] = room.follow_rng.randf_range(-TestRoom.FOLLOW_SPREAD, TestRoom.FOLLOW_SPREAD) * 0.5
		var side := (k % 2) * 2 - 1  # alterna os lados
		var angle := side * 0.35 * (k + 1) + float(_jitter[m])
		room.follow_offsets[m] = back.rotated(angle) * TestRoom.FOLLOW_DISTANCE
		_slots.erase(m)  # o lugar livre é recalculado na próxima rota
		k += 1


var _rumo_formacao := Vector2.ZERO  # rumo em que os lugares foram montados
var _jitter := {}  # seguidor -> variação do ângulo (sorteada uma vez)
var _slots := {}  # seguidor -> lugar livre escolhido {"alvo": Vector2 (líder + deslocamento), "livre": Vector2}
var _espera := {}  # seguidor -> segundos desde a última rota
var _preso := {}  # seguidor -> segundos parado por outro personagem no caminho
var _pausada := {}  # seguidor -> rota guardada enquanto espera alguém passar


func _formacao_completa() -> bool:
	for m in room.party:
		if m != room.player and not room.follow_offsets.has(m):
			return false
	return true


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


const FOLLOW_REPATH := 0.3  # s: no máximo uma rota nova por seguidor a cada 0,3 s (o líder anda 180 px/s)
const FOLLOW_ARRIVE := 10.0  # px: chegou ao lugar, para
const FOLLOW_STALE := 40.0  # px: a rota só é refeita quando o lugar andou mais que isto
const FOLLOW_BLOCKED := 0.35  # s esperando alguém sair da frente antes de pedir rota que contorne


# Seguidores (GDD: grupo espalhado a distância fixa do líder; ninguém atravessa outro personagem; contorna). Rota
# nova no máximo a cada FOLLOW_REPATH, lugar sempre fora de paredes, e quem encontra outro personagem na frente
# espera e depois contorna, em vez de atravessar.
func _update_followers(delta: float) -> void:
	for m in room.party:
		if m == room.player or not m.is_alive() or room.unlinked.has(m):
			continue
		_espera[m] = float(_espera.get(m, FOLLOW_REPATH)) + delta
		var alvo: Vector2 = room.player.pos + room.follow_offsets.get(m, Vector2.LEFT * TestRoom.FOLLOW_DISTANCE)
		var route: PackedVector2Array = room.follow_paths.get(m, _pausada.get(m, PackedVector2Array()))
		var slot: Dictionary = _slots.get(m, {})
		var fim := route[route.size() - 1] if not route.is_empty() else m.pos
		var velho := route.is_empty() or fim.distance_to(alvo) > FOLLOW_STALE
		# Sem rota (chegou ao lugar antigo) o seguidor já corrige para o lugar novo; com rota, só a cada FOLLOW_REPATH.
		if velho and float(_espera[m]) >= (0.1 if route.is_empty() else FOLLOW_REPATH):
			if slot.is_empty() or (slot["alvo"] as Vector2).distance_to(alvo) > FOLLOW_STALE * 0.5:
				slot = {"alvo": alvo, "livre": _slot_livre(m, alvo)}
				_slots[m] = slot
			var goal: Vector2 = slot["livre"]
			if m.pos.distance_to(goal) > FOLLOW_ARRIVE:
				_espera[m] = 0.0
				route = _rota_seguidor(m, goal)
				if route.is_empty():
					# Ainda sem rota: ele está dentro de uma colisão do cenário (Léo, 08/11: "Miguel tá travado", nasceu
					# dentro dos pneus). Sai para o ponto livre mais próximo e tenta de novo no próximo quadro.
					var livre := _ponto_livre_perto(m)
					if livre != m.pos:
						m.pos = livre
						room.queue_redraw()
				else:
					route.remove_at(0)
			elif not route.is_empty():
				route = PackedVector2Array()  # o líder parou e o lugar já está aqui
		if route.is_empty():
			room.follow_paths.erase(m)
			_pausada.erase(m)
			_preso.erase(m)
			continue
		var step := room._iso(route[0]) - room._iso(m.pos)
		var depois := m.pos.move_toward(route[0], TestRoom.SPEED * delta)
		var barreira := _quem_bloqueia(m, depois)
		if barreira != null:
			# Alguém (vivo ou caído) está na frente: espera; se demorar, a próxima rota já o conta como obstáculo.
			var t := float(_preso.get(m, 0.0)) + delta
			_preso[m] = t
			_pausada[m] = route
			room.follow_paths.erase(m)  # parado, não anda no lugar
			if t >= FOLLOW_BLOCKED:
				_pausada.erase(m)
				_preso.erase(m)
				_espera[m] = FOLLOW_REPATH
				_slots.erase(m)
				var rota_nova := _rota_seguidor(m, route[route.size() - 1])
				if not rota_nova.is_empty():
					rota_nova.remove_at(0)
					room.follow_paths[m] = rota_nova
			continue
		_preso.erase(m)
		_pausada.erase(m)
		room.facing8[m] = CharacterSheet.dir_from_vector(step)
		var before := room._iso(m.pos)
		m.pos = depois
		room.walk_dist[m] = room.walk_dist.get(m, 0.0) + before.distance_to(room._iso(m.pos))
		if m.pos.is_equal_approx(route[0]):
			route.remove_at(0)
		if route.is_empty():
			room.follow_paths.erase(m)
		else:
			room.follow_paths[m] = route
		room.queue_redraw()


# Rota do seguidor até `goal`; sem rota com os outros personagens como obstáculo, tenta só com paredes e coberturas
# (dois seguidores encostados deixavam um dentro do obstáculo do outro, parado para sempre).
func _rota_seguidor(m: Combatant, goal: Vector2) -> PackedVector2Array:
	var route: PackedVector2Array = room.pathfinder.find_path(m.pos, goal, room._obstacles(m), m.radius)
	if route.is_empty():
		route = room.pathfinder.find_path(m.pos, goal, room._obstacles(m, false), m.radius)
	return route


# O lugar na formação pode cair dentro de parede ou móvel (porta, canto): usa o ponto livre mais próximo dele.
func _slot_livre(m: Combatant, alvo: Vector2) -> Vector2:
	var obst: Array[Rect2] = room._obstacles(m, false)
	if not _dentro(alvo, m.radius, obst):
		return alvo
	for raio in range(8, 121, 8):
		for k in 16:
			var q := alvo + Vector2.RIGHT.rotated(TAU * k / 16.0) * raio
			if not _dentro(q, m.radius, obst):
				return q
	return room.player.pos  # nada livre perto: vai até o líder


func _dentro(p: Vector2, raio: float, obst: Array[Rect2]) -> bool:
	for o in obst:
		if o.grow(raio).has_point(p):
			return true
	return false


# Outro personagem (do grupo, vivo ou caído, ou inimigo) que `m` tocaria indo para `depois` sem já estar tocando nele.
func _quem_bloqueia(m: Combatant, depois: Vector2) -> Combatant:
	for u in room._living_units():
		if u == m:
			continue
		var folga := (m.radius + u.radius) * 0.9
		var d := depois.distance_to(u.pos)
		if d < folga and d < m.pos.distance_to(u.pos):
			return u
	return null


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
