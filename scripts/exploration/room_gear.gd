class_name RoomGear
extends RefCounted
# Inventário e equipamento da sala (extraído de test_room.gd). A mochila (Inventory) e o equipamento de
# cada um (`room.gear`) mandam; o painel (InventoryPanel) só desenha e chama a sala, que repassa para cá.
# Cada função gear_* devolve a mensagem para o painel ("" se nada a dizer).

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
	if efeito == "san_max":
		return "acessorio"
	return "item"


# Acessório de SAN (pulseira da amizade, Léo 15/11): soma ou tira o bônus de SAN máxima de `m`.
func _apply_accessory(m: Combatant, id: String, sign: int) -> void:
	if id == "" or str(room.cfg.game_data.get_entry("itens", id).get("efeito", "")) != "san_max":
		return
	var v := int(room.cfg.game_data.get_entry("itens", id).get("valor", 0)) * sign
	m.max_san = maxi(m.max_san + v, 0)
	m.san = clampi(m.san + maxi(v, 0), 0, m.max_san)


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
	return TestRoom.SWAP_PA


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


# Usa um consumível da mochila em `m`: bandagem tira o sangramento, antídoto o veneno.
# O kit de primeiros socorros reanima aliado caído e só se usa pela barra de combate.
func gear_use(m: Combatant, bag_index: int) -> String:
	var id := str(room.inventory.slots[bag_index].get("id", ""))
	var effect := str(room.cfg.game_data.get_entry("itens", id).get("efeito", ""))
	var cures := {"remover_sangrando": "sangrando", "remover_envenenado": "envenenado"}
	if effect == "municao":
		return "Recarregue a arma com G"
	if id == TestRoom.KIT_ID:
		return "O kit reanima um aliado caído (barra de combate)"
	if not cures.has(effect):
		return "Sem efeito por enquanto"
	if not m.has_condition(cures[effect]):
		return "%s não precisa" % m.name
	if room.mode == TestRoom.Mode.COMBAT:
		if m != room.player:
			return "Só quem está na vez usa itens"
		if not room.turns.spend(room.player, int(room.cfg.game_data.get_entry("itens", id)["custo_pa_combate"])):
			room._reject("no_pa")
			return "PA insuficientes"
	m.conditions.erase(cures[effect])
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


# Inimigo abatido larga o que a ficha (drops) sorteia direto na mochila, com aviso. Provisório do Claude.
func _loot_enemy(e: Combatant) -> void:
	var found: Array = []
	for d in e.drops:
		if room.loot_rng.randf() < float(d.get("chance", 1.0)):
			found.append({"item": str(d["item"]), "qtd": int(d.get("qtd", 1))})
	if not found.is_empty():
		collect_items(found)


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
