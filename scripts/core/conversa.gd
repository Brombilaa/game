class_name Conversa
extends RefCounted
# Conversas por perguntas (Léo, 20/11/2026: no bar, "todas disponíveis, cada resposta vira entrada do diário").
# Os dados ficam em data/conversas.json: id da conversa -> {titulo, quem, sair, perguntas: [{id, texto, respostas, diario}]}.
# Cada pergunta feita vira a marca "perg_<conversa>_<id>" (vai no save, e a lista abre com ela já riscada) e uma entrada
# do diário (Diario.anotar). Aqui ficam só as regras, sem nós de tela, para testar em modo headless.

const ARQUIVO := "res://data/conversas.json"


static func carregar(conversa_id: String) -> Dictionary:
	var f := FileAccess.open(ARQUIVO, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary and (d as Dictionary).get(conversa_id) is Dictionary:
		return d[conversa_id]
	return {}


static func marca(conversa_id: String, pergunta_id: String) -> String:
	return "perg_%s_%s" % [conversa_id, pergunta_id]


static func feita(conversa_id: String, pergunta_id: String) -> bool:
	return Missao1.tem(marca(conversa_id, pergunta_id))


static func pergunta(dados: Dictionary, pergunta_id: String) -> Dictionary:
	for p in dados.get("perguntas", []):
		if str(p["id"]) == pergunta_id:
			return p
	return {}


static func total_feitas(conversa_id: String, dados: Dictionary) -> int:
	var n := 0
	for p in dados.get("perguntas", []):
		if feita(conversa_id, str(p["id"])):
			n += 1
	return n


# Registra a pergunta: marca como feita e anota a resposta no diário. false se já tinha sido feita antes.
static func registrar(conversa_id: String, dados: Dictionary, pergunta_id: String, lugar: String) -> bool:
	var p := pergunta(dados, pergunta_id)
	if p.is_empty() or feita(conversa_id, pergunta_id):
		return false
	Missao1.marcar(marca(conversa_id, pergunta_id))
	var d: Dictionary = p.get("diario", {})
	if not d.is_empty():
		Diario.anotar(lugar, "%s_%s" % [conversa_id, pergunta_id], str(d["texto"]), "", str(d.get("titulo", "")))
	return true
