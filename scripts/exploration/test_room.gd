extends Node2D
# Sala de teste: exploração com clique para mover, uma porta, inimigos e coberturas.
# A rota contorna obstáculos via Pathfinder; destino inacessível é ignorado.
# Inimigo que vê o personagem (alcance + linha de visão) inicia o combate na hora. C agacha:
# a percepção dos inimigos cai à metade. Clique num inimigo sem alerta faz o ataque furtivo.
# Combate por turnos (TurnManager + CombatRules): no turno do agente, clique no chão
# move (gasta PA), clique no inimigo ataca,
# Espaço passa o turno e D atrasa. R reinicia a sala.
# Grupo (Léo): controla um personagem por vez e os outros seguem espalhados, a distância fixa
# do líder e posição variando. Tab, 1, 2 ou clique no retrato trocam o controlado (na exploração).
# PV zero deixa caído; aliado encostado reanima com kit (2 PA, metade do PV); quem segue
# caído no fim do combate morre.
# Visual provisório: resolução interna 960×540 (DEC-2026-10-29-10), câmera segue a unidade
# em foco e a sala rola. Vista isométrica 2:1 (DEC-2026-10-29-08): a lógica continua em
# coordenadas planas de 1280×720 e só o desenho e o clique passam pela projeção (`_iso`).
# Chão em losangos de 96×48 (um losango = TILE_WORLD unidades da sala); paredes, porta e
# coberturas são caixas; tudo é desenhado por ordem de profundidade (x + y).
# O agente usa a folha real do Nikolai, do Miguel ou do Fernando (CharacterSheet, 128 px; só o visual
# muda); inimigos e chão são arte provisória (PlaceholderArt ampliada, losangos lisos).

enum Mode { EXPLORATION, COMBAT, GAME_OVER }

signal move_finished

const SPEED := 180.0
const STAND_OFFSET := 6.0
const ENEMY_STEP_SECONDS := 0.4
const FOLLOW_DISTANCE := 60.0  # distância fixa do seguidor ao líder (provisório)
const FOLLOW_SPREAD := 1.0  # variação do ângulo do seguidor em radianos (provisório)
const REVIVE_REACH := 16.0  # borda a borda: "adjacente" para reanimar
const SHEET_SIZE := Vector2(212, 72)
const POPUP_SECONDS := 1.2
const HIT_SHAKE_SECONDS := 0.2
const CRIT_SHAKE_SECONDS := 0.35
const POPUP_STYLES := {
	"damage": {"size": 18, "color": Color(1.0, 0.92, 0.85)},
	"crit": {"size": 24, "color": Color(1.0, 0.8, 0.25)},
	"miss": {"size": 15, "color": Color(0.68, 0.66, 0.62)},
	"blocked": {"size": 14, "color": Color(0.6, 0.7, 0.85)},
	"down": {"size": 14, "color": Color(0.95, 0.3, 0.25)},
	"heal": {"size": 15, "color": Color(0.5, 0.9, 0.55)},
	"info": {"size": 13, "color": Color(1.0, 1.0, 0.75)},
}
const WALK_FRAME_SECONDS := 0.11
const IDLE_FRAME_SECONDS := 0.7
const PLACEHOLDER_SCALE := 2.7  # arte provisória de 32×48 ampliada para ~130 px (a altura do herói)
const TILE_WORLD := 64.0  # lado de um losango do chão, em unidades da sala
const TILE_SCREEN := Vector2(96, 48)  # losango 2:1 na tela (V-21)
const BLOCK_HEIGHT := 176.0  # altura na tela das paredes: ~1,35× o herói de 128 px (a arte tem 171 px)
const FRONT_WALL_HEIGHT := 24.0  # paredes voltadas para a câmera
const FRONT_WALL_COLOR := Color("3b2a1d")  # madeira escura do rodapé da arte
const WALL_SPAN := 128.0  # um painel de parede cobre 2 losangos (96 px de tela) ao longo do eixo
# Cobertura -> móvel que a representa. O guarda-roupa é o bloco sólido do meio da sala.
const COVER_PROPS := {"partial": "movel_caixote", "full": "movel_estante"}
const BLOCK_PROP := "movel_guarda_roupa"
const BLOCK_CENTER := Vector2(460, 220)  # centro do Rect2(400, 200, 120, 40) de `walls`
const WALL_BACK := 0  # eixo x, voltada para +y (norte da sala)
const DOOR_OFFSET := Vector2(8, 0)  # ajuste fino da porta dentro do vão da parede
const WALL_SIDE := 1  # eixo y, voltada para +x (oeste da sala e parede da porta)
const AGENT_SHEETS := [  # visuais dos membros do grupo (Fernando, Nikolai, Miguel)
	"res://assets/sprites/personagens/fernando",
	"res://assets/sprites/personagens/nikolai",
	"res://assets/sprites/personagens/miguel",
]
const ROOM_SIZE := Vector2i(1280, 720)
const ENEMY_VARIANTS := ["cultista", "atirador"]  # mesma ordem de `enemies`
# Variantes que já têm folha real; as outras seguem com PlaceholderArt.
const ENEMY_SHEETS := {"cultista": "res://assets/sprites/personagens/cultista"}

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
# Coberturas: parcial (caixote, mureta, -20% de acerto) e total (bloqueia o tiro). Não destrutíveis por ora.
var covers: Array = [
	Cover.new(Rect2(300, 450, 40, 40), "partial", 20),
	Cover.new(Rect2(960, 300, 40, 40), "partial", 20),
	Cover.new(Rect2(720, 520, 80, 24), "full", 60),
]

var cfg := CombatConfig.load_file()
var rules := CombatRules.new(cfg)
# Grupo de teste: Fernando e Nikolai (só para exercitar grupo, troca e reanimação).
var party: Array[Combatant] = [
	cfg.make_unit("agente", "Fernando", Vector2(160, 360)),
	cfg.make_unit("agente", "Nikolai", Vector2(110, 320)),
]
var player: Combatant = party[0]  # personagem controlado (no combate, o do turno)
var looks := {}  # membro do grupo -> índice em AGENT_SHEETS
var follow_paths := {}  # seguidor -> rota restante na exploração
var follow_offsets := {}  # seguidor -> posição relativa ao líder
var follow_rng := RandomNumberGenerator.new()
var kits := 1  # kits de primeiros socorros do grupo (teste; o inventário ainda não existe)
var enemies: Array[Combatant] = [
	cfg.make_enemy("cultista", Vector2(800, 360)),
	cfg.make_enemy("atirador", Vector2(1100, 200)),
]
var turns: TurnManager

var path := PackedVector2Array()
var moving_unit: Combatant = null
var pending_door := false
var door_open := false
var discovered := {}  # regiões da sala já vistas (minimapa)
var pathfinder := Pathfinder.new()
var mode := Mode.EXPLORATION
var busy := false  # animação ou turno inimigo em andamento: entrada do jogador ignorada
var popups: Array = []  # textos de acerto/erro/dano flutuando sobre as unidades
var hit_shake := {}  # Combatant -> segundos restantes de tremor ao levar dano
var screen_shake := 0.0  # segundos restantes de tremor da tela (crítico)
var hud := CombatHud.new()
var audio := AudioDirector.new()
var camera := Camera2D.new()
var fade_layer := CanvasLayer.new()
var fade := ColorRect.new()  # escurece a tela no Game Over
var facing := {}  # Combatant -> PlaceholderArt.Dir
var facing8 := {}  # Combatant -> CharacterSheet.Dir (8 direções; o agente começa virado para SE)
var walk_time := 0.0
var idle_frame := 0
var agent_sheets: Array[CharacterSheet] = []
var enemy_sheets := {}  # variante -> CharacterSheet
var scenery := Scenery.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.025, 0.02))  # fora da sala e salas fechadas: escuridão
	add_child(hud)
	add_child(audio)
	for path in AGENT_SHEETS:
		agent_sheets.append(CharacterSheet.new(path))
	looks[party[0]] = 0
	looks[party[1]] = 1
	party[1].max_san = 16  # Nikolai é Especialista (SAN inicial 16); a ficha de teste é a mesma
	party[1].san = 16
	_reset_follow_offsets(Vector2.RIGHT)
	for variant in ENEMY_SHEETS:
		enemy_sheets[variant] = CharacterSheet.new(ENEMY_SHEETS[variant])
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
			_switch_to(party[(party.find(player) + 1) % party.size()])
		elif event.pressed and event.keycode >= KEY_1 and event.keycode < KEY_1 + party.size():
			_switch_to(party[event.keycode - KEY_1])
		elif event.pressed and event.keycode == KEY_D:
			_player_delay()
		elif event.pressed and event.keycode == KEY_C and mode == Mode.EXPLORATION:
			player.crouched = not player.crouched
			queue_redraw()
		return
	if event is InputEventMouseMotion and mode == Mode.COMBAT:
		queue_redraw()  # atualiza a prévia de chance/custo sob o cursor
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var portrait := _portrait_at(get_viewport().get_mouse_position())
		if portrait:
			_switch_to(portrait)
			return
		var click := _resolve_click(get_global_mouse_position())
		if mode == Mode.EXPLORATION:
			var target := _enemy_at(click)
			if target and _visible(target.pos):
				_stealth_attack(target)
			else:
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
	for m in party:
		if m != player and not m.dead and _visible(m.pos) and mouse.distance_to(_iso(m.pos) + Vector2(0, -56)) <= 44.0:
			return m.pos
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
	_reset_follow_offsets(click - player.pos)
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
	for m in party:
		if not m.dead:
			out.append(m)  # caídos também ocupam espaço (Léo: ninguém atravessa)
	for e in enemies:
		if e.is_alive():
			out.append(e)
	return out


func _start_move(unit: Combatant, new_path: PackedVector2Array) -> void:
	moving_unit = unit
	path = new_path
	path.remove_at(0)


func _process(delta: float) -> void:
	_update_discovered()
	if not popups.is_empty():
		for p in popups:
			p.time -= delta
		popups = popups.filter(func(p: Dictionary) -> bool: return p.time > 0.0)
		queue_redraw()
	for u in hit_shake.keys():
		hit_shake[u] -= delta
		if hit_shake[u] <= 0.0:
			hit_shake.erase(u)
	screen_shake = maxf(screen_shake - delta, 0.0)
	camera.offset = Vector2(randf_range(-3, 3), randf_range(-2, 2)) if screen_shake > 0.0 else Vector2.ZERO
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
	_update_followers(delta)
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
		if not e.is_alive():
			continue
		for m in party:
			if not m.is_alive() or e.pos.distance_to(m.pos) > rules.perception_range(e, m):
				continue
			if Pathfinder.has_line_of_sight(e.pos, m.pos, _sight_blockers()):
				_start_combat()
				return


# Ataque furtivo (Léo): contra inimigo sem alerta, com bônus de acerto e de dano. Se errar,
# o combate começa. Se acertar sem abater, o alvo também entra em alerta (assumido).
# Fora do alcance da arma, o personagem só anda até o alvo.
func _stealth_attack(target: Combatant) -> void:
	player.pa = int(player.weapon["pa_cost"])  # fora do combate não há PA; o custo é só formal
	var blocker := rules.attack_blocker(player, target, _sight_blockers(), covers)
	if blocker == "out_of_range":
		player.pa = 0
		var stand := target.pos.move_toward(player.pos, player.radius + target.radius + 2.0 + float(player.weapon["max_range"]) * 0.5)
		_order_move(stand)
		return
	if blocker != "":
		player.pa = 0
		_reject(blocker)
		return
	path = PackedVector2Array()
	pending_door = false
	var r := rules.attack(player, target, _sight_blockers(), covers, true)
	player.pa = 0
	_show_attack(player, target, r)
	if target.is_alive():
		_start_combat()


# Monta os participantes (todos os inimigos vivos da sala) e ordena a iniciativa.
func _start_combat() -> void:
	mode = Mode.COMBAT
	path = PackedVector2Array()
	moving_unit = null
	pending_door = false
	hud.on_combat_started()
	audio.on_combat_started()
	turns = TurnManager.new(int(cfg.value("pa_per_turn")))
	turns.turn_effects = func(u: Combatant) -> bool:
		var fx := rules.start_turn_effects(u)
		if fx.damage > 0:
			_popup(u.pos, "-%d" % fx.damage, "damage")
		if fx.skip and u.is_alive():
			_popup(u.pos, "Atordoado")
		return fx.skip
	turns.turn_started.connect(_on_turn_started)
	turns.turn_ended.connect(func(_u: Combatant) -> void: hud.on_turn_ended())
	turns.combat_ended.connect(_on_combat_ended)
	follow_paths.clear()
	var units: Array[Combatant] = []
	for m in party:
		if m.is_alive():
			units.append(m)
	for e in enemies:
		if e.is_alive():
			units.append(e)
	turns.start(units)
	queue_redraw()


func _on_turn_started(unit: Combatant) -> void:
	queue_redraw()
	if unit.side == Combatant.Side.PLAYER:
		player = unit
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
		for m in party:
			if not m.is_alive() and not m.dead:
				m.dead = true  # Léo: caído sem reanimação até o fim do combate morre
				_popup(m.pos, "Morreu")
		if player.dead:
			for m in party:
				if not m.dead:
					player = m
					break
	else:
		mode = Mode.GAME_OVER
		_game_over_fade()
	queue_redraw()


# Game Over (Léo): sem tela própria; a tela escurece bem devagar e o jogo volta ao último
# save. A sala de teste ainda não carrega saves, então recarregar a cena é voltar ao início.
func _game_over_fade() -> void:
	fade_layer.layer = 100
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not fade.get_parent():
		fade_layer.add_child(fade)
		add_child(fade_layer)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, cfg.value("game_over_fade_seconds"))
	await tween.finished
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


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
	var fallen := _fallen_at(click)
	if fallen:
		_revive(fallen)
		return
	if _cover_at(click):
		return  # coberturas não podem ser destruídas por enquanto (Léo)
	await _player_move(click)


# Kit de primeiros socorros (Léo): aliado encostado no caído, 2 PA, volta com metade do PV,
# um uso por kit.
func _revive(fallen: Combatant) -> void:
	var kit := cfg.game_data.get_entry("itens", "kit_primeiros_socorros")
	var cost := int(kit["custo_pa_combate"])
	if kits <= 0:
		_reject("requirement")
	elif CombatRules.gap(player, fallen) > REVIVE_REACH:
		_reject("out_of_range")
	elif not turns.spend(player, cost):
		_reject("no_pa")
	else:
		kits -= 1
		fallen.pv = maxi(floori(fallen.max_pv * float(kit["valor"])), 1)
		_popup(fallen.pos, "REANIMADO", "heal")
	_after_player_action()


func _fallen_at(p: Vector2) -> Combatant:
	for m in party:
		if not m.is_alive() and not m.dead and m.pos.distance_to(p) <= m.radius + 4.0:
			return m
	return null


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
		var target := _enemy_target(unit)
		if target == null:
			turns.end_turn()
			break
		if rules.attack_blocker(unit, target, _sight_blockers(), covers) == "":
			_show_attack(unit, target, rules.attack(unit, target, _sight_blockers(), covers))
			turns.action_done()
			continue
		if not await _enemy_advance(unit, target):
			turns.end_turn()
	busy = false
	queue_redraw()


# Alvo do inimigo: o membro do grupo de pé mais próximo.
func _enemy_target(unit: Combatant) -> Combatant:
	var best: Combatant = null
	for m in party:
		if m.is_alive() and (best == null or unit.pos.distance_to(m.pos) < unit.pos.distance_to(best.pos)):
			best = m
	return best


# Retorna false se não houver como se aproximar.
func _enemy_advance(unit: Combatant, target: Combatant) -> bool:
	var stand := target.pos.move_toward(unit.pos, target.radius + unit.radius + 2.0 + float(unit.weapon["max_range"]) * 0.5)
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
	if r.blocked:
		_popup(target.pos, "BLOQUEADO", "blocked")
	elif not r.hit:
		_popup(target.pos, "ERROU", "miss")
	else:
		_popup(target.pos, "-%d" % r.damage, "crit" if r.crit else "damage")
		hit_shake[target] = CRIT_SHAKE_SECONDS if r.crit else HIT_SHAKE_SECONDS
		if r.crit:
			screen_shake = CRIT_SHAKE_SECONDS
	if not target.is_alive():
		_popup(target.pos, "ABATIDO" if target.side == Combatant.Side.ENEMY else "CAIU", "down")
	queue_redraw()


# `at` é um ponto da sala; o texto nasce na altura da cabeça e sobe enquanto some.
# kind: damage, crit, miss, blocked, down, heal ou info (estilos em POPUP_STYLES).
func _popup(at: Vector2, text: String, kind := "info") -> void:
	var stacked := popups.filter(func(p: Dictionary) -> bool: return p.anchor.distance_to(at) < 1.0).size()
	popups.append({"anchor": at, "pos": _iso(at) + Vector2(0, -CharacterSheet.HEIGHT - 14 - 18 * stacked), "text": text, "kind": kind, "time": POPUP_SECONDS})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_floor()
	if mode == Mode.EXPLORATION:
		for e in enemies:
			if e.is_alive() and _visible(e.pos):
				_draw_range(e.pos, rules.perception_range(e, player), Color(PlaceholderArt.color("sangue_claro"), 0.35))
	# Peças ordenadas por profundidade: quanto maior x + y, mais perto da câmera.
	var items: Array = []
	for w in walls:
		# As paredes de frente (sul e leste) ficam baixas para não esconder a sala.
		var front: bool = w.end.y >= ROOM_SIZE.y or w.end.x >= ROOM_SIZE.x
		if not front:
			continue
		for piece in _pieces(w):
			if _visible(piece.get_center()):
				items.append({"key": piece.get_center().x + piece.get_center().y, "block": piece, "front": FRONT_WALL_COLOR, "top": FRONT_WALL_COLOR.lightened(0.1), "height": FRONT_WALL_HEIGHT})
	var panels: Array = []
	panels.append_array(_wall_run(WALL_BACK, 8.0, 0.0, ROOM_SIZE.x))
	panels.append_array(_wall_run(WALL_SIDE, 8.0, 0.0, ROOM_SIZE.y))
	var door_mid := door.get_center()
	panels.append_array(_wall_run(WALL_SIDE, door_mid.x, 0.0, door_mid.y - WALL_SPAN * 0.5))
	panels.append_array(_wall_run(WALL_SIDE, door_mid.x, door_mid.y + WALL_SPAN * 0.5, ROOM_SIZE.y))
	panels.append({"at": door_mid, "name": "parede_y_vao"})
	for p in panels:
		if _visible(p.at):
			items.append({"key": p.at.x + p.at.y, "panel": p})
	if not door_open:
		items.append({"key": door_mid.x + door_mid.y + 0.5, "door": true})
	if _visible(BLOCK_CENTER):
		items.append({"key": BLOCK_CENTER.x + BLOCK_CENTER.y, "prop": BLOCK_PROP, "at": BLOCK_CENTER})
	for c: Cover in covers:
		if not _visible(c.rect.get_center()):
			continue
		if c.is_destroyed():
			_draw_outline(c.rect, PlaceholderArt.color("chao_claro"))
			continue
		items.append({"key": c.rect.get_center().x + c.rect.get_center().y, "prop": COVER_PROPS[c.kind], "at": c.rect.get_center(), "cover": c})
	for u in _living_units():
		if _visible(u.pos):
			items.append({"key": u.pos.x + u.pos.y, "unit": u})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	for it in items:
		if it.has("unit"):
			_draw_unit(it.unit)
			continue
		if it.has("panel"):
			scenery.draw(self, it.panel.name, _iso(it.panel.at))
		elif it.has("door"):
			# A porta fecha o vão da parede lateral; a arte original olha para o outro lado, por isso espelha.
			scenery.draw(self, "movel_porta", _iso(door.get_center()) + DOOR_OFFSET, true)
		elif it.has("prop"):
			scenery.draw(self, it.prop, _iso(it.at))
			if it.has("cover"):
				var c: Cover = it.cover
				var label := "P" if c.kind == "partial" else "C"
				draw_string(font, _iso(it.at) + Vector2(-14, -scenery.height_of(it.prop) - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
		else:
			_draw_box(it.block, it.front, it.top, it.height)
	if mode == Mode.COMBAT:
		_draw_preview(font)
	_draw_hud(font)
	# Textos de rodapé presos à tela, não à sala que rola.
	var footer := get_canvas_transform().affine_inverse() * Vector2(24, 520)
	if mode == Mode.COMBAT:
		draw_string(font, footer, "Rodada %d  |  Espaço passa, D atrasa, R reinicia" % turns.round_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
	elif mode == Mode.EXPLORATION:
		draw_string(font, footer, ("AGACHADO  |  " if player.crouched else "") + "C agacha, Tab ou 1/2 troca o personagem, clique no inimigo ataca de surpresa", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
	for p in popups:
		_draw_popup(font, p)


# Feedback de combate (provisório do Claude, 29/10/2026): dano em número que sobe e some,
# "ERROU" em cinza, crítico maior em dourado com "CRÍTICO!" e um tremor na tela.
func _draw_popup(font: Font, p: Dictionary) -> void:
	var style: Dictionary = POPUP_STYLES.get(p.kind, POPUP_STYLES.info)
	var age: float = 1.0 - p.time / POPUP_SECONDS
	var alpha: float = clampf(p.time / POPUP_SECONDS * 2.5, 0.0, 1.0)
	var size: int = style.size
	if p.kind == "crit" and age < 0.15:
		size = int(size * (1.6 - age * 4.0))  # cresce e assenta no primeiro instante
	var width := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at: Vector2 = p.pos + Vector2(-width * 0.5, -28.0 * age)
	var color: Color = style.color
	draw_string_outline(font, at, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.05, 0.03, 0.02, alpha))
	draw_string(font, at, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
	if p.kind == "crit":
		var tag := "CRÍTICO!"
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var tag_at: Vector2 = p.pos + Vector2(-tw * 0.5, -28.0 * age - size - 2)
		draw_string_outline(font, tag_at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.05, 0.03, 0.02, alpha))
		draw_string(font, tag_at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.35, 0.25, alpha))


# Chão: um tile de 96×48 por losango, sorteado de forma fixa entre as variações.
func _draw_floor() -> void:
	for ty in int(ceil(ROOM_SIZE.y / TILE_WORLD)):
		for tx in int(ceil(ROOM_SIZE.x / TILE_WORLD)):
			if not _visible((Vector2(tx, ty) + Vector2(0.5, 0.5)) * TILE_WORLD):
				continue
			var c := _iso((Vector2(tx, ty) + Vector2(0.5, 0.5)) * TILE_WORLD)
			draw_texture(scenery.floor_texture(tx, ty), (c - TILE_SCREEN * 0.5).round())


# Painéis de parede ao longo de um trecho [from, to]; o último painel recua para não sair do trecho.
func _wall_run(axis: int, fixed: float, from: float, to: float) -> Array:
	var out: Array = []
	var n := maxi(1, int(ceil((to - from) / WALL_SPAN)))
	var step := (to - from - WALL_SPAN) / (n - 1) if n > 1 else 0.0
	for i in n:
		var mid := (from + WALL_SPAN * 0.5 + step * i) if n > 1 else (from + to) * 0.5
		var at := Vector2(mid, fixed) if axis == WALL_BACK else Vector2(fixed, mid)
		var kind := "x_" if axis == WALL_BACK else "y_"
		out.append({"at": at, "name": "parede_" + kind + Scenery.wall_variant(i)})
	return out


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
	if hit_shake.has(u):  # quem leva o golpe treme um instante
		at.x += sin(hit_shake[u] * 70.0) * 3.0
	draw_set_transform(at, 0.0, Vector2(1.0, 0.5))  # sombra achatada sob os pés
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if turns and u == turns.current:
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, PlaceholderArt.color("destaque"), 2.0)
		draw_set_transform(Vector2.ZERO)
	var walking: bool = u == moving_unit or not follow_paths.get(u, PackedVector2Array()).is_empty()
	var i := enemies.find(u)
	if i < 0:
		var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
		var n := int(walk_time / WALK_FRAME_SECONDS) % frames.size() if walking else idle_frame
		agent_sheets[looks.get(u, 0)].draw(self, at, frames[n], facing8.get(u, CharacterSheet.Dir.SE))
		if not u.is_alive():
			draw_string(ThemeDB.fallback_font, at + Vector2(-22, -CharacterSheet.HEIGHT - 14), "CAÍDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))
	else:
		var variant: String = ENEMY_VARIANTS[i % ENEMY_VARIANTS.size()]
		if enemy_sheets.has(variant):
			var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
			var n := int(walk_time / WALK_FRAME_SECONDS) % frames.size() if walking else idle_frame
			enemy_sheets[variant].draw(self, at, frames[n], facing8.get(u, CharacterSheet.Dir.SW))
		else:
			var frame := 1 + int(walk_time / WALK_FRAME_SECONDS) % 2 if walking else 0
			var tex := PlaceholderArt.character_texture(variant, facing.get(u, PlaceholderArt.Dir.SOUTH), frame)
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
		var blocker := rules.attack_blocker(player, target, _sight_blockers(), covers)
		if blocker != "":
			text = HudText.rejection_message(blocker)
		else:
			text = "%d%%" % roundi(rules.hit_chance(player, target, covers) * 100.0)
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


# --- Grupo ---------------------------------------------------------------------

# Troca o personagem controlado (só na exploração; no combate manda a ordem dos turnos).
func _switch_to(m: Combatant) -> void:
	if mode != Mode.EXPLORATION or m == player or m.dead or not m.is_alive():
		return
	if moving_unit == player:
		path = PackedVector2Array()
		moving_unit = null
		walk_time = 0.0
	pending_door = false
	follow_paths.erase(m)
	player = m
	_reset_follow_offsets(Vector2.RIGHT)
	queue_redraw()


# Sorteia a posição de cada seguidor: atrás do líder (oposto ao rumo), a distância fixa,
# com ângulo variando para não formar fila rígida.
func _reset_follow_offsets(heading: Vector2) -> void:
	var back := -heading.normalized() if heading.length() > 0.1 else Vector2.LEFT
	var k := 0
	for m in party:
		if m == player:
			continue
		var side := (k % 2) * 2 - 1  # alterna os lados
		var angle := side * 0.35 * (k + 1) + follow_rng.randf_range(-FOLLOW_SPREAD, FOLLOW_SPREAD) * 0.5
		follow_offsets[m] = back.rotated(angle) * FOLLOW_DISTANCE
		k += 1


func _update_followers(delta: float) -> void:
	for m in party:
		if m == player or not m.is_alive():
			continue
		var goal: Vector2 = player.pos + follow_offsets.get(m, Vector2.LEFT * FOLLOW_DISTANCE)
		var route: PackedVector2Array = follow_paths.get(m, PackedVector2Array())
		var stale := route.is_empty() or route[route.size() - 1].distance_to(goal) > 24.0
		if stale and m.pos.distance_to(goal) > 12.0:
			route = pathfinder.find_path(m.pos, goal, _obstacles(m), m.radius)
			if not route.is_empty():
				route.remove_at(0)
		if route.is_empty():
			follow_paths.erase(m)
			continue
		var step := _iso(route[0]) - _iso(m.pos)
		facing8[m] = CharacterSheet.dir_from_vector(step)
		m.pos = m.pos.move_toward(route[0], SPEED * delta)
		if m.pos.is_equal_approx(route[0]):
			route.remove_at(0)
		follow_paths[m] = route
		if moving_unit == null:
			walk_time += delta
		queue_redraw()


func _portrait_rect(i: int) -> Rect2:
	return Rect2(Vector2(8, 8 + i * (SHEET_SIZE.y + 6)), SHEET_SIZE)


func _portrait_at(screen: Vector2) -> Combatant:
	for i in party.size():
		if _portrait_rect(i).has_point(screen):
			return party[i]
	return null


# HUD da ideia A (Léo, 29/10/2026): fichas do grupo à esquerda (retrato, PV, SAN, PA),
# ordem dos turnos no topo e ações no rodapé durante o combate. Desenhado em pixels da tela.
func _draw_hud(font: Font) -> void:
	var to_world := get_canvas_transform().affine_inverse()
	for i in party.size():
		_draw_sheet(font, party[i], to_world * _portrait_rect(i).position)
	_draw_minimap(font, to_world)
	if mode == Mode.COMBAT and turns:
		_draw_turn_order(font, to_world)
		if turns.current and turns.current.side == Combatant.Side.PLAYER:
			_draw_actions(font, to_world)


func _draw_sheet(font: Font, m: Combatant, pos: Vector2) -> void:
	var active := m == player
	var gold := PlaceholderArt.color("destaque")
	var box := Rect2(pos, SHEET_SIZE)
	draw_rect(box, Color(0.09, 0.07, 0.05, 0.88))
	draw_rect(box, gold if active else Color(0.43, 0.34, 0.24), false, 1.0)
	var face := Rect2(pos + Vector2(6, 6), Vector2(60, 60))
	draw_rect(face, Color(0.16, 0.12, 0.09))
	agent_sheets[looks.get(m, 0)].draw_portrait(self, face)
	if not m.is_alive():
		draw_rect(face, Color(0.4, 0, 0, 0.5))
	draw_rect(face, gold if active else Color(0.43, 0.34, 0.24), false, 1.0)
	draw_string(font, pos + Vector2(74, 16), m.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold if active else Color(0.93, 0.89, 0.8))
	_draw_bar(font, pos + Vector2(74, 22), "PV", m.pv, m.max_pv, Color(0.67, 0.14, 0.14))
	_draw_bar(font, pos + Vector2(74, 38), "SAN", m.san, m.max_san, Color(0.27, 0.43, 0.67))
	var status := ""
	if m.dead:
		status = "MORTO"
	elif not m.is_alive():
		status = "CAÍDO"
	elif mode == Mode.COMBAT and turns and turns.current == m:
		for k in turns.turn_pa(m):
			var c := pos + Vector2(100 + k * 14, 62)
			draw_circle(c, 5.0, gold if k < m.pa else Color(0.2, 0.17, 0.13))
		draw_string(font, pos + Vector2(74, 66), "PA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.66, 0.6, 0.49))
	elif mode == Mode.COMBAT:
		status = "aguardando"
	if status != "":
		draw_string(font, pos + Vector2(74, 66), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.45, 0.45) if status != "aguardando" else Color(0.66, 0.6, 0.49))


func _draw_bar(font: Font, at: Vector2, label: String, value: int, maximum: int, color: Color) -> void:
	draw_string(font, at + Vector2(0, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.66, 0.6, 0.49))
	var bar := Rect2(at + Vector2(24, 1), Vector2(106, 11))
	draw_rect(bar, Color(0.12, 0.1, 0.09))
	if maximum > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(value) / maximum, 0.0, 1.0), bar.size.y)), color)
	draw_string(font, bar.position + Vector2(4, 9), "%d/%d" % [value, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.93, 0.89, 0.8))


# Faixa no topo: retratos na ordem da rodada, o da vez em destaque e inimigos em vermelho.
func _draw_turn_order(font: Font, to_world: Transform2D) -> void:
	var units: Array[Combatant] = []
	for u in turns.order:
		if u.is_alive():
			units.append(u)
	var size := 34.0
	var width := units.size() * (size + 8) + 8
	var pos := to_world * Vector2(480 - width * 0.5, 6)
	draw_rect(Rect2(pos, Vector2(width, 58)), Color(0.09, 0.07, 0.05, 0.88))
	draw_string(font, pos + Vector2(8, 12), "RODADA %d · ORDEM DOS TURNOS" % turns.round_number, HORIZONTAL_ALIGNMENT_LEFT, width - 16, 9, Color(0.66, 0.6, 0.49))
	for k in units.size():
		var u := units[k]
		var face := Rect2(pos + Vector2(8 + k * (size + 8), 18), Vector2(size, size))
		draw_rect(face, Color(0.16, 0.12, 0.09))
		_draw_face(u, face)
		var edge := PlaceholderArt.color("destaque") if u == turns.current else (Color(0.6, 0.2, 0.2) if u.side == Combatant.Side.ENEMY else Color(0.43, 0.34, 0.24))
		draw_rect(face, edge, false, 2.0 if u == turns.current else 1.0)


func _draw_face(u: Combatant, rect: Rect2) -> void:
	var i := enemies.find(u)
	if i < 0:
		agent_sheets[looks.get(u, 0)].draw_portrait(self, rect)
		return
	var variant: String = ENEMY_VARIANTS[i % ENEMY_VARIANTS.size()]
	if enemy_sheets.has(variant):
		enemy_sheets[variant].draw_portrait(self, rect)
	else:
		var tex := PlaceholderArt.character_texture(variant, PlaceholderArt.Dir.SOUTH, 0)
		draw_texture_rect_region(tex, rect, Rect2(4, 0, 24, 24))


# Rodapé: ações do personagem da vez (arma equipada e kit), com o custo em PA.
func _draw_actions(font: Font, to_world: Transform2D) -> void:
	var kit := cfg.game_data.get_entry("itens", "kit_primeiros_socorros")
	var slots := [
		[str(player.weapon["id"]).capitalize(), "%d PA" % int(player.weapon["pa_cost"]), true],
		["Kit", "%d PA · x%d" % [int(kit["custo_pa_combate"]), kits], false],
		["Mover", "1 PA / 2 m", false],
	]
	var slot := Vector2(82, 40)
	var width := slots.size() * (slot.x + 6) - 6
	var pos := to_world * Vector2(480 - width * 0.5, 540 - slot.y - 12)
	for k in slots.size():
		var r := Rect2(pos + Vector2(k * (slot.x + 6), 0), slot)
		draw_rect(r, Color(0.09, 0.07, 0.05, 0.88))
		draw_rect(r, PlaceholderArt.color("destaque") if slots[k][2] else Color(0.43, 0.34, 0.24), false, 1.0)
		draw_string(font, r.position + Vector2(0, 17), slots[k][0], HORIZONTAL_ALIGNMENT_CENTER, slot.x, 12, Color(0.93, 0.89, 0.8))
		draw_string(font, r.position + Vector2(0, 33), slots[k][1], HORIZONTAL_ALIGNMENT_CENTER, slot.x, 9, Color(0.66, 0.6, 0.49))



# Minimapa: radar redondo visto de cima, centrado no controlado (Léo escolheu, 29/10/2026).
# Só desenha o que o grupo já descobriu: o outro lado de uma porta nunca aberta não aparece,
# e inimigos só aparecem enquanto estão à vista.
const RADAR_CENTER := Vector2(888, 72)  # pixels da tela
const RADAR_RADIUS := 56.0
const RADAR_SCALE := 0.11  # pixels do radar por unidade da sala
const RADAR_GRID := 64.0  # um losango do chão, em unidades da sala
const RADAR_INK := Color(0.07, 0.05, 0.04)
const RADAR_FLOOR := Color(0.25, 0.2, 0.15)
const RADAR_WALL := Color(0.84, 0.76, 0.6)
const RADAR_DOOR := Color(0.66, 0.4, 0.2)
const RADAR_ENEMY := Color(0.86, 0.2, 0.2)
const RADAR_BRONZE := Color(0.55, 0.43, 0.27)


# Regiões da sala já vistas pelo grupo (0 e 1: os lados da porta; ver _region).
func _update_discovered() -> void:
	for m in party:
		if not m.dead and _region(m.pos) >= 0:
			discovered[_region(m.pos)] = true
	if door_open:
		discovered[0] = true
		discovered[1] = true


# Partes da sala que o minimapa pode mostrar, em unidades da sala.
func _known_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if discovered.has(0):
		out.append(Rect2(0, 0, door.position.x, ROOM_SIZE.y))
	if discovered.has(1):
		out.append(Rect2(door.end.x, 0, ROOM_SIZE.x - door.end.x, ROOM_SIZE.y))
	if not out.is_empty():
		out.append(Rect2(door.position.x, 0, door.size.x, ROOM_SIZE.y))  # a parede da porta
	return out


func _map_poly(to_map: Callable, r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([to_map.call(r.position), to_map.call(Vector2(r.end.x, r.position.y)), to_map.call(r.end), to_map.call(Vector2(r.position.x, r.end.y))])


# Ângulo (na planta) para onde o personagem olha, a partir da direção do sprite na tela.
func _facing_angle(m: Combatant) -> float:
	var screen := {
		CharacterSheet.Dir.E: Vector2(1, 0), CharacterSheet.Dir.SE: Vector2(1, 0.5), CharacterSheet.Dir.S: Vector2(0, 1),
		CharacterSheet.Dir.SW: Vector2(-1, 0.5), CharacterSheet.Dir.W: Vector2(-1, 0), CharacterSheet.Dir.NW: Vector2(-1, -0.5),
		CharacterSheet.Dir.N: Vector2(0, -1), CharacterSheet.Dir.NE: Vector2(1, -0.5),
	}
	var v: Vector2 = screen.get(facing8.get(m, CharacterSheet.Dir.SE), Vector2(1, 0.5))
	return _uniso(v * 100.0).angle()


func _draw_minimap(font: Font, to_world: Transform2D) -> void:
	var center := to_world * RADAR_CENTER
	var focus := player
	var to_map := func(p: Vector2) -> Vector2: return center + (p - focus.pos) * RADAR_SCALE
	var disc := PackedVector2Array()
	for k in 64:
		disc.append(center + Vector2.RIGHT.rotated(TAU * k / 64.0) * RADAR_RADIUS)
	var known := _known_rects()
	# Recorta um retângulo da sala pelo que já foi descoberto e pelo círculo do radar.
	var fill := func(r: Rect2, color: Color) -> void:
		for k: Rect2 in known:
			var part := r.intersection(k)
			if part.has_area():
				for piece in Geometry2D.intersect_polygons(_map_poly(to_map, part), disc):
					draw_colored_polygon(piece, color)
	var line := func(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([to_map.call(a), to_map.call(b)]), disc):
			draw_polyline(seg, color, width)

	# Fundo: escuro, com a borda ainda mais escura.
	draw_circle(center, RADAR_RADIUS, Color(0.04, 0.03, 0.02, 0.94))
	for c in known:
		fill.call(c, RADAR_FLOOR)
		# Grade fraca de losangos do chão, só no que já foi visto.
		var x := ceilf(c.position.x / RADAR_GRID) * RADAR_GRID
		while x < c.end.x:
			line.call(Vector2(x, c.position.y), Vector2(x, c.end.y), Color(1, 1, 1, 0.05), 1.0)
			x += RADAR_GRID
		var y := ceilf(c.position.y / RADAR_GRID) * RADAR_GRID
		while y < c.end.y:
			line.call(Vector2(c.position.x, y), Vector2(c.end.x, y), Color(1, 1, 1, 0.05), 1.0)
			y += RADAR_GRID
	for c: Cover in covers:
		if c.kind == "full":
			fill.call(c.rect, RADAR_WALL.darkened(0.25))
		else:
			fill.call(c.rect, RADAR_FLOOR.lightened(0.25))
	for w in walls:
		fill.call(w, RADAR_WALL)
	if door_open:
		fill.call(door, RADAR_FLOOR)
		var hinge: Vector2 = door.position + Vector2(door.size.x * 0.5, 0)
		line.call(hinge, hinge + Vector2(door.size.y * 0.7, door.size.y * 0.7), RADAR_DOOR, 1.5)
	elif not known.is_empty():
		fill.call(door, RADAR_DOOR)
	for k in range(1, 3):
		draw_arc(center, RADAR_RADIUS * k / 3.0, 0.0, TAU, 48, Color(0.83, 0.67, 0.31, 0.12), 1.0)

	# Inimigos: só os que estão à vista agora. Fora do alcance do radar, viram seta na borda.
	for e in enemies:
		if not (e.is_alive() and _visible(e.pos)):
			continue
		var at: Vector2 = to_map.call(e.pos)
		if at.distance_to(center) <= RADAR_RADIUS - 5:
			draw_circle(at, 3.2, RADAR_INK)
			draw_circle(at, 2.3, RADAR_ENEMY)
		else:
			var d := (at - center).normalized()
			var tip := center + d * (RADAR_RADIUS - 3)
			var arrow := PackedVector2Array([tip, tip - d * 7 + d.orthogonal() * 4, tip - d * 7 - d.orthogonal() * 4])
			draw_colored_polygon(arrow, RADAR_ENEMY)
			arrow.append(arrow[0])
			draw_polyline(arrow, RADAR_INK, 1.0)
	for m in party:
		if m == focus:
			continue
		var at: Vector2 = to_map.call(m.pos)
		if at.distance_to(center) > RADAR_RADIUS - 4:
			continue
		if m.dead:
			continue
		if m.is_alive():
			draw_circle(at, 3.2, RADAR_INK)
			draw_circle(at, 2.3, PlaceholderArt.color("destaque"))
		else:  # caído: X cinza até ser reanimado
			draw_line(at + Vector2(-2.5, -2.5), at + Vector2(2.5, 2.5), Color(0.6, 0.58, 0.54), 1.5)
			draw_line(at + Vector2(-2.5, 2.5), at + Vector2(2.5, -2.5), Color(0.6, 0.58, 0.54), 1.5)
	# Controlado: seta no centro, apontando para onde olha.
	var dir := Vector2.RIGHT.rotated(_facing_angle(focus))
	var side := dir.orthogonal()
	var tri := PackedVector2Array([center + dir * 6.5, center - dir * 4 + side * 4.5, center - dir * 2 , center - dir * 4 - side * 4.5])
	draw_colored_polygon(tri, PlaceholderArt.color("destaque"))
	tri.append(tri[0])
	draw_polyline(tri, RADAR_INK, 1.0)

	# Moldura: aro escuro, aro de bronze, marcas dos pontos cardeais e o N no topo.
	draw_arc(center, RADAR_RADIUS + 1.5, 0.0, TAU, 64, RADAR_INK, 3.0)
	draw_arc(center, RADAR_RADIUS - 0.5, 0.0, TAU, 64, RADAR_BRONZE, 1.5)
	for k in 4:
		var d := Vector2.UP.rotated(TAU * k / 4.0)
		draw_line(center + d * (RADAR_RADIUS - 5), center + d * (RADAR_RADIUS - 1), RADAR_BRONZE, 1.5)
	var n_at := center + Vector2(0, -RADAR_RADIUS - 1)
	draw_circle(n_at, 6.5, RADAR_INK)
	draw_arc(n_at, 6.5, 0.0, TAU, 24, RADAR_BRONZE, 1.0)
	draw_string(font, n_at + Vector2(-6.5, 4), "N", HORIZONTAL_ALIGNMENT_CENTER, 13, 10, Color(0.83, 0.67, 0.31))
	# Placa com o nome do local logo abaixo.
	var plate := Rect2(center + Vector2(-46, RADAR_RADIUS + 4), Vector2(92, 15))
	draw_rect(plate, Color(0.07, 0.05, 0.04, 0.9))
	draw_rect(plate, RADAR_BRONZE, false, 1.0)
	draw_string(font, plate.position + Vector2(0, 11), "SALA DE TESTE", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 10, Color(0.93, 0.89, 0.8))
