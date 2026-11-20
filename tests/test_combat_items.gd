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
	_check(items.combat_items() == ["coquetel", "sinalizador"], "dois itens de combate em itens.json: coquetel no lugar da granada (Léo 20/11), sem sal (Léo 19/11)")
	for id in items.combat_items():
		_check(items.cost(id) == 1, "%s custa 1 PA (custo de usar item)" % id)
		_check(cfg.game_data.provisional.has("itens." + id), "%s marcado como provisório" % id)
		_check(ItemIcons.has_icon(id), "%s tem ícone" % id)
	_check(not items.is_combat_item("bandagem"), "bandagem não é item de arremesso")
	_check(not cfg.game_data.has_entry("itens", "sal") and not cfg.game_data.has_entry("itens", "granada_luz"), "nem sal (Léo, 19/11) nem granada de luz (Léo, 20/11)")


func _test_coquetel() -> void:
	_fresh()
	var f := _agent()
	var c1 := cfg.make_enemy("cultista", Vector2(_m(6), 0))
	var c2 := cfg.make_enemy("cultista", Vector2(_m(6), _m(1.5)))
	var far := cfg.make_enemy("cultista", Vector2(_m(6), _m(6)))
	var ally := _agent(Vector2(_m(6), -_m(1)))
	for c in [c1, c2, far]:
		c.max_pv = 100
		c.pv = 100
	var pv_ally := ally.pv
	var out := items.use(f, "coquetel", 1, c1.pos, null, [f, c1, c2, far, ally], NO_WALLS)
	_check(out.ok and f.pa == 2, "coquetel sai e gasta 1 PA")
	_check(out.tipo_dano == "fogo", "o dano é de fogo")
	_check(c1.pv <= 90 and c2.pv <= 90, "queima os inimigos no raio com 10 ou mais de dano (flor Amarela)")
	_check(c1.has_condition("em_chamas") and c2.has_condition("em_chamas"), "deixa os inimigos em chamas")
	_check(far.pv == 100 and not far.has_condition("em_chamas"), "não atinge inimigo fora do raio")
	_check(ally.pv == pv_ally and not ally.has_condition("em_chamas"), "não atinge aliados")
	for i in 30:  # o mínimo continua 10 ou mais mesmo com 10% de defesa
		_fresh(i)
		var d := cfg.make_enemy("dama_sangue", Vector2(_m(4), 0))
		d.defense = 0.1
		d.max_pv = 500
		d.pv = 500
		var u := _agent()
		items.use(u, "coquetel", 1, d.pos, null, [u, d], NO_WALLS)
		if d.pv > 490:
			_check(false, "coquetel tirou menos de 10 da Dama com 10%% de defesa (semente %d)" % i)
			break
	var nik := cfg.make_agent("nikolai", Vector2.ZERO)
	nik.pa = 3
	_check(not items.can_throw(nik, "coquetel") and items.blocker(nik, "coquetel", 1, Vector2(_m(4), 0)) == "requirement", "só o Fernando arremessa o coquetel")
	_check(items.can_throw(nik, "sinalizador"), "o sinalizador qualquer um usa")


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
