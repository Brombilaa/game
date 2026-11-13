extends SceneTree
# Teste headless da base do menu: autoload Game, SceneLoader (fade e trava contra
# clique duplo), buses de áudio e gravação das opções. Rodar com:
#   godot --headless --path . -s tests/test_scene_loader.gd

const OPTIONS_PATH := "user://test_opcoes_loader.cfg"
const TARGET := "res://scenes/menu/main_menu.tscn"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	# Buses de música e efeitos existem para os volumes funcionarem.
	_check(AudioServer.get_bus_index("Music") > 0, "bus Music existe")
	_check(AudioServer.get_bus_index("SFX") > 0, "bus SFX existe")
	var audio := AudioDirector.new()
	_check(audio.music_player.bus == &"Music", "música toca no bus Music")
	_check(audio.sfx_players[0].bus == &"SFX", "efeitos tocam no bus SFX")
	audio.free()

	# Volumes mexem nos buses certos.
	var o := GameOptions.load_from(OPTIONS_PATH)
	o.set_volume("music", 0.5)
	o.set_volume("sfx", 0.0)
	o.apply()
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5)), "volume da música vai para o bus Music")
	_check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) < -60.0, "efeitos em zero ficam mudos")

	# Game e SceneLoader são autoloads do projeto; se o modo -s não os criou, cria aqui.
	var game: Node = root.get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/core/game.gd").new()
		game.name = "Game"
		root.add_child(game)
		await process_frame
	_check(GameOptions.shared() == game.options, "GameOptions.shared() devolve a cópia única do Game")
	_check(GameOptions.shared() == GameOptions.shared(), "menu e jogo recebem a mesma cópia")
	var loader: Node = root.get_node_or_null("SceneLoader")
	if loader == null:
		loader = load("res://scripts/core/scene_loader.gd").new()
		loader.name = "SceneLoader"
		root.add_child(loader)
		await process_frame
	_check(Scenes.go(self, TARGET), "primeira troca de cena é aceita")
	_check(Scenes.busy(self), "troca em andamento fica marcada")
	_check(not Scenes.go(self, TARGET), "segundo pedido durante a troca é ignorado")
	_check(not await loader.go("res://nao_existe.tscn"), "cena inexistente é recusada")
	var waited := 0.0
	while Scenes.busy(self) and waited < 3.0:
		await process_frame
		waited += 1.0 / 60.0
	_check(not Scenes.busy(self), "troca termina")
	_check(current_scene != null and current_scene.scene_file_path == TARGET, "cena nova ficou ativa")

	DirAccess.remove_absolute(OPTIONS_PATH)
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok    - " + label)
	else:
		failures += 1
		print("FALHA - " + label)
