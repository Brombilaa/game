class_name Dicas
extends RefCounted
# Dicas da primeira vez (modelo A, Léo, 15/11/2026): uma faixa no rodapé mostra uma dica por vez e cada dica
# some para sempre depois que o jogador faz a ação. A ordem é a da lista; em combate a dica de atacar passa
# na frente. Só a lógica fica aqui (sem nós, para testar em modo headless); o desenho é de RoomDicasHud.
# As dicas feitas vão no save (campo "dicas") e voltam ao novo jogo.

# id, texto antes da tecla, tecla (vazia = sem tecla), texto depois. Textos provisórios.
const PASSOS: Array[Dictionary] = [
	{"id": "andar", "antes": "Clique no chão para andar.", "tecla": "", "depois": ""},
	{"id": "examinar", "antes": "Clique em um ponto brilhante para examinar.", "tecla": "", "depois": ""},
	{"id": "agachar", "antes": "Aperte", "tecla": "C", "depois": "para agachar e ser menos notado."},
	{"id": "atacar", "antes": "Clique em um inimigo para atacar.", "tecla": "", "depois": ""},
]

static var feitas: Dictionary = {}


static func reiniciar() -> void:
	feitas.clear()


static func marcar(id: String) -> void:
	feitas[id] = true


static func feita(id: String) -> bool:
	return feitas.has(id)


# A dica a mostrar agora, ou {} se não há. Em exploração só as de exploração; em combate só a de atacar.
static func atual(em_combate: bool) -> Dictionary:
	for p in PASSOS:
		if feitas.has(p["id"]):
			continue
		if (p["id"] == "atacar") == em_combate:
			return p
	return {}


static func para_save() -> Array:
	return feitas.keys()


static func do_save(lista: Variant) -> void:
	feitas.clear()
	if lista is Array:
		for id in lista:
			feitas[str(id)] = true
