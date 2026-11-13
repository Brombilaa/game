class_name TestRoom
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
# A sala é cinza e leve (Léo, 05/11/2026): chão liso, paredes, porta e coberturas são caixas
# cinzas desenhadas por ordem de profundidade (x + y); o cenário de arte saiu daqui.
# O agente usa a folha real do Nikolai, do Miguel ou do Fernando (CharacterSheet, 128 px; só o visual
# muda); o atirador ainda é arte provisória (PlaceholderArt ampliada).

enum Mode { EXPLORATION, COMBAT, GAME_OVER }


signal move_finished


const SPEED := 180.0

const STAND_OFFSET := 6.0

const FOLLOW_DISTANCE := 60.0  # distância fixa do seguidor ao líder (provisório)

const FOLLOW_SPREAD := 1.0  # variação do ângulo do seguidor em radianos (provisório)

const REVIVE_REACH := 16.0  # borda a borda: "adjacente" para reanimar

const KIT_ID := "kit_primeiros_socorros"

const RELOAD_SECONDS := 2.0  # recarga: 12 quadros a 6/s (AnimSheet.FPS["reload"])
const SWAP_PA := 1  # trocar de arma em combate (GDD #18)

const POPUP_SECONDS := 1.2

const HIT_SHAKE_SECONDS := 0.2

const CRIT_SHAKE_SECONDS := 0.35

const POPUP_STYLES := {
	"damage": {"size": 28, "color": Color(1.0, 0.92, 0.85)},
	"crit": {"size": 40, "color": Color(1.0, 0.8, 0.25)},
	"miss": {"size": 15, "color": Color(0.68, 0.66, 0.62)},
	"blocked": {"size": 14, "color": Color(0.6, 0.7, 0.85)},
	"down": {"size": 14, "color": Color(0.95, 0.3, 0.25)},
	"heal": {"size": 15, "color": Color(0.5, 0.9, 0.55)},
	"info": {"size": 13, "color": Color(1.0, 1.0, 0.75)},
}

# Quadro da caminhada avança por distância percorrida na tela (não por tempo): os pés não deslizam,
# cada unidade tem a sua própria fase e o ritmo é o mesmo em todas as direções.
# VALORES PROVISÓRIOS (Léo pediu animações mais lentas, 06/11/2026; ajustar testando no jogo).
# Velocidade de andar = 180 px/s, então ciclo/180 = segundos por passo completo.
const WALK_FRAME_PIXELS := 20.0  # Fernando e demais folhas 2D de 6 quadros: ciclo de 120 px = 0,67 s (antes 90 px = 0,5 s)
const NIKOLAI_WALK_CYCLE_PIXELS := 144.0  # Nikolai 3D: 0,8 s por passo completo (antes 0,5 s)
const CREATURE_WALK_CYCLE_PIXELS := 180.0  # Criatura de Sangue: 1,0 s por ciclo (antes 0,5 s)
const NIKOLAI_ATTACK_SECONDS := 0.8  # mira/golpe do Nikolai (antes 0,6 s)
const CREATURE_ATTACK_SECONDS := 1.2  # golpe da Criatura, 16 quadros (antes 0,6 s = 27 quadros/s)

const IDLE_FRAME_SECONDS := 0.9  # antes 0,7

const PLACEHOLDER_SCALE := 2.7  # arte provisória de 32×48 ampliada para ~130 px (a altura do herói)

const TILE_WORLD := 64.0  # lado de um losango do chão, em unidades da sala

const TILE_SCREEN := Vector2(96, 48)  # losango 2:1 na tela (V-21)

const WALL_HEIGHT := 72.0  # altura na tela das paredes e do bloco do meio

const FRONT_WALL_HEIGHT := 24.0  # paredes voltadas para a câmera (sul e leste), baixas para não esconder a sala

const FLOOR_COLOR := Color(0.33, 0.34, 0.36)

const WALL_COLOR := Color(0.5, 0.51, 0.54)

const DOOR_COLOR := Color(0.42, 0.37, 0.33)

const COVER_COLORS := {"partial": Color(0.6, 0.6, 0.58), "full": Color(0.4, 0.41, 0.46)}

const COVER_HEIGHTS := {"partial": 22.0, "full": 64.0}

const AGENT_SHEETS := [  # visuais dos membros do grupo (Fernando, Nikolai, Miguel)
	"res://assets/sprites/personagens/legado_2d/fernando",
	"res://assets/sprites/personagens/legado_2d/nikolai",
	"res://assets/sprites/personagens/legado_2d/miguel",
]

const ROOM_SIZE := Vector2i(1280, 720)

const ENEMY_VARIANTS := ["cultista", "atirador"]  # mesma ordem de `enemies`

# Variantes que já têm folha real; as outras seguem com PlaceholderArt.
# O atirador ainda não tem figura própria: usa a do cultista (o retrato do HUD já é o dele).
const ENEMY_SHEETS := {"cultista": "res://assets/sprites/personagens/legado_2d/cultista", "atirador": "res://assets/sprites/personagens/legado_2d/cultista"}
# Variantes em 3D renderizado como pixel art (CreatureSheet): idle, andar, transição, ataque e morte.
const CREATURE_VARIANT := "criatura_sangue"
const TRANSITION_SECONDS := 2.0  # a transição (entrada em combate) toca uma vez ao começar o combate; 12 quadros a 6/s (provisório, antes 0,9 s e cortava o fim)


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

var unlinked := {}  # seguidores soltos da corrente do grupo: não acompanham o líder

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

var fx := CombatFx.new()  # animação de combate, modelo B (Léo, 01/11/2026)

const CAMERA_EASE_SECONDS := 0.6  # suaviza a câmera durante o ataque e na volta ao foco

var _cam_ease := 0.0

var zoom_base := Vector2.ONE  # zoom do jogador; o pulso do tiro é aplicado por cima

var zoom_pulsing := false

var combat_log: Array = []  # P3: últimas linhas do combate {text, time}

var cam_pan := Vector2.ZERO  # P6: deslocamento da câmera livre em combate (botão do meio)

var _pan_unit: Combatant = null

var options := GameOptions.shared()

var perf_on := false  # P11: medidor F3

var perf_text := ""

var _perf_time := 0.0

var _perf_path_usec := 0

var _perf_path_calls := 0

var _draw_usec := 0

var screen_shake := 0.0  # segundos restantes de tremor da tela (crítico)

var hud := CombatHud.new()
var party_hud := RoomPartyHud.new(self)
var action_bar := RoomActionBar.new(self)
var minimap := RoomMinimap.new(self)
var hud_blur := HudBlur.new(self)
var objectives_hud := RoomObjectivesHud.new(self)

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

var creature := CreatureSheet.new()  # Criatura de Sangue (parque)
var nikolai_clock := {}  # Combatant -> {"anim": String, "start": ms}: dano, morte ou levantar do Nikolai 3D
var creature_clock := {}  # inimigo -> segundo (ms) em que a morte começou
var combat_started_ms := -100000
var fernando3d := AnimSheet.new("fernando3d", "fernando3d")  # Fernando em 3D: as mesmas animações do Nikolai, no esqueleto dele
var nikolai3d := AnimSheet.new()  # Nikolai em 3D renderizado como pixel art (teste das animações)
var miguel3d := AnimSheet.new("miguel3d", "miguel3d", nikolai3d)  # Miguel: só modelo 3D (parque), quadros contados pelo Nikolai

var use_3d := true  # tecla V troca entre o Nikolai 3D e o sprite 2D

var anim3d_pick := -1  # tecla N: -1 = automático (parado/andando); senão o índice em AnimSheet.NAMES

var anim3d_tick := 0


func _ready() -> void:
	fx.iso = _iso
	fx.chest_px = _chest_px
	fx.impact.connect(_on_fx_impact)
	RenderingServer.set_default_clear_color(Color(0.03, 0.025, 0.02))  # fora da sala e salas fechadas: escuridão
	hud.room_draws_hud = true  # a sala desenha modo, PA e fim do turno na moldura A
	add_child(hud)
	add_child(audio)
	add_child(hud_blur)
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
	camera.limit_top = int(corners[0].y) - int(WALL_HEIGHT) - 16
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


# Pulso de zoom de 8% por 0,45 s no impacto: aplicado por cima do zoom que o jogador escolheu.
func _apply_zoom_pulse() -> void:
	if fx.zoom_time > 0.0:
		if not zoom_pulsing:
			zoom_base = camera.zoom
			zoom_pulsing = true
		var z := zoom_base.x * fx.zoom_factor()
		camera.zoom = Vector2(z, z)
	elif zoom_pulsing:
		camera.zoom = zoom_base
		zoom_pulsing = false


func _zoom_min() -> float:
	return 1.0


func _zoom_by(factor: float) -> void:
	var z := clampf(camera.zoom.x * factor, _zoom_min(), ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	zoom_base = camera.zoom
	queue_redraw()  # o HUD e a prévia do mouse dependem do zoom


func _unhandled_input(event: InputEvent) -> void:
	# P6: câmera livre em combate. Arrastar com o botão do meio move; clicar nele (ou Home) volta.
	if mode == Mode.COMBAT:
		if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			cam_pan -= event.relative / camera.zoom.x
			queue_redraw()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			cam_pan = Vector2.ZERO
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
			cam_pan = Vector2.ZERO
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		perf_on = not perf_on
		queue_redraw()
		return
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
		elif event.pressed and event.keycode == KEY_G and use_3d and _sheet3d(player) != null and not fx.animating() and not _reloading(player):
			nikolai_clock[player] = {"anim": "reload", "start": Time.get_ticks_msec()}  # teste da recarga (ainda não há munição no jogo)
			queue_redraw()
		elif event.pressed and event.keycode == KEY_V:
			use_3d = not use_3d
			_popup(player.pos, "Nikolai 3D" if use_3d else "Nikolai 2D")
			queue_redraw()
		elif event.pressed and event.keycode == KEY_N:
			anim3d_pick = (anim3d_pick + 2) % (AnimSheet.NAMES.size() + 1) - 1
			_popup(player.pos, "anim: automático" if anim3d_pick < 0 else "anim: " + AnimSheet.NAMES[anim3d_pick])
			queue_redraw()
		elif event.pressed and event.keycode == KEY_C and (mode == Mode.EXPLORATION or _player_ready()):
			_toggle_crouch()
		return
	if event is InputEventMouseMotion:
		_update_cursor()
	if event is InputEventMouseMotion and mode == Mode.COMBAT:
		queue_redraw()  # atualiza a prévia de chance/custo sob o cursor
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var screen := get_viewport().get_mouse_position()
		var link := _link_at(screen)
		if link >= 0:
			_toggle_link(party[link + 1])
			return
		var portrait := _portrait_at(screen)
		if portrait:
			_switch_to(portrait)
			return
		if _mouse_on_hud(screen):  # rodapé: o fim do turno passa a vez; os ícones não movem o personagem
			var n := action_bar._action_slots().size()
			if action_bar._end_turn_rect(n).has_point(screen):
				_player_pass()
			elif _reserve_id() != "" and action_bar._action_rect(1, n).has_point(screen):
				_swap_weapon()
			elif action_bar._action_rect(action_bar.kit_index(), n).has_point(screen):
				_use_kit_button()
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


# Agachar (tecla C). Léo, 13/11: se o time está junto, todos agacham e levantam juntos. "Junto" = o líder e os
# seguidores presos na corrente; quem foi solto da corrente (`unlinked`) mantém a postura própria. Em combate
# a postura continua valendo e a tecla C troca a de quem está na vez (grátis, sem PA; provisório).
func _toggle_crouch() -> void:
	var stance := not player.crouched
	player.crouched = stance
	if mode == Mode.EXPLORATION:
		for m in party:
			if m != player and m.is_alive() and not unlinked.has(m):
				m.crouched = stance
	queue_redraw()


# Recarga (tecla G, por enquanto só a animação): enquanto dura, o personagem não ataca (Léo, 13/11: "atira enquanto recarrega").
func _reloading(u: Combatant) -> bool:
	var c: Dictionary = nikolai_clock.get(u, {})
	if c.get("anim", "") != "reload":
		return false
	return (Time.get_ticks_msec() - int(c["start"])) / 1000.0 < RELOAD_SECONDS


# Bloqueio do ataque: a recarga em curso vem antes das regras (alcance, linha de visão).
func _attack_blocker(attacker: Combatant, target: Combatant) -> String:
	if _reloading(attacker):
		return "reloading"
	return rules.attack_blocker(attacker, target, _sight_blockers(), covers)


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
	minimap._update_discovered()
	fx.update(delta)
	_apply_zoom_pulse()
	camera.offset = fx.shake_offset()
	if fx.active() or not fx.particles.is_empty() or not fx.muzzles.is_empty() or fx.flash_red > 0.0 or not fx.trail.is_empty() or not fx.kicks.is_empty() or not fx.white.is_empty():
		queue_redraw()
	if fx.hitstop > 0.0:  # parada de 90 ms no impacto: o mundo congela um instante
		fx.hitstop -= delta
		return
	if mode == Mode.COMBAT and _player_ready():
		queue_redraw()  # gema de PA pulsando e estados do botão de fim do turno
	if not combat_log.is_empty():
		for l in combat_log:
			l.time -= delta
		combat_log = combat_log.filter(func(l: Dictionary) -> bool: return l.time > 0.0)
		queue_redraw()
	_update_perf(delta)
	if _san_ratio() < 1.0 and player.max_san > 0 and player.san <= 0:
		queue_redraw()  # a tela pulsa na ruptura
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
	_update_cursor()
	var focus := turns.current if mode == Mode.COMBAT and turns and turns.current else player
	# Durante o ataque a câmera acompanha atacante e alvo até o fim da animação (mira, arremesso e
	# rastro da barra), mesmo que o turno já tenha passado; entra e sai suavemente.
	if focus != _pan_unit:
		_pan_unit = focus
		cam_pan = Vector2.ZERO  # a câmera livre volta ao personagem da vez
	var cam_goal := _iso(focus.pos) + (cam_pan if mode == Mode.COMBAT else Vector2.ZERO)
	var fx_focus := fx.camera_focus()
	if fx_focus != Vector2.INF:
		cam_goal = _iso(fx_focus)  # o ataque tem prioridade sobre a câmera livre
		_cam_ease = CAMERA_EASE_SECONDS
	if _cam_ease > 0.0:
		if fx_focus == Vector2.INF:
			_cam_ease -= delta
		camera.position = camera.position.lerp(cam_goal, 1.0 - exp(-12.0 * delta)).round()
	else:
		camera.position = cam_goal.round()  # pixel inteiro: o cenário não treme ao andar
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
	if (use_3d or _has_creatures()) and tick3d != anim3d_tick:
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
				_start_combat(Combatant.Side.ENEMY)  # quem percebe pega o grupo desprevenido
				return


# Ataque furtivo (Léo): contra inimigo sem alerta, com bônus de acerto e de dano. Se errar,
# o combate começa. Se acertar sem abater, o alvo também entra em alerta (assumido).
# Fora do alcance da arma, o personagem só anda até o alvo.
func _stealth_attack(target: Combatant) -> void:
	player.pa = int(player.weapon["pa_cost"])  # fora do combate não há PA; o custo é só formal
	var blocker := _attack_blocker(player, target)
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
# surprise_side: lado que pegou o outro desprevenido e age todo na rodada 1 (-1 = ninguém).
func _start_combat(surprise_side: int = -1) -> void:
	mode = Mode.COMBAT
	combat_started_ms = Time.get_ticks_msec()
	combat_log.clear()
	cam_pan = Vector2.ZERO
	Engine.time_scale = 2.0 if options.values["fast_combat"] else 1.0  # P7: combate rápido (Opções)
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
	turns.start(units, surprise_side)
	queue_redraw()


func _on_turn_started(unit: Combatant) -> void:
	rules.units = _living_units()  # M4: quem está em campo, para achar o flanqueador
	queue_redraw()
	_log("Vez de %s" % unit.name)
	if unit.side == Combatant.Side.PLAYER:
		player = unit
		hud.on_turn_started(unit.name, unit.pa, turns.turn_pa(player))
		audio.play_sfx("turn_start")
	else:
		_run_enemy_turn.call_deferred(unit)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_combat_ended(result: TurnManager.Result) -> void:
	Engine.time_scale = 1.0
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


# Game Over (Léo): sem tela própria; a tela escurece bem devagar e o jogo volta ao último save.
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
		_voltar_ao_save()


# A sala de teste não tem save: recomeça. O parque e os outros lugares voltam ao autosave.
func _voltar_ao_save() -> void:
	get_tree().reload_current_scene()


# --- Turno do jogador --------------------------------------------------------


func _player_ready() -> bool:
	return mode == Mode.COMBAT and not busy and turns.is_turn_of(player)


func _combat_click(click: Vector2) -> void:
	if not _player_ready():
		return
	var target := _enemy_at(click)
	if target:
		if _reloading(player):
			_reject("reloading")
			return
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
		hud.show_notice("Sem kit de primeiros socorros")
	elif CombatRules.gap(player, fallen) > REVIVE_REACH:
		_reject("out_of_range")
		hud.show_notice("Chegue mais perto de %s para reanimar" % fallen.name)
	elif not turns.spend(player, cost):
		_reject("no_pa")
	else:
		inventory.remove(KIT_ID)
		fallen.pv = maxi(floori(fallen.max_pv * float(kit["valor"])), 1)
		_popup(fallen.pos, "REANIMADO", "heal")
	_after_player_action()


# Ícone do kit na barra de combate: reanima o aliado caído que está encostado no controlado.
func _use_kit_button() -> void:
	if not _player_ready():
		return
	for m in party:
		if m != player and not m.is_alive() and not m.dead and CombatRules.gap(player, m) <= REVIVE_REACH:
			_revive(m)
			return
	_reject("out_of_range")
	hud.show_notice("Nenhum aliado caído encostado em %s" % player.name)


func _fallen_at(p: Vector2) -> Combatant:
	for m in party:
		if not m.is_alive() and not m.dead and m.pos.distance_to(p) <= m.radius + 4.0:
			return m
	return null


func _player_move(click: Vector2) -> void:
	var full := pathfinder.find_path(player.pos, click, _obstacles(player), player.radius)
	if full.is_empty():
		await _player_unstick(click)
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


# P9: se o controlado está preso (dentro de um obstáculo ou separado de todo o grupo) e o destino é um
# ponto livre, salta, sem gastar PA, para o ponto livre mais perto do destino com caminho até ele.
# Fora disso o clique em destino inacessível continua sendo ignorado.
func _player_unstick(click: Vector2) -> void:
	if not Pathfinder.is_free(click, _obstacles(player), player.radius) or not _player_trapped():
		return
	var spot := ai.spot_toward(player, click, 0.0, true)
	if spot == Vector2.INF:
		return
	busy = true
	_start_move(player, PackedVector2Array([player.pos, spot]))
	await move_finished
	busy = false
	queue_redraw()


func _player_trapped() -> bool:
	var obstacles := _obstacles(player)
	if not Pathfinder.is_free(player.pos, obstacles, player.radius):
		return true
	var others := 0
	for m in party:
		if m != player and m.is_alive():
			others += 1
			if not pathfinder.find_path(player.pos, m.pos, _obstacles(player), player.radius).is_empty():
				return false
	return others > 0


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
	if use_3d and _sheet3d(m) != null:
		nikolai_clock[m] = {"anim": "pickup_object", "start": Time.get_ticks_msec()}  # gesto de usar o item
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
# A IA mora em EnemyAi (scripts/exploration/enemy_ai.gd); a sala só entrega o turno e responde pelo
# movimento animado (_start_move/move_finished) e pela encenação do ataque (_show_attack).


var ai := EnemyAi.new(self)


func _run_enemy_turn(unit: Combatant) -> void:
	await ai.run_turn(unit)


func _enemy_target(unit: Combatant) -> Combatant:
	return ai.pick_target(unit)


# --- Feedback ----------------------------------------------------------------


# O ataque já foi resolvido pelas regras; aqui só se encena: mira de 0,6 s e, no impacto, os efeitos
# do modelo B (CombatFx) e os textos (_on_fx_impact). A barra de vida do alvo fica no valor antigo até lá.
func _show_attack(attacker: Combatant, target: Combatant, r: Dictionary) -> void:
	if not r.ok:
		_reject(r.reason)
		return
	var before := mini(target.pv + int(r.get("damage", 0)), target.max_pv) if r.get("hit", false) else target.pv
	# Quem ataca vira para o alvo (antes atirava para onde estivesse olhando: Léo, 08/11, "combate dessincronizado").
	if target.pos != attacker.pos:
		facing8[attacker] = CharacterSheet.dir_from_vector(_iso(target.pos) - _iso(attacker.pos))  # direção vista na tela
	var aim := _attack_aim(attacker)
	fx.start(attacker, target, r, before, aim)
	_attack_started(attacker, target, aim)
	queue_redraw()


# Duração da mira até o impacto (o golpe acerta no fim dela).
func _attack_aim(attacker: Combatant) -> float:
	if _has_creatures() and enemies.has(attacker):
		return CREATURE_ATTACK_SECONDS
	if use_3d and _sheet3d(attacker) != null:
		return NIKOLAI_ATTACK_SECONDS
	return CombatFx.AIM_SECONDS


# Verdadeiro quando o modelo 3D do personagem já pisca sozinho (o parque 3D); senão a mancha branca é desenhada.
func _flash_in_3d(_u: Combatant) -> bool:
	return false


# Gancho para a sala encenar o golpe por conta própria (o parque 3D toca a animação do modelo).
func _attack_started(_attacker: Combatant, _target: Combatant, _aim: float) -> void:
	pass


const LOG_SECONDS := 8.0

const LOG_MAX := 4


# P3: registro curto do combate no canto inferior esquerdo (as últimas linhas somem sozinhas).
func _log(text: String) -> void:
	combat_log.append({"text": text, "time": LOG_SECONDS})
	while combat_log.size() > LOG_MAX:
		combat_log.pop_front()
	queue_redraw()


func _on_fx_impact(job: Dictionary) -> void:
	var target: Combatant = job["target"]
	var r: Dictionary = job["r"]
	var attacker: Combatant = job["attacker"]
	if r.get("blocked", false):
		_log("%s atira em %s: bloqueado" % [attacker.name, target.name])
	elif not r.get("hit", false):
		_log("%s erra %s" % [attacker.name, target.name])
	else:
		_log("%s acerta %s: %d%s" % [attacker.name, target.name, int(r.damage), " (crítico)" if r.get("crit", false) else ""])
	if not target.is_alive():
		_log("%s %s" % [target.name, "foi abatido" if target.side == Combatant.Side.ENEMY else "caiu"])
	if r.get("blocked", false):
		_popup(target.pos, "BLOQUEADO", "blocked")
	elif not r.get("hit", false):
		_popup(target.pos, "ERROU", "miss")
	else:
		if target.pos != attacker.pos and target.is_alive():
			facing8[target] = CharacterSheet.dir_from_vector(_iso(attacker.pos) - _iso(target.pos))  # o atingido vira para quem bateu
		_popup(target.pos, "-%d" % r.damage, "crit" if r.crit else "damage")
		hit_shake[target] = CRIT_SHAKE_SECONDS if r.crit else HIT_SHAKE_SECONDS
		if target.is_alive() and _sheet3d(target) != null and not enemies.has(target):
			nikolai_clock[target] = {"anim": "hit", "start": Time.get_ticks_msec()}  # reação ao golpe (Nikolai 3D)
	if not target.is_alive():
		_popup(target.pos, "ABATIDO" if target.side == Combatant.Side.ENEMY else "CAIU", "down")
	queue_redraw()


# `at` é um ponto da sala; o texto nasce na altura da cabeça e sobe enquanto some.
# kind: damage, crit, miss, blocked, down, heal ou info (estilos em POPUP_STYLES).
func _popup(at: Vector2, text: String, kind := "info") -> void:
	var stacked := popups.filter(func(p: Dictionary) -> bool: return p.anchor.distance_to(at) < 1.0).size()
	popups.append({"anchor": at, "pos": _iso(at) + Vector2(0, -CharacterSheet.HEIGHT - 14 - 18 * stacked), "text": text, "kind": kind, "time": POPUP_SECONDS})


func _draw() -> void:
	var _draw_t0 := Time.get_ticks_usec()
	var font := ThemeDB.fallback_font
	_draw_floor()
	if mode == Mode.EXPLORATION:
		for e in enemies:
			if e.is_alive() and _visible(e.pos):
				_draw_range(e.pos, rules.perception_range(e, player), Color(PlaceholderArt.color("sangue_claro"), 0.35))
	# Peças ordenadas por profundidade: quanto maior x + y, mais perto da câmera.
	var items: Array = []
	for w in walls:
		var front: bool = w.end.y >= ROOM_SIZE.y or w.end.x >= ROOM_SIZE.x
		for piece in _pieces(w):
			if _visible(piece.get_center()):
				items.append({"key": piece.get_center().x + piece.get_center().y, "block": piece, "color": WALL_COLOR, "height": FRONT_WALL_HEIGHT if front else WALL_HEIGHT})
	if not door_open:
		items.append({"key": door.get_center().x + door.get_center().y + 0.5, "block": door, "color": DOOR_COLOR, "height": WALL_HEIGHT})
	for c: Cover in covers:
		if not _visible(c.rect.get_center()):
			continue
		if c.is_destroyed():
			_draw_outline(c.rect, PlaceholderArt.color("chao_claro"))
			continue
		items.append({"key": c.rect.get_center().x + c.rect.get_center().y, "block": c.rect, "color": COVER_COLORS[c.kind], "height": COVER_HEIGHTS[c.kind], "cover": c})
	for u in _drawn_units():
		if _visible(u.pos):
			items.append({"key": u.pos.x + u.pos.y, "unit": u})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	for it in items:
		if it.has("unit"):
			_draw_unit(it.unit)
			continue
		_draw_box(it.block, it.color, it.height)
		if it.has("cover"):
			var c: Cover = it.cover
			var label := "P" if c.kind == "partial" else "C"
			draw_string(font, _iso(c.rect.get_center()) + Vector2(-4, -it.height - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	if mode == Mode.COMBAT:
		_draw_preview(font)
	_draw_fx()
	_draw_san_tint()
	var tr_view := get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)
	draw_rect(tr_view, Color(0.95, 0.5, 0.18, 0.04))  # luz quente leve das 17h na sala de teste
	_draw_hud(font)
	for p in popups:
		_draw_popup(font, p)
	_draw_usec = Time.get_ticks_usec() - _draw_t0


# 1.0 com a SAN cheia, 0.0 na ruptura (só para quem tem SAN).
func _san_ratio() -> float:
	if player == null or player.max_san <= 0:
		return 1.0
	return clampf(float(player.san) / float(player.max_san), 0.0, 1.0)


# P4 (modelo B, Léo 02/11/2026): quanto menos SAN, mais a cor some (cinza por cima do mundo, antes do
# HUD) e, na ruptura, a tela pulsa devagar em escuro. Só aviso visual: a regra da ruptura é outra tarefa.
func _draw_san_tint() -> void:
	var ratio := _san_ratio()
	if ratio >= 1.0:
		return
	var inv := get_canvas_transform().affine_inverse()
	var screen := Rect2(inv * Vector2.ZERO, inv.basis_xform(get_viewport_rect().size))
	draw_rect(screen, Color(0.42, 0.42, 0.42, (1.0 - ratio) * 0.5))
	if player.san <= 0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		draw_rect(screen, Color(0, 0, 0, 0.12 + 0.18 * pulse))


# P3 (modelo A): até 4 linhas no canto inferior esquerdo, esmaecendo com o tempo.
func _draw_combat_log(font: Font) -> void:
	if mode != Mode.COMBAT or combat_log.is_empty():
		return
	var to_world := _hud_to_world()
	var top := 540.0 - 14.0 - 15.0 * LOG_MAX
	draw_rect(Rect2(to_world * Vector2(8, top - 6), Vector2(250, 15.0 * LOG_MAX + 10)), Color(0.04, 0.03, 0.02, 0.5))
	for i in combat_log.size():
		var l: Dictionary = combat_log[i]
		var a := clampf(l.time / 2.0, 0.0, 1.0)
		draw_string(font, to_world * Vector2(14, top + 12 + 15.0 * (LOG_MAX - combat_log.size() + i)), l.text, HORIZONTAL_ALIGNMENT_LEFT, 236, 11, Color(0.95, 0.9, 0.82, a))


# P11: medidor F3 (só teste): quadros por segundo, rotas calculadas e tempo do desenho.
func _update_perf(delta: float) -> void:
	if not perf_on:
		return
	_perf_time += delta
	if _perf_time >= 1.0:
		var usec := pathfinder.usec_total - _perf_path_usec
		var calls := pathfinder.calls_total - _perf_path_calls
		_perf_path_usec = pathfinder.usec_total
		_perf_path_calls = pathfinder.calls_total
		perf_text = "%d FPS · rotas %d (%.1f ms) · desenho %.1f ms" % [Engine.get_frames_per_second(), calls, usec / 1000.0, _draw_usec / 1000.0]
		_perf_time = 0.0
	queue_redraw()


func _draw_perf(font: Font) -> void:
	if not perf_on:
		return
	var at := _hud_to_world() * Vector2(500, 14)
	draw_rect(Rect2(at + Vector2(-4, -11), Vector2(330, 16)), Color(0, 0, 0, 0.6))
	draw_string(font, at, perf_text if perf_text != "" else "medindo…", HORIZONTAL_ALIGNMENT_LEFT, 322, 11, Color(0.6, 1.0, 0.6))


# Feedback de combate (provisório do Claude, 29/10/2026): dano em número que sobe e some,
# "ERROU" em cinza, crítico maior em dourado com "CRÍTICO!" e um tremor na tela.
# Pop-ups só com o número (Léo, 13/11): sem placa nem etiqueta, fonte do título, contorno escuro e uma sombra suave.
# Palavras (ERROU, CAÍDO...) ficam menores, na mesma fonte.
const POPUP_FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")


# Pop-ups só com o número, na máquina de escrever (Léo, 13/11: "essa é a fonte que usaremos para a maioria das coisas
# in game"): levemente tortos, contorno escuro fino, sem placa nem etiqueta; o crítico é maior, dourado e torto para o outro lado.
func _draw_popup(_font: Font, p: Dictionary) -> void:
	var style: Dictionary = POPUP_STYLES.get(p.kind, POPUP_STYLES.info)
	var age: float = 1.0 - p.time / POPUP_SECONDS
	var alpha: float = clampf(p.time / POPUP_SECONDS * 2.5, 0.0, 1.0)
	var size: int = style.size
	if p.kind == "crit" and age < 0.15:
		size = int(size * (1.5 - age * 3.3))  # o crítico cresce e assenta no primeiro instante
	var width := POPUP_FONT.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at: Vector2 = p.pos + Vector2(0, -28.0 * age)
	var color: Color = style.color
	draw_set_transform(at, -0.06 if p.kind != "crit" else 0.05, Vector2.ONE)
	draw_string_outline(POPUP_FONT, Vector2(-width * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.05, 0.03, 0.02, alpha))
	draw_string(POPUP_FONT, Vector2(-width * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.lerp(Color(0.93, 0.89, 0.78), 0.45), alpha))
	draw_set_transform(Vector2.ZERO)


# Chão liso e cinza. A sala é dividida pela parede do meio; cada metade só aparece quando está visível
# (porta fechada esconde o outro lado) e a abertura da porta aparece com ela aberta.
func _draw_floor() -> void:
	for r in [Rect2(0, 0, 600, ROOM_SIZE.y), Rect2(624, 0, ROOM_SIZE.x - 624, ROOM_SIZE.y)]:
		if _visible(r.get_center()):
			_draw_floor_rect(r)
	if door_open:
		_draw_floor_rect(Rect2(600, 0, 24, ROOM_SIZE.y))


func _draw_floor_rect(r: Rect2) -> void:
	draw_colored_polygon(PackedVector2Array([_iso(r.position), _iso(Vector2(r.end.x, r.position.y)), _iso(r.end), _iso(Vector2(r.position.x, r.end.y))]), FLOOR_COLOR)


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
func _draw_box(r: Rect2, color: Color, height: float) -> void:
	var lift := Vector2(0, -height)
	var a := _iso(r.position)  # canto de trás
	var b := _iso(Vector2(r.end.x, r.position.y))  # canto da direita
	var c := _iso(r.end)  # canto da frente
	var d := _iso(Vector2(r.position.x, r.end.y))  # canto da esquerda
	draw_colored_polygon(PackedVector2Array([d, c, c + lift, d + lift]), color.darkened(0.12))  # face +y
	draw_colored_polygon(PackedVector2Array([c, b, b + lift, c + lift]), color.darkened(0.3))  # face +x
	draw_colored_polygon(PackedVector2Array([a + lift, b + lift, c + lift, d + lift]), color.lightened(0.1))


func _draw_outline(r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array([_iso(r.position), _iso(Vector2(r.end.x, r.position.y)), _iso(r.end), _iso(Vector2(r.position.x, r.end.y)), _iso(r.position)])
	draw_polyline(pts, color, 1.0)


# Círculo no chão (alcance): vira uma elipse deitada na tela.
func _draw_range(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 97:
		pts.append(_iso(center + Vector2.from_angle(TAU * i / 96.0) * radius))
	draw_polyline(pts, color, 1.0)


# Luz das 17h (Léo, 05/11/2026; valores provisórios): a sombra é uma mancha suave e sem forma
# (bokeh grande e limpo), levemente deslocada para longe do sol, em tom frio.
const SHADOW_COLOR := Color(0.06, 0.05, 0.14, 0.42)
const SHADOW_OFFSET := Vector2(0.9, 0.42)  # deslocamento da mancha (fração do raio)
const SHADOW_SCALE := 2.4  # tamanho da mancha em relação ao raio do contato
static var _soft_shadow: Texture2D


# Textura radial com queda suave (centro cheio, borda transparente), criada uma vez.
static func _soft_shadow_texture() -> Texture2D:
	if _soft_shadow == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := (n - 1) * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x - c, y - c).length() / c
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(0.0, 1.0, d)))
		_soft_shadow = ImageTexture.create_from_image(img)
	return _soft_shadow


func _draw_cast_shadow(at: Vector2, _height: float, radius: float) -> void:
	var r := radius * SHADOW_SCALE
	var center := at + SHADOW_OFFSET * radius * 0.8
	draw_texture_rect(_soft_shadow_texture(), Rect2(center - Vector2(r, r * 0.5), Vector2(r * 2.0, r)), false, SHADOW_COLOR)


const MEMBER_COLORS := {2: Color("#5e4a82")}  # figura provisória: Miguel (roxo); o Fernando já tem a folha de parado em 3D


# Figura provisória (corpo, cabeça e nome), como a do Caio e da Letícia no parque.
func _draw_member_placeholder(u: Combatant, at: Vector2) -> void:
	var color: Color = MEMBER_COLORS.get(looks.get(u, 0), Color("#6a6a6a"))
	draw_rect(Rect2(at + Vector2(-11, -66), Vector2(22, 60)), color)
	draw_rect(Rect2(at + Vector2(-8, -86), Vector2(16, 18)), Color("#d6b292"))
	if turns:
		return  # em combate o nome já aparece sobre a barra de vida
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, at + Vector2(-width * 0.5, -94), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.05, 0.03, 0.02))
	draw_string(font, at + Vector2(-width * 0.5, -94), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.93, 0.89, 0.8))


func _draw_unit(u: Combatant) -> void:
	var at := _iso(u.pos)
	at += fx.offset_of(u)  # arremessado pelo tiro ou desviando dele
	_draw_cast_shadow(at, CharacterSheet.HEIGHT, 26.0)
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
		if use_3d and _sheet3d(u) != null:  # Nikolai e Fernando: mesmas animações
			var sheet := _sheet3d(u)
			var anim := "walk" if walking else "idle"
			if u.crouched:  # agachado (tecla C): parado ou andando agachado
				anim = "crouch_walk" if walking else "crouch_idle"
			if anim3d_pick >= 0:
				anim = AnimSheet.NAMES[anim3d_pick]
			var count := sheet.frame_count(anim)
			var f := int(Time.get_ticks_msec() / 1000.0 * AnimSheet.FPS[anim]) % count
			if walking and anim3d_pick < 0:
				f = int(walk_dist.get(u, 0.0) / (NIKOLAI_WALK_CYCLE_PIXELS / count)) % count  # passo por distância
			var pose := _nikolai_pose(u) if anim3d_pick < 0 else []
			if not pose.is_empty():
				anim = pose[0]
				f = pose[1]
			sheet.draw(self, at, anim, f, facing8.get(u, CharacterSheet.Dir.SE))
		elif use_3d:
			_draw_member_placeholder(u, at)  # Miguel: figura provisória até a arte 3D existir
		else:
			var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
			var n := walk_n % frames.size() if walking else idle_frame
			agent_sheets[looks.get(u, 0)].draw(self, at, frames[n], facing8.get(u, CharacterSheet.Dir.SE))
		if not u.is_alive():
			draw_string(ThemeDB.fallback_font, at + Vector2(-22, -CharacterSheet.HEIGHT - 14), "CAÍDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))
	else:
		var variant := _enemy_variant(i)
		if variant == CREATURE_VARIANT:
			_draw_creature(u, at, walking, walk_dist.get(u, 0.0))
		elif enemy_sheets.has(variant):
			var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
			var n := walk_n % frames.size() if walking else idle_frame
			enemy_sheets[variant].draw(self, at, frames[n], facing8.get(u, CharacterSheet.Dir.SW))
		else:
			var frame := 1 + walk_n % 2 if walking else 0
			var tex := PlaceholderArt.character_texture(variant, facing.get(u, PlaceholderArt.Dir.SOUTH), frame)
			var size := Vector2(PlaceholderArt.FRAME_SIZE * PLACEHOLDER_SCALE)
			draw_texture_rect(tex, Rect2((at - PlaceholderArt.PIVOT * PLACEHOLDER_SCALE).round(), size), false)
	var flash := fx.white_alpha(u)
	if flash > 0.0 and not _flash_in_3d(u):  # alvo pisca branco (até a arte entregar os quadros de dano)
		draw_set_transform(at + Vector2(0, -CharacterSheet.HEIGHT * 0.5), 0.0, Vector2(0.55, 1.0))
		draw_circle(Vector2.ZERO, CharacterSheet.HEIGHT * 0.42, Color(1, 1, 1, 0.75 * flash))
		draw_set_transform(Vector2.ZERO)
	if mode != Mode.EXPLORATION:
		_draw_health_bar(u, at)


# Folha 3D do personagem (Nikolai ou Fernando); null para quem ainda não tem arte 3D.
func _sheet3d(u: Combatant) -> AnimSheet:
	if enemies.has(u):
		return null
	match looks.get(u, 0):
		1:
			return nikolai3d
		0:
			return fernando3d
		2:
			return miguel3d if _modelos_3d() and Agente3D.tem_modelo("miguel3d") else null
	return null


# Sala com personagens 3D de verdade (o parque); aqui, na sala de teste, só existem as folhas.
func _modelos_3d() -> bool:
	return false


# Animação de ataque do Nikolai 3D por arma; sem ela (espada, por exemplo) ele não muda de pose.
const ATTACK_ANIM := {"pistola": "pistol_shoot", "escopeta": "rifle_fire", "fuzil_precisao": "rifle_fire", "soco": "punch"}


# Pose de combate do Nikolai 3D: [animação, quadro] ou [] quando vale parado/andando.
# Morte (fica no último quadro até reanimar), levantar, dano e a mira do ataque (durante a mira do CombatFx).
func _nikolai_pose(u: Combatant) -> Array:
	var sheet := _sheet3d(u)
	var now := Time.get_ticks_msec()
	if not u.is_alive() and not fx.hold_pv.has(u):  # o tombo espera o impacto do tiro
		if nikolai_clock.get(u, {}).get("anim", "") != "death":
			nikolai_clock[u] = {"anim": "death", "start": now}
		var n := sheet.frame_count("death")
		return ["death", mini(int((now - nikolai_clock[u]["start"]) / 1000.0 * AnimSheet.FPS["death"]), n - 1)]
	if nikolai_clock.has(u):
		var c: Dictionary = nikolai_clock[u]
		if c["anim"] == "death":
			nikolai_clock[u] = {"anim": "getup", "start": now}  # reanimado: levanta
			c = nikolai_clock[u]
		var anim: String = c["anim"]
		var f := int((now - c["start"]) / 1000.0 * AnimSheet.FPS[anim])
		if f < sheet.frame_count(anim):
			return [anim, f]
		nikolai_clock.erase(u)
	for job in fx.jobs:
		if job["attacker"] == u and ATTACK_ANIM.has(str(u.weapon["id"])):
			var attack: String = ATTACK_ANIM[str(u.weapon["id"])]
			var n := sheet.frame_count(attack)
			return [attack, mini(int(CombatFx.aim_progress(job) * n), n - 1)]
	return []


func _has_creatures() -> bool:
	return not enemies.is_empty() and _enemy_variant(0) == CREATURE_VARIANT


# Escolhe a animação da Criatura de Sangue: morte, ataque (durante a mira), transição ao entrar em
# combate, andar ou parada.
func _draw_creature(u: Combatant, at: Vector2, walking: bool, dist: float) -> void:
	var now := Time.get_ticks_msec()
	var dir: CharacterSheet.Dir = facing8.get(u, CharacterSheet.Dir.SW)
	var anim := "idle"
	var f := 0
	if not u.is_alive():
		if not creature_clock.has(u):
			creature_clock[u] = now
		anim = "death"
		f = mini(int((now - creature_clock[u]) / 1000.0 * CreatureSheet.FPS["death"]), creature.frame_count("death") - 1)
	else:
		creature_clock.erase(u)
		var attacking := false
		for job in fx.jobs:
			if job["attacker"] == u:
				anim = "attack"
				var n := creature.frame_count("attack")
				f = mini(int(CombatFx.aim_progress(job) * n), n - 1)
				attacking = true
				break
		if not attacking:
			var since := (now - combat_started_ms) / 1000.0
			if mode == Mode.COMBAT and since < TRANSITION_SECONDS:
				anim = "transition"
				f = mini(int(since * CreatureSheet.FPS["transition"]), creature.frame_count("transition") - 1)
			elif walking:
				anim = "walk"
				f = int(dist / (CREATURE_WALK_CYCLE_PIXELS / creature.frame_count("walk"))) % creature.frame_count("walk")
			else:
				f = int(now / 1000.0 * CreatureSheet.FPS["idle"]) % creature.frame_count("idle")
	creature.draw(self, at, anim, f, dir)


# Barra de vida com nome (modelo B): desce no impacto e deixa um rastro claro por 0,6 s.
func _draw_health_bar(u: Combatant, at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var bar := Rect2(at + Vector2(-26, -CharacterSheet.HEIGHT - 8), Vector2(52, 6))
	if _under_hud_panel(bar.get_center()):  # o nome e a barra não aparecem através do vidro fosco do HUD
		return
	var shown := float(fx.displayed_pv(u)) / maxf(u.max_pv, 1)
	draw_string_outline(font, bar.position + Vector2(0, -3), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0.05, 0.03, 0.02))
	draw_string(font, bar.position + Vector2(0, -3), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.93, 0.89, 0.8))
	draw_rect(bar.grow(1.0), Color(0.05, 0.03, 0.02))
	draw_rect(bar, Color(0.2, 0.2, 0.2))
	if fx.trail.has(u):
		var t: Dictionary = fx.trail[u]
		var from := clampf(float(t["from"]) / maxf(u.max_pv, 1), 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * from, bar.size.y)), Color(1, 1, 1, 0.85 * clampf(t["time"] / CombatFx.TRAIL_SECONDS, 0.0, 1.0)))
	var color := Color(0.3, 0.85, 0.35) if u.side == Combatant.Side.PLAYER else Color(0.85, 0.28, 0.25)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown, bar.size.y)), color)


# Vivos mais os abatidos que o tiro ainda está encenando.
func _drawn_units() -> Array[Combatant]:
	var out := _living_units()
	for u in fx.dying():
		out.append(u)
	return out


# Altura do peito em px do desenho: onde a mira e o impacto pousam (a sala 2D usa 60; o parque 3D, a do modelo).
func _chest_px(_u: Combatant) -> float:
	return 60.0


# Mira, clarão, partículas e flash vermelho do modelo B, por cima da cena e por baixo do HUD.
func _draw_fx() -> void:
	# Sem linha durante a animação do ataque (Léo, 13/11): a única linha é a da prévia, ao apontar/clicar no alvo.
	for m in fx.muzzles:  # clarão de 2 quadros
		var big: bool = m["time"] > CombatFx.MUZZLE_SECONDS * 0.5
		var r := 9.0 if big else 5.0
		draw_circle(m["pos"], r, Color(1.0, 0.85, 0.45, 0.95))
		draw_circle(m["pos"], r * 0.5, Color(1, 1, 0.9))
	for pt in fx.particles:
		var k: float = clampf(pt["life"] / pt["max"], 0.0, 1.0)
		match pt["kind"]:
			"smoke":
				draw_circle(pt["pos"], pt["size"] * (1.6 - k), Color(0.75, 0.75, 0.75, 0.35 * k))
			"casing":
				draw_rect(Rect2(pt["pos"], Vector2(3, 2)), Color(0.9, 0.7, 0.25, k))
			_:
				draw_circle(pt["pos"], pt["size"], Color(0.7, 0.05, 0.05, k))
	if fx.flash_red > 0.0:  # flash vermelho de 0,22 s na tela
		var view := get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)
		draw_rect(view, Color(0.8, 0.05, 0.05, 0.28 * fx.flash_strength * fx.flash_red / CombatFx.FLASH_RED_SECONDS))


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
		var blocker := _attack_blocker(player, target)
		if blocker != "":
			text = HudText.rejection_message(blocker)
		else:
			_draw_hit_label(font, screen_mouse, target)  # P1: etiqueta de acerto, dano e cobertura
		_draw_fire_line(font, target, blocker)
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


# P1 (modelo A, Léo 02/11/2026): etiqueta junto da mira com a chance de acerto, a faixa de dano e,
# quando há, a cobertura que pesa na conta.
func _draw_hit_label(font: Font, at: Vector2, target: Combatant) -> void:
	var lines: Array[String] = ["Acerto %d%%" % roundi(rules.hit_chance(player, target, covers) * 100.0), "Dano %d a %d" % [int(player.weapon["damage_min"]), int(player.weapon["damage_max"])]]
	if rules.flanker(player, target) != null:
		lines.append("Flanco +%d%%" % roundi(cfg.value("flank_hit_bonus") * 100.0))
	var c := rules.cover_between(player.pos, target, covers)
	if c:
		if c.kind == "partial":
			lines.append("Cobertura −%d%%" % roundi(float(cfg.cover("partial")["hit_penalty"]) * 100.0))
		else:
			lines.append("Cobertura completa")
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var box := Rect2(at + Vector2(16, -24 - 15 * lines.size()), Vector2(w + 12, 8 + 15 * lines.size()))
	_draw_tag_box(box, Color(1, 1, 1, 0.22))
	for i in lines.size():
		var col := Color(0.89, 0.69, 0.3) if i == 0 else (Color(0.88, 0.55, 0.35) if i == 2 else Color(0.95, 0.9, 0.82))
		draw_string(font, box.position + Vector2(6, 14 + 15 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if i == 0 else 11, col)


# Etiqueta do jogo no mundo no estilo do HUD: placa escura, contorno preto e uma linha fina por dentro.
func _draw_tag_box(box: Rect2, line: Color) -> void:
	draw_rect(box, Color(0.04, 0.04, 0.05, 0.94))
	draw_rect(box.grow(1.0), Color.BLACK, false, 1.0)
	draw_rect(box.grow(-0.5), line, false, 0.75)


# P2 (modelo B): linha de tiro tracejada; a cobertura que pesa ganha um escudo com a penalidade e a
# parede (sem linha de visão) uma marca de bloqueio no meio da linha.
func _draw_fire_line(font: Font, target: Combatant, blocker: String) -> void:
	var from := _iso(player.pos) + Vector2(0, -30)
	var to := _iso(target.pos) + Vector2(0, -30)
	var red := Color(0.85, 0.33, 0.31, 0.9)
	draw_dashed_line(from, to, red, 1.5, 6.0)
	if blocker == "no_line_of_sight":
		var mid := (from + to) * 0.5
		draw_line(mid + Vector2(-5, -5), mid + Vector2(5, 5), red, 2.0)
		draw_line(mid + Vector2(-5, 5), mid + Vector2(5, -5), red, 2.0)
		return
	var c := rules.cover_between(player.pos, target, covers)
	if c and c.kind == "partial":
		var k := clampf(Geometry2D.get_closest_point_to_segment(_iso(c.rect.get_center()) + Vector2(0, -30), from, to).distance_to(from) / maxf(from.distance_to(to), 1.0), 0.0, 1.0)
		var at := from.lerp(to, k)
		var label := "−%d%%" % roundi(float(cfg.cover("partial")["hit_penalty"]) * 100.0)
		var r := Rect2(at + Vector2(-17, -26), Vector2(34, 16))
		_draw_tag_box(r, Color(0.88, 0.55, 0.35, 0.6))
		draw_string(font, r.position + Vector2(3, 12), label, HORIZONTAL_ALIGNMENT_CENTER, 28, 11, Color(0.88, 0.55, 0.35))


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
	_draw_tag_box(Rect2(tag - Vector2(w * 0.5, 9), Vector2(w, 16)), Color(gold, 0.55))
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
	unlinked.erase(m)  # o novo líder volta à corrente
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


# Solta o seguidor da corrente (ele para de acompanhar o líder) ou o prende de volta.
func _toggle_link(m: Combatant) -> void:
	if m == player:
		return
	if unlinked.has(m):
		unlinked.erase(m)
	else:
		unlinked[m] = true
		follow_paths.erase(m)
	queue_redraw()


# Índice do elo (entre o cartão i e o i + 1) sob o ponto da tela, ou -1.
func _link_at(screen: Vector2) -> int:
	for i in party.size() - 1:
		if party_hud.link_rect(i).has_point(screen):
			return i
	return -1


func _update_followers(delta: float) -> void:
	for m in party:
		if m == player or not m.is_alive() or unlinked.has(m):
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
			if route.is_empty():
				# Ainda sem rota: ele está dentro de uma colisão do cenário (Léo, 08/11: "Miguel tá travado", nasceu
				# dentro dos pneus). Sai para o ponto livre mais próximo e tenta de novo no próximo quadro.
				var livre := _ponto_livre_perto(m)
				if livre != m.pos:
					m.pos = livre
					queue_redraw()
					continue
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


# Ponto mais próximo de `m` fora das colisões do cenário (anéis de 8 em 8 px, até 96 px); sem nenhum, a própria posição.
func _ponto_livre_perto(m: Combatant) -> Vector2:
	for raio in range(8, 97, 8):
		for k in 16:
			var q := m.pos + Vector2.RIGHT.rotated(TAU * k / 16.0) * raio
			var livre := true
			for o in _obstacles(m, false):
				if (o as Rect2).grow(m.radius).has_point(q):
					livre = false
					break
			if livre:
				return q
	return m.pos


# Medida do desenho em tamanho cheio -> pixels da ficha na escala atual.
func _k(v: float) -> float:
	return v * party_hud.SHEET_SCALE


func _fs(size: int) -> int:
	return maxi(roundi(size * party_hud.SHEET_SCALE), 8)


func _portrait_rect(i: int) -> Rect2:
	return party_hud.card_rect(i)


# Mouse sobre uma ficha ou sobre o rodapé de ações: sem prévia de movimento ou ataque.
func _mouse_on_hud(screen: Vector2) -> bool:
	if _portrait_at(screen) or _link_at(screen) >= 0:
		return true
	if mode != Mode.COMBAT or not _player_ready():
		return false
	return action_bar._bar_rect(action_bar._action_slots().size()).grow(8).has_point(screen)  # a barra inteira e a faixa de PA


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
		party_hud._draw_sheet(font, party[i], i, to_world)
	party_hud._draw_links(font, to_world)
	minimap._draw_minimap(font, to_world)
	objectives_hud._draw_objectives(font, to_world, _objectives())
	if mode == Mode.COMBAT and turns:
		party_hud._draw_turn_order(font, to_world)
		if _player_ready():
			action_bar._draw_actions(font, to_world)
	_draw_combat_log(font)
	_draw_perf(font)


# Da posição na tela (960×540) para onde o HUD é desenhado. Com a câmera aproximada o parque desenha o
# HUD com escala inversa ao zoom e troca isto por uma translação.
func _hud_to_world() -> Transform2D:
	return get_canvas_transform().affine_inverse()


# Ponto do mundo que cai sobre uma placa de vidro fosco do HUD (com uma folga de 10 px).
func _under_hud_panel(world: Vector2) -> bool:
	var p := get_canvas_transform() * world
	for r in _hud_blur_rects():
		if r.grow(10.0).has_point(p):
			return true
	return false


# Escala do desenho do HUD (a sala de teste desenha em pixels da tela; o parque troca pelo inverso do zoom).
func _hud_draw_scale() -> Vector2:
	return Vector2.ONE


# Placas do HUD com vidro fosco por trás (pixels da tela): ordem dos turnos e barra de ações, no combate.
func _hud_blur_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if mode == Mode.COMBAT and turns:
		out.append(party_hud.turn_order_rect())
		if _player_ready():
			out.append(action_bar._bar_rect(action_bar._action_slots().size()))
	return out


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


# Objetivos mostrados no HUD; a sala de teste não tem, as áreas derivadas (parque) trocam.
func _objectives() -> Array[Dictionary]:
	return []


# Nome do local na placa do radar; as áreas derivadas trocam.
func _place_label() -> String:
	return "SALA DE TESTE"


# Visual do inimigo `i` da lista `enemies` (a sala de teste alterna cultista e atirador).
func _enemy_variant(i: int) -> String:
	return ENEMY_VARIANTS[i % ENEMY_VARIANTS.size()]


