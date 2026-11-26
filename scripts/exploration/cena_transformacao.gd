class_name CenaTransformacao
extends Node
# Transformação de Roberto Ghular na Dama de Sangue, em cena (Léo, 26/11/2026: "não precisa ler a transformação, tem que
# torná-la visual"; texto do roteiro 5b). O corpo dele (recém sacrificado) convulsiona, uma vinha rompe do ombro e abre
# uma flor de dentes afiados, sete vinhas com flores coloridas completam a forma, a flor central "olha" o grupo e grita
# de novo; só então a Dama aparece de verdade e o combate volta. Sem texto: tudo é imagem, tremor e clarão.
# Mesmo molde da CenaTentaculo (combate congelado, faixas do cinema, câmera conduzida pela cena); filho de local3d.gd.
# Três enquadramentos para o Léo escolher (regra "sempre 3 modelos"); `estilo` troca a condução da câmera e do ritmo:
#   A · Ruptura de perto: câmera apertada no corpo o tempo todo; as vinhas estouram uma depois da outra.
#   B · Subida: a câmera sobe junto com a vinha central até a flor, e só então abre para as sete vinhas.
#   C · Sangue primeiro: plano aberto do salão; o sangue dos fossos corre até o corpo antes de ele romper.
# Formas, cores e tempos provisórios do Claude, até o modelo da Dama sair do Blender do Léo.

signal terminou  # a cena acabou e o combate voltou

const ESTILOS := ["A", "B", "C"]
# Sem janela (testes headless) a cena não toca, como a CenaNarrada.
static var pular := DisplayServer.get_name() == "headless"
static var estilo := "A"  # provisório até a escolha do Léo

# Cores das sete flores, na ordem da tabela do Léo (data/dama_sangue.json).
const CORES := [
	Color(0.96, 0.52, 0.12), Color(0.95, 0.42, 0.68), Color(0.58, 0.28, 0.85), Color(0.97, 0.85, 0.2),
	Color(0.35, 0.75, 0.3), Color(0.28, 0.5, 0.95), Color(0.85, 0.08, 0.1),
]
const SANGUE := Color(0.55, 0.03, 0.05)
const MARFIM := Color(0.96, 0.92, 0.82)

var room  # local3d.gd
var dama: Combatant
var corpo: Combatant  # Roberto Ghular, caído
var cinema: Cinema
var central: Tentaculo3D
var flor_central: FlorDentes
var vinhas: Array[Tentaculo3D] = []
var flores: Array[Node3D] = []
var _cam_alvo := Vector2.ZERO
var _zoom_alvo := 1.5
var _zoom_base := 1.5
var _seguir := false
var _cam_pos := Vector2.ZERO  # a sala reposiciona a câmera no _process dela: a cena guarda a própria posição e sobrescreve
var _zoom := 1.5
var _limites: Array = []
var _tremor := 0.0  # força do tremor do corpo
var _ag: Agente3D
var _ag_pos := Vector3.ZERO
var encerrada := false  # as vinhas já foram liberadas
var _origem := Vector3.ZERO  # onde o corpo está (mundo 3D)


# Flor de dentes afiados da vinha central (a "cabeça" da Dama). `abre` (0 a 1) abre as pétalas e mostra os dentes.
class FlorDentes extends Node3D:
	var abre := 0.0:
		set(v):
			abre = v
			for i in petalas.size():
				petalas[i].rotation.x = lerpf(-0.15, -1.25, v)
			for d in dentes:
				d.scale = Vector3.ONE * lerpf(0.2, 1.0, v)
	var petalas: Array[Node3D] = []
	var dentes: Array[Node3D] = []

	func _init() -> void:
		var garganta := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.3
		s.height = 0.5
		garganta.mesh = s
		garganta.material_override = CenaTransformacao._mat(Color(0.12, 0.0, 0.02))
		garganta.position = Vector3(0, 0.05, 0)
		add_child(garganta)
		for i in 6:
			var pivo := Node3D.new()
			pivo.rotation.y = TAU * i / 6.0
			add_child(pivo)
			var p := MeshInstance3D.new()
			var q := SphereMesh.new()
			q.radius = 0.34
			q.height = 0.5
			p.mesh = q
			p.scale = Vector3(0.55, 1.5, 0.22)
			p.position = Vector3(0.0, 0.42, 0.28)
			p.material_override = CenaTransformacao._mat(Color(0.62, 0.05, 0.1), 0.5)
			var gancho := Node3D.new()  # a pétala gira em torno da base, no anel
			gancho.position = Vector3(0, 0, 0.22)
			gancho.add_child(p)
			p.position = Vector3(0.0, 0.42, 0.06)
			pivo.add_child(gancho)
			petalas.append(gancho)
		for i in 12:
			var dpivo := Node3D.new()
			dpivo.rotation.y = TAU * i / 12.0
			add_child(dpivo)
			var d := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.045
			c.height = 0.34
			c.radial_segments = 6
			d.mesh = c
			d.material_override = CenaTransformacao._mat(CenaTransformacao.MARFIM, 0.4)
			d.position = Vector3(0, 0.12, 0.3)
			d.rotation.x = -0.35
			var gd := Node3D.new()
			gd.add_child(d)
			dpivo.add_child(gd)
			dentes.append(gd)
		abre = 0.0


static func _mat(cor: Color, brilho := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # a luz da cripta é fraca: o mesmo recurso do DamaVisual
	if brilho > 0.0:
		m.albedo_color = cor.lerp(Color.WHITE, 0.12 * brilho)
	return m


func iniciar(sala, a_dama: Combatant, o_corpo: Combatant) -> void:
	room = sala
	dama = a_dama
	corpo = o_corpo
	_congelar_combate()
	tocar()


# O combate para aqui: ninguém age mais e o HUD some (igual à cena do Fernando).
func _congelar_combate() -> void:
	room.mode = room.Mode.CUTSCENE
	if room.turns:
		room.turns.state = TurnManager.State.ENDED
		room.turns.current = null
	Engine.time_scale = 1.0
	room.busy = true
	room.path = PackedVector2Array()
	room.popups.clear()
	room.combat_log.clear()
	room.audio.stop_music()
	room.hud.on_turn_ended()
	var cam: Camera2D = room.camera
	_zoom_base = cam.zoom.x
	_limites = [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	_cam_alvo = cam.position
	_cam_pos = cam.position
	_zoom = cam.zoom.x
	_zoom_alvo = _zoom_base
	room.queue_redraw()


func _process(delta: float) -> void:
	if room == null:
		return
	var cam: Camera2D = room.camera
	if _seguir and central:
		_cam_alvo = _iso3(central.ponta())
	_cam_pos = _cam_pos.lerp(_cam_alvo, 1.0 - exp(-3.2 * delta))
	cam.position = _cam_pos.round()
	_zoom = lerpf(_zoom, _zoom_alvo * float(Cinema.ZOOM_REL[cinema.modo]) if cinema else _zoom_alvo, 1.0 - exp(-2.4 * delta))
	cam.zoom = Vector2(_zoom, _zoom)
	if encerrada:
		return
	if flor_central and central:
		flor_central.position = central.ponta()
		var t := central.ponta() - central._em(maxf(central.crescimento * central.comprimento - 0.4, 0.0))
		if t.length() > 0.01:
			flor_central.basis = Basis(Quaternion(Vector3.UP, t.normalized()))  # o cálice aponta na direção da ponta
		flor_central.visible = central.crescimento > 0.02
	for i in vinhas.size():
		if i < flores.size():
			var v := vinhas[i]
			flores[i].position = v.ponta()
			flores[i].visible = v.crescimento > 0.05
			flores[i].scale = Vector3.ONE * clampf(v.crescimento * 1.6, 0.0, 1.0) * 1.5
	if _ag and _tremor > 0.0:
		_ag.modelo.position = _ag_pos + Vector3(randf_range(-1, 1), randf_range(0, 0.5), randf_range(-1, 1)) * 0.06 * _tremor
	room.queue_redraw()


func _iso3(p: Vector3) -> Vector2:
	return room._iso(Vector2(p.x * 64.0, p.z * 64.0)) + Vector2(0.0, -p.y * room.PX_ALTURA)


func _p3(p: Vector2, alto := 0.0) -> Vector3:
	return Vector3(p.x / 64.0, room._altura(p) + alto, p.y / 64.0)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _crescer(t: Tentaculo3D, s: float, trans := Tween.TRANS_QUAD, ate := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(t, "crescimento", ate, s).set_trans(trans).set_ease(Tween.EASE_OUT)
	await tw.finished


func _tremer(forca: float, tempo: float, flash := 0.0) -> void:
	room.fx.shake_time = tempo
	room.fx.shake_px = forca
	if flash > 0.0:
		room.fx.flash_red = flash
		room.fx.flash_strength = 1.5


func _sangue(ponto: Vector2, qtd: int, forca := 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	for i in qtd:
		room.fx.particles.append({"pos": ponto, "vel": Vector2(rng.randf_range(-90, 90), rng.randf_range(-140, 10)) * forca, "life": 1.0, "max": 1.0, "kind": "blood", "size": rng.randf_range(1.5, 3.5)})


# C: o sangue dos fossos corre até o corpo (linhas de respingo convergindo ao redor).
func _sangue_corre(segundos: float) -> void:
	var rng := RandomNumberGenerator.new()
	var alvo := _iso3(_origem + Vector3(0, 0.6, 0))
	var t := 0.0
	while t < segundos:
		for i in 5:
			var ang := rng.randf() * TAU
			var raio := rng.randf_range(150.0, 330.0)
			var de := alvo + Vector2(cos(ang), sin(ang) * 0.55) * raio
			var vel := (alvo - de) / 0.7
			room.fx.particles.append({"pos": de, "vel": vel, "life": 0.7, "max": 0.7, "kind": "blood", "size": rng.randf_range(2.0, 4.0)})
		await _esperar(0.08)
		t += 0.08


func _poca(f: Vector3) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.32, 0.015, 0.04, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = f + Vector3(0, 0.06, 0)
	mi.scale = Vector3(0.1, 0.1, 0.1)
	room.world3d.mundo.add_child(mi)
	create_tween().tween_property(mi, "scale", Vector3(1, 1, 1), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	vinhas_extras.append(mi)


var vinhas_extras: Array[Node] = []


func _flor_orquidea(cor: Color) -> Node3D:
	var n := Node3D.new()
	for i in 5:
		var p := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.06
		p.mesh = s
		p.material_override = _mat(cor, 1.0)
		p.position = Vector3(cos(TAU * i / 5.0) * 0.17, 0.0, sin(TAU * i / 5.0) * 0.17)
		p.scale = Vector3(1.4, 1.0, 0.8)
		p.rotation.y = -TAU * i / 5.0
		n.add_child(p)
	var nucleo := MeshInstance3D.new()
	var ns := SphereMesh.new()
	ns.radius = 0.08
	ns.height = 0.16
	nucleo.mesh = ns
	nucleo.material_override = _mat(Color(0.95, 0.85, 0.6), 1.0)
	nucleo.position = Vector3(0, 0.04, 0)
	n.add_child(nucleo)
	return n


func _nova_vinha(pontos: Array[Vector3], rb: float, rp: float) -> Tentaculo3D:
	var t := Tentaculo3D.new()
	t.raio_base = rb
	t.raio_ponta = rp
	t.ondula = 0.1
	room.world3d.mundo.add_child(t)
	t.definir(pontos)
	return t


func tocar() -> void:
	cinema = Cinema.new()
	room.add_child(cinema)
	_origem = _p3(corpo.pos)
	var o := _origem
	_ag = room.agentes.get(corpo)
	if _ag:
		_ag_pos = _ag.modelo.position
	var ombro := o + Vector3(0.1, 0.5, 0)  # o corpo está caído: a vinha rompe do ombro, perto do chão
	# Vinha central: sobe torcendo até a altura de duas pessoas.
	var pc: Array[Vector3] = [ombro, ombro + Vector3(0.1, 1.3, 0.2), ombro + Vector3(-0.25, 2.5, -0.1), ombro + Vector3(0.0, 3.7, 0.15)]
	central = _nova_vinha(pc, 0.34, 0.2)
	central.ondula = 0.2
	flor_central = FlorDentes.new()
	room.world3d.mundo.add_child(flor_central)
	flor_central.visible = false
	flor_central.scale = Vector3.ONE * 1.5
	# Sete vinhas: abrem em leque em volta do corpo, cada uma com a flor da sua cor.
	for k in 7:
		var ang := TAU * (k + 0.35) / 7.0
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var alto := 1.5 + 0.5 * float(k % 3)
		var pv: Array[Vector3] = [ombro - d * 0.1, ombro + d * 0.7 + Vector3(0, 1.0, 0), ombro + d * 1.7 + Vector3(0, alto + 0.4, 0), ombro + d * 2.9 + Vector3(0, alto - 0.3 + 0.4 * float(k % 2), 0)]
		var v := _nova_vinha(pv, 0.2, 0.1)
		v.ondula = 0.16
		vinhas.append(v)
		var fl := _flor_orquidea(CORES[k])
		room.world3d.mundo.add_child(fl)
		fl.visible = false
		flores.append(fl)
	# Câmera e ritmo de cada modelo.
	match estilo:
		"A":
			_cam_alvo = _iso3(o + Vector3(0, 1.4, 0))
			_zoom_alvo = _zoom_base + 0.9
		"B":
			_cam_alvo = _iso3(o + Vector3(0, 0.8, 0))
			_zoom_alvo = _zoom_base + 0.8
		_:
			_cam_alvo = _iso3(o + Vector3(0, 0.5, 0))
			_zoom_alvo = maxf(_zoom_base - 0.15, 0.9)
	_tremer(3.0, 0.5)
	await cinema.entrar(0.9)
	await _esperar(0.3)
	# 1. O sangue verte para dentro do corpo; ele tem espasmos (socos vindos de dentro).
	_tremor = 1.0
	if estilo == "C":
		_poca(o)
		await _sangue_corre(2.2)
	else:
		_poca(o)
		await _esperar(0.9)
	for i in 3:
		_tremer(5.0 + 2.0 * i, 0.3)
		_sangue(_iso3(o + Vector3(0, 0.5, 0)), 10)
		_tremor = 1.5 + i
		await _esperar(0.4 if estilo != "A" else 0.3)
	# 2. A vinha central rompe separando o ombro do pescoço e se projeta para cima.
	_tremer(11.0, 0.7, 0.5)
	_sangue(_iso3(ombro), 40, 1.4)
	_seguir = estilo == "B"
	if estilo == "B":
		_zoom_alvo = _zoom_base + 0.5
	await _crescer(central, 0.9 if estilo != "A" else 0.6, Tween.TRANS_EXPO)
	_seguir = false
	# 3. A flor de dentes abre e grita.
	if estilo == "B":
		_cam_alvo = _iso3(central.ponta())
		_zoom_alvo = _zoom_base + 0.9
	elif estilo == "A":
		_cam_alvo = _iso3(o + Vector3(0, 2.2, 0))
		_zoom_alvo = _zoom_base + 0.7
	var abre := create_tween()
	abre.tween_property(flor_central, "abre", 1.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await abre.finished
	room.audio.on_boss_appeared()  # o grito
	_tremer(10.0, 0.9, 0.55)
	_tremor = 0.3
	await _esperar(0.7)
	# 4. As sete vinhas saem do corpo, estourando órgãos e ossos, com as flores coloridas.
	if estilo == "B":
		_cam_alvo = _iso3(o + Vector3(0, 1.8, 0))
		_zoom_alvo = _zoom_base + 0.2
	elif estilo == "C":
		_cam_alvo = _iso3(o + Vector3(0, 1.6, 0))
		_zoom_alvo = _zoom_base + 0.3
	for k in 7:
		_tremer(6.0, 0.35)
		_sangue(_iso3(ombro + Vector3(0, 0.3, 0)), 14)
		_crescer(vinhas[k], 0.85, Tween.TRANS_BACK)
		await _esperar(0.22 if estilo != "A" else 0.16)
	await _esperar(0.7)
	# 5. A flor central se vira como se olhasse o grupo e grita outra vez.
	var vira := create_tween()
	vira.tween_property(flor_central, "scale", Vector3.ONE * 1.9, 0.4).set_trans(Tween.TRANS_SINE)
	_cam_alvo = _iso3(central.ponta())
	_zoom_alvo = _zoom_base + 0.4
	await _esperar(0.6)
	_tremer(13.0, 1.0, 0.65)
	_sangue(_iso3(central.ponta()), 30, 1.2)
	await _esperar(1.3)
	# 6. A forma se fecha: a Dama toma o lugar do corpo e o combate volta.
	await _retomar()


func _retomar() -> void:
	_tremor = 0.0
	if _ag:
		_ag.modelo.position = _ag_pos
	room.transformacao_pendente = false  # a Dama passa a ser desenhada e as flores dela aparecem
	var recua := create_tween().set_parallel(true)
	for v in vinhas:
		recua.tween_property(v, "recuo", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	recua.tween_property(central, "recuo", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	recua.tween_property(flor_central, "scale", Vector3.ZERO, 0.7)
	for f in flores:
		recua.tween_property(f, "scale", Vector3.ZERO, 0.7)
	_cam_alvo = _iso3(_origem + Vector3(0, 1.2, 0))
	_zoom_alvo = _zoom_base
	await recua.finished
	encerrada = true
	for v in vinhas:
		v.queue_free()
	for f in flores:
		f.queue_free()
	for e in vinhas_extras:
		e.queue_free()
	central.queue_free()
	flor_central.queue_free()
	await cinema.sair(0.8)
	cinema.queue_free()
	var cam: Camera2D = room.camera
	cam.zoom = Vector2(_zoom_base, _zoom_base)
	cam.limit_left = _limites[0]
	cam.limit_top = _limites[1]
	cam.limit_right = _limites[2]
	cam.limit_bottom = _limites[3]
	room.mode = room.Mode.COMBAT
	room.busy = false
	Engine.time_scale = 2.0 if room.options.values["fast_combat"] else 1.0
	room.audio.on_combat_started()
	room.turns.state = TurnManager.State.ACTIVE
	room.turns._advance()  # segue a ordem normal, agora com a Dama
	terminou.emit()
	queue_free()
