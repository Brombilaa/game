extends SceneTree
# A sala do Ghular às 21h (item 11 da conferência do roteiro): aberta, com agenda, cofre, gravador e quadro.
# O lado das 17h (porta trancada, chave do armário) fica em test_local3d.gd.
# Rodar com:
#   godot --headless --path . -s tests/test_sala_ghular.gd

const MARCAS_DAS_CENAS := ["delegacia17_chegada", "ghular_17h", "ghular_21h", "biblioteca_julia", "ligacao_juliana", "delegacia_tulio_morte", "cripta_ghular"]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false
	Missao1.reiniciar()
	for m in MARCAS_DAS_CENAS:
		Missao1.marcar(m)
	Missao1.local = "delegacia_21h"
	Missao1.chegada = ""
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	_check(room.portas.is_empty(), "21h: sem porta trancada no escritório")
	for cid in ["agenda_ghular", "cofre_ghular", "gravador_ghular", "quadro_flor"]:
		_check(room.scenario.clues.has(cid), "21h: o escritório tem a pista " + cid)
		var pos: Vector2 = room.scenario.clues[cid].pos
		_check(room.pathfinder.find_path(room.player.pos, pos, room._obstacles(room.player), room.player.radius).size() > 1, "21h: dá para chegar a " + cid)
	print("Falhas: %d" % failures if failures > 0 else "OK: test_sala_ghular")
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)
