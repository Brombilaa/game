class_name ChefeDama
extends RefCounted
# Luta da Dama de Sangue (sugestão 6 da revisão de 14/11; números do GDD #14 e provisórios do Claude).
# A sala (local3d.gd) cria este controle quando a Dama surge de Roberto Ghular e entrega a ele o turno dela.
#
#   - Fases por % de vida (inimigos.json, "fases"): a fase 2, abaixo de 50%, é anunciada na tela, dá +25% de dano
#     e encurta o intervalo da Maré de Sangue.
#   - Garra de Sangue (corpo a corpo, deixa sangrando) e Lança de Sangue (8 m): a Dama escolhe a que alcança.
#   - Maré de Sangue, o golpe avisado: num turno ela só marca um círculo no chão; no turno seguinte, quem ainda
#     estiver dentro leva o dano (sem rolagem de acerto) e fica sangrando. Dá tempo de sair.
#   - Chamado de Sangue: 3 PA, 2 cultistas surgem ao lado de um símbolo de pé (no máx. a cada N turnos dela).
#   - Símbolos de Sangue na arena: alvos sem turno. Cada um de pé dá +10% de defesa à Dama, e sem nenhum de pé
#     ela não consegue mais chamar cultistas.
# A morte do Fernando aos ~30% é da cena do fim (cena_tentaculo.gd), não daqui.

const ID := "dama_sangue"
const ESTILOS := ["A", "B", "C"]  # 3 modelos visuais para o Léo escolher (aviso de fase, círculo e símbolo)

static var estilo := "A"  # provisório até a escolha do Léo

var room  # sala de combate (local3d.gd); sem tipo para não criar dependência circular
var dama: Combatant
var hab := {}  # id -> habilidade da ficha
var fases: Array = []
var fase := 1
var turno := 0  # turnos da Dama já começados
var ultima_mare := -99
var ultimo_chamado := -99
var carga := {}  # Maré marcada: {"centro": Vector2, "raio": px}; vazio = nada avisado
var simbolos: Array[Combatant] = []
var base_defesa := 0.0
var nos := {}  # símbolo -> Node3D
var zona: Node3D  # círculo da Maré no chão (3D)
var _quebrados := {}  # símbolos cuja quebra já foi anunciada


func _init(owner_room, unit: Combatant, posicoes: Array = []) -> void:
	room = owner_room
	dama = unit
	var ficha: Dictionary = room.cfg.game_data.get_entry("inimigos", ID)
	for h in ficha.get("habilidades", []):
		hab[str(h["id"])] = h
	fases = (ficha.get("fases", []) as Array).duplicate()
	fases.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["fase"]) < int(b["fase"]))
	base_defesa = dama.defense
	for p in posicoes:
		_novo_simbolo(Vector2(float(p[0]), float(p[1])))
	_atualizar_defesa()


# --- Símbolos ------------------------------------------------------------------------------

func _novo_simbolo(at: Vector2) -> void:
	var h: Dictionary = hab.get("simbolos", {})
	var s := Combatant.new()
	s.name = str(h.get("nome", "Símbolo de Sangue"))
	s.side = Combatant.Side.ENEMY
	s.objeto = true
	s.behavior = "objeto"
	s.max_pv = int(h.get("pv", 10))
	s.pv = s.max_pv
	s.radius = room.cfg.value("enemy_radius")
	s.pos = _livre_perto(at, s.radius)
	s.weapon = room.cfg.weapon("garra_dama")  # nunca ataca; só para as contas que leem a arma de todo inimigo
	simbolos.append(s)
	room.enemies.append(s)
	var no := _simbolo3d()
	if no:
		no.position = _em3d(s.pos)
		nos[s] = no


func simbolos_de_pe() -> int:
	return simbolos.filter(func(s: Combatant) -> bool: return s.is_alive()).size()


func _atualizar_defesa() -> void:
	var cada := float((hab.get("simbolos", {}) as Dictionary).get("defesa_por_simbolo", 0.1))
	dama.defense = minf(base_defesa + cada * simbolos_de_pe(), 0.9)


# --- Fases ---------------------------------------------------------------------------------

func fase_atual() -> Dictionary:
	for f in fases:
		if int(f["fase"]) == fase:
			return f
	return {}


func dano_mult() -> float:
	return float(fase_atual().get("dano_mult", 1.0))


func intervalo_mare() -> int:
	return int(fase_atual().get("mare_intervalo", 3))


# Muda de fase quando a vida cai abaixo do limite (uma por vez, sempre para a frente); anuncia na tela.
func checar_fase() -> void:
	for f in fases:
		var n := int(f["fase"])
		if n > fase and dama.pv <= float(f["abaixo_de"]) * dama.max_pv and dama.is_alive():
			fase = n
			if f.get("registro") != null:
				room._log(str(f["registro"]))
			if f.get("texto") != null:
				anunciar(str(f["texto"]))


# Chamado pela sala a cada impacto (golpe do grupo ou da Dama).
func ao_impacto(alvo: Combatant) -> void:
	if alvo == dama:
		checar_fase()
	elif simbolos.has(alvo) and not alvo.is_alive() and not _quebrados.has(alvo):
		_quebrados[alvo] = true
		_atualizar_defesa()
		_quebrar3d(alvo)
		room._popup(alvo.pos, "QUEBRADO", "down")
		room._log("Um símbolo se parte. A Dama fica mais exposta (%d de pé)." % simbolos_de_pe())


# --- Turno da Dama -------------------------------------------------------------------------

func run_turn() -> void:
	room.busy = true
	turno += 1
	await _pausa()
	if not carga.is_empty():
		await _soltar_mare()
	elif _pode_chamar():
		await _chamar()
	elif _pode_marcar():
		_marcar_mare()
	var ai: EnemyAi = room.ai
	while room.mode == room.Mode.COMBAT and room.turns.is_turn_of(dama):
		await _pausa()
		if not room.turns.is_turn_of(dama):
			break
		var alvo := ai.pick_target(dama)
		if alvo == null:
			room.turns.end_turn()
			break
		var arma := _arma_para(alvo)
		if arma != "":
			_empunhar(arma)
			await _atacar(alvo)
			continue
		_empunhar("lanca")  # anda até ficar a meio alcance da Lança
		if not await ai.advance(dama, alvo):
			room.turns.end_turn()
	room.busy = false
	room.queue_redraw()


func _pausa() -> void:
	await room.get_tree().create_timer(room.cfg.value("enemy_step_seconds")).timeout


# Garra se alcança, senão Lança; "" quando nenhuma pode ser usada daqui (ou faltam PA).
func _arma_para(alvo: Combatant) -> String:
	for id in ["garra", "lanca"]:
		if not hab.has(id):
			continue
		_empunhar(id)
		if room.rules.attack_blocker(dama, alvo, room._sight_blockers(), room.covers) == "":
			return id
	return ""


# Arma da habilidade, com o dano da fase (a fase 2 bate 25% mais forte).
func _empunhar(id: String) -> void:
	var w: Dictionary = room.cfg.weapon(str(hab[id]["arma"]))
	var k := dano_mult()
	w["damage_min"] = int(round(int(w["damage_min"]) * k))
	w["damage_max"] = int(round(int(w["damage_max"]) * k))
	w["habilidade"] = id
	dama.weapon = w


func _atacar(alvo: Combatant) -> void:
	room.ai._note_attack(dama, alvo)
	var r: Dictionary = room.rules.attack(dama, alvo, room._sight_blockers(), room.covers)
	var cond := str(hab[str(dama.weapon["habilidade"])].get("condicao", ""))
	if r.get("hit", false) and cond != "" and alvo.is_alive():
		room.rules.apply_condition(alvo, cond)  # a Garra deixa sangrando (GDD #14)
	room._show_attack(dama, alvo, r)
	await _esperar_fx()
	room.turns.action_done()


func _esperar_fx() -> void:
	while room.fx.blocking() and room.mode == room.Mode.COMBAT:
		await room.get_tree().process_frame


# --- Chamado de Sangue ---------------------------------------------------------------------

func _pode_chamar() -> bool:
	var h: Dictionary = hab.get("chamado", {})
	if h.is_empty() or dama.pa < int(h["pa"]) or turno < int(h.get("primeiro", 1)):
		return false
	if turno - ultimo_chamado < int(h["intervalo"]):
		return false
	if bool(h.get("requer_simbolo", false)) and simbolos_de_pe() == 0:
		return false
	var em_campo := 0
	for e: Combatant in room.enemies:
		if e.is_alive() and not e.objeto and e != dama:
			em_campo += 1
	return em_campo + int(h["quantos"]) <= int(h.get("max_em_campo", 99))


func _chamar() -> void:
	var h: Dictionary = hab["chamado"]
	ultimo_chamado = turno
	room.turns.spend(dama, int(h["pa"]))
	room._log("%s: o sangue dos símbolos se ergue." % str(h["nome"]))
	room._popup(dama.pos, str(h["nome"]).to_upper(), "down")
	var fontes: Array[Combatant] = []
	for s in simbolos:
		if s.is_alive():
			fontes.append(s)
	if fontes.is_empty():
		fontes.append(dama)
	for i in int(h["quantos"]):
		var perto: Combatant = fontes[i % fontes.size()]
		var u: Combatant = room.cfg.make_enemy(str(h["invoca"]), _livre_perto(perto.pos + Vector2.from_angle(TAU * i / 3.0) * 28.0, room.cfg.value("enemy_radius")))
		u.perception = INF
		room.enemies.append(u)
		room.turns.add_unit(u)  # age no fim desta rodada e, depois, na ordem normal
		room._popup(u.pos, "SURGE", "info")
	room.fx.shake_time = 0.35
	room.fx.shake_px = 4.0
	room.queue_redraw()
	await room.get_tree().create_timer(0.6).timeout
	room.turns.action_done()


# --- Maré de Sangue (golpe avisado) --------------------------------------------------------

func _pode_marcar() -> bool:
	var h: Dictionary = hab.get("mare", {})
	if h.is_empty() or dama.pa < int(h.get("pa_carregar", 3)) or turno < int(h.get("primeiro", 1)):
		return false
	return turno - ultima_mare >= intervalo_mare() and _centro_mare() != Vector2.INF


func raio_mare() -> float:
	return float((hab.get("mare", {}) as Dictionary).get("raio_m", 2.5)) * room.cfg.value("pixels_per_meter")


# Onde marcar: no membro de pé que tem mais aliados dentro do raio (empate: o mais perto da Dama).
func _centro_mare() -> Vector2:
	var best := Vector2.INF
	var best_n := 0
	var best_d := INF
	var r := raio_mare()
	for m: Combatant in room.party:
		if not m.is_alive():
			continue
		var n := 0
		for o: Combatant in room.party:
			if o.is_alive() and o.pos.distance_to(m.pos) <= r:
				n += 1
		var d := m.pos.distance_to(dama.pos)
		if n > best_n or (n == best_n and d < best_d):
			best = m.pos
			best_n = n
			best_d = d
	return best


func _marcar_mare() -> void:
	var h: Dictionary = hab["mare"]
	ultima_mare = turno
	carga = {"centro": _centro_mare(), "raio": raio_mare()}
	room.turns.spend(dama, dama.pa)  # marcar gasta o turno inteiro
	room._log("%s. Saiam do círculo!" % str(h.get("aviso", "A Dama concentra o sangue")))
	room._popup(dama.pos, "MARÉ DE SANGUE", "crit")
	if dama.pos != carga["centro"]:
		room.facing8[dama] = CharacterSheet.dir_from_vector(room._iso(carga["centro"]) - room._iso(dama.pos))
	_mostrar_zona()
	room.queue_redraw()
	room.turns.end_turn()


# Quem ainda está dentro do círculo leva o dano, sem rolagem de acerto; a defesa (colete) reduz como sempre.
func _soltar_mare() -> void:
	var h: Dictionary = hab["mare"]
	var centro: Vector2 = carga["centro"]
	var raio: float = carga["raio"]
	carga = {}
	room.turns.spend(dama, mini(int(h.get("pa_soltar", 2)), dama.pa))
	room._popup(centro, "MARÉ DE SANGUE", "crit")
	room.fx.shake_time = 0.5
	room.fx.shake_px = 7.0
	var atingidos := 0
	for m: Combatant in room.party:
		if not m.is_alive() or m.pos.distance_to(centro) > raio + m.radius:
			continue
		atingidos += 1
		var dano := float(room.rules.rng.randi_range(int(h["dano"][0]), int(h["dano"][1]))) * dano_mult()
		var final: int = room.rules.damage_after_defense(dano, m.defense)
		m.take_damage(final)
		if m.is_alive() and h.get("condicao") != null:
			room.rules.apply_condition(m, str(h["condicao"]))
		room.hit_shake[m] = 0.35
		room._popup(m.pos, "-%d" % final, "crit")
		room._log("%s atinge %s: %d" % [str(h["nome"]), m.name, final])
		if not m.is_alive():
			room._popup(m.pos, "CAIU", "down")
			room._log("%s caiu" % m.name)
	if atingidos == 0:
		room._log("%s acerta o chão vazio." % str(h["nome"]))
	_esconder_zona()
	room.queue_redraw()
	await room.get_tree().create_timer(0.7).timeout
	room.turns.action_done()


# Fim do combate (vitória): símbolos e o círculo somem.
func encerrar() -> void:
	carga = {}
	_esconder_zona()
	for s in simbolos:
		room.enemies.erase(s)


# --- Visual (3 modelos; ver ESTILOS) -------------------------------------------------------

func _mundo() -> Node:
	if room.world3d == null or not ("mundo" in room.world3d) or room.world3d.mundo == null:
		return null
	return room.world3d.mundo


func _em3d(p: Vector2) -> Vector3:
	return Vector3(p.x / 64.0, room._altura(p), p.y / 64.0)


func _livre_perto(at: Vector2, raio: float) -> Vector2:
	var obst: Array[Rect2] = room._obstacles(null)
	if Pathfinder.is_free(at, obst, raio):
		return at
	for ring in range(1, 20):
		for k in 12:
			var p := at + Vector2.from_angle(TAU * k / 12.0) * ring * 8.0
			if Pathfinder.is_free(p, obst, raio):
				return p
	return at


static func _mat(cor: Color, brilho := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.9
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m


static func _peca(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


const PEDRA := Color(0.16, 0.13, 0.12)
const SANGUE := Color(0.62, 0.04, 0.05)


# A: estaca de pedra com uma faixa de glifos em brasa. B: pedestal baixo com um coração de sangue flutuando.
# C: círculo de giz no chão (sem brilho) com três velas.
func _simbolo3d() -> Node3D:
	var mundo := _mundo()
	if mundo == null:
		return null
	var n := Node3D.new()
	n.name = "SimboloSangue"
	match estilo:
		"A":
			var b := BoxMesh.new()
			b.size = Vector3(0.34, 1.5, 0.34)
			n.add_child(_peca(b, _mat(PEDRA), Vector3(0, 0.75, 0)))
			var faixa := BoxMesh.new()
			faixa.size = Vector3(0.37, 0.14, 0.37)
			var brasa := _peca(faixa, _mat(SANGUE, 2.2), Vector3(0, 1.05, 0))
			brasa.name = "brilho"
			n.add_child(brasa)
			var ponta := PrismMesh.new()
			ponta.size = Vector3(0.34, 0.3, 0.34)
			var topo := _peca(ponta, _mat(PEDRA), Vector3(0, 1.65, 0))
			topo.name = "topo"
			n.add_child(topo)
		"B":
			var ped := CylinderMesh.new()
			ped.top_radius = 0.26
			ped.bottom_radius = 0.34
			ped.height = 0.6
			n.add_child(_peca(ped, _mat(PEDRA), Vector3(0, 0.3, 0)))
			var esf := SphereMesh.new()
			esf.radius = 0.2
			esf.height = 0.4
			var coracao := _peca(esf, _pulso(), Vector3(0, 0.98, 0))
			coracao.name = "brilho"
			n.add_child(coracao)
		_:
			var disco := PlaneMesh.new()
			disco.size = Vector2(1.9, 1.9)
			var circ := _peca(disco, _runa_chao(), Vector3(0, 0.03, 0))
			circ.name = "disco"
			n.add_child(circ)
			for k in 3:
				var vela := CylinderMesh.new()
				vela.top_radius = 0.035
				vela.bottom_radius = 0.04
				vela.height = 0.22
				var a := TAU * k / 3.0 + 0.5
				var at := Vector3(cos(a) * 0.8, 0.11, sin(a) * 0.8)
				n.add_child(_peca(vela, _mat(Color(0.78, 0.72, 0.6)), at))
				var chama := SphereMesh.new()
				chama.radius = 0.03
				chama.height = 0.07
				var f := _peca(chama, _mat(Color(1.0, 0.65, 0.25), 4.0), at + Vector3(0, 0.15, 0))
				f.name = "chama%d" % k
				n.add_child(f)
	mundo.add_child(n)
	return n


func _quebrar3d(s: Combatant) -> void:
	var n: Node3D = nos.get(s)
	if n == null:
		return
	match estilo:
		"A":  # a estaca parte no meio e apaga
			for c in n.get_children():
				if c.name == "brilho" or c.name == "topo":
					c.visible = false
				elif c is MeshInstance3D:
					c.scale = Vector3(1, 0.4, 1)
					c.position.y = 0.3
					c.rotation.z = 0.25
		"B":  # o coração estoura: fica uma poça
			for c in n.get_children():
				if c.name == "brilho":
					c.visible = false
			var poca := CylinderMesh.new()
			poca.top_radius = 0.55
			poca.bottom_radius = 0.55
			poca.height = 0.01
			n.add_child(_peca(poca, _mat(Color(0.3, 0.02, 0.02)), Vector3(0, 0.02, 0)))
		_:  # o círculo se apaga (fica escuro) e as velas morrem
			for c in n.get_children():
				if c.name.begins_with("chama"):
					c.visible = false
				elif c.name == "disco":
					(c.material_override as ShaderMaterial).set_shader_parameter("apagado", 1.0)


func _pulso() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
void fragment() {
	float p = 0.65 + 0.35 * sin(TIME * 3.0);
	ALBEDO = vec3(0.75, 0.04, 0.05) * (0.8 + 0.6 * p);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _runa_chao() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform float apagado = 0.0;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float anel = smoothstep(0.06, 0.0, abs(r - 0.86)) + smoothstep(0.04, 0.0, abs(r - 0.66));
	float glifo = step(0.5, fract(a * 3.8197)) * step(0.7, r) * step(r, 0.82) * step(0.35, fract(r * 9.0));
	float estrela = smoothstep(0.035, 0.0, abs(c.x * cos(1.2566) + c.y * sin(1.2566) - 0.2)) * step(r, 0.66);
	estrela += smoothstep(0.035, 0.0, abs(c.x * cos(-1.2566) + c.y * sin(-1.2566) - 0.2)) * step(r, 0.66);
	estrela += smoothstep(0.035, 0.0, abs(c.y + 0.2)) * step(r, 0.66);
	float m = clamp(anel + glifo * 0.8 + estrela, 0.0, 1.0) * step(r, 1.0);
	ALBEDO = mix(vec3(0.86, 0.82, 0.72), vec3(0.12, 0.1, 0.09), apagado);  // giz e cinza: contrasta com o anel vermelho do chão
	ROUGHNESS = 1.0;
	ALPHA = m * mix(0.9, 0.55, apagado);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = 12
	return m


# Círculo da Maré no chão. A: poça vermelha que pulsa. B: anel de runas girando, sem preenchimento.
# C: hachura em diagonal com borda tracejada.
func _mostrar_zona() -> void:
	_esconder_zona()
	var mundo := _mundo()
	if mundo == null:
		return
	var r: float = carga["raio"] / 64.0
	var plano := PlaneMesh.new()
	plano.size = Vector2(r * 2.0, r * 2.0)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform int estilo = 0;
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float a = atan(c.y, c.x);
	float dentro = step(r, 1.0);
	float p = 0.5 + 0.5 * sin(TIME * 4.0);
	vec3 cor = vec3(0.85, 0.06, 0.06);
	float alfa = 0.0;
	if (estilo == 0) {
		alfa = (0.22 + 0.18 * p) * dentro + smoothstep(0.05, 0.0, abs(r - 0.97)) * 0.95;
	} else if (estilo == 1) {
		float seg = step(0.45, fract(a * 2.546 + TIME * 0.35));
		alfa = smoothstep(0.09, 0.0, abs(r - 0.92)) * seg;
		alfa += smoothstep(0.035, 0.0, abs(r - 0.78)) * 0.9;
		alfa += 0.12 * dentro * p;
		float runa = step(0.6, fract(a * 6.366 - TIME * 0.2)) * step(0.8, r) * step(r, 0.88);
		alfa += runa * 0.8;
	} else {
		float hach = step(0.5, fract((c.x + c.y) * 5.0 - TIME * 0.6));
		alfa = hach * 0.5 * dentro;
		float tra = step(0.5, fract(a * 4.775));
		alfa += smoothstep(0.06, 0.0, abs(r - 0.96)) * tra;
		cor = vec3(0.95, 0.25, 0.12);
	}
	ALBEDO = cor;
	ALPHA = clamp(alfa, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("estilo", ESTILOS.find(estilo))
	m.render_priority = 12  # depois do quadro da névoa (que só enxerga o opaco), como os decalques das pistas
	zona = _peca(plano, m, _em3d(carga["centro"]) + Vector3(0, 0.05, 0))
	zona.name = "ZonaMare"
	mundo.add_child(zona)


func _esconder_zona() -> void:
	if zona and is_instance_valid(zona):
		zona.queue_free()
	zona = null


# Os símbolos criados antes de o cenário 3D existir (volta de um save) ganham o objeto quando ele aparece.
func _garantir_3d() -> void:
	if _mundo() == null:
		return
	for s in simbolos:
		if not nos.has(s):
			var no := _simbolo3d()
			no.position = _em3d(s.pos)
			nos[s] = no
			if not s.is_alive():
				_quebrar3d(s)


# Sala sem 3D (testes, sala de teste): o círculo é desenhado no plano, pela sala.
func desenhar_2d(canvas: CanvasItem) -> void:
	_garantir_3d()
	if carga.is_empty() or zona != null:
		return
	var c: Vector2 = room._iso(carga["centro"])
	var r: float = carga["raio"]
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * r * 1.414, sin(a) * r * 0.707))
	canvas.draw_polyline(pts, Color(0.85, 0.06, 0.06, 0.9), 2.0)


# Aviso de fase na tela. A: faixa vermelha no meio com o texto grande. B: clarão vermelho nas bordas e texto
# no terço de cima, com tremor. C: linha pequena de máquina de escrever logo abaixo da ordem dos turnos.
func anunciar(texto: String) -> void:
	var camada := CanvasLayer.new()
	camada.layer = 70
	room.add_child(camada)
	var tela: Vector2 = room.get_viewport_rect().size
	var fonte: Font = room.POPUP_FONT
	var t: Tween = room.create_tween()
	match estilo:
		"A":
			var faixa := ColorRect.new()
			faixa.color = Color(0.32, 0.02, 0.03, 0.88)
			faixa.position = Vector2(0, tela.y * 0.5 - 46)
			faixa.size = Vector2(tela.x, 92)
			camada.add_child(faixa)
			var l := _rotulo(texto, fonte, 44, Color(0.96, 0.9, 0.82))
			l.position = Vector2(0, tela.y * 0.5 - 30)
			l.size = Vector2(tela.x, 60)
			camada.add_child(l)
			for n in [faixa, l]:
				n.modulate.a = 0.0
			t.tween_property(faixa, "modulate:a", 1.0, 0.25)
			t.parallel().tween_property(l, "modulate:a", 1.0, 0.25)
			t.tween_interval(2.0)
			t.tween_property(faixa, "modulate:a", 0.0, 0.6)
			t.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
		"B":
			var veu := TextureRect.new()
			veu.texture = _vinheta()
			veu.stretch_mode = TextureRect.STRETCH_SCALE
			veu.size = tela
			camada.add_child(veu)
			var l := _rotulo(texto, fonte, 56, Color(1.0, 0.86, 0.8))
			l.add_theme_color_override("font_outline_color", Color(0.35, 0.0, 0.0))
			l.add_theme_constant_override("outline_size", 10)
			l.position = Vector2(0, tela.y * 0.24)
			l.size = Vector2(tela.x, 80)
			camada.add_child(l)
			room.fx.shake_time = 0.6
			room.fx.shake_px = 8.0
			l.modulate.a = 0.0
			t.tween_property(l, "modulate:a", 1.0, 0.15)
			t.tween_interval(1.8)
			t.tween_property(veu, "modulate:a", 0.0, 0.9)
			t.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
		_:
			var l := _rotulo("", fonte, 24, Color(0.93, 0.86, 0.76))
			l.position = Vector2(0, 132)
			l.size = Vector2(tela.x, 34)
			camada.add_child(l)
			var linha := ColorRect.new()
			linha.color = Color(0.6, 0.08, 0.06, 0.9)
			linha.position = Vector2(tela.x * 0.5 - 220, 168)
			linha.size = Vector2(440, 2)
			camada.add_child(linha)
			for i in texto.length() + 1:
				t.tween_callback(func() -> void: l.text = texto.substr(0, i)).set_delay(0.035)
			t.tween_interval(2.4)
			t.tween_property(l, "modulate:a", 0.0, 0.6)
			t.parallel().tween_property(linha, "modulate:a", 0.0, 0.6)
	t.tween_callback(camada.queue_free)


static func _rotulo(texto: String, fonte: Font, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _vinheta() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.0, 0.0, 0.0))
	g.set_color(1, Color(0.6, 0.0, 0.02, 0.6))
	g.set_offset(0, 0.6)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	return tex
