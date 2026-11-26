extends SceneTree
# Teste headless das fraquezas e resistências dos inimigos: afinidade por tipo de dano, multiplicador no tiro, no
# golpe e no ritual, descoberta por pista e no combate (entra no diário uma vez só), ida e volta no save e
# consistência de data/fraquezas.json com inimigos.json e com as pistas dos cenários. Rodar com:
#   godot --headless --path . -s tests/test_fraquezas.gd

var failures := 0
var cfg: CombatConfig
const NO_WALLS: Array[Rect2] = []


func _initialize() -> void:
	cfg = CombatConfig.load_file()
	Missao1.reiniciar()
	_afinidades()
	_dano_arma()
	_dano_ritual()
	_descoberta()
	_criaturas()
	_dados()
	Missao1.reiniciar()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_fraquezas")
	quit(1 if failures > 0 else 0)


func _afinidades() -> void:
	var gd := cfg.game_data
	_check(Fraquezas.afinidade(gd, "criatura_sangue", "balistico") == "resistencia", "Criatura resiste a bala")
	_check(Fraquezas.afinidade(gd, "criatura_sangue", "ritual") == "fraqueza", "Criatura é fraca a ritual")
	_check(Fraquezas.afinidade(gd, "cultista", "ritual") == "", "cultista é neutro a ritual (Léo, 22/11)")
	_check(Fraquezas.afinidade(gd, "roberto_ghular", "ritual") == "" and Fraquezas.afinidade(gd, "dama_sangue", "ritual") == "", "Roberto e Dama são neutros a ritual (Léo, 22/11)")
	_check(Fraquezas.afinidade(gd, "atirador", "corpo_a_corpo") == "fraqueza", "atirador é fraco de perto")
	_check(Fraquezas.afinidade(gd, "cultista", "balistico") == "", "cultista é neutro a bala")
	_check(Fraquezas.afinidade(gd, "", "ritual") == "", "agente não tem afinidade")
	_check(Fraquezas.afinidade(gd, "dama_sangue", "atordoado") == "resistencia", "imunidade a atordoar continua na lista")
	_check(is_equal_approx(Fraquezas.multiplicador("fraqueza"), 1.5) and is_equal_approx(Fraquezas.multiplicador("resistencia"), 0.5), "multiplicadores provisórios")
	_check(is_equal_approx(Fraquezas.multiplicador(""), 1.0), "sem afinidade o dano não muda")
	_check(Fraquezas.titulo(gd, "criatura_sangue", "ritual") == "Zumbi de Sangue: rituais ferem mais", "título da fraqueza")
	_check(Fraquezas.titulo(gd, "atirador", "corpo_a_corpo") == "Atirador: golpes corpo a corpo ferem mais", "título da fraqueza do atirador")
	_check(Fraquezas.titulo(gd, "criatura_sangue", "balistico") == "Zumbi de Sangue: balas ferem menos", "título da resistência")


# Tiro fixo de 6: na Criatura (resiste a bala) sai 3, no cultista 6; crítico dobra antes da resistência.
func _dano_arma() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rules := CombatRules.new(cfg, rng)
	var resist := 0
	var normal := 0
	var fraco := 0
	for i in 120:
		var a := cfg.make_agent("fernando", Vector2.ZERO)
		a.weapon = a.weapon.duplicate()
		a.weapon["damage_min"] = 6
		a.weapon["damage_max"] = 6
		a.weapon["base_chance"] = 1.0
		a.weapon["mag_size"] = 0
		a.hit_bonus = 1.0
		a.pa = 3
		var kind: String = ["criatura_sangue", "cultista"][i % 2]
		var t := cfg.make_enemy(kind, Vector2(20, 0))
		t.pv = 100
		t.max_pv = 100
		t.defense = 0.0
		var r := rules.attack(a, t, NO_WALLS, [])
		if not r.hit:
			continue
		var base := 12 if r.crit else 6
		_check(r.tipo_dano == ("corpo_a_corpo" if a.weapon.get("melee", false) else "balistico"), "tipo de dano da arma") if i < 2 else null
		if kind == "criatura_sangue":
			_check(r.afinidade == "resistencia" and r.damage == base / 2, "bala na Criatura sai pela metade (%d)" % r.damage) if not a.weapon.get("melee", false) else null
			resist += 1
		else:
			_check(r.afinidade == "" and r.damage == base, "cultista leva o dano cheio (%d)" % r.damage)
			normal += 1
	_check(resist > 0 and normal > 0, "acertou os dois alvos")
	# Soco no atirador (fraco de perto): 2 fixo vira 3.
	for i in 40:
		var a := cfg.make_agent("fernando", Vector2.ZERO)
		a.weapon = cfg.weapon("soco")
		a.atributos = {}  # sem bônus de Força no soco
		a.weapon["damage_min"] = 2
		a.weapon["damage_max"] = 2
		a.weapon["base_chance"] = 1.0
		a.hit_bonus = 1.0
		a.pa = 3
		var t := cfg.make_enemy("atirador", Vector2(20, 0))
		t.pv = 100
		t.max_pv = 100
		var r := rules.attack(a, t, NO_WALLS, [])
		if r.hit and not r.crit:
			_check(r.afinidade == "fraqueza" and r.damage == 3, "soco no atirador leva +50%% (%d)" % r.damage)
			fraco += 1
	_check(fraco > 0, "soco acertou o atirador")


func _dano_ritual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rules := CombatRules.new(cfg, rng)
	var rit := RitualRules.new(cfg, rules, SanRules.new(cfg, rng), rng)
	rit.inventory = Inventory.new(cfg.game_data)  # a Eletrocussão gasta um componente de Energia
	for iid in rit.component_items(rit.element("eletrocussao")):
		rit.inventory.add(iid, 5)
	var m := cfg.make_agent("miguel", Vector2.ZERO, {"VIG": 1, "FOR": 1, "INT": 1, "AGI": 1, "PRE": 1})
	m.max_san = 50
	m.san = 50
	for kind in ["criatura_sangue", "cultista", "atirador"]:
		var t := cfg.make_enemy(kind, Vector2(100, 0))
		t.pv = 200
		t.max_pv = 200
		t.defense = 0.0
		m.pa = 3
		var out := rit.cast(m, "eletrocussao", t, NO_WALLS, [])
		_check(out.ok and out.tipo_dano == "ritual", "Eletrocussão é dano de ritual (%s)" % kind)
		match kind:
			"criatura_sangue":
				_check(out.afinidade == "fraqueza" and out.damage >= 12 and out.damage <= 18, "Criatura leva 8-12 x1,5 (%d)" % out.damage)
			"cultista":
				_check(out.afinidade == "" and out.damage >= 8 and out.damage <= 12, "cultista leva o dano normal (%d)" % out.damage)
			"atirador":
				_check(out.afinidade == "" and out.damage >= 8 and out.damage <= 12, "atirador leva o dano normal (%d)" % out.damage)


func _descoberta() -> void:
	Missao1.reiniciar()
	var gd := cfg.game_data
	_check(not Fraquezas.conhecida("criatura_sangue", "balistico"), "começa sem saber")
	_check(Fraquezas.ao_examinar(gd, "balanco").is_empty(), "pista sem descoberta não anota nada")
	var novas := Fraquezas.ao_examinar(gd, "banco_quebrado")
	_check(novas == ["Zumbi de Sangue: balas ferem menos"], "o banco quebrado ensina a resistência da Criatura")
	_check(Fraquezas.conhecida("criatura_sangue", "balistico"), "fica conhecida")
	var e: Dictionary = Missao1.diario[Missao1.diario.size() - 1]
	_check(e["lugar"] == Fraquezas.LUGAR and e["id"] == "frq_criatura_sangue_balistico", "entra no diário em INIMIGOS")
	_check(Fraquezas.ao_examinar(gd, "banco_quebrado").is_empty(), "examinar de novo não repete")
	# No combate: primeira vez anota, depois só mostra o aviso.
	var t := cfg.make_enemy("atirador", Vector2.ZERO)
	var r := {"afinidade": "fraqueza", "tipo_dano": "corpo_a_corpo"}
	var f := Fraquezas.ao_acertar(gd, t, r)
	_check(f["popup"] == "FRAQUEZA" and f["nova"], "o primeiro golpe de perto no atirador revela a fraqueza")
	_check(str(Missao1.diario[Missao1.diario.size() - 1]["texto"]).contains("fuzil"), "usa o texto de combate")
	f = Fraquezas.ao_acertar(gd, t, r)
	_check(f["popup"] == "FRAQUEZA" and not f["nova"], "o segundo só mostra o aviso")
	_check(Fraquezas.ao_acertar(gd, t, {"afinidade": "", "tipo_dano": "balistico"})["popup"] == "", "golpe neutro não avisa")
	_check(Fraquezas.ao_acertar(gd, cfg.make_agent("fernando", Vector2.ZERO), r)["popup"] == "", "agente não tem afinidade")
	var n := Missao1.diario.size()
	var salvo := JSON.parse_string(JSON.stringify(Missao1.diario)) as Array
	Missao1.reiniciar()
	Missao1.diario = Diario.ler(salvo)
	_check(Missao1.diario.size() == n and Fraquezas.conhecida("atirador", "corpo_a_corpo") and Fraquezas.conhecida("criatura_sangue", "balistico"), "as descobertas voltam do save com o diário")


# Seção CRIATURAS (caderno do Miguel): só entra quem foi visto ou tem descoberta; o que falta vem como não conhecido.
func _criaturas() -> void:
	Missao1.reiniciar()
	var gd := cfg.game_data
	_check(Fraquezas.criaturas(gd).is_empty(), "caderno começa vazio")
	Fraquezas.ver("atirador")
	var cs := Fraquezas.criaturas(gd)
	_check(cs.size() == 1 and cs[0]["kind"] == "atirador" and not cs[0]["afinidades"][0]["conhecida"], "visto em combate entra sem nada descoberto")
	Fraquezas.ao_examinar(gd, "banco_quebrado")
	cs = Fraquezas.criaturas(gd)
	_check(cs.size() == 2, "descoberta por pista também faz a criatura entrar")
	for c in cs:
		_check(str(c["nota"]) != "", "nota do Miguel: " + str(c["kind"]))
		if c["kind"] == "criatura_sangue":
			var sabe := 0
			for a in c["afinidades"]:
				sabe += 1 if a["conhecida"] else 0
				_check(str(a["miguel"]) != "", "fala do Miguel em cada descoberta")
			_check(c["afinidades"].size() == 2 and sabe == 1, "Criatura com 1 de 2 anotadas")
	var fichas: Dictionary = Fraquezas.dados()["criaturas"]
	for id in gd.ids("inimigos"):
		_check(fichas.has(id), "todo inimigo tem página no caderno: " + id)


func _dados() -> void:
	var gd := cfg.game_data
	var pistas := {}
	for f in DirAccess.get_files_at("res://data/cenarios"):
		if not f.ends_with(".json"):
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cenarios/" + f))
		for c in d.get("pistas", []):
			pistas[c["id"]] = true
	var tipos: Dictionary = Fraquezas.dados()["tipos"]
	var cobertas := {}
	for d in Fraquezas.descobertas():
		var k := "%s/%s" % [d["inimigo"], d["tipo"]]
		_check(not cobertas.has(k), "descoberta única: " + k)
		cobertas[k] = true
		_check(Fraquezas.afinidade(gd, d["inimigo"], d["tipo"]) != "", "a descoberta existe em inimigos.json: " + k)
		_check(str(d["texto"]) != "" and str(d.get("combate", "")) != "", "texto de pista e de combate: " + k)
		for p in d["pistas"]:
			_check(pistas.has(p), "pista existe nos cenários: " + str(p))
	for id in gd.ids("inimigos"):
		var e := gd.get_entry("inimigos", id)
		for tipo in (e["fraquezas"] as Array) + (e["resistencias"] as Array):
			if tipo == "atordoado":
				continue
			_check(tipos.has(tipo), "tipo de dano conhecido: %s/%s" % [id, tipo])
			_check(cobertas.has("%s/%s" % [id, tipo]), "toda afinidade tem como ser descoberta: %s/%s" % [id, tipo])


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FALHOU: " + what)
