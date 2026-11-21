class_name DamaVisual
extends RefCounted
# Visual da luta da Dama de Sangue (ChefeDama): as 7 flores na coroa dela, os seis pendurados com o tentáculo que os
# segura, a Prisão de Tentáculos, as áreas das habilidades e o aviso na tela. Três modelos para o Léo escolher
# (regra "sempre 3 modelos"); `estilo` muda tudo junto. Formas, cores e tempos provisórios do Claude.
#   A · Orquídeas e casulos: flor de pétalas abertas na ponta de uma vinha; pendurado num casulo de vinha que sai do
#       chão em arco; aviso em faixa vermelha atravessando a tela.
#   B · Bocas e correntes: flor fechada em boca com espinhos; pendurado de cabeça para baixo numa corrente do teto,
#       com o tentáculo enrolado; aviso no terço de cima com clarão nas bordas e tremor.
#   C · Lanternas e raízes: flor como bulbo aceso na ponta de um talo; corpo deitado preso ao chão por raízes;
#       aviso discreto, uma linha de máquina de escrever abaixo da ordem dos turnos.
# O estado vem do ChefeDama; sync() (a cada quadro, pela sala) cria o que falta e acompanha cada mudança.

const ESTILOS := ["A", "B", "C"]
const FONTE := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const SANGUE := Color(0.55, 0.03, 0.05)
const VINHA := Color(0.22, 0.05, 0.06)
const PELE := Color(0.86, 0.72, 0.62)
const MURCHA := Color(0.24, 0.17, 0.1)

static var estilo := "A"  # provisório até a escolha do Léo

var room
var chefe  # ChefeDama
var raiz: Node3D
var nos := {}  # "flor_<id>", "corpo_<n>" ou o Combatant do tentáculo da prisão -> {"no": Node3D, "estado": String, "tipo"}
var _tempo := 0.0
var _faixa: CanvasLayer
var _faixa_tw: Tween


static func criar(sala, c) -> DamaVisual:
	var v := DamaVisual.new()
	v.room = sala
	v.chefe = c
	return v


# --- Base -------------------------------------------------------------------------------------------

func _mundo() -> Node:
	if room == null or room.world3d == null or not ("mundo" in room.world3d) or room.world3d.mundo == null:
		return null
	return room.world3d.mundo


func _em3d(p: Vector2, alto := 0.0) -> Vector3:
	return Vector3(p.x / 64.0, room._altura(p) + alto, p.y / 64.0)


static func _mat(cor: Color, brilho := 0.0, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.85
	if unshaded:  # padrão: a luz vermelha e fraca da cripta deixa o material sombreado quase preto
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m


# Transparente no mundo do local3d: só aparece acima da névoa com render_priority alto (ver memória dama-sangue-fases).
static func _mat_transp(cor: Color) -> StandardMaterial3D:
	var m := _mat(cor, 0.0, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true
	m.render_priority = 12
	m.no_depth_test = false
	return m


static func _peca(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _esfera(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0.0 else r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cilindro(r0: float, r1: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = 8
	return c


func _tentaculo(pontos: Array[Vector3], rb: float, rp: float) -> Tentaculo3D:
	var t := Tentaculo3D.new()
	t.raio_base = rb
	t.raio_ponta = rp
	t.ondula = 0.05
	t.definir(pontos)
	t.crescimento = 1.0
	return t


func _garantir_raiz() -> bool:
	var mundo := _mundo()
	if mundo == null:
		return false
	if raiz == null or not is_instance_valid(raiz):
		raiz = Node3D.new()
		raiz.name = "DamaVisual"
		mundo.add_child(raiz)
	return true


# --- Sincronia ----------------------------------------------------------------------------------------

func sync() -> void:
	if chefe == null or not _garantir_raiz():
		return
	_tempo += room.get_process_delta_time()
	for f: Dictionary in chefe.flores:
		_sync_flor(f)
	for c: Dictionary in chefe.corpos:
		_sync_corpo(c)
	for t: Combatant in nos.keys().filter(func(k) -> bool: return k is Combatant):
		if not chefe.prisoes.has(t):
			_apagar(t)
	for t: Combatant in chefe.prisoes:
		if not nos.has(t):
			_criar_prisao(t, chefe.prisoes[t])


func _apagar(chave) -> void:
	var e: Dictionary = nos.get(chave, {})
	if e.has("no") and is_instance_valid(e["no"]):
		(e["no"] as Node).queue_free()
	nos.erase(chave)


func encerrar() -> void:
	for k in nos.keys():
		var e: Dictionary = nos[k]
		if str(e["estado"]) == "salvo" or str(e["estado"]).begins_with("murcha"):
			continue  # o salvo continua deitado no chão e a flor murcha fica caída
		if e.has("no") and is_instance_valid(e["no"]):
			(e["no"] as Node).queue_free()
		nos.erase(k)


# --- Flores -------------------------------------------------------------------------------------------

func _cor(f: Dictionary) -> Color:
	var c: Array = f["dados"]["rgb"]
	return Color(float(c[0]), float(c[1]), float(c[2]))


func _sync_flor(f: Dictionary) -> void:
	var estado := str(f["estado"])
	var vuln: bool = estado == "aberta" and f["unit"] != null and not (f["unit"] as Combatant).protegido
	var id := "flor_%s" % f["dados"]["id"]
	var e: Dictionary = nos.get(id, {})
	var chave := "%s/%s" % [estado, vuln]
	if e.is_empty():
		e = {"no": _criar_flor(f), "estado": ""}
		nos[id] = e
	var no: Node3D = e["no"]
	if e["estado"] != chave:
		e["estado"] = chave
		_aplicar_flor(f, no, estado, vuln)
	# respiração da flor vulnerável
	var cab: Node3D = no.get_node_or_null("cabeca")
	if cab and estado == "aberta":
		var k := 1.0 + (0.12 * sin(_tempo * 5.0 + float(f["indice"])) if vuln else 0.0)
		cab.scale = Vector3.ONE * k
	var aura: Node3D = no.get_node_or_null("aura")
	if aura:
		aura.visible = vuln
		if vuln:
			(aura as MeshInstance3D).transparency = 0.0
			aura.scale = Vector3.ONE * (1.0 + 0.15 * sin(_tempo * 4.0))


func _criar_flor(f: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Flor_%s" % f["dados"]["id"]
	raiz.add_child(n)
	var base := _em3d(chefe.dama.pos, 0.6)
	var topo := _em3d(chefe.pos_flor(int(f["indice"])), 2.3 if estilo != "C" else 1.8)
	n.position = topo
	var meio := (base + topo) * 0.5 + Vector3(0, 0.6, 0)
	var talo := _tentaculo([base - topo, meio - topo, Vector3.ZERO], 0.09 if estilo != "C" else 0.05, 0.05)
	talo.name = "talo"
	n.add_child(talo)
	var cab := Node3D.new()
	cab.name = "cabeca"
	n.add_child(cab)
	var miolo := Node3D.new()  # tamanho da flor (provisório: 2x, para ler de longe na câmera do combate)
	miolo.scale = Vector3.ONE * 2.0
	cab.add_child(miolo)
	cab = miolo
	var cor := _cor(f)
	match estilo:
		"A":  # orquídea: cinco pétalas abertas e o miolo
			for i in 5:
				var p := _peca(_esfera(0.16, 0.06), _mat(cor, 0.6), Vector3.ZERO)
				p.name = "petala%d" % i
				p.position = Vector3(cos(TAU * i / 5.0) * 0.17, 0.0, sin(TAU * i / 5.0) * 0.17)
				p.scale = Vector3(1.4, 1.0, 0.8)
				p.rotation.y = -TAU * i / 5.0
				cab.add_child(p)
			var nucleo := _peca(_esfera(0.08), _mat(Color(0.95, 0.85, 0.6), 1.0), Vector3(0, 0.04, 0))
			nucleo.name = "nucleo"
			cab.add_child(nucleo)
		"B":  # boca: cabeça redonda com coroa de espinhos
			var b := _peca(_esfera(0.2), _mat(cor, 0.5), Vector3.ZERO)
			b.name = "petala0"
			cab.add_child(b)
			for i in 8:
				var esp := _peca(_cilindro(0.0, 0.04, 0.2), _mat(Color(0.95, 0.9, 0.8)), Vector3(cos(TAU * i / 8.0) * 0.2, 0.08, sin(TAU * i / 8.0) * 0.2))
				esp.rotation = Vector3(sin(TAU * i / 8.0) * 0.9, 0, -cos(TAU * i / 8.0) * 0.9)
				cab.add_child(esp)
		"C":  # lanterna: bulbo aceso
			var bulbo := _peca(_esfera(0.17, 0.42), _mat(cor, 2.2, true), Vector3(0, 0.1, 0))
			bulbo.name = "petala0"
			cab.add_child(bulbo)
	# aura de vulnerável: anel no chão (A e B) ou luz da cor (C)
	if estilo == "C":
		var luz := OmniLight3D.new()
		luz.name = "aura_luz"
		luz.light_color = cor
		luz.omni_range = 2.2
		luz.light_energy = 0.0
		n.add_child(luz)
	var anel := TorusMesh.new()
	anel.inner_radius = 0.32
	anel.outer_radius = 0.42
	var aura := _peca(anel, _mat_transp(Color(cor.r, cor.g, cor.b, 0.85)), Vector3(0, room._altura(chefe.pos_flor(int(f["indice"]))) - topo.y + 0.03, 0))
	aura.name = "aura"
	aura.visible = false
	n.add_child(aura)
	return n


func _aplicar_flor(f: Dictionary, no: Node3D, estado: String, vuln: bool) -> void:
	var cab: Node3D = no.get_node("cabeca")
	var cor := _cor(f)
	var nucleo := no.find_child("nucleo", true, false)
	if nucleo:
		nucleo.visible = estado == "aberta"
	match estado:
		"fechada":  # botão pequeno, fechado, na cor apagada
			cab.scale = Vector3.ONE * 0.5
			_pintar(cab, cor.darkened(0.45), 0.0)
		"aberta":
			var tw: Tween = room.create_tween()
			tw.tween_property(cab, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_pintar(cab, cor, 0.8 if vuln else 0.0)
			if not vuln:
				_pintar(cab, cor.darkened(0.25), 0.0)
		"murcha":
			var tw: Tween = room.create_tween()
			tw.tween_property(cab, "scale", Vector3(0.7, 0.35, 0.7), 0.8)
			tw.parallel().tween_property(no, "position:y", no.position.y - 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_pintar(cab, MURCHA, 0.0)
	var luz: OmniLight3D = no.get_node_or_null("aura_luz")
	if luz:
		luz.light_energy = 1.6 if vuln else 0.0


func _pintar(n: Node, cor: Color, brilho: float) -> void:
	for c in n.get_children():
		_pintar(c, cor, brilho)
		if c is MeshInstance3D and str(c.name).begins_with("petala"):
			var m: StandardMaterial3D = (c as MeshInstance3D).material_override
			m.albedo_color = cor
			m.emission_enabled = brilho > 0.0
			m.emission = cor
			m.emission_energy_multiplier = brilho


# --- Pendurados -------------------------------------------------------------------------------------

func _sync_corpo(c: Dictionary) -> void:
	var id := "corpo_%s" % c["nome"]
	var e: Dictionary = nos.get(id, {})
	if e.is_empty():
		e = {"no": _criar_corpo(c), "estado": "pendurado"}
		nos[id] = e
	var no: Node3D = e["no"]
	var corpo: Node3D = no.get_node("corpo")
	if e["estado"] == "pendurado":
		corpo.rotation.z = 0.08 * sin(_tempo * 1.6 + c["pos"].x)  # balança
	if e["estado"] == str(c["estado"]):
		return
	e["estado"] = str(c["estado"])
	var tent: Node3D = no.get_node_or_null("tentaculo")
	match str(c["estado"]):
		"salvo":
			if tent:
				tent.queue_free()
			var tw: Tween = room.create_tween()
			tw.tween_property(corpo, "position", Vector3(0.3, 0.12, 0.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(corpo, "rotation", Vector3(0, 0, PI / 2.0), 0.5)
		"devorado":
			if tent:
				tent.queue_free()
			var tw: Tween = room.create_tween()
			tw.tween_property(corpo, "scale", Vector3(0.2, 0.2, 0.2), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(corpo.hide)
			var poca := _peca(_cilindro(0.55, 0.55, 0.02), _mat(SANGUE, 0.3), Vector3(0, 0.02, 0))
			no.add_child(poca)


func _figura() -> Node3D:
	var f := Node3D.new()
	f.name = "corpo"
	f.scale = Vector3.ONE * 1.3
	var tronco := _peca(_cilindro(0.17, 0.2, 0.75), _mat(Color(0.66, 0.6, 0.52)), Vector3(0, 0.0, 0))  # roupa clara e suja
	f.add_child(tronco)
	f.add_child(_peca(_esfera(0.14), _mat(PELE), Vector3(0, 0.52, 0)))
	f.add_child(_peca(_cilindro(0.07, 0.07, 0.7), _mat(Color(0.36, 0.32, 0.36)), Vector3(-0.09, -0.7, 0)))
	f.add_child(_peca(_cilindro(0.07, 0.07, 0.7), _mat(Color(0.36, 0.32, 0.36)), Vector3(0.09, -0.7, 0)))
	return f


func _criar_corpo(c: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.name = "Pendurado"
	raiz.add_child(n)
	n.position = _em3d(c["pos"])
	var corpo := _figura()
	n.add_child(corpo)
	var dir: Vector2 = (chefe.dama.pos - c["pos"]).normalized()
	var pe := Vector3(dir.x, 0, dir.y) * 1.3
	match estilo:
		"A":  # casulo de vinha: o tentáculo sai do chão, do lado da Dama, e desce até o ombro
			corpo.position = Vector3(0, 1.5, 0)
			var t := _tentaculo([pe, pe + Vector3(0, 2.8, 0), Vector3(0, 3.1, 0), Vector3(0, 2.15, 0)], 0.16, 0.08)
			t.name = "tentaculo"
			n.add_child(t)
			for i in 3:  # voltas do casulo no tronco
				var anel := TorusMesh.new()
				anel.inner_radius = 0.19
				anel.outer_radius = 0.26
				var v := _peca(anel, _mat(VINHA), Vector3(0, -0.25 + i * 0.25, 0))
				v.rotation.x = 0.25 * (i - 1)
				corpo.add_child(v)
		"B":  # de cabeça para baixo numa corrente do teto, o tentáculo enrolado no corpo
			corpo.position = Vector3(0, 1.9, 0)
			corpo.rotation.x = PI
			var corrente := _peca(_cilindro(0.025, 0.025, 3.0), _mat(Color(0.3, 0.3, 0.32)), Vector3(0, 4.1, 0))
			n.add_child(corrente)
			var t := _tentaculo([pe, pe * 0.5 + Vector3(0, 0.8, 0), Vector3(0.25, 1.4, 0.1), Vector3(-0.2, 1.9, -0.1), Vector3(0.15, 2.4, 0)], 0.13, 0.06)
			t.name = "tentaculo"
			n.add_child(t)
		"C":  # deitado, preso ao chão por raízes
			corpo.position = Vector3(0, 0.22, 0)
			corpo.rotation.z = PI / 2.0
			var t := Node3D.new()
			t.name = "tentaculo"
			n.add_child(t)
			for k in 3:
				var x := -0.5 + k * 0.5
				t.add_child(_tentaculo([Vector3(x, 0, -0.35), Vector3(x, 0.55, 0), Vector3(x, 0, 0.35)], 0.07, 0.04))
	return n


# --- Prisão de Tentáculos e áreas -----------------------------------------------------------------

func _criar_prisao(t: Combatant, preso: Combatant) -> void:
	var n := Node3D.new()
	n.name = "Prisao"
	raiz.add_child(n)
	n.position = _em3d(preso.pos)
	for k in 4:
		var a := TAU * k / 4.0
		var p0 := Vector3(cos(a) * 0.45, 0, sin(a) * 0.45)
		n.add_child(_tentaculo([p0, p0 * 0.6 + Vector3(0, 0.9, 0), Vector3(-sin(a) * 0.18, 1.4, cos(a) * 0.18)], 0.08, 0.03))
	nos[t] = {"no": n, "estado": "preso"}


func habilidade(_id: String) -> void:
	room.fx.shake_time = 0.3
	room.fx.shake_px = 4.0


# Área de Miasma ou Chuva: um disco que aparece e some no chão.
func zona(p: Vector2, raio_px: float, id: String, dura := 0.9) -> void:
	if not _garantir_raiz():
		return
	var cor := Color(0.35, 0.55, 0.2, 0.55) if id == "miasma_fetido" else Color(0.7, 0.03, 0.05, 0.6)
	var mat := _mat_transp(cor)
	mat.no_depth_test = true  # por cima do chão de qualquer altura (ponte, degrau); os personagens são desenhados depois
	var m := _peca(_cilindro(raio_px / 64.0, raio_px / 64.0, 0.02), mat, _em3d(p, 0.05))
	raiz.add_child(m)
	var tw: Tween = room.create_tween()
	tw.tween_interval(dura)
	tw.tween_property(m.material_override, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(m.queue_free)


func cone(origem: Vector2, eixo: Vector2, alcance_px: float, angulo: float) -> void:
	if not _garantir_raiz():
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := _em3d(origem, 0.06)
	var passos := 10
	for i in passos:
		var a0 := eixo.angle() - angulo * 0.5 + angulo * i / passos
		var a1 := eixo.angle() - angulo * 0.5 + angulo * (i + 1) / passos
		var p0 := origem + Vector2.from_angle(a0) * alcance_px
		var p1 := origem + Vector2.from_angle(a1) * alcance_px
		im.surface_add_vertex(Vector3.ZERO)
		im.surface_add_vertex(_em3d(p0, 0.06) - c)
		im.surface_add_vertex(_em3d(p1, 0.06) - c)
	im.surface_end()
	var mc := _mat_transp(Color(0.85, 0.05, 0.08, 0.5))
	mc.no_depth_test = true
	var m := _peca(im, mc, c)
	(m.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	raiz.add_child(m)
	var tw: Tween = room.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(m.material_override, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(m.queue_free)


# Os eventos chegam pelo estado (sync); estes ficam para o ChefeDama avisar sem saber do visual.
func corpo_criar(_c: Dictionary) -> void:
	pass


func corpo_devorado(_c: Dictionary) -> void:
	pass


func corpo_salvo(_c: Dictionary) -> void:
	pass


func flor_abrir(_f: Dictionary) -> void:
	pass


func flor_murchar(_f: Dictionary) -> void:
	pass


func flor_janela(_f: Dictionary, _vulneravel: bool) -> void:
	pass


func prisao_criar(_t: Combatant, _m: Combatant) -> void:
	pass


func prisao_fim(_t: Combatant) -> void:
	pass


# --- Aviso na tela ------------------------------------------------------------------------------------

# `grande`: mudança de fase (mais forte); senão flor aberta ou murcha.
func anunciar(texto: String, cor: Color, grande: bool) -> void:
	if room == null or not room.is_inside_tree():
		return
	if _faixa_tw != null and _faixa_tw.is_valid():
		_faixa_tw.kill()
	if _faixa != null and is_instance_valid(_faixa):
		_faixa.queue_free()
	_faixa = CanvasLayer.new()
	_faixa.layer = 70
	room.add_child(_faixa)
	var tela: Vector2 = room.get_viewport_rect().size
	var raiz2 := Control.new()
	raiz2.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(raiz2)
	var rot := Label.new()
	rot.text = texto
	rot.add_theme_font_override("font", FONTE)
	rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rot.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	rot.add_theme_constant_override("outline_size", 6)
	var dura := 2.0 if grande else 1.6
	match estilo:
		"A":
			var faixa := ColorRect.new()
			faixa.color = Color(cor.r * 0.55, cor.g * 0.2, cor.b * 0.2, 0.82) if grande else Color(0.06, 0.02, 0.02, 0.78)
			var h := 62.0 if grande else 44.0
			faixa.position = Vector2(0, tela.y * 0.42 - h * 0.5)
			faixa.size = Vector2(tela.x, h)
			raiz2.add_child(faixa)
			var linha := ColorRect.new()
			linha.color = cor
			linha.position = faixa.position + Vector2(0, h - 3)
			linha.size = Vector2(tela.x, 3)
			raiz2.add_child(linha)
			rot.position = faixa.position
			rot.size = faixa.size
			rot.add_theme_font_size_override("font_size", 34 if grande else 24)
			rot.add_theme_color_override("font_color", Color(1, 0.93, 0.85))
		"B":
			var borda := ColorRect.new()
			borda.set_anchors_preset(Control.PRESET_FULL_RECT)
			borda.color = Color(cor.r, cor.g, cor.b, 0.0)
			borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sh := Shader.new()
			sh.code = "shader_type canvas_item; uniform vec4 c : source_color; void fragment(){ vec2 d = abs(UV - 0.5) * 2.0; float e = smoothstep(0.55, 1.0, max(d.x, d.y)); COLOR = vec4(c.rgb, c.a * e); }"
			var sm := ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("c", Color(cor.r, cor.g, cor.b, 0.75 if grande else 0.5))
			borda.material = sm
			raiz2.add_child(borda)
			rot.position = Vector2(0, tela.y * 0.16)
			rot.size = Vector2(tela.x, 60)
			rot.add_theme_font_size_override("font_size", 40 if grande else 28)
			rot.add_theme_color_override("font_color", cor.lightened(0.3))
			room.fx.shake_time = 0.45 if grande else 0.25
			room.fx.shake_px = 7.0 if grande else 4.0
		"C":
			rot.position = Vector2(0, 96)
			rot.size = Vector2(tela.x, 28)
			rot.add_theme_font_size_override("font_size", 20 if grande else 16)
			rot.add_theme_color_override("font_color", cor.lightened(0.25))
			rot.visible_ratio = 0.0
			var tw0: Tween = room.create_tween()
			tw0.tween_property(rot, "visible_ratio", 1.0, 0.6)
	raiz2.add_child(rot)
	_faixa_tw = room.create_tween()
	_faixa_tw.tween_interval(dura)
	_faixa_tw.tween_property(raiz2, "modulate:a", 0.0, 0.5)
	_faixa_tw.tween_callback(_faixa.queue_free)
