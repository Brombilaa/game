class_name AnimSheet
extends RefCounted
# Animações do Nikolai em 3D renderizado como pixel art (Hunyuan3D + Mixamo, render do Claude).
# Uma folha por animação e direção: `nikolai3d_<animação>_<s|se|e|ne|n>.png`, quadros de 384×384
# em fila (alta definição, o dobro dos pixels de antes, desenhados a 50% para o personagem ter o mesmo tamanho na tela). SO, O e NO espelham SE, E e NE, como em CharacterSheet. Os pés ficam no mesmo ponto.

const FRAME := 384  # lado do quadro na folha, em pixels
const SCALE := 0.5  # tamanho na tela: a folha tem o dobro dos pixels do 2D
const PIVOT := Vector2(192, 358)  # pés no quadro da folha (o mesmo ponto do 2D, a 2x)
const ROOT := "res://assets/sprites/personagens/nikolai3d/nikolai3d_%s_%s.png"
# Animação -> quadros por segundo. A ordem é a do ciclo da tecla N na sala de teste.
const FPS := {
	"idle": 4.0, "walk": 10.0, "pistol_idle": 6.0, "pistol_walk": 10.0, "crouch_walk": 8.0,
	"rifle_walk": 10.0, "run": 14.0, "pickup_object": 10.0, "pickup": 5.0, "opening": 5.0,
	"pistol_aim_prov": 6.0,
	"pistol_shoot": 8.0, "rifle_fire": 12.0, "punch": 10.0, "kick": 10.0, "hit": 8.0, "death": 8.0, "getup": 5.0,
}
# Animações com o corpo mais largo ou baixo que o quadro padrão (deitado, lance do soco) usam quadro maior;
# os pés ficam em x = metade da largura e na mesma linha PIVOT.y.
const BIG := Vector2i(576, 512)
const FRAME_OF := {"punch": BIG, "kick": BIG, "death": Vector2i(704, 512), "getup": BIG}  # morte: o corpo deitado é mais comprido
const NAMES := ["idle", "walk", "pistol_idle", "pistol_walk", "crouch_walk", "rifle_walk", "run", "pickup_object", "pickup", "opening", "pistol_aim_prov",
	"pistol_shoot", "rifle_fire", "punch", "kick", "hit", "death", "getup"]

var textures := {}  # animação -> {"se": Texture2D, ...}


func _init() -> void:
	for anim in NAMES:
		var per_dir := {}
		for d in ["se", "e", "ne", "s", "n"]:
			per_dir[d] = load(ROOT % [anim, d])
		textures[anim] = per_dir


# Tamanho do quadro da animação na folha, em pixels.
static func frame_size(anim: String) -> Vector2i:
	return FRAME_OF.get(anim, Vector2i(FRAME, FRAME))


func frame_count(anim: String) -> int:
	return int(textures[anim]["e"].get_width() / frame_size(anim).x)


# Desenha o quadro `frame` da animação virado para `dir`, com os pés em `pos`.
func draw(canvas: CanvasItem, pos: Vector2, anim: String, frame: int, dir: CharacterSheet.Dir) -> void:
	var info: Array = CharacterSheet.SHEET_OF[dir]
	var tex: Texture2D = textures[anim][info[0]]
	var fs := Vector2(frame_size(anim))
	var size := fs * SCALE
	var src := Rect2(frame * fs.x, 0, fs.x, fs.y)
	var pivot := Vector2(fs.x * 0.5, PIVOT.y) * SCALE
	var origin := (pos - pivot).round()
	if info[1]:
		canvas.draw_set_transform(Vector2(origin.x + pivot.x, origin.y), 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(tex, Rect2(Vector2(-pivot.x, 0), size), src)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(tex, Rect2(origin, size), src)
