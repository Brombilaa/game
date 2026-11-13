extends SceneTree
# Teste headless do HUD de combate e dos textos. Rodar com:
#   godot --headless --path . -s tests/test_combat_hud.gd

var failures := 0


func _init() -> void:
	# Textos.
	_check(HudText.pa_label(2, 3) == "PA 2/3", "texto de PA")
	_check(HudText.pa_label(-1, 3) == "PA 0/3", "PA negativo vira zero")
	_check(HudText.pa_label(5, 3) == "PA 3/3", "PA acima do máximo é limitado")
	_check(HudText.rejection_message("no_pa") == "PA insuficientes", "rejeição por falta de PA")
	_check(HudText.rejection_message("xyz") == HudText.UNKNOWN_REJECTION, "rejeição desconhecida tem texto genérico")
	_check(HudText.mode_label(true) == "COMBATE", "rótulo de combate")

	# HUD: começa em exploração, sem painel de turno.
	var hud := CombatHud.new()
	_check(hud.mode_label.text == "EXPLORAÇÃO", "começa em exploração")
	_check(not hud.turn_panel.visible, "painel de turno escondido fora do combate")

	# Combate começa: aviso aparece, mas o painel só abre quando um turno começa.
	hud.on_combat_started()
	_check(hud.mode_label.text == "COMBATE", "modo muda para combate")
	_check(not hud.notice_label.visible, "o combate começa direto, sem aviso")
	_check(not hud.turn_panel.visible, "sem turno confirmado, sem painel")

	hud.on_turn_started("Rafael", 3, 3)
	_check(hud.turn_panel.visible, "painel aparece no turno")
	_check(hud.unit_label.text == "Rafael", "nome da unidade atual")
	_check(hud.pips.get_child_count() == 3, "3 marcadores de PA")

	hud.on_pa_changed(1, 3)
	_check(hud.pa_label.text == "PA 1/3", "PA atualizado")
	_check(hud.pips.get_child_count() == 3, "marcadores não se acumulam")
	var full := 0
	for pip in hud.pips.get_children():
		if (pip as ColorRect).color == CombatHud.PIP_FULL:
			full += 1
	_check(full == 1, "1 marcador cheio")

	var pressed := [false]
	hud.end_turn_requested.connect(func() -> void: pressed[0] = true)
	hud.end_turn_button.pressed.emit()
	_check(pressed[0], "botão pede para passar o turno")

	hud.on_action_rejected("out_of_range")
	_check(hud.notice_label.text == "Fora de alcance", "aviso de ação rejeitada")

	hud.on_turn_ended()
	_check(not hud.turn_panel.visible, "painel fecha no fim do turno")

	hud.on_combat_ended()
	_check(hud.mode_label.text == "EXPLORAÇÃO", "volta para exploração")

	hud.free()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
