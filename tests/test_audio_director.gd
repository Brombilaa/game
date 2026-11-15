extends SceneTree
# Teste headless do AudioDirector. Rodar com:
#   godot --headless --path . -s tests/test_audio_director.gd

var failures := 0


func _init() -> void:
	var audio := AudioDirector.new()

	# A tabela real carrega e lista os eventos previstos.
	_check(audio.sfx_cues.has("combat_start"), "tabela de efeitos carregada")
	_check(audio.music_cues.has("combat"), "tabela de música carregada")

	# Sem arquivos ainda: tudo fica mudo, sem erro.
	_check(not audio.play_sfx("combat_start"), "efeito sem arquivo fica mudo")
	_check(not audio.play_sfx("nao_existe"), "evento desconhecido fica mudo")
	_check(audio.play_music("combat"), "música de combate toca")
	_check((audio.music_player.stream as AudioStreamOggVorbis).loop, "música de combate repete")
	_check(audio.current_music == "combat", "música pedida fica registrada")
	audio.play_music("combat")
	_check(audio.current_music == "combat", "pedir a mesma música mantém a faixa")
	audio.stop_music()
	_check(audio.play_music("exploration"), "música de investigação toca")
	audio.stop_music()
	_check(audio.current_music == "", "parar música limpa o estado")

	# Caminho inexistente também fica mudo.
	audio.load_cues('{"sfx": {"x": {"path": "res://assets/audio/nao_existe.ogg"}}}')
	_check(not audio.play_sfx("x"), "arquivo inexistente fica mudo")

	# JSON inválido: tabelas vazias.
	audio.load_cues("{ quebrado")
	_check(audio.sfx_cues.is_empty() and audio.music_cues.is_empty(), "JSON inválido deixa tudo mudo")

	# Variações, armas, passos, ambiente e coração (com arquivos de teste temporários).
	var wav := "res://assets/audio/musica_combate.ogg"
	audio.load_cues(JSON.stringify({
		"sfx": {"a": {"paths": [wav, "res://nao_existe.ogg"]}, "shot_pistol": {"path": wav}, "step_floor": {"path": wav}, "step_crouch": {"path": wav}, "heartbeat": {"path": wav, "volume_db": -6.0}},
		"ambience": {"parque": {"path": wav}}, "areas": {"parque": "parque"},
		"weapons": {"pistola": "shot_pistol", "faca": "melee_knife"}}))
	_check(audio.has_sound(audio.sfx_cues, "a"), "variação que existe vale, a que falta é ignorada")
	_check(audio.attack_cue({"id": "pistola"}) == "shot_pistol", "arma na tabela usa o seu evento")
	_check(audio.attack_cue({"id": "x", "tipo": "corpo_a_corpo"}) == "melee_generic", "arma sem evento cai no padrão corpo a corpo")
	_check(audio.attack_cue({"id": "x", "tipo": "distancia"}) == "shot_generic", "arma sem evento cai no padrão de tiro")
	_check(audio.play_attack({"id": "pistola"}), "tiro da pistola toca")
	_check(audio.play_step("floor", false), "passo no piso toca")
	_check(audio.play_step("floor", true), "passo agachado usa o evento próprio")
	_check(not audio.play_step("grass", false), "passo sem arquivo fica mudo")
	_check(audio.play_area_ambience("parque"), "ambiente do cenário toca")
	_check(audio.current_ambience == "parque", "ambiente fica registrado")
	_check(not audio.play_area_ambience("sem_ambiente"), "cenário sem ambiente cala")
	_check(audio.current_ambience == "", "ambiente sem cenário limpa o estado")
	audio.update_heartbeat(0.2)
	_check(audio.heart_player.stream != null, "SAN baixa carrega o batimento")
	_check(audio.heart_player.volume_db > -18.0 and audio.heart_player.volume_db < -6.0, "volume do batimento fica abaixo do cheio com SAN a 20%")
	audio.update_heartbeat(0.9)
	_check(not audio.heart_player.playing, "SAN alta cala o coração")
	audio.play_impact({"hit": false}, false, false)  # sem arquivos: não deve dar erro
	audio.play_impact({"hit": true, "crit": true}, true, true)

	audio.free()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
