extends SceneTree
# Teste headless das falas soltas do grupo. Rodar com:
#   godot --headless --path . -s tests/test_falas_soltas.gd

var failures := 0


func _init() -> void:
	Missao1.reiniciar()
	# Dados: cada item tem id único, área de cenário existente, 1 a 2 linhas curtas de personagem conhecido.
	var ids := {}
	var areas := {}
	for f in FalasSoltas.dados()["falas"]:
		var id := str(f["id"])
		_check(not ids.has(id), "%s: id único" % id)
		ids[id] = true
		areas[str(f["area"])] = true
		_check(FileAccess.file_exists("res://data/cenarios/%s.json" % f["area"]), "%s: cenário %s existe" % [id, f["area"]])
		_check(f["falas"].size() >= 1 and f["falas"].size() <= 2, "%s: 1 a 2 linhas" % id)
		for l in f["falas"]:
			_check(str(l["texto"]).length() > 0 and str(l["texto"]).length() <= 100, "%s: texto curto" % id)
			_check(CaixaFala.NOMES.has(str(l["quem"])), "%s: personagem %s conhecido" % [id, l["quem"]])
			_check(str(l["quem"]) in ["fernando", "nikolai", "miguel"], "%s: só os agentes conversam (sem Caio e Letícia)" % id)
	# Relógio: não anda com o jogador ocupado; a primeira fala vem depois da espera inicial.
	var fs := FalasSoltas.new("parque")
	var vistas := ["marcas_pneu", "banco_quebrado"]  # a fala sobre uma pista só toca depois de o grupo examiná-la
	_check(FalasSoltas.new("parque").tick(100.0, true).is_empty(), "sem examinar nenhuma pista, a fala sobre pista não toca")
	Missao1.reiniciar()
	_check(fs.tick(100.0, false).is_empty(), "ocupado: não fala e não gasta o relógio")
	_check(fs.tick(FalasSoltas.PRIMEIRA_ESPERA - 1.0, true, vistas).is_empty(), "antes da espera: calada")
	var f1 := fs.tick(1.5, true, vistas)
	_check(str(f1.get("id", "")) == "parque_1", "primeira fala do parque, na ordem")
	_check(Missao1.tem("fala_parque_1"), "a fala vira marca (vai para o save)")
	# Intervalo entre falas e ordem.
	_check(fs.tick(FalasSoltas.ESPERA_MIN - 1.0, true, vistas).is_empty(), "intervalo mínimo respeitado")
	var f2 := fs.tick(FalasSoltas.ESPERA_MAX, true, vistas)
	_check(str(f2.get("id", "")) == "parque_2", "segunda fala, sem repetir a primeira")
	# Fala de outro lugar não toca aqui, e o que já foi dito não volta.
	_check(fs.proxima(vistas).get("id", "") == "parque_3", "próxima do parque")
	var fb := FalasSoltas.new("biblioteca")
	_check(fb.proxima().get("id", "") == "biblioteca_1", "cada lugar tem as suas falas")
	for i in 3:
		fs.tick(FalasSoltas.ESPERA_MAX, true, vistas)
	_check(fs.proxima(vistas).is_empty(), "esgotou: nada mais a dizer no parque")
	_check(fs.tick(FalasSoltas.ESPERA_MAX, true, vistas).is_empty(), "esgotado não fala")
	# Fala já dita num save carregado não repete.
	Missao1.reiniciar()
	Missao1.marcar("fala_biblioteca_1")
	_check(FalasSoltas.new("biblioteca").proxima(["fichario"]).get("id", "") == "biblioteca_2", "marca salva pula a fala já dita")
	Missao1.reiniciar()
	print("Falhas: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("ok   - ", name)
	else:
		failures += 1
		print("FAIL - ", name)
