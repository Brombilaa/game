class_name RoomPartyHud
extends RefCounted
# Fichas do grupo, ordem dos turnos, moldura A e dicas do HUD da sala (extraído de test_room.gd, M5).
# Só desenha: o estado vem da sala (`room`). Desenhado em pixels da tela (960×540).

var room: TestRoom  # a sala de teste (test_room.gd)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


const SHEET_SCALE := 0.75  # fichas do grupo 25% menores que o desenho em tamanho cheio (pedido do Léo, 30/10/2026)
const SHEET_SIZE := Vector2(223, 75) * SHEET_SCALE  # retrato e ficha lado a lado
const HUD_BRONZE := Color(0.43, 0.34, 0.24)

# Moldura A, bronze gótico (Léo escolheu entre três modelos, 30/10/2026).
const FRAME_FILL := Color(0.063, 0.043, 0.031, 0.93)
const FRAME_OUTER := Color(0.612, 0.455, 0.22)
const FRAME_INNER := Color(0.353, 0.255, 0.149)
const FRAME_ACCENT := Color(0.839, 0.678, 0.361)
const FRAME_ENEMY := Color(0.639, 0.149, 0.165)
const CONDITION_ICONS := {  # ordem e cor dos ícones de condição embaixo do retrato
	"sangrando": Color(0.85, 0.2, 0.2), "atordoado": Color(0.95, 0.82, 0.35),
	"em_chamas": Color(0.95, 0.5, 0.15), "envenenado": Color(0.5, 0.75, 0.35),
}


# Moldura A: placa escura, filete duplo de bronze e cantoneiras com voluta e losango.
# `s` encolhe os enfeites junto com a peça (fichas usam SHEET_SCALE).
func _draw_frame(r: Rect2, enemy := false, s := 1.0) -> void:
	var outer := FRAME_ENEMY if enemy else FRAME_OUTER
	var accent := FRAME_ENEMY if enemy else FRAME_ACCENT
	room.draw_rect(r, FRAME_FILL)
	room.draw_rect(r.grow(-1.0 * s), outer, false, 1.0)
	room.draw_rect(r.grow(-4.0 * s), FRAME_INNER, false, 0.5)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o: Vector2 = r.position + corner * r.size
		var d := Vector2(1.0 - corner.x * 2.0, 1.0 - corner.y * 2.0) * s  # para dentro da peça
		var arc := PackedVector2Array()
		for k in 7:  # voluta: curva de (1, 9) a (9, 1) puxada para o canto
			var t := k / 6.0
			var p := Vector2(1, 9).lerp(Vector2(1, 1), t).lerp(Vector2(1, 1).lerp(Vector2(9, 1), t), t)
			arc.append(o + p * d)
		room.draw_polyline(arc, accent, 0.5)
		room.draw_polyline(PackedVector2Array([o + Vector2(4, 11) * d, o + Vector2(4, 4) * d, o + Vector2(11, 4) * d]), accent, 0.5)
		_draw_diamond(o + Vector2(3.25, 3.25) * d, 2.5 * s, accent)
	if r.size.x > 80:  # losango no meio das bordas de cima e de baixo
		_draw_diamond(Vector2(r.get_center().x, r.position.y + 1), 3.5 * s, accent)
		_draw_diamond(Vector2(r.get_center().x, r.end.y - 1), 3.5 * s, accent)


func _draw_diamond(c: Vector2, r: float, color: Color) -> void:
	room.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


# Ficha de um membro do grupo: retrato numa moldura e, ao lado, nome, PV e SAN em outra.
# As medidas são do desenho em tamanho cheio e passam por `_k` (SHEET_SCALE).
func _draw_sheet(font: Font, m: Combatant, pos: Vector2) -> void:
	var active := m == room.player
	var face_box := Rect2(pos, Vector2(room._k(75), room._k(75)))
	var info := Rect2(pos + Vector2(room._k(73), room._k(10)), Vector2(room._k(150), room._k(56)))
	_draw_frame(info, false, SHEET_SCALE)
	_draw_frame(face_box, false, SHEET_SCALE)
	var face := face_box.grow(-room._k(6))
	room.draw_rect(face, Color(0.16, 0.12, 0.09))
	room.agent_sheets[room.looks.get(m, 0)].draw_portrait(room, face)
	if not m.is_alive():
		room.draw_rect(face, Color(0.4, 0, 0, 0.5))
	if active:
		room.draw_rect(face_box.grow(-room._k(1)), FRAME_ACCENT, false, 1.5)
	var left := info.position.x + room._k(11)
	room.draw_string(font, Vector2(left, info.position.y + room._k(17)), m.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, room._fs(13), FRAME_ACCENT if active else Color(0.91, 0.87, 0.79))
	var status := ""
	if m.dead:
		status = "MORTO"
	elif not m.is_alive():
		status = "CAÍDO"
	elif room.mode == room.Mode.COMBAT and room.turns and room.turns.current == m:
		status = "na vez"
	elif room.mode == room.Mode.COMBAT:
		status = "aguardando"
	elif m.crouched:
		status = "agachado"
	if status != "":
		room.draw_string(font, Vector2(left, info.position.y + room._k(17)), status, HORIZONTAL_ALIGNMENT_RIGHT, info.size.x - room._k(22), room._fs(10), Color(1, 0.45, 0.45) if status in ["MORTO", "CAÍDO"] else Color(0.66, 0.6, 0.49))
	_draw_bar(font, Vector2(left - room._k(3), info.position.y + room._k(22)), "pv", m.pv, m.max_pv, Color(0.74, 0.16, 0.16), Color(0.45, 0.07, 0.07))
	_draw_bar(font, Vector2(left - room._k(3), info.position.y + room._k(37)), "san", m.san, m.max_san, Color(0.33, 0.52, 0.8), Color(0.15, 0.26, 0.5))
	var k := 0
	for id in CONDITION_ICONS:  # condições ativas embaixo do retrato
		if m.has_condition(id):
			_draw_condition(Rect2(pos + Vector2(room._k(1) + k * room._k(21), room._k(76)), Vector2(room._k(20), room._k(20))), id)
			k += 1


# Ícone de condição: quadrado escuro com o símbolo na cor da condição.
func _draw_condition(r: Rect2, id: String) -> void:
	var color: Color = CONDITION_ICONS[id]
	room.draw_rect(r, FRAME_FILL)
	room.draw_rect(r, color, false, 1.0)
	if ItemIcons.CONDITION_ART.has(id):
		room.draw_texture_rect(ItemIcons.CONDITION_ART[id], r.grow(-r.size.x * 0.04), false)
		return
	var c := r.get_center()
	var u := r.size.x / 15.0
	match id:
		"sangrando":  # gota
			room.draw_circle(c + Vector2(0, 1.5) * u, 3.0 * u, color)
			room.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, 0.5) * u, c + Vector2(0, -5) * u, c + Vector2(2.6, 0.5) * u]), color)
		"atordoado":  # estrela de quatro pontas
			room.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5) * u, c + Vector2(1.2, -1.2) * u, c + Vector2(5, 0) * u, c + Vector2(1.2, 1.2) * u,
				c + Vector2(0, 5) * u, c + Vector2(-1.2, 1.2) * u, c + Vector2(-5, 0) * u, c + Vector2(-1.2, -1.2) * u]), color)
		"em_chamas":  # chama
			room.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, 4) * u, c + Vector2(-3.5, 0) * u, c + Vector2(-1, -2.5) * u, c + Vector2(0, -5.5) * u,
				c + Vector2(1.5, -2) * u, c + Vector2(3.5, -0.5) * u, c + Vector2(3.5, 4) * u]), color)
		_:  # envenenado: bolhas
			room.draw_circle(c + Vector2(-1.5, 1.5) * u, 2.6 * u, color)
			room.draw_circle(c + Vector2(2.2, -2.2) * u, 1.6 * u, color)


# Barra com ícone (coração de PV, olho de SAN), fundo chanfrado, degradê, divisões a cada 5 pontos e brilho.
func _draw_bar(font: Font, at: Vector2, kind: String, value: int, maximum: int, color: Color, shade: Color) -> void:
	var icon := at + Vector2(room._k(7), room._k(7))
	if kind == "pv":
		var h := room._k(5.0)
		room.draw_circle(icon + Vector2(-h * 0.5, -h * 0.35), h * 0.6, color)
		room.draw_circle(icon + Vector2(h * 0.5, -h * 0.35), h * 0.6, color)
		room.draw_colored_polygon(PackedVector2Array([icon + Vector2(-h * 1.05, -h * 0.1), icon + Vector2(h * 1.05, -h * 0.1), icon + Vector2(0, h * 1.1)]), color)
	else:
		var w := room._k(6.5)
		var eye := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			eye.append(icon + Vector2(lerpf(-w, w, t), -sin(t * PI) * room._k(3.4)))
		for i in 13:
			var t := 1.0 - i / 12.0
			eye.append(icon + Vector2(lerpf(-w, w, t), sin(t * PI) * room._k(3.4)))
		room.draw_polyline(eye + PackedVector2Array([eye[0]]), color, 1.0)
		room.draw_circle(icon, room._k(2.2), color)
	var bar := Rect2(at + Vector2(room._k(18), room._k(1)), Vector2(room._k(114), room._k(12)))
	room.draw_rect(Rect2(bar.position - Vector2(1, 1), bar.size + Vector2(2, 2)), Color(0.04, 0.03, 0.03))
	room.draw_rect(bar, Color(0.12, 0.1, 0.09))
	var fill := bar.size.x * clampf(float(value) / maxf(maximum, 1), 0.0, 1.0) if maximum > 0 else 0.0
	if fill > 0.0:
		room.draw_rect(Rect2(bar.position, Vector2(fill, bar.size.y)), shade)
		room.draw_rect(Rect2(bar.position, Vector2(fill, bar.size.y * 0.55)), color)
		room.draw_rect(Rect2(bar.position + Vector2(0, 1), Vector2(fill, 1)), color.lightened(0.35))
	if maximum > 0:
		var step := 5
		for n in range(step, maximum, step):
			var x := bar.position.x + bar.size.x * n / maximum
			room.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.45), 0.5)
	room.draw_rect(bar, HUD_BRONZE, false, 0.5)
	room.draw_string(font, bar.position + Vector2(room._k(5), bar.size.y - room._k(2.5)), "%d/%d" % [value, maximum], HORIZONTAL_ALIGNMENT_LEFT, -1, room._fs(9), Color(0.96, 0.93, 0.85))


# Faixa no topo: retratos emoldurados na ordem da rodada, inimigos em vermelho, o da vez sublinhado.
func _draw_turn_order(font: Font, to_world: Transform2D) -> void:
	var units: Array[Combatant] = []
	for u in room.turns.order:
		if u.is_alive():
			units.append(u)
	var step := 56.0
	var width := units.size() * step + 14
	var screen_pos := Vector2(480 - width * 0.5, 8)
	var pos := to_world * screen_pos
	var mouse := room.get_viewport().get_mouse_position()
	var hovered: Combatant = null
	var hover_rect := Rect2()
	_draw_frame(Rect2(pos, Vector2(width, 66)))
	for k in units.size():
		var u := units[k]
		var cell := Rect2(pos + Vector2(10 + k * step, 7), Vector2(50, 50))
		_draw_frame(cell, u.side == Combatant.Side.ENEMY)
		var face := cell.grow(-4)
		room.draw_rect(face, Color(0.16, 0.12, 0.09))
		_draw_face(u, face)
		if u == room.turns.current:
			room.draw_rect(Rect2(cell.position + Vector2(5, 52), Vector2(40, 2)), FRAME_ACCENT)
		if Rect2(screen_pos + Vector2(10 + k * step, 7), cell.size).has_point(mouse):
			hovered = u
			hover_rect = cell
			room.draw_rect(face, Color(1, 1, 1, 0.18))
	room.draw_string(font, pos + Vector2(0, 80), "RODADA %d" % room.turns.round_number, HORIZONTAL_ALIGNMENT_CENTER, width, 9, Color(0.72, 0.65, 0.52))
	if hovered:  # nome embaixo do retrato sob o mouse
		_draw_tooltip(font, Vector2(hover_rect.get_center().x, hover_rect.end.y + 26), hovered.name.to_upper(), "", hovered.side == Combatant.Side.ENEMY)


# Etiqueta flutuante centrada em `top_center`, com uma segunda linha opcional.
func _draw_tooltip(font: Font, top_center: Vector2, title: String, detail: String, enemy := false) -> void:
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	if detail != "":
		w = maxf(w, font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x)
	var tip := Rect2(top_center - Vector2(w * 0.5 + 7, 0), Vector2(w + 14, 31 if detail != "" else 19))
	room.draw_rect(tip, Color(0.05, 0.04, 0.03, 0.96))
	room.draw_rect(tip, FRAME_ENEMY if enemy else FRAME_ACCENT, false, 1.0)
	room.draw_string(font, tip.position + Vector2(0, 13), title, HORIZONTAL_ALIGNMENT_CENTER, tip.size.x, 12, Color(0.93, 0.89, 0.8))
	if detail != "":
		room.draw_string(font, tip.position + Vector2(0, 26), detail, HORIZONTAL_ALIGNMENT_CENTER, tip.size.x, 9, Color(0.72, 0.65, 0.52))


func _draw_face(u: Combatant, rect: Rect2) -> void:
	var i := room.enemies.find(u)
	if i < 0:
		room.agent_sheets[room.looks.get(u, 0)].draw_portrait(room, rect)
		return
	var variant := room._enemy_variant(i)
	if room.enemy_sheets.has(variant):
		room.enemy_sheets[variant].draw_portrait(room, rect)
	else:
		var tex := PlaceholderArt.character_texture(variant, PlaceholderArt.Dir.SOUTH, 0)
		room.draw_texture_rect_region(tex, rect, Rect2(4, 0, 24, 24))
