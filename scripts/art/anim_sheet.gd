class_name AnimSheet
extends RefCounted
# Animações do Nikolai em 3D renderizado como pixel art (Hunyuan3D + Mixamo, render do Claude).
# Uma folha por animação e direção: `nikolai3d_<animação>_<s|se|e|ne|n>.png`, quadros de 192×192
# em fila. SO, O e NO espelham SE, E e NE, como em CharacterSheet. Os pés ficam no mesmo ponto.

const ROOT := "res://assets/sprites/personagens/nikolai3d/nikolai3d_%s_%s.png"
# Animação -> quadros por segundo. A ordem é a do ciclo da tecla N na sala de teste.
const FPS := {
	"idle": 4.0, "walk": 10.0, "pistol_idle": 6.0, "pistol_walk": 10.0, "crouch_walk": 8.0,
	"rifle_walk": 10.0, "run": 14.0, "pickup_object": 10.0, "pickup": 5.0, "opening": 5.0,
	"pistol_aim_prov": 6.0,
}
const NAMES := ["idle", "walk", "pistol_idle", "pistol_walk", "crouch_walk", "rifle_walk", "run", "pickup_object", "pickup", "opening", "pistol_aim_prov"]

var textures := {}  # animação -> {"se": Texture2D, ...}


func _init() -> void:
	for anim in NAMES:
		var per_dir := {}
		for d in ["se", "e", "ne", "s", "n"]:
			per_dir[d] = load(ROOT % [anim, d])
		textures[anim] = per_dir


func frame_count(anim: String) -> int:
	return int(textures[anim]["e"].get_width() / CharacterSheet.FRAME)


# Desenha o quadro `frame` da animação virado para `dir`, com os pés em `pos`.
func draw(canvas: CanvasItem, pos: Vector2, anim: String, frame: int, dir: CharacterSheet.Dir) -> void:
	var info: Array = CharacterSheet.SHEET_OF[dir]
	var tex: Texture2D = textures[anim][info[0]]
	var size := Vector2(CharacterSheet.FRAME, CharacterSheet.FRAME)
	var src := Rect2(frame * CharacterSheet.FRAME, 0, CharacterSheet.FRAME, CharacterSheet.FRAME)
	var origin := (pos - CharacterSheet.PIVOT).round()
	if info[1]:
		canvas.draw_set_transform(Vector2(origin.x + CharacterSheet.PIVOT.x, origin.y), 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(tex, Rect2(Vector2(-CharacterSheet.PIVOT.x, 0), size), src)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(origin, size), src)
