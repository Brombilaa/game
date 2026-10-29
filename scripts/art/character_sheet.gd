class_name CharacterSheet
extends RefCounted
# Folha de poses de um personagem feita a partir de uma imagem do ChatGPT (tools/sprites/converter.py).
# Uma fila de 8 quadros de 144×144: 0 e 1 parado, 2 a 7 andando. Desenhada virada para a direita
# (leste); para a esquerda o quadro é espelhado. Direções diagonais e de costas ainda não existem.

const FRAME := 144
const IDLE_FRAMES := [0, 1]
const WALK_FRAMES := [2, 3, 4, 5, 6, 7]
# Ponto do quadro que fica sobre a posição da unidade: meio dos pés.
const PIVOT := Vector2(72, 135)
# Altura do personagem acima do pivô, para posicionar barras de vida.
const HEIGHT := 100.0

var texture: Texture2D


func _init(path: String) -> void:
	texture = load(path)


func frame_count() -> int:
	return int(texture.get_width() / FRAME)


# Desenha o quadro `frame` com os pés em `pos`. `flip` espelha para a esquerda.
func draw(canvas: CanvasItem, pos: Vector2, frame: int, flip: bool) -> void:
	var src := Rect2(frame * FRAME, 0, FRAME, FRAME)
	var origin := (pos - PIVOT).round()
	if flip:
		# Espelha em torno do pivô: largura negativa mantém o pé no mesmo lugar.
		canvas.draw_texture_rect_region(texture, Rect2(origin + Vector2(FRAME, 0), Vector2(-FRAME, FRAME)), src)
	else:
		canvas.draw_texture_rect_region(texture, Rect2(origin, Vector2(FRAME, FRAME)), src)
