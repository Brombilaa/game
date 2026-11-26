class_name Fraquezas
extends RefCounted
# Fraquezas e resistências dos inimigos (sugestão 6 da segunda leva, aprovada pelo Léo em 16/11/2026).
# O que cada inimigo tem fica em inimigos.json ('fraquezas' e 'resistencias', por tipo de dano); multiplicadores,
# nomes dos tipos e como o grupo descobre cada uma ficam em data/fraquezas.json. Valores provisórios do Claude.
# A descoberta é uma entrada comum do diário (lugar "INIMIGOS"), então vai no save junto com ele.
# Sem nós de tela, para testar em modo headless.

const ARQUIVO := "res://data/fraquezas.json"
const LUGAR := "INIMIGOS"
const BALISTICO := "balistico"
const CORPO_A_CORPO := "corpo_a_corpo"
const RITUAL := "ritual"

static var _cache: Dictionary = {}


static func dados() -> Dictionary:
	if _cache.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
		if d is Dictionary:
			_cache = d
	return _cache


# Tipo de dano de uma arma no formato de CombatConfig.weapon (corpo a corpo ou bala).
static func tipo_da_arma(weapon: Dictionary) -> String:
	return CORPO_A_CORPO if weapon.get("melee", false) else BALISTICO


# Afinidade do inimigo `kind` (id de inimigos.json) com o tipo de dano: "fraqueza", "resistencia" ou "".
# Agentes (kind vazio) não têm nenhuma.
static func afinidade(game_data: GameData, kind: String, tipo: String) -> String:
	if kind == "" or tipo == "" or game_data == null:
		return ""
	var e := game_data.get_entry("inimigos", kind)
	if (e.get("fraquezas", []) as Array).has(tipo):
		return "fraqueza"
	if (e.get("resistencias", []) as Array).has(tipo):
		return "resistencia"
	return ""


static func multiplicador(af: String) -> float:
	if af == "":
		return 1.0
	return float(dados().get(af, 1.0))


# Nome do tipo para texto ("balas", "rituais"...).
static func nome_tipo(tipo: String) -> String:
	return str((dados().get("tipos", {}) as Dictionary).get(tipo, tipo))


static func id_entrada(kind: String, tipo: String) -> String:
	return "frq_%s_%s" % [kind, tipo]


# O grupo já sabe dessa fraqueza/resistência (está no diário)?
static func conhecida(kind: String, tipo: String) -> bool:
	var id := id_entrada(kind, tipo)
	for e in Missao1.diario:
		if e["id"] == id:
			return true
	return false


static func descobertas() -> Array:
	return dados().get("descobertas", [])


static func _descoberta(kind: String, tipo: String) -> Dictionary:
	for d in descobertas():
		if d["inimigo"] == kind and d["tipo"] == tipo:
			return d
	return {}


# Título da entrada no diário: "Zumbi de Sangue: rituais ferem mais" (sem gênero, serve para todos).
static func titulo(game_data: GameData, kind: String, tipo: String) -> String:
	var nome := kind
	if game_data != null:
		nome = str(game_data.get_entry("inimigos", kind).get("nome", kind))
	var af := afinidade(game_data, kind, tipo)
	return "%s: %s ferem %s" % [nome, nome_tipo(tipo), "mais" if af == "fraqueza" else "menos"]


# Anota a descoberta no diário. via = "pista" usa o texto da pista; "combate" o texto de quando se percebe lutando.
# Devolve true se era nova.
static func revelar(game_data: GameData, kind: String, tipo: String, via := "pista") -> bool:
	if conhecida(kind, tipo) or afinidade(game_data, kind, tipo) == "":
		return false
	var d := _descoberta(kind, tipo)
	var texto := str(d.get("combate" if via == "combate" else "texto", ""))
	if texto == "":
		texto = str(d.get("texto", "Descoberto no combate."))
	return Diario.anotar(LUGAR, id_entrada(kind, tipo), texto, "", titulo(game_data, kind, tipo))


# Pista examinada: revela o que ela ensina. Devolve os títulos das entradas novas (para avisar na tela).
static func ao_examinar(game_data: GameData, pista: String) -> Array[String]:
	var out: Array[String] = []
	for d in descobertas():
		if (d["pistas"] as Array).has(pista) and revelar(game_data, d["inimigo"], d["tipo"]):
			out.append(titulo(game_data, d["inimigo"], d["tipo"]))
	return out


# Golpe que acertou (resultado de CombatRules.attack ou RitualRules.cast): se pegou fraqueza ou resistência,
# devolve o texto curto do combate ("FRAQUEZA"/"RESISTE") e, se ainda não era conhecida, anota no diário.
# {"popup": String, "nova": bool}; popup vazio quando não há afinidade.
static func ao_acertar(game_data: GameData, target: Combatant, r: Dictionary) -> Dictionary:
	var af := str(r.get("afinidade", ""))
	if af == "" or target == null or target.kind == "":
		return {"popup": "", "nova": false}
	var nova := revelar(game_data, target.kind, str(r.get("tipo_dano", "")), "combate")
	return {"popup": "FRAQUEZA" if af == "fraqueza" else "RESISTE", "nova": nova}


# --- Seção CRIATURAS do diário (o caderno do Miguel) ------------------------------------------------

# O grupo encontrou o inimigo num combate: a criatura passa a aparecer na seção, mesmo sem nada descoberto.
static func ver(kind: String) -> void:
	if kind != "":
		Missao1.marcar("visto_" + kind)


# Criaturas que aparecem na seção, na ordem de data/fraquezas.json: vistas em combate ou com alguma descoberta.
# Cada uma: {kind, nome, nota, retrato, afinidades: [{tipo, afinidade, nome_tipo, conhecida, miguel}]}.
# Afinidades ainda não descobertas vêm com conhecida = false (a seção mostra "???").
static func criaturas(game_data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fichas: Dictionary = dados().get("criaturas", {})
	for kind in fichas:
		var afs: Array[Dictionary] = []
		var alguma := false
		for d in descobertas():
			if d["inimigo"] != kind:
				continue
			var sabe := conhecida(kind, d["tipo"])
			alguma = alguma or sabe
			afs.append({"tipo": d["tipo"], "afinidade": afinidade(game_data, kind, d["tipo"]), "nome_tipo": nome_tipo(d["tipo"]), "conhecida": sabe, "miguel": str(d.get("miguel", ""))})
		if not alguma and not Missao1.tem("visto_" + kind):
			continue
		var nome := str(kind)
		if game_data != null:
			nome = str(game_data.get_entry("inimigos", kind).get("nome", kind))
		out.append({"kind": kind, "nome": nome, "nota": str(fichas[kind].get("nota", "")), "retrato": str(fichas[kind].get("retrato", "")), "afinidades": afs})
	return out
