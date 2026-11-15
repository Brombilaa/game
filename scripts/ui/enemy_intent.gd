class_name EnemyIntent
extends Node2D
# Intenção do inimigo no combate (sugestão 11, 15/11/2026): no turno do grupo, mostra quem cada inimigo
# vai atacar na próxima vez dele e até onde ele alcança. Filho da sala: desenha no mesmo espaço dela
# (coordenadas de tela isométrica, _iso) por cima das unidades. A previsão vem de EnemyAi.predict_intents
# e é recalculada só quando algo muda (posições, PV, vez).
#
# Três estilos para o Léo escolher (`estilo`):
#   A "Linha de mira": fio tracejado do inimigo até o alvo e um alvo no chão sob quem vai levar o golpe.
#   B "Etiqueta": plaqueta sobre a cabeça do inimigo com o nome do alvo e o que ele vai fazer.
#   C "Marcas numeradas": cada inimigo ganha um número (a ordem em que age) e o alvo recebe o losango
#     com o número de cada inimigo que vai atacá-lo, à direita da barra de vida.
# Em todos, passar o mouse sobre um inimigo mostra o alcance da arma (linha cheia) e até onde ele chega
# andando e ainda atacando (tracejada).

const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const HEAD := 134.0  # CharacterSheet.HEIGHT: altura da cabeça na tela

var room  # a sala de combate (test_room.gd e filhas)
var estilo := "A"
var mostrar := true
var foco: Combatant = null  # força o alcance de um inimigo (capturas); null = o que estiver sob o mouse
var _intents: Array = []
var _key := ""


func _init(owner_room = null) -> void:
	room = owner_room


func _process(_delta: float) -> void:
	queue_redraw()


# Só no turno do grupo, com o combate andando e nada encenando.
func ativo() -> bool:
	if room == null or not mostrar or room.mode != room.Mode.COMBAT or room.turns == null:
		return false
	var cur: Combatant = room.turns.current
	return cur != null and cur.side == Combatant.Side.PLAYER and not room.busy


func intents() -> Array:
	var k := _signature()
	if k != _key:
		_key = k
		_intents = room.ai.predict_intents()
	return _intents


func _signature() -> String:
	var parts: Array[String] = [str(room.turns.round_number), str(room.turns.current)]
	for u in room.party + room.enemies:
		parts.append("%d,%d,%d,%d" % [roundi(u.pos.x), roundi(u.pos.y), u.pv, u.pa])
	return "|".join(parts)


func _draw() -> void:
	if not ativo():
		return
	var list := intents()
	var hover: Combatant = _hovered()
	match estilo:
		"B":
			_draw_b(list)
		"C":
			_draw_c(list)
		_:
			_draw_a(list)
	for it in list:
		if it.unit == hover:
			_draw_reach(it)


func _hovered() -> Combatant:
	if foco:
		return foco
	var mouse: Vector2 = room._resolve_click(room.get_global_mouse_position())
	return room._enemy_at(mouse)


# --- Cores ------------------------------------------------------------------------------------

func _blood(a := 1.0) -> Color:
	return Color(PlaceholderArt.color("sangue_claro").lightened(0.25), a)


func _paper(a := 1.0) -> Color:
	return Color(0.93, 0.89, 0.8, a)


func _ink(a := 1.0) -> Color:
	return Color(0.05, 0.03, 0.02, a)


# --- A: linha de mira ------------------------------------------------------------------------

func _draw_a(list: Array) -> void:
	for it in list:
		var from: Vector2 = room._iso(it.unit.pos) + Vector2(0, -HEAD * 0.45)
		var to: Vector2 = room._iso(it.target.pos) + Vector2(0, -HEAD * 0.45)
		var strong: bool = it.acao != "aproxima"
		var col := _blood(0.85 if strong else 0.4)
		var end := to if strong else from.lerp(to, 0.55)
		_dashed(from, end, col, 2.0 if it.acao == "ataca" else 1.5, 10.0, 6.0)
		_arrow(end, (end - from).normalized(), col)
	var hits := _count_by_target(list)
	for t in hits:
		_floor_target(t, hits[t])


func _floor_target(t: Combatant, n: int) -> void:
	var r := t.radius + 10.0
	var ring := _floor_circle(t.pos, r, 28)
	ring.append(ring[0])
	draw_polyline(ring, _blood(0.9), 2.0)
	var inner := _floor_circle(t.pos, r * 0.45, 20)
	inner.append(inner[0])
	draw_polyline(inner, _blood(0.7), 1.5)
	for k in 4:
		var d := Vector2.from_angle(k * PI * 0.5)
		draw_line(room._iso(t.pos + d * r * 0.65), room._iso(t.pos + d * r * 1.3), _blood(0.9), 2.0)
	if n > 1:
		var at: Vector2 = room._iso(t.pos + Vector2(r * 1.3, 0)) + Vector2(4, 4)
		_text("×%d" % n, at, 14, _blood())


# --- B: etiqueta sobre a cabeça --------------------------------------------------------------

const ACAO_TEXTO := {"ataca": "ataca", "aproxima_ataca": "avança e ataca", "aproxima": "avança"}


func _draw_b(list: Array) -> void:
	for it in list:
		var head: Vector2 = room._iso(it.unit.pos) + Vector2(0, -HEAD - 30)
		var line1: String = "→ %s" % it.target.name
		var line2: String = ACAO_TEXTO[it.acao]
		var w: float = maxf(FONT.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, FONT.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 14.0
		var box := Rect2(head - Vector2(w * 0.5, 30), Vector2(w, 30))
		draw_rect(box, _paper(0.92))
		draw_rect(Rect2(box.position, Vector2(3, box.size.y)), _blood(1.0 if it.acao != "aproxima" else 0.45))
		draw_rect(box, _ink(0.9), false, 1.0)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-5, 0), head + Vector2(5, 0), head + Vector2(0, 6)]), _paper(0.92))
		draw_string(FONT, box.position + Vector2(8, 13), line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _ink())
		draw_string(FONT, box.position + Vector2(8, 26), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _blood() if it.acao != "aproxima" else _ink(0.6))


# --- C: marcas no alvo e zona de ameaça --------------------------------------------------------

func _draw_c(list: Array) -> void:
	var marks := {}  # alvo -> [[número do inimigo na ordem, ação]]
	for i in list.size():
		var it: Dictionary = list[i]
		var tag: Vector2 = room._iso(it.unit.pos) + Vector2(-46, -HEAD - 4)
		_diamond(tag, str(i + 1), it.acao != "aproxima")
		if not marks.has(it.target):
			marks[it.target] = []
		marks[it.target].append([i + 1, it.acao])
	for t in marks:
		var n: int = marks[t].size()
		var start: Vector2 = room._iso(t.pos) + Vector2(38, -HEAD - 4)  # à direita da barra de vida
		for k in n:
			_diamond(start + Vector2(k * 20.0, 0), str(marks[t][k][0]), marks[t][k][1] != "aproxima")


# Losango de sangue com o número do inimigo na ordem dos turnos (C).
func _diamond(c: Vector2, label: String, strong: bool) -> void:
	var dia := PackedVector2Array([c + Vector2(0, -10), c + Vector2(8, 0), c + Vector2(0, 10), c + Vector2(-8, 0)])
	draw_colored_polygon(dia, _blood(1.0 if strong else 0.4))
	dia.append(dia[0])
	draw_polyline(dia, _ink(0.9), 1.5)
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(FONT, c + Vector2(-w * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _paper())


# --- Alcance (mouse sobre o inimigo, todos os estilos) ----------------------------------------

func _draw_reach(it: Dictionary) -> void:
	var u: Combatant = it.unit
	var weapon := _floor_circle(u.pos, it.alcance_px + u.radius, 48)
	draw_colored_polygon(weapon, _blood(0.12))
	weapon.append(weapon[0])
	draw_polyline(weapon, _blood(0.8), 1.5)
	var walk := _floor_circle(u.pos, it.ameaca_px + u.radius, 64)
	walk.append(walk[0])
	_dashed_poly(walk, _blood(0.6), 1.5)
	var m := 1.0 / maxf(room.cfg.value("pixels_per_meter"), 1.0)
	var label := "arma %d m · andando %d m" % [roundi(it.alcance_px * m), roundi(it.ameaca_px * m)]
	_text(label, room._iso(u.pos + Vector2(0, it.ameaca_px + u.radius)) + Vector2(-60, 16), 12, _paper())


# --- Auxiliares ---------------------------------------------------------------------------------

func _count_by_target(list: Array, actions := false) -> Dictionary:
	var out := {}
	for it in list:
		if actions:
			if not out.has(it.target):
				out[it.target] = []
			out[it.target].append(it.acao)
		elif it.acao != "aproxima":
			out[it.target] = out.get(it.target, 0) + 1
	return out


func _floor_circle(center: Vector2, r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(room._iso(center + Vector2.from_angle(TAU * i / n) * r))
	return pts


func _dashed(a: Vector2, b: Vector2, col: Color, width: float, dash: float, gap: float) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / maxf(len, 0.001)
	var t := 0.0
	while t < len:
		draw_line(a + dir * t, a + dir * minf(t + dash, len), col, width, true)
		t += dash + gap


func _dashed_poly(pts: PackedVector2Array, col: Color, width: float) -> void:
	for i in range(1, pts.size()):
		if i % 2 == 0:
			draw_line(pts[i - 1], pts[i], col, width, true)


func _arrow(at: Vector2, dir: Vector2, col: Color) -> void:
	var side := dir.orthogonal() * 5.0
	draw_colored_polygon(PackedVector2Array([at + dir * 4.0, at - dir * 8.0 + side, at - dir * 8.0 - side]), col)


func _text(s: String, at: Vector2, size: int, col: Color) -> void:
	draw_string_outline(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, _ink(0.9))
	draw_string(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
