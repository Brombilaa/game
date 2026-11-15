extends SceneTree
# Captura do parque com a área clicável de cada pista pintada: antes (bolinha + elipses) e depois (contorno da malha + folga).
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_pistas.gd -- pasta pista [zoom=1.0]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var pasta := a[0]
	var cid := a[1]
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 8:
		await process_frame
	var c: Dictionary = room.scenario.clues[cid]
	room.player.pos = c.pos + Vector2(40, 110)
	room.camera.position = room._iso(c.pos)
	room.camera.zoom = Vector2(float(a[2]) if a.size() > 2 else 2.0, float(a[2]) if a.size() > 2 else 2.0)
	room.hover_forcado = cid
	for i in 40:
		await process_frame
	var img := root.get_texture().get_image()
	var k: Vector2 = Vector2(img.get_size()) / room.get_viewport_rect().size
	var antes := img.duplicate() as Image
	var depois := img.duplicate() as Image
	var passo := 3
	for y in range(0, int(room.get_viewport_rect().size.y), passo):
		for x in range(0, int(room.get_viewport_rect().size.x), passo):
			var m: Vector2 = room.get_canvas_transform().affine_inverse() * Vector2(x, y)
			var dep: bool = room._clue_under(m) == cid
			var ant: bool = m.distance_to(room._dot_pos(cid)) <= room.DOT_HIT
			if not ant:
				for ar in c.areas:
					var rel: Vector2 = m - (room._iso(c.pos) + Vector2(float(ar[0]), float(ar[1])))
					if (rel.x * rel.x) / (float(ar[2]) * float(ar[2])) + (rel.y * rel.y) / (float(ar[3]) * float(ar[3])) <= 1.0:
						ant = true
			_pintar(antes, Vector2i(Vector2(x, y) * k), int(passo * k.x), ant)
			_pintar(depois, Vector2i(Vector2(x, y) * k), int(passo * k.x), dep)
	antes.save_png("%s/%s_antes.png" % [pasta, cid])
	depois.save_png("%s/%s_depois.png" % [pasta, cid])
	print("ok ", cid)
	quit()


func _pintar(img: Image, p: Vector2i, n: int, ativo: bool) -> void:
	if not ativo:
		return
	for j in n:
		for i in n:
			var q := p + Vector2i(i, j)
			if q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, img.get_pixelv(q).lerp(Color(0.2, 0.8, 1.0), 0.45))
