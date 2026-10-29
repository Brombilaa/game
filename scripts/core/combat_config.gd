class_name CombatConfig
extends RefCounted
# Valores de balanceamento do combate. Constantes do protótipo vêm de data/combat.json;
# armas e fichas de inimigo vêm das tabelas de GameData (armas.json, inimigos.json).
# Nada aqui é definitivo: os números estão PENDENTES no GDD e ficam nos arquivos de dados.

const DEFAULT_PATH := "res://data/combat.json"

var data: Dictionary = {}
var game_data: GameData


static func load_file(path: String = DEFAULT_PATH, data_dir: String = "res://data") -> CombatConfig:
	var cfg := CombatConfig.new()
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "combat.json inválido: " + path)
	cfg.data = parsed
	cfg.game_data = GameData.new()
	if not cfg.game_data.load_dir(data_dir):
		push_error("\n".join(cfg.game_data.errors))
	return cfg


func value(key: String) -> float:
	return float(data[key])


func cover(kind: String) -> Dictionary:
	return data["cover"][kind]


# Arma de armas.json no formato usado por CombatRules (distâncias já em pixels).
# Alcance efetivo = fim da distância ideal. Custo em PA: custo_corpo_a_corpo_pa ou
# custo_ataque_distancia_pa das regras, conforme o tipo; enquanto null, attack_pa_cost provisório.
func weapon(id: String) -> Dictionary:
	var w := game_data.get_entry("armas", id)
	assert(not w.is_empty(), "arma inexistente: " + id)
	var ppm := value("pixels_per_meter")
	var cost = game_data.rule("custo_corpo_a_corpo_pa" if w["tipo"] == "corpo_a_corpo" else "custo_ataque_distancia_pa")
	return {
		"id": id,
		"pa_cost": int(cost) if cost != null else int(value("attack_pa_cost")),
		"base_chance": float(w["precisao_base"]),
		"effective_range": float(w["distancia_ideal"][1]) * ppm,
		"max_range": float(w["alcance_maximo"]) * ppm,
		"damage_min": int(w["dano"][0]),
		"damage_max": int(w["dano"][1]),
	}


# Cria um protagonista de teste a partir da ficha em "units" de combat.json
# (personagens.json ainda não tem atributos nem classes definidos).
func make_unit(unit_id: String, display_name: String, pos: Vector2) -> Combatant:
	var sheet: Dictionary = data["units"][unit_id]
	var u := Combatant.new()
	u.name = display_name
	u.side = Combatant.Side.PLAYER if sheet["side"] == "player" else Combatant.Side.ENEMY
	u.max_pv = int(sheet["pv"])
	u.pv = u.max_pv
	u.initiative = int(sheet["initiative"])
	u.precision = int(sheet["precision"])
	u.defense = int(sheet["defense"])
	u.weapon = weapon(sheet["weapon"])
	u.radius = float(sheet["radius"])
	u.pos = pos
	return u


# Cria um inimigo a partir de inimigos.json. Usa o primeiro ataque da ficha.
func make_enemy(enemy_id: String, pos: Vector2) -> Combatant:
	var sheet := game_data.get_entry("inimigos", enemy_id)
	assert(not sheet.is_empty(), "inimigo inexistente: " + enemy_id)
	var u := Combatant.new()
	u.name = sheet["nome"]
	u.side = Combatant.Side.ENEMY
	u.max_pv = int(sheet["pv"])
	u.pv = u.max_pv
	u.pa_per_turn = int(sheet["pa"]) if sheet["pa"] != null else -1
	u.initiative = int(sheet["iniciativa"])
	u.precision = int(sheet["precisao"]) if sheet["precisao"] != null else int(value("enemy_precision"))
	u.defense = int(sheet["defesa"]) if sheet["defesa"] != null else int(value("enemy_defense"))
	u.weapon = weapon(sheet["ataques"][0])
	u.radius = value("enemy_radius")
	u.pos = pos
	return u
