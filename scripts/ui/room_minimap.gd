class_name RoomMinimap
extends RefCounted
# Minimapa redondo do HUD da sala (extraído de test_room.gd, M5): regiões descobertas e desenho.
# `_known_rects` e `_place_label` ficam na sala, porque as áreas derivadas (parque) os substituem.

var room: TestRoom  # a sala de teste (test_room.gd)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Minimapa: radar redondo visto de cima, centrado no controlado (Léo escolheu, 29/10/2026).
# Só desenha o que o grupo já descobriu: o outro lado de uma porta nunca aberta não aparece,
# e inimigos só aparecem enquanto estão à vista.
const RADAR_CENTER := Vector2(898, 62)  # pixels da tela
const RADAR_RADIUS := 40.0  # área do mapa; o aro da moldura A fica 6 px para fora
const RADAR_SCALE := 0.08  # pixels do radar por unidade da sala
const RADAR_GRID := 64.0  # um losango do chão, em unidades da sala
const RADAR_INK := Color(0.07, 0.05, 0.04)
const RADAR_FLOOR := Color(0.25, 0.2, 0.15)
const RADAR_WALL := Color(0.84, 0.76, 0.6)
const RADAR_DOOR := Color(0.66, 0.4, 0.2)
const RADAR_ENEMY := Color(0.86, 0.2, 0.2)


# Regiões da sala já vistas pelo grupo (0 e 1: os lados da porta; ver _region).
func _update_discovered() -> void:
	for m in room.party:
		if not m.dead and room._region(m.pos) >= 0:
			room.discovered[room._region(m.pos)] = true
	if room.door_open:
		room.discovered[0] = true
		room.discovered[1] = true


func _map_poly(to_map: Callable, r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([to_map.call(r.position), to_map.call(Vector2(r.end.x, r.position.y)), to_map.call(r.end), to_map.call(Vector2(r.position.x, r.end.y))])


# Ângulo (na planta) para onde o personagem olha, a partir da direção do sprite na tela.
func _facing_angle(m: Combatant) -> float:
	var screen := {
		CharacterSheet.Dir.E: Vector2(1, 0), CharacterSheet.Dir.SE: Vector2(1, 0.5), CharacterSheet.Dir.S: Vector2(0, 1),
		CharacterSheet.Dir.SW: Vector2(-1, 0.5), CharacterSheet.Dir.W: Vector2(-1, 0), CharacterSheet.Dir.NW: Vector2(-1, -0.5),
		CharacterSheet.Dir.N: Vector2(0, -1), CharacterSheet.Dir.NE: Vector2(1, -0.5),
	}
	var v: Vector2 = screen.get(room.facing8.get(m, CharacterSheet.Dir.SE), Vector2(1, 0.5))
	return room._uniso(v * 100.0).angle()


func _draw_minimap(font: Font, to_world: Transform2D) -> void:
	var center := to_world * RADAR_CENTER
	var focus := room.player
	var to_map := func(p: Vector2) -> Vector2: return center + (p - focus.pos) * RADAR_SCALE
	var disc := PackedVector2Array()
	for k in 64:
		disc.append(center + Vector2.RIGHT.rotated(TAU * k / 64.0) * RADAR_RADIUS)
	var known := room._known_rects()
	# Recorta um retângulo da sala pelo que já foi descoberto e pelo círculo do radar.
	var fill := func(r: Rect2, color: Color) -> void:
		for k: Rect2 in known:
			var part := r.intersection(k)
			if part.has_area():
				for piece in Geometry2D.intersect_polygons(_map_poly(to_map, part), disc):
					room.draw_colored_polygon(piece, color)
	var line := func(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([to_map.call(a), to_map.call(b)]), disc):
			room.draw_polyline(seg, color, width)

	# Fundo escuro no círculo inteiro do aro.
	room.draw_circle(center, RADAR_RADIUS + 6, Color(0.04, 0.03, 0.02, 0.92))
	for c in known:
		fill.call(c, RADAR_FLOOR)
		# Grade fraca de losangos do chão, só no que já foi visto.
		var x := ceilf(c.position.x / RADAR_GRID) * RADAR_GRID
		while x < c.end.x:
			line.call(Vector2(x, c.position.y), Vector2(x, c.end.y), Color(1, 1, 1, 0.05), 1.0)
			x += RADAR_GRID
		var y := ceilf(c.position.y / RADAR_GRID) * RADAR_GRID
		while y < c.end.y:
			line.call(Vector2(c.position.x, y), Vector2(c.end.x, y), Color(1, 1, 1, 0.05), 1.0)
			y += RADAR_GRID
	for c: Cover in room.covers:
		if c.kind == "full":
			fill.call(c.rect, RADAR_WALL.darkened(0.25))
		else:
			fill.call(c.rect, RADAR_FLOOR.lightened(0.25))
	for w in room.walls:
		fill.call(w, RADAR_WALL)
	if room.door_open:
		fill.call(room.door, RADAR_FLOOR)
		var hinge: Vector2 = room.door.position + Vector2(room.door.size.x * 0.5, 0)
		line.call(hinge, hinge + Vector2(room.door.size.y * 0.7, room.door.size.y * 0.7), RADAR_DOOR, 1.5)
	elif not known.is_empty():
		fill.call(room.door, RADAR_DOOR)
	for k in range(1, 3):
		room.draw_arc(center, RADAR_RADIUS * k / 3.0, 0.0, TAU, 48, Color(0.83, 0.67, 0.31, 0.12), 1.0)

	# Inimigos: só os que estão à vista agora. Fora do alcance do radar, viram seta na borda.
	for e in room.enemies:
		if not (e.is_alive() and room._visible(e.pos)):
			continue
		var at: Vector2 = to_map.call(e.pos)
		if at.distance_to(center) <= RADAR_RADIUS - 5:
			room.draw_circle(at, 3.2, RADAR_INK)
			room.draw_circle(at, 2.3, RADAR_ENEMY)
		else:
			var d := (at - center).normalized()
			var tip := center + d * (RADAR_RADIUS - 3)
			var arrow := PackedVector2Array([tip, tip - d * 7 + d.orthogonal() * 4, tip - d * 7 - d.orthogonal() * 4])
			room.draw_colored_polygon(arrow, RADAR_ENEMY)
			arrow.append(arrow[0])
			room.draw_polyline(arrow, RADAR_INK, 1.0)
	for m in room.party:
		if m == focus:
			continue
		var at: Vector2 = to_map.call(m.pos)
		if at.distance_to(center) > RADAR_RADIUS - 4:
			continue
		if m.dead:
			continue
		if m.is_alive():
			room.draw_circle(at, 3.2, RADAR_INK)
			room.draw_circle(at, 2.3, PlaceholderArt.color("destaque"))
		else:  # caído: X cinza até ser reanimado
			room.draw_line(at + Vector2(-2.5, -2.5), at + Vector2(2.5, 2.5), Color(0.6, 0.58, 0.54), 1.5)
			room.draw_line(at + Vector2(-2.5, 2.5), at + Vector2(2.5, -2.5), Color(0.6, 0.58, 0.54), 1.5)
	# Controlado: seta no centro, apontando para onde olha.
	var dir := Vector2.RIGHT.rotated(_facing_angle(focus))
	var side := dir.orthogonal()
	var tri := PackedVector2Array([center + dir * 6.5, center - dir * 4 + side * 4.5, center - dir * 2 , center - dir * 4 - side * 4.5])
	room.draw_colored_polygon(tri, PlaceholderArt.color("destaque"))
	tri.append(tri[0])
	room.draw_polyline(tri, RADAR_INK, 1.0)

	# Moldura A: aro de bronze, filete interno e N, L, S e O em medalhões nos pontos cardeais.
	var rim := RADAR_RADIUS + 6
	room.draw_arc(center, rim, 0.0, TAU, 72, room.party_hud.FRAME_OUTER, 2.5)
	room.draw_arc(center, RADAR_RADIUS + 1, 0.0, TAU, 72, room.party_hud.FRAME_INNER, 1.0)
	for c in [["N", Vector2.UP], ["L", Vector2.RIGHT], ["S", Vector2.DOWN], ["O", Vector2.LEFT]]:
		var at: Vector2 = center + c[1] * rim
		room.draw_circle(at, 8.5, Color(0.07, 0.047, 0.031))
		room.draw_arc(at, 8.5, 0.0, TAU, 24, room.party_hud.FRAME_OUTER, 1.0)
		room.draw_string(font, at + Vector2(-8.5, 3.5), c[0], HORIZONTAL_ALIGNMENT_CENTER, 17, 10, room.party_hud.FRAME_ACCENT)
	# Placa com o local e o modo logo abaixo.
	var plate := Rect2(center + Vector2(-50, rim + 9), Vector2(100, 30))
	room.party_hud._draw_frame(plate)
	room.draw_string(font, plate.position + Vector2(0, 12), room._place_label(), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 8, Color(0.73, 0.65, 0.52))
	room.draw_string(font, plate.position + Vector2(0, 24), HudText.mode_label(room.mode == room.Mode.COMBAT), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 9, Color(0.93, 0.89, 0.8))
