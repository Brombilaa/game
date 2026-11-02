class_name GameOptions
extends RefCounted
# Opções do menu inicial: volumes (0 a 1) e tela cheia, gravados em user://opcoes.cfg.
# O volume geral vai no bus Master. Música e efeitos usam os buses "Music" e "SFX" quando
# existirem; hoje o projeto só tem o Master, então esses dois ficam guardados para depois.

const PATH := "user://opcoes.cfg"
const SECTION := "opcoes"
const DEFAULTS := {"master": 0.8, "music": 0.6, "sfx": 0.7, "fullscreen": false, "fast_combat": false}
const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX"}

var values: Dictionary = DEFAULTS.duplicate()


static func load_from(path := PATH) -> GameOptions:
	var options := GameOptions.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for key in DEFAULTS:
			options.values[key] = cfg.get_value(SECTION, key, DEFAULTS[key])
	for key in BUSES:
		options.set_volume(key, float(options.values[key]))
	options.values["fullscreen"] = bool(options.values["fullscreen"])
	options.values["fast_combat"] = bool(options.values["fast_combat"])
	return options


func volume(key: String) -> float:
	return float(values.get(key, 0.0))


func set_volume(key: String, value: float) -> void:
	values[key] = clampf(snappedf(value, 0.05), 0.0, 1.0)


func save(path := PATH) -> Error:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value(SECTION, key, values[key])
	return cfg.save(path)


func apply() -> void:
	for key in BUSES:
		var bus := AudioServer.get_bus_index(BUSES[key])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume(key), 0.0001)))
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if values["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
