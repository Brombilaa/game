extends SceneTree
# Luta da Dama de Sangue (ChefeDama): ficha nos dados, símbolos sem turno que dão defesa, fase 2 anunciada abaixo
# de 50%, Maré de Sangue avisada um turno antes, Chamado de Sangue e imunidade a atordoar.
# Rodar com:
#   godot --headless --path . -s tests/test_chefe_dama.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	_ficha()
	await _luta()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_chefe_dama")
	quit(1 if failures > 0 else 0)


func _ficha() -> void:
	var cfg := CombatConfig.load_file()
	var d := cfg.game_data.get_entry("inimigos", "dama_sangue")
	_check(int(d["pv"]) == 120 and d["chefe"], "ficha: 120 PV e chefe (GDD #14)")
	_check((d["ataques"] as Array).has("garra_dama") and (d["ataques"] as Array).has("lanca_dama"), "ficha: Garra e Lança de Sangue")
	_check((d["fases"] as Array).size() == 2, "ficha: duas fases")
	var dama := cfg.make_enemy("dama_sangue", Vector2.ZERO)
	var rules := CombatRules.new(cfg)
	rules.apply_condition(dama, "atordoado")
	_check(not dama.has_condition("atordoado"), "a Dama é imune a atordoar")
	rules.apply_condition(dama, "sangrando")
	_check(dama.has_condition("sangrando"), "mas sangra normalmente")
	var lanca := cfg.weapon("lanca_dama")
	_check(lanca["max_range"] == 8.0 * cfg.value("pixels_per_meter") and lanca["pa_cost"] == 2, "Lança: 8 m e 2 PA")


func _luta() -> void:
	Missao1.reiniciar()
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4"]:
		Missao1.marcar(m)
	Missao1.local = "cripta"
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	var roberto: Combatant = null
	for e in room.enemies:
		if e.name == "Roberto Ghular":
			roberto = e
	room._start_combat()
	roberto.pv = 5
	room._show_attack(room.player, roberto, {"ok": true, "hit": true, "damage": 3, "crit": false, "blocked": false})
	var cd: ChefeDama = room.chefe_dama
	_check(cd != null and cd.dama.is_alive(), "a Dama surge com o controle da luta")
	_check(cd.simbolos.size() == 3 and cd.simbolos_de_pe() == 3, "três símbolos na arena")
	for s in cd.simbolos:
		_check(Pathfinder.is_free(s.pos, room._obstacles(s), s.radius), "símbolo em ponto livre (%s)" % s.pos)
		_check(room.enemies.has(s), "símbolo pode ser atacado (está entre os inimigos)")
	_check(is_equal_approx(cd.dama.defense, 0.4), "com 3 símbolos de pé a Dama tem 40%% de defesa (%.2f)" % cd.dama.defense)
	for n in 3:
		room.turns._next_round()
		_check(not room.turns.order.any(func(u: Combatant) -> bool: return u.objeto), "símbolo não entra na ordem dos turnos")
	# Quebrar um símbolo tira 10% da defesa.
	var s0: Combatant = cd.simbolos[0]
	s0.pv = 0
	cd.ao_impacto(s0)
	_check(is_equal_approx(cd.dama.defense, 0.3) and cd.simbolos_de_pe() == 2, "quebrar um símbolo baixa a defesa para 30%")
	# Fase 2 abaixo de 50%.
	_check(cd.fase == 1 and is_equal_approx(cd.dano_mult(), 1.0), "começa na fase 1")
	cd.dama.pv = 61
	cd.ao_impacto(cd.dama)
	_check(cd.fase == 1, "61 de 120 ainda é fase 1")
	cd.dama.pv = 60
	cd.ao_impacto(cd.dama)
	_check(cd.fase == 2 and is_equal_approx(cd.dano_mult(), 1.25), "60 de 120: fase 2 com +25% de dano")
	cd._empunhar("garra")
	_check(int(cd.dama.weapon["damage_min"]) == 10 and int(cd.dama.weapon["damage_max"]) == 15, "Garra na fase 2: 10 a 15")
	# Maré: marca no grupo, quem sai do círculo escapa, quem fica leva dano.
	var a: Combatant = room.party[0]
	var b: Combatant = room.party[1]
	for m in room.party:
		m.pv = m.max_pv
		m.conditions.clear()
	b.pos = a.pos + Vector2(20, 0)
	room.party[2].pos = a.pos + Vector2(600, 0)
	room.turns.current = cd.dama
	room.turns.state = TurnManager.State.ACTIVE
	cd.dama.pa = 3
	_check(cd._centro_mare().distance_to(a.pos) < 30.0, "a Maré mira onde há mais gente junta")
	cd._marcar_mare()
	_check(not cd.carga.is_empty() and cd.dama.pa == 0, "marcar a Maré gasta o turno e deixa o aviso")
	b.pos = cd.carga["centro"] + Vector2(cd.carga["raio"] + 60.0, 0)  # b sai do círculo
	a.pos = cd.carga["centro"]
	var pv_a := a.pv
	var pv_b := b.pv
	room.turns.state = TurnManager.State.ACTIVE
	room.turns.current = cd.dama
	cd.dama.pa = 3
	await cd._soltar_mare()
	_check(a.pv < pv_a and a.has_condition("sangrando"), "quem ficou no círculo leva a Maré e sangra (%d -> %d)" % [pv_a, a.pv])
	_check(b.pv == pv_b, "quem saiu do círculo escapa")
	_check(cd.carga.is_empty(), "o aviso some depois do golpe")
	# Chamado: 2 cultistas ao lado de um símbolo de pé; sem símbolos, não chama mais.
	for e in room.enemies:
		if not e.objeto and e != cd.dama:
			e.pv = 0
	room.turns.state = TurnManager.State.ACTIVE
	room.turns.current = cd.dama
	cd.dama.pa = 3
	cd.turno = 10
	_check(cd._pode_chamar(), "pode chamar com símbolo de pé e PA")
	var antes: int = room.enemies.size()
	await cd._chamar()
	_check(room.enemies.size() == antes + 2, "o Chamado traz 2 cultistas")
	for s in cd.simbolos:
		s.pv = 0
		cd.ao_impacto(s)
	cd.turno = 20
	cd.dama.pa = 3
	_check(not cd._pode_chamar(), "sem símbolos a Dama não chama mais")
	_check(is_equal_approx(cd.dama.defense, 0.1), "sem símbolos volta à defesa da ficha (10%)")
	# Vitória: os símbolos saem da lista.
	for e in room.enemies:
		e.pv = 0
	room.turns.state = TurnManager.State.ACTIVE
	room.turns.action_done()
	_check(not room.enemies.any(func(u: Combatant) -> bool: return u.objeto), "fim do combate tira os símbolos")
	room.queue_free()
	await process_frame


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		print("FALHOU: " + msg)
