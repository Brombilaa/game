class_name IdleSheet
extends RefCounted
# Personagem com só a animação de parado (idle), em 3D renderizado no estilo PC antigo: Fernando e Caio por enquanto.
# Folhas `<nome>_idle_<s|se|e|ne|n>.png`, 16 quadros de 384 px em fila, desenhados a 50% (mesmo tamanho e pivô do AnimSheet).
# SO, O e NO espelham SE, E e NE, como em CharacterSheet.

const FRAME := 384
const SCALE := 0.5
const PIVOT := Vector2(192, 358)
const FPS := 2.0  # o ciclo do Mixamo tem 8,3 s para 16 quadros: velocidade original

var textures := {}  # direção ("se", "e", ...) -> Texture2D


func _init(folder: String, prefix: String) -> void:
	for d in ["se", "e", "ne", "s", "n"]:
		textures[d] = load("res://assets/sprites/personagens/%s/%s_idle_%s.png" % [folder, prefix, d])


func frame_count() -> int:
	return int(textures["e"].get_width() / FRAME)


# Quadro do momento atual (relógio em milissegundos).
func frame_at(now_msec: int) -> int:
	return int(now_msec / 1000.0 * FPS) % frame_count()


func draw(canvas: CanvasItem, pos: Vector2, frame: int, dir: CharacterSheet.Dir) -> void:
	var info: Array = CharacterSheet.SHEET_OF[dir]
	var tex: Texture2D = textures[info[0]]
	var size := Vector2(FRAME, FRAME) * SCALE
	var src := Rect2(frame * FRAME, 0, FRAME, FRAME)
	var pivot := PIVOT * SCALE
	var origin := (pos - pivot).round()
	if info[1]:
		canvas.draw_set_transform(Vector2(origin.x + pivot.x, origin.y), 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(tex, Rect2(Vector2(-pivot.x, 0), size), src)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(origin, size), src)
