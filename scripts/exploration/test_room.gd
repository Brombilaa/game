extends Node2D
# Sala de teste: exploração com clique para mover, uma porta, inimigos e coberturas.
# A rota contorna obstáculos via Pathfinder; destino inacessível é ignorado.
# Inimigo que vê o personagem (alcance + linha de visão) inicia o combate na hora.
# Combate por turnos (TurnManager + CombatRules): no turno do agente, clique no chão
# move (gasta PA), clique no inimigo ataca, clique na cobertura mira a estrutura,
# Espaço passa o turno e D atrasa. R reinicia a sala.

enum Mode { EXPLORATION, COMBAT, GAME_OVER }

signal move_finished

const SPEED := 180.0
const STAND_OFFSET := 6.0
const PERCEPTION_RANGE := 300.0  # provisório: alcance de percepção está PENDENTE no GDD
const ENEMY_STEP_SECONDS := 0.4
const POPUP_SECONDS := 1.2

var walls: Array[Rect2] = [
	Rect2(0, 0, 1280, 16),
	Rect2(0, 704, 1280, 16),
	Rect2(0, 0, 16, 720),
	Rect2(1264, 0, 16, 720),
	Rect2(600, 0, 24, 300),
	Rect2(600, 420, 24, 300),
	Rect2(400, 200, 120, 40),
]
var door := Rect2(600, 300, 24, 120)
# Resistência da estrutura por material (valores provisórios).
var covers: Array = [
	Cover.new(Rect2(300, 450, 40, 40), "partial", 20),
	Cover.new(Rect2(960, 300, 40, 40), "partial", 20),
	Cover.new(Rect2(720, 520, 80, 24), "full", 60),
]

var cfg := CombatConfig.load_file()
var rules := CombatRules.new(cfg)
var player: Combatant = cfg.make_unit("agente", "Agente", Vector2(160, 360))
var enemies: Array[Combatant] = [
	cfg.make_enemy("cultista_teste", Vector2(800, 360)),
	cfg.make_enemy("atirador_teste", Vector2(1100, 200)),
]
var turns: TurnManager

var path := PackedVector2Array()
var moving_unit: Combatant = null
var pending_door := false
var door_open := false
var pathfinder := Pathfinder.new()
var mode := Mode.EXPLORATION
var busy := false  # animação ou turno inimigo em andamento: entrada do jogador ignorada
var popups: Array = []  # textos de acerto/erro/dano flutuando sobre as unidades
var hud := CombatHud.new()
var audio := AudioDirector.new()


func _ready() -> void:
	add_child(hud)
	add_child(audio)
	hud.end_turn_requested.connect(_player_pass)
	audio.play_music("exploration")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.pressed and event.keycode == KEY_SPACE:
			_player_pass()
		elif event.pressed and event.keycode == KEY_D:
			_player_delay()
		return
	if event is InputEventMouseMotion and mode == Mode.COMBAT:
		queue_redraw()  # atualiza a prévia de chance/custo sob o cursor
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == Mode.EXPLORATION:
			_order_move(get_global_mouse_position())
		elif mode == Mode.COMBAT:
			_combat_click(get_global_mouse_position())


func _order_move(click: Vector2) -> void:
	var wants_door := false
	if not door_open and door.grow(12).has_point(click):
		# Clique na porta: andar até o lado em que o personagem está e abrir ao chegar.
		var stand_x := door.position.x - player.radius - STAND_OFFSET if player.pos.x < door.get_center().x else door.end.x + player.radius + STAND_OFFSET
		click = Vector2(stand_x, door.get_center().y)
		wants_door = true
	var new_path := pathfinder.find_path(player.pos, click, _obstacles(player), player.radius)
	if new_path.is_empty():
		return  # destino inacessível
	# Novo destino cancela a interação pendente e recalcula a rota.
	pending_door = wants_door
	_start_move(player, new_path)


# Paredes, porta fechada, coberturas de pé e as outras unidades vivas.
func _obstacles(mover: Combatant = null) -> Array[Rect2]:
	var obstacles := _sight_blockers()
	for c: Cover in covers:
		if not c.is_destroyed():
			obstacles.append(c.rect)
	for u in _living_units():
		if u != mover:
			obstacles.append(Rect2(u.pos - Vector2(u.radius, u.radius), Vector2(u.radius, u.radius) * 2))
	return obstacles


# Bloqueiam linha de visão: paredes e porta fechada. Coberturas não.
func _sight_blockers() -> Array[Rect2]:
	var blockers: Array[Rect2] = []
	blockers.append_array(walls)
	if not door_open:
		blockers.append(door)
	return blockers


func _living_units() -> Array[Combatant]:
	var out: Array[Combatant] = []
	if player.is_alive():
		out.append(player)
	for e in enemies:
		if e.is_alive():
			out.append(e)
	return out


func _start_move(unit: Combatant, new_path: PackedVector2Array) -> void:
	moving_unit = unit
	path = new_path
	path.remove_at(0)


func _process(delta: float) -> void:
	if not popups.is_empty():
		for p in popups:
			p.time -= delta
		popups = popups.filter(func(p: Dictionary) -> bool: return p.time > 0.0)
		queue_redraw()
	if moving_unit and not path.is_empty():
		moving_unit.pos = moving_unit.pos.move_toward(path[0], SPEED * delta)
		if moving_unit.pos.is_equal_approx(path[0]):
			path.remove_at(0)
		if path.is_empty():
			moving_unit = null
			move_finished.emit()
		queue_redraw()
	if mode != Mode.EXPLORATION:
		return
	if path.is_empty() and pending_door:
		pending_door = false
		door_open = true
		audio.play_sfx("door_open")
		queue_redraw()
	_check_detection()


# Inimigo detecta o personagem se ele estiver no alcance e com linha de visão livre
# (parede e porta fechada bloqueiam). Detecção inicia o combate imediatamente.
func _check_detection() -> void:
	for e in enemies:
		if not e.is_alive() or e.pos.distance_to(player.pos) > PERCEPTION_RANGE:
			continue
		if Pathfinder.has_line_of_sight(e.pos, player.pos, _sight_blockers()):
			_start_combat()
			return


# Monta os participantes (todos os inimigos vivos da sala) e ordena a iniciativa.
func _start_combat() -> void:
	mode = Mode.COMBAT
	path = PackedVector2Array()
	moving_unit = null
	pending_door = false
	hud.on_combat_started()
	audio.on_combat_started()
	turns = TurnManager.new(int(cfg.value("pa_per_turn")))
	turns.turn_started.connect(_on_turn_started)
	turns.turn_ended.connect(func(_u: Combatant) -> void: hud.on_turn_ended())
	turns.combat_ended.connect(_on_combat_ended)
	var units: Array[Combatant] = [player]
	for e in enemies:
		if e.is_alive():
			units.append(e)
	turns.start(units)
	queue_redraw()


func _on_turn_started(unit: Combatant) -> void:
	queue_redraw()
	if unit.side == Combatant.Side.PLAYER:
		hud.on_turn_started(unit.name, unit.pa, turns.turn_pa(player))
		audio.play_sfx("turn_start")
	else:
		_run_enemy_turn.call_deferred(unit)


func _on_combat_ended(result: TurnManager.Result) -> void:
	hud.on_turn_ended()
	audio.on_combat_ended()
	if result == TurnManager.Result.VICTORY:
		mode = Mode.EXPLORATION
		hud.on_combat_ended()
	else:
		mode = Mode.GAME_OVER
		hud.show_notice("Game Over")
	queue_redraw()


# --- Turno do jogador --------------------------------------------------------

func _player_ready() -> bool:
	return mode == Mode.COMBAT and not busy and turns.is_turn_of(player)


func _combat_click(click: Vector2) -> void:
	if not _player_ready():
		return
	var target := _enemy_at(click)
	if target:
		_show_attack(player, target, rules.attack(player, target, _sight_blockers(), covers))
		_after_player_action()
		return
	var cover := _cover_at(click)
	if cover:
		var r := rules.attack_cover(player, cover, _sight_blockers())
		if not r.ok:
			_reject(r.reason)
		else:
			var center := cover.rect.get_center()
			_popup(center, ("-%d" % r.damage if r.hit else "Errou") + (" DESTRUÍDA" if r.destroyed else ""))
		_after_player_action()
		return
	await _player_move(click)


func _player_move(click: Vector2) -> void:
	var full := pathfinder.find_path(player.pos, click, _obstacles(player), player.radius)
	if full.is_empty():
		return  # destino inacessível
	var plan := rules.plan_move(full, player.pa)
	if plan.cost == 0:
		return
	if plan.cost > player.pa or not turns.spend(player, plan.cost):
		_reject("no_pa")
		return
	hud.on_pa_changed(player.pa, turns.turn_pa(player))
	busy = true
	_start_move(player, plan.path)
	await move_finished
	busy = false
	_after_player_action()


func _after_player_action() -> void:
	if turns.is_turn_of(player):
		hud.on_pa_changed(player.pa, turns.turn_pa(player))
	turns.action_done()
	queue_redraw()


func _player_pass() -> void:
	if _player_ready():
		turns.pass_turn()


func _player_delay() -> void:
	if not _player_ready():
		return
	if not turns.delay():
		_reject("requirement")
	else:
		hud.show_notice("Atrasou")


func _reject(reason: String) -> void:
	hud.on_action_rejected(reason)
	audio.play_sfx("action_rejected")


func _enemy_at(p: Vector2) -> Combatant:
	for e in enemies:
		if e.is_alive() and e.pos.distance_to(p) <= e.radius + 4.0:
			return e
	return null


func _cover_at(p: Vector2) -> Cover:
	for c: Cover in covers:
		if not c.is_destroyed() and c.rect.has_point(p):
			return c
	return null


# --- Turno do inimigo --------------------------------------------------------
# IA provisória: ataca enquanto puder; se não puder, anda em direção ao agente até
# ficar a meio alcance da arma e tenta de novo. Comportamento por inimigo é PENDENTE.

func _run_enemy_turn(unit: Combatant) -> void:
	busy = true
	while mode == Mode.COMBAT and turns.is_turn_of(unit):
		await get_tree().create_timer(ENEMY_STEP_SECONDS).timeout
		if not turns.is_turn_of(unit):
			break
		if rules.attack_blocker(unit, player, _sight_blockers()) == "":
			_show_attack(unit, player, rules.attack(unit, player, _sight_blockers(), covers))
			turns.action_done()
			continue
		if not await _enemy_advance(unit):
			turns.end_turn()
	busy = false
	queue_redraw()


# Retorna false se não houver como se aproximar.
func _enemy_advance(unit: Combatant) -> bool:
	var stand := player.pos.move_toward(unit.pos, player.radius + unit.radius + 2.0 + float(unit.weapon["max_range"]) * 0.5)
	var full := pathfinder.find_path(unit.pos, stand, _obstacles(unit), unit.radius)
	if full.size() < 2:
		return false
	var plan := rules.plan_move(full, unit.pa)
	if plan.cost == 0 or not turns.spend(unit, plan.cost):
		return false
	_start_move(unit, plan.path)
	await move_finished
	turns.action_done()
	return true


# --- Feedback ----------------------------------------------------------------

func _show_attack(attacker: Combatant, target: Combatant, r: Dictionary) -> void:
	if not r.ok:
		_reject(r.reason)
		return
	var text := "Errou"
	if r.blocked:
		text = "Bloqueado"
	elif r.hit:
		text = ("-%d CRÍTICO" if r.crit else "-%d") % r.damage
	_popup(target.pos, text)
	if not target.is_alive():
		_popup(target.pos + Vector2(0, 18), "Abatido" if target.side == Combatant.Side.ENEMY else "Caiu")
	queue_redraw()


func _popup(at: Vector2, text: String) -> void:
	popups.append({"pos": at + Vector2(-20, -24 - 16 * popups.size()), "text": text, "time": POPUP_SECONDS})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.12, 0.14))
	for w in walls:
		draw_rect(w, Color(0.35, 0.35, 0.4))
	if door_open:
		draw_rect(door, Color(0.4, 0.6, 0.4, 0.5))
	else:
		draw_rect(door, Color(0.55, 0.35, 0.2))
	for c: Cover in covers:
		if c.is_destroyed():
			draw_rect(c.rect, Color(0.4, 0.35, 0.3, 0.25), false, 1.0)
			continue
		draw_rect(c.rect, Color(0.5, 0.42, 0.3) if c.kind == "partial" else Color(0.55, 0.55, 0.6))
		draw_string(font, c.rect.position + Vector2(2, 14), "%s %d" % ["P" if c.kind == "partial" else "C", c.hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
	for e in enemies:
		if not e.is_alive():
			continue
		if mode == Mode.EXPLORATION:
			draw_arc(e.pos, PERCEPTION_RANGE, 0.0, TAU, 96, Color(0.9, 0.2, 0.2, 0.25), 1.0)
		_draw_unit(e, Color(0.85, 0.2, 0.2))
	if player.is_alive():
		_draw_unit(player, Color(0.3, 0.6, 1.0))
	if mode == Mode.COMBAT:
		_draw_preview(font)
		draw_string(font, Vector2(32, 690), "Rodada %d  |  Espaço passa, D atrasa, R reinicia" % turns.round_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))
	elif mode == Mode.GAME_OVER:
		draw_string(font, Vector2(32, 690), "Game Over (R reinicia)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.5, 0.5))
	for p in popups:
		draw_string(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 0.7, clampf(p.time / POPUP_SECONDS * 2.0, 0.0, 1.0)))


func _draw_unit(u: Combatant, color: Color) -> void:
	if turns and u == turns.current:
		draw_arc(u.pos, u.radius + 5, 0.0, TAU, 32, Color(1, 0.85, 0.3), 2.0)
	draw_circle(u.pos, u.radius, color)
	if mode != Mode.EXPLORATION:
		var bar := Rect2(u.pos + Vector2(-14, -u.radius - 9), Vector2(28, 4))
		draw_rect(bar, Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(u.pv) / u.max_pv, bar.size.y)), Color(0.3, 0.85, 0.35))


# Prévia sob o cursor no turno do agente: chance de acerto no inimigo ou custo do movimento.
func _draw_preview(font: Font) -> void:
	if not _player_ready():
		return
	var mouse := get_global_mouse_position()
	var target := _enemy_at(mouse)
	var text := ""
	if target:
		var blocker := rules.attack_blocker(player, target, _sight_blockers())
		if blocker != "":
			text = HudText.rejection_message(blocker)
		else:
			text = "%d%%" % roundi(rules.hit_chance(player, target) * 100.0)
			var c := rules.cover_between(player.pos, target, covers)
			if c:
				text += " (cobertura %s)" % ("parcial" if c.kind == "partial" else "completa")
		draw_line(player.pos, target.pos, Color(1, 1, 1, 0.3), 1.0)
	elif _cover_at(mouse) == null:
		var route := pathfinder.find_path(player.pos, mouse, _obstacles(player), player.radius)
		if route.is_empty():
			text = "Inacessível"
		else:
			var cost := rules.move_cost(CombatRules.path_length(route))
			text = "%d PA" % cost if cost <= player.pa else "%d PA (parcial)" % player.pa
	if text != "":
		draw_string(font, mouse + Vector2(14, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
