class_name CombatRules
extends RefCounted
# Regras puras do combate: custo de movimento, chance de acerto, cobertura e dano.
# Os números vêm de CombatConfig; o sorteio usa um RNG injetável para os testes.
#
# Ordem de resolução de um ataque (decisões do Léo, 29/10/2026, provisórias até testar):
#   1. Validar: PA suficientes, alcance máximo da arma e linha de visão. Paredes, porta
#      fechada e cobertura total no caminho bloqueiam o tiro.
#   2. Chance = base da arma (75% à queima-roupa) - 5% a cada 2 m além da distância ideal
#               + AGI (provisório) + bônus (mira) - 20% se o alvo tem cobertura parcial;
#               limitada a 25%–95%.
#   3. Dano = sorteio inteiro na faixa da arma; crítico (10%) dobra.
#   4. Defesa do alvo (colete) reduz o dano em percentual; arredonda para baixo, mínimo 1.

var cfg: CombatConfig
var rng: RandomNumberGenerator


func _init(config: CombatConfig, random: RandomNumberGenerator = null) -> void:
	cfg = config
	rng = random if random else RandomNumberGenerator.new()


# --- Movimento ---------------------------------------------------------------

# PA que o turno já pagou por ter andado `moved` pixels: os primeiros `free_move_px` são grátis
# e, depois, cada `pixels_per_pa` custa 1 PA (Léo, 01/11/2026).
func _paid_pa(moved: float) -> int:
	var extra := moved - cfg.value("free_move_px")
	if extra <= 0.001:
		return 0
	return ceili(extra / cfg.value("pixels_per_pa") - 0.0001)


# PA necessários para andar mais `distance` pixels num turno em que já se andou `moved`.
func move_cost(distance: float, moved := 0.0) -> int:
	if distance <= 0.001:
		return 0
	return _paid_pa(moved + distance) - _paid_pa(moved)


# Ajusta a rota ao saldo de PA: rota completa se couber, senão movimento parcial
# até o limite dos PA restantes. Retorna {path, cost}. `path` começa na posição atual.
func plan_move(path: PackedVector2Array, pa_available: int, moved := 0.0) -> Dictionary:
	var length := path_length(path)
	var cost := move_cost(length, moved)
	if cost <= pa_available:
		return {"path": path, "cost": cost}
	var limit := cfg.value("free_move_px") + float(_paid_pa(moved) + pa_available) * cfg.value("pixels_per_pa") - moved
	return {"path": truncate_path(path, maxf(limit, 0.0)), "cost": pa_available}


static func path_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


static func truncate_path(path: PackedVector2Array, max_dist: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.is_empty():
		return out
	out.append(path[0])
	var left := max_dist
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if seg <= left:
			out.append(path[i])
			left -= seg
		else:
			if left > 0.0:
				out.append(path[i - 1].move_toward(path[i], left))
			break
	return out


# --- Cobertura ---------------------------------------------------------------

# Melhor cobertura que protege `target` contra um ataque vindo de `from`: a estrutura
# precisa estar entre os dois e encostada no alvo. Completa vence parcial. Null se nenhuma.
# Na resolução do ataque, a completa bloqueia o tiro em qualquer ponto do caminho
# (ver attack_blocker); a parcial só conta encostada no alvo.
func cover_between(from: Vector2, target: Combatant, covers: Array) -> Cover:
	var best: Cover = null
	var adjacent := cfg.value("cover_adjacent_distance") + target.radius
	for c: Cover in covers:
		if c.is_destroyed():
			continue
		if _distance_to_rect(target.pos, c.rect) > adjacent:
			continue
		if not Pathfinder.segment_crosses_rect(from, target.pos, c.rect):
			continue
		if best == null or (c.kind == "full" and best.kind != "full"):
			best = c
	return best


static func _distance_to_rect(p: Vector2, r: Rect2) -> float:
	var closest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(closest)


# --- Ataque ------------------------------------------------------------------

# Distância borda a borda entre duas unidades.
static func gap(a: Combatant, b: Combatant) -> float:
	return maxf(a.pos.distance_to(b.pos) - a.radius - b.radius, 0.0)


func hit_chance(attacker: Combatant, target: Combatant, covers: Array = [], stealth := false) -> float:
	var w := attacker.weapon
	var chance := float(w["base_chance"]) + attacker.hit_bonus
	if stealth:
		chance += cfg.value("stealth_hit_bonus")
	chance += maxi(attacker.initiative - 1, 0) * cfg.value("agi_hit_bonus")  # initiative = AGI
	chance -= _range_penalty(w, gap(attacker, target))
	var c := cover_between(attacker.pos, target, covers)
	if c and c.kind == "partial":
		chance -= float(cfg.cover("partial")["hit_penalty"])
	return clampf(chance, cfg.value("hit_chance_min"), cfg.value("hit_chance_max"))


# -5% a cada 2 m completos além da distância ideal da arma.
func _range_penalty(w: Dictionary, distance: float) -> float:
	var over := maxf(distance - float(w["free_range"]), 0.0)
	var step := 2.0 * cfg.value("pixels_per_meter")
	return floorf(over / step) * cfg.value("range_falloff_per_2m")


# Motivo pelo qual o ataque não pode ser feito, ou "" se pode. Os códigos são os
# mesmos do HUD (HudText.REJECTION_MESSAGES).
func attack_blocker(attacker: Combatant, target: Combatant, walls: Array[Rect2], covers: Array = []) -> String:
	if not attacker.is_alive() or not target.is_alive():
		return "requirement"
	if attacker.pa < int(attacker.weapon["pa_cost"]):
		return "no_pa"
	if gap(attacker, target) > float(attacker.weapon["max_range"]):
		return "out_of_range"
	if not Pathfinder.has_line_of_sight(attacker.pos, target.pos, walls):
		return "no_line_of_sight"
	if not attacker.weapon.get("melee", false):
		for c: Cover in covers:
			if c.kind == "full" and Pathfinder.segment_crosses_rect(attacker.pos, target.pos, c.rect):
				return "no_line_of_sight"
	return ""


# Resolve o ataque, gasta PA e aplica dano. Coberturas não são destruídas (Léo: ainda não).
# stealth: ataque furtivo contra inimigo sem alerta (bônus de acerto e multiplicador de dano).
# Retorna {ok, reason, chance, hit, blocked, crit, damage, cover}.
func attack(attacker: Combatant, target: Combatant, walls: Array[Rect2], covers: Array, stealth := false) -> Dictionary:
	var result := {"ok": false, "reason": "", "chance": 0.0, "hit": false, "blocked": false, "crit": false, "damage": 0, "cover": ""}
	result.reason = attack_blocker(attacker, target, walls, covers)
	if result.reason != "":
		return result
	result.ok = true
	attacker.pa -= int(attacker.weapon["pa_cost"])
	var c := cover_between(attacker.pos, target, covers)
	if c:
		result.cover = c.kind
	result.chance = hit_chance(attacker, target, covers, stealth)
	if rng.randf() >= result.chance:
		return result
	result.hit = true
	var dmg := float(rng.randi_range(int(attacker.weapon["damage_min"]), int(attacker.weapon["damage_max"])))
	if rng.randf() < cfg.value("crit_chance"):
		result.crit = true
		dmg *= cfg.value("crit_multiplier")
	if stealth:
		dmg *= cfg.value("stealth_damage_multiplier")
	result.damage = damage_after_defense(dmg, target.defense)
	target.take_damage(result.damage)
	if result.crit and target.is_alive():
		for id in attacker.weapon.get("crit_conditions", []):
			apply_condition(target, id)
	return result


# Redução percentual da defesa (colete), para baixo, com mínimo de dano.
func damage_after_defense(dmg: float, defense: float) -> int:
	return maxi(floori(dmg * (1.0 - defense) + 0.0001), int(cfg.value("min_damage")))


# Alcance com que `observer` percebe `target`: o da ficha, pela metade se o alvo está agachado.
func perception_range(observer: Combatant, target: Combatant) -> float:
	return observer.perception * (cfg.value("crouch_perception_factor") if target.crouched else 1.0)



# --- Condições ---------------------------------------------------------------
# Léo: sangrando, atordoado, em chamas e envenenado. Percentuais e durações em condicoes.json.

func apply_condition(unit: Combatant, id: String) -> void:
	var c := cfg.condition(id)
	var rounds := -1
	if c["duracao"] == "rodadas":
		var lo := int(c["rodadas"])
		rounds = rng.randi_range(lo, int(c["rodadas_max"])) if c["rodadas_max"] != null else lo
	if unit.conditions.has(id):
		var cur: Dictionary = unit.conditions[id]
		if c["acumula"]:
			cur.stacks = mini(cur.stacks + 1, int(c["acumulo_max"]) if c["acumulo_max"] != null else 99)
		cur.rounds = maxi(cur.rounds, rounds) if rounds >= 0 else -1
		return
	unit.conditions[id] = {"stacks": 1, "rounds": rounds}


# Remove a condição (ex.: bandagem tira o sangramento). Retorna se havia algo a remover.
func remove_condition(unit: Combatant, id: String) -> bool:
	return unit.conditions.erase(id)


# Início do turno: aplica o dano das condições e conta as durações.
# Retorna {damage, skip}: skip = a unidade perde este turno (atordoado).
func start_turn_effects(unit: Combatant) -> Dictionary:
	var out := {"damage": 0, "skip": false}
	for id in unit.conditions.keys():
		var c := cfg.condition(id)
		var state: Dictionary = unit.conditions[id]
		var pct: float = float(c["dano_por_turno"]) * state.stacks
		if pct > 0.0:
			var dmg: int = maxi(floori(unit.max_pv * pct + 0.0001), int(cfg.value("min_damage")))
			unit.take_damage(dmg)
			out.damage += dmg
		if c["pula_turno"]:
			out.skip = true
		if state.rounds > 0:
			state.rounds -= 1
			if state.rounds == 0:
				unit.conditions.erase(id)
	return out
