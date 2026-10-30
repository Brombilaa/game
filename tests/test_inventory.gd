extends SceneTree
# Teste headless da mochila (20 espaços, pilhas). Rodar com:
#   godot --headless --path . -s tests/test_inventory.gd

var failures := 0


func _init() -> void:
	var data := GameData.new()
	_check(data.load_dir(), "dados carregam")
	var inv := Inventory.new(data)
	_check(inv.used() == 0 and inv.slots.size() == 20, "mochila vazia com 20 espaços")
	_check(inv.stack_max("bandagem") == 5, "bandagem empilha até 5")
	_check(inv.stack_max("pistola") == 1, "arma não empilha")

	_check(inv.add("bandagem", 7) == 0, "7 bandagens cabem")
	_check(inv.used() == 2 and inv.count("bandagem") == 7, "7 bandagens ocupam 2 espaços (5 + 2)")
	_check(inv.add("bandagem", 3) == 0 and inv.used() == 2, "completa a pilha antes de abrir outra")
	_check(inv.count("bandagem") == 10, "10 bandagens")

	_check(inv.remove("bandagem", 4), "tira 4 bandagens")
	_check(inv.count("bandagem") == 6, "sobram 6")
	_check(not inv.remove("bandagem", 9) and inv.count("bandagem") == 6, "tirar demais não mexe em nada")
	_check(inv.remove("bandagem", 6) and inv.used() == 0, "esvazia e libera os espaços")

	for i in 20:
		inv.add("pistola")
	_check(inv.used() == 20 and inv.free_slot() == -1, "20 armas enchem a mochila")
	_check(inv.add("pistola", 2) == 2, "o que não cabe volta como resto")
	var gone := inv.discard(3)
	_check(gone["id"] == "pistola" and inv.used() == 19 and inv.free_slot() == 3, "descartar libera o espaço")

	print("Falhas: ", failures)
	quit(failures)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
