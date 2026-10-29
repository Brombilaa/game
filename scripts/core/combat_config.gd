class_name CombatConfig
extends RefCounted
# Valores de balanceamento do combate, lidos de data/combat.json.
# Nada aqui é definitivo: os números estão PENDENTES no GDD e ficam no arquivo de dados.

const DEFAULT_PATH := "res://data/combat.json"

var data: Dictionary = {}


static func load_file(path: String = DEFAULT_PATH) -> CombatConfig:
	var cfg := CombatConfig.new()
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "combat.json inválido: " + path)
	cfg.data = parsed
	return cfg


func value(key: String) -> float:
	return float(data[key])


func cover(kind: String) -> Dictionary:
	return data["cover"][kind]


func weapon(id: String) -> Dictionary:
	return data["weapons"][id]


# Cria um combatente a partir da ficha em "units".
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
