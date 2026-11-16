class_name RitualRules
extends RefCounted
# Rituais do Ocultista (GDD #11, Léo 29/10/2026): custam PA e SAN; INT soma ao dano e à cura.
# Os quatro rituais do Miguel estão em data/rituais.json (todos os números são provisórios do Claude, 15/11/2026).
#   Armadura de Sangue: redução de dano em si por algumas rodadas.   Amaldiçoar Arma: dano extra por golpe.
#   Eletrocussão: dano que não erra no inimigo à vista (+ chance de atordoar).   Cicatrização: cura e tira a ruptura.
# Ordem de um ritual: validar (classe, PA, SAN, alvo, alcance, visão) -> pagar PA -> pagar SAN (sem resistência de PRE;
# se a SAN chega a 0 é ruptura, ou loucura na segunda vez no combate) -> aplicar o efeito.
# Só regras: a sala mostra o resultado (textos flutuantes, registro) e passa a vez quando os PA acabam.

var cfg: CombatConfig
var rules: CombatRules
var san: SanRules
var rng: RandomNumberGenerator


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


# Bônus de INT no dano ou na cura (Ficha.bonus_ritual).
func int_bonus(caster: Combatant) -> int:
	return Ficha.bonus_ritual(cfg.game_data, caster.atributos)


# Motivo pelo qual o ritual não pode ser conjurado, ou "" se pode. Códigos do HUD (HudText.REJECTION_MESSAGES):
# requirement (não conhece, morto, enlouquecido, alvo inválido), no_pa, no_san, out_of_range, no_line_of_sight.
# `target`: inimigo (eletrocussão) ou aliado (cicatrização); ignorado nos rituais em si.
func blocker(caster: Combatant, id: String, target: Combatant = null, walls: Array[Rect2] = [], covers: Array = []) -> String:
	if not caster.is_alive() or caster.insane or not known(caster).has(id):
		return "requirement"
	var r := ritual(id)
	if caster.pa < int(r["custo_pa"]):
		return "no_pa"
	if caster.san < int(r["custo_san"]):
		return "no_san"
	match r["alvo"]:
		"si":
			return ""
		"inimigo":
			if target == null or not target.is_alive() or target.side == caster.side:
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


# Conjura. Retorna {ok, reason, id, san (resultado de SanRules.lose), + o efeito: damage, stunned, resisted_stun,
# healed, cleared, rounds, defense, bonus}.
func cast(caster: Combatant, id: String, target: Combatant = null, walls: Array[Rect2] = [], covers: Array = []) -> Dictionary:
	var out := {"ok": false, "reason": "", "id": id, "san": {}, "damage": 0, "stunned": false, "resisted_stun": false, "healed": 0, "cleared": false}
	out.reason = blocker(caster, id, target, walls, covers)
	if out.reason != "":
		return out
	out.ok = true
	var r := ritual(id)
	caster.pa -= int(r["custo_pa"])
	out.san = san.lose(caster, int(r["custo_san"]), false)  # custo de ritual: PRE não resiste
	if not caster.is_alive() or caster.insane:
		return out  # enlouqueceu pagando o custo: o ritual não sai
	match r["tipo"]:
		"defesa":
			caster.buffs[id] = {"rounds": int(r["rodadas"]), "defesa": float(r["valor"]), "dano": 0}
		"dano_arma":
			caster.buffs[id] = {"rounds": int(r["rodadas"]), "defesa": 0.0, "dano": int(r["valor"])}
		"dano":
			var dmg := rng.randi_range(int(r["dano"][0]), int(r["dano"][1])) + int_bonus(caster)
			out.damage = rules.damage_after_defense(float(dmg), target.defense_total())
			target.take_damage(out.damage)
			if target.is_alive() and rng.randf() < float(r["chance_atordoar"] if r["chance_atordoar"] != null else 0.0):
				if _resists_stun(target):
					out.resisted_stun = true
				else:
					rules.apply_condition(target, "atordoado")
					out.stunned = true
		"cura":
			var heal := floori(target.max_pv * float(r["cura_percentual"]) + 0.0001) + int_bonus(caster)
			out.healed = mini(maxi(heal, 1), target.max_pv - target.pv)
			target.pv += out.healed
			if r["limpa_ruptura"] and target.ruptured:
				san.recover(target, 0, true)
				out.cleared = true
	return out


func _resists_stun(target: Combatant) -> bool:
	if target.kind == "":
		return false
	return (cfg.game_data.get_entry("inimigos", target.kind).get("resistencias", []) as Array).has("atordoado")


# Encerra todos os efeitos de ritual (fim do combate).
static func clear_buffs(units: Array) -> void:
	for u: Combatant in units:
		u.buffs.clear()
