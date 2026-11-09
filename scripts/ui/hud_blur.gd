class_name HudBlur
extends Node2D
# Fundo de vidro fosco das placas do HUD (ordem dos turnos e barra de ações). Fica atrás do desenho da
# sala (show_behind_parent), por isso o shader desfoca só o mundo, e o HUD é desenhado por cima.
# As placas vêm de `room._hud_blur_rects()` (pixels da tela, 960×540).

const SHADER := preload("res://assets/shaders/hud_fosco.gdshader")

var room: TestRoom
var white: ImageTexture
var was_on := false


func _init(owner_room: TestRoom) -> void:
	room = owner_room
	show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	var on := not room._hud_blur_rects().is_empty()
	if on or was_on:  # a câmera anda: redesenha a cada quadro enquanto houver placa
		queue_redraw()
	was_on = on


func _draw() -> void:
	var rects := room._hud_blur_rects()
	if rects.is_empty():
		return
	var to_world := room._hud_to_world()
	draw_set_transform(Vector2.ZERO, 0.0, room._hud_draw_scale())
	for r in rects:
		draw_texture_rect(white, Rect2(to_world * r.position, r.size), false)
