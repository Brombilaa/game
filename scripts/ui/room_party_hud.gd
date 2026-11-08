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


# Cartões do grupo em coluna (Preto liso, Léo 08/11/2026): retrato quadrado, duas barras chapadas
# (PV e SAN, com os números dentro) e uma etiqueta; entre os cartões fica a corrente, clicável.
const CARD_X := 8.0
const CARD_TOP := 8.0
const CARD_W := 62.0
const CARD_W_ON := 70.0  # o cartão ativo é maior
const CARD_BELOW := 37.0  # barras e etiqueta embaixo do retrato
const LINK_H := 11.0  # altura do elo entre cartões
const CARD_BG := Color(0.043, 0.043, 0.05)
const BAR_PV := Color(0.82, 0.23, 0.27)
const BAR_SAN := Color(0.31, 0.56, 0.88)
const LINK_ON := Color(0.84, 0.8, 0.7)
const LINK_OFF := Color(0.95, 0.55, 0.2)


# Retângulo do cartão `i` (em pixels da tela): o ativo é mais largo e fica centrado na coluna.
func card_rect(i: int) -> Rect2:
	var y := CARD_TOP
	for k in i:
		y += _card_w(k) + CARD_BELOW + LINK_H
	var w := _card_w(i)
	return Rect2(Vector2(CARD_X + (CARD_W_ON - w) * 0.5, y), Vector2(w, w + CARD_BELOW))


# Retângulo clicável do elo entre o cartão `i` e o `i + 1` (em pixels da tela).
func link_rect(i: int) -> Rect2:
	var c := card_rect(i)
	return Rect2(Vector2(CARD_X + CARD_W_ON * 0.5 - 12.0, c.end.y), Vector2(24.0, LINK_H))


func _card_w(i: int) -> float:
	return CARD_W_ON if room.party[i] == room.player else CARD_W


# Cartão de um membro do grupo (`screen` = onde fica na tela; `to_world` leva a tela para onde se desenha).
func _draw_sheet(font: Font, m: Combatant, i: int, to_world: Transform2D) -> void:
	var active := m == room.player
	var sr := card_rect(i)
	var r := Rect2(to_world * sr.position, sr.size)
	room.draw_rect(r.grow(2.0), Color.BLACK)  # só um contorno preto
	if active:  # anel branco entre dois pretos
		room.draw_rect(r.grow(4.0), Color.BLACK, false, 1.0)
		room.draw_rect(r.grow(3.0), Color.WHITE, false, 1.0)
		room.draw_rect(r.grow(2.0), Color.BLACK, false, 1.0)
	room.draw_rect(r, CARD_BG)
	var face := Rect2(r.position, Vector2(r.size.x, r.size.x))
	room.draw_rect(face, Color(0.16, 0.12, 0.09))
	room.agent_sheets[room.looks.get(m, 0)].draw_portrait(room, face, _hurt(m))
	if not m.is_alive():
		room.draw_rect(face, Color(0.4, 0, 0, 0.5))
	var strip := Rect2(face.position + Vector2(0, face.size.y - 11.0), Vector2(face.size.x, 11.0))
	room.draw_rect(strip, Color(0, 0, 0, 0.62))
	room.draw_string(font, strip.position + Vector2(3, 8.5), m.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, strip.size.x - 12.0, 8, Color(0.95, 0.93, 0.88))
	if m == room.player:  # coroa pequena do líder
		var c := strip.position + Vector2(strip.size.x - 7.0, 5.5)
		room.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, 2.5), c + Vector2(-3.5, -2.5), c + Vector2(-1.7, 0), c + Vector2(0, -3), c + Vector2(1.7, 0), c + Vector2(3.5, -2.5), c + Vector2(3.5, 2.5)]), Color(0.93, 0.8, 0.38))
	var k := 0
	for id in CONDITION_ICONS:  # condições ativas no canto de cima do retrato
		if m.has_condition(id):
			_draw_condition(Rect2(face.position + Vector2(2 + k * 12.0, 2), Vector2(11, 11)), id)
			k += 1
	var y := face.end.y + 3.0
	_draw_flat_bar(font, Rect2(Vector2(r.position.x, y), Vector2(r.size.x, 8.0)), m.pv, m.max_pv, BAR_PV)
	_draw_flat_bar(font, Rect2(Vector2(r.position.x, y + 10.0), Vector2(r.size.x, 7.0)), m.san, m.max_san, BAR_SAN)
	var status := _status_text(m)
	var pill := Rect2(Vector2(r.position.x, y + 19.0), Vector2(r.size.x, 9.0))
	if status[0] != "":
		room.draw_rect(pill, Color(0, 0, 0, 0.7))
		room.draw_string(font, pill.position + Vector2(0, 7.0), status[0], HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 7, status[1])


# Texto e cor da etiqueta de baixo do cartão.
func _status_text(m: Combatant) -> Array:
	if m.dead:
		return ["MORTO", Color(1, 0.45, 0.45)]
	if not m.is_alive():
		return ["CAÍDO", Color(1, 0.45, 0.45)]
	if room.mode == room.Mode.COMBAT:
		if room.turns and room.turns.current == m:
			return ["na vez", Color.WHITE]
		return ["aguardando", Color(0.66, 0.66, 0.7)]
	if m == room.player:
		return ["líder", Color.WHITE]
	if room.unlinked.has(m):
		return ["parado", LINK_OFF]
	return ["seguindo", Color(0.66, 0.66, 0.7)]


# Barra chapada: fundo escuro, preenchimento liso e o número à direita.
func _draw_flat_bar(font: Font, bar: Rect2, value: int, maximum: int, color: Color) -> void:
	room.draw_rect(bar, Color(0.1, 0.1, 0.12))
	if maximum > 0:
		room.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(value) / maximum, 0.0, 1.0), bar.size.y)), color)
	room.draw_string(font, bar.position + Vector2(0, bar.size.y - 1.5), "%d/%d" % [value, maximum], HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x - 2.0, 7, Color.WHITE)


# Corrente entre os cartões: dois elos presos quando o de baixo segue; soltos, com um risco laranja, quando parou.
func _draw_links(font: Font, to_world: Transform2D) -> void:
	var mouse := room.get_viewport().get_mouse_position()
	for i in room.party.size() - 1:
		var sr := link_rect(i)
		var c := to_world * sr.get_center()
		var follower: Combatant = room.party[i + 1]
		var off: bool = room.unlinked.has(follower)
		var col := LINK_OFF if off else LINK_ON
		var d := 3.0 if off else 1.6
		room.draw_arc(c + Vector2(0, -d), 3.2, 0.0, TAU, 16, col, 1.2)
		room.draw_arc(c + Vector2(0, d), 3.2, 0.0, TAU, 16, col, 1.2)
		if off:
			room.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), LINK_OFF, 1.2)
		if sr.has_point(mouse):
			var tip := "Soltar: %s para de seguir" % follower.name if not off else "Prender: %s volta a seguir" % follower.name
			_draw_tooltip(font, to_world * (Vector2(sr.end.x + 4.0 + 90.0, sr.position.y - 4.0)), tip, "")


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


# Retrato ferido quando o PV está baixo (e a pessoa ainda não caiu).
func _hurt(m: Combatant) -> bool:
	return m.pv > 0 and float(m.pv) / maxf(1.0, float(m.max_pv)) <= CharacterSheet.HURT_BELOW


func _draw_face(u: Combatant, rect: Rect2) -> void:
	var i := room.enemies.find(u)
	if i < 0:
		room.agent_sheets[room.looks.get(u, 0)].draw_portrait(room, rect, _hurt(u))
		return
	var variant := room._enemy_variant(i)
	if room.enemy_sheets.has(variant):
		room.enemy_sheets[variant].draw_portrait(room, rect)
	else:
		var tex := PlaceholderArt.character_texture(variant, PlaceholderArt.Dir.SOUTH, 0)
		room.draw_texture_rect_region(tex, rect, Rect2(4, 0, 24, 24))
