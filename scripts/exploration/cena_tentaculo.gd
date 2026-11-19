class_name CenaTentaculo
extends Node
# Cutscene in-game da morte do Fernando (Léo, 15/11/2026): com a Dama de Sangue em ~20% de vida (fim.limite de cripta.json), um tentáculo dela sobe,
# desce até o chão, rasteja até o Fernando e atravessa o meio do corpo dele. Ele morre e o combate continua.
# Roda dentro do jogo, em modo cinema (Cinema), com o combate congelado e o HUD escondido. Tempos, textos e a
# forma do tentáculo são provisórios do Claude. Filho da sala (local3d.gd): o _process dele roda depois do da sala e
# manda na câmera.

signal terminou  # a cena acabou e o combate voltou

const ZOOM_DAMA := 1.5
const ZOOM_PONTA := 1.25
const ZOOM_GOLPE := 1.4  # o corpo inteiro cabe na janela das faixas (Léo, 15/11: "não dá pra ver a morte")
const T_SOBE := 1.5  # s: do corpo da Dama até o ar e de volta ao chão
const T_RASTEJA := 1.7  # s: pelo chão até as costas do Fernando
const T_ENROSCA := 0.7  # s: a ponta se levanta e mira
const T_GOLPE := 0.16  # s: a estocada
const T_SEGURA := 1.8  # s: segura o Fernando erguido, com o tentáculo atravessado
const T_RECUA := 0.9  # s: o tentáculo sai do corpo e volta

var room  # local3d.gd
var dama: Combatant
var fernando: Combatant
var cinema: Cinema
var tentaculo: Tentaculo3D
var extras: Array[Tentaculo3D] = []
var fim: Dictionary  # data/cenarios/cripta.json -> "fim"
var _cam_alvo := Vector2.ZERO  # onde a câmera quer estar (desenho iso)
var _zoom_alvo := 1.0
var _seguir_ponta := false
var _zoom_base := 1.0
var _limites: Array = []


func iniciar(sala, a_dama: Combatant, a_fim: Dictionary) -> void:
	room = sala
	dama = a_dama
	fim = a_fim
	for m in room.party:
		if m.name == "Fernando":
			fernando = m
	if fernando == null:
		fernando = room.party[0]
	_congelar_combate()
	tocar()


# O combate acaba aqui: ninguém age mais e o HUD some. A vitória sobre a Dama não vale (a cena decide o fim).
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
	if not fernando.is_alive():
		fernando.pv = 1  # caído quando a cena começou: a cena é dele
	room.facing8[fernando] = CharacterSheet.dir_from_vector(Vector2(0, 1))  # de frente para a câmera
	room.facing8[dama] = CharacterSheet.dir_from_vector(room._iso(fernando.pos) - room._iso(dama.pos))  # a Dama olha para ele
	var cam: Camera2D = room.camera
	_zoom_base = cam.zoom.x
	_limites = [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]  # a cena enquadra além da borda do mapa
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	_cam_alvo = cam.position
	_zoom_alvo = _zoom_base
	room.queue_redraw()


func _process(delta: float) -> void:
	if room == null:
		return
	var cam: Camera2D = room.camera
	if _seguir_ponta and tentaculo:
		_cam_alvo = _iso3(tentaculo.ponta())
	cam.position = cam.position.lerp(_cam_alvo, 1.0 - exp(-4.5 * delta)).round()
	var z := lerpf(cam.zoom.x, _zoom_alvo * float(Cinema.ZOOM_REL[cinema.modo]) if cinema else _zoom_alvo, 1.0 - exp(-3.0 * delta))
	cam.zoom = Vector2(z, z)
	room.queue_redraw()


# Mundo 3D -> ponto do desenho iso (onde a câmera 2D mira).
func _iso3(p: Vector3) -> Vector2:
	return room._iso(Vector2(p.x * 64.0, p.z * 64.0)) + Vector2(0.0, -p.y * room.PX_ALTURA)


func _p3(p: Vector2, alto := 0.0) -> Vector3:
	return Vector3(p.x / 64.0, room._altura(p) + alto, p.y / 64.0)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _crescer(ate: float, s: float, trans := Tween.TRANS_SINE) -> void:
	var tw := create_tween()
	tw.tween_property(tentaculo, "crescimento", ate, s).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func tocar() -> void:
	cinema = Cinema.new()
	room.add_child(cinema)
	var d := _p3(dama.pos)
	var f := _p3(fernando.pos)
	var h := Vector3(f.x - d.x, 0.0, f.z - d.z)
	var dist := h.length()
	h = h.normalized() if dist > 0.01 else Vector3(1, 0, 0)
	var lado := Vector3(-h.z, 0.0, h.x)  # perpendicular no chão
	var atras := Vector3(-sin(PI / 4.0), 0.0, -cos(PI / 4.0)) * 0.22  # um pouco atrás do centro do corpo: o meio some dentro dele e só as pontas aparecem
	var dir_direita := Vector3(cos(PI / 4.0), 0.0, -sin(PI / 4.0))  # para a direita da tela
	# Caminho: sai das costas da Dama, sobe, desce até o chão, rasteja até a esquerda do Fernando (na tela), levanta
	# a ponta e o atravessa de lado a lado na altura do peito: entra pela esquerda e sai pela direita, tudo à vista.
	var pts: Array[Vector3] = [
		d + Vector3(0, 1.9, 0),  # 0 base
		d + h * 0.8 + Vector3(0, 4.4, 0),  # 1 sobe
		d + h * dist * 0.42 + lado * 0.6 + Vector3(0, 3.0, 0),  # 2 arqueia
		d + h * dist * 0.6 + lado * 1.0 + Vector3(0, 0.15, 0),  # 3 toca o chão
		f - dir_direita * 4.6 + Vector3(0, 0.15, 0),  # 4 rasteja
		f - dir_direita * 3.4 + Vector3(0, 0.6, 0),  # 5 enrosca
		f - dir_direita * 2.0 + atras + Vector3(0, 1.5, 0),  # 6 mira (a ponta se levanta)
		f + atras + Vector3(0, 1.6, 0),  # 7 meio do corpo
		f + dir_direita * 2.1 + atras + Vector3(0, 1.75, 0),  # 8 sai do outro lado
	]
	tentaculo = Tentaculo3D.new()
	room.world3d.mundo.add_child(tentaculo)
	tentaculo.definir(pts)
	# 1. Barras, HUD fora, câmera na Dama.
	_cam_alvo = _iso3(d + Vector3(0, 1.2, 0))
	_zoom_alvo = ZOOM_DAMA
	room.fx.shake_time = 0.4
	room.fx.shake_px = 4.0
	create_tween().tween_property(self, "_zoom_alvo", ZOOM_DAMA + 0.3, 2.2).set_trans(Tween.TRANS_SINE)  # a câmera se aproxima devagar
	_extras(d, h, lado)
	await cinema.entrar(1.0)
	await _esperar(0.9)
	# 2. O tentáculo sobe e desce até o chão; a câmera segue a ponta.
	_seguir_ponta = true
	_zoom_alvo = ZOOM_PONTA
	await _crescer(tentaculo.fracao_em(3), T_SOBE)
	# 3. Rasteja até as costas do Fernando.
	await _crescer(tentaculo.fracao_em(5), T_RASTEJA)
	# 4. Enrosca: a ponta se levanta; a câmera abre em Fernando.
	_seguir_ponta = false
	_cam_alvo = _iso3(f + Vector3(0, 2.6, 0))
	_zoom_alvo = ZOOM_GOLPE
	await _crescer(tentaculo.fracao_em(6), T_ENROSCA)
	room._attack_started(dama, fernando, room._attack_aim(dama))  # a Dama se inclina para o golpe
	await _esperar(0.55)
	# 5. A estocada.
	var viva := tentaculo.ondula
	tentaculo.ondula = 0.02
	await _crescer(1.0, T_GOLPE, Tween.TRANS_EXPO)
	_impacto(f)
	_zoom_alvo = ZOOM_GOLPE + 0.2
	await _esperar(0.28)  # o mundo para um instante no golpe
	_zoom_alvo = ZOOM_GOLPE
	# 6. Segura: o Fernando erguido, com o tentáculo atravessado.
	var ag: Agente3D = room.agentes.get(fernando)
	if ag:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(ag.modelo, "position:y", ag.modelo.position.y + 0.35, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ag.modelo, "rotation:x", -0.3, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var bal := create_tween().set_loops(2)  # o corpo balança, preso no tentáculo
		bal.tween_property(ag.modelo, "rotation:z", 0.07, 0.4).set_trans(Tween.TRANS_SINE)
		bal.tween_property(ag.modelo, "rotation:z", -0.07, 0.4).set_trans(Tween.TRANS_SINE)
	await _esperar(T_SEGURA)
	tentaculo.ondula = viva
	# 7. O tentáculo sai do corpo e volta; o Fernando cai.
	var recua := create_tween().set_parallel(true)
	recua.tween_property(tentaculo, "recuo", 1.0, T_RECUA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if ag:
		recua.tween_property(ag.modelo, "rotation:x", -PI / 2.0 + 0.1, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		recua.tween_property(ag.modelo, "position:y", ag.modelo.position.y - 0.15, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await recua.finished
	room.fx.shake_time = 0.3
	room.fx.shake_px = 3.0
	_poca(f)
	_cam_alvo = _iso3(f + Vector3(0, 0.2, 0))
	_zoom_alvo = ZOOM_PONTA + 0.25
	await _esperar(0.8)
	if fim.has("legenda"):
		cinema.legenda(str(fim["legenda"]), 2.4)
	await _esperar(2.6)
	_cam_alvo = _iso3(d + Vector3(0, 1.5, 0))  # a câmera sobe até a Dama, que olha o grupo
	_zoom_alvo = ZOOM_DAMA
	await _esperar(2.2)
	await _retomar()


# Três tentáculos menores ondulando atrás da Dama, para ela não ser só um corpo com um braço.
func _extras(d: Vector3, h: Vector3, lado: Vector3) -> void:
	for k in 3:
		var u := float(k - 1)
		var base := d + Vector3(0, 1.8, 0) + lado * u * 0.3
		var pts: Array[Vector3] = [base, base + Vector3(0, 1.2, 0) - h * 0.3 + lado * u * 0.6, base + Vector3(0, 2.4 + 0.5 * k, 0) + lado * u * 1.4, base + Vector3(0, 3.4 + 0.4 * k, 0) + h * 0.5 + lado * u * 2.0]
		var t := Tentaculo3D.new()
		t.raio_base = 0.2
		t.raio_ponta = 0.07
		t.ondula = 0.4
		room.world3d.mundo.add_child(t)
		t.definir(pts)
		extras.append(t)
		var tw := create_tween()
		tw.tween_interval(0.25 * k)
		tw.tween_property(t, "crescimento", 1.0, 1.4).set_trans(Tween.TRANS_SINE)


# Poça de sangue que cresce sob o Fernando.
func _poca(f: Vector3) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
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
	create_tween().tween_property(mi, "scale", Vector3(1, 1, 1), 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Sangue, clarão vermelho e tranco da câmera no instante em que a ponta atravessa o peito.
func _impacto(f: Vector3) -> void:
	var fx: CombatFx = room.fx
	fx.shake_time = 0.7
	fx.shake_px = 11.0
	fx.flash_red = 0.5
	fx.flash_strength = 1.6
	fx.white[fernando] = 0.25
	var rng := RandomNumberGenerator.new()
	var ponto := _iso3(f + Vector3(0, 1.6, 0))
	for i in 34:
		fx.particles.append({"pos": ponto, "vel": Vector2(rng.randf_range(-70, 110), rng.randf_range(-130, 20)), "life": 0.9, "max": 0.9, "kind": "blood", "size": rng.randf_range(1.5, 3.5)})
	var ag: Agente3D = room.agentes.get(fernando)
	if ag:
		ag.levar_dano(Vector3(-sin(PI / 4.0), 0.0, -cos(PI / 4.0)))


# O combate continua (Léo, 15/11): o Fernando fica caído para sempre, as barras saem e a vez passa ao próximo.
# O fim do capítulo vem depois (Dama morta, Letícia, celeiro com a Ordem, cutscene fora do jogo): não é aqui.
func _retomar() -> void:
	fernando.pv = 0
	fernando.dead = true  # morto de verdade: o kit não o levanta e o corpo fica na cena
	Missao1.marcar("fernando_morreu")
	tentaculo.queue_free()
	for t in extras:
		t.queue_free()
	await cinema.sair(0.9)
	cinema.queue_free()
	var cam: Camera2D = room.camera
	cam.zoom = Vector2(_zoom_base, _zoom_base)
	cam.limit_left = _limites[0]
	cam.limit_top = _limites[1]
	cam.limit_right = _limites[2]
	cam.limit_bottom = _limites[3]
	if room.player == fernando:
		for m in room.party:
			if not m.dead and m.is_alive():
				room.player = m
				break
	room.mode = room.Mode.COMBAT
	room.busy = false
	Engine.time_scale = 2.0 if room.options.values["fast_combat"] else 1.0
	room.audio.on_combat_started()
	room.turns.state = TurnManager.State.ACTIVE
	room.turns._advance()  # segue a ordem normal: a Dama continua em ~20% e o grupo luta sem o Fernando
	terminou.emit()
	queue_free()
