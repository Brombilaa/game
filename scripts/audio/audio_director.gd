class_name AudioDirector
extends Node
# Toca efeitos e música por nome de evento sonoro, lidos de data/audio_cues.json.
# Evento sem arquivo (caminho vazio ou inexistente) fica mudo, sem erro, para o
# jogo rodar antes de existir qualquer áudio. Quem chama decide quando tocar.

const CUES_PATH := "res://data/audio_cues.json"
const SFX_VOICES := 4
const MUSIC_BUS := &"Music"  # default_bus_layout.tres; o volume vem das Opções
const SFX_BUS := &"SFX"

var sfx_cues := {}
var music_cues := {}
var ambience_cues := {}
var area_cues := {}  # id do cenário -> ambiente
var weapon_cues := {}  # id da arma -> evento (tiro/golpe); arma fora da tabela usa o padrão do tipo
var current_ambience := ""
var ambience_player: AudioStreamPlayer
var heart_player: AudioStreamPlayer
var _last_variant := {}  # evento -> última variação tocada, para não repetir em seguida
var current_music := ""
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _init() -> void:
	load_cues(FileAccess.get_file_as_string(CUES_PATH))
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = SFX_BUS
	add_child(ambience_player)
	heart_player = AudioStreamPlayer.new()
	heart_player.bus = SFX_BUS
	add_child(heart_player)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		sfx_players.append(p)


# Lê a tabela de eventos. Texto inválido deixa as tabelas vazias (tudo mudo).
func load_cues(json_text: String) -> void:
	var data = JSON.parse_string(json_text) if not json_text.is_empty() else null
	if not data is Dictionary:
		sfx_cues = {}
		music_cues = {}
		ambience_cues = {}
		weapon_cues = {}
		area_cues = {}
		return
	sfx_cues = data.get("sfx", {})
	music_cues = data.get("music", {})
	ambience_cues = data.get("ambience", {})
	weapon_cues = data.get("weapons", {})
	area_cues = data.get("areas", {})


# Retorna true se o evento tem um arquivo de áudio que existe.
func has_sound(table: Dictionary, cue: String) -> bool:
	return not _paths_of(table, cue).is_empty()


# Caminhos que existem de um evento. "path" é um arquivo; "paths" são variações (sorteadas a cada toque).
func _paths_of(table: Dictionary, cue: String) -> Array[String]:
	var entry: Dictionary = table.get(cue, {})
	var out: Array[String] = []
	var all: Array = entry.get("paths", [])
	if entry.has("path"):
		all = all + [entry["path"]]
	for p in all:
		if not str(p).is_empty() and ResourceLoader.exists(str(p)):
			out.append(str(p))
	return out


func _pick(table: Dictionary, cue: String) -> String:
	var options := _paths_of(table, cue)
	if options.is_empty():
		return ""
	var chosen := options[randi() % options.size()]
	if options.size() > 1 and chosen == _last_variant.get(cue, ""):
		chosen = options[(options.find(chosen) + 1) % options.size()]
	_last_variant[cue] = chosen
	return chosen


func play_sfx(cue: String) -> bool:
	if not has_sound(sfx_cues, cue):
		return false
	var p := sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	_start(p, sfx_cues[cue], _pick(sfx_cues, cue))
	return true


# Troca a música; pedir a música que já toca não reinicia a faixa.
func play_music(cue: String) -> bool:
	if cue == current_music:
		return music_player.playing
	current_music = cue
	music_player.stop()
	if not has_sound(music_cues, cue):
		return false
	_start(music_player, music_cues[cue], _pick(music_cues, cue))
	return true


func stop_music() -> void:
	current_music = ""
	music_player.stop()


# Som ambiente do lugar (delegacia à noite, parque à noite...); "" ou sem arquivo cala o ambiente.
func play_ambience(cue: String) -> bool:
	if cue == current_ambience:
		return ambience_player.playing
	current_ambience = cue
	ambience_player.stop()
	if cue.is_empty() or not has_sound(ambience_cues, cue):
		return false
	_start(ambience_player, ambience_cues[cue], _pick(ambience_cues, cue))
	return true


func play_area_ambience(area_id: String) -> bool:
	return play_ambience(str(area_cues.get(area_id, "")))


# Evento do disparo ou golpe da arma. `weapon` é a ficha de armas.json (id e tipo).
func attack_cue(weapon: Dictionary) -> String:
	var id := str(weapon.get("id", ""))
	if weapon_cues.has(id):
		return str(weapon_cues[id])
	return "melee_generic" if str(weapon.get("tipo", "")) == "corpo_a_corpo" else "shot_generic"


func play_attack(weapon: Dictionary) -> bool:
	return play_sfx(attack_cue(weapon))


# Resultado do golpe no alvo: errou, bloqueado, acerto (colete abafa), caiu e grito.
func play_impact(r: Dictionary, target_vest: bool, target_down: bool) -> void:
	if r.get("blocked", false):
		play_sfx("shot_blocked")
	elif not r.get("hit", false):
		play_sfx("miss")
	else:
		play_sfx("hit_vest" if target_vest else ("hit_crit" if r.get("crit", false) else "hit_flesh"))
		play_sfx("pain")
	if target_down:
		play_sfx("body_fall")


# Passo: a superfície ("floor", "grass") e a postura escolhem o evento.
func play_step(surface: String, crouched: bool) -> bool:
	return play_sfx("step_crouch" if crouched else "step_" + surface)


# Coração com SAN baixa: batimento em laço enquanto a SAN estiver abaixo do limite (fração 0..1);
# o volume sobe quanto menor a SAN. Sem arquivo, fica mudo.
const HEART_BELOW := 0.4


func update_heartbeat(san_ratio: float) -> void:
	if san_ratio >= HEART_BELOW or not has_sound(sfx_cues, "heartbeat"):
		if heart_player.playing:
			heart_player.stop()
		return
	var base := float(sfx_cues["heartbeat"].get("volume_db", 0.0))
	heart_player.volume_db = base - 12.0 * (san_ratio / HEART_BELOW)  # SAN 0: volume cheio
	if not heart_player.playing:
		var stream = load(_pick(sfx_cues, "heartbeat"))
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		heart_player.stream = stream
		if heart_player.is_inside_tree():
			heart_player.play()


func on_boss_appeared() -> void:
	play_music("combat_boss")


func on_combat_started() -> void:
	play_sfx("combat_start")
	play_music("combat")


func on_combat_ended() -> void:
	play_music("exploration")
	update_heartbeat(1.0)


func _start(p: AudioStreamPlayer, cue: Dictionary, path: String) -> void:
	var stream = load(path)
	# Música e ambiente repetem sozinhos; efeitos tocam uma vez.
	if (p == music_player or p == ambience_player) and stream is AudioStreamOggVorbis:
		stream.loop = true
	p.stream = stream
	p.volume_db = cue.get("volume_db", 0.0)
	if p.is_inside_tree():
		p.play()
