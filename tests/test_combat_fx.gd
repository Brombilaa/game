extends SceneTree
# Teste headless da animação de combate (modelo B, Léo 01/11/2026). Rodar com:
#   godot --headless --path . -s tests/test_combat_fx.gd

var failures := 0
var impacts := 0


func _init() -> void:
	var fx := CombatFx.new()
	fx.rng.seed = 1
	fx.impact.connect(func(_job: Dictionary) -> void: impacts += 1)
	var a := Combatant.new()
	a.weapon = {"melee": false}
	var t := Combatant.new()
	t.max_pv = 20
	t.pv = 20
	t.pos = Vector2(100, 0)

	t.pv = 14  # o golpe já foi resolvido pelas regras: 20 -> 14
	fx.start(a, t, {"ok": true, "hit": true, "crit": false, "blocked": false, "damage": 6}, 20)
	_check(fx.active() and fx.displayed_pv(t) == 20, "a barra fica no PV antigo até o impacto")
	fx.update(0.3)
	_check(impacts == 0 and fx.active(), "a mira dura 0,6 s")
	_check(is_equal_approx(CombatFx.aim_progress(fx.jobs[0]), 0.5), "o retículo fecha com o tempo")
	fx.update(0.31)
	_check(impacts == 1 and not fx.active(), "o impacto acontece ao fim da mira")
	_check(fx.displayed_pv(t) == 14, "depois do impacto a barra mostra o PV novo")
	_check(fx.trail.has(t) and fx.trail[t]["from"] == 20, "a barra deixa um rastro claro do PV antigo")
	_check(is_equal_approx(fx.hitstop, CombatFx.HITSTOP_SECONDS), "parada de 90 ms")
	_check(is_equal_approx(fx.shake_px, 4.0) and fx.flash_red > 0.0 and fx.zoom_time > 0.0, "tremor de 4 px, flash vermelho e zoom")
	_check(fx.muzzles.size() == 1 and fx.particles.size() > 0, "clarão, fumaça, cápsula e sangue")
	fx.update(CombatFx.KNOCK_SECONDS * 0.5)
	_check(absf(fx.offset_of(t).x - CombatFx.KNOCK_PX) < 0.5, "o alvo é arremessado 10 px (no ponto mais longe)")
	_check(fx.zoom_factor() > 1.0 and fx.zoom_factor() <= 1.0 + CombatFx.ZOOM_PULSE + 0.0001, "zoom de até 8%")
	fx.update(2.0)
	_check(fx.offset_of(t) == Vector2.ZERO and fx.trail.is_empty() and fx.particles.is_empty() and fx.zoom_factor() == 1.0, "tudo volta ao normal")

	# Câmera: acompanha atacante e alvo (ponto médio) durante toda a animação e solta no fim.
	_check(fx.camera_focus() == Vector2.INF and not fx.animating(), "sem ataque a câmera segue o turno")
	a.pos = Vector2(0, 0)
	t.pos = Vector2(100, 40)
	t.pv = 14
	fx.start(a, t, {"ok": true, "hit": true, "crit": false, "blocked": false, "damage": 6}, 20)
	_check(fx.animating() and fx.camera_focus() == Vector2(50, 20), "durante a mira a câmera fica entre os dois")
	fx.update(0.61)
	_check(fx.animating() and fx.camera_focus() == Vector2(50, 20), "depois do impacto segue até o arremesso e o rastro acabarem")
	fx.update(2.0)
	_check(not fx.animating() and fx.camera_focus() == Vector2.INF, "no fim da animação a câmera é liberada")

	# Crítico: tremor de 7 px e arremesso de 18 px; e o abatido continua aparecendo até o fim.
	t.pv = 0
	fx.start(a, t, {"ok": true, "hit": true, "crit": true, "blocked": false, "damage": 14}, 14)
	_check(fx.dying().has(t), "o abatido aparece enquanto a mira não bate")
	fx.update(0.61)
	_check(is_equal_approx(fx.shake_px, 7.0) and fx.kicks[t]["dist"] == CombatFx.KNOCK_CRIT_PX, "crítico: 7 px de tremor e 18 px de arremesso")
	_check(fx.dying().has(t), "o abatido some só depois do arremesso")
	fx.update(1.0)
	_check(not fx.dying().has(t), "o abatido sai de cena")

	# Erro: o alvo desvia 10 px, sem tremor nem flash.
	t.pv = 20
	fx.shake_time = 0.0
	fx.flash_red = 0.0
	fx.start(a, t, {"ok": true, "hit": false, "crit": false, "blocked": false}, 20)
	fx.update(0.61)
	_check(fx.kicks.has(t) and fx.kicks[t]["dist"] == CombatFx.DODGE_PX and fx.flash_red == 0.0 and fx.shake_time == 0.0, "erro: o alvo desvia 10 px")

	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
