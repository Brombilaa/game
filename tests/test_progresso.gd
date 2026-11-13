extends SceneTree
# Teste headless do save de verdade (Progresso): o que entra no save, como volta para o lugar, o autosave
# ao chegar e no início do combate (sem a pista que disparou o combate) e o carregar abrindo a cena certa.
# Rodar com:
#   godot --headless --path . -s tests/test_progresso.gd

const DIR := "user://test_progresso"

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_cleanup()
	Progresso.dir = DIR
	Progresso.autosave_ativo = true
	Missao1.reiniciar()
	await _parque_ida_e_volta()
	await _combate_autosave()
	await _local_e_missao()
	await _carregar_abre_a_cena()
	_cleanup()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_progresso")
	quit(1 if failures > 0 else 0)


func _abrir(cena: String) -> Node:
	var room = load(cena).instantiate()
	root.add_child(room)
	await process_frame
	return room


func _fechar(room: Node) -> void:
	room.queue_free()
	await process_frame


func _parque_ida_e_volta() -> void:
	var room = await _abrir(Progresso.CENA_PARQUE)
	var auto := SaveSlots.load_slot(SaveSlots.AUTO, DIR)
	_check(auto.get("current_area") == "parque", "chegar no parque grava o autosave")
	_check(auto.get("rotulo") == "PARQUE", "o autosave guarda o nome do lugar para o menu")

	# Mexe no grupo e na mochila e fotografa.
	room.party[0].pv = 7
	room.party[1].san = 3
	room.seen_clues.append("balanco")
	room.inventory.slots[19] = {"id": "bandagem", "qty": 4}
	room.player = room.party[1]
	var data := Progresso.capturar(room, room._area_id(), room._place_label())
	_check(data["grupo"].size() == 3 and data["grupo"][0]["nome"] == "Fernando" and data["grupo"][0]["pv"] == 7, "o save guarda o PV de cada um")
	_check(data["grupo"][1]["san"] == 3, "o save guarda a SAN")
	_check(data["grupo"][2]["equip"]["principal"] == "espada", "o save guarda o equipamento")
	_check(data["pistas"] == ["balanco"], "o save guarda as pistas vistas")
	_check(data["lider"] == 1, "o save guarda quem está sendo controlado")
	_check(JSON.parse_string(JSON.stringify(data)) is Dictionary, "o conteúdo só tem tipos que o JSON guarda")
	await _fechar(room)

	# Abre de novo com o save pendente (passando pelo JSON, como no disco).
	SaveSlots.save(SaveSlots.manual(1), data, DIR)
	var lido := SaveSlots.load_slot(SaveSlots.manual(1), DIR)
	_check(Progresso.preparar_missao(lido) == Progresso.CENA_PARQUE, "save do parque abre o parque")
	Progresso.pendente = lido
	room = await _abrir(Progresso.CENA_PARQUE)
	_check(Progresso.pendente.is_empty(), "a cena consome o save pendente")
	_check(room.party[0].pv == 7 and room.party[1].san == 3, "PV e SAN voltam do save")
	_check(room.seen_clues.has("balanco"), "pistas vistas voltam do save")
	_check(room.inventory.slots[19] == {"id": "bandagem", "qty": 4}, "a mochila volta do save")
	_check(room.player == room.party[1], "o controlado volta do save")
	_check(room.party[2].weapon["id"] == "espada", "a arma equipada volta do save")
	await _fechar(room)


# O combate da árvore grava o autosave antes de começar, sem a pista da árvore: o Game Over volta para antes dele.
func _combate_autosave() -> void:
	Missao1.reiniciar()
	var room = await _abrir(Progresso.CENA_PARQUE)
	for cid in room.scenario.clues:
		if cid != "arvore_simbolo":
			room.seen_clues.append(cid)
	room.party[0].pv = 11
	room._show_dialog("", "teste", "arvore_simbolo")
	room._close_dialog()
	_check(room.mode == room.Mode.COMBAT, "a árvore começa o combate")
	var auto := SaveSlots.load_slot(SaveSlots.AUTO, DIR)
	_check(not auto.get("pistas", []).has("arvore_simbolo"), "o autosave do combate tira a pista que o disparou")
	_check(auto.get("pistas", []).size() == room.scenario.clues.size() - 1, "as outras pistas ficam no autosave")
	_check(int(auto["grupo"][0]["pv"]) == 11, "o autosave guarda o grupo de antes do combate")
	_check(room.pista_gatilho == "", "a marca da pista do gatilho é limpa depois")
	await _fechar(room)


func _local_e_missao() -> void:
	Missao1.reiniciar()
	Missao1.local = "delegacia_21h"
	Missao1.chegada = "subsolo"
	Missao1.marcar("alcapao")
	var room = await _abrir(Missao1.CENA_LOCAL)
	var auto := SaveSlots.load_slot(SaveSlots.AUTO, DIR)
	_check(auto.get("current_area") == "delegacia_21h", "chegar num lugar da missão grava o autosave")
	_check(auto["missao"]["local"] == "delegacia_21h" and auto["missao"]["chegada"] == "subsolo", "o save guarda o lugar e a chegada")
	_check(auto["missao"]["marcas"].has("alcapao"), "o save guarda as marcas da missão")
	await _fechar(room)
	Missao1.reiniciar()
	_check(Progresso.preparar_missao(auto) == Missao1.CENA_LOCAL, "save de um lugar abre a cena dos lugares")
	_check(Missao1.local == "delegacia_21h" and Missao1.chegada == "subsolo" and Missao1.tem("alcapao"), "a missão volta como estava")
	_check(Progresso.preparar_missao({"current_area": "parque"}) == "", "save sem a missão é recusado")
	Missao1.reiniciar()


func _carregar_abre_a_cena() -> void:
	_check(not Progresso.carregar(self, SaveSlots.manual(3)), "slot vazio não carrega")
	_check(Progresso.carregar(self, SaveSlots.manual(1)), "Carregar aceita o slot com save")
	_check(not Progresso.pendente.is_empty() and Missao1.local == "", "o save fica pendente para a cena")
	var waited := 0.0
	while Scenes.busy(self) and waited < 5.0:
		await process_frame
		waited += 1.0 / 60.0
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == Progresso.CENA_PARQUE, "Carregar abre o parque")
	_check(current_scene != null and current_scene.party[0].pv == 7, "o lugar aberto já tem o grupo do save")
	if current_scene:
		current_scene.queue_free()
		await process_frame


func _cleanup() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(DIR)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("ok    - " + label)
	else:
		failures += 1
		print("FALHA - " + label)
