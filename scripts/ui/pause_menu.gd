class_name PauseMenu
extends MainMenu
# Menu de pausa, modelo C "Faixa lateral" sem as barras de PV e SAN (Léo, 13/11): uma faixa escura entra
# pela esquerda com PAUSADO, os itens e onde o grupo está; o jogo segue visível à direita, só um pouco mais
# escuro. Os painéis (Salvar, Carregar, Opções) abrem ao lado da faixa. Esc no jogo abre (TestRoom); Esc, botão direito ou Continuar fecham.
# Itens: Continuar, Salvar (3 slots manuais, só fora do combate, DEC-2026-10-29-01), Carregar (automático +
# manuais), Opções, Voltar ao menu e Sair do jogo (estes dois pedem confirmação).
# O save manual guarda o mesmo que o autosave (Progresso.capturar): grupo, mochila, pistas e o lugar; ao
# carregar, o lugar abre pela chegada, como no autosave.

const PAUSE_ITEMS := [["resume", "Continuar"], ["save", "Salvar"], ["load", "Carregar"], ["opts", "Opções"], ["menu", "Voltar ao menu"], ["quit", "Sair do jogo"]]
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const SHADER := preload("res://assets/shaders/pausa_fundo.gdshader")
const LAYER := 90  # acima do HUD, abaixo do fade do SceneLoader (100)

var room: Node
var save_slots: Array[Dictionary] = []  # os 3 manuais, para o painel Salvar
var save_target := ""  # slot que espera a confirmação de substituir
var last_saved := ""  # slot gravado agora há pouco (o painel avisa)
var last_error := OK
var strip: TextureRect  # a faixa escura com título, itens e onde o grupo está

const STRIP := Color(0.039, 0.031, 0.027)
const STRIP_W := 0.34  # fração da largura da tela


# Pausa o jogo e abre o menu numa camada própria, filha da sala (some junto se a cena trocar).
static func open_on(owner_room: Node) -> PauseMenu:
	var layer := CanvasLayer.new()
	layer.name = "Pausa"
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var m := PauseMenu.new()
	m.room = owner_room
	layer.add_child(m)
	owner_room.add_child(layer)
	owner_room.get_tree().paused = true
	return m


func _ready() -> void:
	t = INTRO_END  # sem abertura: aparece pronto
	super()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # filho de CanvasLayer: ocupa a tela toda
	size = get_viewport_rect().size
	_build_strip()
	_layout()


# Faixa escura à esquerda que some num degradê para a direita; o jogo continua visível do outro lado.
func _build_strip() -> void:
	strip = TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(STRIP, 0.97), Color(STRIP, 0.97), Color(STRIP, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 4
	strip.texture = tex
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	move_child(strip, background.get_index() + 1)
	version_label.add_theme_font_override("font", spaced_font(2))
	version_label.add_theme_color_override("font_color", MUTED)


# Sem abertura nem flutuação: tudo já aparece no lugar.
func _apply_intro() -> void:
	curtain.color.a = 0.0
	title_label.modulate.a = 1.0
	title_rule.modulate.a = 1.0
	version_label.modulate.a = 1.0
	title_label.position.y = _title_y
	for r in menu_rows:
		r.intro = 1.0


func _make_background() -> Control:
	var r := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("raio", 0.0)  # Faixa lateral: o jogo fica visível, só um pouco mais escuro
	m.set_shader_parameter("brilho", 0.7)
	m.set_shader_parameter("cor", 0.85)
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _title_text() -> String:
	return "PAUSADO"


func in_combat() -> bool:
	return room != null and room.get("mode") == TestRoom.Mode.COMBAT


func can_save() -> bool:
	return room != null and room.has_method("_area_id") and room.get("mode") == TestRoom.Mode.EXPLORATION


func _footer_text() -> String:
	var place := str(room.call("_place_label")) if room and room.has_method("_place_label") else ""
	var parts := [place, "COMBATE" if in_combat() else "EXPLORAÇÃO"]
	if in_combat():
		parts.append("SALVAR SÓ FORA DO COMBATE")
	return " · ".join(parts.filter(func(p: String) -> bool: return p != ""))


func _menu_items() -> Array:
	return PAUSE_ITEMS.duplicate()


func refresh_items() -> void:
	super()
	for r in menu_rows:
		if r.id == "save":
			r.disabled = not can_save()


func _layout() -> void:
	super()
	if strip:
		strip.position = Vector2.ZERO
		strip.size = Vector2(size.x * STRIP_W, size.y)
	menu_box.position.x = size.x * 0.06 + 8
	version_label.position = Vector2(size.x * 0.06, size.y - 36)
	# Painéis abrem no espaço à direita da faixa, centrados na altura.
	var pw := minf(size.x * 0.5, 480.0)
	panel_box.custom_minimum_size = Vector2(pw, 0)
	panel_box.reset_size()
	panel_box.position = Vector2(size.x * (STRIP_W + 0.04), ((size.y - panel_box.size.y) / 2.0)).round()


func activate(item: String) -> void:
	if starting:
		return
	match item:
		"resume":
			close_pause()
		"save":
			if not can_save():
				return
			last_saved = ""
			_open("save")
		"menu", "quit":
			_ask(item)
		_:
			super(item)


func _ask_text(action: String) -> String:
	match action:
		"menu":
			return "Voltar ao menu inicial? O que não foi salvo será perdido."
		"quit":
			return "Sair do jogo? O que não foi salvo será perdido."
		"overwrite":
			return "Substituir o save do slot %s?" % SLOT_MARK.get(save_target, "?")
	return ""


func _confirmed(action: String) -> void:
	match action:
		"menu":
			_leave()
			if not Scenes.go(get_tree(), MENU_SCENE):
				_stay()
		"quit":
			get_tree().quit()
		"overwrite":
			write_save(save_target)


func _panel_title(which: String) -> String:
	return "SALVAR" if which == "save" else super(which)


func _fill_panel(which: String) -> void:
	if which != "save":
		return
	save_slots.clear()
	for entry in SaveSlots.list(save_dir):
		if entry["slot"] != SaveSlots.AUTO:
			save_slots.append(entry)
	for i in save_slots.size():
		var r := MenuRow.new(self, MenuRow.Kind.SLOT, str(i), "")
		r.slot = save_slots[i]
		r.activated.connect(func(id: String) -> void: save_to(int(id)))
		_add_panel_row(r)
	if last_saved != "":
		var ok := last_error == OK
		var note := _label("Jogo salvo no slot %s." % SLOT_MARK.get(last_saved, "?") if ok else "Não deu para salvar (erro %d)." % last_error, 13, MUTED if ok else WARN)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel_body.add_child(note)


# Slot com alguma coisa (mesmo corrompido) pede confirmação antes de ser substituído.
func save_to(index: int) -> void:
	if index < 0 or index >= save_slots.size() or not can_save():
		return
	var entry := save_slots[index]
	save_target = str(entry["slot"])
	if str(entry.get("status", SaveGame.EMPTY)) != SaveGame.EMPTY:
		_ask("overwrite")
	else:
		write_save(save_target)


func write_save(slot: String) -> Error:
	if not can_save():
		return ERR_UNAVAILABLE
	var data := Progresso.capturar(room, str(room.call("_area_id")), str(room.call("_place_label")))
	last_error = SaveSlots.save(slot, data, save_dir)
	last_saved = slot
	_open("save")
	for r in panel_rows:
		if r.slot.get("slot", "") == slot:
			r.grab_focus()
	return last_error


# Carregar a partir da pausa: solta o jogo (a sala fica desligada até a cena trocar) e abre o save.
func _start_game(slot: String) -> bool:
	if starting:
		return false
	starting = true
	_leave()
	if not Progresso.carregar(get_tree(), slot, save_dir):
		_stay()
		refresh_slots()
		return false
	return true


# Tira a pausa sem deixar a sala correr durante o fade da troca de cena.
func _leave() -> void:
	starting = true
	if room:
		room.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = false


# A troca não aconteceu: volta a pausar, com a sala ligada de novo.
func _stay() -> void:
	starting = false
	get_tree().paused = true
	if room:
		room.process_mode = Node.PROCESS_MODE_INHERIT


func close_pause() -> void:
	if starting:
		return
	get_tree().paused = false
	var layer := get_parent()
	if layer:
		layer.queue_free()
	if room and room.has_method("_update_cursor"):
		room.call("_update_cursor")


# Esc ou botão direito: fecha a pergunta, depois o painel, e por fim a pausa.
func _back() -> void:
	if confirming != "":
		confirm(false)
	elif panel != "":
		close_panel()
	else:
		close_pause()
