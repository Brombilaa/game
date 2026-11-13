class_name Scenario
extends RefCounted
## Cenário de uma missão em dados (`data/cenarios/<id>.json`): fundo pintado, colisões, pistas e gatilhos.
## Coordenadas em unidades da sala (64 = um losango); a projeção do fundo vem do próprio arquivo.

const DIR := "res://data/cenarios/"

var id := ""
var size := Vector2.ZERO
var backdrop_path := ""
var backdrop_origin := Vector2.ZERO  # ponto da imagem (px) onde cai o ponto (0, 0) da sala
var extended_path := ""  # fundo estendido além do mapa (opcional)
var extended_pos := Vector2.ZERO  # canto da imagem estendida, em px do fundo
var screen_scale := Vector2.ZERO  # px de tela por unidade da sala, em x e em y
var party_start: Array[Vector2] = []
var npcs := {}  # id -> posição
var colliders := {}  # id -> Rect2
var clues := {}  # id -> {"pos", "raio", "ordem", "texto", ...}
var triggers := {}  # id -> gatilho
var occluders: Array[Dictionary] = []  # {"id", "arquivo", "pos" (na imagem do fundo), "rect" (colisão de mesmo id)}
var errors: PackedStringArray = []


static func load_id(scenario_id: String) -> Scenario:
	var s := Scenario.new()
	var path := "%s%s.json" % [DIR, scenario_id]
	if not FileAccess.file_exists(path):
		s.errors.append("cenário não encontrado: " + path)
		return s
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		s.errors.append("JSON inválido: " + path)
		return s
	s._parse(data)
	return s


func ok() -> bool:
	return errors.is_empty()


## Ponto da sala -> ponto da imagem de fundo (e da tela, com a câmera na origem do fundo).
func to_backdrop(p: Vector2) -> Vector2:
	var k := screen_scale / 64.0
	return backdrop_origin + Vector2((p.x - p.y) * k.x, (p.x + p.y) * k.y)


## Ponto da imagem de fundo -> ponto da sala (no nível do chão).
func from_backdrop(s: Vector2) -> Vector2:
	var k := screen_scale / 64.0
	var d := s - backdrop_origin
	var a := d.x / k.x
	var b := d.y / k.y
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


func collider_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in colliders.values():
		out.append(r)
	return out


## Pistas liberadas: as de ordem 1 sempre; as de ordem 2 só depois de todas as de ordem 1 vistas.
func available_clues(seen: Array) -> Array[String]:
	var first_done := true
	for cid in clues:
		if clues[cid]["ordem"] == 1 and not seen.has(cid):
			first_done = false
	var out: Array[String] = []
	for cid in clues:
		if clues[cid]["ordem"] == 1 or first_done:
			out.append(cid)
	return out


## Pista ao alcance de `pos` (a mais próxima dentro do raio), ou "".
func clue_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for cid in clues:
		var d := pos.distance_to(clues[cid]["pos"])
		if d <= clues[cid]["raio"] and d < best_d:
			best = cid
			best_d = d
	return best


## Gatilhos que disparam depois de a pista `clue_id` ser vista.
func triggers_after(clue_id: String) -> Array:
	var out := []
	for tid in triggers:
		if triggers[tid]["apos"] == clue_id:
			out.append(triggers[tid])
	return out


## O ponto `p` (no chão) está na frente do retângulo `r` para quem olha da câmera (+x e +y)?
## Nos casos ambíguos (de lado), decide pela soma x + y, como a ordem de desenho do resto da sala.
static func in_front(p: Vector2, r: Rect2) -> bool:
	var front := p.y >= r.end.y or p.x >= r.end.x
	var back := p.y <= r.position.y or p.x <= r.position.x
	if front and not back:
		return true
	if back and not front:
		return false
	var c := r.get_center()
	return p.x + p.y >= c.x + c.y


func _parse(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	size = _vec(data.get("tamanho"))
	var bg: Dictionary = data.get("fundo", {})
	backdrop_path = str(bg.get("arquivo", ""))
	backdrop_origin = _vec(bg.get("origem"))
	var ext: Dictionary = bg.get("estendido", {})
	extended_path = str(ext.get("arquivo", ""))
	extended_pos = _vec(ext.get("pos"))
	screen_scale = _vec(bg.get("escala_tela"))
	if id == "" or size == Vector2.ZERO or screen_scale == Vector2.ZERO:
		errors.append("faltam id, tamanho ou escala_tela")
	var start: Dictionary = data.get("inicio", {})
	for p in start.get("grupo", []):
		party_start.append(_vec(p))
	for n in start.get("npcs", []):
		npcs[n["id"]] = _vec(n["pos"])
	for c in data.get("colisoes", []):
		var r: Array = c["rect"]
		var rect := Rect2(r[0], r[1], r[2], r[3])
		if not Rect2(Vector2.ZERO, size).encloses(rect):
			errors.append("colisão fora do plano: " + str(c["id"]))
		colliders[c["id"]] = rect
	for c in data.get("pistas", []):
		clues[c["id"]] = {"pos": _vec(c["pos"]), "raio": float(c["raio"]), "ordem": int(c["ordem"]), "texto": str(c["texto"]), "inspecao": str(c.get("inspecao", "")), "bolinha": _vec(c.get("bolinha", [0, -60])), "areas": c.get("areas", []), "destaque": c.get("destaque", {})}
	for o in data.get("oclusores", []):
		if not colliders.has(o["id"]):
			errors.append("oclusor sem colisão de mesmo id: " + str(o["id"]))
			continue
		occluders.append({"id": o["id"], "arquivo": str(o["arquivo"]), "pos": _vec(o["pos"]), "rect": colliders[o["id"]]})
	for g in data.get("gatilhos", []):
		if not clues.has(g["apos"]):
			errors.append("gatilho %s depende de pista inexistente: %s" % [g["id"], g["apos"]])
		triggers[g["id"]] = g


static func _vec(a: Variant) -> Vector2:
	if typeof(a) == TYPE_ARRAY and a.size() == 2:
		return Vector2(a[0], a[1])
	return Vector2.ZERO
