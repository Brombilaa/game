extends SceneTree
# Teste headless dos itens de uso em combate (coquetel do Fernando e sinalizador). Rodar com:
#   godot --headless --path . -s tests/test_combat_items.gd

var failures := 0
var cfg: CombatConfig
var rules: CombatRules
var items: ItemRules
const NO_WALLS: Array[Rect2] = []


func _init() -> void:
	cfg = CombatConfig.load_file()
	_test_data()
	_test_coquetel()
	_test_range_and_walls()
	_test_flare()
	_test_cost()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _fresh(seed_value := 5) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	rules = CombatRules.new(cfg, r)
	items = ItemRules.new(cfg, rules, r)


func _agent(pos := Vector2.ZERO) -> Combatant:
	var a := cfg.make_agent("fernando", pos)
	a.pa = 3
	return a


func _m(meters: float) -> float:
	return meters * cfg.value("pixels_per_meter")


func _test_data() -> void:
	_fresh()
	_check(items.combat_items() == ["sinalizador", "bulbo_bravo_purpulis", "fertilizante", "agrotoxico", "balde", "garrafa_agua", "coquetel"],
		"itens de combate: sinalizador, coquetel e os das flores da Dama (sem sal nem granada)")
	for id in items.combat_items():
		_check(items.cost(id) == 1, "%s custa 1 PA (custo de usar item)" % id)
		_check(cfg.game_data.provisional.has("itens." + id), "%s marcado como provisório" % id)
		_check(ItemIcons.has_icon(id), "%s tem ícone" % id)
	_check(not items.is_combat_item("bandagem"), "bandagem não é item de arremesso")
	_check(not cfg.game_data.has_entry("itens", "sal"), "o sal não existe no jogo (Léo, 19/11)")
	_check(not cfg.game_data.has_entry("itens", "granada_luz"), "a granada de luz saiu (Léo, 20/11: coquetel no lugar)")


func _test_coquetel() -> void:
	_fresh()
	var f := _agent()
	var c1 := cfg.make_enemy("cultista", Vector2(_m(6), 0))
	var c2 := cfg.make_enemy("cultista", Vector2(_m(6), _m(1.2)))
	var far := cfg.make_enemy("cultista", Vector2(_m(6), _m(6)))
	var ally := _agent(Vector2(_m(6), -_m(1)))
	var pv_ally := ally.pv
	var out := items.use(f, "coquetel", 1, c1.pos, null, [f, c1, c2, far, ally], NO_WALLS)
	_check(out.ok, "o Fernando arremessa o coquetel")
	_check(f.pa == 2, "coquetel gasta 1 PA")
	_check(c1.pv < c1.max_pv and c2.pv < c2.max_pv, "fogo fere os inimigos no raio")
	_check(far.pv == far.max_pv, "não atinge inimigo fora do raio")
	_check(ally.pv == pv_ally and not ally.has_condition("em_chamas"), "não atinge aliados")
	for u in [c1, c2]:
		if u.is_alive():
			_check(u.has_condition("em_chamas") and int(u.conditions["em_chamas"].rounds) in [1, 2], "Em chamas por 1 ou 2 turnos, sorteado (Léo, 20/11)")
	var seen := {}
	for s in 40:  # o sorteio dá os dois valores
		_fresh(s)
		var e := cfg.make_enemy("cultista", Vector2(_m(4), 0))
		e.max_pv = 999
		e.pv = 999
		var g := _agent()
		items.use(g, "coquetel", 1, e.pos, null, [g, e], NO_WALLS)
		seen[int(e.conditions["em_chamas"].rounds)] = true
	_check(seen.has(1) and seen.has(2) and seen.size() == 2, "o fogo sorteia 1 ou 2 turnos")
	# só o Fernando arremessa
	var n := cfg.make_agent("nikolai", Vector2.ZERO)
	n.pa = 3
	_check(not items.can_throw(n, "coquetel") and items.blocker(n, "coquetel", 1, Vector2(_m(4), 0)) == "requirement", "o Nikolai não arremessa o coquetel")
	_check(items.can_throw(n, "sinalizador"), "o sinalizador qualquer um usa")


func _test_range_and_walls() -> void:
	_fresh()
	var f := _agent()
	_check(items.blocker(f, "coquetel", 1, Vector2(_m(9) + f.radius, 0)) == "out_of_range", "coquetel além de 8 m: fora de alcance")
	var wall: Array[Rect2] = [Rect2(_m(2), -50, 10, 100)]
	_check(items.blocker(f, "coquetel", 1, Vector2(_m(4), 0), null, wall) == "no_line_of_sight", "parede bloqueia o arremesso")
	_check(items.blocker(f, "coquetel", 0, Vector2(_m(4), 0)) == "requirement", "sem o item na mochila não usa")
	f.pa = 0
	_check(items.blocker(f, "coquetel", 1, Vector2(_m(4), 0)) == "no_pa", "sem PA não usa")


func _test_flare() -> void:
	_fresh()
	var f := _agent()
	f.weapon = cfg.weapon("pistola")
	var lit := cfg.make_enemy("cultista", Vector2(_m(8), 0))
	var dark := cfg.make_enemy("cultista", Vector2(_m(8), _m(5)))
	var before := rules.hit_chance(f, lit)
	var out := items.use(f, "sinalizador", 1, lit.pos, null, [f, lit, dark], NO_WALLS)
	_check(out.ok and rules.lit_zones.size() == 1, "sinalizador aceso")
	_check(is_equal_approx(rules.hit_chance(f, lit), minf(before + 0.15, cfg.value("hit_chance_max"))), "+15% contra quem está na luz")
	_check(is_equal_approx(rules.hit_chance(f, dark), rules.hit_chance(f, dark) ) and rules.lit_bonus(f, dark) == 0.0, "sem bônus fora da luz")
	_check(rules.lit_bonus(lit, f) == 0.0, "inimigo não ganha bônus com o sinalizador")
	items.tick(lit)
	_check(rules.lit_zones.size() == 1, "turno do inimigo não apaga o sinalizador")
	for i in 3:
		items.tick(f)
	_check(rules.lit_zones.is_empty(), "apaga depois de 3 turnos de quem lançou")
	items.use(_agent(), "sinalizador", 1, lit.pos, null, [], NO_WALLS)
	items.clear()
	_check(rules.lit_zones.is_empty(), "fim do combate apaga os sinalizadores")


func _test_cost() -> void:
	_fresh()
	var f := _agent()
	f.pa = 1
	var c := cfg.make_enemy("cultista", Vector2(_m(4), 0))
	_check(items.use(f, "coquetel", 1, c.pos, null, [f, c], NO_WALLS).ok and f.pa == 0, "com 1 PA dá para usar")
	_check(items.use(f, "sinalizador", 1, c.pos, null, [f, c], NO_WALLS).reason == "no_pa", "sem PA, recusado")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("ok    ", label)
	else:
		failures += 1
		print("FALHA ", label)
