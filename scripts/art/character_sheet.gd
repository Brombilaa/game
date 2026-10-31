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
# Animações extras que uma folha pode ter e a duração de cada quadro, em segundos.
const ANIMS := {
	"pistol_shoot": 0.09, "rifle_fire": 0.09, "punch_cross": 0.07, "kick": 0.07,
	"hit": 0.1, "death": 0.12, "getup": 0.12,
}
# Ponto do quadro que fica sobre a posição da unidade: meio dos pés.
const PIVOT := Vector2(96, 179)
# Altura do personagem acima do pivô, para posicionar barras de vida.
const HEIGHT := 134.0
# Recorte do rosto e ombros no quadro parado da folha S, para retratos do HUD.
const PORTRAIT := Rect2(66, 48, 60, 60)

var textures := {}  # "se" -> Texture2D
# Animações extras (assets/sprites/personagens/<prefixo>_anim_<nome>_<se|e|ne|s|n>.png, uma fila de quadros de 192×192).
# Só existem para quem foi renderizado em 3D (Nikolai); "pistol_shoot" -> {"se": Texture2D, ...}.
var anims := {}
var portrait: Texture2D  # retrato próprio (assets/sprites/retratos); sem ele, recorta o rosto da folha S


func _init(prefix: String) -> void:
	for name in ["se", "e", "ne", "s", "n"]:
		textures[name] = load("%s_%s.png" % [prefix, name])
	for anim in ANIMS:
		var first := "%s_anim_%s_se.png" % [prefix, anim]
		if not ResourceLoader.exists(first):
			continue
		var by_dir := {}
		for name in ["se", "e", "ne", "s", "n"]:
			by_dir[name] = load("%s_anim_%s_%s.png" % [prefix, anim, name])
		anims[anim] = by_dir
	var own := "res://assets/sprites/retratos/%s_64.png" % prefix.get_file()
	if ResourceLoader.exists(own):
		portrait = load(own)


func has_anim(anim: String) -> bool:
	return anims.has(anim)


func anim_frame_count(anim: String) -> int:
	return int(anims[anim]["e"].get_width() / FRAME) if anims.has(anim) else 0


func anim_seconds(anim: String) -> float:
	return anim_frame_count(anim) * float(ANIMS.get(anim, 0.1))


# Quadro de `anim` a `t` segundos do início; parado no último quadro depois do fim.
func anim_frame_at(anim: String, t: float) -> int:
	return clampi(int(t / float(ANIMS.get(anim, 0.1))), 0, maxi(anim_frame_count(anim) - 1, 0))


func frame_count() -> int:
	return int(textures["e"].get_width() / FRAME)


# Direção da tela (y para baixo) mais próxima de um vetor de movimento: setores de 45°.
static func dir_from_vector(v: Vector2) -> Dir:
	return int(posmod(roundi(v.angle() / (PI / 4.0)), 8)) as Dir


# Desenha o quadro `frame` virado para `dir`, com os pés em `pos`.
func draw(canvas: CanvasItem, pos: Vector2, frame: int, dir: Dir, anim := "") -> void:
	var info: Array = SHEET_OF[dir]
	var tex: Texture2D = anims[anim][info[0]] if anim != "" and anims.has(anim) else textures[info[0]]
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
func draw_portrait(canvas: CanvasItem, rect: Rect2) -> void:
	if portrait:
		canvas.draw_texture_rect(portrait, rect, false)
		return
	canvas.draw_texture_rect_region(textures["s"], rect, PORTRAIT)
