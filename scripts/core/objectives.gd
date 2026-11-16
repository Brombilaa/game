class_name Objectives
extends RefCounted
# Lista de objetivos do HUD (GDD §12: "objetivo atual"). Sem nós de tela, para testar em modo headless.
# Todos os lugares usam o mesmo formato, a lista "objetivos" do JSON do cenário (from_data). Cada objetivo:
#   texto; feito por "pista" (uma pista vista), "pistas" (todas vistas; mostra "x/y") ou "marca" (Missao1);
#   "requer": marca que faz o objetivo aparecer; "trancado": true mostra ??? até os anteriores estarem feitos.
# build() é o caminho antigo do parque (pistas de ordem 1, depois a de ordem 2), para cenário sem "objetivos".
# Textos provisórios até o Léo revisar a redação.

const COMBAT_TEXT := "Sobreviver ao combate"
const LOCKED_TEXT := "???"


# Cada item: {texto, feito, atual, detalhe}. `atual` marca o objetivo em andamento (só um por vez).
# `tem`: Callable(marca) -> bool (Missao1.tem no jogo).
static func from_data(lista: Array, seen: Array, tem: Callable, in_combat: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var anteriores_feitos := true
	for o in lista:
		if o.has("requer") and not tem.call(str(o["requer"])):
			continue
		var feito := false
		var detalhe := ""
		if o.has("pistas"):
			var vistas: int = (o["pistas"] as Array).filter(func(c) -> bool: return seen.has(str(c))).size()
			feito = vistas >= (o["pistas"] as Array).size()
			detalhe = "%d/%d" % [vistas, (o["pistas"] as Array).size()]
		elif o.has("pista"):
			feito = seen.has(str(o["pista"]))
		if o.has("marca") and tem.call(str(o["marca"])):
			feito = true
		var texto := str(o["texto"])
		if bool(o.get("trancado", false)) and not anteriores_feitos and not feito:
			texto = LOCKED_TEXT
		out.append({"texto": texto, "feito": feito, "atual": false, "detalhe": detalhe})
		anteriores_feitos = anteriores_feitos and feito
	return _finish(out, in_combat)


# Parque sem "objetivos" nos dados: investigar as pistas de ordem 1, depois examinar as de ordem 2.
static func build(clues: Dictionary, seen: Array, in_combat: bool) -> Array[Dictionary]:
	var primeiras: Array = []
	var lista: Array = []
	for cid in clues:
		if int(clues[cid]["ordem"]) == 1:
			primeiras.append(cid)
	if not primeiras.is_empty():
		lista.append({"texto": "Investigar o parque", "pistas": primeiras})
	for cid in clues:
		if int(clues[cid]["ordem"]) != 1:
			lista.append({"texto": "Examinar o símbolo", "pista": cid, "trancado": true})
	return from_data(lista, seen, func(_m: String) -> bool: return false, in_combat)


static func _finish(out: Array[Dictionary], in_combat: bool) -> Array[Dictionary]:
	if in_combat:
		out.append({"texto": COMBAT_TEXT, "feito": false, "atual": false, "detalhe": ""})
	for item in out:  # o primeiro que ainda não foi feito (e não está bloqueado) é o atual
		if not item["feito"] and item["texto"] != LOCKED_TEXT:
			item["atual"] = true
			break
	if in_combat and not out.is_empty():  # em combate o foco é sobreviver
		for item in out:
			item["atual"] = item["texto"] == COMBAT_TEXT
	return out
