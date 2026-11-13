class_name Missao1
extends RefCounted
# Caminho da missão 1 entre os lugares (história #8): parque 16h, delegacia 17h, biblioteca 19h, volta à
# delegacia 21h (subsolo e invasão), Fazenda Ghular 23h; depois viriam a cripta e as ruínas (ainda não construídas).
# Guarda, entre uma cena e outra, para onde o grupo vai, por onde chega e o que já aconteceu (marcas).
# Vai para o save pelo Progresso (local, chegada e marcas); carregar abre o lugar pela mesma chegada.

const CENA_PARQUE := "res://scenes/exploration/parque.tscn"
const CENA_LOCAL := "res://scenes/exploration/local3d.tscn"
const DEPOIS_DO_PARQUE := "delegacia_17h"

static var local := ""  # id do cenário em data/cenarios que a cena local3d abre
static var chegada := ""  # por onde o grupo chega ("" = início do cenário)
static var marcas := {}  # o que já aconteceu: "alcapao", "invasao_vencida"...


static func reiniciar() -> void:
	local = ""
	chegada = ""
	marcas.clear()


static func marcar(nome: String) -> void:
	marcas[nome] = true


static func tem(nome: String) -> bool:
	return marcas.get(nome, false)
