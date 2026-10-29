extends SceneTree
# Teste headless das regras de combate. Rodar com:
#   godot --headless --path . -s tests/test_combat.gd

var failures := 0
var cfg: CombatConfig


func _init() -> void:
	cfg = CombatConfig.load_file()
	_test_data_sources()
	_test_initiative_and_pa()
	_test_delay_and_pass()
	_test_combat_end()
	_test_movement()
	_test_hit_chance()
	_test_attack()
	_test_cover()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _unit(id: String, n: String, init: int, pos := Vector2.ZERO) -> Combatant:
	var u := cfg.make_unit(id, n, pos) if id == "agente" else cfg.make_enemy(id, pos)
	u.initiative = init
	return u


func _test_data_sources() -> void:
	var ppm := cfg.value("pixels_per_meter")
	var w := cfg.weapon("pistola_teste")
	var src := cfg.game_data.get_entry("armas", "pistola_teste")
	_check(w.base_chance == src["precisao_base"] and w.damage_min == src["dano"][0], "arma lida de armas.json")
	_check(is_equal_approx(w.max_range, src["alcance_maximo"] * ppm), "alcance convertido de metros para pixels")
	var e := cfg.make_enemy("cultista_teste", Vector2.ZERO)
	var sheet := cfg.game_data.get_entry("inimigos", "cultista_teste")
	_check(e.max_pv == sheet["pv"] and e.initiative == sheet["iniciativa"] and e.side == Combatant.Side.ENEMY, "inimigo lido de inimigos.json")
	e.pa_per_turn = 2
	var a := _unit("agente", "A", 1)
	var tm := TurnManager.new()
	tm.start([e, a] as Array[Combatant])
	_check(tm.current == e and e.pa == 2, "inimigo começa o turno com os PA da ficha")


func _test_initiative_and_pa() -> void:
	var a := _unit("agente", "A", 12)
	var b := _unit("agente", "B", 15)
	var e := _unit("cultista_teste", "E", 13)
	var tm := TurnManager.new(int(cfg.value("pa_per_turn")))
	tm.start([a, b, e] as Array[Combatant])
	_check(tm.order[0] == b and tm.order[1] == e and tm.order[2] == a, "ordem por iniciativa, maior primeiro")
	_check(tm.current == b and b.pa == 3, "primeiro da ordem começa com 3 PA")
	_check(not tm.spend(a, 1), "ação fora do turno é recusada")
	_check(tm.spend(b, 2) and b.pa == 1 and a.pa == 0, "gastar PA não mexe no saldo de outro")
	_check(not tm.spend(b, 2), "ação sem PA suficiente é recusada")
	tm.spend(b, 1)
	tm.action_done()
	_check(tm.current == e and e.pa == 3, "PA esgotados passam a vez")
	tm.end_turn()
	tm.spend(a, 1)
	tm.end_turn()
	_check(tm.round_number == 2 and tm.current == b and b.pa == 3, "nova rodada recomeça com 3 PA, sem acúmulo")
	_check(a.pa == 0, "PA restantes de quem encerrou o turno são perdidos")

	var tie_e := _unit("cultista_teste", "E", 10)
	var tie_p := _unit("agente", "P", 10)
	var tm2 := TurnManager.new()
	tm2.start([tie_e, tie_p] as Array[Combatant])
	_check(tm2.order[0] == tie_p, "empate residual: protagonista antes do inimigo")


func _test_delay_and_pass() -> void:
	var a := _unit("agente", "A", 15)
	var b := _unit("agente", "B", 12)
	var e := _unit("cultista_teste", "E", 10)
	var tm := TurnManager.new()
	tm.start([a, b, e] as Array[Combatant])
	_check(tm.delay() and tm.current == b, "atrasar passa a vez para o próximo")
	tm.end_turn()
	tm.end_turn()
	_check(tm.current == a and tm.round_number == 1 and a.pa == 3, "quem atrasou age no fim da mesma rodada")
	_check(not tm.delay(), "atrasar só uma vez por rodada")
	tm.end_turn()
	_check(tm.round_number == 2 and tm.current == a, "rodada seguinte volta à ordem normal")
	tm.spend(a, 1)
	_check(not tm.delay(), "não pode atrasar depois de gastar PA")
	tm.pass_turn()
	_check(tm.current == b, "passar encerra o turno")
	tm.end_turn()
	tm.end_turn()
	_check(tm.round_number == 3 and tm.current == a, "quem passou só volta a agir na rodada seguinte")


func _test_combat_end() -> void:
	var a := _unit("agente", "A", 15)
	var e := _unit("cultista_teste", "E", 10)
	var tm := TurnManager.new()
	var ended := []
	tm.combat_ended.connect(func(r): ended.append(r))
	tm.start([a, e] as Array[Combatant])
	e.take_damage(999)
	tm.spend(a, 1)
	tm.action_done()
	_check(tm.state == TurnManager.State.ENDED and tm.result == TurnManager.Result.VICTORY, "sem inimigos vivos, vitória imediata")
	_check(ended.size() == 1 and tm.current == null, "combate termina sem rodada extra")

	var a2 := _unit("agente", "A", 5)
	var e2 := _unit("cultista_teste", "E", 10)
	var tm2 := TurnManager.new()
	tm2.start([a2, e2] as Array[Combatant])
	a2.take_damage(999)
	tm2.action_done()
	_check(tm2.result == TurnManager.Result.GAME_OVER, "sem protagonistas vivos, Game Over")


func _test_movement() -> void:
	var rules := CombatRules.new(cfg)
	var ppa := cfg.value("pixels_per_pa")
	_check(rules.move_cost(0) == 0, "não andar custa 0 PA")
	_check(rules.move_cost(ppa) == 1 and rules.move_cost(ppa + 1) == 2, "custo proporcional à distância")
	var path := PackedVector2Array([Vector2(0, 0), Vector2(ppa * 2, 0), Vector2(ppa * 2, ppa * 3)])
	var full := rules.plan_move(path, 5)
	_check(full.cost == 5 and full.path.size() == 3, "rota que cabe nos PA é feita inteira")
	var partial := rules.plan_move(path, 3)
	_check(partial.cost == 3 and is_equal_approx(CombatRules.path_length(partial.path), ppa * 3), "movimento parcial até o limite dos PA")
	_check(partial.path[partial.path.size() - 1].is_equal_approx(Vector2(ppa * 2, ppa)), "parcial para no ponto certo da rota")


func _test_hit_chance() -> void:
	var rules := CombatRules.new(cfg)
	var a := _unit("agente", "A", 1, Vector2(0, 0))
	var e := _unit("cultista_teste", "E", 1, Vector2(100, 0))
	var expected := 0.70 + (2 - 0) * 0.05
	_check(is_equal_approx(rules.hit_chance(a, e), expected), "chance = base + diferença de precisão/defesa")
	e.pos = Vector2(a.weapon.effective_range + 20 + 100, 0)
	_check(is_equal_approx(rules.hit_chance(a, e), expected - 0.10), "distância além do alcance efetivo reduz a chance")
	a.precision = 100
	_check(is_equal_approx(rules.hit_chance(a, e), 0.95), "chance máxima 95%")
	a.precision = -100
	_check(is_equal_approx(rules.hit_chance(a, e), 0.05), "chance mínima 5%")


func _test_attack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rules := CombatRules.new(cfg, rng)
	var walls: Array[Rect2] = [Rect2(200, -50, 20, 100)]
	var a := _unit("agente", "A", 1, Vector2(0, 0))
	var e := _unit("cultista_teste", "E", 1, Vector2(400, 0))
	a.pa = 3
	_check(rules.attack(a, e, walls, []).reason == "no_line_of_sight", "parede bloqueia o ataque")
	_check(a.pa == 3, "ataque recusado não gasta PA")
	e.pos = Vector2(100, 0)
	a.pa = 0
	_check(rules.attack(a, e, walls, []).reason == "no_pa", "sem PA não ataca")
	var claw := _unit("cultista_teste", "C", 1, Vector2(100, 0))
	claw.pa = 3
	_check(rules.attack(claw, a, [] as Array[Rect2], []).reason == "out_of_range", "corpo a corpo exige estar perto")

	var hits := 0
	var damage_ok := true
	var crits := 0
	for i in 400:
		a.pa = a.weapon.pa_cost
		e.pv = 999
		var r := rules.attack(a, e, [] as Array[Rect2], [])
		if r.hit:
			hits += 1
			var dmg: int = r.damage
			if r.crit:
				crits += 1
				damage_ok = damage_ok and dmg >= 12 and dmg <= 18
			else:
				damage_ok = damage_ok and dmg >= 8 and dmg <= 12
			damage_ok = damage_ok and e.pv == 999 - dmg
	_check(a.pa == 0, "ataque gasta o custo em PA da arma")
	_check(hits > 280 and hits < 360, "taxa de acerto perto de 80%% (%d/400)" % hits)
	_check(damage_ok, "dano dentro da faixa da arma e aplicado ao alvo")
	_check(crits > 0, "críticos acontecem")


func _test_cover() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rules := CombatRules.new(cfg, rng)
	var a := _unit("agente", "A", 1, Vector2(0, 0))
	var e := _unit("cultista_teste", "E", 1, Vector2(300, 0))
	var partial := Cover.new(Rect2(270, -20, 10, 40), "partial", 30)
	var full := Cover.new(Rect2(275, -20, 10, 40), "full", 30)
	var far := Cover.new(Rect2(100, -20, 10, 40), "full", 30)
	_check(rules.cover_between(a.pos, e, [partial]) == partial, "cobertura encostada no alvo protege")
	_check(rules.cover_between(a.pos, e, [far]) == null, "cobertura longe do alvo não protege")
	_check(rules.cover_between(Vector2(600, 0), e, [partial]) == null, "atacar pelo outro lado ignora a cobertura")
	_check(rules.cover_between(a.pos, e, [partial, full]) == full, "completa tem prioridade sobre parcial")
	a.pa = 3
	_check(rules.attack_blocker(a, e, [] as Array[Rect2]) == "", "cobertura não bloqueia a linha de visão")

	var stats := {}
	for kind in ["partial", "full"]:
		var c := Cover.new(Rect2(270, -20, 10, 40), kind, 30)
		var blocked := 0
		var total_dmg := 0
		var damaged := 0
		for i in 2000:
			a.pa = a.weapon.pa_cost
			e.pv = 999
			var r := rules.attack(a, e, [] as Array[Rect2], [c])
			if r.blocked:
				blocked += 1
			elif r.hit:
				total_dmg += r.damage
				damaged += 1
		stats[kind] = {"blocked": blocked, "avg": float(total_dmg) / damaged}
		_check(c.hp == 30, "atacar alvo protegido (%s) não danifica a cobertura" % kind)
	_check(stats.full.blocked > stats.partial.blocked, "completa bloqueia mais que parcial")
	_check(stats.full.avg < stats.partial.avg, "completa reduz mais dano que parcial")

	var wall_cover := Cover.new(Rect2(100, -20, 10, 40), "partial", 5)
	var hit_cover := false
	for i in 50:
		a.pa = a.weapon.pa_cost
		var r := rules.attack_cover(a, wall_cover, [] as Array[Rect2])
		if r.hit:
			hit_cover = true
			break
	_check(hit_cover and wall_cover.is_destroyed(), "mirar a estrutura danifica e destrói a cobertura")
	_check(rules.cover_between(a.pos, e, [wall_cover]) == null, "cobertura destruída não protege")


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
