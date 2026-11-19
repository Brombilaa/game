class_name RoomRitual
extends RefCounted
# Rituais do Ocultista na sala (Miguel): escolhe o alvo, chama RitualRules e encena o resultado com textos
# flutuantes e registro. Cada ritual gasta um componente do seu elemento da mochila; sem ele, avisa o que falta. Atalho: a tecla numérica da casa do ritual na barra de combate (Léo, 19/11: 1 a 9 em
# ordem, sem letras). Só em combate, na vez do controlado.

var room: TestRoom


func _init(owner_room: TestRoom) -> void:
	room = owner_room


func cast(id: String) -> void:
	if not room._player_ready():
		return
	var caster := room.player
	if not room.rituals.known(caster).has(id):
		room.hud.show_notice("%s não conhece este ritual" % caster.name)
		room.audio.play_sfx("action_rejected")
		return
	var r := room.rituals.ritual(id)
	var target: Combatant = null
	match r["alvo"]:
		"inimigo":
			target = _pick_enemy(caster, id)
			if target == null:
				_reject("out_of_range", "Nenhum inimigo ao alcance de %s" % r["nome"])
				return
		"aliado":
			target = _pick_ally(caster, id)
			if target == null:
				_reject("requirement", "Ninguém precisa de %s agora" % r["nome"])
				return
	room.rules.units = room._living_units()
	var out := room.rituals.cast(caster, id, target, room._sight_blockers(), room.covers)
	if not out.ok:
		_reject(out.reason, _component_notice(id) if out.reason == "no_component" else "")
		return
	_show(caster, id, target, out)
	room.room_combat._after_player_action()


# Aviso de componente em falta: "Sem componente de Sangue (sangue coagulado, prego enferrujado...)".
func _component_notice(id: String) -> String:
	var rr := room.rituals
	var names: Array[String] = []
	for iid in rr.component_items(rr.element(id)):
		names.append(str(room.cfg.game_data.get_entry("itens", iid)["nome"]).to_lower())
	return "Sem componente de %s para %s (%s)" % [RitualRules.element_name(rr.element(id)), rr.ritual(id)["nome"], ", ".join(names)]


func _reject(reason: String, notice := "") -> void:
	room.room_combat._reject(reason)
	if notice != "":
		room.hud.show_notice(notice)


# Eletrocussão: o inimigo sob o mouse, se estiver ao alcance e à vista; senão o mais perto que o ritual alcança.
func _pick_enemy(caster: Combatant, id: String) -> Combatant:
	var walls := room._sight_blockers()
	if not room._mouse_on_hud(room.get_viewport().get_mouse_position()):
		var under := room.room_combat._enemy_at(room._resolve_click(room.get_global_mouse_position()))
		if under and room.rituals.blocker(caster, id, under, walls, room.covers) in ["", "no_pa", "no_san", "no_component"]:
			return under
	var best: Combatant = null
	for e in room.enemies:
		if e.is_alive() and room.rituals.blocker(caster, id, e, walls, room.covers) in ["", "no_pa", "no_san", "no_component"]:
			if best == null or CombatRules.gap(caster, e) < CombatRules.gap(caster, best):
				best = e
	return best


# Cicatrização: o aliado vivo ao alcance que mais precisa (menor fração de PV; ruptura conta); o próprio conjurador entra.
func _pick_ally(caster: Combatant, id: String) -> Combatant:
	var best: Combatant = null
	var best_need := 0.0
	for m in room.party:
		if not m.is_alive() or m.dead or room.rituals.blocker(caster, id, m) in ["requirement", "out_of_range"]:
			continue
		var need := 1.0 - float(m.pv) / float(m.max_pv) + (0.5 if m.ruptured else 0.0)
		if need > best_need + 0.0001:
			best_need = need
			best = m
	return best


func _show(caster: Combatant, id: String, target: Combatant, out: Dictionary) -> void:
	var r := room.rituals.ritual(id)
	room.audio.play_sfx("item_use")
	room.room_combat._popup(caster.pos, r["nome"].to_upper(), "san")
	room.room_combat._log("%s conjura %s" % [caster.name, r["nome"]])
	for iid in out.components:
		room.room_combat._log("%s gasta %s" % [caster.name, str(room.cfg.game_data.get_entry("itens", iid)["nome"]).to_lower()])
	room.room_combat._san_report({caster: out.san}, "paga o ritual")
	if not out.ok or caster.insane:
		return
	match r["tipo"]:
		"defesa":
			room.room_combat._popup(caster.pos, "-%d%% DANO" % roundi(float(r["valor"]) * 100.0), "heal")
		"dano_arma":
			room.room_combat._popup(caster.pos, "+%d DANO" % int(r["valor"]), "heal")
		"dano":
			room.room_combat._popup(target.pos, "-%d" % out.damage, "damage")
			room.room_combat._afinidade(target, out)
			room.room_combat._log("%s atinge %s: %d" % [r["nome"], target.name, out.damage])
			room.hit_shake[target] = TestRoom.HIT_SHAKE_SECONDS
			if out.stunned:
				room.room_combat._popup(target.pos, "ATORDOADO", "info")
			elif out.resisted_stun:
				room.room_combat._popup(target.pos, "IMUNE", "info")
			if not target.is_alive():
				room.room_combat._popup(target.pos, "ABATIDO", "down")
				room.room_combat._log("%s foi abatido" % target.name)
				if not target.looted:
					target.looted = true
					room._loot_enemy(target)
		"cura":
			room.room_combat._popup(target.pos, "+%d PV" % out.healed, "heal")
			room.room_combat._log("%s cura %s: +%d PV" % [caster.name, target.name, out.healed])
			if out.cleared:
				room.room_combat._popup(target.pos, "RUPTURA CURADA", "heal")
	room.queue_redraw()
