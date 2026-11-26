extends SceneTree
# Gera o cenário 3D do BAR de Aurora (provisório, Claude 22/11/2026): assets/3d/missao1/bar.glb e bar.json.
# Diferente dos outros lugares, o bar não nasce de um protótipo three.js: é montado aqui com caixas e cilindros
# e exportado pelo GLTFDocument do próprio Godot, no mesmo formato que o cenario3d.gd lê. Roda uma vez:
#   godot --headless --path . -s tools/cenarios3d/missao1/gerar_bar.gd
# Medidas em metros (1 m = 64 px do plano da sala). Planta 10 x 7 m; só as duas paredes do fundo (x = 0 e z = 0)
# existem, porque a câmera olha de x e z grandes. Entrada pelo lado leste (x = 10). Balcão a oeste, mesa de
# bilhar no meio, mesa do fundo (a da Letícia) no canto nordeste, jukebox junto à parede norte.

const SAIDA := "res://assets/3d/missao1/"
const L := 10.0  # comprimento (x)
const P := 7.0  # profundidade (z)
const ALTURA := 3.1

var raiz: Node3D
var mats := {}


func _initialize() -> void:
	raiz = Node3D.new()
	raiz.name = "bar"
	_piso()
	_paredes()
	_balcao()
	_bilhar()
	_mesa_fundo()
	_mesas_soltas()
	_decoracao()
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var e := doc.append_from_scene(raiz, estado)
	if e != OK:
		push_error("append_from_scene falhou: %d" % e)
		quit(1)
		return
	e = doc.write_to_filesystem(estado, SAIDA + "bar.glb")
	if e != OK:
		push_error("write_to_filesystem falhou: %d" % e)
		quit(1)
		return
	print("ok bar.glb")
	quit(0)


func _mat(nome: String, cor: Color, brilho := 0.0) -> StandardMaterial3D:
	if mats.has(nome):
		return mats[nome]
	var m := StandardMaterial3D.new()
	m.resource_name = nome
	m.albedo_color = cor
	m.roughness = 1.0
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	mats[nome] = m
	return m


func _caixa(nome: String, mat: String, cor: Color, pos: Vector3, tam: Vector3, brilho := 0.0, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = _mat(mat, cor, brilho)
	raiz.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	return mi


func _cilindro(nome: String, mat: String, cor: Color, pos: Vector3, raio: float, alt: float, brilho := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = alt
	c.radial_segments = 14
	mi.mesh = c
	mi.material_override = _mat(mat, cor, brilho)
	raiz.add_child(mi)
	mi.position = pos
	return mi


func _piso() -> void:
	_caixa("piso", "madeira_piso", Color("#6b4a30"), Vector3(L * 0.5, -0.05, P * 0.5), Vector3(L, 0.1, P))
	# Tábuas: faixas um pouco mais escuras, para o piso não ficar chapado.
	var i := 0
	var z := 0.35
	while z < P:
		_caixa("tabua%d" % i, "madeira_piso_escura", Color("#5a3e28"), Vector3(L * 0.5, 0.002, z), Vector3(L, 0.004, 0.03))
		z += 0.7
		i += 1
	# Tapete vermelho gasto sob a mesa do fundo e capacho na entrada.
	_caixa("tapete_fundo", "tapete", Color("#6e2a24"), Vector3(8.0, 0.006, 1.6), Vector3(3.4, 0.012, 2.6))
	_caixa("capacho", "capacho", Color("#2e2620"), Vector3(9.55, 0.006, 5.3), Vector3(0.8, 0.012, 1.5))


func _paredes() -> void:
	# Parede do fundo (z = 0) e parede oeste (x = 0): reboco claro sujo em cima, lambril de madeira embaixo.
	_caixa("parede_n", "reboco", Color("#b79a78"), Vector3(L * 0.5, ALTURA * 0.5, -0.1), Vector3(L + 0.2, ALTURA, 0.2))
	_caixa("parede_o", "reboco", Color("#b79a78"), Vector3(-0.1, ALTURA * 0.5, P * 0.5), Vector3(0.2, ALTURA, P))
	_caixa("lambril_n", "lambril", Color("#4a3224"), Vector3(L * 0.5, 0.55, 0.04), Vector3(L, 1.1, 0.08))
	_caixa("lambril_o", "lambril", Color("#4a3224"), Vector3(0.04, 0.55, P * 0.5), Vector3(0.08, 1.1, P))
	_caixa("friso_n", "lambril", Color("#33221a"), Vector3(L * 0.5, 1.12, 0.05), Vector3(L, 0.05, 0.1))
	_caixa("friso_o", "lambril", Color("#33221a"), Vector3(0.05, 1.12, P * 0.5), Vector3(0.1, 0.05, P))
	_caixa("rodape_n", "lambril", Color("#2a1b13"), Vector3(L * 0.5, 0.06, 0.05), Vector3(L, 0.12, 0.1))
	# Janelas na parede do fundo: caixilho escuro e vidro com a luz da tarde (acende, não recebe luz).
	for x in [3.0, 5.4]:
		_caixa("caixilho_%.1f" % x, "caixilho", Color("#2a1b13"), Vector3(x, 1.95, 0.06), Vector3(1.5, 1.3, 0.1))
		_caixa("vidro_%.1f" % x, "vidro", Color("#ffd9a0"), Vector3(x, 1.95, 0.1), Vector3(1.32, 1.12, 0.04), 1.05)
		_caixa("trave_%.1f" % x, "caixilho", Color("#2a1b13"), Vector3(x, 1.95, 0.13), Vector3(0.05, 1.12, 0.03))
	# Vitrine da entrada (parede oeste não tem; a porta fica no lado leste, fora do quadro).
	# Porta dos fundos (parede norte, perto do canto leste), só para dar sentido ao canto da mesa.
	_caixa("porta_fundos", "porta", Color("#3a2517"), Vector3(9.4, 1.0, 0.07), Vector3(0.95, 2.0, 0.1))
	_caixa("placa_saida", "neon_verde", Color("#7cff9a"), Vector3(9.4, 2.25, 0.1), Vector3(0.4, 0.12, 0.04), 1.4)


func _balcao() -> void:
	# Balcão em L suave junto à parede oeste (z de 1.3 a 5.7), tampo claro e frente de madeira.
	_caixa("balcao_frente", "madeira_balcao", Color("#4c3020"), Vector3(1.15, 0.52, 3.5), Vector3(0.7, 1.04, 4.4))
	_caixa("balcao_tampo", "tampo", Color("#8a6a48"), Vector3(1.15, 1.07, 3.5), Vector3(0.84, 0.06, 4.54))
	_caixa("balcao_pe", "madeira_balcao", Color("#33221a"), Vector3(1.15, 0.05, 3.5), Vector3(0.78, 0.1, 4.46))
	# Prateleiras atrás do balcão, com garrafas coloridas.
	for h in [1.55, 2.1]:
		_caixa("prat_%.2f" % h, "lambril", Color("#33221a"), Vector3(0.22, h, 3.5), Vector3(0.36, 0.05, 3.9))
	var cores := [Color("#3f7a4c"), Color("#9a5a28"), Color("#d8c27a"), Color("#6a2a2a"), Color("#4a6a9a"), Color("#c8a040")]
	var k := 0
	for h in [1.55, 2.1]:
		var z := 1.8
		while z < 5.3:
			var cor: Color = cores[k % cores.size()]
			_cilindro("garrafa%d" % k, "garrafa%d" % (k % cores.size()), cor, Vector3(0.2, h + 0.17, z), 0.045, 0.3)
			z += 0.22
			k += 1
	# Espelho atrás das prateleiras, refletindo a luz quente (apenas um painel claro).
	_caixa("espelho", "espelho", Color("#9a8a72"), Vector3(0.03, 1.8, 3.5), Vector3(0.04, 1.3, 3.9))
	# Banquetas altas junto ao balcão.
	for i in 4:
		var z := 2.0 + i * 1.05
		_cilindro("banqueta%d_assento" % i, "banqueta", Color("#6e2a24"), Vector3(1.9, 0.72, z), 0.2, 0.08)
		_cilindro("banqueta%d_pe" % i, "ferro", Color("#26221e"), Vector3(1.9, 0.36, z), 0.04, 0.72)
		_cilindro("banqueta%d_base" % i, "ferro", Color("#26221e"), Vector3(1.9, 0.02, z), 0.17, 0.04)
	# Letreiro de neon sobre as prateleiras: só uma barra vermelha acesa (o letreiro desenhado vem depois).
	_caixa("neon_bar", "neon_vermelho", Color("#ff4a3a"), Vector3(0.07, 2.65, 3.5), Vector3(0.05, 0.22, 1.6), 1.9)
	_caixa("neon_bar_moldura", "ferro", Color("#26221e"), Vector3(0.05, 2.65, 3.5), Vector3(0.03, 0.34, 1.76))


func _bilhar() -> void:
	# Mesa de bilhar no centro: 2,7 x 1,4 m, feltro verde, caçapas e pés torneados.
	var c := Vector3(5.2, 0.0, 4.5)
	_caixa("bilhar_moldura", "madeira_balcao", Color("#4c3020"), c + Vector3(0, 0.82, 0), Vector3(2.9, 0.16, 1.6))
	_caixa("bilhar_feltro", "feltro", Color("#2f6a46"), c + Vector3(0, 0.915, 0), Vector3(2.55, 0.03, 1.25))
	_caixa("bilhar_saia", "madeira_balcao", Color("#33221a"), c + Vector3(0, 0.62, 0), Vector3(2.7, 0.4, 1.4))
	for sx in [-1.2, 1.2]:
		for sz in [-0.55, 0.55]:
			_caixa("bilhar_pe_%.1f_%.2f" % [sx, sz], "madeira_balcao", Color("#33221a"), c + Vector3(sx, 0.3, sz), Vector3(0.22, 0.6, 0.22))
	# Caçapas: seis quadrados escuros nos cantos e no meio das laterais maiores.
	for sx in [-1.28, 0.0, 1.28]:
		for sz in [-0.66, 0.66]:
			_caixa("cacapa_%.2f_%.2f" % [sx, sz], "cacapa", Color("#0c0907"), c + Vector3(sx, 0.935, sz), Vector3(0.16, 0.02, 0.16))
	# Bolas e giz sobre o feltro.
	var bolas := [Color("#e8e2d0"), Color("#c8402a"), Color("#e0b030"), Color("#2a5ab8"), Color("#1a1a1a"), Color("#7a2a8a"), Color("#d86a1a")]
	for i in bolas.size():
		var bx := 0.5 + (i % 3) * 0.14
		var bz := -0.14 + (i / 3) * 0.14
		var mi := MeshInstance3D.new()
		mi.name = "bola%d" % i
		var sph := SphereMesh.new()
		sph.radius = 0.035
		sph.height = 0.07
		sph.radial_segments = 8
		sph.rings = 4
		mi.mesh = sph
		mi.material_override = _mat("bola%d" % i, bolas[i])
		raiz.add_child(mi)
		mi.position = c + Vector3(bx, 0.97, bz)
	# Luminária de bilhar pendurada: cúpula verde-escura com luz acesa por baixo.
	_cilindro("fio_bilhar", "ferro", Color("#26221e"), c + Vector3(0, 2.45, 0), 0.01, 1.3)
	_caixa("cupula_bilhar", "cupula", Color("#1e3a2a"), c + Vector3(0, 1.82, 0), Vector3(1.9, 0.22, 0.55))
	_caixa("lampada_bilhar", "lampada", Color("#ffe2a8"), c + Vector3(0, 1.68, 0), Vector3(1.7, 0.04, 0.4), 2.0)
	# Tacos no suporte da parede... (na parede oeste não cabe: ficam encostados no canto sudoeste da mesa)
	_caixa("taco1", "madeira_taco", Color("#b08850"), Vector3(3.55, 0.7, 3.4), Vector3(0.04, 1.45, 0.04), 0.0)
	_caixa("taco2", "madeira_taco", Color("#b08850"), Vector3(3.62, 0.7, 3.46), Vector3(0.04, 1.45, 0.04), 0.0)


func _mesa_fundo() -> void:
	# O reservado da Letícia: banco corrido na parede do fundo (x de 6,5 a 9,5), mesa de 1,5 x 0,9 e duas cadeiras
	# do lado de fora; tapete vermelho por baixo. O grupo senta ao redor.
	_caixa("banco_assento", "estofado", Color("#6e2a24"), Vector3(8.0, 0.42, 0.38), Vector3(3.0, 0.12, 0.6))
	_caixa("banco_encosto", "estofado", Color("#5a2420"), Vector3(8.0, 0.8, 0.1), Vector3(3.0, 0.6, 0.1))
	_caixa("banco_base", "madeira_balcao", Color("#33221a"), Vector3(8.0, 0.18, 0.38), Vector3(2.9, 0.36, 0.5))
	_caixa("mesa_tampo", "tampo", Color("#8a6a48"), Vector3(8.0, 0.76, 1.55), Vector3(1.6, 0.06, 0.95))
	_caixa("mesa_pe1", "madeira_balcao", Color("#33221a"), Vector3(7.3, 0.37, 1.55), Vector3(0.1, 0.74, 0.1))
	_caixa("mesa_pe2", "madeira_balcao", Color("#33221a"), Vector3(8.7, 0.37, 1.55), Vector3(0.1, 0.74, 0.1))
	# Copos, uma garrafa e um cinzeiro na mesa.
	_cilindro("copo1", "vidro_copo", Color("#c8b890"), Vector3(7.6, 0.85, 1.5), 0.04, 0.12)
	_cilindro("copo2", "vidro_copo", Color("#c8b890"), Vector3(8.25, 0.85, 1.7), 0.04, 0.12)
	_cilindro("cinzeiro", "ferro", Color("#26221e"), Vector3(8.0, 0.8, 1.45), 0.06, 0.03)
	# Duas cadeiras de madeira do lado de fora da mesa (z = 2,5).
	for x in [7.4, 8.6]:
		_caixa("cadeira_%.1f_assento" % x, "madeira_taco", Color("#7a5232"), Vector3(x, 0.45, 2.45), Vector3(0.45, 0.06, 0.45))
		_caixa("cadeira_%.1f_encosto" % x, "madeira_taco", Color("#7a5232"), Vector3(x, 0.8, 2.66), Vector3(0.45, 0.6, 0.05))
		for dx in [-0.19, 0.19]:
			for dz in [-0.19, 0.19]:
				_caixa("cadeira_%.1f_pe_%.2f_%.2f" % [x, dx, dz], "madeira_taco", Color("#5a3e28"), Vector3(x + dx, 0.21, 2.45 + dz), Vector3(0.05, 0.42, 0.05))
	# Luminária baixa sobre a mesa (a luz que escolhe o canto).
	_cilindro("fio_mesa", "ferro", Color("#26221e"), Vector3(8.0, 2.55, 1.55), 0.01, 1.1)
	_cilindro("cupula_mesa", "cupula", Color("#6e3a1e"), Vector3(8.0, 1.96, 1.55), 0.3, 0.16)
	_cilindro("lampada_mesa", "lampada", Color("#ffe2a8"), Vector3(8.0, 1.86, 1.55), 0.22, 0.03, 2.0)


func _mesas_soltas() -> void:
	# Duas mesas redondas vazias com banquetas, para o bar parecer um bar pouco movimentado.
	for pos in [Vector2(3.3, 5.8), Vector2(8.3, 5.8)]:
		_cilindro("mesa_redonda_tampo_%.1f" % pos.x, "tampo", Color("#8a6a48"), Vector3(pos.x, 0.75, pos.y), 0.45, 0.06)
		_cilindro("mesa_redonda_pe_%.1f" % pos.x, "ferro", Color("#26221e"), Vector3(pos.x, 0.37, pos.y), 0.05, 0.74)
		_cilindro("mesa_redonda_base_%.1f" % pos.x, "ferro", Color("#26221e"), Vector3(pos.x, 0.02, pos.y), 0.28, 0.04)
		for d in [Vector2(-0.7, 0), Vector2(0.7, 0)]:
			_cilindro("banq_%.1f_%.1f" % [pos.x + d.x, pos.y], "banqueta", Color("#6e2a24"), Vector3(pos.x + d.x, 0.45, pos.y + d.y), 0.18, 0.07)
			_cilindro("banq_pe_%.1f_%.1f" % [pos.x + d.x, pos.y], "ferro", Color("#26221e"), Vector3(pos.x + d.x, 0.22, pos.y + d.y), 0.03, 0.44)


func _decoracao() -> void:
	# Jukebox junto à parede norte (x = 1,8): corpo escuro, tampa curva feita de caixas, luzes acesas.
	_caixa("jukebox_corpo", "jukebox", Color("#5a2a1e"), Vector3(1.9, 0.8, 0.4), Vector3(0.95, 1.6, 0.6))
	_caixa("jukebox_topo", "jukebox", Color("#6e3224"), Vector3(1.9, 1.7, 0.4), Vector3(0.8, 0.2, 0.55))
	_caixa("jukebox_vidro", "neon_amarelo", Color("#ffcf6a"), Vector3(1.9, 1.2, 0.72), Vector3(0.62, 0.7, 0.04), 1.5)
	_caixa("jukebox_faixa", "neon_vermelho", Color("#ff4a3a"), Vector3(1.9, 1.7, 0.72), Vector3(0.5, 0.06, 0.04), 1.8)
	# Quadros na parede do fundo: pôster desbotado e um quadro de troféu (o "torneio").
	_caixa("quadro_trofeu", "quadro", Color("#2a1b13"), Vector3(7.0, 1.95, 0.06), Vector3(0.9, 0.7, 0.06))
	_caixa("quadro_trofeu_foto", "quadro_foto", Color("#b8a888"), Vector3(7.0, 1.95, 0.1), Vector3(0.76, 0.56, 0.02))
	_caixa("poster", "quadro_foto", Color("#8a3a2a"), Vector3(8.7, 2.05, 0.06), Vector3(0.6, 0.9, 0.04))
	# Barril e caixa de garrafas encostados na parede oeste, ao norte do balcão.
	_cilindro("barril", "madeira_balcao", Color("#6a4528"), Vector3(0.55, 0.45, 0.85), 0.32, 0.9)
	_caixa("caixote", "madeira_taco", Color("#7a5232"), Vector3(0.5, 0.25, 6.45), Vector3(0.7, 0.5, 0.6))
	# Viga e ventilador de teto não entram: a câmera corta o teto.
