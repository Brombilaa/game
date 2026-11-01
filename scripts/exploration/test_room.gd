extends Node2D
# Sala de teste: exploração com clique para mover, uma porta, inimigos e coberturas.
# A rota contorna obstáculos via Pathfinder; destino inacessível é ignorado.
# Inimigo que vê o personagem (alcance + linha de visão) inicia o combate na hora. C agacha:
# a percepção dos inimigos cai à metade. Clique num inimigo sem alerta faz o ataque furtivo.
# Combate por turnos (TurnManager + CombatRules): no turno do agente, clique no chão
# move (gasta PA), clique no inimigo ataca,
# Espaço passa o turno e D atrasa. R reinicia a sala.
# Grupo (Léo): controla um personagem por vez e os outros seguem espalhados, a distância fixa
# do líder e posição variando. Tab, 1, 2, 3 ou clique no retrato trocam o controlado (na exploração).
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
const KIT_ID := "kit_primeiros_socorros"
const SWAP_PA := 1  # trocar de arma em combate (GDD #18)
const SHEET_SCALE := 0.75  # fichas do grupo 25% menores que o desenho em tamanho cheio (pedido do Léo, 30/10/2026)
const SHEET_SIZE := Vector2(223, 75) * SHEET_SCALE  # retrato e ficha lado a lado
const HUD_BRONZE := Color(0.43, 0.34, 0.24)
# Moldura A, bronze gótico (Léo escolheu entre três modelos, 30/10/2026).
const FRAME_FILL := Color(0.063, 0.043, 0.031, 0.93)
const FRAME_OUTER := Color(0.612, 0.455, 0.22)
const FRAME_INNER := Color(0.353, 0.255, 0.149)
const FRAME_ACCENT := Color(0.839, 0.678, 0.361)
const FRAME_ENEMY := Color(0.639, 0.149, 0.165)
const CONDITION_ICONS := {  # ordem e cor dos ícones de condição embaixo do retrato
	"sangrando": Color(0.85, 0.2, 0.2), "atordoado": Color(0.95, 0.82, 0.35),
	"em_chamas": Color(0.95, 0.5, 0.15), "envenenado": Color(0.5, 0.75, 0.35),
}
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
# Quadro da caminhada avança por distância percorrida na tela (não por tempo): os pés não deslizam,
# cada unidade tem a sua própria fase e o ritmo é o mesmo em todas as direções.
const WALK_FRAME_PIXELS := 15.0
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
# Grupo de teste: Fernando, Nikolai e Miguel (só para exercitar grupo, troca e reanimação).
var party: Array[Combatant] = [
	cfg.make_unit("agente", "Fernando", Vector2(160, 360)),
	cfg.make_unit("agente", "Nikolai", Vector2(110, 320)),
	cfg.make_unit("agente", "Miguel", Vector2(110, 400)),
]
var player: Combatant = party[0]  # personagem controlado (no combate, o do turno)
var looks := {}  # membro do grupo -> índice em AGENT_SHEETS
var follow_paths := {}  # seguidor -> rota restante na exploração
var follow_offsets := {}  # seguidor -> posição relativa ao líder
var follow_rng := RandomNumberGenerator.new()
var inventory: Inventory  # mochila compartilhada do grupo (20 espaços)
var gear := {}  # membro -> {"principal", "secundaria", "colete", "acessorio"}: ids ("" = vazio)
var inv_panel: InventoryPanel
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
var walk_dist := {}  # unidade -> distância (px de tela) andada desde que começou a andar
var idle_frame := 0
var cursor_kind := GameCursor.Kind.ARROW
var agent_sheets: Array[CharacterSheet] = []
var enemy_sheets := {}  # variante -> CharacterSheet
var scenery := Scenery.new()
var nikolai3d := AnimSheet.new()  # Nikolai em 3D renderizado como pixel art (teste das animações)
var use_3d := true  # tecla V troca entre o Nikolai 3D e o sprite 2D
var anim3d_pick := -1  # tecla N: -1 = automático (parado/andando); senão o índice em AnimSheet.NAMES
var anim3d_tick := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.03, 0.025, 0.02))  # fora da sala e salas fechadas: escuridão
	hud.room_draws_hud = true  # a sala desenha modo, PA e fim do turno na moldura A
	add_child(hud)
	add_child(audio)
	for path in AGENT_SHEETS:
		agent_sheets.append(CharacterSheet.new(path))
	looks[party[0]] = 0
	looks[party[1]] = 1
	party[1].max_san = 16  # Nikolai é Especialista (SAN inicial 16); a ficha de teste é a mesma
	party[1].san = 16
	looks[party[2]] = 2
	party[2].max_san = 20  # Miguel é Ocultista (SAN inicial 20) e luta com a espada (GDD #16)
	party[2].san = 20
	party[2].weapon = cfg.weapon("espada")
	_setup_gear()
	inv_panel = InventoryPanel.new()
	inv_panel.room = self
	var inv_layer := CanvasLayer.new()  # fica sobre o HUD e não acompanha a câmera
	inv_layer.layer = 20
	inv_layer.add_child(inv_panel)
	add_child(inv_layer)
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
	GameCursor.apply(GameCursor.Kind.ARROW)


# Mira vermelha quando o mouse está sobre um inimigo que o controlado pode atacar; seta dourada no resto.
func _update_cursor() -> void:
	var kind := GameCursor.Kind.ARROW
	if _player_ready():
		var target := _enemy_at(_resolve_click(get_global_mouse_position()))
		if target and rules.attack_blocker(player, target, _sight_blockers(), covers) == "":
			kind = GameCursor.Kind.ATTACK
	if kind != cursor_kind:
		cursor_kind = kind
		GameCursor.apply(kind)


# Zoom da câmera pela roda do mouse (Léo, 01/11/2026). A câmera segue fixa e isométrica; só a
# aproximação muda, em passos, dentro de [_zoom_min(), ZOOM_MAX]. A sala de teste usa 1 a 3.
const ZOOM_MAX := 3.0
const ZOOM_STEP := 1.1


func _zoom_min() -> float:
	return 1.0


func _zoom_by(factor: float) -> void:
	var z := clampf(camera.zoom.x * factor, _zoom_min(), ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	queue_redraw()  # o HUD e a prévia do mouse dependem do zoom


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(ZOOM_STEP)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / ZOOM_STEP)
			return
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
		elif event.pressed and event.keycode == KEY_Q:
			_swap_weapon()
		elif event.pressed and event.keycode == KEY_V:
			use_3d = not use_3d
			_popup(player.pos, "Nikolai 3D" if use_3d else "Nikolai 2D")
			queue_redraw()
		elif event.pressed and event.keycode == KEY_N:
			anim3d_pick = (anim3d_pick + 2) % (AnimSheet.NAMES.size() + 1) - 1
			_popup(player.pos, "anim: automático" if anim3d_pick < 0 else "anim: " + AnimSheet.NAMES[anim3d_pick])
			queue_redraw()
		elif event.pressed and event.keycode == KEY_C and mode == Mode.EXPLORATION:
			player.crouched = not player.crouched
			queue_redraw()
		return
	if event is InputEventMouseMotion:
		_update_cursor()
	if event is InputEventMouseMotion and mode == Mode.COMBAT:
		queue_redraw()  # atualiza a prévia de chance/custo sob o cursor
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen := get_viewport().get_mouse_position()
		var portrait := _portrait_at(screen)
		if portrait:
			_switch_to(portrait)
			return
		if _mouse_on_hud(screen):  # rodapé: o fim do turno passa a vez; os ícones não movem o personagem
			var n := _action_slots().size()
			if _end_turn_rect(n).has_point(screen):
				_player_pass()
			elif _reserve_id() != "" and _action_rect(1, n).has_point(screen):
				_swap_weapon()
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
func _obstacles(mover: Combatant = null, with_units := true) -> Array[Rect2]:
	var obstacles := _sight_blockers()
	for c: Cover in covers:
		if not c.is_destroyed():
			obstacles.append(c.rect)
	for u in _living_units() if with_units else []:
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
	if inv_panel and inv_panel.open:
		return  # inventário aberto: o tempo para (GDD #23)
	_update_discovered()
	if mode == Mode.COMBAT and _player_ready():
		queue_redraw()  # gema de PA pulsando e estados do botão de fim do turno
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
	_update_cursor()
	var focus := turns.current if mode == Mode.COMBAT and turns and turns.current else player
	camera.position = _iso(focus.pos).round()  # pixel inteiro: o cenário não treme ao andar
	if moving_unit and not path.is_empty():
		var step := _iso(path[0]) - _iso(moving_unit.pos)  # a direção vista na tela
		facing[moving_unit] = PlaceholderArt.dir_from_vector(step)
		facing8[moving_unit] = CharacterSheet.dir_from_vector(step)
		var before := _iso(moving_unit.pos)
		moving_unit.pos = moving_unit.pos.move_toward(path[0], SPEED * delta)
		walk_dist[moving_unit] = walk_dist.get(moving_unit, 0.0) + before.distance_to(_iso(moving_unit.pos))
		if moving_unit.pos.is_equal_approx(path[0]):
			path.remove_at(0)
		if path.is_empty():
			moving_unit = null
			move_finished.emit()
		queue_redraw()
	var tick3d := int(Time.get_ticks_msec() / 100.0)  # o Nikolai 3D anima a até 10 quadros por segundo
	if use_3d and tick3d != anim3d_tick:
		anim3d_tick = tick3d
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
	if inventory.count(KIT_ID) <= 0:
		_reject("requirement")
	elif CombatRules.gap(player, fallen) > REVIVE_REACH:
		_reject("out_of_range")
	elif not turns.spend(player, cost):
		_reject("no_pa")
	else:
		inventory.remove(KIT_ID)
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
	var plan := rules.plan_move(full, player.pa, player.moved_px)
	if CombatRules.path_length(plan.path) < 1.0:
		if plan.cost == 0 and rules.move_cost(CombatRules.path_length(full), player.moved_px) > 0:
			_reject("no_pa")
		return
	if plan.cost > player.pa or (plan.cost > 0 and not turns.spend(player, plan.cost)):
		_reject("no_pa")
		return
	player.moved_px += CombatRules.path_length(plan.path)
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


# Arma de reserva do controlado ("" se não tem).
func _reserve_id() -> String:
	return str(gear[player]["secundaria"])


# Troca a arma em mãos pela reserva: 1 PA em combate (GDD #18), grátis fora dele.
func _swap_weapon() -> void:
	var id := _reserve_id()
	if id == "" or not player.is_alive():
		return
	if mode == Mode.COMBAT:
		if not _player_ready():
			return
		if not turns.spend(player, SWAP_PA):
			_reject("no_pa")
			return
	gear[player]["secundaria"] = gear[player]["principal"]
	gear[player]["principal"] = id
	player.weapon = cfg.weapon(id)
	hud.show_notice("Empunhou: %s" % cfg.game_data.get_entry("armas", id).get("nome", id))
	queue_redraw()


# --- Inventário e equipamento ---------------------------------------------------
# A mochila (Inventory) e o equipamento de cada um (`gear`) mandam; o painel (InventoryPanel)
# só desenha e chama estas funções. Cada uma devolve a mensagem para o painel ("" se nada a dizer).

# O inventário abre fora do combate ou no turno do jogador (o tempo para; no turno inimigo não).
func inventory_can_open() -> bool:
	return mode == Mode.EXPLORATION or _player_ready()


# "arma", "colete" ou "item".
func gear_item_kind(id: String) -> String:
	if cfg.game_data.has_entry("armas", id):
		return "arma"
	if cfg.game_data.get_entry("itens", id).get("efeito") == "defesa":
		return "colete"
	return "item"


func gear_is_equippable(id: String) -> bool:
	return gear_item_kind(id) != "item"


func gear_slot_id(m: Combatant, slot: String) -> String:
	return str(gear[m][slot])


# Em combate só quem está na vez troca de arma, por 1 PA; colete só fora do combate.
func _gear_change_cost(m: Combatant, kind: String) -> Variant:
	if mode != Mode.COMBAT:
		return 0
	if kind == "colete":
		return "Troque de colete fora do combate"
	if m != player:
		return "Só quem está na vez troca de arma"
	return SWAP_PA


# Equipa o item do espaço `bag_index` no espaço `slot` de `m`; o que estava lá vai para o lugar dele.
func gear_equip(m: Combatant, slot: String, bag_index: int) -> String:
	var entry: Dictionary = inventory.slots[bag_index]
	if entry.is_empty():
		return ""
	var id := str(entry["id"])
	var kind := gear_item_kind(id)
	if kind == "item" or slot == "acessorio":
		return "Esse item não vai aí"
	if (kind == "colete") != (slot == "colete"):
		return "Esse item não vai aí"
	var cost = _gear_change_cost(m, kind)
	if cost is String:
		return cost
	if cost > 0 and not turns.spend(player, cost):
		_reject("no_pa")
		return "PA insuficientes"
	var old := str(gear[m][slot])
	inventory.slots[bag_index] = {"id": old, "qty": 1} if old != "" else {}
	gear[m][slot] = id
	if slot == "principal":
		m.weapon = cfg.weapon(id)
	elif slot == "colete":
		m.defense = float(cfg.game_data.get_entry("itens", id)["valor"])
	queue_redraw()
	return "%s: %s" % [m.name, cfg.game_data.get_entry("armas", id).get("nome", cfg.game_data.get_entry("itens", id).get("nome", id))]


# Troca a arma principal pela secundária de `m` (no inventário; Q faz o mesmo para o controlado).
func gear_swap_weapons(m: Combatant) -> String:
	var g: Dictionary = gear[m]
	if g["secundaria"] == "" and g["principal"] == "":
		return ""
	var cost = _gear_change_cost(m, "arma")
	if cost is String:
		return cost
	if cost > 0 and not turns.spend(player, cost):
		_reject("no_pa")
		return "PA insuficientes"
	var main: String = g["principal"]
	g["principal"] = g["secundaria"]
	g["secundaria"] = main
	m.weapon = cfg.weapon(g["principal"]) if g["principal"] != "" else cfg.weapon("soco")
	queue_redraw()
	return "%s empunha %s" % [m.name, cfg.game_data.get_entry("armas", g["principal"]).get("nome", "o soco")]


# Guarda de volta na mochila o que `m` tem em `slot`.
func gear_unequip(m: Combatant, slot: String) -> String:
	var id := str(gear[m][slot])
	if id == "":
		return ""
	var cost = _gear_change_cost(m, gear_item_kind(id))
	if cost is String:
		return cost
	if inventory.free_slot() < 0:
		return "Mochila cheia"
	if cost > 0 and not turns.spend(player, cost):
		_reject("no_pa")
		return "PA insuficientes"
	inventory.add(id)
	gear[m][slot] = ""
	if slot == "principal":
		m.weapon = cfg.weapon("soco")
	elif slot == "colete":
		m.defense = 0.0
	queue_redraw()
	return "Guardou na mochila"


func gear_discard(bag_index: int) -> String:
	var gone := inventory.discard(bag_index)
	return "" if gone.is_empty() else "Descartou %s" % cfg.game_data.get_entry("itens", str(gone["id"])).get("nome", cfg.game_data.get_entry("armas", str(gone["id"])).get("nome", gone["id"]))


# Usa um consumível da mochila em `m`: bandagem tira o sangramento, antídoto o veneno.
# O kit de primeiros socorros reanima aliado caído e só se usa pela barra de combate.
func gear_use(m: Combatant, bag_index: int) -> String:
	var id := str(inventory.slots[bag_index].get("id", ""))
	var effect := str(cfg.game_data.get_entry("itens", id).get("efeito", ""))
	var cures := {"remover_sangrando": "sangrando", "remover_envenenado": "envenenado"}
	if id == KIT_ID:
		return "O kit reanima um aliado caído (barra de combate)"
	if not cures.has(effect):
		return "Sem efeito por enquanto"
	if not m.has_condition(cures[effect]):
		return "%s não precisa" % m.name
	if mode == Mode.COMBAT:
		if m != player:
			return "Só quem está na vez usa itens"
		if not turns.spend(player, int(cfg.game_data.get_entry("itens", id)["custo_pa_combate"])):
			_reject("no_pa")
			return "PA insuficientes"
	m.conditions.erase(cures[effect])
	inventory.remove(id)
	queue_redraw()
	return "%s usou %s" % [m.name, cfg.game_data.get_entry("itens", id)["nome"]]


# Mochila e equipamento iniciais da sala de teste (provisório do Claude).
func _setup_gear() -> void:
	inventory = Inventory.new(cfg.game_data)
	for item in [[KIT_ID, 1], ["bandagem", 2], ["antidoto", 1], ["colete_leve", 1], ["colete_pesado", 1]]:
		inventory.add(item[0], item[1])
	for m in party:
		var second = cfg.game_data.get_entry("personagens", m.name.to_lower()).get("arma_secundaria")
		var main := str(m.weapon["id"])
		gear[m] = {"principal": main, "secundaria": "" if second == null or str(second) == main else str(second), "colete": "", "acessorio": ""}


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
	if not Pathfinder.is_free(unit.pos, _obstacles(unit), unit.radius):
		# Preso dentro de um obstáculo (ex.: surgiu atrás da árvore): salta para o ponto livre
		# mais perto do alvo, sem gastar PA, e segue o turno de lá (Léo, 01/11/2026).
		var spot := _jump_spot(unit, target)
		if spot == Vector2.INF:
			return false
		_start_move(unit, PackedVector2Array([unit.pos, spot]))
		await move_finished
		return true
	var full := pathfinder.find_path(unit.pos, stand, _obstacles(unit), unit.radius)
	if full.size() < 2:
		return false
	var plan := rules.plan_move(full, unit.pa, unit.moved_px)
	if CombatRules.path_length(plan.path) < 1.0 or (plan.cost > 0 and not turns.spend(unit, plan.cost)):
		return false
	unit.moved_px += CombatRules.path_length(plan.path)
	_start_move(unit, plan.path)
	await move_finished
	turns.action_done()
	return true


# Ponto livre perto de `unit` de onde há caminho até o alvo; entre os candidatos, o mais perto do
# alvo (na prática, o lado da frente do obstáculo). Vector2.INF se não houver.
func _jump_spot(unit: Combatant, target: Combatant) -> Vector2:
	var obstacles := _obstacles(unit)
	var candidates: Array[Vector2] = []
	for ring in range(1, 26):
		for k in 16:
			var spot := unit.pos + Vector2.from_angle(TAU * k / 16.0) * ring * 8.0
			if Pathfinder.is_free(spot, obstacles, unit.radius):
				candidates.append(spot)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(target.pos) < b.distance_to(target.pos))
	for spot in candidates.slice(0, 12):
		var stand := target.pos.move_toward(spot, target.radius + unit.radius + 2.0)
		if pathfinder.find_path(spot, stand, obstacles, unit.radius).size() > 1:
			return spot
	return candidates[0] if not candidates.is_empty() else Vector2.INF


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
	if not walking:
		walk_dist.erase(u)  # a próxima caminhada recomeça no primeiro quadro
	var walk_n := int(walk_dist.get(u, 0.0) / WALK_FRAME_PIXELS)
	var i := enemies.find(u)
	if i < 0:
		if use_3d and looks.get(u, 0) == 1:
			var anim := "walk" if walking else "idle"
			if anim3d_pick >= 0:
				anim = AnimSheet.NAMES[anim3d_pick]
			var count := nikolai3d.frame_count(anim)
			var f := int(Time.get_ticks_msec() / 1000.0 * AnimSheet.FPS[anim]) % count
			if walking and anim3d_pick < 0:
				f = int(walk_dist.get(u, 0.0) / (WALK_FRAME_PIXELS * 6.0 / count)) % count  # passo por distância
			nikolai3d.draw(self, at, anim, f, facing8.get(u, CharacterSheet.Dir.SE))
		else:
			var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
			var n := walk_n % frames.size() if walking else idle_frame
			agent_sheets[looks.get(u, 0)].draw(self, at, frames[n], facing8.get(u, CharacterSheet.Dir.SE))
		if not u.is_alive():
			draw_string(ThemeDB.fallback_font, at + Vector2(-22, -CharacterSheet.HEIGHT - 14), "CAÍDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))
	else:
		var variant := _enemy_variant(i)
		if enemy_sheets.has(variant):
			var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
			var n := walk_n % frames.size() if walking else idle_frame
			enemy_sheets[variant].draw(self, at, frames[n], facing8.get(u, CharacterSheet.Dir.SW))
		else:
			var frame := 1 + walk_n % 2 if walking else 0
			var tex := PlaceholderArt.character_texture(variant, facing.get(u, PlaceholderArt.Dir.SOUTH), frame)
			var size := Vector2(PlaceholderArt.FRAME_SIZE * PLACEHOLDER_SCALE)
			draw_texture_rect(tex, Rect2((at - PlaceholderArt.PIVOT * PLACEHOLDER_SCALE).round(), size), false)
	if mode != Mode.EXPLORATION:
		var bar := Rect2(at + Vector2(-20, -CharacterSheet.HEIGHT - 8), Vector2(40, 4))
		draw_rect(bar, Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(u.pv) / u.max_pv, bar.size.y)), Color(0.3, 0.85, 0.35))


# Rota da prévia do mouse. A prévia é redesenhada todo quadro; refazer o pathfinding a cada quadro
# travava o jogo, então a rota só é recalculada quando muda o ponto do mouse, quem anda ou as unidades.
var _route_key := ""
var _route_cache := PackedVector2Array()


func _preview_route(mouse: Vector2) -> PackedVector2Array:
	var key := "%s|%s|%s" % [player.pos, mouse.round(), _living_units().map(func(u: Combatant) -> Vector2: return u.pos)]
	if key != _route_key:
		_route_key = key
		_route_cache = pathfinder.find_path(player.pos, mouse, _obstacles(player), player.radius)
	return _route_cache


# Prévia sob o cursor no turno do agente: chance de acerto no inimigo ou custo do movimento.
func _draw_preview(font: Font) -> void:
	if not _player_ready() or _mouse_on_hud(get_viewport().get_mouse_position()):
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
		var route := _preview_route(mouse)
		if route.is_empty():
			text = "Inacessível"
		else:
			var cost := rules.move_cost(CombatRules.path_length(route), player.moved_px)
			var plan := rules.plan_move(route, player.pa, player.moved_px)
			_draw_move_path(font, route, plan["path"], int(plan["cost"]), cost > player.pa)
	if text != "":
		draw_string(font, screen_mouse + Vector2(14, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


# Caminho do movimento antes do clique (modelo C, Léo, 30/10/2026): marcas de passo em ouro até
# onde os PA chegam, o resto apagado em vermelho, e o ladrilho aceso no destino com o custo em cima.
# `route` é a rota inteira, `reach` o trecho que os PA pagam e `over` diz se o destino passa do saldo.
func _draw_move_path(font: Font, route: PackedVector2Array, reach: PackedVector2Array, cost: int, over: bool) -> void:
	var gold := Color(0.96, 0.78, 0.36)
	var dim := Color(0.8, 0.28, 0.25, 0.5)
	var total := CombatRules.path_length(route)
	var reach_len := CombatRules.path_length(reach)
	var end_room: Vector2 = reach[reach.size() - 1] if reach.size() > 0 else route[route.size() - 1]
	var d := 0.0
	var side := 1.0
	while d < total:
		var a := _iso(_point_along(route, d))
		var b := _iso(_point_along(route, minf(d + 4.0, total)))
		var dir := (b - a).normalized()
		var off := dir.orthogonal() * side * 3.0
		draw_line(a + off, a + off + dir * 4.0, Color(gold, 0.8) if d < reach_len else dim, 1.5 if d < reach_len else 1.0)
		side = -side
		d += 12.0
	_draw_floor_halo(_iso(end_room), 13.0, gold)
	var text := "%d PA%s" % [cost, " (parcial)" if over else ""]
	var w := 36.0 if not over else 78.0
	var tag := _iso(end_room) + Vector2(0, -20)
	draw_rect(Rect2(tag - Vector2(w * 0.5, 9), Vector2(w, 16)), Color(0.04, 0.03, 0.025, 0.9))
	draw_rect(Rect2(tag - Vector2(w * 0.5, 9), Vector2(w, 16)).grow(-0.5), gold, false, 0.75)
	draw_string(font, tag + Vector2(-w * 0.5 + 2, 3), text, HORIZONTAL_ALIGNMENT_CENTER, w - 4, 10, gold)


# Ponto de `route` a `dist` pixels do começo (o último, se passar do fim).
func _point_along(route: PackedVector2Array, dist: float) -> Vector2:
	var left := dist
	for i in range(1, route.size()):
		var seg := route[i - 1].distance_to(route[i])
		if left <= seg and seg > 0.0:
			return route[i - 1].lerp(route[i], left / seg)
		left -= seg
	return route[route.size() - 1]


# Halo pequeno no chão (destino do movimento): anéis de luz achatados na proporção do chão
# isométrico (2:1), mais fortes no centro, com um aro fino de ouro.
func _draw_floor_halo(c: Vector2, radius: float, color: Color) -> void:
	for i in 5:
		var t := 1.0 - i / 5.0
		_draw_ellipse(c, radius * (0.45 + 0.55 * t), Color(color, 0.07 + 0.05 * (1.0 - t)), true)
	_draw_ellipse(c, radius * 0.9, Color(color, 0.85), false)
	draw_circle(c, 1.2, Color(1, 0.92, 0.7, 0.9))


func _draw_ellipse(c: Vector2, radius: float, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * radius, sin(a) * radius * 0.5))
	if filled:
		draw_colored_polygon(pts, color)
	else:
		draw_polyline(pts + PackedVector2Array([pts[0]]), color, 0.75)


# --- Grupo ---------------------------------------------------------------------

# Troca o personagem controlado (só na exploração; no combate manda a ordem dos turnos).
func _switch_to(m: Combatant) -> void:
	if mode != Mode.EXPLORATION or m == player or m.dead or not m.is_alive():
		return
	if moving_unit == player:
		path = PackedVector2Array()
		moving_unit = null
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
			if route.is_empty():
				# Dois seguidores se encostaram e um ficou dentro do obstáculo do outro: sem esta rota
				# de reserva (só paredes e coberturas) ele ficaria parado para sempre.
				route = pathfinder.find_path(m.pos, goal, _obstacles(m, false), m.radius)
			if not route.is_empty():
				route.remove_at(0)
		if route.is_empty():
			follow_paths.erase(m)
			continue
		var step := _iso(route[0]) - _iso(m.pos)
		facing8[m] = CharacterSheet.dir_from_vector(step)
		var before := _iso(m.pos)
		m.pos = m.pos.move_toward(route[0], SPEED * delta)
		walk_dist[m] = walk_dist.get(m, 0.0) + before.distance_to(_iso(m.pos))
		if m.pos.is_equal_approx(route[0]):
			route.remove_at(0)
		follow_paths[m] = route
		queue_redraw()


# Medida do desenho em tamanho cheio -> pixels da ficha na escala atual.
func _k(v: float) -> float:
	return v * SHEET_SCALE


func _fs(size: int) -> int:
	return maxi(roundi(size * SHEET_SCALE), 8)


func _portrait_rect(i: int) -> Rect2:
	return Rect2(Vector2(8, 8 + i * _k(98)), SHEET_SIZE)  # sobra espaço para os ícones de condição


# Mouse sobre uma ficha ou sobre o rodapé de ações: sem prévia de movimento ou ataque.
func _mouse_on_hud(screen: Vector2) -> bool:
	if _portrait_at(screen):
		return true
	if mode != Mode.COMBAT or not _player_ready():
		return false
	return _bar_rect(_action_slots().size()).grow(8).has_point(screen)  # a barra inteira e a faixa de PA


func _portrait_at(screen: Vector2) -> Combatant:
	for i in party.size():
		if _portrait_rect(i).has_point(screen):
			return party[i]
	return null


# HUD da ideia A (Léo, 29/10/2026) na moldura A, bronze gótico (Léo escolheu, 30/10/2026): fichas do
# grupo à esquerda, ordem dos turnos no topo, radar à direita e, no turno do jogador, PA, ações e
# fim do turno no rodapé. Desenhado em pixels da tela (960×540).
func _draw_hud(font: Font) -> void:
	var to_world := _hud_to_world()
	for i in party.size():
		_draw_sheet(font, party[i], to_world * _portrait_rect(i).position)
	_draw_minimap(font, to_world)
	if mode == Mode.COMBAT and turns:
		_draw_turn_order(font, to_world)
		if _player_ready():
			_draw_actions(font, to_world)


# Da posição na tela (960×540) para onde o HUD é desenhado. Com a câmera aproximada o parque desenha o
# HUD com escala inversa ao zoom e troca isto por uma translação.
func _hud_to_world() -> Transform2D:
	return get_canvas_transform().affine_inverse()


# Moldura A: placa escura, filete duplo de bronze e cantoneiras com voluta e losango.
# `s` encolhe os enfeites junto com a peça (fichas usam SHEET_SCALE).
func _draw_frame(r: Rect2, enemy := false, s := 1.0) -> void:
	var outer := FRAME_ENEMY if enemy else FRAME_OUTER
	var accent := FRAME_ENEMY if enemy else FRAME_ACCENT
	draw_rect(r, FRAME_FILL)
	draw_rect(r.grow(-1.0 * s), outer, false, 1.0)
	draw_rect(r.grow(-4.0 * s), FRAME_INNER, false, 0.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o: Vector2 = r.position + corner * r.size
		var d := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0) * s  # para dentro da peça
		var arc := PackedVector2Array()
		for k in 7:  # voluta: curva de (1, 9) a (9, 1) puxada para o canto
			var t := k / 6.0
			var p := Vector2(1, 9).lerp(Vector2(1, 1), t).lerp(Vector2(1, 1).lerp(Vector2(9, 1), t), t)
			arc.append(o + p * d)
		draw_polyline(arc, accent, 0.5)
		draw_polyline(PackedVector2Array([o + Vector2(4, 11) * d, o + Vector2(4, 4) * d, o + Vector2(11, 4) * d]), accent, 0.5)
		_draw_diamond(o + Vector2(3.25, 3.25) * d, 2.5 * s, accent)
	if r.size.x > 80:  # losango no meio das bordas de cima e de baixo
		_draw_diamond(Vector2(r.get_center().x, r.position.y + 1), 3.5 * s, accent)
		_draw_diamond(Vector2(r.get_center().x, r.end.y - 1), 3.5 * s, accent)


func _draw_diamond(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


# Ficha de um membro do grupo: retrato numa moldura e, ao lado, nome, PV e SAN em outra.
# As medidas são do desenho em tamanho cheio e passam por `_k` (SHEET_SCALE).
func _draw_sheet(font: Font, m: Combatant, pos: Vector2) -> void:
	var active := m == player
	var face_box := Rect2(pos, Vector2(_k(75), _k(75)))
	var info := Rect2(pos + Vector2(_k(73), _k(10)), Vector2(_k(150), _k(56)))
	_draw_frame(info, false, SHEET_SCALE)
	_draw_frame(face_box, false, SHEET_SCALE)
	var face := face_box.grow(-_k(6))
	draw_rect(face, Color(0.16, 0.12, 0.09))
	agent_sheets[looks.get(m, 0)].draw_portrait(self, face)
	if not m.is_alive():
		draw_rect(face, Color(0.4, 0, 0, 0.5))
	if active:
		draw_rect(face_box.grow(-_k(1)), FRAME_ACCENT, false, 1.5)
	var left := info.position.x + _k(11)
	draw_string(font, Vector2(left, info.position.y + _k(17)), m.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), FRAME_ACCENT if active else Color(0.91, 0.87, 0.79))
	var status := ""
	if m.dead:
		status = "MORTO"
	elif not m.is_alive():
		status = "CAÍDO"
	elif mode == Mode.COMBAT and turns and turns.current == m:
		status = "na vez"
	elif mode == Mode.COMBAT:
		status = "aguardando"
	elif m.crouched:
		status = "agachado"
	if status != "":
		draw_string(font, Vector2(left, info.position.y + _k(17)), status, HORIZONTAL_ALIGNMENT_RIGHT, info.size.x - _k(22), _fs(10), Color(1, 0.45, 0.45) if status in ["MORTO", "CAÍDO"] else Color(0.66, 0.6, 0.49))
	_draw_bar(font, Vector2(left - _k(3), info.position.y + _k(22)), "pv", m.pv, m.max_pv, Color(0.74, 0.16, 0.16), Color(0.45, 0.07, 0.07))
	_draw_bar(font, Vector2(left - _k(3), info.position.y + _k(37)), "san", m.san, m.max_san, Color(0.33, 0.52, 0.8), Color(0.15, 0.26, 0.5))
	var k := 0
	for id in CONDITION_ICONS:  # condições ativas embaixo do retrato
		if m.has_condition(id):
			_draw_condition(Rect2(pos + Vector2(_k(1) + k * _k(21), _k(76)), Vector2(_k(20), _k(20))), id)
			k += 1


# Ícone de condição: quadrado escuro com o símbolo na cor da condição.
func _draw_condition(r: Rect2, id: String) -> void:
	var color: Color = CONDITION_ICONS[id]
	draw_rect(r, FRAME_FILL)
	draw_rect(r, color, false, 1.0)
	if ItemIcons.CONDITION_ART.has(id):
		draw_texture_rect(ItemIcons.CONDITION_ART[id], r.grow(-r.size.x * 0.04), false)
		return
	var c := r.get_center()
	var u := r.size.x / 15.0
	match id:
		"sangrando":  # gota
			draw_circle(c + Vector2(0, 1.5) * u, 3.0 * u, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, 0.5) * u, c + Vector2(0, -5) * u, c + Vector2(2.6, 0.5) * u]), color)
		"atordoado":  # estrela de quatro pontas
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5) * u, c + Vector2(1.2, -1.2) * u, c + Vector2(5, 0) * u, c + Vector2(1.2, 1.2) * u,
				c + Vector2(0, 5) * u, c + Vector2(-1.2, 1.2) * u, c + Vector2(-5, 0) * u, c + Vector2(-1.2, -1.2) * u]), color)
		"em_chamas":  # chama
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, 4) * u, c + Vector2(-3.5, 0) * u, c + Vector2(-1, -2.5) * u, c + Vector2(0, -5.5) * u,
				c + Vector2(1.5, -2) * u, c + Vector2(3.5, -0.5) * u, c + Vector2(3.5, 4) * u]), color)
		_:  # envenenado: bolhas
			draw_circle(c + Vector2(-1.5, 1.5) * u, 2.6 * u, color)
			draw_circle(c + Vector2(2.2, -2.2) * u, 1.6 * u, color)


# Barra com ícone (coração de PV, olho de SAN), fundo chanfrado, degradê, divisões a cada 5 pontos e brilho.
func _draw_bar(font: Font, at: Vector2, kind: String, value: int, maximum: int, color: Color, shade: Color) -> void:
	var icon := at + Vector2(_k(7), _k(7))
	if kind == "pv":
		var h := _k(5.0)
		draw_circle(icon + Vector2(-h * 0.5, -h * 0.35), h * 0.6, color)
		draw_circle(icon + Vector2(h * 0.5, -h * 0.35), h * 0.6, color)
		draw_colored_polygon(PackedVector2Array([icon + Vector2(-h * 1.05, -h * 0.1), icon + Vector2(h * 1.05, -h * 0.1), icon + Vector2(0, h * 1.1)]), color)
	else:
		var w := _k(6.5)
		var eye := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			eye.append(icon + Vector2(lerpf(-w, w, t), -sin(t * PI) * _k(3.4)))
		for i in 13:
			var t := 1.0 - i / 12.0
			eye.append(icon + Vector2(lerpf(-w, w, t), sin(t * PI) * _k(3.4)))
		draw_polyline(eye + PackedVector2Array([eye[0]]), color, 1.0)
		draw_circle(icon, _k(2.2), color)
	var bar := Rect2(at + Vector2(_k(18), _k(1)), Vector2(_k(114), _k(12)))
	draw_rect(Rect2(bar.position - Vector2(1, 1), bar.size + Vector2(2, 2)), Color(0.04, 0.03, 0.03))
	draw_rect(bar, Color(0.12, 0.1, 0.09))
	var fill := bar.size.x * clampf(float(value) / maxf(maximum, 1), 0.0, 1.0) if maximum > 0 else 0.0
	if fill > 0.0:
		draw_rect(Rect2(bar.position, Vector2(fill, bar.size.y)), shade)
		draw_rect(Rect2(bar.position, Vector2(fill, bar.size.y * 0.55)), color)
		draw_rect(Rect2(bar.position + Vector2(0, 1), Vector2(fill, 1)), color.lightened(0.35))
	if maximum > 0:
		var step := 5
		for n in range(step, maximum, step):
			var x := bar.position.x + bar.size.x * n / maximum
			draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.45), 0.5)
	draw_rect(bar, HUD_BRONZE, false, 0.5)
	draw_string(font, bar.position + Vector2(_k(5), bar.size.y - _k(2.5)), "%d/%d" % [value, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(9), Color(0.96, 0.93, 0.85))


# Faixa no topo: retratos emoldurados na ordem da rodada, inimigos em vermelho, o da vez sublinhado.
func _draw_turn_order(font: Font, to_world: Transform2D) -> void:
	var units: Array[Combatant] = []
	for u in turns.order:
		if u.is_alive():
			units.append(u)
	var step := 56.0
	var width := units.size() * step + 14
	var screen_pos := Vector2(480 - width * 0.5, 8)
	var pos := to_world * screen_pos
	var mouse := get_viewport().get_mouse_position()
	var hovered: Combatant = null
	var hover_rect := Rect2()
	_draw_frame(Rect2(pos, Vector2(width, 66)))
	for k in units.size():
		var u := units[k]
		var cell := Rect2(pos + Vector2(10 + k * step, 7), Vector2(50, 50))
		_draw_frame(cell, u.side == Combatant.Side.ENEMY)
		var face := cell.grow(-4)
		draw_rect(face, Color(0.16, 0.12, 0.09))
		_draw_face(u, face)
		if u == turns.current:
			draw_rect(Rect2(cell.position + Vector2(5, 52), Vector2(40, 2)), FRAME_ACCENT)
		if Rect2(screen_pos + Vector2(10 + k * step, 7), cell.size).has_point(mouse):
			hovered = u
			hover_rect = cell
			draw_rect(face, Color(1, 1, 1, 0.18))
	draw_string(font, pos + Vector2(0, 80), "RODADA %d" % turns.round_number, HORIZONTAL_ALIGNMENT_CENTER, width, 9, Color(0.72, 0.65, 0.52))
	if hovered:  # nome embaixo do retrato sob o mouse
		_draw_tooltip(font, Vector2(hover_rect.get_center().x, hover_rect.end.y + 26), hovered.name.to_upper(), "", hovered.side == Combatant.Side.ENEMY)


# Etiqueta flutuante centrada em `top_center`, com uma segunda linha opcional.
func _draw_tooltip(font: Font, top_center: Vector2, title: String, detail: String, enemy := false) -> void:
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	if detail != "":
		w = maxf(w, font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x)
	var tip := Rect2(top_center - Vector2(w * 0.5 + 7, 0), Vector2(w + 14, 31 if detail != "" else 19))
	draw_rect(tip, Color(0.05, 0.04, 0.03, 0.96))
	draw_rect(tip, FRAME_ENEMY if enemy else FRAME_ACCENT, false, 1.0)
	draw_string(font, tip.position + Vector2(0, 13), title, HORIZONTAL_ALIGNMENT_CENTER, tip.size.x, 12, Color(0.93, 0.89, 0.8))
	if detail != "":
		draw_string(font, tip.position + Vector2(0, 26), detail, HORIZONTAL_ALIGNMENT_CENTER, tip.size.x, 9, Color(0.72, 0.65, 0.52))


func _draw_face(u: Combatant, rect: Rect2) -> void:
	var i := enemies.find(u)
	if i < 0:
		agent_sheets[looks.get(u, 0)].draw_portrait(self, rect)
		return
	var variant := _enemy_variant(i)
	if enemy_sheets.has(variant):
		enemy_sheets[variant].draw_portrait(self, rect)
	else:
		var tex := PlaceholderArt.character_texture(variant, PlaceholderArt.Dir.SOUTH, 0)
		draw_texture_rect_region(tex, rect, Rect2(4, 0, 24, 24))


# Ações do rodapé no turno do jogador: [ícone, título, detalhe, ativa]. A arma secundária
# aparece apagada quando faltam PA para a troca.
func _action_slots() -> Array:
	var data := cfg.game_data
	var kit := data.get_entry("itens", "kit_primeiros_socorros")
	var id := str(player.weapon["id"])
	var slots := [[id, str(data.get_entry("armas", id).get("nome", id)), "Atacar · %d PA · clique no inimigo" % int(player.weapon["pa_cost"]), true]]
	var second := _reserve_id()
	if second != "":
		slots.append([second, str(data.get_entry("armas", second).get("nome", second)), "Trocar arma · %d PA · tecla Q" % SWAP_PA, player.pa >= SWAP_PA])
	slots.append(["kit", "Kit de primeiros socorros", "Reanimar · %d PA · restam %d" % [int(kit["custo_pa_combate"]), inventory.count(KIT_ID)], inventory.count(KIT_ID) > 0])
	slots.append(["atrasar", "Atrasar", "Age depois na rodada · tecla D", true])
	return slots


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
	var mouse := get_viewport().get_mouse_position()
	var bar := _bar_rect(n)
	var br := Rect2(to_world * bar.position, bar.size)
	_draw_bar_frame(br, (to_world * _end_turn_rect(n).position).x)
	_draw_pa_strip(br.position + Vector2(14, 0), turns.turn_pa(player), player.pa)
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
	_draw_end_turn(font, er, over_end, over_end and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), _player_ready())
	if tip >= 0:
		var r := Rect2(to_world * _action_rect(tip, n).position, Vector2(BAR_SLOT, BAR_SLOT))
		_draw_tooltip(font, Vector2(r.get_center().x, r.position.y - 64), slots[tip][1], slots[tip][2])
	elif over_end:
		_draw_tooltip(font, Vector2(er.get_center().x, er.position.y - 42), "Fim do turno", "Barra de espaço", true)


# Moldura única: placa escura semitransparente, filete duplo de ouro velho, cantoneiras finas,
# remates góticos nas pontas e um divisor com losango carmesim antes do fim do turno.
func _draw_bar_frame(r: Rect2, end_x: float) -> void:
	draw_rect(r, BAR_FILL)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 0.85, 0.6, 0.06))
	draw_rect(r.grow(-0.5), FRAME_OUTER, false, 1.0)
	draw_rect(r.grow(-3), Color(FRAME_INNER, 0.8), false, 0.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o: Vector2 = r.position + corner * r.size
		var d := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0)
		draw_polyline(PackedVector2Array([o + Vector2(1.5, 9) * d, o + Vector2(1.5, 1.5) * d, o + Vector2(9, 1.5) * d]), FRAME_ACCENT, 1.0)
		_draw_diamond(o + Vector2(5, 5) * d, 1.5, FRAME_ACCENT)
	for side in [-1.0, 1.0]:  # remates: ponta de lança com o losango carmesim
		var c := Vector2(r.position.x if side < 0 else r.end.x, r.get_center().y)
		var tip := c + Vector2(side * 7, 0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), tip, c + Vector2(0, 9)]), FRAME_FILL)
		draw_polyline(PackedVector2Array([c + Vector2(0, -9), tip, c + Vector2(0, 9)]), FRAME_OUTER, 1.0)
		_draw_diamond(c + Vector2(side * 2.5, 0), 2.5, BAR_CRIMSON)
	var x := end_x - BAR_DIVIDER * 0.5
	for dx in [-1.5, 1.5]:
		draw_line(Vector2(x + dx, r.position.y + 6), Vector2(x + dx, r.end.y - 6), Color(FRAME_INNER, 0.9), 0.5)
	_draw_diamond(Vector2(x, r.get_center().y), 4.5, FRAME_OUTER)
	_draw_diamond(Vector2(x, r.get_center().y), 3.0, BAR_CRIMSON)
	_draw_diamond(Vector2(x, r.position.y + 6), 1.5, FRAME_ACCENT)
	_draw_diamond(Vector2(x, r.end.y - 6), 1.5, FRAME_ACCENT)


# Faixa de PA sobre a borda de cima da barra: medalhão, trilho fino e uma gema lapidada por PA.
# Gema acesa = PA disponível; soquete escuro = PA gasto; a próxima a ser gasta pulsa de leve.
func _draw_pa_strip(at: Vector2, total: int, left: int) -> void:
	var step := 15.0
	var end_x := at.x + 22.0 + total * step
	draw_rect(Rect2(Vector2(at.x, at.y - 1.5), Vector2(end_x - at.x, 3)), Color(0.035, 0.026, 0.022))
	draw_line(Vector2(at.x, at.y - 1.5), Vector2(end_x, at.y - 1.5), FRAME_INNER, 0.5)
	draw_line(Vector2(at.x, at.y + 1.5), Vector2(end_x, at.y + 1.5), FRAME_INNER, 0.5)
	_draw_diamond(Vector2(end_x + 2, at.y), 2.0, FRAME_OUTER)
	draw_circle(at, 7.5, Color(0.035, 0.026, 0.022))
	draw_arc(at, 7.0, 0, TAU, 24, FRAME_OUTER, 1.0)
	draw_arc(at, 4.5, 0, TAU, 16, Color(FRAME_INNER, 0.8), 0.5)
	_draw_diamond(at, 2.5, BAR_CRIMSON)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	for n in total:
		var c := Vector2(at.x + 20.0 + n * step, at.y)
		_draw_diamond(c, 6.5, Color(0.035, 0.026, 0.022))
		_draw_diamond(c, 5.5, FRAME_OUTER if n < left else FRAME_INNER)
		if n < left:
			if n == left - 1:
				_draw_diamond(c, 8.0 + pulse, Color(FRAME_ACCENT, 0.12 + 0.1 * pulse))
			_draw_gem(c, 4.5)
		else:
			_draw_diamond(c, 4.5, Color(0.09, 0.05, 0.045))
			_draw_diamond(c, 1.5, Color(BAR_CRIMSON, 0.45))


# Gema dourada lapidada: faces claras em cima à esquerda, escuras embaixo, brilho no topo.
func _draw_gem(c: Vector2, r: float) -> void:
	var top := c + Vector2(0, -r)
	var right := c + Vector2(r, 0)
	var bottom := c + Vector2(0, r)
	var left := c + Vector2(-r, 0)
	var mid := c + Vector2(-0.6, -0.6)
	draw_colored_polygon(PackedVector2Array([top, mid, left]), Color(1.0, 0.9, 0.6))
	draw_colored_polygon(PackedVector2Array([top, right, mid]), FRAME_ACCENT)
	draw_colored_polygon(PackedVector2Array([left, mid, bottom]), Color(0.72, 0.52, 0.22))
	draw_colored_polygon(PackedVector2Array([mid, right, bottom]), Color(0.5, 0.33, 0.13))
	draw_rect(Rect2(c + Vector2(-1.5, -2.5), Vector2(1, 1)), Color(1, 1, 0.9, 0.9))


# Casa de ação: fundo escuro, filete de ouro velho e o ícone em pixel art no centro.
# Selecionada: ouro forte com halo; sob o mouse: filete mais claro; indisponível: ícone apagado.
func _draw_slot(r: Rect2, slot: Array, selected: bool, hover: bool) -> void:
	var enabled: bool = slot[3]
	draw_rect(r, Color(0.055, 0.042, 0.035, 0.96))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, r.size.y * 0.45)), Color(1, 0.9, 0.7, 0.04))
	draw_rect(Rect2(r.position + Vector2(1, r.size.y - 4), Vector2(r.size.x - 2, 3)), Color(0, 0, 0, 0.35))
	# Contornos: filete externo de 2 px da janela (1.0) e interno de 1 px (0.5), sempre nas mesmas
	# posições para as casas não parecerem de espessuras diferentes; a selecionada só muda de cor.
	if selected:
		draw_rect(r.grow(1.25), Color(FRAME_ACCENT, 0.35), false, 0.5)
		draw_rect(r.grow(-0.5), Color(1.0, 0.85, 0.5), false, 1.0)
		draw_rect(r.grow(-2.75), Color(FRAME_ACCENT, 0.6), false, 0.5)
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			_draw_diamond(r.position + corner * r.size, 1.75, Color(1.0, 0.85, 0.5))
	else:
		draw_rect(r.grow(-0.5), FRAME_OUTER.lightened(0.25) if hover else Color(FRAME_OUTER, 0.9), false, 1.0)
		draw_rect(r.grow(-2.75), Color(FRAME_INNER, 0.6), false, 0.5)
	if hover:
		draw_rect(r.grow(-3), Color(1, 0.9, 0.7, 0.07))
	_draw_action_icon(r, slot[0], enabled)
	if not enabled:
		draw_rect(r.grow(-1), Color(0.02, 0.015, 0.012, 0.35))


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
	draw_rect(r, fill)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, r.size.y * 0.45)), Color(1, 0.5, 0.4, 0.06 if not pressed else 0.0))
	draw_rect(r.grow(-0.5), edge, false, 1.0)
	draw_rect(r.grow(-2.5), Color(FRAME_ACCENT, 0.45) if enabled else Color(edge, 0.5), false, 0.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		_draw_diamond(r.position + corner * r.size, 2.0, edge.lightened(0.2))
	var glass := ItemIcons.ART_SIZE  # a ampulheta da arte é estreita; o quadro é o mesmo dos outros ícones
	ItemIcons.draw(self, Rect2(r.position + Vector2(5, (r.size.y - glass) * 0.5), Vector2(glass, glass)), "ampulheta", enabled)
	draw_string(font, r.position + Vector2(glass + 8, 17), "FIM DO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - glass - 14, 11, ink)
	draw_string(font, r.position + Vector2(glass + 8, 30), "TURNO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - glass - 14, 11, ink)


func _draw_action_icon(r: Rect2, id: String, enabled: bool) -> void:
	ItemIcons.draw(self, r, id, enabled)


# Minimapa: radar redondo visto de cima, centrado no controlado (Léo escolheu, 29/10/2026).
# Só desenha o que o grupo já descobriu: o outro lado de uma porta nunca aberta não aparece,
# e inimigos só aparecem enquanto estão à vista.
const RADAR_CENTER := Vector2(866, 88)  # pixels da tela
const RADAR_RADIUS := 56.0  # área do mapa; o aro da moldura A fica 6 px para fora
const RADAR_SCALE := 0.11  # pixels do radar por unidade da sala
const RADAR_GRID := 64.0  # um losango do chão, em unidades da sala
const RADAR_INK := Color(0.07, 0.05, 0.04)
const RADAR_FLOOR := Color(0.25, 0.2, 0.15)
const RADAR_WALL := Color(0.84, 0.76, 0.6)
const RADAR_DOOR := Color(0.66, 0.4, 0.2)
const RADAR_ENEMY := Color(0.86, 0.2, 0.2)


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


# Nome do local na placa do radar; as áreas derivadas trocam.
func _place_label() -> String:
	return "SALA DE TESTE"


# Visual do inimigo `i` da lista `enemies` (a sala de teste alterna cultista e atirador).
func _enemy_variant(i: int) -> String:
	return ENEMY_VARIANTS[i % ENEMY_VARIANTS.size()]


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

	# Fundo escuro no círculo inteiro do aro.
	draw_circle(center, RADAR_RADIUS + 6, Color(0.04, 0.03, 0.02, 0.92))
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

	# Moldura A: aro de bronze, filete interno e N, L, S e O em medalhões nos pontos cardeais.
	var rim := RADAR_RADIUS + 6
	draw_arc(center, rim, 0.0, TAU, 72, FRAME_OUTER, 2.5)
	draw_arc(center, RADAR_RADIUS + 1, 0.0, TAU, 72, FRAME_INNER, 1.0)
	for c in [["N", Vector2.UP], ["L", Vector2.RIGHT], ["S", Vector2.DOWN], ["O", Vector2.LEFT]]:
		var at: Vector2 = center + c[1] * rim
		draw_circle(at, 8.5, Color(0.07, 0.047, 0.031))
		draw_arc(at, 8.5, 0.0, TAU, 24, FRAME_OUTER, 1.0)
		draw_string(font, at + Vector2(-8.5, 3.5), c[0], HORIZONTAL_ALIGNMENT_CENTER, 17, 10, FRAME_ACCENT)
	# Placa com o local e o modo logo abaixo.
	var plate := Rect2(center + Vector2(-65, rim + 12), Vector2(130, 37))
	_draw_frame(plate)
	draw_string(font, plate.position + Vector2(0, 15), _place_label(), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 8, Color(0.73, 0.65, 0.52))
	draw_string(font, plate.position + Vector2(0, 28), HudText.mode_label(mode == Mode.COMBAT), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 11, Color(0.93, 0.89, 0.8))
