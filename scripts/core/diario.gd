class_name Diario
extends RefCounted
# Diário de pistas (modelo A, "caderno de campo", escolhido pelo Léo em 15/11/2026): guarda tudo o que o grupo
# examinou, com texto e imagem, de todos os lugares da missão. A lista vive em Missao1.diario (entra no save com
# a missão); aqui ficam as regras, sem nós de tela, para testar em modo headless.
# Cada entrada: {id, lugar (ex.: "PARQUE · 16h"), titulo, texto, imagem ("" quando a pista não tem imagem)}.

# Títulos curtos das pistas (a lista do caderno). Pista sem título aqui usa o id com a primeira letra maiúscula.
const TITULOS := {
	"caio": "O corpo do Caio",
	"marcas_pneu": "Marcas de pneu",
	"balanco": "Balanço arranhado",
	"banco_quebrado": "Banco quebrado",
	"banco_velho": "Banco velho",
	"arvore_simbolo": "Símbolo na árvore",
	"leticia": "Letícia está viva",
	"tapete": "Tapete fora do lugar",
	"poco": "O poço da fazenda",
	"livro_faltando": "O livro Sanguis Orchid",
	"livro_ocorrencias": "Livro de ocorrências",
	"agenda_ghular": "A agenda do delegado",
	"gaveta_provas": "Gaveta de provas forçada",
	"ficha_desaparecidos": "Fichas de desaparecidos",
	"cela_arranhoes": "Arranhões na cela",
	"chaveiro_recepcao": "Chaveiro da recepção",
	"kit_recepcao": "Kit esquecido",
	"fichario": "Fichas de empréstimo",
	"mesa_leitura": "Livro de história",
	"mapa_antigo": "Recorte de 1977",
	"diario_bibliotecaria": "Diário da bibliotecária",
	"caixa_arquivo": "Caixa de arquivo",
	# Necrotério e casa do Velho Geraldo (22/11)
	"tutu_corpo": "O corpo do Tutu",
	"tutu_pescoco": "Pontos no pescoço do Tutu",
	"mesa_legista": "A mesa do legista",
	"gaveta_zumbi": "A gaveta do zumbi",
	"armario_instrumentos": "Armário de instrumentos",
	"pagina_parasitagem": "Página: Parasitagem",
	"pagina_caladenia_purpura": "Página: Caladenia purpura",
	"pagina_caladenia_viridis": "Página: Caladenia viridis",
	"pagina_caladenia_flavum": "Página: Caladenia flavum",
	"leticia_despedida": "A Letícia no necrotério",
	"geraldo_conversa": "O Velho Geraldo",
	"geraldo_1977": "O caso de 1977",
	"geraldo_despedida": "O que o Geraldo ficou de contar",
	"geraldo_pescoco": "Cicatrizes no pescoço",
	"geraldo_tique": "O tique do Geraldo",
	"cerca_buracos": "Cerca cheia de buracos",
	"arma_chumbinho": "Arma de chumbinho",
	"caixote_varanda": "Caixote da varanda",
}


static func titulo(id: String) -> String:
	if TITULOS.has(id):
		return TITULOS[id]
	var t := id.replace("_", " ")
	return t.substr(0, 1).to_upper() + t.substr(1)


# Anota uma pista examinada. Devolve false se o diário já tinha essa pista (mesmo lugar e id).
static func anotar(lugar: String, id: String, texto: String, imagem := "", titulo_proprio := "") -> bool:
	for e in Missao1.diario:
		if e["id"] == id and e["lugar"] == lugar:
			return false
	for i in range(Missao1.diario.size() - 1, -1, -1):  # examinar de verdade substitui a dedução do grupo
		if Missao1.diario[i]["id"] == "ded_" + id and Missao1.diario[i]["lugar"] == lugar:
			Missao1.diario.remove_at(i)
	Missao1.diario.append({"id": id, "lugar": lugar, "titulo": titulo_proprio if titulo_proprio != "" else titulo(id), "texto": texto, "imagem": imagem})
	return true


# Dedução do grupo (Léo, 22/11): pista essencial que ficou sem examinar entra como resumo superficial, no estilo
# "falhou no teste" do roteiro. Não repete se a pista já foi examinada ou deduzida; examinar depois a substitui.
static func deduzir(lugar: String, id: String, resumo: String) -> bool:
	for e in Missao1.diario:
		if e["lugar"] == lugar and (e["id"] == id or e["id"] == "ded_" + id):
			return false
	Missao1.diario.append({"id": "ded_" + id, "lugar": lugar, "titulo": "Dedução: " + titulo(id), "texto": resumo, "imagem": ""})
	return true


# Entradas da mais nova para a mais antiga (a lista do caderno abre na última descoberta).
static func recentes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(Missao1.diario.size() - 1, -1, -1):
		out.append(Missao1.diario[i])
	return out


# Texto e detalhe do objetivo em andamento, a partir da lista do HUD (Objectives); "" se não há nenhum.
static func objetivo_atual(lista: Array) -> String:
	for o in lista:
		if o.get("atual", false):
			var det := str(o.get("detalhe", ""))
			return str(o["texto"]) + (" (%s)" % det if det != "" else "")
	return ""


# Lê do save (JSON) só o que parece uma entrada; o resto é ignorado.
static func ler(lista: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not lista is Array:
		return out
	for e in lista:
		if e is Dictionary and e.has("id") and e.has("texto"):
			out.append({"id": str(e["id"]), "lugar": str(e.get("lugar", "")), "titulo": str(e.get("titulo", titulo(str(e["id"])))), "texto": str(e["texto"]), "imagem": str(e.get("imagem", ""))})
	return out
