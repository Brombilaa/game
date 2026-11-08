extends "res://scripts/exploration/test_room.gd"
# Parque da missão 1: a sala inicial do jogo (Léo, 30/10/2026). Reaproveita tudo da sala de
# teste (grupo, combate, HUD, inventário) e troca só o cenário: o fundo 3D aprovado, as
# colisões, as pistas e o gatilho do combate vêm de `data/cenarios/parque.json` (Scenario).
# O fundo tem projeção própria (48 × 18,13 px por unidade), por isso `_iso` e `_uniso` mudam.
# Pistas: clique no objeto, o grupo anda até perto e o texto aparece; a árvore só depois das
# outras. Depois da árvore, dois cultistas (provisórios) atacam. A cutscene da morte do Caio
# e os diálogos dos NPCs ainda não existem.

const SCENARIO_ID := "parque"
const BOUNDS_PAD := 64.0  # espessura das paredes invisíveis na borda do plano
const BIG_PROPS := ["van", "lago", "lago_2", "lago_3", "lago_4", "arvore", "mata_1", "mata_2", "arbusto_4"]  # paredes: bloqueiam também a visão (Léo: van e arbustos atrás da árvore)
const NPC_RADIUS := 14.0
const NPC_NAMES := {"caio": "Caio", "leticia": "Letícia"}
const NPC_COLORS := {"caio": Color("#46628a"), "leticia": Color("#885050")}  # figuras provisórias
var caio3d := IdleSheet.new("caio3d", "caio3d")  # Caio: só a animação de parado (morre no primeiro mapa)

const DOT_RADIUS := 6.0  # bolinha da pista, em px do desenho
const DOT_HIT := 14.0  # raio em que o clique na bolinha vale (px do desenho)
const CLUE_NEAR := 260.0  # a bolinha ganha um anel quando o controlado chega perto
const STAND_FACTOR := 0.85  # distância de parada, em fração do raio da pista
const DUSK_TINT := Color(0.95, 0.55, 0.2, 0.1)  # véu do fim de tarde, 17h: sol baixo, laranja nas áreas claras (Léo, 05/11; provisório)
const DUSK_COOL := Color(0.16, 0.14, 0.42, 0.07)  # penumbra fria que escurece e esfria o conjunto (sombras azuladas)
const VOID_COLOR := Color(0.078, 0.07, 0.063)  # além da névoa do fundo estendido
const CAMERA_ZOOM := 1.5  # zoom inicial da câmera (a roda do mouse muda); câmera aproximada: o fundo estendido cobre o que ela mostra (Léo, 30/10)
const VIGNETTE_SIZE := 128  # textura da vinheta, esticada sobre a tela
const VIGNETTE_STRENGTH := 0.4
const FRAME_BG := Color(0.063, 0.043, 0.031, 0.95)
# Cenário 3D ao vivo (Léo, 08/11/2026: migração completa para o parque 3D). O fundo assado e os recortes de
# oclusão ficam só como reserva (USE_WORLD3D = false). A projeção é a mesma: 1 unidade 3D = 64 px do plano.
const USE_WORLD3D := true
const PARQUE3D := preload("res://scenes/exploration/parque3d.tscn")
const P3D := preload("res://scripts/exploration/parque3d.gd")
const PX_UNIT := 67.88  # px do desenho por unidade 3D, nos eixos da câmera (48 / sqrt(0.5))
const NEVOA_FORCA := 0.6  # névoa de distância do protótipo JS (1 = igual); modelo C, escolhido pelo Léo em 8/11
const NEVOA_BAIXA := 0.55  # névoa rente ao chão (modelo C, escolhido pelo Léo em 8/11)
const CARD_LIFT := 0.3  # cartão adiantado na direção da câmera: a sola não afunda no chão (não muda o lugar na tela)

var scenario: Scenario
var backdrop: Texture2D
var extended: Texture2D  # fundo com terreno e lago além do mapa
var occluder_textures := {}  # id -> recorte do fundo
var seen_clues: Array[String] = []
var pending_clue := ""
var dialog_layer: CanvasLayer
var dialog_clue := ""
var dialog_text: Label
var dialog_image: TextureRect
var vignette: Texture2D
var world3d: Node3D  # parque3d.gd embutido
var cards: Array[MeshInstance3D] = []  # cartões dos personagens no 3D, reaproveitados a cada quadro
var blobs: Array[MeshInstance3D] = []  # sombra de contato sob cada cartão
var cards_used := 0
var agentes := {}  # personagem (Combatant) ou id do NPC -> Agente3D, modelo 3D com esqueleto
var agentes_usados := {}  # personagens com modelo desenhado neste quadro
var drawing_key: Variant = null  # personagem (ou id do NPC) sendo desenhado, para a folha achar o modelo dele


func _ready() -> void:
	scenario = Scenario.load_id(SCENARIO_ID)
	assert(scenario.ok(), "\n".join(scenario.errors))
	backdrop = load(scenario.backdrop_path)
	if scenario.extended_path != "":
		extended = load(scenario.extended_path)
	for o in scenario.occluders:
		occluder_textures[o["id"]] = load(o["arquivo"])
	_load_layout()
	if USE_WORLD3D:
		world3d = PARQUE3D.instantiate()
		world3d.embutido = true
		world3d.nevoa_forca = NEVOA_FORCA
		world3d.nevoa_baixa = NEVOA_BAIXA
		if OS.get_environment("NEVOA") != "":  # comparação de modelos de névoa: "forca,baixa"
			var v := OS.get_environment("NEVOA").split(",")
			world3d.nevoa_forca = float(v[0])
			world3d.nevoa_baixa = float(v[1])
		add_child(world3d)
	super()
	var corners := [_iso(Vector2.ZERO), _iso(Vector2(scenario.size.x, 0)), _iso(Vector2(0, scenario.size.y)), _iso(scenario.size)]
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	if extended:  # a câmera nunca sai da imagem estendida
		var top_left := scenario.extended_pos - scenario.backdrop_origin
		camera.limit_left = int(top_left.x)
		camera.limit_top = int(top_left.y)
		camera.limit_right = int(top_left.x) + extended.get_width()
		camera.limit_bottom = int(top_left.y) + extended.get_height()
	else:
		camera.limit_left = int(corners[2].x) - 16
		camera.limit_right = int(corners[1].x) + 16
		camera.limit_top = int(corners[0].y) - 16
		camera.limit_bottom = int(corners[3].y) + 16
	vignette = _make_vignette()
	_build_dialog()
	if world3d:
		fx.muzzle_at = _arma3d
	fx.chest_px = _chest_px


# Paredes e coberturas a partir das colisões do cenário; o grupo começa na entrada.
func _load_layout() -> void:
	var size := scenario.size
	walls.clear()
	walls.append(Rect2(-BOUNDS_PAD, -BOUNDS_PAD, size.x + BOUNDS_PAD * 2.0, BOUNDS_PAD))
	walls.append(Rect2(-BOUNDS_PAD, size.y, size.x + BOUNDS_PAD * 2.0, BOUNDS_PAD))
	walls.append(Rect2(-BOUNDS_PAD, 0, BOUNDS_PAD, size.y))
	walls.append(Rect2(size.x, 0, BOUNDS_PAD, size.y))
	covers.clear()
	for cid in scenario.colliders:
		var rect: Rect2 = scenario.colliders[cid]
		if BIG_PROPS.has(cid):
			walls.append(rect)
		else:
			covers.append(Cover.new(rect, "partial", 20))
	door = Rect2(-1000, -1000, 1, 1)  # não há porta: nada fica escondido
	door_open = true
	enemies.clear()  # os cultistas só aparecem depois da árvore
	for i in party.size():
		party[i].pos = scenario.party_start[i]


# --- Projeção do fundo ----------------------------------------------------------------------

func _iso(p: Vector2) -> Vector2:
	return scenario.to_backdrop(p) - scenario.backdrop_origin


func _uniso(s: Vector2) -> Vector2:
	return scenario.from_backdrop(s + scenario.backdrop_origin)


func _place_label() -> String:
	return "PARQUE"


func _enemy_variant(_i: int) -> String:
	return CREATURE_VARIANT  # Criatura de Sangue no lugar dos cultistas (Léo, 5/11)


# Os NPCs também bloqueiam o caminho.
func _obstacles(mover: Combatant = null, with_units := true) -> Array[Rect2]:
	var out := super(mover, with_units)
	for npc in scenario.npcs.values():
		out.append(Rect2(npc - Vector2(NPC_RADIUS, NPC_RADIUS), Vector2(NPC_RADIUS, NPC_RADIUS) * 2.0))
	return out


# Minimapa: o parque inteiro conta como visto.
func _known_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append(Rect2(Vector2.ZERO, scenario.size))
	return out


# --- Desenho ----------------------------------------------------------------------------------

# Vinheta suave: escurece só as bordas da tela, de forma que o centro fica intacto.
static func _make_vignette() -> Texture2D:
	var img := Image.create(VIGNETTE_SIZE, VIGNETTE_SIZE, false, Image.FORMAT_RGBA8)
	var c := (VIGNETTE_SIZE - 1) * 0.5
	for y in VIGNETTE_SIZE:
		for x in VIGNETTE_SIZE:
			var d := Vector2(x - c, y - c).length() / (c * 1.414)
			var a := smoothstep(0.45, 1.0, d) * VIGNETTE_STRENGTH
			img.set_pixel(x, y, Color(0.05, 0.02, 0.0, a))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	var _draw_t0 := Time.get_ticks_usec()
	var font := ThemeDB.fallback_font
	var view := get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, get_viewport_rect().size)
	if world3d:
		_sync_camera3d()
		cards_used = 0
		agentes_usados.clear()
	else:
		draw_rect(view, VOID_COLOR)  # fora do parque é escuro, não o cinza do render
		if extended:
			draw_texture(extended, scenario.extended_pos - scenario.backdrop_origin)
		draw_texture(backdrop, -scenario.backdrop_origin)
	if mode == Mode.EXPLORATION:
		for e in enemies:
			if e.is_alive():
				_draw_range(e.pos, rules.perception_range(e, player), Color(PlaceholderArt.color("sangue_claro"), 0.35))
	var items: Array = []
	for u in _drawn_units():
		items.append({"pos": u.pos, "unit": u})
	for npc_id in scenario.npcs:
		items.append({"pos": scenario.npcs[npc_id], "npc": npc_id})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.x + a.pos.y < b.pos.x + b.pos.y)
	# Oclusão: o recorte de cada objeto é desenhado logo antes do primeiro personagem que está na
	# frente dele (todos os de antes ficam cobertos; os da frente são desenhados depois, por cima).
	var after := {}  # índice do item -> recortes a desenhar depois dele
	for o in ([] if world3d else scenario.occluders):  # no 3D a profundidade já esconde quem está atrás
		var cut := items.size()
		for i in items.size():
			if Scenario.in_front(items[i].pos, o["rect"]):
				cut = i
				break
		if cut > 0:
			after[cut - 1] = after.get(cut - 1, []) + [o]
	for i in items.size():
		if items[i].has("unit"):
			_draw_unit(items[i].unit)
		else:
			_draw_npc(font, items[i].npc)
		for o in after.get(i, []):
			draw_texture(occluder_textures[o["id"]], o["pos"] - scenario.backdrop_origin)
	if world3d:
		_hide_unused_cards()
		for u in agentes:
			agentes[u].visible = agentes_usados.has(u)
	if mode == Mode.EXPLORATION:
		_draw_clue_hints()  # por cima dos recortes: a bolinha da árvore ficava escondida atrás da copa
	if mode == Mode.COMBAT:
		_draw_preview(font)
	_draw_fx()
	_draw_san_tint()
	# Véu quente e vinheta cobrem o cenário e os personagens, mas ficam por baixo do HUD.
	if world3d == null:  # no 3D a luz e a névoa vêm da própria cena; o véu e a vinheta ficavam chapados por cima (Léo, 08/11)
		draw_rect(view, DUSK_COOL)
		draw_rect(view, DUSK_TINT)
		draw_texture_rect(vignette, view, false)
	_draw_hud(font)
	for p in popups:
		_draw_popup(font, p)
	_draw_usec = Time.get_ticks_usec() - _draw_t0


# Com a câmera aproximada o HUD é desenhado com a escala inversa ao zoom, para continuar do mesmo
# tamanho na tela: ponto da tela s vira s - origem do canvas, e o zoom devolve o tamanho.
func _hud_to_world() -> Transform2D:
	return Transform2D(0.0, -get_canvas_transform().origin)


# Afastar até o limite em que a câmera ainda cabe na imagem estendida (nunca mostra fora dela).
func _zoom_min() -> float:
	if extended == null:
		return 1.0
	var view := get_viewport_rect().size
	return maxf(1.0, maxf(view.x / extended.get_width(), view.y / extended.get_height()))


func _draw_hud(font: Font) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / camera.zoom.x)
	super(font)
	draw_set_transform(Vector2.ZERO)


# --- Parque 3D ----------------------------------------------------------------------------------

# Câmera 3D na mesma vista da Camera2D: o centro da tela cai no mesmo ponto do chão e o zoom vira o tamanho ortográfico.
func _sync_camera3d() -> void:
	var cam: Camera3D = world3d.camera
	var view := get_viewport_rect().size
	var xf := get_canvas_transform()
	var center := _uniso(xf.affine_inverse() * (view * 0.5))
	var target := Vector3(center.x / 64.0, 0.0, center.y / 64.0)
	cam.size = view.y / (xf.get_scale().y * PX_UNIT)
	cam.position = target + _to_camera() * P3D.DIST
	cam.look_at(target, Vector3.UP)


# Direção do chão para a câmera (azimute de 45°, elevação ELEV do parque3d).
func _to_camera() -> Vector3:
	var e: float = P3D.ELEV
	return Vector3(cos(e) * sin(PI / 4.0), sin(e), cos(e) * cos(PI / 4.0))


# Chamado pelas folhas (AnimSheet, IdleSheet, CreatureSheet) no lugar de desenhar no 2D: o quadro vira um
# cartão em pé nos pés do personagem, virado para a câmera, com a altura corrigida pela inclinação da câmera
# (assim ocupa na tela exatamente o mesmo lugar do desenho 2D).
func _sprite3d(tex: Texture2D, src: Rect2, pivot: Vector2, scale: float, flip: bool, pos: Vector2) -> void:
	if cards_used == cards.size():
		_new_card()
	var card := cards[cards_used]
	var blob := blobs[cards_used]
	cards_used += 1
	var cos_e := cos(P3D.ELEV)
	var w := src.size.x * scale / PX_UNIT
	var h := src.size.y * scale / (PX_UNIT * cos_e)
	(card.mesh as QuadMesh).size = Vector2(w, h)
	var m := card.material_override as ShaderMaterial
	var ts := tex.get_size()
	m.set_shader_parameter("folha", tex)
	m.set_shader_parameter("regiao", Vector4(src.position.x / ts.x, src.position.y / ts.y, src.size.x / ts.x, src.size.y / ts.y))
	m.set_shader_parameter("espelhar", flip)
	var g := _uniso(pos)
	var feet := Vector3(g.x / 64.0, 0.0, g.y / 64.0)
	var right := Vector3(cos(PI / 4.0), 0.0, -sin(PI / 4.0))
	var dx := (src.size.x * 0.5 - pivot.x) * scale / PX_UNIT * (-1.0 if flip else 1.0)
	var dy := (pivot.y - src.size.y * 0.5) * scale / (PX_UNIT * cos_e)
	card.position = feet + _to_camera() * CARD_LIFT + right * dx + Vector3(0.0, dy, 0.0)
	card.visible = true
	blob.position = feet + Vector3(0.0, 0.02, 0.0)
	blob.visible = true


const DIR_TELA := [Vector2(1, 0), Vector2(1, 0.5), Vector2(0, 1), Vector2(-1, 0.5), Vector2(-1, 0), Vector2(-1, -0.5), Vector2(0, -1), Vector2(1, -0.5)]  # CharacterSheet.Dir na tela


func _draw_unit(u: Combatant) -> void:
	drawing_key = u
	super(u)
	drawing_key = null


# Chamado pelo AnimSheet antes de desenhar a folha: se o personagem tem modelo 3D (Agente3D), o modelo faz a pose
# e a folha não é desenhada. A fase (quadro / total) mantém o mesmo tempo das animações do jogo.
func _modelos_3d() -> bool:
	return world3d != null


func _model3d(pasta: String, pos: Vector2, anim: String, fase: float, dir: CharacterSheet.Dir) -> bool:
	if world3d == null or drawing_key == null or not Agente3D.tem_modelo(pasta):
		return false
	var ag: Agente3D = agentes.get(drawing_key)
	if ag == null:
		ag = Agente3D.new(pasta)
		world3d.mundo.add_child(ag)
		agentes[drawing_key] = ag
	var g := _uniso(pos)
	ag.position = Vector3(g.x / 64.0, 0.0, g.y / 64.0)
	var frente := _uniso(pos + DIR_TELA[dir] * 32.0) - g
	var golpe: Dictionary = golpes.get(drawing_key, {})
	var continua := false  # fase do golpe já vem do relógio (contínua)
	if not golpe.is_empty():
		var t := (Time.get_ticks_msec() - int(golpe["inicio"])) / 1000.0
		var g3: Array = GOLPE_3D[golpe["anim"]]
		var dur: float = golpe["duracao"]
		var f: float = g3[0] * t / golpe["mira"] if t < golpe["mira"] else g3[0] + (t - golpe["mira"]) * g3[2] / dur
		var alvo: Combatant = golpe["alvo"]
		if f >= g3[1] or not (drawing_key as Combatant).is_alive():
			golpes.erase(drawing_key)  # terminou o arremate (ou caiu no meio): volta à pose do jogo
		else:
			anim = golpe["anim"]
			fase = f
			continua = true
			if alvo.pos != (drawing_key as Combatant).pos:
				frente = alvo.pos - (drawing_key as Combatant).pos  # mira exata no alvo, não nas 8 direções
	ag.virar(atan2(frente.x, frente.y))
	ag.pose(anim, fase, continua)
	if drawing_key is Combatant:
		ag.clarao(fx.white_alpha(drawing_key))
	agentes_usados[drawing_key] = true
	# Sombra de contato: reaproveita a mancha dos cartões (cartão escondido).
	if cards_used == cards.size():
		_new_card()
	cards[cards_used].visible = false
	blobs[cards_used].position = ag.position + Vector3(0.0, 0.02, 0.0)
	blobs[cards_used].visible = true
	cards_used += 1
	return true


# Golpes com modelo 3D (Léo, 08/11: combate dessincronizado). Antes a animação inteira era espremida na mira e o
# impacto vinha no último quadro, bem depois do tiro que se via. Agora a animação toca na velocidade dela, o impacto
# (dano, clarão, sangue) cai no quadro do disparo e o resto do movimento continua depois, até o fim do arremate.
# Animação -> [fase do disparo, fase em que o arremate termina, velocidade]. Fases medidas pelo movimento da mão
# direita nos clipes do Mixamo (pico de velocidade = golpe ou coice).
const GOLPE_3D := {
	"pistol_shoot": [0.6, 0.85, 1.5],
	"rifle_fire": [0.12, 0.45, 1.0],
	"punch": [0.27, 0.6, 1.0],
	"kick": [0.375, 0.7, 1.0],
	"attack": [0.5, 0.78, 1.33],  # Criatura de Sangue: o segundo golpe, o mais forte
}
var golpes := {}  # Combatant -> {"anim", "inicio" (ms), "mira" (s), "duracao" (s do clipe), "alvo"}


# Animação de golpe do atacante quando ele tem modelo 3D; "" quando não tem (fica a mira de antes).
func _golpe3d(attacker: Combatant) -> String:
	if world3d == null or not agentes.has(attacker):
		return ""
	if _has_creatures() and enemies.has(attacker):
		return "attack"
	if enemies.has(attacker):
		return ""
	return ATTACK_ANIM.get(str(attacker.weapon.get("id", "")), "")


func _attack_aim(attacker: Combatant) -> float:
	var anim := _golpe3d(attacker)
	if anim == "" or not (agentes[attacker] as Agente3D).player.has_animation(anim):
		return super(attacker)
	var g3: Array = GOLPE_3D[anim]
	return g3[0] * (agentes[attacker] as Agente3D).player.get_animation(anim).length / g3[2]


func _attack_started(attacker: Combatant, target: Combatant, aim: float) -> void:
	var anim := _golpe3d(attacker)
	if anim == "" or not (agentes[attacker] as Agente3D).player.has_animation(anim):
		return
	var g3: Array = GOLPE_3D[anim]
	var dur: float = (agentes[attacker] as Agente3D).player.get_animation(anim).length
	golpes[attacker] = {"anim": anim, "inicio": Time.get_ticks_msec(), "mira": aim, "duracao": dur, "alvo": target}


# Altura do peito dos modelos 3D em px do desenho (medida nas capturas: agente ~78, Criatura de Sangue ~100).
func _chest_px(u: Combatant) -> float:
	return 100.0 if _has_creatures() and enemies.has(u) else 78.0


func _flash_in_3d(u: Combatant) -> bool:
	return agentes_usados.has(u)


# Onde está a arma (mão direita do modelo) em coordenadas de desenho, para o clarão do tiro sair dela.
func _arma3d(u: Combatant) -> Vector2:
	var ag: Agente3D = agentes.get(u)
	if world3d == null or ag == null or not ag.visible:
		return Vector2.INF
	var mao := ag.boca_arma()
	var cam: Camera3D = world3d.camera
	if cam.is_position_behind(mao):
		return Vector2.INF
	var tela := cam.unproject_position(mao) * (get_viewport_rect().size / Vector2(world3d.mundo.size))
	return get_canvas_transform().affine_inverse() * tela


func _new_card() -> void:
	var card := MeshInstance3D.new()
	card.mesh = QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/3d/shaders/personagem_cartao.gdshader")
	card.material_override = m
	card.rotation.y = PI / 4.0  # de frente para a câmera
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.extra_cull_margin = 4.0
	world3d.mundo.add_child(card)
	cards.append(card)
	var blob := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	blob.mesh = plane
	blob.material_override = _blob_material()
	blob.rotation.y = PI / 4.0
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world3d.mundo.add_child(blob)
	blobs.append(blob)


var _blob_mat: StandardMaterial3D
# Sombra de contato: mancha suave sob os pés (o Compatibility não tem sombra de contato nem decal).
func _blob_material() -> StandardMaterial3D:
	if _blob_mat:
		return _blob_mat
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.5))
	_blob_mat = StandardMaterial3D.new()
	_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blob_mat.albedo_texture = ImageTexture.create_from_image(img)
	_blob_mat.disable_receive_shadows = true
	return _blob_mat


func _hide_unused_cards() -> void:
	for i in range(cards_used, cards.size()):
		cards[i].visible = false
		blobs[i].visible = false


# No 3D a sombra vem da mancha de contato embaixo do cartão; a elipse 2D ficaria por cima das árvores.
func _draw_cast_shadow(at: Vector2, height: float, radius: float) -> void:
	if world3d == null:
		super(at, height, radius)


# Objetivos do HUD: investigar o parque, depois o símbolo da árvore; em combate, sobreviver.
func _objectives() -> Array[Dictionary]:
	return Objectives.build(scenario.clues, seen_clues, mode == Mode.COMBAT)


# Caio tem a folha de parado em 3D; a Letícia ainda é figura provisória (corpo, cabeça e nome).
func _draw_npc(font: Font, npc_id: String) -> void:
	var at := _iso(scenario.npcs[npc_id])
	_draw_cast_shadow(at, 86.0, 22.0)
	if npc_id == "caio":
		drawing_key = npc_id
		caio3d.draw(self, at, caio3d.frame_at(Time.get_ticks_msec()), CharacterSheet.Dir.SE)
		drawing_key = null
		queue_redraw()  # a respiração anima
		return
	draw_rect(Rect2(at + Vector2(-11, -66), Vector2(22, 60)), NPC_COLORS[npc_id])
	draw_rect(Rect2(at + Vector2(-8, -86), Vector2(16, 18)), Color("#d6b292"))
	var name_text: String = NPC_NAMES[npc_id]
	var width := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, at + Vector2(-width * 0.5, -94), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.05, 0.03, 0.02))
	draw_string(font, at + Vector2(-width * 0.5, -94), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.93, 0.89, 0.8))


# Brilho dourado sobre as pistas que ainda não foram vistas, quando o controlado está perto.
# Cada pista ainda não vista e já liberada ganha uma bolinha acima do objeto; é nela que se clica.
func _dot_pos(cid: String) -> Vector2:
	var c: Dictionary = scenario.clues[cid]
	return _iso(c.pos) + c.bolinha


func _draw_clue_hints() -> void:
	var available := scenario.available_clues(seen_clues)
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 260.0)
	var hover := _clue_under(get_global_mouse_position()) if not dialog_layer.visible else ""
	for cid in scenario.clues:
		if seen_clues.has(cid):
			continue
		var at := _dot_pos(cid)
		var radius := DOT_RADIUS + (2.0 if cid == hover else 0.0)
		# A pista ainda bloqueada (a árvore, antes das outras) fica apagada: clicar só avisa.
		var locked := not available.has(cid)
		var tint := Color(0.84, 0.68, 0.36) if not locked else Color(0.66, 0.2, 0.2)
		var alpha := 1.0 if cid == hover else (pulse if not locked else 0.55)
		draw_circle(at, radius + 2.0, Color(0.05, 0.03, 0.02, 0.85))
		draw_circle(at, radius, Color(tint, alpha))
		if locked:
			continue
		if player.pos.distance_to(scenario.clues[cid].pos) <= CLUE_NEAR:
			draw_arc(at, radius + 5.0, 0.0, TAU, 24, Color(0.84, 0.68, 0.36, 0.5 * pulse), 1.0)
	queue_redraw()  # a bolinha pulsa


# --- Pistas ---------------------------------------------------------------------------------------

func _order_move(click: Vector2) -> void:
	if dialog_layer.visible:
		return
	pending_clue = ""
	var cid := _clue_under(get_global_mouse_position()) if mode == Mode.EXPLORATION else ""
	if cid != "":
		_go_to_clue(cid)
		return
	super(_nearest_free(click) if mode == Mode.EXPLORATION else click)


# Clique em cima de um obstáculo: em vez de ignorar, vai até o ponto livre mais próximo (contorna).
func _nearest_free(click: Vector2) -> Vector2:
	var obstacles := _obstacles(player)
	if pathfinder.find_path(player.pos, click, obstacles, player.radius).size() > 1:
		return click
	for ring in range(1, 26):
		var r := ring * 8.0
		var best := Vector2.INF
		var best_d := INF
		for k in 16:
			var spot := click + Vector2.from_angle(TAU * k / 16.0) * r
			if scenario.size.x < spot.x or scenario.size.y < spot.y or spot.x < 0.0 or spot.y < 0.0:
				continue
			var d := spot.distance_to(player.pos)
			if d < best_d and pathfinder.find_path(player.pos, spot, obstacles, player.radius).size() > 1:
				best = spot
				best_d = d
		if best != Vector2.INF:
			return best
	return click


# `mouse` está em px do desenho (get_global_mouse_position): vale o clique dentro da bolinha.
func _clue_under(mouse: Vector2) -> String:
	var best := ""
	var best_d := INF
	for cid in scenario.clues:
		if seen_clues.has(cid):
			continue
		var d := mouse.distance_to(_dot_pos(cid))
		if d <= DOT_HIT and d < best_d:
			best = cid
			best_d = d
	if best != "":
		return best
	# Objetos grandes (a árvore) também respondem ao clique no desenho todo: elipses [cx, cy, rx, ry]
	# em px do desenho, relativas ao pé da pista (Léo, 01/11/2026: clicar "bem na árvore").
	for cid in scenario.clues:
		if seen_clues.has(cid):
			continue
		var base := _iso(scenario.clues[cid].pos)
		for a in scenario.clues[cid].areas:
			var rel := mouse - (base + Vector2(float(a[0]), float(a[1])))
			if (rel.x * rel.x) / (float(a[2]) * float(a[2])) + (rel.y * rel.y) / (float(a[3]) * float(a[3])) <= 1.0:
				return cid
	return ""


# Já está perto: examina. Senão anda até o ponto livre mais próximo do objeto e examina ao chegar.
func _go_to_clue(cid: String) -> void:
	var c: Dictionary = scenario.clues[cid]
	if player.pos.distance_to(c.pos) <= c.raio:
		_inspect(cid)
		return
	var spots: Array[Vector2] = []
	for k in 16:
		spots.append(c.pos + Vector2.from_angle(TAU * k / 16.0) * c.raio * STAND_FACTOR)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(player.pos) < b.distance_to(player.pos))
	for spot in spots:
		var route := pathfinder.find_path(player.pos, spot, _obstacles(player), player.radius)
		if route.size() > 1:
			pending_clue = cid
			_reset_follow_offsets(spot - player.pos)
			_start_move(player, route)
			return


func _process(delta: float) -> void:
	super(delta)
	if mode != Mode.EXPLORATION:
		pending_clue = ""
	elif pending_clue != "" and path.is_empty() and moving_unit == null:
		var cid := pending_clue
		pending_clue = ""
		_inspect(cid)


func _inspect(cid: String) -> void:
	var c: Dictionary = scenario.clues[cid]
	if not scenario.available_clues(seen_clues).has(cid):
		_show_dialog("", "Ainda há o que olhar no parque antes disso.", "")
		return
	_show_dialog(c.inspecao, c.texto, cid)


func _show_dialog(image_path: String, text: String, cid: String) -> void:
	dialog_clue = cid
	dialog_text.text = text
	dialog_image.texture = load(image_path) if image_path != "" else null
	dialog_image.visible = image_path != ""
	dialog_layer.visible = true


# Fecha a caixa de texto. Se era uma pista nova, registra e dispara o que vem depois dela.
func _close_dialog() -> void:
	dialog_layer.visible = false
	var cid := dialog_clue
	dialog_clue = ""
	if cid == "" or seen_clues.has(cid):
		return
	seen_clues.append(cid)
	for trigger in scenario.triggers_after(cid):
		_run_trigger(trigger)
	queue_redraw()


func _run_trigger(trigger: Dictionary) -> void:
	if trigger["tipo"] != "combate":
		return
	for spec in trigger["inimigos"]:
		var p: Array = spec["pos"]
		enemies.append(cfg.make_enemy(spec["tipo"], Vector2(p[0], p[1])))
	_start_combat()


func _on_dialog_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_dialog()


# Caixa de texto embaixo e, para a inspeção, a imagem grande no centro da tela (decisão do Léo).
func _build_dialog() -> void:
	dialog_layer = CanvasLayer.new()
	dialog_layer.layer = 25
	dialog_layer.visible = false
	add_child(dialog_layer)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_dialog_input)
	dialog_layer.add_child(catcher)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.add_child(dim)
	dialog_image = TextureRect.new()
	dialog_image.position = Vector2(300, 28)
	dialog_image.size = Vector2(360, 360)
	dialog_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	dialog_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.add_child(dialog_image)
	var panel := PanelContainer.new()
	panel.position = Vector2(180, 410)
	panel.size = Vector2(600, 96)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_BG
	style.set_border_width_all(2)
	style.border_color = party_hud.FRAME_OUTER
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	dialog_text = Label.new()
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.add_theme_font_size_override("font_size", 16)
	dialog_text.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	panel.add_child(dialog_text)
	catcher.add_child(panel)
