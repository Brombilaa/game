class_name MainMenu
extends Control
# Menu inicial, modelo "Vela e pincel" com menu lateral (escolha do Léo, 30/10/2026).
# Abertura de ~4,6 s: o símbolo é pintado traço por traço, as letras do nome surgem uma a uma
# e o menu aparece; clique ou tecla pula a abertura. Depois o nome pulsa em vermelho e a luz de
# vela treme atrás do símbolo. Tudo é desenhado por código (sem imagens), na tela de 960×540.
# Carregar lista os 3 slots manuais do SaveSlots. A sala de teste ainda não lê saves, então
# carregar um slot só guarda qual foi escolhido (`pending_slot`) e abre a sala.

const GAME_SCENE := "res://scenes/exploration/test_room.tscn"
const TITLE := "PACTO CARMESIM"
const ITEMS := [["new", "Novo jogo"], ["load", "Carregar"], ["opts", "Opções"], ["quit", "Sair do jogo"]]
const OPTION_ROWS := [["master", "Volume geral"], ["music", "Música"], ["sfx", "Efeitos"], ["fullscreen", "Tela cheia"]]
const ROMAN := ["I", "II", "III"]
const AREA_NAMES := {"test_room": "Sala de teste"}

# Tempos da abertura, em segundos.
const DRAW_SECONDS := 2.4  # cada traço do símbolo
const LETTER_START := 2.2
const LETTER_STEP := 0.09
const LETTER_FADE := 0.9
const MENU_START := 3.6
const MENU_FADE := 1.0
const GLOW_START := 4.5
const GLOW_PERIOD := 4.0
const INTRO_END := 4.6
const BRUSH_SECONDS := 0.3  # pincelada atrás da opção em foco
const PANEL_FADE_SECONDS := 0.3

const BG := Color("080605")
const INK := Color("f3e6cc")
const MENU_INK := Color("d9ccb2")
const MENU_INK_ON := Color("fff6e4")
const GOLD := Color("d4aa50")
const MUTED := Color("a8977c")
const LINE := Color("4a3a28")
const BLOOD := Color("aa2424")
const BLOOD_LIGHT := Color("e04040")
const BLOOD_DARK := Color("5e0c0c")
const PANEL_BG := Color(0.07, 0.05, 0.035, 0.96)

const TITLE_SIZE := 44
const MENU_SIZE := 22
const MENU_GAP := 40.0

static var pending_slot := ""

var t := 0.0
var focus := 0  # opção do menu em foco
var focus_time := 0.0
var panel := ""  # "", "load" ou "opts"
var panel_focus := 0  # linha em foco no painel; a última é o "Fechar"
var panel_fade := 0.0
var save_dir := SaveSlots.DIR
var slots: Array[Dictionary] = []
var options_path := GameOptions.PATH
var options := GameOptions.load_from()
var strokes := sigil_strokes()
var blots := sigil_blots()
var light_tex := _radial([Color(0.6, 0.24, 0.12, 0.34), Color(0.6, 0.24, 0.12, 0.0)], [0.0, 1.0])
var vignette_tex := _radial([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.82)], [0.0, 0.5, 1.0])


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	RenderingServer.set_default_clear_color(BG)
	options.apply()
	GameCursor.apply(GameCursor.Kind.ARROW)


func _process(delta: float) -> void:
	t += delta
	focus_time += delta
	panel_fade = move_toward(panel_fade, 1.0 if panel != "" else 0.0, delta / PANEL_FADE_SECONDS)
	queue_redraw()


# --- Abertura ---------------------------------------------------------------

func intro_done() -> bool:
	return t >= INTRO_END


func skip_intro() -> void:
	t = maxf(t, INTRO_END)


static func stroke_progress(time: float, delay: float) -> float:
	var x := clampf((time - delay) / DRAW_SECONDS, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func letter_alpha(time: float, index: int) -> float:
	return clampf((time - LETTER_START - index * LETTER_STEP) / LETTER_FADE, 0.0, 1.0)


static func menu_alpha(time: float) -> float:
	return clampf((time - MENU_START) / MENU_FADE, 0.0, 1.0)


# Trecho inicial da linha, do começo até a fração `p` do comprimento total.
static func partial(points: PackedVector2Array, p: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2 or p <= 0.0:
		return out
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var left := total * minf(p, 1.0)
	out.append(points[0])
	for i in range(1, points.size()):
		var seg := points[i - 1].distance_to(points[i])
		if seg >= left:
			out.append(points[i - 1].lerp(points[i], left / seg if seg > 0.0 else 1.0))
			return out
		left -= seg
		out.append(points[i])
	return out


# --- Símbolo (coordenadas de -100 a 100) ----------------------------------------

# Cada traço: {"points", "width", "delay"}. Ordem = ordem em que o pincel pinta.
static func sigil_strokes() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	# Anel externo, uma volta e pouco, levemente torto como pintado à mão.
	var ring := PackedVector2Array()
	for i in 53:
		var a := deg_to_rad(-92.0 + i * 7.0)
		var r := 85.0 + 2.0 * sin(a * 3.0) + 1.5 * sin(a * 7.0 + 1.0)
		ring.append(Vector2(cos(a), sin(a)) * r)
	list.append({"points": ring, "width": 7.0, "delay": 0.0})
	list.append({"points": _arc(72.0, 155.0, 205.0), "width": 2.2, "delay": 0.5})
	list.append({"points": _arc(72.0, -25.0, 25.0), "width": 2.2, "delay": 0.5})
	list.append({"points": PackedVector2Array([Vector2(-58, -34), Vector2(60, -36), Vector2(1, 66), Vector2(-58, -34)]), "width": 6.0, "delay": 0.9})
	list.append({"points": PackedVector2Array([Vector2(0, -100), Vector2(1, 98)]), "width": 4.5, "delay": 1.4})
	var eye := _quad(Vector2(-32, -6), Vector2(0, -26), Vector2(32, -6))
	eye.append_array(_quad(Vector2(32, -6), Vector2(0, 14), Vector2(-32, -6)))
	list.append({"points": eye, "width": 4.0, "delay": 1.7})
	list.append({"points": PackedVector2Array([Vector2(-26, 40), Vector2(26, 38)]), "width": 4.0, "delay": 1.9})
	list.append({"points": PackedVector2Array([Vector2(-14, 52), Vector2(14, 51)]), "width": 4.0, "delay": 1.95})
	var runes := [
		[Vector2(-6, -96), Vector2(0, -88), Vector2(6, -96)],
		[Vector2(88, -30), Vector2(96, -24)], [Vector2(92, -34), Vector2(92, -20)],
		[Vector2(60, 74), Vector2(70, 70), Vector2(68, 80)],
		[Vector2(-66, 72), Vector2(-74, 66)], [Vector2(-72, 76), Vector2(-64, 64)],
		[Vector2(-94, -24), Vector2(-86, -20), Vector2(-94, -16)],
		[Vector2(-40, -90), Vector2(-36, -80)], [Vector2(-30, -92), Vector2(-34, -82)],
		[Vector2(42, -88), Vector2(50, -80)], [Vector2(50, -88), Vector2(42, -80)],
	]
	for i in runes.size():
		list.append({"points": PackedVector2Array(runes[i]), "width": 2.6, "delay": 1.2 + i * 0.05})
	return list


# Manchas de tinta: Vector3(x, y, raio) e o instante em que caem.
static func sigil_blots() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for b in [[0, -6, 7, 2.1], [-58, -34, 4.5, 2.2], [60, -36, 4, 2.25], [1, 66, 5, 2.3], [38, -58, 2.2, 2.35], [-46, 30, 1.8, 2.4], [70, 56, 2.6, 2.4]]:
		list.append({"at": Vector2(b[0], b[1]), "radius": float(b[2]), "delay": float(b[3])})
	return list


static func _arc(radius: float, from_deg: float, to_deg: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 9:
		var a := deg_to_rad(lerpf(from_deg, to_deg, i / 8.0))
		out.append(Vector2(cos(a), sin(a)) * radius)
	return out


static func _quad(a: Vector2, c: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		out.append(a.lerp(c, k).lerp(c.lerp(b, k), k))
	return out


# --- Carregar ---------------------------------------------------------------

func refresh_slots() -> void:
	slots.clear()
	for entry in SaveSlots.list(save_dir):
		if entry["slot"] != SaveSlots.AUTO:
			slots.append(entry)


static func area_label(area: String) -> String:
	if area.is_empty():
		return "Local desconhecido"
	return AREA_NAMES.get(area, area.capitalize())


static func date_label(unix: int) -> String:
	if unix <= 0:
		return ""
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "Salvo em %02d/%02d às %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]


# --- Ações --------------------------------------------------------------------

func activate(item: String) -> void:
	match item:
		"new":
			pending_slot = ""
			get_tree().change_scene_to_file(GAME_SCENE)
		"load":
			refresh_slots()
			_open("load")
		"opts":
			_open("opts")
		"quit":
			get_tree().quit()


func close_panel() -> void:
	if panel == "opts":
		options.save(options_path)
	panel = ""


func load_slot(index: int) -> bool:
	if index < 0 or index >= slots.size() or slots[index]["empty"]:
		return false
	pending_slot = slots[index]["slot"]
	get_tree().change_scene_to_file(GAME_SCENE)
	return true


func _open(which: String) -> void:
	panel = which
	panel_focus = 0


func _panel_rows() -> int:
	return (slots.size() if panel == "load" else OPTION_ROWS.size()) + 1


func _change_option(row: int, step: float) -> void:
	var key: String = OPTION_ROWS[row][0]
	if key == "fullscreen":
		options.values["fullscreen"] = not options.values["fullscreen"]
	else:
		options.set_volume(key, options.volume(key) + step)
	options.apply()


func _accept_panel_row(row: int) -> void:
	if row == _panel_rows() - 1:
		close_panel()
	elif panel == "load":
		load_slot(row)
	elif OPTION_ROWS[row][0] == "fullscreen":
		_change_option(row, 0.0)


# --- Entrada --------------------------------------------------------------------

func _set_focus(i: int) -> void:
	if i != focus:
		focus = i
		focus_time = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _hit(event.position)
		if hit.x == 0:
			_set_focus(hit.y)
		elif hit.x == 1:
			panel_focus = hit.y
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not intro_done():
			skip_intro()
			return
		var hit := _hit(event.position)
		if hit.x == 0:
			activate(ITEMS[hit.y][0])
		elif hit.x == 1:
			panel_focus = hit.y
			if panel == "opts" and hit.y < OPTION_ROWS.size() and OPTION_ROWS[hit.y][0] != "fullscreen":
				var bar := _option_bar(hit.y)
				var key: String = OPTION_ROWS[hit.y][0]
				options.set_volume(key, (event.position.x - bar.position.x) / bar.size.x)
				options.apply()
			else:
				_accept_panel_row(hit.y)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() and not (event.is_action("ui_left") or event.is_action("ui_right")):
		return
	if not intro_done():
		if event is InputEventKey:
			skip_intro()
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if panel == "":
		if event.is_action("ui_up"):
			_set_focus(posmod(focus - 1, ITEMS.size()))
		elif event.is_action("ui_down"):
			_set_focus(posmod(focus + 1, ITEMS.size()))
		elif event.is_action("ui_accept"):
			activate(ITEMS[focus][0])
		else:
			handled = false
	else:
		if event.is_action("ui_cancel"):
			close_panel()
		elif event.is_action("ui_up"):
			panel_focus = posmod(panel_focus - 1, _panel_rows())
		elif event.is_action("ui_down"):
			panel_focus = posmod(panel_focus + 1, _panel_rows())
		elif event.is_action("ui_accept"):
			_accept_panel_row(panel_focus)
		elif panel == "opts" and panel_focus < OPTION_ROWS.size() and (event.is_action("ui_left") or event.is_action("ui_right")):
			_change_option(panel_focus, 0.1 if event.is_action("ui_right") else -0.1)
		else:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


# Vector2i(0, i) = opção i do menu; (1, i) = linha i do painel; (-1, -1) = nada.
func _hit(p: Vector2) -> Vector2i:
	if panel != "":
		for i in _panel_rows():
			if _panel_row_rect(i).has_point(p):
				return Vector2i(1, i)
		return Vector2i(-1, -1)
	for i in ITEMS.size():
		if _item_rect(i).has_point(p):
			return Vector2i(0, i)
	return Vector2i(-1, -1)


# --- Layout ---------------------------------------------------------------------

func _menu_x() -> float:
	return size.x * 0.05


func _item_y(i: int) -> float:
	return size.y * 0.5 + (i - (ITEMS.size() - 1) / 2.0) * MENU_GAP


func _item_rect(i: int) -> Rect2:
	return Rect2(_menu_x() + 8, _item_y(i) - MENU_GAP / 2.0, size.x * 0.25, MENU_GAP)


func _sigil_center() -> Vector2:
	return Vector2(size.x * 0.64, size.y * 0.46)


func _sigil_scale() -> float:
	return size.x * 0.40 / 220.0


func _panel_rect() -> Rect2:
	var h := 262.0 if panel == "load" else 230.0
	var x := size.x * 0.33
	return Rect2(x, (size.y - h) / 2.0, size.x * 0.96 - x, h)


func _panel_row_rect(i: int) -> Rect2:
	var r := _panel_rect()
	if i == _panel_rows() - 1:
		return Rect2(r.get_center().x - 50, r.end.y - 34, 100, 26)
	var row_h := 50.0 if panel == "load" else 34.0
	return Rect2(r.position.x + 24, r.position.y + 46 + i * (row_h + 8), r.size.x - 48, row_h)


func _option_bar(i: int) -> Rect2:
	var row := _panel_row_rect(i)
	return Rect2(row.position.x + row.size.x * 0.42, row.get_center().y - 3, row.size.x * 0.42, 6)


# --- Desenho --------------------------------------------------------------------

func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var center := _sigil_center()
	var flicker := 0.86 + 0.08 * sin(t * 7.3) + 0.06 * sin(t * 13.1 + 1.7)
	var light_size := Vector2(size.x * 0.9, size.y * 1.3)
	draw_texture_rect(light_tex, Rect2(center - light_size / 2.0, light_size), false, Color(1, 1, 1, flicker))
	_draw_sigil(center, _sigil_scale(), 1.0 - 0.6 * panel_fade)
	draw_texture_rect(vignette_tex, Rect2(Vector2.ZERO, size), false)
	_draw_title(font, center, 1.0 - panel_fade)
	_draw_menu(font, menu_alpha(t))
	if panel != "":
		_draw_panel(font, panel_fade)
	draw_string(font, Vector2(size.x - 34, size.y - 10), "v0.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.43, 0.36, 0.27))


func _draw_sigil(center: Vector2, k: float, alpha: float) -> void:
	for s in strokes:
		var p := stroke_progress(t, s["delay"])
		var pts := partial(s["points"], p)
		if pts.size() < 2:
			continue
		var screen := PackedVector2Array()
		for v in pts:
			screen.append(center + v * k)
		_brush(screen, float(s["width"]) * k, alpha)
	for b in blots:
		var a := clampf((t - float(b["delay"])) / 0.6, 0.0, 1.0)
		if a > 0.0:
			var r: float = b["radius"] * k * (0.4 + 0.6 * a)
			draw_circle(center + b["at"] * k, r * 1.15, Color(BLOOD_DARK, 0.9 * a * alpha))
			draw_circle(center + b["at"] * k, r, Color(BLOOD, a * alpha))


# Pincelada: borda escura, corpo vermelho e dois fios mais claro/escuro deslocados (falhas do pincel).
func _brush(pts: PackedVector2Array, w: float, alpha: float) -> void:
	draw_polyline(pts, Color(BLOOD_DARK, 0.9 * alpha), w * 1.25, true)
	draw_polyline(pts, Color(BLOOD, alpha), w, true)
	draw_polyline(_offset(pts, w * 0.22), Color(BLOOD_LIGHT, 0.35 * alpha), maxf(w * 0.22, 1.0), true)
	draw_polyline(_offset(pts, -w * 0.3), Color(BLOOD_DARK, 0.55 * alpha), maxf(w * 0.18, 1.0), true)
	draw_circle(pts[0], w * 0.55, Color(BLOOD, alpha))
	draw_circle(pts[pts.size() - 1], w * 0.5, Color(BLOOD, alpha))


static func _offset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var n := (b - a).orthogonal().normalized()
		out.append(pts[i] + n * d)
	return out


func _letters_width(font: Font, text: String, font_size: int, spacing: float) -> float:
	var w := 0.0
	for ch in text:
		w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing
	return w - spacing


func _draw_title(font: Font, center: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var spacing := TITLE_SIZE * 0.12
	var width := _letters_width(font, TITLE, TITLE_SIZE, spacing)
	var x := minf(center.x - width / 2.0, size.x - 16 - width)
	var base := center.y + TITLE_SIZE * 0.3
	var glow := 0.0
	if t > GLOW_START:
		glow = 0.5 - 0.5 * cos((t - GLOW_START) * TAU / GLOW_PERIOD)
	for i in TITLE.length():
		var ch := TITLE[i]
		var a := letter_alpha(t, i) * alpha
		if a > 0.0 and ch != " ":
			var pos := Vector2(x, base)
			# Saindo do desfoque: cópias espalhadas que se juntam conforme a letra aparece.
			var spread := (1.0 - a) * 6.0
			if spread > 0.1:
				for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
					draw_char(font, pos + o * spread, ch, TITLE_SIZE, Color(INK, a * 0.25))
			# Brilho vermelho que respira.
			var halo := Color(BLOOD_LIGHT, (0.22 + 0.3 * glow) * a)
			for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-3, -3), Vector2(3, 3), Vector2(3, -3), Vector2(-3, 3)]:
				draw_char(font, pos + o * (0.6 + 0.6 * glow), ch, TITLE_SIZE, halo)
			draw_char(font, pos + Vector2(0, 2), ch, TITLE_SIZE, Color(0, 0, 0, 0.7 * a))
			draw_char(font, pos, ch, TITLE_SIZE, Color(INK, a))
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x + spacing
	# Ornamento dourado abaixo do nome.
	var oa := menu_alpha(t) * alpha
	if oa > 0.0:
		var y := base + 22
		var cx := center.x
		for side in [-1.0, 1.0]:
			for j in 12:
				var x0: float = cx + side * (10.0 + j * 8.0)
				draw_line(Vector2(x0, y), Vector2(x0 + side * 8.0, y), Color(GOLD, oa * (1.0 - j / 12.0)), 1.0)
		_diamond(Vector2(cx, y), 4.0, Color(GOLD, oa), false)


func _diamond(c: Vector2, r: float, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		draw_polyline(pts, color, 1.0)


func _draw_menu(font: Font, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var lx := _menu_x()
	var top := _item_y(0) - MENU_GAP * 0.75
	var bottom := _item_y(ITEMS.size() - 1) + MENU_GAP * 0.75
	draw_line(Vector2(lx, top), Vector2(lx, bottom), Color(GOLD, 0.45 * alpha), 1.0)
	_diamond(Vector2(lx, top - 4), 4.0, Color(GOLD, alpha), true)
	_diamond(Vector2(lx, bottom + 4), 4.0, Color(GOLD, alpha), true)
	for i in ITEMS.size():
		var y := _item_y(i)
		var label: String = ITEMS[i][1]
		var tx := lx + 16
		var on: bool = i == focus and (panel == "" or ITEMS[i][0] == panel)
		if on:
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, MENU_SIZE).x
			var grow := clampf(focus_time / BRUSH_SECONDS, 0.0, 1.0) if panel == "" else 1.0
			_brush_mark(Vector2(tx - 8, y), (w + 24) * (1.0 - pow(1.0 - grow, 3.0)), Color(BLOOD, 0.95 * alpha))
			_diamond(Vector2(lx, y), 4.0, Color(BLOOD_LIGHT, alpha), true)
		draw_string(font, Vector2(tx, y + MENU_SIZE * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, MENU_SIZE, Color(MENU_INK_ON if on else MENU_INK, alpha))


# Pincelada horizontal irregular atrás da opção em foco.
func _brush_mark(left_mid: Vector2, width: float, color: Color) -> void:
	if width < 4.0:
		return
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		var x := left_mid.x + width * k
		top.append(Vector2(x, left_mid.y - 7.0 + 2.5 * sin(k * 7.0) - 2.0 * k))
		bottom.append(Vector2(x, left_mid.y + 9.0 + 2.0 * sin(k * 5.0 + 2.0) - 3.0 * sin(k * PI)))
	bottom.reverse()
	top.append_array(bottom)
	draw_colored_polygon(top, color)


func _draw_panel(font: Font, alpha: float) -> void:
	var r := _panel_rect()
	draw_rect(r.grow(5), Color(PANEL_BG, alpha))
	draw_rect(r.grow(5), Color(GOLD, 0.22 * alpha), false, 1.0)
	draw_rect(r, Color(GOLD, 0.55 * alpha), false, 1.0)
	var c := 12.0
	for corner in [[r.position + Vector2(-8, -8), Vector2(1, 1)], [r.end + Vector2(8, 8), Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(p, p + Vector2(c * d.x, 0), Color(GOLD, alpha), 2.0)
		draw_line(p, p + Vector2(0, c * d.y), Color(GOLD, alpha), 2.0)
	var heading := "CARREGAR" if panel == "load" else "OPÇÕES"
	var spacing := 5.0
	var hw := _letters_width(font, heading, 14, spacing)
	var hx := r.get_center().x - hw / 2.0
	for ch in heading:
		draw_char(font, Vector2(hx, r.position.y + 28), ch, 14, Color(GOLD, alpha))
		hx += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + spacing
	if panel == "load":
		_draw_slots(font, alpha)
	else:
		_draw_options(font, alpha)
	var close := _panel_row_rect(_panel_rows() - 1)
	var close_on := panel_focus == _panel_rows() - 1
	draw_string(font, Vector2(close.position.x, close.get_center().y + 5), "Fechar", HORIZONTAL_ALIGNMENT_CENTER, close.size.x, 14, Color(GOLD if close_on else MENU_INK, alpha))


func _draw_slots(font: Font, alpha: float) -> void:
	for i in slots.size():
		var row := _panel_row_rect(i)
		var entry: Dictionary = slots[i]
		var empty: bool = entry["empty"]
		var on := i == panel_focus and not empty
		var a := alpha * (0.5 if empty else 1.0)
		draw_rect(row, Color(0.35, 0.05, 0.05, 0.35 * alpha) if on else Color(0, 0, 0, 0.35 * alpha))
		draw_rect(row, Color(BLOOD_LIGHT if on else LINE, a), false, 1.0)
		draw_string(font, Vector2(row.position.x + 14, row.get_center().y + 9), ROMAN[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(GOLD, a))
		var tx := row.position.x + 64
		if empty:
			draw_string(font, Vector2(tx, row.get_center().y + 5), "Vazio", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MENU_INK, a))
		else:
			draw_string(font, Vector2(tx, row.position.y + 21), area_label(entry["area"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MENU_INK_ON, a))
			draw_string(font, Vector2(tx, row.position.y + 39), date_label(entry["saved_at"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(MUTED, a))


func _draw_options(font: Font, alpha: float) -> void:
	for i in OPTION_ROWS.size():
		var row := _panel_row_rect(i)
		var key: String = OPTION_ROWS[i][0]
		var on := i == panel_focus
		draw_string(font, Vector2(row.position.x + 8, row.get_center().y + 6), OPTION_ROWS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(MENU_INK_ON if on else MENU_INK, alpha))
		if on:
			_diamond(Vector2(row.position.x - 6, row.get_center().y), 3.0, Color(BLOOD_LIGHT, alpha), true)
		var bar := _option_bar(i)
		if key == "fullscreen":
			var box := Rect2(bar.position.x, row.get_center().y - 7, 14, 14)
			draw_rect(box, Color(GOLD, alpha), false, 1.0)
			if options.values["fullscreen"]:
				draw_rect(box.grow(-3), Color(BLOOD_LIGHT, alpha))
		else:
			var v := options.volume(key)
			draw_rect(bar, Color(0, 0, 0, 0.5 * alpha))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), Color(BLOOD if not on else BLOOD_LIGHT, alpha))
			draw_rect(bar, Color(GOLD, 0.5 * alpha), false, 1.0)
			draw_string(font, Vector2(bar.end.x + 10, row.get_center().y + 5), "%d%%" % roundi(v * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(MUTED, alpha))


static func _radial(colors: Array, offsets: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
