extends Node2D
# Sala de teste: exploração com clique para mover, uma porta, inimigos e coberturas.
# A rota contorna obstáculos via Pathfinder; destino inacessível é ignorado.
# Inimigo que vê o personagem (alcance + linha de visão) inicia o combate na hora.
# Combate por turnos (TurnManager + CombatRules): no turno do agente, clique no chão
# move (gasta PA), clique no inimigo ataca, clique na cobertura mira a estrutura,
# Espaço passa o turno e D atrasa. R reinicia a sala. Tab troca o visual do agente (Nikolai/Miguel).
# Visual provisório: resolução interna 960×540 (DEC-2026-10-29-10), câmera segue a unidade
# em foco e a sala rola. Vista isométrica 2:1 (DEC-2026-10-29-08): a lógica continua em
# coordenadas planas de 1280×720 e só o desenho e o clique passam pela projeção (`_iso`).
# Chão em losangos de 96×48 (um losango = TILE_WORLD unidades da sala); paredes, porta e
# coberturas são caixas; tudo é desenhado por ordem de profundidade (x + y).
# O agente usa a folha real do Nikolai ou do Miguel (CharacterSheet, 128 px; só o visual
# muda); inimigos e chão são arte provisória (PlaceholderArt ampliada, losangos lisos).

enum Mode { EXPLORATION, COMBAT, GAME_OVER }

signal move_finished

const SPEED := 180.0
const STAND_OFFSET := 6.0
const PERCEPTION_RANGE := 300.0  # provisório: alcance de percepção está PENDENTE no GDD
const ENEMY_STEP_SECONDS := 0.4
const POPUP_SECONDS := 1.2
const WALK_FRAME_SECONDS := 0.11
const IDLE_FRAME_SECONDS := 0.7
const PLACEHOLDER_SCALE := 2.7  # arte provisória de 32×48 ampliada para ~130 px (a altura do herói)
const TILE_WORLD := 64.0  # lado de um losango do chão, em unidades da sala
const TILE_SCREEN := Vector2(96, 48)  # losango 2:1 na tela (V-21)
const BLOCK_HEIGHT := 160.0  # altura na tela das paredes e da porta: ~1,25× o herói de 128 px
const FRONT_WALL_HEIGHT := 24.0  # paredes voltadas para a câmera
const COVER_HEIGHT := {"partial": 56.0, "full": 100.0}
const AGENT_SHEETS := ["res://assets/sprites/personagens/nikolai", "res://assets/sprites/personagens/miguel"]
const ROOM_SIZE := Vector2i(1280, 720)
const ENEMY_VARIANTS := ["cultista", "atirador"]  # mesma ordem de `enemies`

var walls: Array[Rect2] = [
	Rect2(0, 0, 1280, 16),
	Rect2(0, 704, 1280, 16),
	Rect2(0, 0, 16, 720),
	Rect2(1264, 0, 16, 720),
	Rect2(600, 0, 24, 336),
	Rect2(600, 408, 24, 312),
	Rect2(400, 200, 120, 40),
]
var door := Rect2(600, 336, 24, 72)  # 72 unidades: pouco mais de um losango, ~2× a largura de um herói
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
var camera := Camera2D.new()
var facing := {}  # Combatant -> PlaceholderArt.Dir
var facing8 := {}  # Combatant -> CharacterSheet.Dir (8 direções; o agente começa virado para SE)
var walk_time := 0.0
var idle_frame := 0
var agent_sheets: Array[CharacterSheet] = []
var agent_look := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.025, 0.02))  # fora da sala e salas fechadas: escuridão
	add_child(hud)
	add_child(audio)
	for path in AGENT_SHEETS:
		agent_sheets.append(CharacterSheet.new(path))
	var corners := [_iso(Vector2.ZERO), _iso(Vector2(ROOM_SIZE.x, 0)), _iso(Vector2(0, ROOM_SIZE.y)), _iso(Vector2(ROOM_SIZE))]
	camera.limit_left = int(corners[2].x) - 16
	camera.limit_right = int(corners[1].x) + 16
	camera.limit_top = int(corners[0].y) - int(BLOCK_HEIGHT) - 16
	camera.limit_bottom = int(corners[3].y) + 16
	camera.position = _iso(player.pos)
	add_child(camera)
	hud.end_turn_requested.connect(_player_pass)
	audio.play_music("exploration")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.pressed and event.keycode == KEY_SPACE:
			_player_pass()
		elif event.pressed and event.keycode == KEY_TAB:
			agent_look = (agent_look + 1) % agent_sheets.size()
			queue_redraw()
		elif event.pressed and event.keycode == KEY_D:
			_player_delay()
		return
	if event is InputEventMouseMotion and mode == Mode.COMBAT:
		queue_redraw()  # atualiza a prévia de chance/custo sob o cursor
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click := _resolve_click(get_global_mouse_position())
		if mode == Mode.EXPLORATION:
			_order_move(click)
		elif mode == Mode.COMBAT:
			_combat_click(click)


# --- Visibilidade --------------------------------------------------------------
# A sala é dividida pela parede da porta. Com a porta fechada, o personagem só vê o lado em
# que está: nada do outro lado (chão, paredes, inimigos, coberturas) é desenhado.

func _region(p: Vector2) -> int:
	if p.x < door.position.x:
		return 0
	return 1 if p.x > door.end.x else -1  # -1: na parede da porta


func _visible(p: Vector2) -> bool:
	if door_open:
		return true
	var r := _region(p)
	return r == -1 or r == _region(player.pos)


# --- Projeção isométrica -----------------------------------------------------

# Ponto da sala -> ponto da tela. Um losango do chão (TILE_WORLD) vira 96×48.
func _iso(p: Vector2) -> Vector2:
	var k := TILE_SCREEN / TILE_WORLD
	return Vector2((p.x - p.y) * k.x * 0.5, (p.x + p.y) * k.y * 0.5)


# Ponto da tela -> ponto da sala (no nível do chão).
func _uniso(s: Vector2) -> Vector2:
	var k := TILE_SCREEN / TILE_WORLD
	var a := s.x / (k.x * 0.5)
	var b := s.y / (k.y * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


# Converte o ponto do mouse (tela) no ponto da sala que a lógica entende: o corpo de um
# inimigo ou a face de uma cobertura/porta valem como o ponto no chão dessas peças.
func _resolve_click(mouse: Vector2) -> Vector2:
	for e in enemies:
		if e.is_alive() and _visible(e.pos) and mouse.distance_to(_iso(e.pos) + Vector2(0, -56)) <= 44.0:
			return e.pos
	for lift in [0.0, 18.0, 36.0, 54.0, 72.0]:
		var p := _uniso(mouse + Vector2(0, lift))
		var cover := _cover_at(p)
		if (cover and _visible(cover.rect.get_center())) or (not door_open and door.grow(12).has_point(p)):
			return p
	return _uniso(mouse)


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
	var focus := turns.current if mode == Mode.COMBAT and turns and turns.current else player
	camera.position = _iso(focus.pos)
	if moving_unit and not path.is_empty():
		var step := _iso(path[0]) - _iso(moving_unit.pos)  # a direção vista na tela
		facing[moving_unit] = PlaceholderArt.dir_from_vector(step)
		facing8[moving_unit] = CharacterSheet.dir_from_vector(step)
		walk_time += delta
		moving_unit.pos = moving_unit.pos.move_toward(path[0], SPEED * delta)
		if moving_unit.pos.is_equal_approx(path[0]):
			path.remove_at(0)
		if path.is_empty():
			moving_unit = null
			walk_time = 0.0
			move_finished.emit()
		queue_redraw()
	var breath := int(Time.get_ticks_msec() / (IDLE_FRAME_SECONDS * 1000.0)) % 2
	if breath != idle_frame:
		idle_frame = breath
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
		_popup(target.pos + Vector2(14, 14), "Abatido" if target.side == Combatant.Side.ENEMY else "Caiu")
	queue_redraw()


# `at` é um ponto da sala; o texto sobe da altura da cabeça de uma unidade.
func _popup(at: Vector2, text: String) -> void:
	popups.append({"pos": _iso(at) + Vector2(-20, -CharacterSheet.HEIGHT - 12 - 16 * popups.size()), "text": text, "time": POPUP_SECONDS})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_floor()
	if mode == Mode.EXPLORATION:
		for e in enemies:
			if e.is_alive() and _visible(e.pos):
				_draw_range(e.pos, PERCEPTION_RANGE, Color(PlaceholderArt.color("sangue_claro"), 0.35))
	# Peças ordenadas por profundidade: quanto maior x + y, mais perto da câmera.
	var items: Array = []
	for w in walls:
		# As paredes de frente (sul e leste) ficam baixas para não esconder a sala.
		var wall_height := FRONT_WALL_HEIGHT if w.end.y >= ROOM_SIZE.y or w.end.x >= ROOM_SIZE.x else BLOCK_HEIGHT
		for piece in _pieces(w):
			if not _visible(piece.get_center()):
				continue
			items.append({"key": piece.get_center().x + piece.get_center().y, "block": piece, "front": PlaceholderArt.color("parede"), "top": PlaceholderArt.color("parede_topo"), "height": wall_height})
	if not door_open:
		for piece in _pieces(door):
			items.append({"key": piece.get_center().x + piece.get_center().y, "block": piece, "front": PlaceholderArt.color("couro"), "top": PlaceholderArt.color("couro_claro"), "height": BLOCK_HEIGHT})
	for c: Cover in covers:
		if not _visible(c.rect.get_center()):
			continue
		if c.is_destroyed():
			_draw_outline(c.rect, PlaceholderArt.color("chao_claro"))
			continue
		var partial := c.kind == "partial"
		items.append({
			"key": c.rect.get_center().x + c.rect.get_center().y, "block": c.rect, "cover": c,
			"front": PlaceholderArt.color("couro") if partial else PlaceholderArt.color("parede"),
			"top": PlaceholderArt.color("couro_claro") if partial else PlaceholderArt.color("metal"),
			"height": COVER_HEIGHT[c.kind],
		})
	for u in _living_units():
		if _visible(u.pos):
			items.append({"key": u.pos.x + u.pos.y, "unit": u})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	for it in items:
		if it.has("unit"):
			_draw_unit(it.unit)
			continue
		_draw_box(it.block, it.front, it.top, it.height)
		if it.has("cover"):
			var c: Cover = it.cover
			var label := "%s %d" % ["P" if c.kind == "partial" else "C", c.hp]
			draw_string(font, _iso(c.rect.get_center()) + Vector2(-14, -it.height - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	if mode == Mode.COMBAT:
		_draw_preview(font)
	# Textos de rodapé presos à tela, não à sala que rola.
	var footer := get_canvas_transform().affine_inverse() * Vector2(24, 520)
	if mode == Mode.COMBAT:
		draw_string(font, footer, "Rodada %d  |  Espaço passa, D atrasa, R reinicia" % turns.round_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
	elif mode == Mode.GAME_OVER:
		draw_string(font, footer, "Game Over (R reinicia)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.5, 0.5))
	for p in popups:
		draw_string(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 0.7, clampf(p.time / POPUP_SECONDS * 2.0, 0.0, 1.0)))


# Chão provisório: losangos lisos em dois tons, com uma linha escura entre eles.
func _draw_floor() -> void:
	var half := TILE_SCREEN * 0.5
	for ty in int(ceil(ROOM_SIZE.y / TILE_WORLD)):
		for tx in int(ceil(ROOM_SIZE.x / TILE_WORLD)):
			if not _visible((Vector2(tx, ty) + Vector2(0.5, 0.5)) * TILE_WORLD):
				continue
			var c := _iso((Vector2(tx, ty) + Vector2(0.5, 0.5)) * TILE_WORLD)
			var pts := PackedVector2Array([c + Vector2(0, -half.y), c + Vector2(half.x, 0), c + Vector2(0, half.y), c + Vector2(-half.x, 0)])
			draw_colored_polygon(pts, PlaceholderArt.color("chao") if (tx + ty) % 2 == 0 else PlaceholderArt.color("chao_claro").darkened(0.15))
			pts.append(pts[0])
			draw_polyline(pts, PlaceholderArt.color("chao_escuro"), 1.0)


# Divide um retângulo longo em peças de no máximo um losango, para a ordem de desenho.
func _pieces(r: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var nx := maxi(1, int(ceil(r.size.x / TILE_WORLD)))
	var ny := maxi(1, int(ceil(r.size.y / TILE_WORLD)))
	for ix in nx:
		for iy in ny:
			var step := Vector2(r.size.x / nx, r.size.y / ny)
			out.append(Rect2(r.position + Vector2(step.x * ix, step.y * iy), step))
	return out


# Caixa vista de lado: faces voltadas para a câmera (+x e +y) e o topo claro.
func _draw_box(r: Rect2, front: Color, top: Color, height: float) -> void:
	var lift := Vector2(0, -height)
	var a := _iso(r.position)  # canto de trás
	var b := _iso(Vector2(r.end.x, r.position.y))  # canto da direita
	var c := _iso(r.end)  # canto da frente
	var d := _iso(Vector2(r.position.x, r.end.y))  # canto da esquerda
	draw_colored_polygon(PackedVector2Array([d, c, c + lift, d + lift]), front.darkened(0.12))  # face +y
	draw_colored_polygon(PackedVector2Array([c, b, b + lift, c + lift]), front.darkened(0.3))  # face +x
	draw_colored_polygon(PackedVector2Array([a + lift, b + lift, c + lift, d + lift]), top)


func _draw_outline(r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array([_iso(r.position), _iso(Vector2(r.end.x, r.position.y)), _iso(r.end), _iso(Vector2(r.position.x, r.end.y)), _iso(r.position)])
	draw_polyline(pts, color, 1.0)


# Círculo no chão (alcance): vira uma elipse deitada na tela.
func _draw_range(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 97:
		pts.append(_iso(center + Vector2.from_angle(TAU * i / 96.0) * radius))
	draw_polyline(pts, color, 1.0)


func _draw_unit(u: Combatant) -> void:
	var at := _iso(u.pos)
	draw_set_transform(at, 0.0, Vector2(1.0, 0.5))  # sombra achatada sob os pés
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if turns and u == turns.current:
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, PlaceholderArt.color("destaque"), 2.0)
		draw_set_transform(Vector2.ZERO)
	var walking := u == moving_unit
	var i := enemies.find(u)
	if i < 0:
		var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
		var n := int(walk_time / WALK_FRAME_SECONDS) % frames.size() if walking else idle_frame
		agent_sheets[agent_look].draw(self, at, frames[n], facing8.get(u, CharacterSheet.Dir.SE))
	else:
		var frame := 1 + int(walk_time / WALK_FRAME_SECONDS) % 2 if walking else 0
		var tex := PlaceholderArt.character_texture(ENEMY_VARIANTS[i % ENEMY_VARIANTS.size()], facing.get(u, PlaceholderArt.Dir.SOUTH), frame)
		var size := Vector2(PlaceholderArt.FRAME_SIZE * PLACEHOLDER_SCALE)
		draw_texture_rect(tex, Rect2((at - PlaceholderArt.PIVOT * PLACEHOLDER_SCALE).round(), size), false)
	if mode != Mode.EXPLORATION:
		var bar := Rect2(at + Vector2(-20, -CharacterSheet.HEIGHT - 8), Vector2(40, 4))
		draw_rect(bar, Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(u.pv) / u.max_pv, bar.size.y)), Color(0.3, 0.85, 0.35))


# Prévia sob o cursor no turno do agente: chance de acerto no inimigo ou custo do movimento.
func _draw_preview(font: Font) -> void:
	if not _player_ready():
		return
	var screen_mouse := get_global_mouse_position()
	var mouse := _resolve_click(screen_mouse)
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
		draw_line(_iso(player.pos), _iso(target.pos), Color(1, 1, 1, 0.3), 1.0)
	elif _cover_at(mouse) == null:
		var route := pathfinder.find_path(player.pos, mouse, _obstacles(player), player.radius)
		if route.is_empty():
			text = "Inacessível"
		else:
			var cost := rules.move_cost(CombatRules.path_length(route))
			text = "%d PA" % cost if cost <= player.pa else "%d PA (parcial)" % player.pa
	if text != "":
		draw_string(font, screen_mouse + Vector2(14, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
