class_name MainMenu
extends Control
# Menu inicial, layout A "Cinema" (Léo, 13/11): fundo animado "A árvore velha" (MenuFundoArvore, escolhido por
# enquanto), nome do jogo no alto à esquerda, menu fino à esquerda sem caixas e painéis discretos à direita.
# Feito com nós de Control (cada linha é um Control focável que desenha a si mesmo), então mouse, teclado e foco
# seguem as regras da Godot. Tudo em Special Elite (decisão de 13/11), sem logo e sem subtítulo.
# Itens: Continuar (só com save; abre o mais recente), Novo jogo (pede confirmação se já há save), Carregar
# (automático + 3 manuais, com aviso de save corrompido ou de versão nova), Opções (volumes, tela cheia,
# sincronia vertical, combate rápido; gravadas a cada mudança), Créditos e Sair (com confirmação).
# Esc ou o botão direito fecham a confirmação ou o painel. Quem lê o save e abre o lugar é o Progresso.

const ITEMS := [["new", "Novo jogo"], ["load", "Carregar"], ["opts", "Opções"], ["credits", "Créditos"], ["quit", "Sair"]]
const CONTINUE_ITEM := ["continue", "Continuar"]  # primeiro item, só quando há um save que carrega
const OPTION_ROWS := [["master", "Volume geral"], ["music", "Música"], ["sfx", "Efeitos"], ["fullscreen", "Tela cheia"], ["vsync", "Sincronia vertical"], ["fast_combat", "Combate rápido (2x)"]]
const TOGGLE_KEYS := ["fullscreen", "vsync", "fast_combat"]
const SLOT_MARK := {"auto": "A", "manual_1": "I", "manual_2": "II", "manual_3": "III"}
const AREA_NAMES := {"test_room": "Sala de teste", "parque": "Parque"}
const PANEL_TITLES := {"load": "CARREGAR", "opts": "OPÇÕES", "credits": "CRÉDITOS"}
# Créditos provisórios: o nome de quem faz o jogo ainda não foi definido pelo Léo.
const CREDITS := [
	["Pacto Carmesim", "Protótipo da missão 1"],
	["Criação e direção", "a definir"],
	["Feito com", "Godot Engine 4.3"],
	["Fonte", "Special Elite (Apache 2.0)"],
]
const VERSION := "v0.1"

# Abertura, em segundos: o fundo sai do preto, o nome sobe e os itens entram um a um.
const BG_FADE := 1.2
const TITLE_FADE := 2.2
const ITEM_START := 1.2
const ITEM_STEP := 0.18
const ITEM_FADE := 0.9
const INTRO_END := 3.0  # ITEM_START + 5 * ITEM_STEP + ITEM_FADE: o sexto item (com Continuar) termina aqui
const FLOAT_PERIOD := 7.0  # o nome flutua devagar
const FLOAT_PX := 5.0
const PANEL_FADE := 0.3

const BG := Color("050302")
const INK := Color("f3e6cc")
const ITEM_INK := Color(0.9, 0.855, 0.77, 0.66)
const ITEM_ON := Color("fff6e4")
const MUTED := Color("a8977c")
const LINE := Color("4a3a28")
const BLOOD := Color("aa2424")
const BLOOD_LIGHT := Color("c8382e")
const WARN := Color("e0453a")
const PANEL_BG := Color(0.03, 0.02, 0.018, 0.78)

const TITLE := "PACTO CARMESIM"
const TITLE_SIZE := 33
const ITEM_SIZE := 20
const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")

static var pending_slot := ""

var starting := false  # já pediu a troca para o jogo
var t := 0.0
var panel := ""  # "", "load", "opts" ou "credits"
var confirming := ""  # "", "new" ou "quit": pergunta aberta
var save_dir := SaveSlots.DIR
var slots: Array[Dictionary] = []
var items: Array = ITEMS.duplicate()  # ITEMS, com Continuar na frente quando há save
var continue_slot := ""  # slot que o Continuar abre
var options_path := GameOptions.PATH
var options := GameOptions.shared()

var background: Control  # MenuFundoArvore no menu inicial; o jogo desfocado na pausa
var curtain: ColorRect  # preto da abertura
var title_label: Label
var title_rule: ColorRect
var menu_box: VBoxContainer
var menu_rows: Array[MenuRow] = []
var version_label: Label
var panel_box: PanelContainer
var panel_title: Label
var panel_body: VBoxContainer
var panel_rows: Array[MenuRow] = []
var dialog: Control
var dialog_text: Label
var dialog_rows: Array[MenuRow] = []
var _title_y := 0.0
var _last_focus: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _is_pause():
		RenderingServer.set_default_clear_color(BG)
	theme = menu_theme()
	options.apply()
	GameCursor.apply(GameCursor.Kind.ARROW)
	background = _make_background()
	add_child(background)
	_build_title()
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 2)
	add_child(menu_box)
	version_label = _label(_footer_text(), 10, Color(INK, 0.4))
	add_child(version_label)
	_build_panel()
	_build_dialog()
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(curtain)
	refresh_items()
	resized.connect(_layout)
	_layout()
	_apply_intro()


# Tema do menu: Special Elite em tudo, sem caixas nem bordas padrão da Godot.
static func menu_theme() -> Theme:
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 15
	th.set_color("font_color", "Label", INK)
	var empty := StyleBoxEmpty.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = Color(LINE, 0.9)
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 16
	th.set_stylebox("panel", "PanelContainer", panel_style)
	th.set_stylebox("focus", "Control", empty)
	return th


static func spaced_font(spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = FONT
	f.spacing_glyph = spacing
	return f


func _label(text: String, font_size: int, color: Color, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if spacing != 0:
		l.add_theme_font_override("font", spaced_font(spacing))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_title() -> void:
	title_label = _label(_title_text(), TITLE_SIZE, Color("efdcc6"), 8)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.add_theme_constant_override("shadow_outline_size", 6)
	add_child(title_label)
	title_rule = ColorRect.new()
	title_rule.color = Color(BLOOD_LIGHT, 0.8)
	title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_rule)


func _build_panel() -> void:
	panel_box = PanelContainer.new()
	panel_box.visible = false
	panel_box.modulate.a = 0.0
	add_child(panel_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel_box.add_child(col)
	panel_title = _label("", 14, Color("d4aa50"), 5)
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(panel_title)
	panel_body = VBoxContainer.new()
	panel_body.add_theme_constant_override("separation", 6)
	col.add_child(panel_body)


func _build_dialog() -> void:
	dialog = Control.new()
	dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog.visible = false
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.add_child(dim)
	var box := PanelContainer.new()
	box.name = "Box"
	dialog.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	box.add_child(col)
	dialog_text = _label("", 16, INK)
	dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(320, 0)
	col.add_child(dialog_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	col.add_child(row)
	for spec in [["yes", "Sim"], ["no", "Não"]]:
		var r := MenuRow.new(self, MenuRow.Kind.ITEM, spec[0], spec[1])
		r.font_size = 17
		r.custom_minimum_size = Vector2(90, 30)
		r.activated.connect(func(id: String) -> void: confirm(id == "yes"))
		row.add_child(r)
		dialog_rows.append(r)


func _layout() -> void:
	var w := size.x
	var h := size.y
	background.position = Vector2.ZERO
	background.size = size
	title_label.position = Vector2(w * 0.06, w * 0.08 - TITLE_SIZE * 0.6)
	_title_y = title_label.position.y
	title_rule.position = Vector2(w * 0.06 + 2, title_label.position.y + TITLE_SIZE * 1.45)
	title_rule.size = Vector2(w * 0.05, 1)
	menu_box.position = Vector2(w * 0.06, h * 0.5 - h * 0.08)
	menu_box.size = Vector2(w * 0.3, 0)
	version_label.position = Vector2(w * 0.014, h - 20)
	panel_box.custom_minimum_size = Vector2(w * 0.52, 0)
	panel_box.reset_size()
	panel_box.position = Vector2(w * 0.4, h * 0.2)
	var box: Control = dialog.get_node("Box")
	box.reset_size()
	box.position = (size - box.size) / 2.0


# --- Pontos que o menu de pausa (PauseMenu) troca ------------------------------------

func _is_pause() -> bool:
	return false


func _make_background() -> Control:
	return MenuFundoArvore.new()


func _title_text() -> String:
	return TITLE


func _footer_text() -> String:
	return VERSION


# Continuar só existe quando algum slot carrega.
func _menu_items() -> Array:
	continue_slot = SaveSlots.latest(save_dir)
	var list: Array = ITEMS.duplicate()
	if continue_slot != "":
		list.push_front(CONTINUE_ITEM)
	return list


func _ask_text(action: String) -> String:
	return "Começar um novo jogo? O save automático será substituído ao chegar no parque." if action == "new" else "Sair do jogo?"


func _confirmed(action: String) -> void:
	if action == "new":
		_start_game("")
	elif action == "quit":
		get_tree().quit()


func _panel_title(which: String) -> String:
	return PANEL_TITLES.get(which, which.to_upper())


func _fill_panel(_which: String) -> void:
	pass


# --- Abertura -------------------------------------------------------------------------

func _process(delta: float) -> void:
	t += delta
	_apply_intro()
	var mouse := get_local_mouse_position()
	if size.x > 0 and background is MenuFundoArvore:
		background.parallax = Vector2(mouse.x / size.x - 0.5, mouse.y / size.y - 0.5)


func intro_done() -> bool:
	return t >= INTRO_END


func skip_intro() -> void:
	t = maxf(t, INTRO_END)
	_apply_intro()


static func ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


# Transparência de cada item na abertura (0 a 1), um depois do outro.
static func item_alpha(time: float, index: int) -> float:
	return ease_out((time - ITEM_START - index * ITEM_STEP) / ITEM_FADE)


func _apply_intro() -> void:
	curtain.color.a = 1.0 - ease_out(t / BG_FADE)
	var k := ease_out(t / TITLE_FADE)
	title_label.modulate.a = k
	title_rule.modulate.a = k
	title_label.position.y = _title_y + (1.0 - k) * 12.0 + sin(t * TAU / FLOAT_PERIOD) * FLOAT_PX
	for i in menu_rows.size():
		menu_rows[i].intro = item_alpha(t, i)
	version_label.modulate.a = ease_out((t - ITEM_START) / ITEM_FADE)


# --- Itens ----------------------------------------------------------------------------

# Continuar só existe quando algum slot carrega; o foco começa no primeiro item.
func refresh_items() -> void:
	items = _menu_items()
	for r in menu_rows:
		menu_box.remove_child(r)
		r.queue_free()
	menu_rows.clear()
	for spec in items:
		var r := MenuRow.new(self, MenuRow.Kind.ITEM, spec[0], spec[1])
		r.activated.connect(activate)
		menu_box.add_child(r)
		menu_rows.append(r)
	if is_inside_tree() and panel == "" and confirming == "":
		menu_rows[0].grab_focus.call_deferred()


func activate(item: String) -> void:
	if starting:
		return
	if not intro_done():
		skip_intro()
	match item:
		"continue":
			_start_game(continue_slot)
		"new":
			if continue_slot != "":
				_ask("new")
			else:
				_start_game("")
		"load":
			refresh_slots()
			_open("load")
		"opts":
			_open("opts")
		"credits":
			_open("credits")
		"quit":
			_ask("quit")


# --- Confirmação ----------------------------------------------------------------------

func _ask(action: String) -> void:
	_last_focus = get_viewport().gui_get_focus_owner()
	confirming = action
	dialog_text.text = _ask_text(action)
	dialog.visible = true
	_layout()
	dialog_rows[1].grab_focus()  # o foco começa no "Não"


func confirm(yes: bool) -> void:
	var action := confirming
	confirming = ""
	dialog.visible = false
	if _last_focus and is_instance_valid(_last_focus):
		_last_focus.grab_focus()
	if yes:
		_confirmed(action)


# --- Painéis --------------------------------------------------------------------------

func _open(which: String) -> void:
	panel = which
	panel_title.text = _panel_title(which)
	panel_rows.clear()
	for c in panel_body.get_children():
		panel_body.remove_child(c)  # sai já, para o painel encolher na altura do conteúdo novo
		c.queue_free()
	match which:
		"load":
			for i in slots.size():
				var r := MenuRow.new(self, MenuRow.Kind.SLOT, str(i), "")
				r.slot = slots[i]
				r.disabled = slots[i]["empty"]
				r.activated.connect(func(id: String) -> void: load_slot(int(id)))
				_add_panel_row(r)
		"opts":
			for spec in OPTION_ROWS:
				var kind := MenuRow.Kind.TOGGLE if spec[0] in TOGGLE_KEYS else MenuRow.Kind.VOLUME
				var r := MenuRow.new(self, kind, spec[0], spec[1])
				r.activated.connect(func(id: String) -> void: change_option(id, 0.0))
				_add_panel_row(r)
		"credits":
			for line in CREDITS:
				var block := VBoxContainer.new()
				block.add_theme_constant_override("separation", 0)
				var head := _label(line[0], 11, MUTED, 2)
				var body := _label(line[1], 15, INK)
				block.add_child(head)
				block.add_child(body)
				panel_body.add_child(block)
		_:
			_fill_panel(which)
	var close := MenuRow.new(self, MenuRow.Kind.ITEM, "close", "Fechar")
	close.font_size = 15
	close.centered = true
	close.activated.connect(func(_id: String) -> void: close_panel())
	_add_panel_row(close)
	panel_box.visible = true
	_layout()
	create_tween().tween_property(panel_box, "modulate:a", 1.0, PANEL_FADE)
	for r in panel_rows:
		if not r.disabled:
			r.grab_focus()
			break


func _add_panel_row(r: MenuRow) -> void:
	panel_body.add_child(r)
	panel_rows.append(r)


func close_panel() -> void:
	if panel == "":
		return
	if panel == "opts":
		options.save(options_path)
	var was := panel
	panel = ""
	panel_box.modulate.a = 0.0
	panel_box.visible = false
	for r in menu_rows:
		if items[menu_rows.find(r)][0] == was:
			r.grab_focus()
			return
	if not menu_rows.is_empty():
		menu_rows[0].grab_focus()


# Volume: `step` soma ao valor (setas); 0 num interruptor inverte. Grava a cada mudança.
func change_option(key: String, step: float) -> void:
	if key in TOGGLE_KEYS:
		options.values[key] = not bool(options.values.get(key, false))
	else:
		options.set_volume(key, options.volume(key) + step)
	options.apply()
	options.save(options_path)


func set_volume(key: String, value: float) -> void:
	options.set_volume(key, value)
	options.apply()
	options.save(options_path)


# --- Carregar -------------------------------------------------------------------------

func refresh_slots() -> void:
	slots.clear()
	for entry in SaveSlots.list(save_dir):
		slots.append(entry)


func load_slot(index: int) -> bool:
	if index < 0 or index >= slots.size() or slots[index]["empty"]:
		return false
	return _start_game(slots[index]["slot"])


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


# Nome do lugar no slot: o rótulo gravado ("DELEGACIA · 21h" vira "Delegacia · 21h") ou o id da área.
static func slot_label(entry: Dictionary) -> String:
	var rotulo := str(entry.get("rotulo", ""))
	if rotulo.is_empty():
		return area_label(str(entry.get("area", "")))
	var words := []
	for w in rotulo.to_lower().split(" "):
		words.append(w.substr(0, 1).to_upper() + w.substr(1) if w.length() > 0 and w[0] >= "a" and w[0] <= "z" else w)
	return " ".join(words)


# Linha de baixo do slot: quando salvou, ou o aviso de por que não carrega.
static func slot_detail(entry: Dictionary) -> String:
	match str(entry.get("status", "")):
		SaveGame.CORRUPT:
			return "Save corrompido, não dá para carregar"
		SaveGame.NEWER:
			return "Feito por uma versão mais nova do jogo"
	var when := date_label(int(entry.get("saved_at", 0)))
	return ("Automático · " + when) if entry.get("slot") == SaveSlots.AUTO else when


# Troca para o jogo com fade; um segundo pedido durante a troca é ignorado.
func _start_game(slot: String) -> bool:
	if starting:
		return false
	starting = true
	pending_slot = slot
	var game := get_node_or_null("/root/Game")
	if game:
		game.pending_slot = slot
	var ok := Progresso.novo_jogo(get_tree()) if slot == "" else Progresso.carregar(get_tree(), slot, save_dir)
	if not ok:
		starting = false
		refresh_items()
		refresh_slots()
	return ok


# --- Entrada --------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not intro_done():
			skip_intro()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_back()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if starting or not event.is_pressed():
		return
	if not intro_done() and event is InputEventKey:
		skip_intro()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		_back()
		get_viewport().set_input_as_handled()


# Esc ou botão direito: fecha a pergunta, depois o painel.
func _back() -> void:
	if confirming != "":
		confirm(false)
	elif panel != "":
		close_panel()


# Uma linha do menu: item, slot de save, volume ou interruptor. Focável por mouse e teclado; desenha a si mesma.
class MenuRow:
	extends Control

	signal activated(id: String)

	enum Kind { ITEM, SLOT, VOLUME, TOGGLE }

	var menu: MainMenu
	var kind: Kind
	var id := ""
	var text := ""
	var slot := {}
	var disabled := false
	var font_size := MainMenu.ITEM_SIZE
	var centered := false
	var intro := 1.0  # transparência da abertura
	var on := 0.0  # animação do foco, 0 a 1
	var _font: FontVariation

	func _init(owner_menu: MainMenu, row_kind: Kind, row_id: String, row_text: String) -> void:
		menu = owner_menu
		kind = row_kind
		id = row_id
		text = row_text
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = MainMenu.spaced_font(3 if kind == Kind.ITEM else 1)
		match kind:
			Kind.ITEM:
				custom_minimum_size = Vector2(0, 36)
			Kind.SLOT:
				custom_minimum_size = Vector2(0, 46)
			_:
				custom_minimum_size = Vector2(0, 30)
		mouse_entered.connect(func() -> void:
			if not disabled and menu.intro_done():
				grab_focus())

	func _process(delta: float) -> void:
		var target := 1.0 if has_focus() else 0.0
		var before := on
		on = move_toward(on, target, delta / 0.35)
		if on != before or intro < 1.0:
			queue_redraw()

	func _bar() -> Rect2:
		return Rect2(size.x * 0.46, size.y / 2.0 - 3.0, size.x * 0.42, 6.0)

	func _gui_input(event: InputEvent) -> void:
		if disabled or menu.starting:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if not menu.intro_done():
				menu.skip_intro()
				return
			if kind == Kind.VOLUME:
				var bar := _bar()
				menu.set_volume(id, (event.position.x - bar.position.x) / bar.size.x)
			else:
				activated.emit(id)
			queue_redraw()
		elif event is InputEventMouseMotion and kind == Kind.VOLUME and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var bar := _bar()
			menu.set_volume(id, (event.position.x - bar.position.x) / bar.size.x)
			queue_redraw()
			accept_event()
		elif event.is_action_pressed("ui_accept"):
			accept_event()
			if kind != Kind.VOLUME:
				activated.emit(id)
			queue_redraw()
		elif kind == Kind.VOLUME and (event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_right", true)):
			accept_event()
			menu.change_option(id, 0.05 if event.is_action("ui_right") else -0.05)
			queue_redraw()

	func _draw() -> void:
		var e := MainMenu.ease_out(on)
		var a := intro * (0.45 if disabled else 1.0)
		match kind:
			Kind.ITEM:
				_draw_item(e, a)
			Kind.SLOT:
				_draw_slot(e, a)
			Kind.VOLUME, Kind.TOGGLE:
				_draw_option(e, a)

	func _draw_item(e: float, a: float) -> void:
		var shift := 11.0 * e + (1.0 - intro) * 10.0
		var col := MainMenu.ITEM_INK.lerp(MainMenu.ITEM_ON, e)
		var y := size.y / 2.0 + font_size * 0.35
		if centered:
			draw_string(_font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(col, col.a * a))
			if e > 0.01:
				var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var cx := size.x / 2.0
				draw_line(Vector2(cx - tw / 2.0 * e, y + 6), Vector2(cx + tw / 2.0 * e, y + 6), Color(MainMenu.BLOOD_LIGHT, a), 1.0)
			return
		draw_string(_font, Vector2(22.0 + shift, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(col, col.a * a))
		if e > 0.01:
			draw_line(Vector2(shift - 4.0, size.y / 2.0), Vector2(shift - 4.0 + 17.0 * e, size.y / 2.0), Color(MainMenu.BLOOD_LIGHT, a), 1.0)

	func _draw_slot(e: float, a: float) -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.35, 0.05, 0.05, 0.28 * e * a))
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(MainMenu.LINE, a), 1.0)
		if e > 0.01:
			draw_line(Vector2(0, 4), Vector2(0, size.y - 4), Color(MainMenu.BLOOD_LIGHT, a * e), 2.0)
		draw_string(_font, Vector2(14, size.y / 2.0 + 8), MainMenu.SLOT_MARK.get(slot.get("slot", ""), "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d4aa50", a))
		var tx := 64.0 + 6.0 * e
		var status := str(slot.get("status", SaveGame.EMPTY if slot.get("empty", true) else SaveGame.OK_STATUS))
		if status == SaveGame.EMPTY:
			draw_string(_font, Vector2(tx, size.y / 2.0 + 5), "Vazio", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(MainMenu.MUTED, a))
		elif slot.get("empty", true):  # existe, mas não carrega: avisa em vez de fingir que está vazio
			draw_string(_font, Vector2(tx, size.y / 2.0 + 5), MainMenu.slot_detail(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(MainMenu.WARN, intro * 0.85))
		else:
			var col := MainMenu.ITEM_INK.lerp(MainMenu.ITEM_ON, e)
			draw_string(_font, Vector2(tx, 20), MainMenu.slot_label(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(col, a))
			draw_string(_font, Vector2(tx, 37), MainMenu.slot_detail(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(MainMenu.MUTED, a))

	func _draw_option(e: float, a: float) -> void:
		var col := MainMenu.ITEM_INK.lerp(MainMenu.ITEM_ON, e)
		var y := size.y / 2.0 + 5.0
		draw_string(_font, Vector2(14.0 + 4.0 * e, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(col, col.a * a))
		if e > 0.01:
			draw_line(Vector2(0, size.y / 2.0), Vector2(9.0 * e, size.y / 2.0), Color(MainMenu.BLOOD_LIGHT, a), 1.0)
		var bar := _bar()
		if kind == Kind.TOGGLE:
			var box := Rect2(bar.position.x, size.y / 2.0 - 7.0, 14, 14)
			draw_rect(box, Color("d4aa50", 0.8 * a), false, 1.0)
			if bool(menu.options.values.get(id, false)):
				draw_rect(box.grow(-3), Color(MainMenu.BLOOD_LIGHT, a))
			return
		var v := menu.options.volume(id)
		draw_rect(bar, Color(0, 0, 0, 0.5 * a))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), Color(MainMenu.BLOOD.lerp(MainMenu.BLOOD_LIGHT, e), a))
		draw_rect(bar, Color("d4aa50", 0.45 * a), false, 1.0)
		draw_string(_font, Vector2(bar.end.x + 10, y), "%d%%" % roundi(v * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(MainMenu.MUTED, a))
