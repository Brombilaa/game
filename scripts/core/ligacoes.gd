class_name Ligacoes
extends RefCounted
# Ligação de pistas (sugestão 3 do relatório de 14/11): o jogador junta duas pistas do diário e, se elas se
# completam, o diário ganha uma conclusão nova (e, às vezes, uma marca da missão). Os pares ficam em
# data/ligacoes.json; aqui ficam as regras, sem nós de tela, para testar em modo headless.
# A conclusão é uma entrada comum do diário (lugar "LIGAÇÃO"), então já vai no save com o diário.

const ARQUIVO := "res://data/ligacoes.json"
const LUGAR := "LIGAÇÃO"

enum Resultado { NOVA, JA_FEITA, SEM_LIGACAO, INVALIDA }

static var _cache: Array = []


# Tenta ligar duas pistas do diário pelo id. Devolve {"resultado": Resultado, "entrada": Dictionary}; a entrada
# só vem preenchida em NOVA e JA_FEITA.
static func tentar(a: String, b: String) -> Dictionary:
	if a == b or not _no_diario(a) or not _no_diario(b):
		return {"resultado": Resultado.INVALIDA, "entrada": {}}
	for lig in todas():
		if not _par(lig, a, b):
			continue
		var id := id_entrada(lig)
		for e in Missao1.diario:
			if e["id"] == id:
				return {"resultado": Resultado.JA_FEITA, "entrada": e}
		Diario.anotar(LUGAR, id, str(lig["texto"]), "", str(lig["titulo"]))
		if str(lig.get("marca", "")) != "":
			Missao1.marcar(str(lig["marca"]))
		return {"resultado": Resultado.NOVA, "entrada": Missao1.diario[Missao1.diario.size() - 1]}
	return {"resultado": Resultado.SEM_LIGACAO, "entrada": {}}


# Id da entrada do diário que a ligação gera.
static func id_entrada(lig: Dictionary) -> String:
	return "lig_" + str(lig["id"])


# Quantas ligações já foram feitas e quantas existem entre as pistas que o diário já tem (para o contador do caderno).
static func feitas() -> int:
	var n := 0
	for lig in todas():
		for e in Missao1.diario:
			if e["id"] == id_entrada(lig):
				n += 1
				break
	return n


# Ligações possíveis agora (as duas pistas no diário e ainda não feitas): serve de dica barata e de teste.
static func disponiveis() -> Array:
	var out := []
	for lig in todas():
		var p: Array = lig["pistas"]
		if _no_diario(p[0]) and _no_diario(p[1]) and not _no_diario(id_entrada(lig)):
			out.append(lig)
	return out


static func todas() -> Array:
	if _cache.is_empty():
		var f := FileAccess.open(ARQUIVO, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary and d.get("ligacoes") is Array:
				_cache = d["ligacoes"]
	return _cache


static func _par(lig: Dictionary, a: String, b: String) -> bool:
	var p: Array = lig["pistas"]
	return (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a)


static func _no_diario(id: String) -> bool:
	for e in Missao1.diario:
		if e["id"] == id:
			return true
	return false
