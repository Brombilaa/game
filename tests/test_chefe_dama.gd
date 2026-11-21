extends SceneTree
# Teste da luta da Dama de Sangue com as 7 flores (ChefeDama; Léo, 20/11/2026). Rodar com:
#   godot --headless --path . -s tests/test_chefe_dama.gd
# Abre a cripta com a Dama já surgida e confere: peças iniciais, devorar e abrir flor, mecânica certa e errada,
# bônus perdidos, salvar um pendurado, fase 2, Prisão de Tentáculos e as condições novas.

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	_condicoes()
	await _luta()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_chefe_dama")
	quit(1 if failures > 0 else 0)


# Confuso tira 1 PA do próximo turno; preso não anda; miasma tira 4 PV por turno; objeto não tem turno.
func _condicoes() -> void:
	var cfg := CombatConfig.load_file()
	var rules := CombatRules.new(cfg)
	var a := cfg.make_agent("nikolai", Vector2.ZERO)
	var tm := TurnManager.new(3)
	rules.apply_condition(a, "confuso")
	rules.start_turn_effects(a)
	_check(a.pa_menos == 1 and tm.turn_pa(a) == 2, "confuso: começa o turno com 1 PA a menos")
	rules.start_turn_effects(a)
	_check(a.pa_menos == 0 and tm.turn_pa(a) == 3, "confuso: dura um turno")
	rules.apply_condition(a, "preso")
	rules.start_turn_effects(a)
	_check(a.preso, "preso: não anda no primeiro turno")
	rules.start_turn_effects(a)
	_check(a.preso and not a.has_condition("preso"), "preso: nem no segundo (2 turnos)")
	rules.start_turn_effects(a)
	_check(not a.preso, "preso: no terceiro anda")
	var pv := a.pv
	rules.apply_condition(a, "miasma")
	var fx := rules.start_turn_effects(a)
	_check(a.pv == pv - 4 and fx.damage == 4, "miasma: 4 PV no início do turno")
	var flor := Combatant.new()
	flor.objeto = true
	flor.side = Combatant.Side.ENEMY
	flor.pv = 1
	var e := cfg.make_enemy("cultista", Vector2(500, 0))
	tm.start([a, e, flor] as Array[Combatant])
	_check(not tm.order.has(flor), "objeto: fora da ordem dos turnos")
	e.pv = 0
	tm.action_done()
	_check(tm.result == TurnManager.Result.VICTORY, "objeto: flor de pé não segura o combate")


func _luta() -> void:
	Missao1.reiniciar()
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4", "dama_surgiu"]:
		Missao1.marcar(m)
	Missao1.local = "cripta"
	Missao1.chegada = ""
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	var ch: ChefeDama = room.chefe_dama
	_check(ch != null, "a Dama surgida traz a luta das flores")
	if ch == null:
		return
	var dama := ch.dama
	_check(dama.max_pv == 100 and is_equal_approx(dama.defense, 0.1), "ficha: 100 PV (Léo) e defesa 10%")
	_check(ch.corpos.size() == 6 and ch.corpos[0]["nome"] == "Selena Schaefer" and ch.corpos[5]["nome"] == "Marcos Paixão", "seis pendurados, do mais jovem ao mais velho")
	_check((ch.corpos[0]["tentaculo"] as Combatant).max_pv == 30, "cada pendurado é seguro por um tentáculo de 30 PV")
	var vermelha: Dictionary = ch.flores[6]
	_check(vermelha["estado"] == "aberta" and not (vermelha["unit"] as Combatant).protegido, "a Vermelha já nasce aberta e vulnerável")
	_check(ch.flores.slice(0, 6).all(func(f: Dictionary) -> bool: return f["estado"] == "fechada"), "as outras seis começam fechadas")
	room._start_combat()
	Engine.time_scale = 8.0
	# Turno 1: devora Selena e abre a Laranja (Visão Macabra), vulnerável.
	await _turno_da_dama(room, ch)
	var laranja: Dictionary = ch.flores[0]
	_check(ch.corpos[0]["estado"] == "devorado", "turno 1: devora o primeiro pendurado")
	_check(laranja["estado"] == "aberta" and not (laranja["unit"] as Combatant).protegido, "turno 1: abre a Laranja, vulnerável")
	_check(ch.flores[1]["estado"] == "fechada", "turno 1: só uma flor abre por rodada")
	# Mecânica errada: bala na Laranja não faz nada. Mecânica certa: corte (espada).
	var lu: Combatant = laranja["unit"]
	var nikolai: Combatant = _membro(room, "Nikolai")
	var miguel: Combatant = _membro(room, "Miguel")
	nikolai.pos = lu.pos + Vector2(60, 0)
	nikolai.pa = 3
	nikolai.hit_bonus = 5.0
	var r: Dictionary = room.rules.attack(nikolai, lu, [] as Array[Rect2], [])
	_check(r.hit and r.sem_efeito and lu.pv == lu.max_pv, "Laranja: bala acerta sem efeito")
	miguel.weapon = room.cfg.weapon("espada")
	miguel.pos = lu.pos + Vector2(lu.radius + miguel.radius + 4, 0)
	miguel.hit_bonus = 5.0
	var golpes := 0
	while lu.is_alive() and golpes < 6:
		miguel.pa = 3
		room.rules.attack(miguel, lu, [] as Array[Rect2], [])
		golpes += 1
	ch.ao_impacto(lu)
	_check(laranja["estado"] == "murcha" and dama.max_pv == 80, "Laranja: o corte a faz murchar e a Dama perde 20 PV máximos")
	# Vermelha com agrotóxico (item): murcha e a Dama perde as resistências.
	room.inventory.add("agrotoxico", 1)
	var out: Dictionary = room.item_rules.use(nikolai, "agrotoxico", 1, (vermelha["unit"] as Combatant).pos, vermelha["unit"], room._living_units(), [] as Array[Rect2])
	_check(out.ok and out.murchou, "Vermelha: o agrotóxico a faz murchar")
	room._apos_efeito(vermelha["unit"])
	_check(vermelha["estado"] == "murcha" and dama.sem_resistencias, "Vermelha: a Dama perde as resistências")
	# Item errado numa flor aberta: nada acontece.
	# Salvar o próximo pendurado (Bruno): o tentáculo dele cai antes do turno dela.
	var t2: Combatant = ch.corpos[1]["tentaculo"]
	t2.pv = 0
	ch.ao_impacto(t2)
	_check(ch.corpos[1]["estado"] == "salvo", "tentáculo destruído: o pendurado é salvo")
	await _turno_da_dama(room, ch)
	_check(ch.corpos[1]["estado"] == "salvo" and ch.flores[1]["estado"] == "fechada", "rodada do salvo: nenhuma flor abre")
	# Turno 3: devora Ramiro e abre a Rosa (próxima da tabela).
	await _turno_da_dama(room, ch)
	var rosa: Dictionary = ch.flores[1]
	_check(ch.corpos[2]["estado"] == "devorado" and rosa["estado"] == "aberta", "turno 3: a Rosa abre com o próximo devorado")
	room.inventory.add("garrafa_agua", 1)
	out = room.item_rules.use(nikolai, "garrafa_agua", 1, (rosa["unit"] as Combatant).pos, rosa["unit"], room._living_units(), [] as Array[Rect2])
	_check(out.ok and out.sem_efeito and (rosa["unit"] as Combatant).is_alive(), "Rosa: água não faz nada (pede fertilizante)")
	# A janela fecha no começo do turno seguinte dela.
	await _turno_da_dama(room, ch)
	_check(rosa["estado"] == "aberta" and (rosa["unit"] as Combatant).protegido, "a flor da rodada anterior fecha a janela")
	_check(room.rules.attack_blocker(nikolai, rosa["unit"], [] as Array[Rect2], []) == "requirement", "flor fora da janela não pode ser atacada")
	# Fase 2: com 50% ou menos, todas as flores de pé se abrem, vulneráveis.
	dama.pv = int(dama.max_pv * 0.5)
	ch.ao_impacto(dama)
	_check(ch.fase == 2, "fase 2 com a Dama a 50%")
	_check(ch.flores.all(func(f: Dictionary) -> bool: return f["estado"] == "murcha" or (f["estado"] == "aberta" and not (f["unit"] as Combatant).protegido)), "fase 2: todas as flores de pé abertas e vulneráveis")
	# Prisão de Tentáculos: prende quem está perto; destruir o tentáculo solta.
	for m in room.party:
		m.pos = dama.pos + Vector2(90, 0)
	await ch._usar("prisao_tentaculos")
	var preso: Combatant = null
	var tp: Combatant = null
	for t in ch.prisoes:
		tp = t
		preso = ch.prisoes[t]
	_check(preso != null and preso.has_condition("preso") and tp.max_pv == 15, "Prisão: prende um e cria o tentáculo de 15 PV")
	if tp:
		tp.pv = 0
		ch.ao_impacto(tp)
		_check(not preso.has_condition("preso") and not preso.preso and ch.prisoes.is_empty(), "Prisão: destruir o tentáculo solta")
	# Grito de Confusão: quem está em volta fica confuso.
	await ch._usar("grito_confusao")
	_check(room.party.any(func(m: Combatant) -> bool: return m.has_condition("confuso")), "Grito: confunde quem está em volta")
	Engine.time_scale = 1.0
	room.queue_free()
	await process_frame


# Dá a vez à Dama e espera o turno dela acabar.
func _turno_da_dama(room, ch: ChefeDama) -> void:
	room.turns.current = ch.dama
	ch.dama.pa = room.turns.turn_pa(ch.dama)
	room.turns.state = TurnManager.State.IDLE  # não deixa a vez passar para os outros durante o teste
	room.turns.state = TurnManager.State.ACTIVE
	var antes: Array = room.turns._queue.duplicate()
	room.turns._queue.clear()
	room.turns._queue.append(room.party[1])  # quem vem depois: um do grupo, que espera o clique
	await ch.run_turn()
	room.turns._queue = antes


func _membro(room, nome: String) -> Combatant:
	for m in room.party:
		if m.name == nome:
			return m
	return null


func _check(cond: bool, label: String) -> void:
	if cond:
		print("ok   - ", label)
	else:
		failures += 1
		print("FAIL: ", label)
