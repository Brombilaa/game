extends SceneTree
# Compara onde o Roberto vira a Dama (limite) e se a Dama entra na fase 2 aos 50% de PV (fase2_pv; 0 = só quando
# os corpos acabam, como no roteiro). Rodar: godot --headless --path . -s tools/balanceamento_50.gd -- [lutas]


func _init() -> void:
	var n := 400
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var cfg := CombatConfig.load_file()
	var variantes := [
		["A. Atual: Roberto vira a 50%, fase 2 da Dama a 50%", 0.5, 0.5],
		["B. Roteiro puro: Roberto vira a 25%, fase 2 só com os corpos", 0.25, 0.0],
		["C. Roberto a 50%, fase 2 só com os corpos", 0.5, 0.0],
		["D. Roberto a 25%, fase 2 da Dama a 50%", 0.25, 0.5],
	]
	for v in variantes:
		var sim := BalancoSim.new(cfg, 22112026)
		var e: Dictionary = BalancoSim.ENCONTROS["salao"].duplicate(true)
		e["chefe"]["limite"] = v[1]
		e["chefe"]["fase2_pv"] = v[2]
		var r := sim.rodar_encontro(e, n)
		print("%s | vitória %d%% | rodadas %.1f | PV que sobra %d%% | caídos por luta %.2f | lutas com alguém caído %d%%" % [v[0], roundi(r.vitoria * 100), r.rodadas, roundi(r.pv_sobra * 100), r.caidos, roundi(r.algum_caiu * 100)])
	quit(0)
