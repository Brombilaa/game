extends SceneTree
# Teste headless da passada de balanceamento da missão 1 (BalancoSim, 19/11/2026). Rodar com:
#   godot --headless --path . -s tests/test_balanceamento.gd
# As faixas são as metas provisórias do Claude, em campo aberto e sem rituais, itens nem cobertura
# (o jogador real faz melhor): vencer quase sempre os combates comuns, com alguém do grupo caindo
# em parte das lutas, para o combate pesar sem virar Game Over.

var failures := 0


func _init() -> void:
	var cfg := CombatConfig.load_file()
	var sim := BalancoSim.new(cfg, 19112026)
	var pv := {}
	for p in BalancoSim.GRUPO:
		pv[p] = cfg.make_agent(p, Vector2.ZERO).max_pv
	_check(pv == {"fernando": 23, "nikolai": 18, "miguel": 14}, "PV do grupo vêm das classes do GDD (%s)" % pv)
	_check(cfg.make_enemy("cultista", Vector2.ZERO).max_pv == 20 and cfg.make_enemy("atirador", Vector2.ZERO).max_pv == 14
		and cfg.make_enemy("dama_sangue", Vector2.ZERO).max_pv == 100, "PV dos inimigos do GDD (cultista 20, atirador 14, Dama 100, Léo 20/11)")
	for id in ["parque", "delegacia", "fazenda", "corredor"]:
		var r := sim.rodar(id, 150)
		_check(r.vitoria >= 0.9, "%s: o grupo vence quase sempre (%d%%)" % [id, roundi(r.vitoria * 100)])
		_check(r.algum_caiu >= 0.1 and r.algum_caiu <= 0.5, "%s: alguém cai em parte das lutas (%d%%)" % [id, roundi(r.algum_caiu * 100)])
		_check(r.rodadas <= 4.0, "%s: luta curta (%.1f rodadas)" % [id, r.rodadas])
	# Chefe: Roberto vira a Dama e, no limite do fim, o Fernando sai da luta (cena) e ela continua. Os 6 do salão
	# seguem o ritual e só lutam se forem atacados (Léo, 19/11), então a luta é contra Roberto e a Dama.
	var r := sim.rodar("salao", 150)
	_check(r.vitoria >= 0.15 and r.vitoria <= 0.7, "salão: luta difícil, mas possível sem rituais (%d%%)" % roundi(r.vitoria * 100))
	var todos: Dictionary = BalancoSim.ENCONTROS["salao"].duplicate(true)
	todos["ritual"] = 0
	_check(sim.rodar_encontro(todos, 60).vitoria < r.vitoria, "salão: com os 7 lutando desde o início é bem pior")
	# Quem está no ritual não age e acorda ao ser atacado, mesmo se o tiro errar.
	var rules := CombatRules.new(cfg)
	var a := cfg.make_agent("nikolai", Vector2.ZERO)
	var c := cfg.make_enemy("cultista", Vector2(64, 0))
	c.em_ritual = true
	a.pa = 3
	a.hit_bonus = -5.0  # erra com certeza (chance mínima 25%; repete até errar)
	var errou := false
	for i in 20:
		c.em_ritual = true
		a.pa = 3
		var res := rules.attack(a, c, [] as Array[Rect2], [])
		if res.ok and not res.hit:
			errou = true
			break
	_check(errou and not c.em_ritual, "ritual: o tiro que erra também acorda o cultista")
	c.em_ritual = true
	c.take_damage(1)
	_check(not c.em_ritual, "ritual: levar dano acorda")
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		failures += 1
		print("  FALHOU  ", label)
