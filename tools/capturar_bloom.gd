extends SceneTree
# Capturas do bloom: um lugar da missão 1 com cada preset do filtro pc_antigo.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_bloom.gd -- pasta id olhar=x,y [zoom=1.5] [marca ...]
const PRESETS := {
	"antes": {"bloom_forca": 0.0},
	"A": {"bloom_forca": 0.6, "bloom_limiar": 0.40, "bloom_joelho": 0.20, "bloom_raio": 0.6, "bloom_tom": Vector3(1.0, 0.96, 0.9), "bloom_veu": 0.0},
	"B": {"bloom_forca": 1.1, "bloom_limiar": 0.45, "bloom_joelho": 0.15, "bloom_raio": 0.9, "bloom_tom": Vector3(1.0, 0.62, 0.30), "bloom_veu": 0.0},
	"C": {"bloom_forca": 0.55, "bloom_limiar": 0.22, "bloom_joelho": 0.18, "bloom_raio": 1.5, "bloom_tom": Vector3(0.92, 0.95, 1.0), "bloom_veu": 0.15},
}
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var pasta := a[0]
	Missao1.reiniciar()
	Missao1.local = a[1]
	var zoom := 0.0
	var olhar := Vector2.INF
	for i in range(2, a.size()):
		if a[i].begins_with("zoom="):
			zoom = float(a[i].trim_prefix("zoom="))
		elif a[i].begins_with("olhar="):
			var v := a[i].trim_prefix("olhar=").split(",")
			olhar = Vector2(float(v[0]), float(v[1]))
		else:
			Missao1.marcar(a[i])
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	for i in 6:
		await process_frame
	if zoom > 0.0:
		room.camera.zoom = Vector2(zoom, zoom)
	if olhar != Vector2.INF:
		room.player.pos = olhar
	for i in 40:
		await process_frame
	var mats: Array = []
	for n in room.find_children("*", "ColorRect", true, false):
		var m = (n as ColorRect).material
		if m is ShaderMaterial and (m as ShaderMaterial).shader.resource_path.ends_with("pc_antigo.gdshader"):
			mats.append(m)
	print("filtros: ", mats.size())
	for nome in PRESETS:
		for m in mats:
			for k in PRESETS[nome]:
				m.set_shader_parameter(k, PRESETS[nome][k])
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [pasta, a[1], nome])
	quit()
