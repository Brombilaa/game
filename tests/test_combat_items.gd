extends SceneTree
# Teste headless dos itens de uso em combate (granada de luz e sinalizador). Rodar com:
#   godot --headless --path . -s tests/test_combat_items.gd

var failures := 0
var cfg: CombatConfig
var rules: CombatRules
var items: ItemRules
const NO_WALLS: Array[Rect2] = []


func _init() -> void:
	cfg = CombatConfig.load_file()
	_test_data()
	_test_flashbang()
	_test_flashbang_range_and_walls()
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
	_check(items.combat_items() == ["granada_luz", "sinalizador", "coquetel_molotov", "fertilizante", "agrotoxico", "garrafa_agua", "balde_agua", "bulbo_bravo_purpulis"],
		"itens de combate em itens.json: granada, sinalizador e os das flores da Dama (sem sal, Léo 19/11)")
	for id in items.combat_items():
		_check(items.cost(id) == 1, "%s custa 1 PA (custo de usar item)" % id)
		_check(cfg.game_data.provisional.has("itens." + id), "%s marcado como provisório" % id)
		_check(ItemIcons.has_icon(id), "%s tem ícone" % id)
	_check(not items.is_combat_item("bandagem"), "bandagem não é item de arremesso")
	_check(not cfg.game_data.has_entry("itens", "sal"), "o sal não existe no jogo (Léo, 19/11)")


func _test_flashbang() -> void:
	_fresh()
	var f := _agent()
	var c1 := cfg.make_enemy("cultista", Vector2(_m(6), 0))
	var c2 := cfg.make_enemy("cultista", Vector2(_m(6), _m(1.5)))
	var far := cfg.make_enemy("cultista", Vector2(_m(6), _m(6)))
	var dama := cfg.make_enemy("dama_sangue", Vector2(_m(7), 0))
	var ally := _agent(Vector2(_m(6), -_m(1)))
	var out := items.use(f, "granada_luz", 1, c1.pos, null, [f, c1, c2, far, dama, ally], NO_WALLS)
	_check(out.ok, "granada de luz sai")
	_check(f.pa == 2, "granada gasta 1 PA")
	_check(c1.has_condition("atordoado") and c2.has_condition("atordoado"), "atordoa os inimigos no raio")
	_check(not far.has_condition("atordoado"), "não atinge inimigo fora do raio")
	_check(not dama.has_condition("atordoado") and out.immune.has(dama), "Dama de Sangue é imune a atordoar")
	_check(not ally.has_condition("atordoado"), "não atinge aliados")
	var fx := rules.start_turn_effects(c1)
	_check(fx.skip, "atordoado perde o próximo turno")
	_check(not c1.has_condition("atordoado"), "atordoado dura um turno")


func _test_flashbang_range_and_walls() -> void:
	_fresh()
	var f := _agent()
	_check(items.blocker(f, "granada_luz", 1, Vector2(_m(9) + f.radius, 0)) == "out_of_range", "granada além de 8 m: fora de alcance")
	var wall: Array[Rect2] = [Rect2(_m(2), -50, 10, 100)]
	_check(items.blocker(f, "granada_luz", 1, Vector2(_m(4), 0), null, wall) == "no_line_of_sight", "parede bloqueia o arremesso")
	_check(items.blocker(f, "granada_luz", 0, Vector2(_m(4), 0)) == "requirement", "sem o item na mochila não usa")
	f.pa = 0
	_check(items.blocker(f, "granada_luz", 1, Vector2(_m(4), 0)) == "no_pa", "sem PA não usa")


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
	_check(items.use(f, "granada_luz", 1, c.pos, null, [f, c], NO_WALLS).ok and f.pa == 0, "com 1 PA dá para usar")
	_check(items.use(f, "sinalizador", 1, c.pos, null, [f, c], NO_WALLS).reason == "no_pa", "sem PA, recusado")


func _check(cond: bool, label: String) -> void:
	if cond:
		print("ok    ", label)
	else:
		failures += 1
		print("FALHA ", label)
