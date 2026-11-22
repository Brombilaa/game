class_name Missao1
extends RefCounted
# Caminho da missão 1 entre os lugares (história #8): parque 16h, delegacia 17h, biblioteca 19h, volta à
# delegacia 21h (subsolo e invasão), Fazenda Ghular 23h; depois viriam a cripta e as ruínas (ainda não construídas).
# Guarda, entre uma cena e outra, para onde o grupo vai, por onde chega e o que já aconteceu (marcas).
# Vai para o save pelo Progresso (local, chegada e marcas); carregar abre o lugar pela mesma chegada.

const CENA_PARQUE := "res://scenes/exploration/parque.tscn"
const CENA_LOCAL := "res://scenes/exploration/local3d.tscn"
const DEPOIS_DO_PARQUE := "delegacia_17h"
# Depois da delegacia das 17h o grupo escolhe livremente entre três lugares (Léo, 20/11); cada um só conta uma vez, e
# quando os três foram visitados a saída leva de volta à delegacia (21h). A hora de cada um vem do cenário (provisório:
# necrotério 18h, biblioteca 19h, casa do Geraldo 20h). Marca de visita: "visitou_<id>" (posta pelo próprio lugar).
const DESTINOS_LIVRES := [
	{"id": "biblioteca", "rotulo": "Biblioteca de Aurora", "detalhe": "A Júlia guarda o arquivo público da cidade.", "texto": "O grupo segue para a biblioteca."},
	{"id": "necrotorio", "rotulo": "Necrotério de Aurora", "detalhe": "A Letícia espera por eles, junto ao legista.", "texto": "O grupo segue para o necrotério."},
	{"id": "casa_geraldo", "rotulo": "Casa do Velho Geraldo", "detalhe": "Rua das Bromélias, a casa velha e vermelha.", "texto": "O grupo segue para a Rua das Bromélias."},
]

static var local := ""  # id do cenário em data/cenarios que a cena local3d abre
static var chegada := ""  # por onde o grupo chega ("" = início do cenário)
static var marcas := {}  # o que já aconteceu: "alcapao", "invasao_vencida"...
static var diario: Array[Dictionary] = []  # pistas examinadas em todos os lugares (Diario); vai no save


static func reiniciar() -> void:
	local = ""
	chegada = ""
	marcas.clear()
	diario.clear()


static func marcar(nome: String) -> void:
	marcas[nome] = true


static func tem(nome: String) -> bool:
	return marcas.get(nome, false)


# Lugares livres que o grupo ainda não visitou, na ordem da lista.
static func destinos_livres() -> Array:
	var out: Array = []
	for d in DESTINOS_LIVRES:
		if not tem("visitou_" + str(d["id"])):
			out.append(d)
	return out
