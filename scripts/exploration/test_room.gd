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

enum Mode { EXPLORATION, COMBAT, GAME_OVER, CUTSCENE }  # CUTSCENE: cena do fim da missão 1 (CenaTentaculo)


signal move_finished


const SPEED := 180.0

const STAND_OFFSET := 6.0

const FOLLOW_DISTANCE := 60.0  # distância fixa do seguidor ao líder (provisório)

const FOLLOW_SPREAD := 1.0  # variação do ângulo do seguidor em radianos (provisório)

const REVIVE_REACH := 16.0  # borda a borda: "adjacente" para reanimar

const KIT_ID := "kit_primeiros_socorros"

const RELOAD_SECONDS := 2.0  # recarga: 12 quadros a 6/s (AnimSheet.FPS["reload"])
const SWAP_PA := 1  # trocar de arma em combate (GDD #18)
const RELOAD_PA := 1  # recarregar em combate (1 PA, GDD #18; provisório)

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
	"san": {"size": 22, "color": Color(0.49, 0.65, 0.93)},
	"fala": {"size": 14, "color": Color(0.9, 0.9, 0.95)},
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
var san := SanRules.new(cfg)  # SAN como medidor de terror: perda, ruptura e loucura (GDD #11)

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
var loot_rng := RandomNumberGenerator.new()  # sorteio dos itens largados pelos inimigos

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
var san_fx := SanFx.new(self)  # aviso de SAN na tela (modelo C com B)
var objectives_hud := RoomObjectivesHud.new(self)

# Módulos da sala (separados de test_room.gd): a sala guarda o estado e repassa para eles; as funções
# que o parque e o local3d trocam continuam aqui (seção "Repasses", no fim do arquivo).
var room_combat := RoomCombat.new(self)
var room_gear := RoomGear.new(self)
var room_party := RoomParty.new(self)
var room_drawing := RoomDrawing.new(self)

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
	add_child(san_fx)  # antes do HudBlur: os dois leem a tela, e as placas do HUD ficam por cima
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
	audio.play_area_ambience(_area_id())
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
	# Esc pausa e abre o menu de pausa (o inventário aberto pega o Esc antes, em _input).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and can_pause():
		PauseMenu.open_on(self)
		get_viewport().set_input_as_handled()
		return
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
		elif event.pressed and event.keycode == KEY_G:
			_reload()
		elif event.pressed and event.keycode == KEY_F:
			_overwatch()
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
			elif action_bar._action_rect(action_bar.kit_index() + 1, n).has_point(screen):
				_overwatch()
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
	if player != null:
		audio.update_heartbeat(_san_ratio())  # coração em laço com a SAN baixa
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
		var stepped := before.distance_to(_iso(moving_unit.pos))
		walk_dist[moving_unit] = walk_dist.get(moving_unit, 0.0) + stepped
		_step_sound(moving_unit, stepped)
		if moving_unit.pos.is_equal_approx(path[0]):
			path.remove_at(0)
		if mode == Mode.COMBAT and moving_unit.side == Combatant.Side.ENEMY and _overwatch_fire(moving_unit):
			path = PackedVector2Array()  # o inimigo é detido pelo tiro de vigilância
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


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# A sala de teste não tem save: recomeça. O parque e os outros lugares voltam ao autosave.
func can_pause() -> bool:
	return mode != Mode.GAME_OVER and not get_tree().paused and not Scenes.busy(get_tree())


func _voltar_ao_save() -> void:
	get_tree().reload_current_scene()


# --- Turno do jogador --------------------------------------------------------


func _player_ready() -> bool:
	return mode == Mode.COMBAT and not busy and turns.is_turn_of(player)


# --- Inventário e equipamento ---------------------------------------------------
# As regras moram em room_gear.gd; aqui fica só o gancho que as áreas trocam.


# Escassez (sugestão 7, 15/11): na missão a mochila começa magra e kit, bandagem, antídoto e munição
# só vêm do cenário (pistas com "da"). A sala de teste segue com a mochila farta. Provisório do Claude.
func _gear_scarce() -> bool:
	return false


# --- Turno do inimigo --------------------------------------------------------
# A IA mora em EnemyAi (scripts/exploration/enemy_ai.gd); a sala só entrega o turno e responde pelo
# movimento animado (_start_move/move_finished) e pela encenação do ataque (_show_attack).


var ai := EnemyAi.new(self)


func _run_enemy_turn(unit: Combatant) -> void:
	await ai.run_turn(unit)


func _enemy_target(unit: Combatant) -> Combatant:
	return ai.pick_target(unit)


# --- Feedback e desenho: ganchos e constantes (o desenho mora em room_drawing.gd) ---


# Verdadeiro quando o modelo 3D do personagem já pisca sozinho (o parque 3D); senão a mancha branca é desenhada.
func _flash_in_3d(_u: Combatant) -> bool:
	return false


# Gancho para a sala encenar o golpe por conta própria (o parque 3D toca a animação do modelo).
func _attack_started(_attacker: Combatant, _target: Combatant, _aim: float) -> void:
	pass


const LOG_SECONDS := 8.0

const LOG_MAX := 4


# Feedback de combate (provisório do Claude, 29/10/2026): dano em número que sobe e some,
# "ERROU" em cinza, crítico maior em dourado com "CRÍTICO!" e um tremor na tela.
# Pop-ups só com o número (Léo, 13/11): sem placa nem etiqueta, fonte do título, contorno escuro e uma sombra suave.
# Palavras (ERROU, CAÍDO...) ficam menores, na mesma fonte.
const POPUP_FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")


# Luz das 17h (Léo, 05/11/2026; valores provisórios): a sombra é uma mancha suave e sem forma
# (bokeh grande e limpo), levemente deslocada para longe do sol, em tom frio.
const SHADOW_COLOR := Color(0.06, 0.05, 0.14, 0.42)
const SHADOW_OFFSET := Vector2(0.9, 0.42)  # deslocamento da mancha (fração do raio)
const SHADOW_SCALE := 2.4  # tamanho da mancha em relação ao raio do contato


const MEMBER_COLORS := {2: Color("#5e4a82")}  # figura provisória: Miguel (roxo); o Fernando já tem a folha de parado em 3D


# Sala com personagens 3D de verdade (o parque); aqui, na sala de teste, só existem as folhas.
func _modelos_3d() -> bool:
	return false


# Animação de ataque do Nikolai 3D por arma; sem ela (espada, por exemplo) ele não muda de pose.
const ATTACK_ANIM := {"pistola": "pistol_shoot", "escopeta": "rifle_fire", "fuzil_precisao": "rifle_fire", "soco": "punch"}


# Altura do peito em px do desenho: onde a mira e o impacto pousam (a sala 2D usa 60; o parque 3D, a do modelo).
func _chest_px(_u: Combatant) -> float:
	return 60.0


# Rota da prévia do mouse. A prévia é redesenhada todo quadro; refazer o pathfinding a cada quadro
# travava o jogo, então a rota só é recalculada quando muda o ponto do mouse, quem anda ou as unidades.
var _route_key := ""

var _route_cache := PackedVector2Array()


# --- HUD e minimapa: ganchos que as áreas trocam ---------------------------------


# Da posição na tela (960×540) para onde o HUD é desenhado. Com a câmera aproximada o parque desenha o
# HUD com escala inversa ao zoom e troca isto por uma translação.
func _hud_to_world() -> Transform2D:
	return get_canvas_transform().affine_inverse()


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


# --- Repasses ------------------------------------------------------------------
# Cada função abaixo mora no módulo indicado. Ficam aqui com o mesmo nome e assinatura porque o parque, o
# local3d, os painéis e os testes as chamam ou as trocam (override); "override" marca as que as áreas trocam.


# Combate (room_combat.gd)


func _reloading(u: Combatant) -> bool:
	return room_combat._reloading(u)


func _attack_blocker(attacker: Combatant, target: Combatant) -> String:
	return room_combat._attack_blocker(attacker, target)


# Passo a cada STEP_SOUND_PIXELS andados na tela; só o controlado soa (o grupo seguindo ficaria um coro).
const STEP_SOUND_PIXELS := 38.0
var _step_acc := 0.0


func _step_sound(u: Combatant, stepped: float) -> void:
	if u.side != Combatant.Side.PLAYER or u != player:
		return
	_step_acc += stepped
	if _step_acc >= STEP_SOUND_PIXELS:
		_step_acc = fmod(_step_acc, STEP_SOUND_PIXELS)
		audio.play_step(_step_surface(), u.crouched)


# Piso sob os pés: "floor" (madeira, interior) ou "grass" (terra e grama); os cenários de fora trocam.
func _step_surface() -> String:
	return "floor"


# Id do cenário, para o som ambiente; a sala de teste não tem (os cenários trocam).
func _area_id() -> String:
	return ""


func _check_detection() -> void:
	room_combat._check_detection()


func _stealth_attack(target: Combatant) -> void:
	room_combat._stealth_attack(target)


func _start_combat(surprise_side: int = -1) -> void:  # override
	room_combat._start_combat(surprise_side)


func _on_combat_ended(result: TurnManager.Result) -> void:  # override
	room_combat._on_combat_ended(result)


func _combat_click(click: Vector2) -> void:
	await room_combat._combat_click(click)


func _revive(fallen: Combatant) -> void:
	room_combat._revive(fallen)


func _use_kit_button() -> void:
	room_combat._use_kit_button()


func _player_pass() -> void:
	room_combat._player_pass()


func _swap_weapon() -> void:
	room_combat._swap_weapon()


func _reload() -> void:
	room_combat._reload()


func _player_delay() -> void:
	room_combat._player_delay()


func _overwatch() -> void:
	room_combat._overwatch()


func _overwatch_fire(mover: Combatant) -> bool:
	return room_combat._overwatch_fire(mover)


func _reject(reason: String) -> void:
	room_combat._reject(reason)


func _enemy_at(p: Vector2) -> Combatant:
	return room_combat._enemy_at(p)


func _cover_at(p: Vector2) -> Cover:
	return room_combat._cover_at(p)


func _show_attack(attacker: Combatant, target: Combatant, r: Dictionary) -> void:  # override
	room_combat._show_attack(attacker, target, r)


func _attack_aim(attacker: Combatant) -> float:  # override
	return room_combat._attack_aim(attacker)


func _log(text: String) -> void:
	room_combat._log(text)


func _on_fx_impact(job: Dictionary) -> void:  # override
	room_combat._on_fx_impact(job)


func _popup(at: Vector2, text: String, kind := "info") -> void:
	room_combat._popup(at, text, kind)


# Inventário e equipamento (room_gear.gd)


func _reserve_id() -> String:
	return room_gear._reserve_id()


func ammo_item(weapon_id: String) -> String:
	return room_gear.ammo_item(weapon_id)


func ammo_of(u: Combatant) -> Array:
	return room_gear.ammo_of(u)


func inventory_can_open() -> bool:
	return room_gear.inventory_can_open()


func gear_item_kind(id: String) -> String:
	return room_gear.gear_item_kind(id)


func gear_is_equippable(id: String) -> bool:
	return room_gear.gear_is_equippable(id)


func gear_slot_id(m: Combatant, slot: String) -> String:
	return room_gear.gear_slot_id(m, slot)


func gear_equip(m: Combatant, slot: String, bag_index: int) -> String:
	return room_gear.gear_equip(m, slot, bag_index)


func gear_swap_weapons(m: Combatant) -> String:
	return room_gear.gear_swap_weapons(m)


func gear_unequip(m: Combatant, slot: String) -> String:
	return room_gear.gear_unequip(m, slot)


func gear_discard(bag_index: int) -> String:
	return room_gear.gear_discard(bag_index)


func gear_use(m: Combatant, bag_index: int) -> String:
	return room_gear.gear_use(m, bag_index)


func _setup_gear() -> void:
	room_gear._setup_gear()


func _loot_enemy(e: Combatant) -> void:
	room_gear._loot_enemy(e)


func collect_items(found: Array) -> String:
	return room_gear.collect_items(found)


# Grupo (room_party.gd)


func _toggle_crouch() -> void:
	room_party._toggle_crouch()


func _switch_to(m: Combatant) -> void:
	room_party._switch_to(m)


func _reset_follow_offsets(heading: Vector2) -> void:
	room_party._reset_follow_offsets(heading)


func _toggle_link(m: Combatant) -> void:
	room_party._toggle_link(m)


func _link_at(screen: Vector2) -> int:
	return room_party._link_at(screen)


func _update_followers(delta: float) -> void:
	room_party._update_followers(delta)


func _k(v: float) -> float:
	return room_party._k(v)


func _fs(size: int) -> int:
	return room_party._fs(size)


func _portrait_rect(i: int) -> Rect2:
	return room_party._portrait_rect(i)


func _mouse_on_hud(screen: Vector2) -> bool:
	return room_party._mouse_on_hud(screen)


func _portrait_at(screen: Vector2) -> Combatant:
	return room_party._portrait_at(screen)


# Desenho (room_drawing.gd)


func _draw_overwatch() -> void:
	room_drawing._draw_overwatch()


func _draw() -> void:  # override
	room_drawing._draw()


func _san_ratio() -> float:
	return room_drawing._san_ratio()


func _draw_san_tint() -> void:
	room_drawing._draw_san_tint()


func _update_perf(delta: float) -> void:
	room_drawing._update_perf(delta)


func _draw_popup(_font: Font, p: Dictionary) -> void:
	room_drawing._draw_popup(_font, p)


func _draw_range(center: Vector2, radius: float, color: Color) -> void:
	room_drawing._draw_range(center, radius, color)


func _draw_cast_shadow(at: Vector2, _height: float, radius: float) -> void:  # override
	room_drawing._draw_cast_shadow(at, _height, radius)


func _draw_unit(u: Combatant) -> void:  # override
	room_drawing._draw_unit(u)


func _sheet3d(u: Combatant) -> AnimSheet:
	return room_drawing._sheet3d(u)


func _has_creatures() -> bool:
	return room_drawing._has_creatures()


func _draw_creature(u: Combatant, at: Vector2, walking: bool, dist: float) -> void:  # override
	room_drawing._draw_creature(u, at, walking, dist)


func _draw_health_bar(u: Combatant, at: Vector2) -> void:  # override
	room_drawing._draw_health_bar(u, at)


func _drawn_units() -> Array[Combatant]:  # override
	return room_drawing._drawn_units()


func _draw_fx() -> void:
	room_drawing._draw_fx()


func _draw_preview(font: Font) -> void:
	room_drawing._draw_preview(font)


func _draw_hud(font: Font) -> void:  # override
	room_drawing._draw_hud(font)


func _under_hud_panel(world: Vector2) -> bool:
	return room_drawing._under_hud_panel(world)