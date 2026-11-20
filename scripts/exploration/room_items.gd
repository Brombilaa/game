class_name RoomItems
extends RefCounted
# Itens de uso em combate na sala (granada de luz e sinalizador): escolhe o ponto ou o alvo, chama
# ItemRules, tira o item da mochila e encena o resultado. Só em combate, na vez do controlado.
# Atalho: a tecla numérica da casa do item na barra de combate (Léo, 19/11: 1 a 9 em ordem, sem letras).
# Mira: o ponto sob o mouse, se der para alcançar; senão (ou clicando na barra) o melhor alvo automático.


var room: TestRoom


func _init(owner_room: TestRoom) -> void:
	room = owner_room


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
	if room.item_rules.effect(id) == "flor":
		target = _pick_flower(user, id, have, walls)
		if target == null:
			_reject("out_of_range", "Nenhuma flor aberta ao alcance de %s" % name)
			return
		point = target.pos
	else:
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


# Flor da Dama de Sangue: a que está sob o mouse; senão a que pede este item; senão a mais perto. Só as abertas e ao alcance.
func _pick_flower(user: Combatant, id: String, have: int, walls: Array[Rect2]) -> Combatant:
	var ok := func(e: Combatant) -> bool:
		return room.item_rules.blocker(user, id, have, e.pos, e, walls) in ["", "no_pa"]
	var mouse := _mouse_point()
	var best: Combatant = null
	for e in room.enemies:
		if not ok.call(e):
			continue
		if mouse != Vector2.INF and e.pos.distance_to(mouse) <= e.radius + 6.0:
			return e
		if best == null or (e.aceita.has(id) and not best.aceita.has(id)) \
				or (e.aceita.has(id) == best.aceita.has(id) and user.pos.distance_to(e.pos) < user.pos.distance_to(best.pos)):
			best = e
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
		"molotov":
			room.room_combat._popup(out.point, "FOGO", "crit")
			for h: Dictionary in out.hits:
				var u: Combatant = h.unit
				if h.sem_efeito:
					room.room_combat._popup(u.pos, "SEM EFEITO", "blocked")
					continue
				room.room_combat._popup(u.pos, "-%d" % int(h.damage), "damage")
				room.hit_shake[u] = TestRoom.HIT_SHAKE_SECONDS
				if not u.is_alive() and not u.objeto:
					room.room_combat._popup(u.pos, "ABATIDO", "down")
					room.room_combat._log("%s foi abatido" % u.name)
					if not u.looted:
						u.looted = true
						room._loot_enemy(u)
				room._apos_efeito(u)
			if out.hits.is_empty():
				room.hud.show_notice("O fogo não pegou ninguém")
		"flor":
			if out.sem_efeito:
				room.room_combat._popup(target.pos, "SEM EFEITO", "blocked")
				room.room_combat._log("%s em %s: nada acontece" % [name, target.name])
			room._apos_efeito(target)
	room.queue_redraw()
