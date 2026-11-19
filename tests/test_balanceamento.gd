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
		and cfg.make_enemy("dama_sangue", Vector2.ZERO).max_pv == 120, "PV dos inimigos do GDD (cultista 20, atirador 14, Dama 120)")
	for id in ["parque", "delegacia", "fazenda", "corredor"]:
		var r := sim.rodar(id, 150)
		_check(r.vitoria >= 0.9, "%s: o grupo vence quase sempre (%d%%)" % [id, roundi(r.vitoria * 100)])
		_check(r.algum_caiu >= 0.1 and r.algum_caiu <= 0.5, "%s: alguém cai em parte das lutas (%d%%)" % [id, roundi(r.algum_caiu * 100)])
		_check(r.rodadas <= 4.0, "%s: luta curta (%.1f rodadas)" % [id, r.rodadas])
	# Chefe: Roberto vira a Dama e, no limite do fim, o Fernando sai da luta (cena) e ela continua.
	var chefe: Dictionary = BalancoSim.ENCONTROS["salao"].duplicate(true)
	chefe["inimigos"] = ["atirador", "roberto_ghular"]
	var r := sim.rodar_encontro(chefe, 150)
	_check(r.vitoria >= 0.15 and r.vitoria <= 0.7, "Roberto e Dama: luta difícil, mas possível sem rituais (%d%%)" % roundi(r.vitoria * 100))
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		failures += 1
		print("  FALHOU  ", label)
