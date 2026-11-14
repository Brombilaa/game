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
var current_music := ""
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _init() -> void:
	load_cues(FileAccess.get_file_as_string(CUES_PATH))
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	add_child(music_player)
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
		return
	sfx_cues = data.get("sfx", {})
	music_cues = data.get("music", {})


# Retorna true se o evento tem um arquivo de áudio que existe.
func has_sound(table: Dictionary, cue: String) -> bool:
	var path: String = table.get(cue, {}).get("path", "")
	return not path.is_empty() and ResourceLoader.exists(path)


func play_sfx(cue: String) -> bool:
	if not has_sound(sfx_cues, cue):
		return false
	var p := sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	_start(p, sfx_cues[cue])
	return true


# Troca a música; pedir a música que já toca não reinicia a faixa.
func play_music(cue: String) -> bool:
	if cue == current_music:
		return music_player.playing
	current_music = cue
	music_player.stop()
	if not has_sound(music_cues, cue):
		return false
	_start(music_player, music_cues[cue])
	return true


func stop_music() -> void:
	current_music = ""
	music_player.stop()


func on_combat_started() -> void:
	play_sfx("combat_start")
	play_music("combat")


func on_combat_ended() -> void:
	play_music("exploration")


func _start(p: AudioStreamPlayer, cue: Dictionary) -> void:
	var stream = load(cue["path"])
	# Música repete sozinha; efeitos tocam uma vez.
	if p == music_player and stream is AudioStreamOggVorbis:
		stream.loop = true
	p.stream = stream
	p.volume_db = cue.get("volume_db", 0.0)
	if p.is_inside_tree():
		p.play()
