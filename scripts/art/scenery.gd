class_name Scenery
extends RefCounted
## Peças de cenário isométricas geradas no ChatGPT (chão 96×48, paredes de 2 tiles, móveis).
## Cada parede e móvel tem uma âncora (pontos da base) em `pecas.json`; o resto é textura solta.

const DIR := "res://assets/sprites/cenario/"
const FLOOR_COUNT := 5  # 0 lisa, 1 gasta, 2 buraco, 3 sangue, 4 entulho
# Sorteio fixo do piso por tile (hash do índice): 70% tábua lisa, o resto gasta, entulho, buraco ou sangue.
const FLOOR_PLAIN := 0
const FLOOR_WEIGHTS := [[0, 28], [1, 7], [4, 2], [2, 1], [3, 1]]  # [variação, peso de 39]
# Ordem das paredes ao longo de um trecho: lisa, janela, lisa, rachada.
const WALL_PATTERN := ["lisa", "janela", "lisa", "quebrada"]

var floors: Array[Texture2D] = []
var pieces := {}  # nome -> Texture2D
var anchors := {}  # nome -> Vector2 (ponto da peça que fica sobre o ponto do chão)


func _init() -> void:
	for i in FLOOR_COUNT:
		floors.append(load("%schao_%d.png" % [DIR, i]))
	for file in ["parede", "movel"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s%s.json" % [DIR, file]))
		for nome in data:
			pieces["%s_%s" % [file, nome]] = load("%s%s_%s.png" % [DIR, file, nome])
			anchors["%s_%s" % [file, nome]] = Vector2(data[nome][0], data[nome][1])


func floor_texture(tx: int, ty: int) -> Texture2D:
	var roll := posmod(tx * 73856093 ^ ty * 19349663, 39)
	for entry in FLOOR_WEIGHTS:
		if roll < entry[1]:
			return floors[entry[0]]
		roll -= entry[1]
	return floors[FLOOR_PLAIN]


## Variante da parede para a peça `i` de um trecho: lisa, janela, lisa, rachada...
static func wall_variant(i: int) -> String:
	return WALL_PATTERN[i % WALL_PATTERN.size()]


## Desenha a peça com a âncora sobre `at`. `mirror` espelha na horizontal em torno da âncora.
func draw(canvas: CanvasItem, nome: String, at: Vector2, mirror := false) -> void:
	var tex: Texture2D = pieces[nome]
	var a: Vector2 = anchors[nome]
	if mirror:
		canvas.draw_set_transform(Vector2(at.x, at.y - a.y), 0.0, Vector2(-1.0, 1.0))
		canvas.draw_texture(tex, Vector2(-a.x, 0.0).round())
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture(tex, (at - a).round())


func height_of(nome: String) -> float:
	return anchors[nome].y
