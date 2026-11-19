extends SceneTree
# Teste do painel do inventário (N2, vidro fosco). Rodar com:
#   godot --headless --path . -s tests/test_inventory_panel.gd
# Cobre abrir/fechar, a lista só com espaços ocupados, filtro de abas, rolagem, clique para escolher,
# botão Equipar, placa de desfoque e radar/objetivos escondidos. As regras da mochila ficam em test_inventory.gd.

var failures := 0


func _initialize() -> void:
	Missao1.reiniciar()
	var room = load("res://scenes/exploration/parque.tscn").instantiate()
	root.add_child(room)
	for i in 6:
		await process_frame
	var ip: InventoryPanel = room.inv_panel
	_check(not ip.open and ip.panel_rect() == Rect2(), "fechado: sem placa de desfoque")
	ip.toggle()
	for i in 300:
		if ip.t >= 1.0:
			break
		await process_frame
	_check(ip.open and ip.t == 1.0, "B abre e a animação termina")
	_check(room._hud_blur_rects().has(ip.panel_rect()), "aberto: a placa entra no desfoque do HUD")
	var all := ip._visible_slots()
	_check(all.size() == room.inventory.used(), "a lista tem um cartão por espaço ocupado")
	ip.tab = 3
	var vests := ip._visible_slots()
	_check(not vests.is_empty() and vests.size() < all.size(), "aba Coletes filtra a lista")
	for i in vests:
		_check(room.gear_item_kind(str(room.inventory.slots[i]["id"])) == "colete", "só coletes na aba")
	ip.tab = 0
	# clicar no primeiro cartão escolhe o item
	var first := ip._row_rect(0)
	ip._click(first.get_center())
	_check(ip.sel.get("kind") == "bag" and ip.sel.get("i") == all[0], "clique escolhe o item")
	# rolagem: com muitos itens a janela mostra só 6 fileiras
	_check(ip._row_rect(12) == Rect2(), "cartões fora da janela não têm área clicável")
	_check(ip._max_scroll() == maxi(ceili(all.size() / 2.0) - InventoryPanel.VISIBLE_ROWS, 0), "rolagem máxima bate com a lista")
	# botão Equipar com um colete escolhido
	var colete := -1
	for i in all:
		if str(room.inventory.slots[i]["id"]) == "colete_leve":
			colete = i
	_check(colete >= 0, "a mochila tem colete leve")
	ip.sel = {"kind": "bag", "i": colete}
	ip._click(ip._button_rect(0).get_center())
	_check(room.gear_slot_id(ip._member(), "colete") == "colete_leve", "botão Equipar põe o colete no personagem")
	# trocar de personagem pelo cartão
	ip._click(ip._portrait_rect(1).get_center())
	_check(ip.viewed == 1 and ip.sel.is_empty(), "cartão do grupo troca o personagem visto")
	# fecha pelo X
	ip._click(ip._close_rect().get_center())
	for i in 300:
		if ip.t <= 0.0:
			break
		await process_frame
	_check(not ip.open and ip.t == 0.0 and room._hud_blur_rects().is_empty(), "X fecha e a placa some")
	print("Falhas: %d" % failures if failures > 0 else "OK: painel do inventário")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FALHA: ", what)
