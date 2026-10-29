class_name Pathfinder
extends RefCounted
# Pathfinding sem grade: grafo de visibilidade sobre os cantos dos obstáculos inflados
# pelo raio do personagem, com A* (AStar2D). Rotas em qualquer ângulo, desviando de paredes.

const CORNER_MARGIN := 1.5


# Retorna os pontos da rota, começando em `from`. Vazio se `from` ou `to` estiverem
# bloqueados ou se não houver caminho (destino inacessível).
func find_path(from: Vector2, to: Vector2, obstacles: Array[Rect2], radius: float) -> PackedVector2Array:
	var blocks: Array[Rect2] = []
	for o in obstacles:
		blocks.append(o.grow(radius))
	if _point_blocked(from, blocks) or _point_blocked(to, blocks):
		return PackedVector2Array()

	var astar := AStar2D.new()
	astar.add_point(0, from)
	astar.add_point(1, to)
	var next_id := 2
	for o in obstacles:
		var c := o.grow(radius + CORNER_MARGIN)
		var corners := [c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]
		for corner in corners:
			if not _point_blocked(corner, blocks):
				astar.add_point(next_id, corner)
				next_id += 1

	var ids := astar.get_point_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if not _segment_blocked(astar.get_point_position(ids[i]), astar.get_point_position(ids[j]), blocks):
				astar.connect_points(ids[i], ids[j])
	return astar.get_point_path(0, 1)


func _point_blocked(p: Vector2, blocks: Array[Rect2]) -> bool:
	for b in blocks:
		if b.has_point(p):
			return true
	return false


func _segment_blocked(a: Vector2, b: Vector2, blocks: Array[Rect2]) -> bool:
	for r in blocks:
		if segment_crosses_rect(a, b, r):
			return true
	return false


# Liang-Barsky: true se o segmento atravessa o interior do retângulo.
# Encostar na borda ou passar por um canto não conta como bloqueio.
static func segment_crosses_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var p := [-d.x, d.x, -d.y, d.y]
	var q := [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	var t0 := 0.0
	var t1 := 1.0
	for i in 4:
		var pv: float = p[i]
		var qv: float = q[i]
		if is_zero_approx(pv):
			if qv <= 0.0:
				return false
		else:
			var t := qv / pv
			if pv < 0.0:
				if t > t1:
					return false
				t0 = maxf(t0, t)
			else:
				if t < t0:
					return false
				t1 = minf(t1, t)
	return t0 < t1


# Linha de visão entre dois pontos: bloqueada por qualquer obstáculo atravessado.
static func has_line_of_sight(a: Vector2, b: Vector2, obstacles: Array[Rect2]) -> bool:
	for r in obstacles:
		if segment_crosses_rect(a, b, r):
			return false
	return true
