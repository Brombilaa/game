extends SceneTree
# Teste headless dos lugares 3D da missão 1 (delegacia 17h e 21h, subsolo, biblioteca, Fazenda Ghular):
# dados válidos, grupo começa livre, saídas alcançáveis, tapete revela o alçapão, invasão na volta do subsolo,
# inimigos do celeiro, o caminho em grade, a cripta (trechos revelados, área elevada, Roberto Ghular e a Dama de Sangue)
# e o fim da missão 1 (a Dama a 30%: cutscene do tentáculo, modo cinema).
# Rodar com:
#   godot --headless --path . -s tests/test_local3d.gd

const LOCAIS := ["delegacia_17h", "delegacia_21h", "subsolo", "biblioteca", "fazenda", "cripta", "celeiro"]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	Progresso.autosave_ativo = false  # não mexe nos saves de quem roda os testes
	_pathfinder_grade()
	for id in LOCAIS:
		var s := Scenario.load_id(id)
		_check(s.ok(), id + ": dados válidos " + ", ".join(s.errors))
	for id in LOCAIS:
		await _local(id)
	await _investigacao()
	await _porta_com_chave()
	await _baus()
	await _tapete_e_alcapao()
	await _invasao()
	await _celeiro()
	await _cripta()
	_cinema_e_tentaculo()
	await _fim_da_missao()
	await _celeiro_ordem()
	print("Falhas: %d" % failures if failures > 0 else "OK: test_local3d")
	quit(1 if failures > 0 else 0)


# Marcas das cenas de diálogo que tocam sozinhas ao chegar (as falas novas de 22/11): os testes de alcance, saque e
# combate não as esperam. `_cenas_de_dialogo` testa as cenas de verdade.
const MARCAS_DAS_CENAS := ["delegacia17_chegada", "ghular_17h", "ghular_21h", "biblioteca_julia", "ligacao_juliana", "cripta_ghular"]


func _abrir(id: String, chegada := "", com_cenas := false) -> Node:
	if not com_cenas:
		for m in MARCAS_DAS_CENAS:
			Missao1.marcar(m)
	Missao1.local = id
	Missao1.chegada = chegada
	var room = load(Missao1.CENA_LOCAL).instantiate()
	root.add_child(room)
	await process_frame
	return room


func _fechar(room: Node) -> void:
	room.queue_free()
	await process_frame


func _local(id: String) -> void:
	Missao1.reiniciar()
	Missao1.marcar("porta_escritorio_ghular")  # aqui o teste é de alcance; a porta trancada tem teste próprio
	var room = await _abrir(id)
	_check(room.scenario.id == id and room.world3d != null, id + ": abre com o cenário 3D")
	_check(room.world3d.mundo.get_node_or_null("cenario") != null, id + ": malhas carregadas")
	for m in room.party:
		_check(Pathfinder.is_free(m.pos, room._obstacles(m), m.radius), id + ": %s começa em ponto livre" % m.name)
	for z in room.dados.get("zonas", []):
		var alvo: Vector2 = _ponto_livre(room, room._ret(z))
		var t0 := Time.get_ticks_msec()
		var rota: PackedVector2Array = room.pathfinder.find_path(room.player.pos, alvo, room._obstacles(room.player), room.player.radius)
		_check(rota.size() > 1, id + ": a zona %s é alcançável" % z["id"])
		_check(Time.get_ticks_msec() - t0 < 1500, id + ": rota até %s em menos de 1,5 s (%d ms)" % [z["id"], Time.get_ticks_msec() - t0])
	for cid in room.scenario.clues:
		var c: Dictionary = room.scenario.clues[cid]
		var ok := false
		for k in 16:
			var spot: Vector2 = c.pos + Vector2.from_angle(TAU * k / 16.0) * c.raio * room.STAND_FACTOR
			if room.pathfinder.find_path(room.player.pos, spot, room._obstacles(room.player), room.player.radius).size() > 1:
				ok = true
				break
		_check(ok, id + ": dá para chegar perto da pista " + cid)
	for e in room.enemies:
		_check(Pathfinder.is_free(e.pos, room._obstacles(e), e.radius), id + ": inimigo nasce em ponto livre")
	# Saída: entrar na zona leva ao próximo lugar (sem esperar a transição).
	for z in room.dados.get("zonas", []):
		if z.has("requer") or str(z.get("acao", "")) != "ir":
			continue
		room.player.pos = room._ret(z).get_center()
		room._zonas()
		_check(room.indo_para == str(z["para"]), id + ": a zona %s leva a %s" % [z["id"], z["para"]])
		break
	await _fechar(room)


func _investigacao() -> void:
	# Delegacia das 17h e biblioteca têm pistas: documentos, itens no chão e gavetas (textos provisórios).
	for id in ["delegacia_17h", "biblioteca"]:
		Missao1.reiniciar()
		var room = await _abrir(id)
		_check(room.scenario.clues.size() >= 5, id + ": tem pelo menos 5 pistas")
		for cid in room.scenario.clues:
			var c: Dictionary = room.scenario.clues[cid]
			_check(str(c.texto).length() > 20, id + ": a pista %s tem texto" % cid)
			_check(Pathfinder.is_free(c.pos, room._obstacles(room.player), room.player.radius), id + ": a pista %s fica em ponto livre" % cid)
		var antes: int = room.inventory.count("kit_primeiros_socorros") + room.inventory.count("municao_pistola") + room.inventory.count("curativo")
		for cid in room.scenario.clues:
			room._inspect(cid)
			room._close_dialog()
		_check(room.seen_clues.size() == room.scenario.clues.size(), id + ": todas as pistas podem ser lidas")
		var depois: int = room.inventory.count("kit_primeiros_socorros") + room.inventory.count("municao_pistola") + room.inventory.count("curativo")
		_check(depois > antes, id + ": achar itens nas pistas enche a mochila")
		await _fechar(room)


func _porta_com_chave() -> void:
	Missao1.reiniciar()
	var room = await _abrir("delegacia_17h")
	var pt: Dictionary = room.portas["escritorio_ghular"]
	var r: Rect2 = pt["rect"]
	_check(room.walls.has(r), "17h: a porta do escritório começa trancada (sólida)")
	_check(pt["no"] != null, "17h: a porta trancada aparece no cenário")
	var pista: Vector2 = room.scenario.clues["agenda_ghular"].pos
	_check(room.pathfinder.find_path(room.player.pos, pista, room._obstacles(room.player), room.player.radius).size() < 2, "17h: sem a chave não dá para chegar ao escritório")
	for i in room.party.size():
		room.party[i].pos = r.get_center() + Vector2(-40.0 + 40.0 * i, 40)
	room._portas()
	_check(room.dialog_layer.visible and room.walls.has(r), "17h: sem a chave aparece o aviso de porta trancada")
	room.dialog_layer.visible = false
	room._inspect("chaveiro_recepcao")
	room._close_dialog()
	_check(room.inventory.count("chave_escritorio") == 1, "17h: o chaveiro dá a chave")
	room._portas()
	_check(not room.walls.has(r) and Missao1.tem("porta_escritorio_ghular"), "17h: com a chave a porta abre sozinha e fica marcada")
	_check(room.pathfinder.find_path(room.player.pos, pista, room._obstacles(room.player), room.player.radius).size() > 1, "17h: com a porta aberta dá para chegar ao escritório")
	await _fechar(room)
	var room2 = await _abrir("delegacia_17h")
	_check(not room2.walls.has(r) and room2.portas.is_empty(), "17h: porta aberta continua aberta ao voltar")
	await _fechar(room2)


func _baus() -> void:
	# Baús e esconderijos com saque (16/11, provisório): chave achada num lugar abre o baú trancado de outro.
	var pares := {"biblioteca": ["gaveta_balcao", "armario_acervo", "chave_acervo"], "fazenda": ["prego_mourao", "bau_celeiro", "chave_celeiro"], "cripta": ["mochila_desaparecido", "ossuario", "chave_ossuario"]}
	for id in pares:
		Missao1.reiniciar()
		var room = await _abrir(id)
		var onde: Array = pares[id]
		var bau: Dictionary = room.scenario.clues[onde[1]]
		_check(bau.chave == onde[2] and not bau.da.is_empty(), id + ": o baú " + onde[1] + " é trancado e tem saque")
		if id == "cripta":
			_check(room._pista_oculta("ossuario"), id + ": o ossuário fica escondido até o salão ser revelado")
			Missao1.marcar("cripta_trecho4")
			_check(not room._pista_oculta("ossuario"), id + ": o ossuário aparece com o salão revelado")
		var antes: int = room.inventory.count("curativo") + room.inventory.count("bandagem") + room.inventory.count("kit_primeiros_socorros") + room.inventory.count("municao_pistola") + room.inventory.count("municao_escopeta")
		room._inspect(onde[1])
		_check(room.dialog_layer.visible and room.dialog_text.text == bau.texto_trancado, id + ": sem a chave aparece o aviso de trancado")
		room._close_dialog()
		_check(not room.seen_clues.has(onde[1]), id + ": o baú trancado não conta como visto sem a chave")
		room._inspect(onde[0])
		room._close_dialog()
		_check(room.inventory.count(onde[2]) == 1, id + ": a chave " + onde[2] + " está num esconderijo do cenário")
		room._inspect(onde[1])
		_check(room.dialog_text.text == bau.texto, id + ": com a chave o baú abre")
		room._close_dialog()
		_check(room.seen_clues.has(onde[1]), id + ": o baú aberto fica visto")
		var depois: int = room.inventory.count("curativo") + room.inventory.count("bandagem") + room.inventory.count("kit_primeiros_socorros") + room.inventory.count("municao_pistola") + room.inventory.count("municao_escopeta")
		_check(depois > antes, id + ": o saque do baú entra na mochila")
		await _fechar(room)
	# Delegacia: o cofre fica atrás da porta trancada do escritório (a chave do chaveiro vale pelas duas coisas).
	Missao1.reiniciar()
	var del = await _abrir("delegacia_17h")
	var cofre: Vector2 = del.scenario.clues["cofre_ghular"].pos
	_check(del.pathfinder.find_path(del.player.pos, cofre, del._obstacles(del.player), del.player.radius).size() < 2, "17h: sem a chave do escritório o cofre é inalcançável")
	del.inventory.add("chave_escritorio", 1)
	del.party[0].pos = (del.portas["escritorio_ghular"]["rect"] as Rect2).get_center() + Vector2(0, 40)
	del._portas()
	_check(del.pathfinder.find_path(del.player.pos, cofre, del._obstacles(del.player), del.player.radius).size() > 1, "17h: com a porta aberta o cofre é alcançável")
	await _fechar(del)
	# Todos os itens do saque existem nos dados.
	var dados_jogo := GameData.new()
	dados_jogo.load_dir()
	for id in ["delegacia_17h", "biblioteca", "fazenda", "cripta", "parque"]:
		var sc := Scenario.load_id(id)
		for cid in sc.clues:
			for f in sc.clues[cid].da:
				_check(dados_jogo.has_entry("itens", str(f["item"])) or dados_jogo.has_entry("armas", str(f["item"])), id + ": o item " + str(f["item"]) + " do saque de " + cid + " existe")


func _tapete_e_alcapao() -> void:
	Missao1.reiniciar()
	var room = await _abrir("delegacia_21h")
	var w = room.world3d
	_check(w.tem_estado("tapete") and w.tem_estado("alcapao"), "21h: o cenário tem tapete e alçapão")
	_check(_visivel(w, "tapete") and not _visivel(w, "alcapao"), "21h: chega com o tapete cobrindo o alçapão")
	var hatch: Dictionary = {}
	for z in room.dados["zonas"]:
		if z["id"] == "alcapao":
			hatch = z
	room.player.pos = Vector2(hatch["ret"][0], hatch["ret"][1] + hatch["ret"][3] + 40)
	room._zonas()
	room.player.pos = room._ret(hatch).get_center()
	room._zonas()
	_check(room.indo_para == "", "antes de olhar o tapete o alçapão não leva a lugar nenhum")
	room._inspect("tapete")
	room._close_dialog()
	_check(not _visivel(w, "tapete") and _visivel(w, "alcapao"), "olhar o tapete revela o alçapão")
	_check(Missao1.tem("alcapao"), "o alçapão aberto fica marcado para a volta")
	room.player.pos = Vector2(hatch["ret"][0], hatch["ret"][1] + hatch["ret"][3] + 40)
	room._zonas()
	room.player.pos = room._ret(hatch).get_center()
	room._zonas()
	_check(room.indo_para == "subsolo", "depois o alçapão leva ao subsolo")
	await _fechar(room)


func _invasao() -> void:
	Missao1.reiniciar()
	Missao1.marcar("alcapao")
	var room = await _abrir("delegacia_21h", "subsolo")
	await process_frame
	_check(_visivel(room.world3d, "alcapao"), "na volta do subsolo o alçapão continua aberto")
	for m in room.party:
		_check(Pathfinder.is_free(m.pos, room._obstacles(m), m.radius), "volta do subsolo: %s chega em ponto livre" % m.name)
	_check(room.mode == room.Mode.EXPLORATION and room.enemies.is_empty(), "na saída do subsolo ainda não há invasão")
	# Invasão (Léo, 13/11): ao entrar na recepção vindo do corredor, flashbang e atiradores pela porta da frente.
	var zona: Dictionary = {}
	for z in room.dados["zonas"]:
		if z["id"] == "invasao":
			zona = z
	_check(not zona.is_empty(), "há a zona da invasão perto da recepção")
	Missao1.marcar("subsolo_visitado")  # o subsolo marca ao chegar
	room.player.pos = room._ret(zona).get_center() - Vector2(0, room._ret(zona).size.y)
	room._zonas()
	room.player.pos = room._ret(zona).get_center()
	room._zonas()
	_check(room.invadindo, "entrar na recepção dispara a flashbang")
	await create_timer(room.FLASH_SOBE + room.FLASH_SEGURA + 0.3).timeout
	_check(room.mode == room.Mode.COMBAT and room.enemies.size() == 3, "depois da flashbang os inimigos invadem e o combate começa")
	for e in room.enemies:
		_check(e.name == "Atirador", "o invasor é atirador")
	for e in room.enemies:
		var rota: PackedVector2Array = room.pathfinder.find_path(e.pos, room.player.pos, room._obstacles(e, false), e.radius)
		_check(rota.size() > 1, "o invasor alcança o grupo")
	var saida: Dictionary = {}
	for z in room.dados["zonas"]:
		if z["id"] == "saida":
			saida = z
	_check(saida.get("requer", "") == "invasao_vencida", "só sai para a fazenda depois de vencer a invasão")
	await _fechar(room)
	Missao1.chegada = ""
	room = await _abrir("delegacia_21h")
	_check(room.mode == room.Mode.EXPLORATION and room.enemies.is_empty(), "chegando pela rua não há invasão")
	await _fechar(room)


func _celeiro() -> void:
	Missao1.reiniciar()
	var room = await _abrir("fazenda")
	_check(room.enemies.size() == 3 and room.mode == room.Mode.EXPLORATION, "fazenda: inimigos no celeiro, sem combate na chegada")
	for e in room.enemies:
		var rota: PackedVector2Array = room.pathfinder.find_path(room.player.pos, e.pos, room._obstacles(room.player, false), room.player.radius)
		_check(rota.size() > 1, "fazenda: dá para chegar até o inimigo do celeiro")
	await _fechar(room)


# Cripta (Léo, 14/11): o poço leva a ela; o cenário aparece por trechos; 2 inimigos desprevenidos no corredor e 7 no
# salão contando Roberto Ghular; área elevada; Roberto se mata com pouca vida e a Dama de Sangue surge; a Letícia só
# acorda depois do combate.
func _cripta() -> void:
	Missao1.reiniciar()
	var room = await _abrir("fazenda")
	room._inspect("poco")
	room._close_dialog()
	_check(room.indo_para == "cripta", "fazenda: examinar o poço leva à cripta")
	await _fechar(room)
	Missao1.reiniciar()
	room = await _abrir("cripta")
	var w = room.world3d
	_check(not _visivel(w, "trecho2") and not _visivel(w, "trecho3") and not _visivel(w, "trecho4"), "cripta: chega só com o primeiro trecho à vista")
	_check(room.enemies.size() == 2, "cripta: 2 inimigos nos primeiros corredores (%d)" % room.enemies.size())
	_check(room.enemies[0].perception < 200.0, "cripta: os do corredor estão desprevenidos (percebem menos)")
	_check(room._known_rects().size() == 2, "cripta: o minimapa só conhece o primeiro trecho")
	for n in [2, 3, 4]:
		_entrar_na_zona(room, "trecho%d_0" % n)
		_check(_visivel(w, "trecho%d" % n) and Missao1.tem("cripta_trecho%d" % n), "cripta: entrar na faixa revela o trecho %d" % n)
	_check(room.enemies.size() == 9, "cripta: com o salão revelado são 2 + 7 inimigos (%d)" % room.enemies.size())
	var roberto: Combatant = null
	for e in room.enemies:
		if e.name == "Roberto Ghular":
			roberto = e
	_check(roberto != null, "cripta: Roberto Ghular está no salão")
	# Área elevada: o atirador do terraço fica a 1,5 m; o chão do salão a 0; a tela volta ao mesmo ponto.
	var alto: Combatant = null
	for e in room.enemies:
		if room._altura(e.pos) > 1.4:
			alto = e
	_check(alto != null, "cripta: há um inimigo na área elevada")
	_check(room._altura(roberto.pos) == 0.0, "cripta: o salão fica no nível do chão")
	if alto != null:
		_check(room._uniso(room._iso(alto.pos)).distance_to(alto.pos) < 1.0, "cripta: o clique acha o ponto do terraço")
		_check(Pathfinder.has_line_of_sight(alto.pos, roberto.pos, room._sight_blockers()), "cripta: do terraço se enxerga o salão por cima do parapeito")
		_check(not Pathfinder.has_line_of_sight(alto.pos, roberto.pos, room.walls), "cripta: mas não se desce do terraço fora da escada")
		var rota: PackedVector2Array = room.pathfinder.find_path(room.party[0].pos, alto.pos + Vector2(40, 0), room._obstacles(room.party[0], false), room.party[0].radius)
		_check(rota.size() > 1, "cripta: dá para subir até o terraço pela rota alta")
	_check(room._uniso(room._iso(roberto.pos)).distance_to(roberto.pos) < 1.0, "cripta: o clique acha o ponto do chão")
	var meio := Vector2((13.8 + 8.0) * 64.0, (25.5 - 2.0) * 64.0)  # meio da escada da rota alta
	_check(absf(room._altura(meio) - 0.75) < 0.1, "cripta: no meio da escada a altura é a metade (%.2f)" % room._altura(meio))
	# A Letícia não acorda antes do combate.
	room._inspect("leticia")
	room._close_dialog()
	_check(not room.seen_clues.has("leticia"), "cripta: antes do combate a Letícia não acorda")
	# Roberto com pouca vida: ele cai e a Dama de Sangue entra no mesmo combate.
	room._start_combat()
	roberto.pv = 8
	room._show_attack(room.player, roberto, {"ok": true, "hit": true, "damage": 3, "crit": false, "blocked": false})
	var dama: Combatant = null
	for e in room.enemies:
		if e.name == "Dama de Sangue":
			dama = e
	_check(not roberto.is_alive() and dama != null and dama.is_alive(), "cripta: Roberto se mata e a Dama de Sangue surge")
	_check(dama != null and room.turns._by_initiative.has(dama) and room.mode == room.Mode.COMBAT, "cripta: a Dama entra no combate em andamento")
	_check(Missao1.tem("dama_surgiu") and not Missao1.tem("cripta_vencida"), "cripta: a marca da Dama fica no save")
	for e in room.enemies:
		e.pv = 0
	room.turns.action_done()
	_check(room.mode == room.Mode.EXPLORATION and Missao1.tem("cripta_vencida") and Missao1.tem("cripta_corredor_limpo"), "cripta: vencer a Dama fecha o combate e marca a cripta")
	room._inspect("leticia")
	room._close_dialog()
	_check(room.seen_clues.has("leticia") and Missao1.tem("leticia_acordou"), "cripta: depois do combate a Letícia acorda ao interagir")
	_check(room.indo_para == "celeiro", "cripta: com a Letícia acordada o grupo sobe para o celeiro")
	await _fechar(room)
	# Voltar de um save: trechos revelados continuam à vista e quem já caiu não volta.
	room = await _abrir("cripta")
	await process_frame
	_check(_visivel(room.world3d, "trecho4") and room.enemies.is_empty(), "cripta: ao carregar, o salão segue revelado e sem inimigos")
	await _fechar(room)
	Missao1.reiniciar()
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4", "dama_surgiu"]:
		Missao1.marcar(m)
	room = await _abrir("cripta")
	var nomes: Array = []
	for e in room.enemies:
		nomes.append(e.name)
	_check(nomes.has("Dama de Sangue") and not nomes.has("Roberto Ghular"), "cripta: save feito depois de a Dama surgir volta com ela")
	await _fechar(room)


# Pós-combate (Léo, 15/11): no celeiro, sem o Fernando, a Ordem espera com a Letícia; a conversa toca ao chegar e
# depois vem o fim do capítulo (cutscene externa, se o vídeo existir, e o cartão AURORA).
func _celeiro_ordem() -> void:
	Missao1.reiniciar()
	for m in ["cripta_vencida", "fernando_morreu", "leticia_acordou"]:
		Missao1.marcar(m)
	var room = await _abrir("celeiro", "poco")
	_check(room.enemies.is_empty(), "celeiro: sem inimigos")
	for n in ["leticia", "tristan", "mark", "julia", "medico"]:
		_check(room.scenario.npcs.has(n), "celeiro: %s está lá" % n)
		if room.scenario.npcs.has(n):
			_check(Pathfinder.is_free(room.scenario.npcs[n], room.walls, room.NPC_RADIUS), "celeiro: %s em ponto livre" % n)
	var fernando: Combatant = room.party[0]
	_check(fernando.name == "Fernando" and fernando.dead and room.player != fernando, "celeiro: o Fernando não volta e outro lidera")
	_check(not room._drawn_units().has(fernando), "celeiro: o corpo do Fernando ficou na cripta")
	await process_frame
	_check(room.mode == room.Mode.CUTSCENE and room.cena != null, "celeiro: a conversa com a Ordem toca ao chegar")
	Engine.time_scale = 4.0
	for i in 60 * 40:
		await process_frame
		if room.fim_capitulo != null:
			break
	_check(Missao1.tem("celeiro_conversa"), "celeiro: a conversa marca que já tocou")
	_check(room.fim_capitulo != null and room.mode == room.Mode.CUTSCENE, "celeiro: depois da conversa vem o fim do capítulo")
	var fim: FimCapitulo = room.fim_capitulo
	var viu_italia := false
	for i in 60 * 30:
		await process_frame
		viu_italia = viu_italia or (is_instance_valid(fim) and fim.italia != null)
		if Missao1.tem("capitulo1_fim"):
			break
	_check(viu_italia, "celeiro: sem o vídeo, corta para a igreja na Itália antes do cartão")
	Engine.time_scale = 1.0
	_check(Missao1.tem("capitulo1_fim"), "celeiro: o cartão AURORA toca e o capítulo termina")
	await _fechar(room)
	# Save feito depois da conversa: vai direto ao fim, sem repetir as falas.
	Missao1.reiniciar()
	for m in ["fernando_morreu", "celeiro_conversa"]:
		Missao1.marcar(m)
	room = await _abrir("celeiro", "poco")
	await process_frame
	await process_frame
	_check(room.cena == null and room.fim_capitulo != null, "celeiro: carregar depois da conversa vai direto ao fim")
	await _fechar(room)


# Modo cinema e curva do tentáculo (sem cena).
func _cinema_e_tentaculo() -> void:
	var tela := Vector2(1920, 1080)
	var faixas := Cinema.janela(Cinema.Modo.FAIXAS, tela)
	_check(absf(faixas.size.x / faixas.size.y - 2.39) < 0.01 and faixas.size.x == tela.x and absf(faixas.get_center().y - 540.0) < 0.5, "cinema: faixas 2,39:1 centradas, de borda a borda")
	var vertical := Cinema.janela(Cinema.Modo.VERTICAL, tela)
	_check(absf(vertical.size.x / vertical.size.y - 9.0 / 16.0) < 0.01 and vertical.size.y == tela.y, "cinema: janela vertical 9:16")
	var quadro := Cinema.janela(Cinema.Modo.QUADRO, tela)
	_check(absf(quadro.size.x / quadro.size.y - 16.0 / 9.0) < 0.01 and quadro.size.x < tela.x, "cinema: quadro 16:9 menor que a tela")
	var t := Tentaculo3D.new()
	var pts: Array[Vector3] = [Vector3(0, 2, 0), Vector3(1, 4, 0), Vector3(3, 0.1, 1), Vector3(5, 1.5, 2)]
	t.definir(pts)
	_check(t.comprimento > 6.0, "tentáculo: a curva tem comprimento (%.1f)" % t.comprimento)
	_check(t.fracao_em(0) == 0.0 and t.fracao_em(1) < t.fracao_em(2) and t.fracao_em(2) < t.fracao_em(3) and absf(t.fracao_em(3) - 1.0) < 0.001, "tentáculo: as frações dos pontos de controle crescem até 1")
	t.crescimento = 1.0
	_check(t.ponta().distance_to(pts[3]) < 0.01, "tentáculo: com tudo crescido a ponta está no último ponto")
	t.free()


# Fim da missão 1 (Léo, 20/11): a Dama não morre antes da cena; a cena começa com ela em 15% ou menos, logo depois do
# turno do Fernando (ou no fim de qualquer turno, se ele estiver caído).
func _fim_da_missao() -> void:
	Missao1.reiniciar()
	for m in ["cripta_trecho2", "cripta_trecho3", "cripta_trecho4", "dama_surgiu"]:
		Missao1.marcar(m)
	var room = await _abrir("cripta")
	var dama: Combatant = null
	for e in room.enemies:
		if e.name == "Dama de Sangue":
			dama = e
	_check(dama != null and not room.dados.get("fim", {}).is_empty(), "fim: a Dama está na cripta e os dados trazem o fim")
	_check(is_equal_approx(float(room.dados["fim"]["limite"]), 0.15), "fim: limite de 15% (Léo, 20/11)")
	room._start_combat()
	var acerto := {"ok": true, "hit": true, "damage": 3, "crit": false, "blocked": false}
	var fernando: Combatant = room.party[0]
	var outro: Combatant = room.party[1]
	# Acima do limite: o turno do Fernando acaba e o combate segue.
	dama.pv = int(dama.max_pv * 0.6)
	room._ao_fim_do_turno(fernando)
	_check(not room.fim_tocou and room.mode == room.Mode.COMBAT, "fim: com a Dama acima do limite a cena não toca")
	# Um golpe que a mataria a deixa por um fio.
	dama.pv = 0
	room._show_attack(room.player, dama, acerto)
	_check(dama.pv == 1, "fim: a Dama não morre antes da cena")
	# Abaixo do limite, mas o turno que acaba não é o do Fernando (de pé): espera a vez dele.
	room._ao_fim_do_turno(outro)
	_check(not room.fim_tocou, "fim: com a Dama a 15% a cena espera o turno do Fernando")
	room._ao_fim_do_turno(fernando)
	_check(room.fim_tocou and room.mode == room.Mode.CUTSCENE, "fim: depois do turno do Fernando a cutscene começa")
	_check(room.turns.state == TurnManager.State.ENDED, "fim: o combate fica congelado")
	_check(not room.can_pause(), "fim: não se pausa durante a cutscene")
	# Só toca uma vez.
	var filhos := room.get_child_count()
	room._ao_fim_do_turno(fernando)
	_check(room.get_child_count() == filhos, "fim: a cutscene não recomeça")
	# A cena acaba e o combate continua sem o Fernando (Léo: depois dele a Dama morre, a Letícia é salva...).
	var cena: CenaTentaculo = null
	for c in room.get_children():
		if c is CenaTentaculo:
			cena = c
	Engine.time_scale = 8.0  # a cena dura ~20 s de jogo
	await cena.terminou
	Engine.time_scale = 1.0
	_check(room.mode == room.Mode.COMBAT and room.turns.state == TurnManager.State.ACTIVE, "fim: depois da cena o combate volta")
	_check(fernando.name == "Fernando" and fernando.dead and not fernando.is_alive() and Missao1.tem("fernando_morreu"), "fim: o Fernando morre de vez")
	_check(room.player != fernando and room.player.is_alive(), "fim: o controle passa a alguém de pé")
	_check(room._drawn_units().has(fernando), "fim: o corpo do Fernando continua na cena")
	_check(not Missao1.tem("capitulo1_fim") and dama.is_alive(), "fim: o capítulo não acaba aqui e a Dama segue viva")


func _entrar_na_zona(room, id: String) -> void:
	for z in room.dados["zonas"]:
		if z["id"] == id:
			room.player.pos = _ponto_livre(room, room._ret(z))
			room.dentro_de[id] = false
			room._zonas()


func _pathfinder_grade() -> void:
	var p := PathfinderGrade.new()
	var paredes: Array[Rect2] = [Rect2(100, 0, 20, 180)]
	p.configurar(paredes, Vector2(300, 200))
	var rota := p.find_path(Vector2(50, 50), Vector2(200, 50), paredes, 8.0)
	_check(rota.size() > 2 and rota[0] == Vector2(50, 50) and rota[-1] == Vector2(200, 50), "grade: contorna a parede")
	for i in rota.size() - 1:
		_check(not Pathfinder.segment_crosses_rect(rota[i], rota[i + 1], paredes[0].grow(8.0)), "grade: nenhum trecho atravessa a parede")
	_check(rota.size() <= 4, "grade: a rota é esticada (sem degraus): %d pontos" % rota.size())
	var gente: Array[Rect2] = [paredes[0], Rect2(140, 0, 20, 200)]
	_check(p.find_path(Vector2(50, 50), Vector2(200, 50), gente, 8.0).is_empty(), "grade: um obstáculo móvel fecha a passagem")
	_check(p.find_path(Vector2(50, 50), Vector2(200, 50), paredes, 8.0).size() > 1, "grade: e ela volta a abrir quando ele sai")
	_check(p.find_path(Vector2(50, 50), Vector2(110, 50), paredes, 8.0).is_empty(), "grade: destino dentro da parede não tem rota")


# Ponto livre dentro da zona, o mais perto do centro (a zona pode ter um carro no meio).
func _ponto_livre(room, r: Rect2) -> Vector2:
	var best := r.get_center()
	var best_d := INF
	for i in 9:
		for j in 9:
			var p := r.position + r.size * Vector2((i + 0.5) / 9.0, (j + 0.5) / 9.0)
			if Pathfinder.is_free(p, room._obstacles(room.player), room.player.radius) and p.distance_to(r.get_center()) < best_d:
				best = p
				best_d = p.distance_to(r.get_center())
	return best


func _visivel(w, nome: String) -> bool:
	for n in w.estados.get(nome, []):
		if n.visible:
			return true
	return false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: " + msg)
