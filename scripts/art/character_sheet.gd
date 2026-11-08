class_name CharacterSheet
extends RefCounted
# Folha de poses de um personagem feita a partir de uma imagem do ChatGPT (tools/sprites/converter.py).
# Cinco folhas (`<prefixo>_se|e|ne|s|n.png`), cada uma com uma fila de 8 quadros de 192×192:
# 0 e 1 parado, 2 a 7 andando. As 8 direções da tela saem delas: SO, O e NO são o espelho de SE, E e NE.

enum Dir { E, SE, S, SW, W, NW, N, NE }
# Folha de cada direção e se ela é espelhada.
const SHEET_OF := {
	Dir.E: ["e", false], Dir.SE: ["se", false], Dir.S: ["s", false], Dir.SW: ["se", true],
	Dir.W: ["e", true], Dir.NW: ["ne", true], Dir.N: ["n", false], Dir.NE: ["ne", false],
}

const FRAME := 192
const IDLE_FRAMES := [0, 1]
const WALK_FRAMES := [2, 3, 4, 5, 6, 7]
# Ponto do quadro que fica sobre a posição da unidade: meio dos pés.
const PIVOT := Vector2(96, 179)
# Altura do personagem acima do pivô, para posicionar barras de vida.
const HEIGHT := 134.0
# Recorte do rosto e ombros no quadro parado da folha S, para retratos do HUD.
const PORTRAIT := Rect2(66, 48, 60, 60)

var textures := {}  # "se" -> Texture2D
var portrait: Texture2D  # retrato próprio (assets/sprites/retratos); sem ele, recorta o rosto da folha S
var portrait_hurt: Texture2D  # retrato "bem ferido" (PV baixo); sem ele, usa o normal

# Fração de PV em que o retrato passa para a versão ferida (provisório até o Léo testar).
const HURT_BELOW := 0.34


func _init(prefix: String) -> void:
	for name in ["se", "e", "ne", "s", "n"]:
		textures[name] = load("%s_%s.png" % [prefix, name])
	var own := "res://assets/sprites/retratos/%s_64.png" % prefix.get_file()
	if ResourceLoader.exists(own):
		portrait = load(own)
	var hurt := "res://assets/sprites/retratos/%s_ferido_64.png" % prefix.get_file()
	if ResourceLoader.exists(hurt):
		portrait_hurt = load(hurt)


func frame_count() -> int:
	return int(textures["e"].get_width() / FRAME)


# Direção da tela (y para baixo) mais próxima de um vetor de movimento: setores de 45°.
static func dir_from_vector(v: Vector2) -> Dir:
	return int(posmod(roundi(v.angle() / (PI / 4.0)), 8)) as Dir


# Desenha o quadro `frame` virado para `dir`, com os pés em `pos`.
func draw(canvas: CanvasItem, pos: Vector2, frame: int, dir: Dir) -> void:
	var info: Array = SHEET_OF[dir]
	var tex: Texture2D = textures[info[0]]
	var src := Rect2(frame * FRAME, 0, FRAME, FRAME)
	var origin := (pos - PIVOT).round()
	if info[1]:
		# Espelha em torno do pivô: o pé fica no mesmo lugar.
		canvas.draw_set_transform(Vector2(origin.x + PIVOT.x, origin.y), 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(tex, Rect2(Vector2(-PIVOT.x, 0), Vector2(FRAME, FRAME)), src)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(origin, Vector2(FRAME, FRAME)), src)


# Retrato desenhado dentro de `rect`: o retrato próprio, ou o rosto do quadro parado de frente.
func draw_portrait(canvas: CanvasItem, rect: Rect2, hurt := false) -> void:
	if portrait:
		canvas.draw_texture_rect(portrait_hurt if hurt and portrait_hurt else portrait, rect, false)
		return
	canvas.draw_texture_rect_region(textures["s"], rect, PORTRAIT)
