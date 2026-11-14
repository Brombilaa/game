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

	audio.free()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
