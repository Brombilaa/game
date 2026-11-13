class_name PathfinderGrade
extends Pathfinder
# Caminho em grade para os cenários 3D da missão 1. Os mapas de colisão destes cenários têm centenas de retângulos
# (a fazenda passa de 800, um para cada moita), e o grafo de visibilidade do Pathfinder fica lento demais com isso.
# Aqui os obstáculos fixos (as paredes da sala) viram uma grade com A* nativo (AStarGrid2D), uma por raio de
# personagem; os que mudam (gente) entram na hora e saem depois. A rota da grade é então esticada: cada trecho vai
# direto até o ponto mais distante que ainda se enxerga, como no Pathfinder, para não andar em degraus.

const CELULA := 8.0  # lado da célula, em unidades da sala (12,5 cm)

var estaticos: Array[Rect2] = []
var tamanho := Vector2.ZERO
var _fixos := {}  # Rect2 -> true (para separar o que é fixo do que é gente)
var _grades := {}  # raio -> AStarGrid2D


func configurar(paredes: Array[Rect2], tamanho_sala: Vector2) -> void:
	estaticos = paredes.duplicate()
	tamanho = tamanho_sala
	_fixos.clear()
	for r in estaticos:
		_fixos[r] = true
	_grades.clear()


func _compute_path(from: Vector2, to: Vector2, obstacles: Array[Rect2], radius: float) -> PackedVector2Array:
	var blocks: Array[Rect2] = []
	var moveis: Array[Rect2] = []
	for o in obstacles:
		blocks.append(o.grow(radius))
		if not _fixos.has(o):
			moveis.append(o.grow(radius))
	if _point_blocked(from, blocks) or _point_blocked(to, blocks):
		return PackedVector2Array()
	if not _segment_blocked(from, to, blocks):
		return PackedVector2Array([from, to])
	var g := _grade(radius)
	var marcadas: Array[Vector2i] = []
	for r in moveis:
		for c in _celulas(r, g):
			if not g.is_point_solid(c):
				g.set_point_solid(c, true)
				marcadas.append(c)
	var a := _livre_perto(g, _celula(from))
	var b := _livre_perto(g, _celula(to))
	var ids: Array[Vector2i] = []
	if a != Vector2i(-1, -1) and b != Vector2i(-1, -1):
		ids = g.get_id_path(a, b)
	for c in marcadas:
		g.set_point_solid(c, false)
	if ids.is_empty():
		return PackedVector2Array()
	var pts := PackedVector2Array([from])
	for i in range(1, ids.size() - 1):
		pts.append((Vector2(ids[i]) + Vector2(0.5, 0.5)) * CELULA)
	pts.append(to)
	return _esticar(pts, blocks)


# Puxa o fio: de cada ponto vai direto ao mais distante que ainda se enxerga sem atravessar obstáculo.
func _esticar(pts: PackedVector2Array, blocks: Array[Rect2]) -> PackedVector2Array:
	var caixa := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		caixa = caixa.expand(p)
	caixa = caixa.grow(CELULA * 2.0)
	var perto: Array[Rect2] = []
	for r in blocks:
		if r.intersects(caixa):
			perto.append(r)
	var out := PackedVector2Array([pts[0]])
	var i := 0
	while i < pts.size() - 1:
		var j := i + 1
		while j + 1 < pts.size() and not _segment_blocked(pts[i], pts[j + 1], perto):
			j += 1
		out.append(pts[j])
		i = j
	return out


func _grade(radius: float) -> AStarGrid2D:
	var chave := snappedf(radius, 0.5)
	if _grades.has(chave):
		return _grades[chave]
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, ceili(tamanho.x / CELULA), ceili(tamanho.y / CELULA))
	g.cell_size = Vector2.ONE
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	for r in estaticos:
		for c in _celulas(r.grow(radius), g):
			g.set_point_solid(c, true)
	_grades[chave] = g
	return g


# Células cujo centro cai dentro de `r`.
func _celulas(r: Rect2, g: AStarGrid2D) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0 := maxi(0, ceili(r.position.x / CELULA - 0.5))
	var y0 := maxi(0, ceili(r.position.y / CELULA - 0.5))
	var x1 := mini(g.region.size.x - 1, floori(r.end.x / CELULA - 0.5))
	var y1 := mini(g.region.size.y - 1, floori(r.end.y / CELULA - 0.5))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out


func _celula(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELULA), floori(p.y / CELULA))


# O ponto está livre, mas a célula dele pode ter caído no obstáculo vizinho: usa a célula livre mais próxima.
func _livre_perto(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	for anel in 3:
		for dy in range(-anel, anel + 1):
			for dx in range(-anel, anel + 1):
				if maxi(absi(dx), absi(dy)) != anel:
					continue
				var k := c + Vector2i(dx, dy)
				if g.is_in_boundsv(k) and not g.is_point_solid(k):
					return k
	return Vector2i(-1, -1)
