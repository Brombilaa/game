class_name EnemyAi
extends RefCounted

# IA provisória do turno inimigo, extraída de test_room.gd (M5). Ataca enquanto puder; se não puder,
# anda em direção ao agente até ficar a meio alcance da arma e tenta de novo. A sala (`room`) fornece
# o estado (grupo, turnos, regras, obstáculos) e a encenação (movimento e ataque animados).

const STEP_SECONDS := 0.4

var room  # a sala de combate (test_room.gd); sem tipo para não criar dependência circular
var _gap_jumped := false  # o inimigo da vez já saltou por falta de rota neste turno


func _init(owner_room) -> void:
	room = owner_room


func run_turn(unit: Combatant) -> void:
	room.busy = true
	_gap_jumped = false
	while room.mode == room.Mode.COMBAT and room.turns.is_turn_of(unit):
		await room.get_tree().create_timer(STEP_SECONDS).timeout
		if not room.turns.is_turn_of(unit):
			break
		var target := pick_target(unit)
		if target == null:
			room.turns.end_turn()
			break
		if room.rules.attack_blocker(unit, target, room._sight_blockers(), room.covers) == "":
			room._show_attack(unit, target, room.rules.attack(unit, target, room._sight_blockers(), room.covers))
			while room.fx.animating() and room.mode == room.Mode.COMBAT:
				await room.get_tree().process_frame  # a vez só passa depois da animação inteira
			room.turns.action_done()
			continue
		if not await advance(unit, target):
			room.turns.end_turn()
	room.busy = false
	room.queue_redraw()


# Alvo do inimigo (P8, provisório): o membro de pé com menor "distância ajustada" pela ameaça. Quem está
# com metade do PV ou menos, ou sem SAN, pesa como se estivesse a 60% da distância. Empate: o mais perto.
func pick_target(unit: Combatant) -> Combatant:
	var best: Combatant = null
	var best_score := INF
	for m in room.party:
		if not m.is_alive():
			continue
		var score := unit.pos.distance_to(m.pos)
		if m.pv * 2 <= m.max_pv or (m.max_san > 0 and m.san <= 0):
			score *= 0.6
		if score < best_score:
			best_score = score
			best = m
	return best


# Retorna false se não houver como se aproximar.
func advance(unit: Combatant, target: Combatant) -> bool:
	var stand := target.pos.move_toward(unit.pos, target.radius + unit.radius + 2.0 + float(unit.weapon["max_range"]) * 0.5)
	if not Pathfinder.is_free(unit.pos, room._obstacles(unit), unit.radius):
		# Preso dentro de um obstáculo (ex.: surgiu atrás da árvore): salta para o ponto livre
		# mais perto do alvo, sem gastar PA, e segue o turno de lá (Léo, 01/11/2026).
		var spot := jump_spot(unit, target)
		if spot == Vector2.INF:
			return false
		room._start_move(unit, PackedVector2Array([unit.pos, spot]))
		await room.move_finished
		return true
	var full := room.pathfinder.find_path(unit.pos, stand, room._obstacles(unit), unit.radius)
	if full.is_empty() and not _gap_jumped:
		# Sem caminho até o alvo (ex.: ponto livre fechado entre a sebe e a árvore): salta, sem gastar
		# PA, para o ponto livre mais perto do alvo de onde há caminho; se não houver, passa o turno.
		# Um salto desses por turno, para não saltar em círculos se o destino continuar sem rota.
		var out := jump_spot(unit, target, true)
		if out == Vector2.INF:
			return false
		_gap_jumped = true
		room._start_move(unit, PackedVector2Array([unit.pos, out]))
		await room.move_finished
		return true
	if full.size() < 2:
		return false
	var plan := room.rules.plan_move(full, unit.pa, unit.moved_px)
	if CombatRules.path_length(plan.path) < 1.0 or (plan.cost > 0 and not room.turns.spend(unit, plan.cost)):
		return false
	unit.moved_px += CombatRules.path_length(plan.path)
	room._start_move(unit, plan.path)
	await room.move_finished
	room.turns.action_done()
	return true


# Ponto livre perto de `unit` de onde há caminho até o alvo; entre os candidatos, o mais perto do
# alvo (na prática, o lado da frente do obstáculo). Vector2.INF se não houver.
# Com `strict`, só vale ponto com caminho até o alvo (evita saltar em círculos sem progresso).
func jump_spot(unit: Combatant, target: Combatant, strict := false) -> Vector2:
	return spot_toward(unit, target.pos, target.radius + unit.radius + 2.0, strict)


# Igual, para um ponto qualquer `goal`; `gap` é a folga que fica entre o ponto de parada e o objetivo.
func spot_toward(unit: Combatant, goal: Vector2, gap: float, strict := false) -> Vector2:
	var obstacles := room._obstacles(unit)
	var candidates: Array[Vector2] = []
	for ring in range(1, 26):
		for k in 16:
			var spot := unit.pos + Vector2.from_angle(TAU * k / 16.0) * ring * 8.0
			if Pathfinder.is_free(spot, obstacles, unit.radius):
				candidates.append(spot)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(goal) < b.distance_to(goal))
	for spot in candidates.slice(0, 40 if strict else 12):
		var stand := goal.move_toward(spot, gap)
		if room.pathfinder.find_path(spot, stand, obstacles, unit.radius).size() > 1:
			return spot
	if strict or candidates.is_empty():
		return Vector2.INF
	return candidates[0]

