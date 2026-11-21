class_name ItemRules
extends RefCounted
# Itens de uso em combate (sugestão 5, aprovada pelo Léo em 16/11/2026): coquetel molotov, sinalizador e itens das flores.
# O sal saiu (Léo, 19/11): o jogo não usa sal nem cruzes, os inimigos não são demônios. A granada de luz saiu e o
# coquetel do Fernando ficou no lugar (Léo, 20/11).
# Custam o PA de usar item (custo_pa_combate em itens.json; 1 PA, provisório). Alcance, raio, dano e duração ficam em
# combat.json, bloco "itens_combate", e são todos PROVISÓRIOS do Claude.
#   Sinalizador: luz no chão por alguns turnos de quem lançou; ataques do grupo contra inimigos na luz ganham acerto.
#   Coquetel molotov (Léo, 20/11: material da flor Amarela, vem com o Fernando): fogo no ponto, dano de fogo e em chamas
#   por 2 turnos (Léo, 20/11); só quem está em "so_personagem" (o Fernando) arremessa.
#   Flor (fertilizante, agrotóxico, água, bulbo; Léo, 20/11): jogado numa flor da Dama de Sangue; a flor certa murcha.
# Só regras: a sala escolhe o alvo, tira o item da mochila e mostra o resultado.

const EFFECTS := ["sinalizador", "molotov", "flor"]  # valor de "efeito" em itens.json
const FOGO := "fogo"  # tipo de dano do molotov (fraquezas.json já reservava)

var cfg: CombatConfig
var rules: CombatRules
var rng: RandomNumberGenerator


func _init(config: CombatConfig, combat_rules: CombatRules, random: RandomNumberGenerator = null) -> void:
	cfg = config
	rules = combat_rules
	rng = random if random else RandomNumberGenerator.new()


# Ids dos itens de combate, na ordem de itens.json.
func combat_items() -> Array[String]:
	var out: Array[String] = []
	for id in cfg.game_data.ids("itens"):
		if is_combat_item(id):
			out.append(id)
	return out


func is_combat_item(id: String) -> bool:
	return str(cfg.game_data.get_entry("itens", id).get("efeito", "")) in EFFECTS


func effect(id: String) -> String:
	return str(cfg.game_data.get_entry("itens", id).get("efeito", ""))


# Parâmetros do bloco itens_combate de combat.json para o item.
func params(id: String) -> Dictionary:
	return cfg.data["itens_combate"][effect(id)]


func cost(id: String) -> int:
	var c = cfg.game_data.get_entry("itens", id).get("custo_pa_combate")
	return int(c if c != null else cfg.regra("custo_usar_item_pa", 1))


func range_px(id: String) -> float:
	return float(params(id)["alcance_m"]) * cfg.value("pixels_per_meter")


func radius_px(id: String) -> float:
	return float(params(id).get("raio_m", 0.0)) * cfg.value("pixels_per_meter")


# Só quem o item permite (campo "so_personagem" do bloco itens_combate; o coquetel é do Fernando).
func can_throw(user: Combatant, id: String) -> bool:
	if not is_combat_item(id):
		return false
	var who := str(params(id).get("so_personagem", ""))
	return who == "" or user.personagem == who


# Motivo pelo qual `user` não pode usar o item, ou "" se pode. Códigos do HUD (HudText.REJECTION_MESSAGES).
# `point`: centro do arremesso; `target`: alvo único (efeito "flor": uma flor aberta da Dama de Sangue).
func blocker(user: Combatant, id: String, have: int, point: Vector2, target: Combatant = null, walls: Array[Rect2] = []) -> String:
	if not user.is_alive() or user.insane or not is_combat_item(id) or have <= 0 or not can_throw(user, id):
		return "requirement"
	if effect(id) == "flor" and (target == null or not target.objeto or target.aceita.is_empty() or not target.is_alive() or target.protegido or target.side == user.side):
		return "requirement"
	if user.pa < cost(id):
		return "no_pa"
	var reach := maxf(user.pos.distance_to(point) - user.radius - (target.radius if target else 0.0), 0.0)
	if reach > range_px(id):
		return "out_of_range"
	if not Pathfinder.has_line_of_sight(user.pos, point, walls):
		return "no_line_of_sight"
	return ""


# Usa o item. Retorna {ok, reason, id, effect, point, damage, flare, hits, murchou, sem_efeito}.
# Não mexe na mochila: quem chama tira o item quando ok.
func use(user: Combatant, id: String, have: int, point: Vector2, target: Combatant = null, units: Array = [], walls: Array[Rect2] = []) -> Dictionary:
	var out := {"ok": false, "reason": "", "id": id, "effect": effect(id), "point": point, "damage": 0, "flare": {}, "hits": [], "murchou": false, "sem_efeito": false}
	out.reason = blocker(user, id, have, point, target, walls)
	if out.reason != "":
		return out
	out.ok = true
	user.pa -= cost(id)
	var p := params(id)
	match effect(id):
		"sinalizador":
			out.flare = {"pos": point, "radius": radius_px(id), "rounds": int(p["rodadas"]), "owner": user, "bonus": float(p["bonus_acerto"])}
			rules.lit_zones.append(out.flare)
		"molotov":  # hits: [{unit, damage, sem_efeito}] dos inimigos no raio
			for u: Combatant in units:
				if u.side == user.side or not u.is_alive() or u.pos.distance_to(point) > radius_px(id) + u.radius:
					continue
				u.provoke()
				if not u.fere(FOGO, id):
					out.hits.append({"unit": u, "damage": 0, "sem_efeito": true})
					continue
				var dmg := rng.randi_range(int(p["dano"][0]), int(p["dano"][1]))
				var af := Fraquezas.afinidade(cfg.game_data, u.kind, FOGO)
				var final := rules.damage_after_defense(float(dmg) * Fraquezas.multiplicador(af), u.defense_total())
				u.take_damage(final)
				out.damage += final
				if u.is_alive() and not u.objeto:
					rules.apply_condition(u, "em_chamas")
					if p.has("rodadas_chamas"):  # Léo (20/11): o fogo do coquetel queima 2 turnos, sem sorteio
						u.conditions["em_chamas"].rounds = maxi(int(u.conditions["em_chamas"].rounds), int(p["rodadas_chamas"]))
				out.hits.append({"unit": u, "damage": final, "sem_efeito": false})
		"flor":  # a flor só murcha com o item que ela pede (aceita); com outro, nada acontece
			if target.fere("", id):
				target.pv = 0
				out.murchou = true
			else:
				out.sem_efeito = true
	return out


# Início do turno de `unit`: os sinalizadores que ela lançou perdem um turno e apagam no fim.
func tick(unit: Combatant) -> void:
	for z: Dictionary in rules.lit_zones.duplicate():
		if z.owner == unit:
			z.rounds -= 1
			if z.rounds <= 0:
				rules.lit_zones.erase(z)


# Fim do combate: apaga os sinalizadores.
func clear() -> void:
	rules.lit_zones.clear()
