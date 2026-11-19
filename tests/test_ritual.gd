extends SceneTree
# Teste headless dos rituais do Miguel (custo de PA e SAN, efeitos, INT, ruptura). Rodar com:
#   godot --headless --path . -s tests/test_ritual.gd

var failures := 0
var cfg: CombatConfig
var rules: CombatRules
var san: SanRules
var rit: RitualRules
const NO_WALLS: Array[Rect2] = []


func _init() -> void:
	cfg = CombatConfig.load_file()
	_test_data()
	_test_known()
	_test_costs()
	_test_armor()
	_test_curse()
	_test_electrocution()
	_test_stun_immunity()
	_test_heal()
	_test_san_edge()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _fresh(seed_value := 3) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	rules = CombatRules.new(cfg, r)
	san = SanRules.new(cfg, r)
	rit = RitualRules.new(cfg, rules, san, r)


func _miguel(int_value := 3) -> Combatant:
	var attrs := Ficha.sugeridos(cfg.game_data, "miguel")
	attrs["INT"] = int_value
	var m := cfg.make_agent("miguel", Vector2.ZERO, attrs)
	m.pa = 3
	san.start_combat([m])
	return m


func _test_data() -> void:
	_fresh()
	var ids := cfg.game_data.ids("rituais")
	_check(ids.size() == 4, "quatro rituais em rituais.json")
	var a := rit.ritual("armadura_sangue")
	_check(int(a.custo_pa) == 1 and int(a.custo_san) == 2 and is_equal_approx(float(a.valor), 0.2) and int(a.rodadas) == 3, "Armadura de Sangue: 1 PA, 2 SAN, 20%, 3 rodadas")
	var e := rit.ritual("eletrocussao")
	_check(int(e.custo_pa) == 2 and int(e.custo_san) == 4 and e.dano == [8, 12] and is_equal_approx(float(e.alcance_m), 6.0), "Eletrocussão: 2 PA, 4 SAN, 8-12, 6 m")
	_check(cfg.game_data.provisional.has("rituais.cicatrizacao"), "rituais marcados como provisórios")


func _test_known() -> void:
	_fresh()
	var m := _miguel()
	_check(rit.known(m).size() == 4, "Miguel (Ocultista) conhece os quatro")
	var f := cfg.make_agent("fernando", Vector2.ZERO)
	f.pa = 3
	_check(rit.known(f).is_empty(), "Fernando (Combatente) não conhece nenhum")
	_check(rit.blocker(f, "armadura_sangue") == "requirement", "quem não conhece é recusado")
	_check(rit.known(cfg.make_enemy("cultista", Vector2.ZERO)).is_empty(), "inimigo não conhece rituais")


func _test_costs() -> void:
	_fresh()
	var m := _miguel()
	m.pa = 0
	_check(rit.blocker(m, "armadura_sangue") == "no_pa", "sem PA")
	m.pa = 3
	m.san = 1
	_check(rit.blocker(m, "armadura_sangue") == "no_san", "SAN abaixo do custo")
	m.san = 22
	var out := rit.cast(m, "armadura_sangue")
	_check(out.ok and m.pa == 2 and m.san == 20, "paga 1 PA e 2 SAN")
	_check(out.san.lost == 2 and not out.san.resisted, "PRE não resiste a custo de ritual")


func _test_armor() -> void:
	_fresh()
	var m := _miguel()
	var e := cfg.make_enemy("cultista", Vector2(30, 0))
	rit.cast(m, "armadura_sangue")
	_check(is_equal_approx(m.defense_total(), 0.2), "Armadura soma 20% de redução")
	m.defense = 0.1
	_check(is_equal_approx(m.defense_total(), 0.3), "soma com o colete")
	m.defense = 0.0
	_check(rules.damage_after_defense(10.0, m.defense_total()) == 8, "10 de dano vira 8")
	for i in 2:
		rules.start_turn_effects(m)
	_check(m.buffs.has("armadura_sangue") and is_equal_approx(m.defense_total(), 0.2), "ainda ativa depois de 2 turnos")
	rules.start_turn_effects(m)
	_check(m.buffs.is_empty() and is_equal_approx(m.defense_total(), 0.0), "acaba no 3º turno depois")
	rit.cast(m, "armadura_sangue")
	RitualRules.clear_buffs([m])
	_check(m.buffs.is_empty(), "fim do combate limpa os efeitos")


func _test_curse() -> void:
	_fresh()
	var m := _miguel()
	var e := cfg.make_enemy("cultista", Vector2(20, 0))
	e.defense = 0.0
	m.pa = 6
	var base_min := int(m.weapon.damage_min)
	rit.cast(m, "amaldicoar_arma")
	_check(m.damage_bonus() == 2, "Amaldiçoar soma +2 de dano")
	var low := 999
	for i in 40:
		e.pv = 100
		m.pa = 3
		m.hit_bonus = 1.0
		var r := rules.attack(m, e, NO_WALLS, [])
		if r.hit and not r.crit:
			low = mini(low, 100 - e.pv)
	_check(low >= base_min + 2 or low == 999, "o golpe leva o dano extra (mín. %d)" % low)


func _test_electrocution() -> void:
	_fresh()
	var m := _miguel(3)
	var e := cfg.make_enemy("atirador", Vector2(100, 0))  # sem fraqueza nem resistência a ritual (o cultista resiste)
	e.defense = 0.0
	e.pv = 100
	e.max_pv = 100
	m.pa = 3
	var out := rit.cast(m, "eletrocussao", e, NO_WALLS, [])
	_check(out.ok and m.pa == 1 and m.san == 22 - 4, "paga 2 PA e 4 SAN")
	# INT 3 = +2: dano 10 a 14
	_check(out.damage >= 10 and out.damage <= 14 and e.pv == 100 - out.damage, "dano 8-12 + INT (%d)" % out.damage)
	var m1 := _miguel(1)
	m1.pa = 3
	e.pv = 100
	var o1 := rit.cast(m1, "eletrocussao", e, NO_WALLS, [])
	_check(o1.damage >= 8 and o1.damage <= 12, "INT 1 não soma (%d)" % o1.damage)
	m.pa = 3
	e.pos = Vector2(1000, 0)
	_check(rit.blocker(m, "eletrocussao", e, NO_WALLS, []) == "out_of_range", "além de 6 m")
	e.pos = Vector2(100, 0)
	var walls: Array[Rect2] = [Rect2(40, -50, 10, 100)]
	_check(rit.blocker(m, "eletrocussao", e, walls, []) == "no_line_of_sight", "parede bloqueia")
	_check(rit.blocker(m, "eletrocussao", m, NO_WALLS, []) == "requirement", "não vale contra aliado")
	var stuns := 0
	for i in 200:
		var t := cfg.make_enemy("atirador", Vector2(100, 0))
		t.pv = 100
		t.max_pv = 100
		var mm := _miguel()
		mm.pa = 3
		if rit.cast(mm, "eletrocussao", t, NO_WALLS, []).stunned:
			stuns += 1
			_check(t.has_condition("atordoado"), "atordoado recebe a condição") if stuns == 1 else null
	_check(stuns > 25 and stuns < 75, "atordoa perto de 25%% (%d/200)" % stuns)


func _test_stun_immunity() -> void:
	_fresh()
	var dama := cfg.make_enemy("dama_sangue", Vector2(100, 0))
	var hits := 0
	for i in 60:
		var m := _miguel()
		m.pa = 3
		dama.pv = dama.max_pv
		var out := rit.cast(m, "eletrocussao", dama, NO_WALLS, [])
		if out.stunned:
			hits += 1
	_check(hits == 0 and not dama.has_condition("atordoado"), "a Dama de Sangue é imune a atordoar")


func _test_heal() -> void:
	_fresh()
	var m := _miguel(3)
	var ally := cfg.make_agent("fernando", Vector2(30, 0))
	ally.pv = 5
	var out := rit.cast(m, "cicatrizacao", ally, NO_WALLS, [])
	var expected := floori(ally.max_pv * 0.3 + 0.0001) + 2
	_check(out.ok and out.healed == expected and ally.pv == 5 + expected, "cura 30%% do PV máx + INT (%d)" % out.healed)
	_check(m.pa == 1 and m.san == 22 - 3, "paga 2 PA e 3 SAN")
	ally.pos = Vector2(500, 0)
	m.pa = 3
	_check(rit.blocker(m, "cicatrizacao", ally) == "out_of_range", "só aliado encostado")
	m.pv = 3
	var self_out := rit.cast(m, "cicatrizacao", m)
	_check(self_out.ok and m.pv > 3, "pode curar a si")
	ally.pv = 0
	ally.pos = Vector2(20, 0)
	m.pa = 3
	_check(rit.blocker(m, "cicatrizacao", ally) == "requirement", "caído usa o kit, não a cura")
	var full := cfg.make_agent("nikolai", Vector2(20, 0))
	var o := rit.cast(m, "cicatrizacao", full)
	_check(o.ok and o.healed == 0, "cura nunca passa do PV máximo")


func _test_san_edge() -> void:
	_fresh()
	var m := _miguel()
	m.san = 4
	var out := rit.cast(m, "eletrocussao", cfg.make_enemy("cultista", Vector2(100, 0)), NO_WALLS, [])
	_check(out.ok and m.san == 0 and m.ruptured and out.san.rupture, "gastar toda a SAN = ruptura")
	_check(rit.blocker(m, "armadura_sangue") == "no_san", "sem SAN não conjura")
	# Cicatrização em si mesmo tira a ruptura criada pelo próprio custo
	var h := _miguel()
	h.san = 3
	h.pv = 5
	var c := rit.cast(h, "cicatrizacao", h)
	_check(c.ok and h.san == 0 and not h.ruptured and c.cleared, "Cicatrização em si cura a ruptura do próprio custo")
	# Ruptura anterior curada em aliado
	var ally := cfg.make_agent("fernando", Vector2(20, 0))
	ally.ruptured = true
	ally.san = 0
	var m2 := _miguel()
	var c2 := rit.cast(m2, "cicatrizacao", ally)
	_check(c2.ok and not ally.ruptured and c2.cleared, "Cicatrização tira a ruptura do aliado")
	# Segunda ruptura no combate = loucura
	var d := _miguel()
	d.san = 2
	rit.cast(d, "armadura_sangue")
	_check(d.ruptured and d.ruptures_in_combat == 1, "primeira ruptura")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok  " + label)
	else:
		failures += 1
		print("  FALHOU  " + label)
