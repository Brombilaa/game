class_name FalasSoltas
extends RefCounted
# Falas soltas do grupo na exploração (Léo, 15/11/2026, modelo C): frases curtas que os agentes dizem enquanto andam,
# sem abrir diálogo e sem pausar o jogo, na CaixaFala em modo "solta". Dão clima e personalidade.
# Só a lógica de quando falar fica aqui (testável sem cena); quem toca é a sala de exploração.
#
# Regras (provisórias do Claude, a testar): a primeira fala vem PRIMEIRA_ESPERA s depois de a exploração começar
# livre, e entre uma fala e outra passam de ESPERA_MIN a ESPERA_MAX s; só conta o tempo com o jogador livre
# (sem combate, diálogo, cena ou transição); cada fala toca uma vez por jogo (vira marca "fala_<id>" e vai
# para o save); a ordem do arquivo é mantida, e "requer" segura a fala até a marca existir.

const ARQUIVO := "res://data/falas_soltas.json"
const PRIMEIRA_ESPERA := 8.0
const ESPERA_MIN := 20.0
const ESPERA_MAX := 40.0

static var _cache: Dictionary = {}

var area := ""
var espera := PRIMEIRA_ESPERA
var rng := RandomNumberGenerator.new()


func _init(area_id := "") -> void:
	area = area_id
	rng.randomize()


static func dados() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(ARQUIVO, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		_cache = d if d is Dictionary else {"falas": []}
	return _cache


static func marca_de(id: String) -> String:
	return "fala_" + id


# Próxima fala ainda não dita deste lugar cuja condição já vale, ou {}. Cada fala é {"id", "area", "falas": [{"quem", "texto"}]}.
func proxima() -> Dictionary:
	for f in dados().get("falas", []):
		if str(f["area"]) != area or Missao1.tem(marca_de(str(f["id"]))):
			continue
		if f.has("requer") and not Missao1.tem(str(f["requer"])):
			continue
		return f
	return {}


# Chamada todo quadro. `livre` = exploração sem combate, diálogo, cena nem transição. Devolve a fala a tocar (e já
# a marca como dita) ou {}. Sem `livre` o relógio fica parado.
func tick(delta: float, livre: bool) -> Dictionary:
	if not livre:
		return {}
	espera -= delta
	if espera > 0.0:
		return {}
	var f := proxima()
	if f.is_empty():
		espera = ESPERA_MAX  # nada a dizer agora: tenta de novo depois (uma marca nova pode liberar uma fala)
		return {}
	Missao1.marcar(marca_de(str(f["id"])))
	espera = rng.randf_range(ESPERA_MIN, ESPERA_MAX)
	return f
