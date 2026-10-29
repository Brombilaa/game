class_name CombatRules
extends RefCounted
# Regras puras do combate: custo de movimento, chance de acerto, cobertura e dano.
# Os números vêm de CombatConfig; o sorteio usa um RNG injetável para os testes.
#
# Ordem de resolução de um ataque (provisória, para revisão do diretor):
#   1. Validar: PA suficientes, alcance máximo da arma e linha de visão (paredes/portas).
#   2. Chance = base da arma + (precisão - defesa) * hit_per_precision_point
#               - queda por distância além do alcance efetivo; limitada a 5%–95%.
#   3. Errou: fim. Acertou: se o alvo está em cobertura, sorteia o bloqueio completo.
#   4. Dano = sorteio inteiro na faixa da arma; crítico multiplica.
#   5. Cobertura reduz o dano em percentual fixo; arredonda e aplica o mínimo de dano.

var cfg: CombatConfig
var rng: RandomNumberGenerator


func _init(config: CombatConfig, random: RandomNumberGenerator = null) -> void:
	cfg = config
	rng = random if random else RandomNumberGenerator.new()


# --- Movimento ---------------------------------------------------------------

# PA necessários para andar `distance` pixels (arredonda para cima).
func move_cost(distance: float) -> int:
	if distance <= 0.001:
		return 0
	return ceili(distance / cfg.value("pixels_per_pa") - 0.0001)


# Ajusta a rota ao saldo de PA: rota completa se couber, senão movimento parcial
# até o limite dos PA restantes. Retorna {path, cost}. `path` começa na posição atual.
func plan_move(path: PackedVector2Array, pa_available: int) -> Dictionary:
	var length := path_length(path)
	var cost := move_cost(length)
	if cost <= pa_available:
		return {"path": path, "cost": cost}
	var limited := truncate_path(path, pa_available * cfg.value("pixels_per_pa"))
	return {"path": limited, "cost": pa_available}


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


func hit_chance(attacker: Combatant, target: Combatant) -> float:
	var w := attacker.weapon
	var chance := float(w["base_chance"])
	chance += (attacker.precision - target.defense) * cfg.value("hit_per_precision_point")
	chance -= _range_penalty(w, gap(attacker, target))
	return clampf(chance, cfg.value("hit_chance_min"), cfg.value("hit_chance_max"))


func _range_penalty(w: Dictionary, distance: float) -> float:
	var over := maxf(distance - float(w["effective_range"]), 0.0)
	return over / 100.0 * cfg.value("range_falloff_per_100px")


# Motivo pelo qual o ataque não pode ser feito, ou "" se pode.
func attack_blocker(attacker: Combatant, target: Combatant, walls: Array[Rect2]) -> String:
	if not attacker.is_alive() or not target.is_alive():
		return "unidade fora de combate"
	if attacker.pa < int(attacker.weapon["pa_cost"]):
		return "PA insuficientes"
	if gap(attacker, target) > float(attacker.weapon["max_range"]):
		return "fora de alcance"
	if not Pathfinder.has_line_of_sight(attacker.pos, target.pos, walls):
		return "sem linha de visão"
	return ""


# Resolve o ataque, gasta PA e aplica dano. Atacar alguém protegido não danifica a cobertura.
# Retorna {ok, reason, chance, hit, blocked, crit, damage, cover}.
func attack(attacker: Combatant, target: Combatant, walls: Array[Rect2], covers: Array) -> Dictionary:
	var result := {"ok": false, "reason": "", "chance": 0.0, "hit": false, "blocked": false, "crit": false, "damage": 0, "cover": ""}
	result.reason = attack_blocker(attacker, target, walls)
	if result.reason != "":
		return result
	result.ok = true
	attacker.pa -= int(attacker.weapon["pa_cost"])
	result.chance = hit_chance(attacker, target)
	if rng.randf() >= result.chance:
		return result
	result.hit = true
	var c := cover_between(attacker.pos, target, covers)
	var cover_cfg := {}
	if c:
		result.cover = c.kind
		cover_cfg = cfg.cover(c.kind)
		if rng.randf() < float(cover_cfg["block_chance"]):
			result.blocked = true
			return result
	var dmg := float(rng.randi_range(int(attacker.weapon["damage_min"]), int(attacker.weapon["damage_max"])))
	if rng.randf() < cfg.value("crit_chance"):
		result.crit = true
		dmg *= cfg.value("crit_multiplier")
	if c:
		dmg *= 1.0 - float(cover_cfg["damage_reduction"])
	result.damage = maxi(roundi(dmg), int(cfg.value("min_damage")))
	target.take_damage(result.damage)
	return result


# Ataque mirando explicitamente a estrutura de cobertura. Sem defesa nem bloqueio.
# Retorna {ok, reason, chance, hit, damage, destroyed}.
func attack_cover(attacker: Combatant, cover: Cover, walls: Array[Rect2]) -> Dictionary:
	var result := {"ok": false, "reason": "", "chance": 0.0, "hit": false, "damage": 0, "destroyed": false}
	var aim := Vector2(clampf(attacker.pos.x, cover.rect.position.x, cover.rect.end.x), clampf(attacker.pos.y, cover.rect.position.y, cover.rect.end.y))
	if cover.is_destroyed():
		result.reason = "cobertura já destruída"
	elif attacker.pa < int(attacker.weapon["pa_cost"]):
		result.reason = "PA insuficientes"
	elif maxf(attacker.pos.distance_to(aim) - attacker.radius, 0.0) > float(attacker.weapon["max_range"]):
		result.reason = "fora de alcance"
	elif not Pathfinder.has_line_of_sight(attacker.pos, aim, walls):
		result.reason = "sem linha de visão"
	if result.reason != "":
		return result
	result.ok = true
	attacker.pa -= int(attacker.weapon["pa_cost"])
	var w := attacker.weapon
	var distance := maxf(attacker.pos.distance_to(aim) - attacker.radius, 0.0)
	result.chance = clampf(float(w["base_chance"]) - _range_penalty(w, distance), cfg.value("hit_chance_min"), cfg.value("hit_chance_max"))
	if rng.randf() >= result.chance:
		return result
	result.hit = true
	result.damage = rng.randi_range(int(w["damage_min"]), int(w["damage_max"]))
	cover.take_damage(result.damage)
	result.destroyed = cover.is_destroyed()
	return result
