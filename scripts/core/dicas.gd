class_name Dicas
extends RefCounted
# Dicas da primeira vez (modelo A, Léo, 15/11/2026): uma faixa no rodapé mostra uma dica por vez e cada dica
# some para sempre depois que o jogador faz a ação. A ordem é a da lista. Só a lógica fica aqui (sem nós, para testar em modo headless); o desenho é de RoomDicasHud.
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


# A dica a mostrar agora, ou {} se não há. Só aparece no momento de usar a habilidade (Léo, 16/11):
# `ctx` diz o que a cena vive agora: "combate" (na vez do jogador), "pista" (perto de uma pista nova) e
# "inimigo" (perto de um inimigo que ainda não percebeu o grupo). Andar vale em qualquer momento de exploração.
static func atual(ctx: Dictionary) -> Dictionary:
	var em_combate: bool = ctx.get("combate", false)
	for p in PASSOS:
		var id: String = p["id"]
		if feitas.has(id):
			continue
		match id:
			"andar":
				if not em_combate:
					return p
			"examinar":
				if not em_combate and ctx.get("pista", false):
					return p
			"agachar":
				if not em_combate and ctx.get("inimigo", false):
					return p
			"atacar":
				if em_combate:
					return p
	return {}


static func para_save() -> Array:
	return feitas.keys()


static func do_save(lista: Variant) -> void:
	feitas.clear()
	if lista is Array:
		for id in lista:
			feitas[str(id)] = true
