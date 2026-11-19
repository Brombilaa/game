class_name DiarioMiguel
extends RefCounted
# Aba DIÁRIO do caderno do Miguel (modelo B1 "couro costurado", Léo 19/11/2026): o relato da missão escrito por
# ele, um lugar por página dupla. Os textos e desenhos ficam em data/diario_miguel.json; aqui ficam as regras
# (o que já pode aparecer), sem nós de tela, para testar em modo headless. O que o grupo viveu vem de
# Missao1.marcas ("esteve_<area>") e das pistas do diário, então entra no save sem estado novo.

const ARQUIVO := "res://data/diario_miguel.json"
const ESBOCOS := "res://assets/sprites/diario/esbocos/%s.png"

static var _cache: Dictionary = {}


static func dados() -> Dictionary:
	if _cache.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
		if d is Dictionary:
			_cache = d
	return _cache


# O grupo chegou num lugar: a página desse lugar passa a existir no caderno.
static func esteve(area: String) -> void:
	if area != "":
		Missao1.marcar("esteve_" + area)


# "pista:<id>" (a pista está no diário), "marca:<nome>" ou "" (sempre).
static func cumpre(requer: String) -> bool:
	if requer == "":
		return true
	if requer.begins_with("pista:"):
		var id := requer.substr(6)
		for e in Missao1.diario:
			if e["id"] == id:
				return true
		return false
	if requer.begins_with("marca:"):
		return Missao1.tem(requer.substr(6))
	return false


# Páginas que já existem, na ordem da missão: {id, titulo, linhas: [{t, maior}], desenhos: [{desenho, legenda}]}.
static func secoes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in dados().get("secoes", []):
		var esteve_la := false
		for a in s["areas"]:
			esteve_la = esteve_la or Missao1.tem("esteve_" + str(a))
		if not esteve_la:
			continue
		var linhas: Array[Dictionary] = []
		for l in s["linhas"]:
			if cumpre(str(l.get("requer", ""))):
				linhas.append({"t": str(l["t"]), "maior": bool(l.get("maior", false))})
		var desenhos: Array[Dictionary] = []
		for d in s["desenhos"]:
			if cumpre(str(d.get("requer", ""))):
				desenhos.append({"desenho": str(d["desenho"]), "legenda": str(d.get("legenda", ""))})
		out.append({"id": str(s["id"]), "titulo": str(s["titulo"]), "linhas": linhas, "desenhos": desenhos})
	return out


static func cabecalho() -> Dictionary:
	return dados().get("cabecalho", {"titulo": "", "sub": ""})


# Caminho do desenho a lápis (ou "" se não existe).
static func caminho(desenho: String) -> String:
	var p := ESBOCOS % desenho
	return p if desenho != "" and ResourceLoader.exists(p) else ""


static func desenho_pista(id: String) -> String:
	return caminho(str((dados().get("desenhos_pistas", {}) as Dictionary).get(id, "")))


static func desenho_criatura(kind: String) -> String:
	return caminho(str((dados().get("desenhos_criaturas", {}) as Dictionary).get(kind, "")))
