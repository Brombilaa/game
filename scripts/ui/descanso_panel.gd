class_name DescansoPanel
extends CanvasLayer
# Painel do ponto de descanso (zona segura): abre com o clique no objeto do ponto (a Van; sem tecla) e fecha com Esc ou o X. Duas partes:
#   DESCANSAR: PV e SAN do grupo ao máximo, tira a ruptura e salva o jogo (DescansoRules).
#   PREPARAR RITUAIS: o Miguel combina componentes e deixa o ritual preparado; cada carga dispensa o componente na hora e reforça
#   o efeito (RitualRules.prepare; tudo provisório, combat.json > preparo). Mostra o que cada preparo gasta e quanto há na mochila.
# Com o painel aberto o tempo para, como no inventário e no diário (GDD #23). Só desenha e lê o mouse; as regras ficam em `room`.

const PW := 600.0
const GOLD := Color(0.839, 0.678, 0.361)
const BRONZE := Color(0.353, 0.255, 0.149)
const PLATE := Color(0.05, 0.037, 0.03, 0.97)
const TEXT := Color(0.91, 0.87, 0.79)
const MUTED := Color(0.66, 0.6, 0.49)
const CRIMSON := Color(0.62, 0.09, 0.11)
const OK := Color(0.55, 0.78, 0.5)

const REASONS := {
	"requirement": "Não pode agora",
	"max_charges": "Já está no máximo",
	"no_component": "Falta o componente do elemento",
	"no_extra": "Falta um componente de outro elemento para combinar",
}

var room: Node
var open := false

var _raiz: Control
var _corpo: VBoxContainer
var _aviso := ""


func _init() -> void:
	layer = 21
	visible = false
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(dim)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(PW, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = PLATE
	estilo.set_border_width_all(2)
	estilo.border_color = BRONZE
	estilo.set_content_margin_all(12)
	painel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(painel)
	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 8)
	painel.add_child(_corpo)


func abrir() -> void:
	if open:
		return
	open = true
	_aviso = ""
	visible = true
	atualizar()


func fechar() -> void:
	open = false
	visible = false


func _rotulo(texto: String, tamanho: int, cor: Color, quebra := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _botao(texto: String, ativo: bool, ao_clicar: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.disabled = not ativo
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(ao_clicar)
	return b


# Refaz o painel a partir do estado da sala (grupo, mochila, cargas).
func atualizar() -> void:
	for f in _corpo.get_children():
		_corpo.remove_child(f)
		f.queue_free()
	var cab := HBoxContainer.new()
	var t := _rotulo("PONTO DE DESCANSO", 16, GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	var x := Button.new()
	x.text = "X"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_color_override("font_color", GOLD)
	x.pressed.connect(fechar)
	cab.add_child(x)
	_corpo.add_child(cab)
	_corpo.add_child(_rotulo("Zona segura: ninguém se apressa aqui.", 12, MUTED))
	_descanso()
	_preparo()
	_corpo.add_child(_rotulo("Valores provisórios, aguardando revisão do Léo.", 10, MUTED))


func _descanso() -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	linha.add_child(_botao("DESCANSAR", true, _descansar))
	var d := _rotulo("PV e SAN do grupo ao máximo, tira a ruptura e salva o jogo.", 12, TEXT, true)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(d)
	_corpo.add_child(linha)
	if _aviso != "":
		_corpo.add_child(_rotulo(_aviso, 12, OK, true))


func _descansar() -> void:
	var got: Dictionary = room.room_descanso.rest()
	var partes: Array[String] = []
	for nome in got:
		var g: Dictionary = got[nome]
		partes.append("%s +%d PV +%d SAN%s" % [nome, g.pv, g.san, " (ruptura curada)" if g.ruptura else ""])
	_aviso = "Descansaram: " + "; ".join(partes) if not partes.is_empty() else "Todos já estavam inteiros. Jogo salvo."
	atualizar()


func _preparo() -> void:
	var feiticeiros: Array = room.room_descanso.casters()
	if feiticeiros.is_empty():
		return
	var rr: RitualRules = room.rituals
	for m: Combatant in feiticeiros:
		_corpo.add_child(HSeparator.new())
		_corpo.add_child(_rotulo("PREPARAR RITUAIS · %s" % m.name, 14, GOLD))
		_corpo.add_child(_rotulo("Combina componentes: cada preparo gasta os do elemento do ritual mais %d de outro elemento. Uma carga preparada dispensa o componente e reforça o efeito em %d%% (guarda até %d)." % [rr.prepare_extra(), roundi(float(room.cfg.preparo("bonus")) * 100.0), rr.prepare_max()], 11, MUTED, true))
		for id in rr.known(m):
			_corpo.add_child(_linha_ritual(rr, m, id))


func _linha_ritual(rr: RitualRules, m: Combatant, id: String) -> Control:
	var r := rr.ritual(id)
	var motivo := rr.prepare_blocker(m, id)
	var box := VBoxContainer.new()
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	var nome := _rotulo("%s  (%d/%d)" % [r["nome"], rr.prepared_charges(m, id), rr.prepare_max()], 13, TEXT)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(nome)
	linha.add_child(_botao("PREPARAR", motivo == "", func() -> void: _preparar(m, id)))
	box.add_child(linha)
	var custo := "Gasta %d de %s + %d de outro elemento · mochila: %d e %d" % [rr.cost_components(id), RitualRules.element_name(rr.element(id)), rr.prepare_extra(), rr.components_available(id), rr.extras_available(id)]
	box.add_child(_rotulo(custo + ("" if motivo == "" else " · " + REASONS.get(motivo, motivo)), 11, MUTED if motivo == "" else CRIMSON, true))
	return box


func _preparar(m: Combatant, id: String) -> void:
	var out: Dictionary = room.room_descanso.prepare(m, id)
	if out.ok:
		var nomes: Array[String] = []
		for iid in out.components:
			nomes.append(str(room.cfg.game_data.get_entry("itens", iid)["nome"]).to_lower())
		_aviso = "%s prepara %s: gasta %s." % [m.name, room.rituals.ritual(id)["nome"], ", ".join(nomes)]
	else:
		_aviso = REASONS.get(out.reason, "Não deu")
	atualizar()


func _input(event: InputEvent) -> void:
	if open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		fechar()
		get_viewport().set_input_as_handled()
