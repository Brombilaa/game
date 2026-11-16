class_name Scenes
extends RefCounted
# Ponto único para trocar de cena. Usa o autoload SceneLoader (fade + trava);
# sem ele (testes rodando com -s), troca direto.


static func go(tree: SceneTree, path: String) -> bool:
	var loader := tree.root.get_node_or_null("SceneLoader")
	if loader:
		if loader.busy:
			return false
		loader.go(path)
		return true
	return tree.change_scene_to_file(path) == OK


static func busy(tree: SceneTree) -> bool:
	var loader := tree.root.get_node_or_null("SceneLoader")
	return loader != null and loader.busy
