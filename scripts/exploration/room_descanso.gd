class_name RoomDescanso
extends RefCounted
# Ponto de descanso na sala (zona segura, GDD #25): o jogador clica no objeto do ponto (a Van do parque) e o DescansoPanel abre com as
# opções; sem tecla (Léo, 20/11). Longe do ponto, o grupo anda até ele e o painel abre ao chegar. Descansar cura o grupo
# (DescansoRules), salva o jogo e não gasta tempo; o Miguel também prepara rituais ali (RitualRules.prepare, números provisórios
# em combat.json > preparo). Os pontos vêm dos dados do lugar (`descansos`: [{"id", "nome", "ret": [x, y, w, h] (onde o grupo
# precisa estar), "clique": id de uma colisão do cenário (o corpo do objeto que responde ao clique)}], lidos por Scenario).
# Léo (20/11): a Van do parque é o ponto de descanso da missão 1.

const BODY_HEIGHT := 100.0  # quanto o objeto sobe na tela acima da colisão no chão (px do desenho)

var room: Node  # TestRoom (Parque tem o cenário, o caminho e o rótulo que isto usa)
var points: Array[Dictionary] = []  # {"id", "nome", "ret": Rect2, "clique": id da colisão}
var pending := ""  # id do ponto até onde o grupo anda para abrir o painel ao chegar


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Lê `descansos` do JSON do lugar.
func load_points(list: Array) -> void:
	points.clear()
	pending = ""
	for d in list:
		var r: Array = d["ret"]
		points.append({"id": str(d["id"]), "nome": str(d.get("nome", "Ponto de descanso")), "ret": Rect2(r[0], r[1], r[2], r[3]), "clique": str(d.get("clique", ""))})


# O ponto em que o controlado está, ou {}.
func point_here() -> Dictionary:
	for p in points:
		if (p["ret"] as Rect2).has_point(room.player.pos):
			return p
	return {}


# Contorno do objeto do ponto na tela: o retângulo da colisão no chão mais o mesmo subido pela altura do objeto.
func _body_polygon(p: Dictionary) -> PackedVector2Array:
	var col: Dictionary = room.scenario.colliders
	if not col.has(p["clique"]):
		return PackedVector2Array()
	var rc: Rect2 = col[p["clique"]]
	var pts := PackedVector2Array()
	for corner in [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]:
		var q: Vector2 = room._iso(corner)
		pts.append(q)
		pts.append(q + Vector2(0, -BODY_HEIGHT))
	return Geometry2D.convex_hull(pts)


# O ponto cujo objeto está sob o mouse (px do desenho), ou {}.
func point_under(mouse: Vector2) -> Dictionary:
	for p in points:
		var poly := _body_polygon(p)
		if not poly.is_empty() and Geometry2D.is_point_in_polygon(mouse, poly):
			return p
	return {}


# Clique no objeto do ponto: abre o painel se o controlado já está na área; senão anda até ela e abre ao chegar. true se tratou o clique.
func click(mouse: Vector2) -> bool:
	if room.mode != TestRoom.Mode.EXPLORATION or room.descanso_panel.open or not room.diario_pode_abrir():
		return false
	var p := point_under(mouse)
	if p.is_empty():
		return false
	if not point_here().is_empty():
		room.descanso_panel.abrir()
		return true
	var ret: Rect2 = p["ret"]
	var spots: Array[Vector2] = []
	for ix in 8:
		for iy in 3:
			spots.append(ret.position + Vector2(ret.size.x * (ix + 0.5) / 8.0, ret.size.y * (iy + 0.5) / 3.0 * 0.85))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(room.player.pos) < b.distance_to(room.player.pos))
	for spot in spots:
		var route: PackedVector2Array = room.pathfinder.find_path(room.player.pos, spot, room._obstacles(room.player), room.player.radius)
		if route.size() > 1:
			pending = str(p["id"])
			room._reset_follow_offsets(spot - room.player.pos, true)
			room._start_move(room.player, route)
			return true
	room.hud.show_notice("Não dá para chegar em %s" % p["nome"])
	return true


# Chegou ao ponto que o clique pediu: abre o painel.
func tick() -> void:
	if pending == "":
		return
	if room.mode != TestRoom.Mode.EXPLORATION:
		pending = ""
	elif room.path.is_empty() and room.moving_unit == null:
		pending = ""
		if not point_here().is_empty() and room.diario_pode_abrir():
			room.descanso_panel.abrir()


# Rótulo "Descansar" sobre o objeto quando o mouse está nele (chamado ao desenhar as pistas).
func draw_hint(mouse: Vector2) -> void:
	if room.mode != TestRoom.Mode.EXPLORATION or room.descanso_panel.open:
		return
	var p := point_under(mouse)
	if p.is_empty():
		return
	var poly := _body_polygon(p)
	var top := Vector2(0, INF)
	var cx := 0.0
	for q in poly:
		cx += q.x / poly.size()
		top.y = minf(top.y, q.y)
	room._rotulo_pista(Vector2(cx, top.y + 46.0), "Descansar")


# Descansar: cura o grupo, salva e devolve o resumo para o painel e o registro.
func rest() -> Dictionary:
	var got: Dictionary = DescansoRules.rest(room.party, room.san)
	room.audio.play_sfx("item_use")
	Progresso.autosalvar(room, room._area_id(), room._place_label())
	room.queue_redraw()
	return got


# Prepara uma carga do ritual no Miguel (o controlado, ou quem conhece o ritual). Devolve o resultado de RitualRules.prepare.
func prepare(caster: Combatant, id: String) -> Dictionary:
	var out: Dictionary = room.rituals.prepare(caster, id)
	if out.ok:
		room.audio.play_sfx("item_use")
		Progresso.autosalvar(room, room._area_id(), room._place_label())
	else:
		room.audio.play_sfx("action_rejected")
	return out


# Quem do grupo conhece rituais (hoje só o Miguel).
func casters() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for m in room.party:
		if not room.rituals.known(m).is_empty():
			out.append(m)
	return out
