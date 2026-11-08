class_name AnimSheet
extends RefCounted
# Animações do Nikolai em 3D renderizado como pixel art (Hunyuan3D + Mixamo, render do Claude).
# Uma folha por animação e direção: `nikolai3d_<animação>_<s|se|e|ne|n>.png`, quadros de 384×384
# em fila (alta definição, o dobro dos pixels de antes, desenhados a 50% para o personagem ter o mesmo tamanho na tela). SO, O e NO espelham SE, E e NE, como em CharacterSheet. Os pés ficam no mesmo ponto.

const FRAME := 384  # lado do quadro na folha, em pixels
const SCALE := 0.5  # tamanho na tela: a folha tem o dobro dos pixels do 2D
const PIVOT := Vector2(192, 358)  # pés no quadro da folha (o mesmo ponto do 2D, a 2x)
const ROOT := "res://assets/sprites/personagens/%s/%s_%s_%s.png"  # pasta, prefixo, animação, direção
# Animação -> quadros por segundo. A ordem é a do ciclo da tecla N na sala de teste.
# PROVISÓRIO (Léo, 06/11/2026: estavam rápidas demais; ~70% dos valores antigos). Andar do jogo vai por distância (NIKOLAI_WALK_CYCLE_PIXELS)
# e ataques por NIKOLAI_ATTACK_SECONDS; estes valores valem para parada, morte, levantar, dano e para o ciclo de teste (tecla N).
# 07/11/2026 (Léo: "não estão fluidas"): as folhas passaram a ter o dobro de quadros (morte 20 em vez de 12), então os valores
# dobraram para manter a mesma duração. A recarga continua com 12 quadros.
const FPS := {
	"idle": 6.0, "walk": 16.0, "pistol_idle": 9.0, "pistol_walk": 16.0, "crouch_walk": 12.0,
	"rifle_walk": 16.0, "run": 22.0, "pickup_object": 16.0, "pickup": 8.0, "opening": 8.0,
	"pistol_aim_prov": 10.0, "crouch_idle": 6.0, "reload": 6.0,
	"pistol_shoot": 12.0, "rifle_fire": 18.0, "punch": 16.0, "kick": 16.0, "hit": 12.0, "death": 10.0, "getup": 8.0,
}
# Animações com o corpo mais largo ou baixo que o quadro padrão (deitado, lance do soco) usam quadro maior;
# os pés ficam em x = metade da largura e na mesma linha PIVOT.y.
const BIG := Vector2i(576, 512)
const FRAME_OF := {"punch": BIG, "kick": BIG, "death": Vector2i(704, 512), "getup": BIG}  # morte: o corpo deitado é mais comprido
const NAMES := ["idle", "walk", "pistol_idle", "pistol_walk", "crouch_walk", "rifle_walk", "run", "pickup_object", "pickup", "opening", "pistol_aim_prov",
	"crouch_idle", "reload", "pistol_shoot", "rifle_fire", "punch", "kick", "hit", "death", "getup"]

var textures := {}  # animação -> {"se": Texture2D, ...}; carregadas na primeira vez que a animação aparece
var folder := ""
var prefix := ""


# O Fernando usa as mesmas animações do Nikolai (mesmo esqueleto do Mixamo): `AnimSheet.new("fernando3d", "fernando3d")`.
# As folhas são carregadas sob demanda: as 20 animações de um personagem em memória de vídeo passariam de 1 GB.
func _init(p_folder := "nikolai3d", p_prefix := "nikolai3d") -> void:
	folder = p_folder
	prefix = p_prefix


# Folha da animação numa direção ("se", "e", "ne", "s", "n").
func texture(anim: String, d: String) -> Texture2D:
	if not textures.has(anim):
		var per_dir := {}
		for dd in ["se", "e", "ne", "s", "n"]:
			per_dir[dd] = load(ROOT % [folder, prefix, anim, dd])
		textures[anim] = per_dir
	return textures[anim][d]


# Tamanho do quadro da animação na folha, em pixels.
static func frame_size(anim: String) -> Vector2i:
	return FRAME_OF.get(anim, Vector2i(FRAME, FRAME))


func frame_count(anim: String) -> int:
	return int(texture(anim, "e").get_width() / frame_size(anim).x)


# Desenha o quadro `frame` da animação virado para `dir`, com os pés em `pos`.
func draw(canvas: CanvasItem, pos: Vector2, anim: String, frame: int, dir: CharacterSheet.Dir) -> void:
	var info: Array = CharacterSheet.SHEET_OF[dir]
	var tex: Texture2D = texture(anim, info[0])
	var fs := Vector2(frame_size(anim))
	var size := fs * SCALE
	var src := Rect2(frame * fs.x, 0, fs.x, fs.y)
	var pivot := Vector2(fs.x * 0.5, PIVOT.y) * SCALE
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
