class_name CombatHud
extends CanvasLayer
# HUD mínimo: modo atual, aviso central e painel do turno com PA e "Passar turno".
# A UI só mostra estado confirmado: quem controla o jogo chama os métodos on_*
# quando o evento acontece (GDD Anexo D), e o HUD nunca altera regras.

signal end_turn_requested

const NOTICE_SECONDS := 2.0  # provisório: duração de avisos está PENDENTE no GDD
const PIP_SIZE := Vector2(12, 12)
const PIP_FULL := Color(0.95, 0.8, 0.25)
const PIP_EMPTY := Color(0.3, 0.3, 0.35)
const FONT_SIZE := 12  # em pixels da resolução interna 960×540

var mode_label: Label
var notice_label: Label
var turn_panel: PanelContainer
var unit_label: Label
var pa_label: Label
var pips: HBoxContainer
var end_turn_button: Button
var notice_timer: Timer
# A sala de teste desenha o modo, os PA e o fim do turno no próprio HUD (moldura A); aqui ficam só os avisos.
var room_draws_hud := false:
	set(value):
		room_draws_hud = value
		mode_label.visible = not value
		if value:
			turn_panel.visible = false


func _init() -> void:
	layer = 10
	_build()
	show_exploration()


func show_exploration() -> void:
	mode_label.text = HudText.mode_label(false)
	turn_panel.visible = false


func on_combat_started() -> void:
	mode_label.text = HudText.mode_label(true)
	show_notice("Combate!")


func on_turn_started(unit_name: String, pa: int, max_pa: int) -> void:
	unit_label.text = unit_name
	on_pa_changed(pa, max_pa)
	end_turn_button.disabled = false
	turn_panel.visible = not room_draws_hud


func on_pa_changed(pa: int, max_pa: int) -> void:
	pa_label.text = HudText.pa_label(pa, max_pa)
	for child in pips.get_children():
		pips.remove_child(child)
		child.free()
	for i in max_pa:
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.color = PIP_FULL if i < pa else PIP_EMPTY
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)


func on_turn_ended() -> void:
	end_turn_button.disabled = true
	turn_panel.visible = false


func on_action_rejected(reason: String) -> void:
	show_notice(HudText.rejection_message(reason))


func on_combat_ended() -> void:
	show_exploration()
	show_notice("Combate encerrado")


func show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = true
	if notice_timer.is_inside_tree():
		notice_timer.start(NOTICE_SECONDS)


func _build() -> void:
	mode_label = Label.new()  # canto superior direito: a esquerda é das fichas do grupo
	mode_label.anchor_left = 1.0
	mode_label.anchor_right = 1.0
	mode_label.offset_left = -220
	mode_label.offset_right = -16
	mode_label.offset_top = 156  # abaixo do minimapa
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_label.add_theme_font_size_override("font_size", 18)
	add_child(mode_label)

	notice_label = Label.new()
	notice_label.anchor_right = 1.0
	notice_label.offset_top = 76
	notice_label.offset_bottom = 114
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 30)
	notice_label.visible = false
	add_child(notice_label)

	notice_timer = Timer.new()
	notice_timer.one_shot = true
	notice_timer.timeout.connect(func() -> void: notice_label.visible = false)
	add_child(notice_timer)

	# Painel do turno no canto inferior direito; o centro da base é da barra de ações.
	turn_panel = PanelContainer.new()
	turn_panel.anchor_left = 1.0
	turn_panel.anchor_right = 1.0
	turn_panel.anchor_top = 1.0
	turn_panel.anchor_bottom = 1.0
	turn_panel.offset_left = -300
	turn_panel.offset_right = -12
	turn_panel.offset_top = -52
	turn_panel.offset_bottom = -12
	turn_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	turn_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(turn_panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	turn_panel.add_child(row)

	unit_label = Label.new()
	unit_label.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(unit_label)
	pa_label = Label.new()
	pa_label.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(pa_label)
	pips = HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(pips)

	end_turn_button = Button.new()
	end_turn_button.text = "Passar turno"
	end_turn_button.add_theme_font_size_override("font_size", FONT_SIZE)
	end_turn_button.focus_mode = Control.FOCUS_NONE  # não roubar o teclado da sala
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	row.add_child(end_turn_button)
