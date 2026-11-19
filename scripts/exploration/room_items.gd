class_name RoomItems
extends RefCounted
# Itens de uso em combate na sala (granada de luz e sinalizador): escolhe o ponto ou o alvo, chama
# ItemRules, tira o item da mochila e encena o resultado. Só em combate, na vez do controlado.
# Teclas provisórias: H granada de luz, U sinalizador; também pela casa do item na barra de combate.
# Mira: o ponto sob o mouse, se der para alcançar; senão (ou clicando na barra) o melhor alvo automático.

const KEYS := {
	KEY_H: "granada_luz",
	KEY_U: "sinalizador",
}
const KEY_LABELS := Atalhos.ITEM_KEYS  # os rótulos moram em Atalhos, que também alimenta o mapa de controles

var room: TestRoom


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Tecla de item: retorna true se a tecla é de item (mesmo que o uso seja recusado).
func handle_key(keycode: int) -> bool:
	if not KEYS.has(keycode) or room.mode != TestRoom.Mode.COMBAT:
		return false
	use(KEYS[keycode])
	return true


# Itens de combate que estão na mochila, na ordem de itens.json.
func available() -> Array[String]:
	var out: Array[String] = []
	if room.inventory == null:
		return out
	for id in room.item_rules.combat_items():
		if room.inventory.count(id) > 0:
			out.append(id)
	return out


func use(id: String) -> void:
	if not room._player_ready():
		return
	var user := room.player
	var have := room.inventory.count(id)
	var name := str(room.cfg.game_data.get_entry("itens", id).get("nome", id))
	if have <= 0:
		_reject("requirement", "Sem %s na mochila" % name)
		return
	var walls := room._sight_blockers()
	var target: Combatant = null
	var point := Vector2.INF
	point = _pick_point(user, id, have, walls)
	if point == Vector2.INF:
		_reject("out_of_range", "Nenhum inimigo ao alcance de %s" % name)
		return
	room.rules.units = room._living_units()
	var out := room.item_rules.use(user, id, have, point, target, room._living_units(), walls)
	if not out.ok:
		_reject(out.reason)
		return
	room.inventory.remove(id)
	_show(user, id, target, out)
	room.room_combat._after_player_action()


func _reject(reason: String, notice := "") -> void:
	room.room_combat._reject(reason)
	if notice != "":
		room.hud.show_notice(notice)


func _mouse_point() -> Vector2:
	if room._mouse_on_hud(room.get_viewport().get_mouse_position()):
		return Vector2.INF
	return room._resolve_click(room.get_global_mouse_position())


# Granada e sinalizador: o ponto sob o mouse, se der; senão o inimigo ao alcance que junta mais inimigos no raio.
func _pick_point(user: Combatant, id: String, have: int, walls: Array[Rect2]) -> Vector2:
	var mouse := _mouse_point()
	if mouse != Vector2.INF and room.item_rules.blocker(user, id, have, mouse, null, walls) in ["", "no_pa"]:
		return mouse
	var best := Vector2.INF
	var best_n := 0
	for e in room.enemies:
		if not e.is_alive() or not (room.item_rules.blocker(user, id, have, e.pos, null, walls) in ["", "no_pa"]):
			continue
		var n := 0
		for o in room.enemies:
			if o.is_alive() and o.pos.distance_to(e.pos) <= room.item_rules.radius_px(id) + o.radius:
				n += 1
		if n > best_n or (n == best_n and best != Vector2.INF and user.pos.distance_to(e.pos) < user.pos.distance_to(best)):
			best_n = n
			best = e.pos
	return best


func _show(user: Combatant, id: String, target: Combatant, out: Dictionary) -> void:
	var name := str(room.cfg.game_data.get_entry("itens", id)["nome"])
	room.audio.play_sfx("item_use")
	room.room_combat._log("%s usa %s" % [user.name, name])
	if room.use_3d and room._sheet3d(user) != null:
		room.nikolai_clock[user] = {"anim": "pickup_object", "start": Time.get_ticks_msec()}  # gesto de arremessar
	match out.effect:
		"granada_luz":
			room.room_combat._popup(out.point, "CLARÃO", "info")
			for u: Combatant in out.stunned:
				room.room_combat._popup(u.pos, "ATORDOADO", "info")
			for u: Combatant in out.immune:
				room.room_combat._popup(u.pos, "IMUNE", "info")
			if out.stunned.is_empty() and out.immune.is_empty():
				room.hud.show_notice("O clarão não pegou ninguém")
		"sinalizador":
			room.room_combat._popup(out.point, "SINALIZADOR", "info")
	room.queue_redraw()
