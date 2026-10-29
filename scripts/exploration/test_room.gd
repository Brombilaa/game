extends Node2D
# Sala de teste da exploração: clique para mover e uma porta.
# Sem pathfinding ainda: a rota é reta e cliques com rota que cruza obstáculo são recusados.

const SPEED := 180.0
const PLAYER_RADIUS := 10.0
const STAND_OFFSET := 6.0

var walls: Array[Rect2] = [
	Rect2(0, 0, 1280, 16),
	Rect2(0, 704, 1280, 16),
	Rect2(0, 0, 16, 720),
	Rect2(1264, 0, 16, 720),
	Rect2(600, 0, 24, 300),
	Rect2(600, 420, 24, 300),
	Rect2(400, 200, 120, 40),
]
var door := Rect2(600, 300, 24, 120)

var player_pos := Vector2(160, 360)
var target := Vector2(160, 360)
var pending_door := false
var door_open := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_order_move(get_global_mouse_position())


func _order_move(click: Vector2) -> void:
	pending_door = false
	if not door_open and door.grow(12).has_point(click):
		# Clique na porta: andar até o lado em que o personagem está e abrir ao chegar.
		var stand_x := door.position.x - PLAYER_RADIUS - STAND_OFFSET if player_pos.x < door.get_center().x else door.end.x + PLAYER_RADIUS + STAND_OFFSET
		click = Vector2(stand_x, door.get_center().y)
		pending_door = true
	elif _is_blocked(click):
		return  # destino inacessível
	if _segment_blocked(player_pos, click):
		return  # rota reta cruza obstáculo; pathfinding ainda não implementado
	target = click


func _is_blocked(p: Vector2) -> bool:
	for w in walls:
		if w.has_point(p):
			return true
	return not door_open and door.has_point(p)


func _segment_blocked(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 4.0) + 1
	for i in range(1, steps + 1):
		if _is_blocked(a.lerp(b, float(i) / steps)):
			return true
	return false


func _process(delta: float) -> void:
	if player_pos.distance_to(target) > 1.0:
		player_pos = player_pos.move_toward(target, SPEED * delta)
		queue_redraw()
	elif pending_door:
		pending_door = false
		door_open = true
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.12, 0.14))
	for w in walls:
		draw_rect(w, Color(0.35, 0.35, 0.4))
	if door_open:
		draw_rect(door, Color(0.4, 0.6, 0.4, 0.5))
	else:
		draw_rect(door, Color(0.55, 0.35, 0.2))
	draw_circle(player_pos, PLAYER_RADIUS, Color(0.3, 0.6, 1.0))
