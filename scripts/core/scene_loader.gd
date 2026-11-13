extends CanvasLayer
# Autoload "SceneLoader": troca de cena com fade preto e trava contra segunda
# chamada (clique duplo em Novo jogo, por exemplo). Use Scenes.go(tree, path),
# que cai na troca direta quando o autoload não existe (testes headless).

const FADE_SECONDS := 0.35

var busy := false
var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


# Devolve false se já houver uma troca em andamento ou se a cena não existir.
func go(path: String) -> bool:
	if busy or not ResourceLoader.exists(path):
		return false
	busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # bloqueia cliques durante o fade
	await _fade(1.0)
	var err := get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade(0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	return err == OK


func _fade(to: float) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", to, FADE_SECONDS)
	await tw.finished
