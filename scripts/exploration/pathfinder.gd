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

	# Linha reta livre: é a rota mais curta e evita montar o grafo (caso mais comum).
	if not _segment_blocked(from, to, blocks):
		return PackedVector2Array([from, to])

	var pts := PackedVector2Array([from, to])
	for o in obstacles:
		var c := o.grow(radius + CORNER_MARGIN)
		for corner in [c.position, Vector2(c.end.x, c.position.y), c.end, Vector2(c.position.x, c.end.y)]:
			if not _point_blocked(corner, blocks):
				pts.append(corner)

	# A* com visibilidade avaliada sob demanda: só testa a aresta quando ela melhora o custo.
	# (Montar o grafo inteiro era O(n² · obstáculos) a cada chamada e travava o jogo no parque.)
	var n := pts.size()
	var g := PackedFloat32Array()
	g.resize(n)
	g.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var closed := PackedByteArray()
	closed.resize(n)
	var open: Array[int] = [0]
	g[0] = 0.0
	while not open.is_empty():
		var best_k := 0
		var best_f := INF
		for k in open.size():
			var f := g[open[k]] + pts[open[k]].distance_to(to)
			if f < best_f:
				best_f = f
				best_k = k
		var i: int = open[best_k]
		open.remove_at(best_k)
		if i == 1:
			break
		closed[i] = 1
		for j in n:
			if closed[j] == 1 or j == i:
				continue
			var nd := g[i] + pts[i].distance_to(pts[j])
			if nd >= g[j] or _segment_blocked(pts[i], pts[j], blocks):
				continue
			g[j] = nd
			prev[j] = i
			if not open.has(j):
				open.append(j)
	if prev[1] == -1:
		return PackedVector2Array()
	var out := PackedVector2Array()
	var cur := 1
	while cur != -1:
		out.append(pts[cur])
		cur = prev[cur]
	out.reverse()
	return out


# true se o ponto está livre para um personagem de `radius` (fora de todos os obstáculos inflados).
static func is_free(p: Vector2, obstacles: Array[Rect2], radius: float) -> bool:
	for o in obstacles:
		if o.grow(radius).has_point(p):
			return false
	return true


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
	# Rejeição rápida: segmento todo de um lado do retângulo não atravessa o interior.
	if maxf(a.x, b.x) <= r.position.x or minf(a.x, b.x) >= r.end.x or maxf(a.y, b.y) <= r.position.y or minf(a.y, b.y) >= r.end.y:
		return false
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
