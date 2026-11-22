class_name RoomObjectivesHud
extends RefCounted
# Objetivos do HUD: texto solto no canto de cima da direita, sem placa, com uma sombra bem leve e
# alinhado à direita com o aro do minimapa (Léo, 09/11/2026). Só desenha; o conteúdo vem de
# `Objectives.build` e a sala fornece a lista em `_objectives()`. Pixels da tela (960×540).

const RIGHT := 950.0  # borda direita do texto (a mesma do aro do minimapa)
const TOP := 112.0
const WIDTH := 210.0  # Léo, 15/11: a parte de tarefas um pouco maior (era 170 de largura, linha de 14 e fonte 8)
const ROW_H := 17.0
const FONT := 10
const FONT_TITULO := 7
const INK := Color(0.96, 0.94, 0.9)
const DIM := Color(0.58, 0.57, 0.55)
const ENEMY := Color(0.86, 0.26, 0.29)

var room: TestRoom


func _init(owner_room: TestRoom) -> void:
	room = owner_room


func _draw_objectives(font: Font, to_world: Transform2D, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	var hud := room.party_hud
	var pos := to_world * Vector2(RIGHT - WIDTH, TOP)
	var combat := room.mode == room.Mode.COMBAT
	hud._draw_soft_text(font, pos + Vector2(0, 6), "OBJETIVOS", HORIZONTAL_ALIGNMENT_RIGHT, WIDTH, FONT_TITULO, DIM)
	for i in 8:  # fio que some para a esquerda
		var x0 := pos.x + WIDTH - 75.0 + i * 9.0
		room.draw_line(Vector2(x0, pos.y + 10), Vector2(x0 + 9.0, pos.y + 10), Color(1, 1, 1, 0.05 + 0.2 * i / 7.0), 0.5)
	for k in items.size():
		var it: Dictionary = items[k]
		var y := pos.y + 16 + k * ROW_H
		var done: bool = it["feito"]
		var current: bool = it["atual"]
		var color: Color = DIM if done or it["texto"] == Objectives.LOCKED_TEXT else INK
		var text: String = it["texto"]
		if it["detalhe"] != "":
			text += "  " + str(it["detalhe"])
		var mark := Vector2(pos.x + WIDTH - 3.5, y + 6.5)
		if current:  # bolinha cheia; vermelha no combate
			var dot := ENEMY if combat else Color.WHITE
			room.draw_circle(mark, 4.0, Color(dot, 0.25))
			room.draw_circle(mark, 2.5, dot)
		elif done:
			room.draw_circle(mark, 2.0, DIM)
		else:
			room.draw_arc(mark, 2.5, 0.0, TAU, 12, DIM, 0.75)
		var tam := _tamanho_que_cabe(font, text)
		hud._draw_soft_text(font, Vector2(pos.x, y + 10), text, HORIZONTAL_ALIGNMENT_RIGHT, WIDTH - 13.0, tam, color)
		if done:  # risco sobre o texto concluído
			var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x, WIDTH - 13.0)
			room.draw_line(Vector2(pos.x + WIDTH - 13.0 - w, y + 6.5), Vector2(pos.x + WIDTH - 13.0, y + 6.5), DIM, 0.5)
	_draw_selo_luz(font, pos + Vector2(0, 16 + items.size() * ROW_H + 4.0))


# Texto longo não é cortado ("escritório do Ghu"): a fonte diminui até caber na largura, no mínimo FONT_MIN.
const FONT_MIN := 7


func _tamanho_que_cabe(font: Font, text: String) -> int:
	var tam := FONT
	while tam > FONT_MIN and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > WIDTH - 13.0:
		tam -= 1
	return tam


# Selo da luz e furtividade (modelo A, Léo 15/11/2026): à noite, na exploração, diz se o líder está
# ESCONDIDO, na PENUMBRA ou VISÍVEL, com o mesmo olho dos cartões.
func _draw_selo_luz(font: Font, at: Vector2) -> void:
	var lider: Combatant = room.player
	if lider == null or lider.iluminacao < 0.0 or room.mode != room.Mode.EXPLORATION:
		return
	var e := LuzFurtividade.estado_de(lider.iluminacao)
	var texto: String = LuzFurtividade.TEXTO[e]
	var w := font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT + 2).x
	var caixa := Rect2(Vector2(at.x + WIDTH - w - 30.0, at.y), Vector2(w + 30.0, 17.0))
	room.draw_rect(caixa, Color(0.04, 0.03, 0.03, 0.78))
	LuzFurtividade.desenhar_olho(room, caixa.position + Vector2(11.0, 8.5), 6.0, e)
	room.draw_string(font, caixa.position + Vector2(22.0, 13.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT + 2, LuzFurtividade.cor_de(e))
