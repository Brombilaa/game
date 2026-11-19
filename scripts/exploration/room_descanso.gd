class_name RoomDescanso
extends RefCounted
# Ponto de descanso na sala (zona segura, GDD #25): quando o líder entra na área de um ponto aparece o aviso "F: descansar" e a tecla F
# abre o DescansoPanel. Descansar cura o grupo (DescansoRules), salva o jogo e não gasta tempo; o Miguel também prepara rituais
# ali (RitualRules.prepare, números provisórios em combat.json > preparo). Os pontos vêm dos dados do lugar (`descansos`:
# [{"id", "nome", "ret": [x, y, w, h]}]); a missão 1 não tem nenhum (Léo, 16/11), então no jogo isto só aparece em lugares que ganharem um.

var room: TestRoom
var points: Array[Dictionary] = []  # {"id", "nome", "ret": Rect2}
var _inside := ""  # id do ponto em que o líder está (o aviso sai só ao entrar)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Lê `descansos` do JSON do lugar.
func load_points(list: Array) -> void:
	points.clear()
	for d in list:
		var r: Array = d["ret"]
		points.append({"id": str(d["id"]), "nome": str(d.get("nome", "Ponto de descanso")), "ret": Rect2(r[0], r[1], r[2], r[3])})


# O ponto em que o controlado está, ou {}.
func point_here() -> Dictionary:
	for p in points:
		if (p["ret"] as Rect2).has_point(room.player.pos):
			return p
	return {}


func tick() -> void:
	if points.is_empty() or room.mode != TestRoom.Mode.EXPLORATION:
		return
	var p := point_here()
	var id := str(p.get("id", ""))
	if id != _inside:
		_inside = id
		if id != "":
			room.hud.show_notice("%s: F para descansar" % p["nome"])


# Tecla F: abre o painel se o controlado está num ponto de descanso e nada mais ocupa a tela. true se abriu.
func try_open() -> bool:
	if room.mode != TestRoom.Mode.EXPLORATION or point_here().is_empty() or room.descanso_panel.open or not room.diario_pode_abrir():
		return false
	room.descanso_panel.abrir()
	return true


# Descansar: cura o grupo, salva e devolve o resumo para o painel e o registro.
func rest() -> Dictionary:
	var got := DescansoRules.rest(room.party, room.san)
	room.audio.play_sfx("item_use")
	Progresso.autosalvar(room, room._area_id(), room._place_label())
	room.queue_redraw()
	return got


# Prepara uma carga do ritual no Miguel (o controlado, ou quem conhece o ritual). Devolve o resultado de RitualRules.prepare.
func prepare(caster: Combatant, id: String) -> Dictionary:
	var out := room.rituals.prepare(caster, id)
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
