extends SceneTree
# Captura de um cenário 3D da missão 1, na vista de uma tomada do protótipo.
# xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_cenario3d.gd -- saida.png id ax ay az vista [estado=0|1 ...]
# Ajustes por variável de ambiente: K_SOL, K_AMB, K_PONTO, QUEDA, K_BRILHO, K_EMI, AO, SEMFX.
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var cena: Node3D = load("res://scripts/exploration/cenario3d.gd").new()
	cena.id = a[1]
	cena.alvo = Vector3(float(a[2]), float(a[3]), float(a[4]))
	cena.vista = float(a[5])
	for par in [["K_SOL", "k_sol"], ["K_AMB", "k_ambiente"], ["NEVOA", "nevoa_forca"], ["ALB", "albedo_ref"], ["K_CEU", "k_ceu"], ["K_PONTO", "k_ponto"], ["QUEDA", "queda_ponto"], ["K_BRILHO", "k_brilho"], ["K_EMI", "k_emissao"], ["AO", "forca_oclusao"], ["EXPO", "expoente_sobreposto"]]:
		if OS.get_environment(par[0]) != "":
			cena.set(par[1], float(OS.get_environment(par[0])))
	root.add_child(cena)
	for i in 4:
		await process_frame
	for i in range(6, a.size()):
		var kv := a[i].split("=")
		cena.estado(kv[0], kv[1] == "1")
	if OS.get_environment("SEMFX") != "":
		for c in cena.get_children():
			if c is CanvasLayer and c.layer == 100:
				c.visible = false
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(a[0])
	print("ok ", a[0])
	quit()
