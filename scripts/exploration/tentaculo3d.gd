class_name Tentaculo3D
extends Node3D
# Tentáculo da Dama de Sangue (cutscene do fim da missão 1, Léo 15/11/2026): um tubo que se afina até a ponta, desenhado
# a cada quadro ao longo de uma curva (Catmull-Rom pelos pontos de controle). `crescimento` (0 a 1) é até onde a ponta
# já chegou; `recuo` (0 a 1) é de onde a base já voltou; o trecho visível vai de um ao outro. Ondula sozinho enquanto vive.
# Provisório: forma, cor e ritmo são do Claude, até o Léo ter o modelo do tentáculo.

const LADOS := 10
const AMOSTRAS_POR_TRECHO := 14
const LUZ := Vector3(-0.35, 0.8, 0.5)  # de cima, da esquerda e da câmera (a luz da cena não conta: o material é sem sombreamento)
const VISTA := Vector3(0.6, 0.45, 0.65)
const COR_SOMBRA := Color(0.1, 0.0, 0.04)
const COR_LUZ := Color(0.62, 0.07, 0.12)
const PONTA_AFINA := 0.7  # unidades 3D em que a ponta se afina até virar bico

var raio_base := 0.3
var raio_ponta := 0.12
var ondula := 0.16  # amplitude da ondulação (unidades 3D); a cena zera no golpe
var crescimento := 0.0
var recuo := 0.0
var comprimento := 0.0

var _pos := PackedVector3Array()  # amostras da curva
var _acum := PackedFloat32Array()  # comprimento acumulado em cada amostra
var _controle := PackedInt32Array()  # índice da amostra de cada ponto de controle
var _tempo := 0.0
var _malha := MeshInstance3D.new()


func _init() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # o brilho vem da cor dos vértices: os dois lados do tubo se leem em qualquer luz da cena
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_malha.material_override = m
	_malha.visible = false
	add_child(_malha)


# Pontos de controle em coordenadas do mundo 3D; a curva passa por todos.
func definir(pontos: Array[Vector3]) -> void:
	_pos.clear()
	_acum.clear()
	_controle.clear()
	var n := pontos.size()
	for i in n - 1:
		var p0 := pontos[maxi(i - 1, 0)]
		var p1 := pontos[i]
		var p2 := pontos[i + 1]
		var p3 := pontos[mini(i + 2, n - 1)]
		_controle.append(_pos.size())
		for k in AMOSTRAS_POR_TRECHO:
			_pos.append(_catmull(p0, p1, p2, p3, float(k) / AMOSTRAS_POR_TRECHO))
	_controle.append(_pos.size())
	_pos.append(pontos[n - 1])
	var soma := 0.0
	_acum.append(0.0)
	for i in range(1, _pos.size()):
		soma += _pos[i].distance_to(_pos[i - 1])
		_acum.append(soma)
	comprimento = soma


# Fração do comprimento em que a curva passa pelo ponto de controle `i`.
func fracao_em(i: int) -> float:
	return _acum[_controle[i]] / comprimento if comprimento > 0.0 else 0.0


# Onde a ponta está agora.
func ponta() -> Vector3:
	return _em(crescimento * comprimento)


func _process(delta: float) -> void:
	_tempo += delta
	_reconstruir()


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


# Ponto da curva à distância `s` da base.
func _em(s: float) -> Vector3:
	if _pos.size() < 2:
		return Vector3.ZERO
	s = clampf(s, 0.0, comprimento)
	var lo := 0
	var hi := _pos.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _acum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg := _acum[hi] - _acum[lo]
	return _pos[lo].lerp(_pos[hi], (s - _acum[lo]) / seg if seg > 0.0 else 0.0)


func _reconstruir() -> void:
	var s0 := clampf(recuo, 0.0, 1.0) * comprimento
	var s1 := clampf(crescimento, 0.0, 1.0) * comprimento
	if s1 - s0 < 0.05 or _pos.size() < 2:
		_malha.visible = false
		return
	var passos := maxi(int((s1 - s0) / 0.1), 4)
	var centro: Array[Vector3] = []
	var dist: Array[float] = []
	for i in passos + 1:
		var s := lerpf(s0, s1, float(i) / passos)
		var p := _em(s)
		centro.append(p)
		dist.append(s)
	# Ondulação para os lados, nula na base e crescendo ao longo do tubo.
	for i in centro.size():
		var t := dist[i] / maxf(comprimento, 0.001)
		var tang := (_em(dist[i] + 0.05) - _em(dist[i] - 0.05)).normalized()
		var lado := tang.cross(Vector3.UP)
		if lado.length() < 0.1:
			lado = Vector3.RIGHT
		lado = lado.normalized()
		var alto := lado.cross(tang).normalized()
		var fase := dist[i] * 2.6 - _tempo * 5.0
		centro[i] += (lado * sin(fase) + alto * cos(fase * 0.8) * 0.6) * ondula * smoothstep(0.0, 0.25, t)
	var verts := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var indices := PackedInt32Array()
	var n1 := Vector3.ZERO
	for i in centro.size():
		var a := centro[maxi(i - 1, 0)]
		var b := centro[mini(i + 1, centro.size() - 1)]
		var tang := (b - a).normalized()
		if i == 0:
			n1 = tang.cross(Vector3.UP if absf(tang.y) < 0.95 else Vector3.RIGHT)
		n1 = (n1 - tang * n1.dot(tang)).normalized()  # transporte paralelo: o anel não gira de um passo para o outro
		var n2 := tang.cross(n1).normalized()
		var t := dist[i] / maxf(comprimento, 0.001)
		var r := lerpf(raio_base, raio_ponta, pow(t, 0.7))
		r *= 0.1 + 0.9 * pow(clampf((s1 - dist[i]) / PONTA_AFINA, 0.0, 1.0), 0.6)  # bico na ponta
		if recuo > 0.0:
			r *= 0.1 + 0.9 * pow(clampf((dist[i] - s0) / PONTA_AFINA, 0.0, 1.0), 0.6)  # e na base que volta
		for j in LADOS:
			var ang := TAU * float(j) / LADOS
			var d := n1 * cos(ang) + n2 * sin(ang)
			verts.append(centro[i] + d * r)
			normais.append(d)
			var lam := clampf(d.dot(LUZ), 0.0, 1.0)
			var brilho := pow(clampf(d.dot((LUZ + VISTA).normalized()), 0.0, 1.0), 14.0)  # pele úmida
			var c := COR_SOMBRA.lerp(COR_LUZ, lam)
			cores.append(Color(c.r + brilho * 0.5, c.g + brilho * 0.3, c.b + brilho * 0.3))
	for i in centro.size() - 1:
		for j in LADOS:
			var j2 := (j + 1) % LADOS
			var q := i * LADOS
			indices.append_array([q + j, q + LADOS + j, q + j2, q + j2, q + LADOS + j, q + LADOS + j2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normais
	arr[Mesh.ARRAY_COLOR] = cores
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_malha.mesh = mesh
	_malha.visible = true
