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
var units: Array = []  # todos em combate (a sala atualiza); usado para achar o aliado que flanqueia


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
	if flanker(attacker, target) != null:
		chance += cfg.value("flank_hit_bonus")
	chance += maxi(attacker.initiative - 1, 0) * cfg.value("agi_hit_bonus")  # initiative = AGI
	if attacker.ruptured:
		chance -= float(cfg.san("ruptura_acerto"))  # ruptura de SAN (GDD #11)
	chance -= _range_penalty(w, gap(attacker, target))
	var c := cover_between(attacker.pos, target, covers)
	if c and c.kind == "partial":
		chance -= float(cfg.cover("partial")["hit_penalty"])
	return clampf(chance, cfg.value("hit_chance_min"), cfg.value("hit_chance_max"))


# Aliado do atacante que flanqueia o alvo (M4): vivo, a até `flank_max_distance_m` do alvo e do lado
# oposto ao atacante (ângulo em torno do alvo de `flank_min_angle_deg` ou mais). Null se nenhum.
func flanker(attacker: Combatant, target: Combatant) -> Combatant:
	var reach := cfg.value("flank_max_distance_m") * cfg.value("pixels_per_meter")
	var min_angle := deg_to_rad(cfg.value("flank_min_angle_deg"))
	var to_attacker := attacker.pos - target.pos
	if to_attacker.length() < 0.001:
		return null
	for u: Combatant in units:
		if u == attacker or u == target or not u.is_alive() or u.side != attacker.side:
			continue
		var to_ally := u.pos - target.pos
		if to_ally.length() > reach or to_ally.length() < 0.001:
			continue
		if absf(to_attacker.angle_to(to_ally)) >= min_angle:
			return u
	return null


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
	if needs_reload(attacker):
		return "no_ammo"
	if gap(attacker, target) > float(attacker.weapon["max_range"]):
		return "out_of_range"
	if not Pathfinder.has_line_of_sight(attacker.pos, target.pos, walls):
		return "no_line_of_sight"
	if not attacker.weapon.get("melee", false):
		for c: Cover in covers:
			if c.kind == "full" and Pathfinder.segment_crosses_rect(attacker.pos, target.pos, c.rect):
				return "no_line_of_sight"
	return ""


# Arma com carregador (mag_size > 0) que a unidade controla (u.mag) e carregador vazio.
# Quem não tem o carregador registrado (inimigos) atira sem limite.
func needs_reload(u: Combatant) -> bool:
	return int(u.weapon.get("mag_size", 0)) > 0 and u.mag.has(u.weapon["id"]) and int(u.mag[u.weapon["id"]]) <= 0


# Resolve o ataque, gasta PA e aplica dano. Coberturas não são destruídas (Léo: ainda não).
# stealth: ataque furtivo contra inimigo sem alerta (bônus de acerto e multiplicador de dano).
# Retorna {ok, reason, chance, hit, blocked, crit, damage, cover, flank, tipo_dano, afinidade ("fraqueza"/"resistencia"/"")}.
func attack(attacker: Combatant, target: Combatant, walls: Array[Rect2], covers: Array, stealth := false) -> Dictionary:
	var result := {"ok": false, "reason": "", "chance": 0.0, "hit": false, "blocked": false, "crit": false, "damage": 0, "cover": "", "flank": false, "tipo_dano": "", "afinidade": ""}
	result.reason = attack_blocker(attacker, target, walls, covers)
	if result.reason != "":
		return result
	result.ok = true
	attacker.pa -= int(attacker.weapon["pa_cost"])
	if int(attacker.weapon.get("mag_size", 0)) > 0 and attacker.mag.has(attacker.weapon["id"]):
		attacker.mag[attacker.weapon["id"]] = int(attacker.mag[attacker.weapon["id"]]) - 1  # cada tiro gasta 1 bala
	var c := cover_between(attacker.pos, target, covers)
	if c:
		result.cover = c.kind
	result.flank = flanker(attacker, target) != null
	result.chance = hit_chance(attacker, target, covers, stealth)
	if rng.randf() >= result.chance:
		return result
	result.hit = true
	var dmg := float(rng.randi_range(int(attacker.weapon["damage_min"]), int(attacker.weapon["damage_max"])))
	dmg += Ficha.bonus_dano(cfg.game_data, attacker.atributos, attacker.weapon)  # Força (provisório, GDD #11)
	dmg += attacker.damage_bonus()  # Amaldiçoar Arma de Sangue (ritual)
	if rng.randf() < cfg.value("crit_chance"):
		result.crit = true
		dmg *= cfg.value("crit_multiplier")
	if stealth:
		dmg *= cfg.value("stealth_damage_multiplier")
	if attacker.ruptured:
		dmg *= 1.0 - float(cfg.san("ruptura_dano"))
	result.tipo_dano = Fraquezas.tipo_da_arma(attacker.weapon)
	result.afinidade = Fraquezas.afinidade(cfg.game_data, target.kind, result.tipo_dano)  # fraqueza/resistência (provisório)
	dmg *= Fraquezas.multiplicador(result.afinidade)
	result.damage = damage_after_defense(dmg, target.defense_total())
	target.take_damage(result.damage)
	if result.crit and target.is_alive():
		for id in attacker.weapon.get("crit_conditions", []):
			apply_condition(target, id)
	return result


# Redução percentual da defesa (colete), para baixo, com mínimo de dano.
func damage_after_defense(dmg: float, defense: float) -> int:
	return maxi(floori(dmg * (1.0 - defense) + 0.0001), int(cfg.value("min_damage")))


# --- Vigilância ----------------------------------------------------------------
# Léo (15/11): gastar PA para atirar no primeiro inimigo que se mover na linha de visão. Os PA de um tiro
# são pagos ao entrar em vigilância; ela dispara uma vez e acaba, ou termina no próximo turno de quem vigia.

# Motivo pelo qual `u` não pode entrar em vigilância, ou "" se pode (mesmos códigos do HUD).
func overwatch_blocker(u: Combatant) -> String:
	if not u.is_alive() or u.overwatch or u.weapon.is_empty() or u.weapon.get("melee", false):
		return "requirement"
	if u.pa < int(u.weapon["pa_cost"]):
		return "no_pa"
	if needs_reload(u):
		return "no_ammo"
	return ""


# Entra em vigilância: paga o tiro e marca a unidade. Retorna o motivo da recusa ou "" se entrou.
func start_overwatch(u: Combatant, dir := Vector2.ZERO) -> String:
	var reason := overwatch_blocker(u)
	if reason != "":
		return reason
	if dir.length() > 0.001:
		u.overwatch_dir = dir.normalized()
	u.pa -= int(u.weapon["pa_cost"])
	u.overwatch = true
	return ""


# Primeiro vigia (do lado oposto) que pode atirar em `mover` onde ele está agora: alcance, linha de visão
# e munição valem como num ataque comum, e o alvo precisa estar dentro do cone apontado (os PA já foram pagos). Null se nenhum.
func overwatch_watcher(mover: Combatant, walls: Array[Rect2], covers: Array = []) -> Combatant:
	if not mover.is_alive():
		return null
	for u: Combatant in units:
		if u == mover or not u.is_alive() or not u.overwatch or u.side == mover.side:
			continue
		var to_mover := mover.pos - u.pos
		if to_mover.length() > 0.001 and absf(u.overwatch_dir.angle_to(to_mover)) > deg_to_rad(cfg.value("overwatch_half_angle_deg")):
			continue  # fora do cone
		var credit := int(u.weapon["pa_cost"])
		u.pa += credit  # o blocker confere PA; aqui já estão pagos
		var reason := attack_blocker(u, mover, walls, covers)
		u.pa -= credit
		if reason == "":
			return u
	return null


# Tiro de reação do vigia: consome a vigilância, vale o PA já pago e leva a penalidade de acerto.
func overwatch_shot(watcher: Combatant, target: Combatant, walls: Array[Rect2], covers: Array = []) -> Dictionary:
	var credit := int(watcher.weapon["pa_cost"])
	var kept := watcher.hit_bonus
	watcher.overwatch = false
	watcher.pa += credit
	watcher.hit_bonus -= cfg.value("overwatch_hit_penalty")
	var r := attack(watcher, target, walls, covers)
	watcher.hit_bonus = kept
	if not r.ok:
		watcher.pa -= credit
	return r


# Alcance com que `observer` percebe `target`: o da ficha, pela metade se o alvo está agachado e, à noite
# (modelo C, luz e furtividade), menor na sombra e maior na luz ou com a lanterna acesa.
func perception_range(observer: Combatant, target: Combatant) -> float:
	var r := observer.perception * (cfg.value("crouch_perception_factor") if target.crouched else 1.0)
	return r * light_factor(target)


# Fator da luz sobre a percepção: de dark_perception_factor (sombra total) a lit_perception_factor (luz cheia).
func light_factor(target: Combatant) -> float:
	if target.iluminacao < 0.0:
		return 1.0
	return lerpf(cfg.value("dark_perception_factor"), cfg.value("lit_perception_factor"), clampf(target.iluminacao, 0.0, 1.0))



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
	for id in unit.buffs.keys():  # rituais: contam os turnos do próprio conjurador
		unit.buffs[id].rounds -= 1
		if unit.buffs[id].rounds <= 0:
			unit.buffs.erase(id)
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
