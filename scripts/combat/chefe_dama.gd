class_name ChefeDama
extends RefCounted
# Luta da Dama de Sangue (Léo, 20/11/2026: roteiro-missao1.md seção 5c, tabela das sete flores e decisões da luta).
# A sala (local3d.gd) cria este controle quando a Dama surge de Roberto Ghular e entrega a ele o turno dela.
#
#   Fase 1: a Dama devora um pendurado por rodada, do mais jovem ao mais velho, desde que surge. Devorar é o turno
#     inteiro: abre a próxima flor da tabela (Laranja, Rosa, Roxa, Amarela, Verde, Azul), usa a habilidade dela e a
#     flor fica vulnerável até o começo do próximo turno da Dama. A Vermelha já nasce aberta (e vulnerável).
#   Cada pendurado é seguro por um tentáculo atacável: destruído antes do turno em que ele seria devorado, o corpo é
#     salvo e nenhuma flor abre naquela rodada (a Dama só ataca).
#   A flor murcha só com a mecânica dela (corte, fertilizante, bulbo, fogo, água, energia, agrotóxico). Murcha, a
#     Dama perde a habilidade da flor e um bônus da ficha (PV máximos, acerto, dano, defesa, resistências).
#   Fase 2: quando os corpos acabam (ou a Dama cai a 50%), todas as flores de pé se abrem e ficam vulneráveis; ela
#     usa uma habilidade por turno, em rodízio, e bate 25% mais forte. Sem habilidade que alcance, pancada ou espinhos.
# A Dama não sai do altar (é o corpo de Roberto que a sustenta): provisório do Claude.
# A morte do Fernando com a Dama em 15% é da sala (local3d.gd) e da cena do tentáculo (cena_tentaculo.gd).
# Números em data/dama_sangue.json; o visual (3 modelos) em DamaVisual.

const ID := "dama_sangue"
const ARQUIVO := "res://data/dama_sangue.json"
const RAIO_FLORES := 52.0  # px do centro da Dama até cada flor (provisório)

var room  # sala de combate (local3d.gd); sem tipo para não criar dependência circular
var dama: Combatant
var d := {}  # data/dama_sangue.json
var fase := 1
var turno := 0  # turnos da Dama já começados
var turnos_fase1 := 0  # turnos da fase 1: o N-ésimo é o do N-ésimo pendurado
var flores: Array[Dictionary] = []  # {dados, unit: Combatant ou null (fechada), estado: fechada/aberta/murcha}
var corpos: Array[Dictionary] = []  # {nome, pos, tentaculo: Combatant, estado: pendurado/devorado/salvo}
var prisoes := {}  # tentáculo da Prisão -> quem ele prende
var bonus := {}  # bônus que a Dama ainda tem (acerto_corpo, acerto_distancia, atributos, resistencias)
var rodizio := 0  # próxima habilidade da fase 2
var visual: DamaVisual
var _avisados := {}  # unidades cuja queda já foi tratada


func _init(owner_room, unit: Combatant, posicoes_corpos: Array = []) -> void:
	room = owner_room
	dama = unit
	d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	var b: Dictionary = d["bonus_base"]
	bonus = {"acerto_corpo": float(b["acerto_corpo"]), "acerto_distancia": float(b["acerto_distancia"]), "atributos": true, "resistencias": true}
	dama.buffs["flor_roxa"] = {"rounds": 9999, "defesa": 0.0, "dano": int(b["atributos_dano"])}  # Atributos: +1 de dano
	visual = DamaVisual.criar(room, self)
	var n := 0
	for f in d["flores"]:
		flores.append({"dados": f, "unit": null, "estado": "fechada", "indice": n})
		n += 1
	var nomes: Array = d["corpos"]["nomes"]
	for i in mini(nomes.size(), posicoes_corpos.size()):
		var p: Array = posicoes_corpos[i]
		_novo_corpo(str(nomes[i]), Vector2(float(p[0]), float(p[1])))
	for f in flores:
		if f["dados"].get("nasce_aberta", false):
			_abrir(f, true)
	_atualizar_alvos()


# --- Peças: corpos, flores, tentáculos ------------------------------------------------------------

func _objeto(nome: String, pv: int, at: Vector2, defesa := 0.0) -> Combatant:
	var u := Combatant.new()
	u.name = nome
	u.side = Combatant.Side.ENEMY
	u.objeto = true
	u.behavior = "objeto"
	u.max_pv = pv
	u.pv = pv
	u.defense = defesa
	u.looted = true  # nada para saquear
	u.radius = room.cfg.value("enemy_radius")
	u.pos = at
	u.weapon = room.cfg.weapon("pancada_dama")  # nunca ataca; só para as contas que leem a arma de todo inimigo
	room.enemies.append(u)
	return u


func _novo_corpo(nome: String, at: Vector2) -> void:
	var c := {"nome": nome, "pos": at, "estado": "pendurado"}
	c["tentaculo"] = _objeto("Tentáculo (%s)" % nome, int(d["corpos"]["tentaculo_pv"]), at, float(d["corpos"]["tentaculo_defesa"]))
	corpos.append(c)
	visual.corpo_criar(c)


# Posição da flor `i` (0 a 6) na coroa em volta da Dama.
func pos_flor(i: int) -> Vector2:
	return dama.pos + Vector2.from_angle(-PI / 2.0 + TAU * i / 7.0) * RAIO_FLORES


func _abrir(f: Dictionary, vulneravel: bool) -> void:
	if f["estado"] != "fechada":
		return
	var fd: Dictionary = f["dados"]
	var u := _objeto("Flor %s" % str(fd["cor"]).to_lower(), int(fd["pv"]), pos_flor(int(f["indice"])))
	u.aceita = (fd["aceita"] as Array).duplicate()
	u.protegido = not vulneravel
	f["unit"] = u
	f["estado"] = "aberta"
	visual.flor_abrir(f)


func flor_de(u: Combatant) -> Dictionary:
	for f in flores:
		if f["unit"] == u:
			return f
	return {}


func corpo_de(u: Combatant) -> Dictionary:
	for c in corpos:
		if c["tentaculo"] == u:
			return c
	return {}


func flores_vivas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in flores:
		if f["estado"] == "aberta":
			out.append(f)
	return out


func murchas() -> int:
	return flores.filter(func(f: Dictionary) -> bool: return f["estado"] == "murcha").size()


# A sala desenha a barra de vida só dos alvos que dá para ferir agora.
func _atualizar_alvos() -> void:
	for f in flores:
		if f["unit"] != null:
			visual.flor_janela(f, f["estado"] == "aberta" and not (f["unit"] as Combatant).protegido)


# --- Reações (impacto de golpe, ritual ou item) ---------------------------------------------------

# Chamado pela sala depois de cada golpe, ritual ou item. Trata flor murcha, corpo salvo, prisão quebrada e a fase 2.
func ao_impacto(alvo: Combatant) -> void:
	if alvo == null or alvo.is_alive() or _avisados.has(alvo):
		if alvo == dama:
			_checar_fase2_por_vida()
		return
	var f := flor_de(alvo)
	if not f.is_empty():
		_avisados[alvo] = true
		_murchar(f)
		return
	var c := corpo_de(alvo)
	if not c.is_empty() and c["estado"] == "pendurado":
		_avisados[alvo] = true
		c["estado"] = "salvo"
		visual.corpo_salvo(c)
		room._popup(c["pos"], "SALVO", "heal")
		room._log("O tentáculo se parte e %s cai no chão, vivo." % c["nome"])
		return
	if prisoes.has(alvo):
		_avisados[alvo] = true
		_soltar(alvo)


func _murchar(f: Dictionary) -> void:
	var fd: Dictionary = f["dados"]
	f["estado"] = "murcha"
	var perde: Dictionary = fd["perde"]
	var o_que: Array[String] = []
	if perde.has("pv_max"):
		dama.max_pv = maxi(dama.max_pv - int(perde["pv_max"]), 1)
		dama.pv = mini(dama.pv, dama.max_pv)
		o_que.append("%d de PV máximo" % int(perde["pv_max"]))
	if perde.has("acerto_corpo"):
		bonus["acerto_corpo"] = 0.0
		o_que.append("força nos golpes")
	if perde.has("acerto_distancia"):
		bonus["acerto_distancia"] = 0.0
		o_que.append("pontaria")
	if perde.has("atributos"):
		bonus["atributos"] = false
		dama.buffs.erase("flor_roxa")
		o_que.append("vigor")
	if perde.has("defesa"):
		dama.defense = maxf(dama.defense - float(perde["defesa"]), 0.0)
		o_que.append("defesa")
	if perde.has("resistencias"):
		bonus["resistencias"] = false
		dama.sem_resistencias = true
		o_que.append("as resistências")
	var hab: Dictionary = d["habilidades"][fd["habilidade"]]
	visual.flor_murchar(f)
	room._popup((f["unit"] as Combatant).pos, "MURCHOU", "crit")
	room._log("A flor %s murcha. A Dama perde %s e %s." % [str(fd["cor"]).to_lower(), str(hab["nome"]), ", ".join(o_que)])
	visual.anunciar("A FLOR %s MURCHA" % str(fd["cor"]).to_upper(), Color(fd["rgb"][0], fd["rgb"][1], fd["rgb"][2]), false)
	room.audio.play_sfx("enemy_spotted")
	room.queue_redraw()


func _checar_fase2_por_vida() -> void:
	if fase == 1 and dama.is_alive() and dama.pv <= float(d["fase2"]["abaixo_de"]) * dama.max_pv:
		_entrar_fase2()


func _entrar_fase2() -> void:
	if fase == 2:
		return
	fase = 2
	for f in flores:
		if f["estado"] == "fechada":
			_abrir(f, true)
		elif f["estado"] == "aberta":
			(f["unit"] as Combatant).protegido = false
	_atualizar_alvos()
	room._log(str(d["fase2"]["registro"]))
	visual.anunciar(str(d["fase2"]["texto"]), Color(0.75, 0.05, 0.08), true)
	room.fx.shake_time = 0.5
	room.fx.shake_px = 6.0
	room.queue_redraw()


func dano_mult() -> float:
	return float(d["fase2"]["dano_mult"]) if fase == 2 else 1.0


# --- Turno da Dama -------------------------------------------------------------------------------

func run_turn() -> void:
	room.busy = true
	turno += 1
	_limpar_prisoes()
	if fase == 1:  # a janela da flor aberta no turno anterior fecha (a Vermelha fica aberta)
		for f in flores_vivas():
			if not f["dados"].get("nasce_aberta", false):
				(f["unit"] as Combatant).protegido = true
		_atualizar_alvos()
		_checar_fase2_por_vida()
	if fase == 1 and turnos_fase1 >= corpos.size():
		_entrar_fase2()
	await _pausa()
	if fase == 1:
		var c: Dictionary = corpos[turnos_fase1]
		turnos_fase1 += 1
		if c["estado"] == "pendurado":
			await _devorar(c)
		else:
			room._log("%s foi salvo: a Dama não tem o que devorar nesta rodada." % c["nome"])
			await _ataques_basicos()
	elif room.turns.is_turn_of(dama):
		var h := _escolher_habilidade()
		if h != "":
			room.turns.spend(dama, mini(int(d["pa_habilidade"]), dama.pa))
			await _usar(h)
		await _ataques_basicos()
	if room.turns.is_turn_of(dama):
		room.turns.end_turn()
	room.busy = false
	room.queue_redraw()


func _pausa(s := -1.0) -> void:
	await room.get_tree().create_timer(s if s > 0.0 else room.cfg.value("enemy_step_seconds")).timeout


func _devorar(c: Dictionary) -> void:
	c["estado"] = "devorado"
	var t: Combatant = c["tentaculo"]
	t.pv = 0
	_avisados[t] = true
	room.turns.spend(dama, mini(int(d["fase1"]["pa_devorar"]), dama.pa))
	visual.corpo_devorado(c)
	room._popup(c["pos"], "DEVORADO", "down")
	room.fx.shake_time = 0.4
	room.fx.shake_px = 5.0
	var proxima: Dictionary = {}
	for f in flores:
		if f["estado"] == "fechada":
			proxima = f
			break
	if proxima.is_empty():
		room._log("A Dama devora %s." % c["nome"])
		await _pausa(0.6)
		return
	_abrir(proxima, true)
	_atualizar_alvos()
	var fd: Dictionary = proxima["dados"]
	var hab: Dictionary = d["habilidades"][fd["habilidade"]]
	room._log("A Dama devora %s. Abre-se a flor %s: %s." % [c["nome"], str(fd["cor"]).to_lower(), hab["nome"]])
	room._log(str(fd["dica"]))
	visual.anunciar("FLOR %s · %s" % [str(fd["cor"]).to_upper(), str(hab["nome"]).to_upper()], Color(fd["rgb"][0], fd["rgb"][1], fd["rgb"][2]), false)
	await _pausa(0.8)
	await _usar(str(fd["habilidade"]))


# Fase 2: a próxima habilidade (rodízio na ordem da tabela) de flor viva que tenha alvo agora.
func _escolher_habilidade() -> String:
	var vivas := flores_vivas()
	if vivas.is_empty() or dama.pa < int(d["pa_habilidade"]):
		return ""
	for k in vivas.size():
		var f: Dictionary = vivas[(rodizio + k) % vivas.size()]
		var h := str(f["dados"]["habilidade"])
		if _tem_alvo(h):
			rodizio = (rodizio + k + 1) % maxi(vivas.size(), 1)
			return h
	return ""


func _px(m: float) -> float:
	return m * room.cfg.value("pixels_per_meter")


func _de_pe() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for m: Combatant in room.party:
		if m.is_alive() and not m.dead:
			out.append(m)
	return out


func _mais_perto(alcance_m: float, sem_preso := false) -> Combatant:
	var best: Combatant = null
	for m in _de_pe():
		if sem_preso and m.has_condition("preso"):
			continue
		if CombatRules.gap(dama, m) > _px(alcance_m):
			continue
		if best == null or dama.pos.distance_to(m.pos) < dama.pos.distance_to(best.pos):
			best = m
	return best


# Ponto (um membro do grupo ao alcance) que junta mais gente no raio. Vector2.INF se ninguém ao alcance.
func _melhor_ponto(alcance_m: float, raio_m: float) -> Vector2:
	var best := Vector2.INF
	var best_n := 0
	for m in _de_pe():
		if CombatRules.gap(dama, m) > _px(alcance_m):
			continue
		var n := 0
		for o in _de_pe():
			if o.pos.distance_to(m.pos) <= _px(raio_m) + o.radius:
				n += 1
		if n > best_n:
			best_n = n
			best = m.pos
	return best


func _tem_alvo(id: String) -> bool:
	var h: Dictionary = d["habilidades"][id]
	match str(h["alvo"]):
		"um":
			return _mais_perto(float(h["alcance_m"]), id == "prisao_tentaculos") != null
		"em_volta":
			return _mais_perto(float(h["raio_m"])) != null
		"cone":
			return _mais_perto(float(h["alcance_m"])) != null
		"ponto":
			return _melhor_ponto(float(h["alcance_m"]), float(h["raio_m"])) != Vector2.INF
	return false


func _dano(h: Dictionary) -> int:
	var v := float(room.rules.rng.randi_range(int(h["dano"][0]), int(h["dano"][1])))
	if bonus["atributos"]:
		v += float(d["bonus_base"]["atributos_dano"])
	return int(round(v * dano_mult()))


# Dano sem rolagem de acerto (habilidade): a defesa (colete) reduz como sempre.
func _ferir(m: Combatant, bruto: int, nome: String) -> void:
	var final: int = room.rules.damage_after_defense(float(bruto), m.defense_total())
	m.take_damage(final)
	room.hit_shake[m] = 0.35
	room._popup(m.pos, "-%d" % final, "crit")
	room._log("%s atinge %s: %d" % [nome, m.name, final])
	if not m.is_alive():
		room._popup(m.pos, "CAIU", "down")
		room._log("%s caiu" % m.name)
		room.room_combat._san_report(room.san.ally_down(m, room.party), "vê %s cair" % m.name)


func _san(m: Combatant, quanto: int, nome: String) -> void:
	room.room_combat._san_report({m: room.san.lose(m, quanto, true)}, "sofre %s" % nome)


func _cond(m: Combatant, id: String) -> void:
	if m.is_alive():
		room.rules.apply_condition(m, id)
		room._popup(m.pos, str(room.cfg.condition(id)["nome"]).to_upper(), "info")


func _usar(id: String) -> void:
	var h: Dictionary = d["habilidades"][id]
	var nome := str(h["nome"])
	room._popup(dama.pos, nome.to_upper(), "crit")
	visual.habilidade(id)
	var alvos: Array[Combatant] = []
	match id:
		"visao_macabra":
			var m := _mais_perto(float(h["alcance_m"]))
			if m:
				_virar(m.pos)
				_san(m, int(h["san"]), nome)
				alvos.append(m)
		"agarrar_arremessar":
			var m := _mais_perto(float(h["alcance_m"]))
			if m:
				_virar(m.pos)
				_ferir(m, _dano(h), nome)
				_arremessar(m, _px(float(h["arremesso_m"])))
				_cond(m, str(h["condicao"]))
				alvos.append(m)
		"grito_confusao":
			for m in _de_pe():
				if CombatRules.gap(dama, m) <= _px(float(h["raio_m"])):
					_san(m, int(h["san"]), nome)
					_cond(m, str(h["condicao"]))
					alvos.append(m)
		"espinhos_sangue":
			var mira := _mais_perto(float(h["alcance_m"]))
			if mira:
				_virar(mira.pos)
				var eixo := (mira.pos - dama.pos).normalized()
				for m in _de_pe():
					var v := m.pos - dama.pos
					if CombatRules.gap(dama, m) <= _px(float(h["alcance_m"])) and (v.length() < 1.0 or absf(eixo.angle_to(v)) <= deg_to_rad(float(h["angulo_graus"]) * 0.5)):
						_ferir(m, _dano(h), nome)
						_cond(m, str(h["condicao"]))
						alvos.append(m)
				visual.cone(dama.pos, eixo, _px(float(h["alcance_m"])), deg_to_rad(float(h["angulo_graus"])))
		"prisao_tentaculos":
			var m := _mais_perto(float(h["alcance_m"]), true)
			if m:
				_virar(m.pos)
				_cond(m, str(h["condicao"]))
				m.preso = true  # já não anda no turno que vem nem neste, se for o dele
				var t := _objeto("Tentáculo da prisão", int(h["tentaculo_pv"]), m.pos + (dama.pos - m.pos).normalized() * (m.radius * 2.2))
				prisoes[t] = m
				visual.prisao_criar(t, m)
				alvos.append(m)
		"miasma_fetido", "chuva_sangue":
			var p := _melhor_ponto(float(h["alcance_m"]), float(h["raio_m"]))
			if p != Vector2.INF:
				_virar(p)
				visual.zona(p, _px(float(h["raio_m"])), id)
				for m in _de_pe():
					if m.pos.distance_to(p) <= _px(float(h["raio_m"])) + m.radius:
						if h.has("dano"):
							_ferir(m, _dano(h), nome)
						_cond(m, str(h["condicao"]))
						alvos.append(m)
	if alvos.is_empty():
		room._log("%s não alcança ninguém." % nome)
	room.queue_redraw()
	await _pausa(0.7)


func _virar(p: Vector2) -> void:
	if p != dama.pos:
		room.facing8[dama] = CharacterSheet.dir_from_vector(room._iso(p) - room._iso(dama.pos))


# Agarrar e Arremessar: joga o alvo a `dist` px, para longe da Dama, no ponto livre mais perto disso.
func _arremessar(m: Combatant, dist: float) -> void:
	var dir := (m.pos - dama.pos).normalized() if m.pos != dama.pos else Vector2.RIGHT
	var alvo := m.pos + dir * dist
	var obst: Array[Rect2] = room._obstacles(m)
	var spot := alvo
	if not Pathfinder.is_free(spot, obst, m.radius):
		spot = m.pos
		var best := INF
		for ring in range(1, 14):
			for k in 16:
				var q := alvo + Vector2.from_angle(TAU * k / 16.0) * ring * 8.0
				if Pathfinder.is_free(q, obst, m.radius) and q.distance_to(alvo) < best:
					best = q.distance_to(alvo)
					spot = q
			if best < INF:
				break
	m.pos = spot
	room._popup(m.pos, "ARREMESSADO", "info")


func _soltar(t: Combatant) -> void:
	var m: Combatant = prisoes[t]
	prisoes.erase(t)
	room.rules.remove_condition(m, "preso")
	m.preso = false
	t.pv = 0
	room.enemies.erase(t)
	visual.prisao_fim(t)
	room._popup(m.pos, "SOLTO", "heal")
	room._log("%s se solta dos tentáculos." % m.name)


# Prisões que acabaram sozinhas (a condição venceu) ou cujo preso caiu: o tentáculo volta para a terra.
func _limpar_prisoes() -> void:
	for t: Combatant in prisoes.keys():
		var m: Combatant = prisoes[t]
		if not m.has_condition("preso") or not m.is_alive():
			_soltar(t)


# Pancada (até 2 m) se alguém está encostado; senão espinhos (8 m). A Dama não sai do lugar.
func _ataques_basicos() -> void:
	while room.mode == room.Mode.COMBAT and room.turns.is_turn_of(dama) and dama.pa > 0:
		var feito := false
		for arma in ["pancada_dama", "espinhos_dama"]:
			_empunhar(arma)
			var alvo := _alvo_basico()
			if alvo != null:
				await _atacar(alvo)
				feito = true
				break
		if not feito:
			break
		await _pausa()


func _alvo_basico() -> Combatant:
	var best: Combatant = null
	for m in _de_pe():
		if room.rules.attack_blocker(dama, m, room._sight_blockers(), room.covers) != "":
			continue
		if best == null or dama.pos.distance_to(m.pos) < dama.pos.distance_to(best.pos):
			best = m
	return best


# Arma do ataque básico com os bônus que a Dama ainda tem (acerto e dano da fase).
func _empunhar(id: String) -> void:
	var w: Dictionary = room.cfg.weapon(id)
	var k := dano_mult()
	w["damage_min"] = int(round(int(w["damage_min"]) * k))
	w["damage_max"] = int(round(int(w["damage_max"]) * k))
	dama.weapon = w
	var acerto := float(bonus["acerto_corpo"] if w["melee"] else bonus["acerto_distancia"])
	if bonus["atributos"]:
		acerto += float(d["bonus_base"]["atributos_acerto"])
	dama.hit_bonus = acerto


func _atacar(alvo: Combatant) -> void:
	room.ai._note_attack(dama, alvo)
	var r: Dictionary = room.rules.attack(dama, alvo, room._sight_blockers(), room.covers)
	if r.get("hit", false) and alvo.is_alive() and str(dama.weapon["id"]) == "espinhos_dama" and room.rules.rng.randf() < 0.25:
		room.rules.apply_condition(alvo, "sangrando")  # disparar espinhos: 25% de sangrar (provisório)
	room._show_attack(dama, alvo, r)
	while room.fx.blocking() and room.mode == room.Mode.COMBAT:
		await room.get_tree().process_frame
	room.turns.action_done()


# Fim do combate (vitória): as peças somem; os salvos ficam no chão.
func encerrar() -> void:
	for t: Combatant in prisoes.keys():
		_soltar(t)
	for f in flores:
		if f["unit"] != null:
			room.enemies.erase(f["unit"])
	for c in corpos:
		room.enemies.erase(c["tentaculo"])
	visual.encerrar()
