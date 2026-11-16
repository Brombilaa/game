extends SceneTree
# Teste headless das fichas do GDD (classe + atributos). Rodar com:
#   godot --headless --path . -s tests/test_ficha.gd

var failures := 0
var cfg: CombatConfig


func _init() -> void:
	cfg = CombatConfig.load_file()
	Ficha.reiniciar()
	_test_distribuicao()
	_test_pv_san()
	_test_agentes()
	_test_bonus()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _test_distribuicao() -> void:
	var d := cfg.game_data
	var a := Ficha.em_branco(d)
	_check(a == {"VIG": 1, "FOR": 1, "INT": 1, "AGI": 1, "PRE": 1}, "todos os atributos começam em 1")
	_check(Ficha.pontos_restantes(d, a) == 4, "4 pontos para distribuir")
	_check(Ficha.validar(d, a) == "Ainda sobram 4 pontos", "ficha com pontos sobrando não vale")
	_check(Ficha.ajustar(d, a, "VIG", 1) and Ficha.ajustar(d, a, "VIG", 1), "sobe o Vigor duas vezes")
	_check(not Ficha.ajustar(d, a, "VIG", 1) and a["VIG"] == 3, "não passa do máximo inicial 3")
	_check(not Ficha.ajustar(d, a, "FOR", -1), "não desce abaixo de 1")
	Ficha.ajustar(d, a, "FOR", 1)
	Ficha.ajustar(d, a, "AGI", 1)
	_check(not Ficha.ajustar(d, a, "PRE", 1), "sem pontos, não sobe mais nada")
	_check(Ficha.validar(d, a) == "", "4 pontos gastos: ficha válida")
	_check(Ficha.validar(d, {"VIG": 3, "FOR": 3, "INT": 3, "AGI": 1, "PRE": 1}) == "Pontos demais: tire 2", "pontos demais não vale")
	_check(Ficha.validar(d, {"VIG": 4, "FOR": 1, "INT": 1, "AGI": 1, "PRE": 3}) != "", "atributo acima de 3 não vale")
	for p in ["fernando", "nikolai", "miguel"]:
		_check(Ficha.validar(d, Ficha.sugeridos(d, p)) == "", "distribuição sugerida de %s é válida" % p)


func _test_pv_san() -> void:
	var d := cfg.game_data
	var a := {"VIG": 3, "FOR": 2, "INT": 1, "AGI": 2, "PRE": 1}
	_check(Ficha.pv_max(d, "combatente", a) == 23, "Combatente com VIG 3: 20 + 3 = 23 PV")
	_check(Ficha.pv_max(d, "combatente", a, 2) == 30, "nível 2: +4 + VIG 3 = 30 PV")
	_check(Ficha.pv_max(d, "ocultista", {"VIG": 1}) == 13, "Ocultista com VIG 1: 12 + 1 = 13 PV")
	_check(Ficha.san_max(d, "combatente", a) == 12, "Combatente com PRE 1: SAN 12")
	_check(Ficha.san_max(d, "ocultista", {"PRE": 2}) == 22, "Ocultista com PRE 2: 20 + 2 = 22 SAN")
	_check(Ficha.san_max(d, "especialista", {"PRE": 1}, 2) == 20, "Especialista nível 2: 16 + 4 = 20 SAN")


func _test_agentes() -> void:
	var f := cfg.make_agent("fernando", Vector2.ZERO)
	_check(f.name == "Fernando" and f.personagem == "fernando", "Fernando nasce da ficha de personagens.json")
	_check(f.max_pv == 23 and f.pv == 23 and f.max_san == 12, "Fernando (Combatente, VIG 3): 23 PV e 12 SAN")
	_check(f.initiative == 2 and f.weapon["id"] == "pistola", "iniciativa = AGI 2; arma inicial pistola")
	var n := cfg.make_agent("nikolai", Vector2.ZERO)
	_check(n.max_pv == 18 and n.max_san == 16 and n.initiative == 3, "Nikolai (Especialista, VIG 2, AGI 3): 18 PV, 16 SAN, iniciativa 3")
	var m := cfg.make_agent("miguel", Vector2.ZERO)
	_check(m.max_pv == 14 and m.max_san == 22 and m.weapon["id"] == "espada", "Miguel (Ocultista, VIG 2, PRE 2): 14 PV, 22 SAN, espada")
	Ficha.escolhas["fernando"] = {"VIG": 1, "FOR": 3, "INT": 1, "AGI": 3, "PRE": 1}
	var f2 := cfg.make_agent("fernando", Vector2.ZERO)
	_check(f2.max_pv == 21 and f2.initiative == 3, "a escolha do jogador vale: VIG 1 = 21 PV, AGI 3 = iniciativa 3")
	Ficha.reiniciar()


func _test_bonus() -> void:
	var d := cfg.game_data
	var forte := {"FOR": 3, "INT": 3}
	_check(Ficha.bonus_dano(d, forte, cfg.weapon("espada")) == 2, "FOR 3: +2 de dano na espada")
	_check(Ficha.bonus_dano(d, forte, cfg.weapon("escopeta")) == 2, "FOR 3: +2 de dano na escopeta")
	_check(Ficha.bonus_dano(d, forte, cfg.weapon("pistola")) == 0, "FOR não soma na pistola")
	_check(Ficha.bonus_dano(d, {}, cfg.weapon("espada")) == 0, "inimigo (sem atributos) não ganha bônus")
	_check(Ficha.bonus_ritual(d, forte) == 2, "INT 3: +2 no ritual")
	# O bônus da Força entra no dano do ataque: soco 1-2 com FOR 3 dá 3-4 (sem crítico, sem defesa).
	var rules := CombatRules.new(cfg)
	var a := cfg.make_agent("fernando", Vector2(0, 0), {"VIG": 1, "FOR": 3, "INT": 1, "AGI": 1, "PRE": 3})
	a.weapon = cfg.weapon("soco")
	var ok := true
	for i in 40:
		var alvo := cfg.make_enemy("cultista", Vector2(a.radius + 10.0 + 4.0, 0))
		a.pa = 3
		var r := rules.attack(a, alvo, [] as Array[Rect2], [])
		if r.hit and not r.crit and (r.damage < 3 or r.damage > 4):
			ok = false
	_check(ok, "soco com FOR 3 causa 3 a 4 de dano")


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
