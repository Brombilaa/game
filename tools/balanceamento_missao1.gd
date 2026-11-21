extends SceneTree
# Relatório do simulador de balanceamento da missão 1 (BalancoSim). Rodar com:
#   godot --headless --path . -s tools/balanceamento_missao1.gd -- [lutas por encontro]


func _init() -> void:
	var n := 400
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var cfg := CombatConfig.load_file()
	var sim := BalancoSim.new(cfg, 19112026)
	for p in BalancoSim.GRUPO:
		var a := cfg.make_agent(p, Vector2.ZERO)
		print("%s: %d PV, AGI %d, %s %s" % [a.name, a.max_pv, a.initiative, a.weapon["id"], [a.weapon["damage_min"], a.weapon["damage_max"]]])
	print("encontro | vitória | rodadas | PV que sobra | caídos por luta | lutas com alguém caído")
	for id in BalancoSim.ENCONTROS:
		var r := sim.rodar(id, n)
		print("%s | %d%% | %.1f | %d%% | %.2f | %d%%" % [r.nome, roundi(r.vitoria * 100), r.rodadas, roundi(r.pv_sobra * 100), r.caidos, roundi(r.algum_caiu * 100)])
	quit(0)
