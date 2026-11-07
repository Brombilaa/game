class_name Objectives
extends RefCounted
# Lista de objetivos do HUD (GDD §12: "objetivo atual"). Sem nós de tela, para testar em modo headless.
# Os objetivos do parque saem das pistas do cenário: investigar as de ordem 1, depois o símbolo da árvore.
# Textos provisórios até o Léo revisar a redação.

const COMBAT_TEXT := "Sobreviver ao combate"
const LOCKED_TEXT := "???"


# Cada item: {texto, feito, atual, detalhe}. `atual` marca o objetivo em andamento (só um por vez).
static func build(clues: Dictionary, seen: Array, in_combat: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first := 0
	var first_seen := 0
	var last_ids: Array[String] = []
	for cid in clues:
		if int(clues[cid]["ordem"]) == 1:
			first += 1
			if seen.has(cid):
				first_seen += 1
		else:
			last_ids.append(cid)
	if first > 0:
		out.append({"texto": "Investigar o parque", "feito": first_seen >= first, "atual": false,
			"detalhe": "%d/%d" % [first_seen, first]})
	for cid in last_ids:
		var open := first_seen >= first
		out.append({"texto": "Examinar o símbolo" if open else LOCKED_TEXT,
			"feito": seen.has(cid), "atual": false, "detalhe": ""})
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
