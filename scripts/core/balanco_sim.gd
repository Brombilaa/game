class_name BalancoSim
extends RefCounted
# Simulador de balanceamento da missão 1 (passada de 19/11/2026, provisória até o Léo jogar).
# Joga os combates da missão muitas vezes com as regras reais (CombatRules, TurnManager, fichas do GDD)
# e mede vitória, rodadas, PV que sobram e quantos do grupo caem.
#
# Simplificações (o jogo real é mais favorável ao grupo, porque o jogador pensa):
#   - campo aberto: sem paredes, sem cobertura, sem flanco planejado, sem mira, sem furtividade;
#   - o grupo não usa rituais, itens, kits nem reanimação; cada membro entra com a arma (principal ou secundária)
#     que rende mais dano por turno na distância inicial, como o jogador escolheria antes de abrir fogo;
#   - inimigos de corpo a corpo andam reto até o alvo; atiradores ficam parados no lugar em que começam;
#   - inimigo escolhe o membro vivo mais perto, respeitando no máximo 2 atacantes por alvo (como EnemyAi);
#   - o grupo atira no inimigo mais ferido ao alcance (o Miguel vai no mais perto, de espada) e não mexe com
#     quem está no ritual (cripta) enquanto houver outro inimigo lutando; o tiro que erra também acorda.
# A SAN não entra: o medidor de terror é outra passada.

const GRUPO := ["fernando", "nikolai", "miguel"]

# Encontros da missão 1 na main (cenários em data/cenarios). dist_m = distância inicial do grupo até os inimigos.
# surpresa: lado que age todo primeiro na rodada 1 (como no jogo). chefe: Roberto vira a Dama a 25% do PV e o
# Fernando morre na cena do tentáculo quando a Dama chega ao limite do fim (cripta.json); a luta segue até a Dama morrer.
const ENCONTROS := {
	"parque": {"nome": "Parque: 2 Criaturas de Sangue", "inimigos": ["criatura_sangue", "criatura_sangue"], "dist_m": 8.0, "surpresa": Combatant.Side.ENEMY},
	"delegacia": {"nome": "Delegacia 21h: invasão de 3 atiradores", "inimigos": ["atirador", "atirador", "atirador"], "dist_m": 9.0, "surpresa": Combatant.Side.ENEMY},
	"fazenda": {"nome": "Fazenda: 3 atiradores", "inimigos": ["atirador", "atirador", "atirador"], "dist_m": 10.0, "surpresa": -1},
	"corredor": {"nome": "Cripta, corredor: 2 cultistas", "inimigos": ["cultista", "cultista"], "dist_m": 7.0, "surpresa": -1},
	# Salão (Léo: 7 inimigos contando Roberto). Léo (19/11): os 6 em volta do Roberto seguem o ritual e só lutam
	# se forem atacados ("ritual": quantos dos primeiros da lista começam em ritual). Limites como em cripta.json.
	"salao": {"nome": "Cripta, salão: 4 cultistas e 2 atiradores no ritual, Roberto e a Dama", "inimigos": ["cultista", "cultista", "cultista", "cultista", "atirador", "atirador", "roberto_ghular"], "ritual": 6, "dist_m": 9.0, "surpresa": -1, "chefe": {"de": "roberto_ghular", "limite": 0.5, "vira": "dama_sangue", "fim": 0.15}},
}

const MAX_RODADAS := 40
# Dano médio em PV da habilidade de cada flor que abre na fase 1 da Dama (Laranja, Rosa, Roxa, Amarela, Verde, Azul;
# dama_sangue.json): Visão, Grito e Prisão não tiram PV; Espinhos e Miasma contados num alvo só.
const DANO_FLORES_FASE1 := [0, 10, 0, 9, 0, 8]

var cfg: CombatConfig
var rng := RandomNumberGenerator.new()


func _init(config: CombatConfig, seed_value := 1) -> void:
	cfg = config
	rng.seed = seed_value


# Joga `n` vezes o encontro e devolve as médias.
func rodar(encontro: String, n: int) -> Dictionary:
	var r := rodar_encontro(ENCONTROS[encontro], n)
	r["encontro"] = encontro
	return r


# Igual a rodar(), para um encontro montado na hora (variantes do salão, testes).
func rodar_encontro(e: Dictionary, n: int) -> Dictionary:
	var vitorias := 0
	var rodadas := 0
	var pv_sobra := 0.0
	var caidos := 0
	var algum_caiu := 0
	for i in n:
		var r := lutar(e)
		if r.vitoria:
			vitorias += 1
			rodadas += r.rodadas
			pv_sobra += r.pv_sobra
		caidos += r.caidos
		if r.caidos > 0:
			algum_caiu += 1
	return {
		"nome": e["nome"],
		"vitoria": float(vitorias) / n,
		"rodadas": float(rodadas) / maxi(vitorias, 1),
		"pv_sobra": pv_sobra / maxi(vitorias, 1),
		"caidos": float(caidos) / n,
		"algum_caiu": float(algum_caiu) / n,
	}


# Uma luta. Retorna {vitoria, rodadas, pv_sobra (fração do PV total do grupo), caidos}.
func lutar(e: Dictionary) -> Dictionary:
	var rules := CombatRules.new(cfg, rng)
	var ppm := cfg.value("pixels_per_meter")
	var units: Array[Combatant] = []
	var grupo: Array[Combatant] = []
	for i in GRUPO.size():
		var a := cfg.make_agent(GRUPO[i], Vector2(0, (i - 1) * 40.0))
		a.weapon = _melhor_arma(rules, a, float(e["dist_m"]) * ppm)
		if int(a.weapon.get("mag_size", 0)) > 0:
			a.mag[a.weapon["id"]] = int(a.weapon["mag_size"])
		grupo.append(a)
		units.append(a)
	var lista: Array = e["inimigos"]
	for i in lista.size():
		var y := (i - (lista.size() - 1) / 2.0) * 50.0
		var inimigo := cfg.make_enemy(lista[i], Vector2(float(e["dist_m"]) * ppm, y))
		inimigo.em_ritual = i < int(e.get("ritual", 0))
		units.append(inimigo)
	rules.units = units
	var turns := TurnManager.new(int(cfg.value("pa_per_turn")))
	turns.start(units, int(e["surpresa"]))
	var chefe: Dictionary = e.get("chefe", {})
	var dama: Combatant = null
	var fim := false
	var fase_dama := 1
	var dama_turnos := 0
	var roteirizado: Combatant = null  # Fernando morto pela cena (não conta como caído)
	var atacantes := {}  # alvo -> quantos inimigos o atacaram nesta rodada
	var rodada := 0
	while turns.state == TurnManager.State.ACTIVE and turns.round_number <= MAX_RODADAS:
		if turns.round_number != rodada:
			rodada = turns.round_number
			atacantes.clear()
		var u := turns.current
		if u == null:
			break
		if u.em_ritual:
			turns.end_turn()  # segue o ritual (só luta depois de ser atacado)
			continue
		if u == dama and fase_dama == 1:
			# Dama (Léo, 20/11; ChefeDama): na fase 1 cada turno é devorar um pendurado e usar a habilidade da flor que
			# abre. Aqui só o dano em PV, sem flores murchando (o grupo da simulação não usa itens nem rituais).
			if dama_turnos < DANO_FLORES_FASE1.size() and dama.pv > 0.5 * dama.max_pv:
				var vitima := _alvo(u, units, {})
				if vitima:
					vitima.take_damage(rules.damage_after_defense(float(DANO_FLORES_FASE1[dama_turnos]), vitima.defense_total()))
				dama_turnos += 1
				turns.end_turn()
				continue
			fase_dama = 2  # corpos acabaram ou ela caiu a 50%: bate 25% mais forte
			dama.weapon["damage_min"] = int(round(int(dama.weapon["damage_min"]) * 1.25))
			dama.weapon["damage_max"] = int(round(int(dama.weapon["damage_max"]) * 1.25))
		var guard := 0
		while turns.is_turn_of(u) and u.pa > 0 and guard < 12:
			guard += 1
			var alvo := _alvo(u, units, atacantes)
			if alvo == null:
				break
			var bloqueio := rules.attack_blocker(u, alvo, [] as Array[Rect2], [])
			if bloqueio == "no_ammo":
				var recarga := int(cfg.regra("custo_recarga_pa", 1))
				if u.pa < recarga:
					break
				u.pa -= recarga
				u.mag[u.weapon["id"]] = int(u.weapon["mag_size"])
			elif bloqueio == "":
				rules.attack(u, alvo, [] as Array[Rect2], [])
				if u.side == Combatant.Side.ENEMY and not atacantes.has([u, alvo]):
					atacantes[alvo] = int(atacantes.get(alvo, 0)) + 1
					atacantes[[u, alvo]] = true
			elif bloqueio != "out_of_range" or not _andar(rules, u, alvo):
				break
			# Roberto vira a Dama de Sangue; a Dama a 30% encerra a luta (fim roteirizado).
			if not chefe.is_empty():
				for x in units:
					if dama == null and x.kind == chefe["de"] and x.is_alive() and x.pv <= float(chefe["limite"]) * x.max_pv:
						dama = cfg.make_enemy(chefe["vira"], x.pos)
						units.append(dama)
						turns.add_unit(dama)
						x.pv = 0
				if dama and not dama.is_alive():
					for x in units:
						if x.em_ritual:
							x.pv = 0  # o ritual se rompe com a Dama (local3d._romper_ritual)
				if dama and not fim and dama.pv <= float(chefe["fim"]) * dama.max_pv:
					fim = true  # cutscene do tentáculo: o Fernando morre e a luta segue com quem sobrou
					for a in grupo:
						if a.personagem == "fernando" and a.is_alive():
							a.pv = 0
							roteirizado = a
			turns.action_done()
		if turns.is_turn_of(u):
			turns.end_turn()
	var vivos := 0
	var pv := 0.0
	var pv_total := 0.0
	for a in grupo:
		if a == roteirizado:
			continue
		pv_total += a.max_pv
		if a.is_alive():
			vivos += 1
			pv += a.pv
	var vitoria := turns.result == TurnManager.Result.VICTORY
	var contados := GRUPO.size() - (1 if roteirizado else 0)
	return {"vitoria": vitoria, "rodadas": turns.round_number, "pv_sobra": pv / pv_total, "caidos": contados - vivos}


func _alvo(u: Combatant, units: Array[Combatant], atacantes: Dictionary) -> Combatant:
	var melhor: Combatant = null
	var nota := INF
	var vivos_grupo := 0
	for x in units:
		if x.side == Combatant.Side.PLAYER and x.is_alive():
			vivos_grupo += 1
	for x in units:
		if x.side == u.side or not x.is_alive():
			continue
		if x.em_ritual and _tem_lutando(units, u.side):
			continue  # o grupo deixa quieto quem está no ritual enquanto houver inimigo lutando
		var d := CombatRules.gap(u, x)
		var n := d
		if u.side == Combatant.Side.ENEMY:
			if vivos_grupo >= 2 and int(atacantes.get(x, 0)) >= 2 and not atacantes.has([u, x]):
				continue  # foco: no máximo 2 inimigos no mesmo alvo (EnemyAi)
		elif not bool(u.weapon["melee"]) and d <= float(u.weapon["max_range"]):
			n = float(x.pv) - 10000.0  # ao alcance: o mais ferido primeiro
		if n < nota:
			nota = n
			melhor = x
	return melhor


# Anda reto até encostar no alvo (corpo a corpo) ou até entrar no alcance. False se não deu para andar.
func _andar(rules: CombatRules, u: Combatant, alvo: Combatant) -> bool:
	var dir := (alvo.pos - u.pos).normalized()
	var falta := maxf(CombatRules.gap(u, alvo) - float(u.weapon["max_range"]) + 2.0, 0.0)
	var budget := cfg.value("free_move_px") + float(rules._paid_pa(u.moved_px) + u.pa) * cfg.value("pixels_per_pa") - u.moved_px
	var passo := minf(falta, budget)
	if passo <= 0.5:
		return false
	var custo := rules.move_cost(passo, u.moved_px)
	if custo > u.pa:
		return false
	u.pa -= custo
	u.moved_px += passo
	u.pos += dir * passo
	return true


# Arma (principal ou secundária da ficha) com mais dano esperado por turno na distância `dist` (px).
func _melhor_arma(rules: CombatRules, a: Combatant, dist: float) -> Dictionary:
	var p := cfg.game_data.get_entry("personagens", a.personagem)
	var melhor := a.weapon
	var nota := -1.0
	for id in [p.get("arma_inicial"), p.get("arma_secundaria")]:
		if id == null:
			continue
		var w := cfg.weapon(str(id))
		var gap := 0.0 if bool(w["melee"]) else dist
		var chance := clampf(float(w["base_chance"]) - rules._range_penalty(w, gap) + maxi(a.initiative - 1, 0) * cfg.value("agi_hit_bonus"),
			cfg.value("hit_chance_min"), cfg.value("hit_chance_max"))
		var medio := (float(w["damage_min"]) + float(w["damage_max"])) / 2.0 + Ficha.bonus_dano(cfg.game_data, a.atributos, w)
		var n := floorf(cfg.value("pa_per_turn") / float(w["pa_cost"])) * chance * medio
		if n > nota:
			nota = n
			melhor = w
	if int(melhor.get("mag_size", 0)) > 0:
		a.mag[melhor["id"]] = int(melhor["mag_size"])
	return melhor


# Algum inimigo do lado oposto a `lado` está de pé e fora do ritual.
func _tem_lutando(units: Array[Combatant], lado: int) -> bool:
	for x in units:
		if x.side != lado and x.is_alive() and not x.em_ritual:
			return true
	return false
