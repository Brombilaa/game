class_name Inventory
extends RefCounted
# Mochila compartilhada do grupo (GDD #18): 20 espaços, cada pilha ocupa 1 espaço.
# Limite da pilha vem de data/itens.json (`pilha_max`); armas, coletes e itens sem limite
# não empilham. Cada espaço é {} (vazio) ou {"id": String, "qty": int}.

const SIZE := 20

var slots: Array[Dictionary] = []
var _data: GameData


func _init(data: GameData) -> void:
	_data = data
	for i in SIZE:
		slots.append({})


func stack_max(id: String) -> int:
	var cap = _data.get_entry("itens", id).get("pilha_max")
	return int(cap) if cap != null else 1


# Guarda `qty` de `id`, completando pilhas antes de abrir espaços. Retorna o que não coube.
func add(id: String, qty := 1) -> int:
	var cap := stack_max(id)
	for s in slots:
		if qty <= 0:
			return 0
		if not s.is_empty() and s["id"] == id and int(s["qty"]) < cap:
			var put := mini(cap - int(s["qty"]), qty)
			s["qty"] = int(s["qty"]) + put
			qty -= put
	for i in SIZE:
		if qty <= 0:
			return 0
		if slots[i].is_empty():
			var put := mini(cap, qty)
			slots[i] = {"id": id, "qty": put}
			qty -= put
	return qty


func count(id: String) -> int:
	var total := 0
	for s in slots:
		if not s.is_empty() and s["id"] == id:
			total += int(s["qty"])
	return total


# Tira `qty` de `id` (das últimas pilhas para as primeiras). Falso, sem mexer, se não houver o bastante.
func remove(id: String, qty := 1) -> bool:
	if count(id) < qty:
		return false
	for i in range(SIZE - 1, -1, -1):
		if qty <= 0:
			break
		if not slots[i].is_empty() and slots[i]["id"] == id:
			var take := mini(int(slots[i]["qty"]), qty)
			slots[i]["qty"] = int(slots[i]["qty"]) - take
			qty -= take
			if int(slots[i]["qty"]) <= 0:
				slots[i] = {}
	return true


# Descarta o espaço inteiro (o item some, GDD #18). Retorna o que havia.
func discard(index: int) -> Dictionary:
	var gone := slots[index]
	slots[index] = {}
	return gone


func used() -> int:
	var n := 0
	for s in slots:
		if not s.is_empty():
			n += 1
	return n


func free_slot() -> int:
	for i in SIZE:
		if slots[i].is_empty():
			return i
	return -1
