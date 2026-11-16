class_name SanFx
extends Node2D
# Aviso de SAN na tela (Léo, 15/11/2026: modelo C "Delírio" com o B "Pulso", sem o visor do batimento).
#   B: no susto as bordas escurecem em azul por ~1,2 s; em ruptura a borda fica pulsando devagar.
#   C: no susto a imagem treme e separa as cores por ~0,5 s; em ruptura, cópia fantasma de quem rompeu,
#      frases vermelhas no chão perto dele (desenhadas pela sala) e falas sozinho; loucura = vermelho, depois cinza.
# Fica atrás do desenho da sala (como o HudBlur): o shader mexe só no mundo 3D, o HUD continua legível.
# Durações e forças são PROVISÓRIAS do Claude.

const SHADER := preload("res://assets/shaders/san_fx.gdshader")
const SCARE_SECONDS := 1.2
const SHAKE_SECONDS := 0.5
const MADNESS_RED_SECONDS := 0.6
const MADNESS_GRAY_SECONDS := 2.4
const TALK_EVERY := Vector2(7.0, 11.0)  # intervalo (s) entre falas sozinho em ruptura
const FALAS := ["Isso não é real...", "Ela está aqui.", "Eu ouvi. Vocês ouviram?", "Não olha pra ela.", "Para. Para. Para.", "Tem sangue nas minhas mãos?"]
const FRASES_CHAO := ["não olhe", "ela está aqui", "você deixou ele morrer", "volta pra casa", "ninguém sai", "está sangrando"]

var room: TestRoom
var white: ImageTexture
var scare_t := 99.0  # segundos desde o último susto
var scare_power := 1.0
var madness_t := 99.0
var talk_in := 8.0
var rng := RandomNumberGenerator.new()


func _init(owner_room: TestRoom) -> void:
	room = owner_room
	show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white = ImageTexture.create_from_image(img)


# Perdeu SAN: borda escura e tremor. `strong` (ruptura) dura e treme mais.
func scare(strong := false) -> void:
	scare_t = 0.0
	scare_power = 1.6 if strong else 1.0


func madness() -> void:
	madness_t = 0.0
	scare(true)


# Quem está em ruptura (vivo), o líder primeiro.
func ruptured() -> Array:
	var out: Array = []
	if room.player and room.player.ruptured and room.player.is_alive():
		out.append(room.player)
	for m in room.party:
		if m != room.player and m.ruptured and m.is_alive() and not m.dead:
			out.append(m)
	return out


func active() -> bool:
	return scare_t < SCARE_SECONDS * scare_power or madness_t < MADNESS_RED_SECONDS + MADNESS_GRAY_SECONDS or not ruptured().is_empty()


func _process(delta: float) -> void:
	scare_t += delta
	madness_t += delta
	var broken := ruptured()
	if not broken.is_empty():
		talk_in -= delta
		if talk_in <= 0.0:
			talk_in = rng.randf_range(TALK_EVERY.x, TALK_EVERY.y)
			var who: Combatant = broken[rng.randi() % broken.size()]
			room._popup(who.pos, "\"%s\"" % FALAS[rng.randi() % FALAS.size()], "fala")
			room.popups[-1]["time"] = 3.0
			room.popups[-1]["dur"] = 3.0
	_update_uniforms(broken)
	queue_redraw()


# Valores do shader para este instante (também usados pelo teste).
func params(broken: Array) -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var p := {"aberr": 0.0, "shake": Vector2.ZERO, "vignette": 0.0, "red": 0.0, "gray": 0.0, "ghost": 0.0}
	var s := clampf(1.0 - scare_t / (SCARE_SECONDS * scare_power), 0.0, 1.0)
	p.vignette = s * s * 0.95
	var k := clampf(1.0 - scare_t / (SHAKE_SECONDS * scare_power), 0.0, 1.0)
	p.aberr = 0.006 * k * scare_power
	p.shake = Vector2(sin(now * 61.0), cos(now * 47.0)) * 0.004 * k * scare_power
	if not broken.is_empty():
		p.vignette = maxf(p.vignette, 0.6 + 0.25 * sin(now * 2.2))
		p.aberr = maxf(p.aberr, 0.0015)
		p.ghost = 0.75 + 0.25 * sin(now * 3.1)
	if madness_t < MADNESS_RED_SECONDS:
		p.red = 0.75 * (1.0 - madness_t / MADNESS_RED_SECONDS)
	if madness_t < MADNESS_RED_SECONDS + MADNESS_GRAY_SECONDS:
		p.gray = clampf((madness_t) / MADNESS_RED_SECONDS, 0.0, 1.0) * clampf(1.0 - (madness_t - MADNESS_RED_SECONDS) / MADNESS_GRAY_SECONDS, 0.0, 1.0) * 0.9
	return p


func _update_uniforms(broken: Array) -> void:
	var p := params(broken)
	var m: ShaderMaterial = material
	for key in p:
		m.set_shader_parameter(key, p[key])
	if not broken.is_empty():
		var size := room.get_viewport_rect().size
		var u: Combatant = broken[0]
		var screen := room.get_canvas_transform() * (room._iso(u.pos) + Vector2(0, -CharacterSheet.HEIGHT * 0.5))
		m.set_shader_parameter("ghost_uv", screen / size)
		var zoom := room.get_canvas_transform().get_scale().x
		m.set_shader_parameter("ghost_size", Vector2(70.0, 130.0) * zoom / size)


func _draw() -> void:
	if not active():
		return
	var inv := room.get_canvas_transform().affine_inverse()
	draw_texture_rect(white, Rect2(inv * Vector2.ZERO, inv.basis_xform(room.get_viewport_rect().size)), false)
