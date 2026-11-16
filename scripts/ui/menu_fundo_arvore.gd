class_name MenuFundoArvore
extends Control
# Fundo do menu inicial: "A árvore velha" (cenário 3, escolhido pelo Léo em 13/11, por enquanto).
# Uma árvore torta sozinha numa colina contra um céu de fim de tarde vermelho escuro: galhos balançando,
# capim ondulando, folhas caindo, corvos, nuvens em faixas, névoa rasteira e um clarão de relâmpago raro.
# Tudo desenhado por código (porte do protótipo em arte/tela-inicial/cenarios_menu.html), sem imagens.
# O mouse dá uma parallax leve (`parallax`, de -0.5 a 0.5). Por cima, a sombra à esquerda (onde fica o menu),
# a vinheta e um grão de filme bem fraco.

const SKY := [Color("07040a"), Color("2a0c10"), Color("6a1e16"), Color("a2412a")]
const SKY_AT := [0.0, 0.45, 0.75, 1.0]
const HILL_FAR := Color("2a0d0e")
const SILHOUETTE := Color("070405")
const TREE_INK := Color("050304")
const LEAF := Color("120708")
const CROWS := 5
const LEAVES := 30
const GRASS := 220
const TREE_DEPTH := 8
const FLASH_MIN := 9.0  # segundos entre relâmpagos (mínimo; soma até 8 s de acaso)
const SHADE_ALPHA := 0.82  # sombra à esquerda, atrás do menu

var t := 0.0
var parallax := Vector2.ZERO  # alvo vindo do mouse
var _par := Vector2.ZERO  # parallax suavizada
var _rng := RandomNumberGenerator.new()
var _crows: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []
var _flash := 0.0
var _next_flash := 7.0
var _sky_tex: GradientTexture2D
var _glow_tex: GradientTexture2D
var _shade_tex: GradientTexture2D
var _vig_tex: GradientTexture2D
var _grain_tex: NoiseTexture2D
var _tree_rng := 0
var _ridge := PackedVector2Array()  # borda de cima da colina da árvore, para o capim
var animate := true  # falso nas capturas e testes que querem um quadro fixo


func _init() -> void:
	_rng.seed = 23
	for i in CROWS:
		_crows.append({"x": -_rng.randf() * 0.5, "y": 0.15 + _rng.randf() * 0.25, "v": 0.02 + _rng.randf() * 0.02, "p": _rng.randf() * 6.0, "s": 0.6 + _rng.randf() * 0.6})
	for i in LEAVES:
		_leaves.append({"x": 0.55 + _rng.randf() * 0.3, "y": _rng.randf(), "v": 0.02 + _rng.randf() * 0.03, "p": _rng.randf() * 6.0})


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sky_tex = _linear(SKY, SKY_AT, Vector2(0, 0), Vector2(0, 1))
	_glow_tex = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 1.0])
	_shade_tex = _linear([Color(0.016, 0.012, 0.012, SHADE_ALPHA), Color(0.016, 0.012, 0.012, 0.5), Color(0.016, 0.012, 0.012, 0.1), Color(0.016, 0.012, 0.012, 0.0)], [0.0, 0.26, 0.46, 0.58], Vector2(0, 0), Vector2(1, 0))
	_vig_tex = _radial([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.85)], [0.0, 0.45, 0.82, 1.0])
	_grain_tex = NoiseTexture2D.new()
	_grain_tex.width = 160
	_grain_tex.height = 160
	_grain_tex.seamless = true
	var noise := FastNoiseLite.new()
	noise.frequency = 0.9
	noise.fractal_octaves = 2
	_grain_tex.noise = noise


func _process(delta: float) -> void:
	if not animate:
		return
	t += delta
	_par += (parallax - _par) * minf(1.0, delta * 3.0)
	_step(delta)
	queue_redraw()


# Anda os corvos, as folhas e o relâmpago (separado do desenho para os testes).
func _step(delta: float) -> void:
	if t > _next_flash:
		_flash = 1.0
		_next_flash = t + FLASH_MIN + _rng.randf() * 8.0
	_flash *= pow(0.88, delta * 60.0)
	for l in _leaves:
		l["y"] += l["v"] * 0.6 * delta
		l["x"] -= (0.0006 + sin(t + l["p"]) * 0.0006) * delta * 60.0
		if l["y"] > 0.95:
			l["y"] = 0.2 + _rng.randf() * 0.2
			l["x"] = 0.6 + _rng.randf() * 0.25
	for c in _crows:
		c["x"] += c["v"] * delta
		if c["x"] > 1.2:
			c["x"] = -0.2
			c["y"] = 0.12 + _rng.randf() * 0.28


func _draw() -> void:
	var w := size.x
	var h := size.y
	var sx := _par.x
	var sy := _par.y
	draw_texture_rect(_sky_tex, Rect2(0, 0, w, h), false)
	_glow(Vector2(w * 0.7, h * 0.78), h * 0.7, Color(1.0, 0.47, 0.24, 0.25))
	# Nuvens em faixas, passando devagar.
	for i in 6:
		var x := fmod(t * (6.0 + i * 2.0) + i * 260.0 * w / 960.0, w * 1.6) - w * 0.3
		_ellipse(Vector2(x, h * (0.2 + i * 0.08)), Vector2(w * 0.3, h * 0.025), Color((20 + i * 8) / 255.0, 8 / 255.0, 10 / 255.0, 0.35))
	if _flash > 0.02:
		draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.78, 0.75, _flash * 0.25))
	# Colinas distantes.
	var far := PackedVector2Array([Vector2(0, h)])
	for k in 61:
		var x := w * k / 60.0
		far.append(Vector2(x, h * (0.78 - 0.04 * sin(x / w * 4.0 + 1.0) - sx * 0.01)))
	far.append(Vector2(w, h))
	draw_colored_polygon(far, HILL_FAR)
	# Colina com a árvore.
	var c := Vector2(w * 0.7 - sx * w * 0.025, h * 0.8 - sy * h * 0.01)
	var hill := PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.93)])
	hill.append_array(_quad(Vector2(0, h * 0.93), Vector2(w * 0.4, h * 0.9), Vector2(c.x - w * 0.1, c.y + h * 0.01)))
	hill.append_array(_quad(Vector2(c.x - w * 0.1, c.y + h * 0.01), Vector2(c.x, c.y - h * 0.035), Vector2(c.x + w * 0.12, c.y + h * 0.02)))
	hill.append_array(_quad(Vector2(c.x + w * 0.12, c.y + h * 0.02), Vector2(w * 0.9, h * 0.88), Vector2(w, h * 0.9)))
	hill.append(Vector2(w, h))
	draw_colored_polygon(hill, SILHOUETTE)
	_ridge = hill.slice(1, hill.size() - 1)
	_tree_rng = 31
	_branch(Vector2(c.x, c.y - h * 0.004), -PI / 2.0 - 0.1, h * 0.17, h * 0.036, 0)
	_grass(w, h, c)
	# Folhas caindo.
	for l in _leaves:
		var at := Vector2((l["x"] - sx * 0.02) * w, l["y"] * h)
		draw_set_transform(at, t * 2.0 + l["p"], Vector2.ONE)
		draw_rect(Rect2(-w * 0.002, -w * 0.001, w * 0.004, w * 0.002), LEAF)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Corvos.
	for cr in _crows:
		var x: float = cr["x"] * w
		var y: float = (cr["y"] + sin(t + cr["p"]) * 0.01) * h
		var s: float = w * 0.009 * cr["s"]
		var f: float = sin(t * 9.0 + cr["p"]) * s * 0.6
		var pts := _quad(Vector2(x - s, y - f), Vector2(x - s * 0.4, y - f * 0.3), Vector2(x, y), 5)
		pts.append_array(_quad(Vector2(x, y), Vector2(x + s * 0.4, y - f * 0.3), Vector2(x + s, y - f), 5))
		draw_polyline(pts, TREE_INK, maxf(1.0, w * 0.0018), true)
	# Névoa rasteira.
	for i in 4:
		var x := fmod(t * (10.0 + i * 6.0) + i * 420.0 * w / 960.0, w * 1.8) - w * 0.4
		_glow(Vector2(x, h * (0.86 + i * 0.03)), w * 0.3, Color(0.78, 0.47, 0.43, 0.14), Vector2(1.0, 0.5))
	# Sombra à esquerda para o menu ler, vinheta e grão.
	draw_texture_rect(_shade_tex, Rect2(0, 0, w, h), false)
	draw_texture_rect(_vig_tex, Rect2(-w * 0.1, -h * 0.25, w * 1.4, h * 1.5), false)
	if _grain_tex.get_image() != null:
		var off := Vector2(fmod(floor(t * 4.0) * 37.0, 160.0), fmod(floor(t * 4.0) * 71.0, 160.0))
		draw_texture_rect(_grain_tex, Rect2(-off, size + Vector2(160, 160)), true, Color(1, 1, 1, 0.05))


# Galho recursivo: balança com o tempo, cada nível um pouco mais.
func _branch(p: Vector2, a: float, l: float, width: float, d: int) -> void:
	if d > TREE_DEPTH:
		return
	var sway := sin(t * 0.9 + d * 0.7) * 0.025 * d + sin(t * 2.3 + p.x * 0.01) * 0.006 * d
	var aa := a + sway
	var p2 := p + Vector2(cos(aa), sin(aa)) * l
	var mid := (p + p2) / 2.0 + Vector2(sin(float(d)) * l * 0.08, 0)
	draw_polyline(_quad(p, mid, p2, 4 if d < 4 else 2), TREE_INK, maxf(width, 0.6), true)
	if width > 1.5:  # junta arredondada, para o galho não quebrar em degrau
		draw_circle(p2, width * 0.5, TREE_INK)
	var n := 3 if d < 2 else 2
	for i in n:
		var da := (i - (n - 1) / 2.0) * (0.48 + _tr() * 0.4) + (_tr() - 0.5) * 0.35
		_branch(p2, aa + da, l * (0.66 + _tr() * 0.14), width * 0.64, d + 1)


# Mesmo gerador do protótipo (Park-Miller), para a árvore ter sempre a mesma forma.
func _tr() -> float:
	_tree_rng = (_tree_rng * 16807) % 2147483647
	return _tree_rng / 2147483647.0


func _grass(w: float, h: float, _c: Vector2) -> void:
	var lines := PackedVector2Array()
	for i in GRASS:
		var k := float(i) / GRASS
		var x := k * w
		var yb := _ridge_y(x) + h * 0.006  # o capim nasce na própria linha da colina
		var gh := h * (0.012 + ((i * 13) % 7) * 0.004)
		var sw := sin(t * 1.6 + i * 0.3) * gh * 0.4
		var m := Vector2(x + sw * 0.5, yb - gh * 0.6)
		lines.append_array([Vector2(x, yb), m, m, Vector2(x + sw, yb - gh)])
	draw_multiline(lines, SILHOUETTE, 0.8, true)


# Altura da colina da árvore no x dado (interpolando a borda de cima do polígono).
func _ridge_y(x: float) -> float:
	for i in range(1, _ridge.size()):
		var a: Vector2 = _ridge[i - 1]
		var b: Vector2 = _ridge[i]
		if x <= b.x and b.x > a.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))
	return _ridge[-1].y if not _ridge.is_empty() else size.y * 0.9


func _glow(center: Vector2, radius: float, color: Color, squash := Vector2.ONE) -> void:
	var r := Vector2(radius, radius) * squash
	draw_texture_rect(_glow_tex, Rect2(center - r, r * 2.0), false, color)


func _ellipse(center: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var ang := TAU * k / 24.0
		pts.append(center + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	draw_colored_polygon(pts, color)


static func _quad(a: Vector2, ctrl: Vector2, b: Vector2, steps := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var k := float(i) / steps
		out.append(a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k))
	return out


static func _linear(colors: Array, offsets: Array, from: Vector2, to: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill_from = from
	tex.fill_to = to
	return tex


static func _radial(colors: Array, offsets: Array) -> GradientTexture2D:
	var tex := _linear(colors, offsets, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	tex.fill = GradientTexture2D.FILL_RADIAL
	return tex
