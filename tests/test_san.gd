extends SceneTree
# Teste headless da SAN como medidor de terror (perda, ruptura, loucura). Rodar com:
#   godot --headless --path . -s tests/test_san.gd

var failures := 0
var cfg: CombatConfig


func _init() -> void:
	cfg = CombatConfig.load_file()
	_test_loss_and_rupture()
	_test_rupture_debuffs()
	_test_insanity()
	_test_outside_combat()
	_test_scares()
	_test_presence()
	_test_recovery_and_stage()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _agent(san := 12) -> Combatant:
	var u := cfg.make_unit("agente", "Agente", Vector2.ZERO)
	u.max_san = san
	u.san = san
	return u


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	return r


func _test_loss_and_rupture() -> void:
	var s := SanRules.new(cfg, _rng())
	var a := _agent(5)
	s.start_combat([a])
	var r := s.lose(a, 3)
	_check(r.lost == 3 and a.san == 2 and not a.ruptured and not r.rupture, "perde SAN sem romper")
	r = s.lose(a, 5)
	_check(r.lost == 2 and a.san == 0, "SAN não fica negativa")
	_check(r.rupture and a.ruptured and a.ruptures_in_combat == 1, "SAN 0 = ruptura")
	_check(a.is_alive() and not a.insane, "ruptura não mata")


func _test_rupture_debuffs() -> void:
	var rules := CombatRules.new(cfg, _rng())
	var a := _agent()
	var e := cfg.make_enemy("cultista", Vector2(40, 0))
	a.pos = Vector2.ZERO
	var normal := rules.hit_chance(a, e)
	a.ruptured = true
	var broken := rules.hit_chance(a, e)
	_check(is_equal_approx(normal - broken, float(cfg.san("ruptura_acerto"))), "ruptura: -20% de acerto")
	var tm := TurnManager.new(3)
	_check(tm.turn_pa(a) == 2, "ruptura: -1 PA por turno")
	a.pa_per_turn = 1
	_check(tm.turn_pa(a) == 1, "ruptura: sempre sobra 1 PA")
	a.pa_per_turn = -1
	# dano: mesmo sorteio com e sem ruptura
	var dmg := []
	for broke in [false, true]:
		var r2 := CombatRules.new(cfg, _rng())
		var atk := _agent()
		atk.ruptured = broke
		atk.hit_bonus = 1.0
		atk.pa = 3
		var t := cfg.make_enemy("dama_sangue", Vector2(30, 0))
		t.defense = 0.0
		var res := r2.attack(atk, t, [] as Array[Rect2], [])
		dmg.append(res.damage)
	_check(dmg[1] == maxi(floori(dmg[0] * 0.8 + 0.0001), 1), "ruptura: -20% de dano " + str(dmg))


func _test_insanity() -> void:
	var s := SanRules.new(cfg, _rng())
	var a := _agent(4)
	s.start_combat([a])
	s.lose(a, 4)
	_check(a.ruptured, "primeira ruptura")
	var r := s.lose(a, 1)
	_check(r.insane and a.insane and a.dead and not a.is_alive(), "segunda vez a 0 no mesmo combate = loucura e morte")
	_check(s.lose(a, 3).lost == 0, "louco não perde mais nada")
	# a contagem zera entre combates
	var b := _agent(4)
	s.start_combat([b])
	s.lose(b, 4)
	s.end_combat([b])
	_check(b.ruptured and b.ruptures_in_combat == 0, "ruptura continua após o combate, contagem zera")
	s.start_combat([b])
	r = s.lose(b, 1)
	_check(not r.insane and b.ruptures_in_combat == 1, "rompido entra no combate e só enlouquece na segunda vez")
	r = s.lose(b, 1)
	_check(r.insane, "segunda vez no novo combate = loucura")
	# recuperar SAN no combate e cair de novo também conta
	var c := _agent(3)
	s.start_combat([c])
	s.lose(c, 3)
	s.recover(c, 2, true)
	_check(not c.ruptured and c.san == 2, "ritual de cura tira da ruptura")
	r = s.lose(c, 2)
	_check(r.insane, "chegar a 0 de novo após cura = loucura")


func _test_outside_combat() -> void:
	var s := SanRules.new(cfg, _rng())
	var a := _agent(2)
	var r := s.clue_read(a, {"perturbadora": true})
	_check(a.san == 0 and a.ruptured and r.rupture, "pista perturbadora pode romper fora de combate")
	r = s.clue_read(a, {"perda_san": 3})
	_check(not r.insane and not a.insane and a.is_alive(), "fora de combate ninguém enlouquece")
	_check(s.clue_loss({"texto": "nada"}) == 0, "pista comum não tira SAN")


func _test_scares() -> void:
	var s := SanRules.new(cfg, _rng())
	var a := _agent(12)
	var b := _agent(12)
	var party := [a, b]
	s.start_combat(party)
	var criatura := cfg.make_enemy("criatura_sangue", Vector2.ZERO)
	var res := s.enemy_seen(criatura, party)
	var terror := int(cfg.san("terror_ao_ver")["criatura_sangue"])
	_check(a.san == 12 - terror and b.san == 12 - terror and res.size() == 2, "ver a Criatura assusta o grupo")
	s.enemy_seen(cfg.make_enemy("criatura_sangue", Vector2.ZERO), party)
	_check(a.san == 12 - terror, "o mesmo tipo só assusta uma vez por combate")
	s.enemy_seen(cfg.make_enemy("cultista", Vector2.ZERO), party)
	_check(a.san == 12 - terror, "cultista não assusta")
	var before := b.san
	a.pv = 0
	s.ally_down(a, party)
	_check(b.san == before - int(cfg.san("perdas")["aliado_caido"]) and a.san == 12 - terror, "aliado caído assusta só os outros vivos")
	before = b.san
	s.ally_down(a, party, true)
	_check(b.san == before - int(cfg.san("perdas")["aliado_morto"]), "aliado morto assusta mais")
	before = b.san
	s.crit_taken(b)
	_check(b.san == before - int(cfg.san("perdas")["critico_recebido"]), "crítico recebido tira SAN")


func _test_presence() -> void:
	var s := SanRules.new(cfg, _rng())
	var a := _agent(500)
	s.pre[a] = 3
	_check(is_equal_approx(s.resist_chance(a), 0.2), "PRE 3 = 20% de resistir")
	var resisted := 0
	for i in 400:
		if s.lose(a, 1).resisted:
			resisted += 1
	_check(resisted > 50 and resisted < 110, "PRE resiste perto de 20%% (%d/400)" % resisted)
	var before := a.san
	s.pre[a] = 99
	_check(s.lose(a, 1, false).lost == 1 and a.san == before - 1, "custo de ritual não é resistido")


func _test_recovery_and_stage() -> void:
	var s := SanRules.new(cfg, _rng())
	var a := _agent(20)
	_check(s.stage(a) == SanRules.ESTAGIO_CALMO, "SAN cheia = calmo")
	a.san = 9
	_check(s.stage(a) == SanRules.ESTAGIO_ABALADO, "abaixo de 50% = abalado")
	a.san = 4
	_check(s.stage(a) == SanRules.ESTAGIO_BEIRA, "abaixo de 25% = à beira")
	s.lose(a, 10)
	_check(s.stage(a) == SanRules.ESTAGIO_RUPTURA, "0 = ruptura")
	s.recover(a, 5)
	_check(a.ruptured and a.san == 5, "recuperar SAN sem cura não tira a ruptura")
	s.rest(a)
	_check(not a.ruptured and a.san == 20, "descanso na zona segura cura tudo")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok  " + label)
	else:
		failures += 1
		print("  FALHOU  " + label)
