class_name RoomGear
extends RefCounted
# Inventário e equipamento da sala (extraído de test_room.gd). A mochila (Inventory) e o equipamento de
# cada um (`room.gear`) mandam; o painel (InventoryPanel) só desenha e chama a sala, que repassa para cá.
# Cada função gear_* devolve a mensagem para o painel ("" se nada a dizer).

const CORPSE_REACH := 80.0  # distância (px do plano) para examinar um corpo (provisório)
const CORPSE_CLICK_PAD := 16.0  # folga do clique em volta do corpo

var room: TestRoom  # a sala de teste (test_room.gd) ou uma área derivada (parque, local3d)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Arma de reserva do controlado ("" se não tem).
func _reserve_id() -> String:
	return str(room.gear[room.player]["secundaria"])


# Munição de uma arma na mochila compartilhada: item "municao_<id da arma>" (pilha de 30).
func ammo_item(weapon_id: String) -> String:
	return "municao_" + weapon_id


# Balas no carregador e na mochila da arma em mãos de `u`: [carregador, reserva]; vazio se a arma não usa munição.
func ammo_of(u: Combatant) -> Array:
	if int(u.weapon.get("mag_size", 0)) <= 0:
		return []
	var wid := str(u.weapon["id"])
	return [int(u.mag.get(wid, 0)), room.inventory.count(ammo_item(wid))]


# O inventário abre fora do combate ou no turno do jogador (o tempo para; no turno inimigo não).
func inventory_can_open() -> bool:
	return room.mode == TestRoom.Mode.EXPLORATION or room._player_ready()


# "arma", "colete" ou "item".
func gear_item_kind(id: String) -> String:
	if room.cfg.game_data.has_entry("armas", id):
		return "arma"
	var efeito = room.cfg.game_data.get_entry("itens", id).get("efeito")
	if efeito == "defesa":
		return "colete"
	if efeito in ACCESSORY_EFFECTS:
		return "acessorio"
	return "item"


# Efeitos de acessório (quarto espaço do equipamento; o GDD deixa acessórios fora do escopo inicial,
# então só há bônus de máximo, valores provisórios do Claude): san_max (pulseira, Léo 15/11) e pv_max.
const ACCESSORY_EFFECTS := ["san_max", "pv_max"]


# Soma (sign 1) ou tira (sign -1) o bônus do acessório `id` no máximo de SAN ou de PV de `m`.
func _apply_accessory(m: Combatant, id: String, sign: int) -> void:
	if id == "":
		return
	var item: Dictionary = room.cfg.game_data.get_entry("itens", id)
	var v := int(item.get("valor", 0)) * sign
	match str(item.get("efeito", "")):
		"san_max":
			m.max_san = maxi(m.max_san + v, 0)
			m.san = clampi(m.san + maxi(v, 0), 0, m.max_san)
		"pv_max":
			m.max_pv = maxi(m.max_pv + v, 1)
			m.pv = clampi(m.pv + maxi(v, 0), 0 if m.pv <= 0 else 1, m.max_pv)


# Arma com carregador que ainda não passou pela mão de `m` começa vazia (recarrega da mochila).
func _ensure_mag(m: Combatant, weapon_id: String) -> void:
	if weapon_id != "" and int(room.cfg.weapon(weapon_id)["mag_size"]) > 0 and not m.mag.has(weapon_id):
		m.mag[weapon_id] = 0


func gear_is_equippable(id: String) -> bool:
	return gear_item_kind(id) != "item"


func gear_slot_id(m: Combatant, slot: String) -> String:
	return str(room.gear[m][slot])


# Em combate só quem está na vez troca de arma, por 1 PA; colete só fora do combate.
func _gear_change_cost(m: Combatant, kind: String) -> Variant:
	if room.mode != TestRoom.Mode.COMBAT:
		return 0
	if kind == "colete":
		return "Troque de colete fora do combate"
	if m != room.player:
		return "Só quem está na vez troca de arma"
	return int(room.cfg.regra("custo_trocar_arma_pa", 1))


# Equipa o item do espaço `bag_index` no espaço `slot` de `m`; o que estava lá vai para o lugar dele.
func gear_equip(m: Combatant, slot: String, bag_index: int) -> String:
	var entry: Dictionary = room.inventory.slots[bag_index]
	if entry.is_empty():
		return ""
	var id := str(entry["id"])
	var kind := gear_item_kind(id)
	if kind == "item":
		return "Esse item não vai aí"
	if (kind == "colete") != (slot == "colete") or (kind == "acessorio") != (slot == "acessorio"):
		return "Esse item não vai aí"
	var cost = _gear_change_cost(m, kind)
	if cost is String:
		return cost
	if cost > 0 and not room.turns.spend(room.player, cost):
		room._reject("no_pa")
		return "PA insuficientes"
	var old := str(room.gear[m][slot])
	room.inventory.slots[bag_index] = {"id": old, "qty": 1} if old != "" else {}
	room.gear[m][slot] = id
	if slot == "acessorio":
		_apply_accessory(m, old, -1)
		_apply_accessory(m, id, 1)
	if slot in ["principal", "secundaria"]:
		_ensure_mag(m, id)
	if slot == "principal":
		m.weapon = room.cfg.weapon(id)
	elif slot == "colete":
		m.defense = float(room.cfg.game_data.get_entry("itens", id)["valor"])
	room.queue_redraw()
	return "%s: %s" % [m.name, room.cfg.game_data.get_entry("armas", id).get("nome", room.cfg.game_data.get_entry("itens", id).get("nome", id))]


# Troca a arma principal pela secundária de `m` (no inventário; Q faz o mesmo para o controlado).
func gear_swap_weapons(m: Combatant) -> String:
	var g: Dictionary = room.gear[m]
	if g["secundaria"] == "" and g["principal"] == "":
		return ""
	var cost = _gear_change_cost(m, "arma")
	if cost is String:
		return cost
	if cost > 0 and not room.turns.spend(room.player, cost):
		room._reject("no_pa")
		return "PA insuficientes"
	var main: String = g["principal"]
	g["principal"] = g["secundaria"]
	g["secundaria"] = main
	_ensure_mag(m, str(g["principal"]))
	m.weapon = room.cfg.weapon(g["principal"]) if g["principal"] != "" else room.cfg.weapon("soco")
	room.queue_redraw()
	return "%s empunha %s" % [m.name, room.cfg.game_data.get_entry("armas", g["principal"]).get("nome", "o soco")]


# Guarda de volta na mochila o que `m` tem em `slot`.
func gear_unequip(m: Combatant, slot: String) -> String:
	var id := str(room.gear[m][slot])
	if id == "":
		return ""
	var cost = _gear_change_cost(m, gear_item_kind(id))
	if cost is String:
		return cost
	if room.inventory.free_slot() < 0:
		return "Mochila cheia"
	if cost > 0 and not room.turns.spend(room.player, cost):
		room._reject("no_pa")
		return "PA insuficientes"
	room.inventory.add(id)
	room.gear[m][slot] = ""
	if slot == "acessorio":
		_apply_accessory(m, id, -1)
	if slot == "principal":
		m.weapon = room.cfg.weapon("soco")
	elif slot == "colete":
		m.defense = 0.0
	room.queue_redraw()
	return "Guardou na mochila"


func gear_discard(bag_index: int) -> String:
	var gone := room.inventory.discard(bag_index)
	return "" if gone.is_empty() else "Descartou %s" % room.cfg.game_data.get_entry("itens", str(gone["id"])).get("nome", room.cfg.game_data.get_entry("armas", str(gone["id"])).get("nome", gone["id"]))


# Usa um consumível da mochila em `m`: bandagem tira o sangramento, antídoto o veneno, curativo recupera PV.
# O kit de primeiros socorros reanima aliado caído e só se usa pela barra de combate.
func gear_use(m: Combatant, bag_index: int) -> String:
	var id := str(room.inventory.slots[bag_index].get("id", ""))
	var effect := str(room.cfg.game_data.get_entry("itens", id).get("efeito", ""))
	var cures := {"remover_sangrando": "sangrando", "remover_envenenado": "envenenado"}
	if effect == "municao":
		return "Recarregue a arma com G"
	if id == TestRoom.KIT_ID:
		return "O kit reanima um aliado caído (barra de combate)"
	var heal := effect == "curar_pv"
	if not cures.has(effect) and not heal:
		return "Sem efeito por enquanto"
	if heal and (not m.is_alive() or m.pv >= m.max_pv):
		return "%s não precisa" % m.name if m.is_alive() else "Caído só volta com o kit"
	if not heal and not m.has_condition(cures[effect]):
		return "%s não precisa" % m.name
	if room.mode == TestRoom.Mode.COMBAT:
		if m != room.player:
			return "Só quem está na vez usa itens"
		var custo = room.cfg.game_data.get_entry("itens", id)["custo_pa_combate"]
		if not room.turns.spend(room.player, int(custo if custo != null else room.cfg.regra("custo_usar_item_pa", 1))):
			room._reject("no_pa")
			return "PA insuficientes"
	if heal:  # curativo: recupera uma fração do PV máximo (valor em itens.json; provisório)
		var cura := maxi(floori(m.max_pv * float(room.cfg.game_data.get_entry("itens", id)["valor"])), 1)
		m.pv = mini(m.pv + cura, m.max_pv)
		room._popup(m.pos, "+%d" % cura, "heal")
	else:
		m.conditions.erase(cures[effect])
	room.audio.play_sfx("item_use")
	room.inventory.remove(id)
	if room.use_3d and room._sheet3d(m) != null:
		room.nikolai_clock[m] = {"anim": "pickup_object", "start": Time.get_ticks_msec()}  # gesto de usar o item
	room.queue_redraw()
	return "%s usou %s" % [m.name, room.cfg.game_data.get_entry("itens", id)["nome"]]


# Mochila e equipamento iniciais (provisório do Claude).
func _setup_gear() -> void:
	room.inventory = Inventory.new(room.cfg.game_data)
	var scarce := room._gear_scarce()
	var items := [[TestRoom.KIT_ID, 1], ["colete_leve", 1], ["colete_pesado", 1]] if scarce else [[TestRoom.KIT_ID, 1], ["bandagem", 2], ["antidoto", 1], ["colete_leve", 1], ["colete_pesado", 1]]
	for item in items:
		room.inventory.add(item[0], item[1])
	var reserves := {"pistola": 12, "escopeta": 0, "fuzil_precisao": 5} if scarce else {"pistola": 24, "escopeta": 12, "fuzil_precisao": 12}
	for w in reserves:  # reservas iniciais
		room.inventory.add(ammo_item(w), int(reserves[w]))
	for m in room.party:
		var second = room.cfg.game_data.get_entry("personagens", m.name.to_lower()).get("arma_secundaria")
		if scarce and second == "escopeta":  # a escopeta só vem do Caio (Léo, 15/11)
			second = null
		var main := str(m.weapon["id"])
		for wid in [main, "" if second == null else str(second)]:  # cada arma com carregador começa cheia
			if wid != "" and int(room.cfg.weapon(wid)["mag_size"]) > 0:
				m.mag[wid] = int(room.cfg.weapon(wid)["mag_size"])
		room.gear[m] = {"principal": main, "secundaria": "" if second == null or str(second) == main else str(second), "colete": "", "acessorio": ""}


func _item_name(id: String) -> String:
	return str(room.cfg.game_data.get_entry("itens", id).get("nome", room.cfg.game_data.get_entry("armas", id).get("nome", id)))


# Inimigo abatido: a tabela da ficha (drops) é sorteada na hora da morte, mas o saque fica no corpo (que brilha no chão)
# até o grupo examinar. Provisório do Claude (sugestão 1 da revisão, 16/11).
func _loot_enemy(e: Combatant) -> void:
	e.loot = []
	for d in e.drops:
		if room.loot_rng.randf() < float(d.get("chance", 1.0)):
			e.loot.append({"item": str(d["item"]), "qtd": int(d.get("qtd", 1))})
	if not e.loot.is_empty():
		room.room_combat._popup(e.pos, "SAQUE", "info")


# Corpo com saque sob o ponto p (plano da sala), ou null. Abatidos ainda sendo encenados não contam.
func corpse_at(p: Vector2) -> Combatant:
	for e in room.enemies:
		if is_corpse(e) and e.pos.distance_to(p) <= e.radius + CORPSE_CLICK_PAD:
			return e
	return null


func is_corpse(e: Combatant) -> bool:
	return not e.is_alive() and not e.loot.is_empty() and not room.fx.dying().has(e)


# O controlado examina o corpo: o que cabe vai para a mochila; o resto fica no corpo. Devolve o aviso.
func examine_corpse(e: Combatant) -> String:
	var kept: Array = []
	var got: Array = []
	var lost := false
	for f in e.loot:
		var id := str(f["item"])
		var qty := int(f.get("qtd", 1))
		var left: int = room.inventory.add(id, qty)
		if qty - left > 0:
			got.append({"item": id, "qtd": qty - left})
		if left > 0:
			lost = true
			kept.append({"item": id, "qtd": left})
	e.loot = kept
	var parts: Array[String] = []
	for g in got:
		parts.append("%dx %s" % [g["qtd"], _item_name(g["item"])])
	var msg := "Saqueou: " + ", ".join(parts) if not parts.is_empty() else ""
	if lost:
		msg += (" · " if msg != "" else "") + "Mochila cheia: o resto fica no corpo"
	if msg != "":
		room.hud.show_notice(msg)
	if not got.is_empty():
		room.room_combat._log("%s examina %s: %s" % [room.player.name, e.name, ", ".join(parts)])
	return msg


# Clique num corpo: perto, examina; longe, o controlado anda até ele e examina ao chegar (Parque: pending_corpse).
func click_corpse(e: Combatant) -> void:
	if room.player.pos.distance_to(e.pos) <= CORPSE_REACH:
		room.pending_corpse = null
		examine_corpse(e)
		return
	room.pending_corpse = e
	room._order_move(e.pos)
	room.pending_corpse = e  # _order_move zera o pedido anterior


# Brilho dourado que respira sobre os corpos com saque (provisório; vira malha com brilho quando houver modelo de corpo).
func draw_corpses() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 280.0)
	var hover := corpse_at(room._resolve_click(room.get_global_mouse_position()))
	var any := false
	for e in room.enemies:
		if not is_corpse(e):
			continue
		any = true
		var at: Vector2 = room._iso(e.pos)
		var near: bool = room.player.pos.distance_to(e.pos) <= CORPSE_REACH * 2.0
		var a := (0.28 + 0.22 * pulse) * (1.4 if near else 1.0) * (1.6 if e == hover else 1.0)
		_draw_ellipse(at, Vector2(26, 13), Color(0.05, 0.03, 0.02, 0.55))  # corpo caído
		_draw_ellipse(at, Vector2(34 + 4 * pulse, 17 + 2 * pulse), Color(0.95, 0.78, 0.38, clampf(a * 0.5, 0.0, 1.0)))
		_draw_ellipse(at, Vector2(20, 10), Color(1.0, 0.88, 0.5, clampf(a, 0.0, 1.0)))
		if e == hover:
			var font := ThemeDB.fallback_font
			var txt := "Examinar"
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var r := Rect2(at + Vector2(-w * 0.5 - 8.0, -34.0), Vector2(w + 16.0, 22.0))
			room.draw_rect(r, Color(0.05, 0.03, 0.02, 0.88))
			room.draw_rect(r, Color(0.84, 0.68, 0.36), false, 1.0)
			room.draw_string(font, r.position + Vector2(8.0, 16.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.93, 0.89, 0.8))
	if any:
		room.queue_redraw()  # o brilho pulsa


func _draw_ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(c + Vector2(cos(TAU * i / 24.0) * r.x, sin(TAU * i / 24.0) * r.y))
	room.draw_colored_polygon(pts, col)


# Itens achados no cenário ao fechar uma pista: [{"item": id, "qtd": n}, ...]. Devolve o texto do aviso
# ("" se nada coube ou não havia nada); o que não cabe na mochila fica perdido com aviso.
func collect_items(found: Array) -> String:
	var parts: Array[String] = []
	var lost := false
	for f in found:
		var id := str(f["item"])
		var qty := int(f.get("qtd", 1))
		var left := room.inventory.add(id, qty)
		lost = lost or left > 0
		if qty - left > 0:
			parts.append("%dx %s" % [qty - left, _item_name(id)])
	if parts.is_empty() and not lost:
		return ""
	var msg := "Achou: " + ", ".join(parts) if not parts.is_empty() else ""
	if lost:
		msg += (" · " if msg != "" else "") + "Mochila cheia"
	room.hud.show_notice(msg)
	return msg
