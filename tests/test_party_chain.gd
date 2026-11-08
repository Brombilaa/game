extends SceneTree
# Teste headless da corrente do grupo: soltar um seguidor para o acompanhamento, prender volta a seguir.
# Rodar com:
#   godot --headless --path . -s tests/test_party_chain.gd

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var room = load("res://scenes/exploration/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var follower: Combatant = room.party[1]
	var link_center: Vector2 = room.party_hud.link_rect(0).get_center()
	_check(room._link_at(link_center) == 0, "o elo entre o 1º e o 2º cartão é clicável")
	_check(room._mouse_on_hud(link_center), "o elo conta como HUD (não move o personagem)")

	room._toggle_link(follower)
	_check(room.unlinked.has(follower), "soltar marca o seguidor como solto")
	var parado := follower.pos
	room.player.pos += Vector2(200, 0)
	for i in 30:
		room._update_followers(1.0 / 30.0)
	_check(follower.pos == parado, "seguidor solto não acompanha o líder")

	room._toggle_link(follower)
	_check(not room.unlinked.has(follower), "prender tira o seguidor da lista de soltos")
	for i in 30:
		room._update_followers(1.0 / 30.0)
	_check(follower.pos != parado, "seguidor preso volta a seguir o líder")

	room._toggle_link(follower)
	room._switch_to(follower)
	_check(not room.unlinked.has(follower), "quem vira líder volta à corrente")
	room._toggle_link(room.player)
	_check(not room.unlinked.has(room.player), "o líder não pode ser solto")

	room.queue_free()
	await process_frame
	print("falhas: ", failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
