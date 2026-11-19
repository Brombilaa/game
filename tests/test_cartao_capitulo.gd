extends SceneTree
# Teste headless do cartão de capítulo: fade de entrada, saída por tecla e sinal `terminou`. Rodar com:
#   godot --headless --path . -s tests/test_cartao_capitulo.gd

var failures := 0
var _fim := false


func _initialize() -> void:
	_run()


func _run() -> void:
	var c := CartaoCapitulo.tocar(root, "AURORA", "CAPÍTULO 1", 2.0)
	c.terminou.connect(func() -> void: _fim = true)
	await process_frame
	_check(c.titulo == "AURORA", "o cartão leva o nome AURORA")
	_check(c.alfa() < 0.2, "começa quase transparente (fade de entrada)")
	c._t = 1.5
	_check(is_equal_approx(c.alfa(), 1.0), "no meio está opaco")
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	c._input(ev)
	_check(c._saindo, "qualquer tecla adianta a saída")
	c._t = c.duracao + c.fade + 0.1
	await process_frame
	await process_frame
	_check(_fim, "emite terminou e some")
	_check(not is_instance_valid(c), "o cartão se remove da árvore")
	print("Falhas: ", failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
