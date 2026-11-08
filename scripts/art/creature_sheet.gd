class_name CreatureSheet
extends RefCounted
# Criatura de Sangue em 3D renderizado como pixel art (Mixamo + render do Claude), mesma ideia do AnimSheet.
# Folhas `criatura_<animação>_<s|se|e|ne|n>.png`, quadros em fila. A maioria tem quadros de 384 px
# (pivô 192,358); o ataque tem quadros de 448 px (pivô 224,398). Escala 0,5 na tela. SO, O e NO espelham SE, E e NE.

const ROOT := "res://assets/sprites/personagens/criatura_sangue/criatura_%s_%s.png"
const SCALE := 0.5
# Quadros por segundo PROVISÓRIOS (Léo, 06/11/2026: estavam rápidos demais). Antes: idle 3,7, transição 10,
# andar 6 (hoje o andar vai por distância, ver CREATURE_WALK_CYCLE_PIXELS), ataque 5 (hoje vai por CREATURE_ATTACK_SECONDS), morte 7,5.
const FPS := {"idle": 3.0, "transition": 6.0, "walk": 6.0, "attack": 5.0, "death": 5.0}
const NAMES := ["idle", "transition", "walk", "attack", "death"]
const FRAME := {"idle": 384, "transition": 384, "walk": 384, "attack": 448, "death": 384}
const PIVOT := {
	"idle": Vector2(192, 358), "transition": Vector2(192, 358), "walk": Vector2(192, 358),
	"attack": Vector2(224, 398), "death": Vector2(192, 358),
}

var textures := {}  # animação -> {"se": Texture2D, ...}


func _init() -> void:
	for anim in NAMES:
		var per_dir := {}
		for d in ["se", "e", "ne", "s", "n"]:
			per_dir[d] = load(ROOT % [anim, d])
		textures[anim] = per_dir


func frame_count(anim: String) -> int:
	return int(textures[anim]["e"].get_width() / FRAME[anim])


func draw(canvas: CanvasItem, pos: Vector2, anim: String, frame: int, dir: CharacterSheet.Dir) -> void:
	if canvas.has_method("_model3d") and canvas._model3d("criatura", pos, anim, float(frame) / maxf(frame_count(anim), 1), dir):
		return  # parque 3D: o modelo 3D faz a pose no lugar da folha
	var info: Array = CharacterSheet.SHEET_OF[dir]
	var tex: Texture2D = textures[anim][info[0]]
	var fs: int = FRAME[anim]
	var size := Vector2(fs, fs) * SCALE
	var src := Rect2(frame * fs, 0, fs, fs)
	var pivot: Vector2 = PIVOT[anim] * SCALE
	var origin := (pos - pivot).round()
	if canvas.has_method("_sprite3d"):  # parque 3D: o quadro vira um cartão dentro do mundo 3D
		canvas._sprite3d(tex, src, pivot / SCALE, SCALE, info[1], pos)
		return
	if info[1]:
		canvas.draw_set_transform(Vector2(origin.x + pivot.x, origin.y), 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(tex, Rect2(Vector2(-pivot.x, 0), size), src)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(origin, size), src)
