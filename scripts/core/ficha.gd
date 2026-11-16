class_name Ficha
extends RefCounted
# Ficha de um agente pelo GDD (#11): classe (classes.json) + cinco atributos (VIG, FOR, INT, AGI, PRE).
# Tudo sai dos dados: PV e SAN da classe, ganho por nível e efeito de cada atributo em regras.json.
#   PV  = pv_base da classe + VIG; por nível acima do 1: pv_por_nivel + VIG × pv_ganho_por_nivel_por_vig.
#   SAN = san_base da classe + (PRE - 1) × pre_san_por_ponto; por nível: san_por_nivel + PRE × san_ganho_por_nivel_por_pre.
#   AGI = iniciativa (maior age primeiro) e +agi_hit_bonus de acerto por ponto acima de 1 (CombatRules).
#   FOR = +for_dano_por_ponto de dano por ponto acima de 1 no corpo a corpo e nas armas de for_dano_armas.
#   INT = +int_ritual_por_ponto no dano e na cura de ritual por ponto acima de 1.
# Distribuição inicial: todos começam em atributo_inicial, o jogador reparte atributo_pontos_iniciais,
# ninguém passa de atributo_max_inicial. Os valores sem decisão do Léo estão marcados como provisórios nos dados.

const ATRIBUTOS := ["VIG", "FOR", "INT", "AGI", "PRE"]

# Escolhas do jogador na tela de fichas: id do personagem -> {atributo: valor}. Vale para a campanha
# inteira (vai no save). Vazio = distribuição sugerida de personagens.json.
static var escolhas := {}


static func reiniciar() -> void:
	escolhas = {}


# Atributos do personagem: a escolha do jogador, senão a sugestão de personagens.json, senão tudo no inicial.
static func atributos_de(data: GameData, personagem: String) -> Dictionary:
	if escolhas.has(personagem):
		return (escolhas[personagem] as Dictionary).duplicate()
	return sugeridos(data, personagem)


static func sugeridos(data: GameData, personagem: String) -> Dictionary:
	var base := _inicial(data)
	var p := data.get_entry("personagens", personagem)
	var out := {}
	for a in ATRIBUTOS:
		var v = (p.get("atributos", {}) as Dictionary).get(a)
		out[a] = int(v) if v != null else base
	return out


static func em_branco(data: GameData) -> Dictionary:
	var out := {}
	for a in ATRIBUTOS:
		out[a] = _inicial(data)
	return out


static func pontos_restantes(data: GameData, atributos: Dictionary) -> int:
	var gastos := 0
	for a in ATRIBUTOS:
		gastos += int(atributos.get(a, _inicial(data))) - _inicial(data)
	return int(_regra(data, "atributo_pontos_iniciais", 4)) - gastos


# "" se a distribuição vale; senão o motivo, em português, para mostrar ao jogador.
static func validar(data: GameData, atributos: Dictionary) -> String:
	var minimo := _inicial(data)
	var maximo := int(_regra(data, "atributo_max_inicial", 3))
	for a in ATRIBUTOS:
		if not atributos.has(a):
			return "Falta o atributo %s" % a
		var v := int(atributos[a])
		if v < minimo:
			return "%s não pode ficar abaixo de %d" % [a, minimo]
		if v > maximo:
			return "%s passa do máximo inicial (%d)" % [a, maximo]
	var resto := pontos_restantes(data, atributos)
	if resto > 0:
		return "Ainda sobra%s %d ponto%s" % ["m" if resto > 1 else "", resto, "s" if resto > 1 else ""]
	if resto < 0:
		return "Pontos demais: tire %d" % -resto
	return ""


# Soma `delta` (+1 ou -1) num atributo se a regra deixar. Devolve true se mudou.
static func ajustar(data: GameData, atributos: Dictionary, atributo: String, delta: int) -> bool:
	var v := int(atributos.get(atributo, _inicial(data))) + delta
	if v < _inicial(data) or v > int(_regra(data, "atributo_max_inicial", 3)):
		return false
	if delta > 0 and pontos_restantes(data, atributos) < delta:
		return false
	atributos[atributo] = v
	return true


static func pv_max(data: GameData, classe: String, atributos: Dictionary, nivel := 1) -> int:
	var c := data.get_entry("classes", classe)
	var vig := int(atributos.get("VIG", 1))
	var pv := int(c.get("pv_base", 1)) + vig
	var por_vig := float(_regra(data, "pv_ganho_por_nivel_por_vig", 1.0))
	for _n in range(1, nivel):
		pv += int(c.get("pv_por_nivel", 0)) + floori(vig * por_vig)
	return maxi(pv, 1)


static func san_max(data: GameData, classe: String, atributos: Dictionary, nivel := 1) -> int:
	var c := data.get_entry("classes", classe)
	var pre := int(atributos.get("PRE", 1))
	var san := int(c.get("san_base", 0)) + maxi(pre - 1, 0) * int(_regra(data, "pre_san_por_ponto", 0))
	var por_pre := float(_regra(data, "san_ganho_por_nivel_por_pre", 0.0))
	for _n in range(1, nivel):
		san += int(c.get("san_por_nivel", 0)) + floori(pre * por_pre)
	return maxi(san, 0)


# Dano extra da Força para a arma (dicionário de CombatConfig.weapon). Inimigos não têm atributos: 0.
static func bonus_dano(data: GameData, atributos: Dictionary, weapon: Dictionary) -> int:
	if atributos.is_empty():
		return 0
	var armas: Array = _regra(data, "for_dano_armas", [])
	if not bool(weapon.get("melee", false)) and not armas.has(str(weapon.get("id", ""))):
		return 0
	return maxi(int(atributos.get("FOR", 1)) - 1, 0) * int(_regra(data, "for_dano_por_ponto", 0))


# Dano ou cura extra de ritual pelo Intelecto.
static func bonus_ritual(data: GameData, atributos: Dictionary) -> int:
	return maxi(int(atributos.get("INT", 1)) - 1, 0) * int(_regra(data, "int_ritual_por_ponto", 0))


static func classe_de(data: GameData, personagem: String) -> String:
	var c = data.get_entry("personagens", personagem).get("classe")
	return str(c) if c != null else ""


static func _inicial(data: GameData) -> int:
	return int(_regra(data, "atributo_inicial", 1))


static func _regra(data: GameData, chave: String, padrao: Variant) -> Variant:
	var v = data.rule(chave)
	return padrao if v == null else v
