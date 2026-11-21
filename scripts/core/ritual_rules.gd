class_name RitualRules
extends RefCounted
# Rituais do Ocultista (GDD #11, Léo 29/10/2026): custam PA e SAN; INT soma ao dano e à cura.
# Os quatro rituais do Miguel estão em data/rituais.json (todos os números são provisórios do Claude, 15/11/2026).
#   Armadura de Sangue: redução de dano em si por algumas rodadas.   Amaldiçoar Arma: dano extra por golpe.
#   Eletrocussão: dano que não erra no inimigo à vista (+ chance de atordoar).   Cicatrização: cura e tira a ruptura.
# Componentes (Léo, 16/11 e 19/11): cada ritual gasta `componentes` itens do seu `elemento` (sangue, energia, morte,
# conhecimento) da mochila. Sem componente não há ritual (não sai mais fraco). Qualquer item do elemento serve;
# gasta primeiro o que a mochila tem mais. Elemento de cada ritual e quantidade: provisórios do Claude.
# Preparo (Léo, 19/11; números provisórios do Claude, combat.json > preparo): no ponto de descanso o Miguel combina componentes e
# deixa o ritual preparado. Preparar gasta os componentes do elemento do ritual mais um de OUTRO elemento (a combinação). Cada carga
# preparada (Combatant.prepared) dispensa o componente ao conjurar e reforça o efeito em 25%; é gasta antes do componente da mochila.
# Ordem de um ritual: validar (classe, PA, SAN, componente, alvo, alcance, visão) -> pagar PA -> gastar componente -> pagar SAN (sem resistência de PRE;
# se a SAN chega a 0 é ruptura, ou loucura na segunda vez no combate) -> aplicar o efeito.
# Só regras: a sala mostra o resultado (textos flutuantes, registro) e passa a vez quando os PA acabam.

var cfg: CombatConfig
var rules: CombatRules
var san: SanRules
var rng: RandomNumberGenerator
var inventory: Inventory  # mochila do grupo, de onde saem os componentes; a sala entrega ao montar a mochila


func _init(config: CombatConfig, combat_rules: CombatRules, san_rules: SanRules, random: RandomNumberGenerator = null) -> void:
	cfg = config
	rules = combat_rules
	san = san_rules
	rng = random if random else RandomNumberGenerator.new()


# Rituais que `caster` conhece, na ordem de rituais.json.
func known(caster: Combatant) -> Array[String]:
	var out: Array[String] = []
	if caster.personagem == "":
		return out
	var classe := Ficha.classe_de(cfg.game_data, caster.personagem)
	for id in cfg.game_data.ids("rituais"):
		if cfg.game_data.get_entry("rituais", id)["classe"] == classe:
			out.append(id)
	return out


func ritual(id: String) -> Dictionary:
	var r := cfg.game_data.get_entry("rituais", id)
	assert(not r.is_empty(), "ritual inexistente: " + id)
	return r


func cost_pa(id: String) -> int:
	return int(ritual(id)["custo_pa"])


func cost_san(id: String) -> int:
	return int(ritual(id)["custo_san"])


func element(id: String) -> String:
	return str(ritual(id)["elemento"])


func cost_components(id: String) -> int:
	return int(ritual(id)["componentes"])


# Itens componentes de um elemento, na ordem de itens.json.
func component_items(elemento: String) -> Array[String]:
	var out: Array[String] = []
	for iid in cfg.game_data.ids("itens"):
		var it := cfg.game_data.get_entry("itens", iid)
		if it["categoria"] == "componente" and it.get("elemento") == elemento:
			out.append(iid)
	return out


# Quantos componentes do elemento do ritual há na mochila (0 sem mochila).
func components_available(id: String) -> int:
	if inventory == null:
		return 0
	var total := 0
	for iid in component_items(element(id)):
		total += inventory.count(iid)
	return total


static func element_name(elemento: String) -> String:
	return {"sangue": "Sangue", "energia": "Energia", "morte": "Morte", "conhecimento": "Conhecimento"}.get(elemento, elemento.capitalize())


# Tira da mochila os componentes do ritual, do item que há mais (empate: o primeiro de itens.json). Retorna os ids gastos.
func _spend_components(id: String) -> Array[String]:
	var spent: Array[String] = []
	for i in cost_components(id):
		var best := ""
		for iid in component_items(element(id)):
			if inventory.count(iid) > (inventory.count(best) if best != "" else 0):
				best = iid
		if best == "" or not inventory.remove(best, 1):
			break
		spent.append(best)
	return spent


# Bônus de INT no dano ou na cura (Ficha.bonus_ritual).
func int_bonus(caster: Combatant) -> int:
	return Ficha.bonus_ritual(cfg.game_data, caster.atributos)


# Motivo pelo qual o ritual não pode ser conjurado, ou "" se pode. Códigos do HUD (HudText.REJECTION_MESSAGES):
# requirement (não conhece, morto, enlouquecido, alvo inválido), no_pa, no_san, no_component, out_of_range, no_line_of_sight.
# `target`: inimigo (eletrocussão) ou aliado (cicatrização); ignorado nos rituais em si.
func blocker(caster: Combatant, id: String, target: Combatant = null, walls: Array[Rect2] = [], covers: Array = []) -> String:
	if not caster.is_alive() or caster.insane or not known(caster).has(id):
		return "requirement"
	var r := ritual(id)
	if caster.pa < int(r["custo_pa"]):
		return "no_pa"
	if caster.san < int(r["custo_san"]):
		return "no_san"
	if caster.prepared.get(id, 0) <= 0 and components_available(id) < int(r["componentes"]):
		return "no_component"
	match r["alvo"]:
		"si":
			return ""
		"inimigo":
			if target == null or not target.is_alive() or target.side == caster.side or target.protegido:
				return "requirement"
			if CombatRules.gap(caster, target) > float(r["alcance_m"]) * cfg.value("pixels_per_meter"):
				return "out_of_range"
			if not Pathfinder.has_line_of_sight(caster.pos, target.pos, walls):
				return "no_line_of_sight"
			for c: Cover in covers:
				if c.kind == "full" and Pathfinder.segment_crosses_rect(caster.pos, target.pos, c.rect):
					return "no_line_of_sight"
			return ""
		_:  # aliado: o próprio conjurador ou um encostado nele; caído não recebe cura (usa o kit)
			if target == null or not target.is_alive() or target.side != caster.side or target.dead:
				return "requirement"
			if target != caster and CombatRules.gap(caster, target) > float(r["alcance_m"]) * cfg.value("pixels_per_meter"):
				return "out_of_range"
			return ""


# Conjura. Retorna {ok, reason, id, components (ids gastos), san (resultado de SanRules.lose), + o efeito: damage, stunned, resisted_stun,
# healed, cleared, rounds, defense, bonus}.
func cast(caster: Combatant, id: String, target: Combatant = null, walls: Array[Rect2] = [], covers: Array = []) -> Dictionary:
	var out := {"ok": false, "reason": "", "id": id, "components": [], "san": {}, "damage": 0, "stunned": false, "resisted_stun": false, "healed": 0, "cleared": false, "tipo_dano": "", "afinidade": "", "sem_efeito": false, "prepared": false}
	out.reason = blocker(caster, id, target, walls, covers)
	if out.reason != "":
		return out
	out.ok = true
	var r := ritual(id)
	caster.pa -= int(r["custo_pa"])
	if caster.prepared.get(id, 0) > 0:  # carga preparada: não gasta componente e reforça o efeito
		caster.prepared[id] = int(caster.prepared[id]) - 1
		if caster.prepared[id] <= 0:
			caster.prepared.erase(id)
		out.prepared = true
	else:
		out.components = _spend_components(id)  # gasto mesmo se o conjurador enlouquecer pagando a SAN
	out.san = san.lose(caster, int(r["custo_san"]), false)  # custo de ritual: PRE não resiste
	if not caster.is_alive() or caster.insane:
		return out  # enlouqueceu pagando o custo: o ritual não sai
	match r["tipo"]:
		"defesa":
			caster.buffs[id] = {"rounds": int(r["rodadas"]), "defesa": float(r["valor"]) * (1.0 + _bonus(out.prepared)), "dano": 0}
		"dano_arma":
			caster.buffs[id] = {"rounds": int(r["rodadas"]), "defesa": 0.0, "dano": _boost(float(r["valor"]), out.prepared)}
		"dano":
			var dmg := rng.randi_range(int(r["dano"][0]), int(r["dano"][1])) + int_bonus(caster)
			dmg = _boost(float(dmg), out.prepared)
			out.tipo_dano = Fraquezas.RITUAL
			out.afinidade = Fraquezas.afinidade(cfg.game_data, target.kind, Fraquezas.RITUAL)  # fraqueza/resistência (provisório)
			if not target.fere(Fraquezas.RITUAL, id):
				out.sem_efeito = true  # flor da Dama que pede outra mecânica
				return out
			out.damage = rules.damage_after_defense(float(dmg) * Fraquezas.multiplicador(out.afinidade), target.defense_total())
			target.take_damage(out.damage)
			if target.is_alive() and rng.randf() < float(r["chance_atordoar"] if r["chance_atordoar"] != null else 0.0):
				if _resists_stun(target):
					out.resisted_stun = true
				else:
					rules.apply_condition(target, "atordoado")
					out.stunned = true
		"cura":
			var heal := _boost(float(floori(target.max_pv * float(r["cura_percentual"]) + 0.0001) + int_bonus(caster)), out.prepared)
			out.healed = mini(maxi(heal, 1), target.max_pv - target.pv)
			target.pv += out.healed
			if r["limpa_ruptura"] and target.ruptured:
				san.recover(target, 0, true)
				out.cleared = true
	return out


# Reforço de uma carga preparada (arredonda para cima); sem carga devolve o valor como está.
func _bonus(prepared: bool) -> float:
	return float(cfg.preparo("bonus")) if prepared else 0.0


func _boost(value: float, prepared: bool) -> int:
	return ceili(value * (1.0 + _bonus(prepared)) - 0.0001)


# --- Preparo no ponto de descanso ---------------------------------------------------

func prepared_charges(caster: Combatant, id: String) -> int:
	return int(caster.prepared.get(id, 0))


func prepare_extra() -> int:
	return int(cfg.preparo("extra_componentes"))


func prepare_max() -> int:
	return int(cfg.preparo("cargas_max"))


# Itens de OUTRO elemento que servem de combinação, na ordem de itens.json.
func extra_items(id: String) -> Array[String]:
	var out: Array[String] = []
	for iid in cfg.game_data.ids("itens"):
		var it := cfg.game_data.get_entry("itens", iid)
		if it["categoria"] == "componente" and it.get("elemento") != element(id):
			out.append(iid)
	return out


func extras_available(id: String) -> int:
	if inventory == null:
		return 0
	var total := 0
	for iid in extra_items(id):
		total += inventory.count(iid)
	return total


# Por que o Miguel não pode preparar o ritual agora, ou "": requirement (não conhece, caído, enlouquecido), max_charges,
# no_component (falta o do elemento do ritual) ou no_extra (falta o de outro elemento, para combinar).
func prepare_blocker(caster: Combatant, id: String) -> String:
	if not caster.is_alive() or caster.insane or not known(caster).has(id):
		return "requirement"
	if prepared_charges(caster, id) >= prepare_max():
		return "max_charges"
	if components_available(id) < cost_components(id):
		return "no_component"
	if extras_available(id) < prepare_extra():
		return "no_extra"
	return ""


# Prepara uma carga: gasta os componentes do elemento e o extra de outro elemento. Retorna {ok, reason, id, components, charges}.
func prepare(caster: Combatant, id: String) -> Dictionary:
	var out := {"ok": false, "reason": prepare_blocker(caster, id), "id": id, "components": [], "charges": prepared_charges(caster, id)}
	if out.reason != "":
		return out
	out.components = _spend_components(id)
	for i in prepare_extra():
		var best := ""
		for iid in extra_items(id):
			if inventory.count(iid) > (inventory.count(best) if best != "" else 0):
				best = iid
		if best != "" and inventory.remove(best, 1):
			out.components.append(best)
	caster.prepared[id] = prepared_charges(caster, id) + 1
	out.ok = true
	out.charges = caster.prepared[id]
	return out


func _resists_stun(target: Combatant) -> bool:
	if target.kind == "":
		return false
	return (cfg.game_data.get_entry("inimigos", target.kind).get("resistencias", []) as Array).has("atordoado")


# Encerra todos os efeitos de ritual (fim do combate).
static func clear_buffs(units: Array) -> void:
	for u: Combatant in units:
		u.buffs.clear()
