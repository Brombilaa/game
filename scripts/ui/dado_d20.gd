class_name DadoD20
extends Control
# Um d20 de verdade (icosaedro) desenhado em 3D no próprio Control: gira, se embaralha e desacelera até parar com o
# número sorteado virado para o jogador. Sem malha nem câmera: projeção ortogonal, faces com sombreado e o número de cada
# face (faces opostas somam 21, como num dado real). Usado pela TelaD20 (teste de perícia, Léo 22/11: "o dado se embaralhando todo").

signal parou

const PHI := 1.6180339887
const LUZ := Vector3(-0.45, -0.6, 0.66)

var verts: Array[Vector3] = []
var faces: Array[PackedInt32Array] = []
var normais: Array[Vector3] = []
var numeros: PackedInt32Array = PackedInt32Array()  # número de cada face
var q := Quaternion(Vector3(0.3, 0.8, 0.5).normalized(), 0.9)
var cor_corpo := Color(0.24, 0.2, 0.27)
var cor_luz := Color(0.78, 0.66, 0.42)
var cor_aresta := Color(0.93, 0.86, 0.68)
var cor_num := Color(1.0, 0.97, 0.88)
var brilho := Color(0, 0, 0, 0)  # halo do resultado (verde ou vermelho)

var _t := 0.0
var _dur := 2.6
var _rodando := false
var _alvo := Quaternion.IDENTITY
var _w0 := 14.0
var _fase := Vector3.ZERO
var _numero_visivel := 0  # durante o giro, o dado "sorteia" mostrando faces; este é o número da face da frente


func _init() -> void:
	_montar()


func _montar() -> void:
	var cru: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			cru.append(Vector3(0, a, b * PHI))
			cru.append(Vector3(a, b * PHI, 0))
			cru.append(Vector3(b * PHI, 0, a))
	for v in cru:
		verts.append(v.normalized())
	for i in verts.size():
		for j in range(i + 1, verts.size()):
			for k in range(j + 1, verts.size()):
				var e := 2.0 / sqrt(1.0 + PHI * PHI)
				if absf(verts[i].distance_to(verts[j]) - e) < 0.01 and absf(verts[j].distance_to(verts[k]) - e) < 0.01 and absf(verts[i].distance_to(verts[k]) - e) < 0.01:
					faces.append(PackedInt32Array([i, j, k]))
	for f in faces:
		normais.append(((verts[f[0]] + verts[f[1]] + verts[f[2]]) / 3.0).normalized())
	numeros.resize(faces.size())
	var usado := PackedInt32Array()
	usado.resize(faces.size())
	var n := 1
	for a in faces.size():
		if usado[a] == 1:
			continue
		for b in range(a + 1, faces.size()):
			if usado[b] == 0 and normais[a].dot(normais[b]) < -0.99:
				numeros[a] = n
				numeros[b] = 21 - n
				usado[a] = 1
				usado[b] = 1
				n += 1
				break


# Lança o dado: gira por `duracao` segundos e para com `valor` (1 a 20) virado para a frente.
func lancar(valor: int, duracao := 2.6) -> void:
	_dur = duracao
	_t = 0.0
	_rodando = true
	_fase = Vector3(randf() * 6.0, randf() * 6.0, randf() * 6.0)
	var f := numeros.find(clampi(valor, 1, 20))
	_alvo = Quaternion(normais[f], Vector3(0, 0, 1))
	# gira o alvo em torno da frente até a aresta de cima ficar reta: o número fica de pé
	var topo := _alvo * (verts[faces[f][0]] - normais[f] * verts[faces[f][0]].dot(normais[f]))
	var ang := atan2(topo.x, -topo.y)
	_alvo = Quaternion(Vector3(0, 0, 1), -ang) * _alvo
	set_process(true)


func parado(valor: int) -> void:  # mostra direto o resultado, sem animação
	_rodando = false
	var f := numeros.find(clampi(valor, 1, 20))
	q = Quaternion(normais[f], Vector3(0, 0, 1))
	_alvo = q
	queue_redraw()


func _process(delta: float) -> void:
	if not _rodando:
		return
	_t += delta
	var u := clampf(_t / _dur, 0.0, 1.0)
	var vel := _w0 * pow(1.0 - u, 2.0)
	var eixo := Vector3(sin(_t * 3.1 + _fase.x), cos(_t * 2.3 + _fase.y), sin(_t * 1.7 + _fase.z)).normalized()
	q = (Quaternion(eixo, vel * delta) * q).normalized()
	if u > 0.62:  # na reta final o dado se acomoda na face sorteada
		var k := (u - 0.62) / 0.38
		q = q.slerp(_alvo, k * k * 0.35 + 0.05).normalized()
	if u >= 1.0:
		q = _alvo
		_rodando = false
		queue_redraw()
		parou.emit()
		return
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.44
	var u := clampf(_t / _dur, 0.0, 1.0) if _rodando else 1.0
	var escala := 1.0 + (1.0 - clampf(_t / 0.45, 0.0, 1.0)) * 0.45 if _rodando else 1.0  # entra grande e assenta
	r *= escala
	if brilho.a > 0.0:
		for i in 5:
			draw_circle(c, r * (1.18 + i * 0.07), Color(brilho.r, brilho.g, brilho.b, brilho.a * 0.16 / (i + 1)))
	var b := Basis(q)
	var lista: Array[Dictionary] = []
	for i in faces.size():
		var n := b * normais[i]
		if n.z <= 0.0:
			continue
		var pts := PackedVector2Array()
		var prof := 0.0
		for vi in faces[i]:
			var p := b * verts[vi]
			pts.append(c + Vector2(p.x, p.y) * r)
			prof += p.z
		lista.append({"i": i, "n": n, "pts": pts, "z": prof})
	lista.sort_custom(func(x, y): return x["z"] < y["z"])
	var fonte := ThemeDB.fallback_font
	var luz := LUZ.normalized()
	for it in lista:
		var n: Vector3 = it["n"]
		var claro := clampf(n.dot(luz), 0.0, 1.0)
		var cor := cor_corpo.lerp(cor_luz, claro * 0.55)
		cor = cor.lerp(Color.WHITE, pow(claro, 6.0) * 0.18)  # um brilho de resina no lado da luz
		draw_colored_polygon(it["pts"], cor)
		var contorno: PackedVector2Array = it["pts"].duplicate()
		contorno.append(contorno[0])
		draw_polyline(contorno, Color(cor_aresta.r, cor_aresta.g, cor_aresta.b, 0.35 + 0.4 * claro), maxf(1.2, r * 0.012), true)
		var centro := Vector2.ZERO
		for p in it["pts"]:
			centro += p
		centro /= 3.0
		var tam := int(r * 0.34 * clampf(n.z, 0.0, 1.0) + 1.0)
		if n.z > 0.35 and tam >= 10:
			var txt := str(numeros[it["i"]])
			var medida := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
			var asc := fonte.get_ascent(tam)
			var pos := centro + Vector2(-medida.x * 0.5, (asc - medida.y * 0.5) * 0.9)
			draw_string(fonte, pos + Vector2(1.5, 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.55))
			draw_string(fonte, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(cor_num.r, cor_num.g, cor_num.b, clampf(n.z * 1.3, 0.0, 1.0)))
	_numero_visivel = 0
