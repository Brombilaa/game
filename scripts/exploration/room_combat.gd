class_name RoomCombat
extends RefCounted
# Combate da sala (extraído de test_room.gd): detecção e ataque furtivo, início e fim do combate,
# turno do jogador (ataque, movimento, reanimação, recarga, troca de arma, vigilância), encenação do ataque
# e textos flutuantes. A sala guarda o estado; os pontos de override (_start_combat, _show_attack, ...)
# continuam na sala e chamam estas funções.

var room: TestRoom  # a sala de teste (test_room.gd) ou uma área derivada (parque, local3d)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


# Recarga (tecla G): fora do combate a animação trava o ataque por RELOAD_SECONDS (Léo, 13/11: "atira enquanto recarrega");
# em combate o custo é só o 1 PA e a animação não bloqueia nada.
func _reloading(u: Combatant) -> bool:
	if room.mode == TestRoom.Mode.COMBAT:  # em combate a recarga custa 1 PA e pronto: sem espera (escassez, sugestão 7)
		return false
	var c: Dictionary = room.nikolai_clock.get(u, {})
	if c.get("anim", "") != "reload":
		return false
	return (Time.get_ticks_msec() - int(c["start"])) / 1000.0 < TestRoom.RELOAD_SECONDS


# Bloqueio do ataque: a recarga em curso vem antes das regras (alcance, linha de visão).
func _attack_blocker(attacker: Combatant, target: Combatant) -> String:
	if _reloading(attacker):
		return "reloading"
	return room.rules.attack_blocker(attacker, target, room._sight_blockers(), room.covers)


# Inimigo detecta o personagem se ele estiver no alcance e com linha de visão livre
# (parede e porta fechada bloqueiam). Detecção inicia o combate imediatamente.
func _check_detection() -> void:
	for e in room.enemies:
		if not e.is_alive():
			continue
		for m in room.party:
			if not m.is_alive() or e.pos.distance_to(m.pos) > room.rules.perception_range(e, m):
				continue
			if Pathfinder.has_line_of_sight(e.pos, m.pos, room._sight_blockers()):
				room.audio.play_sfx("enemy_spotted")
				room._start_combat(Combatant.Side.ENEMY)  # quem percebe pega o grupo desprevenido
				return


# Ataque furtivo (Léo): contra inimigo sem alerta, com bônus de acerto e de dano. Se errar,
# o combate começa. Se acertar sem abater, o alvo também entra em alerta (assumido).
# Fora do alcance da arma, o personagem só anda até o alvo.
func _stealth_attack(target: Combatant) -> void:
	room.player.pa = int(room.player.weapon["pa_cost"])  # fora do combate não há PA; o custo é só formal
	if room.rules.needs_reload(room.player):  # carregador vazio: recarrega sozinho; o ataque furtivo fica para o próximo clique
		room.player.pa = 0
		_reload()
		return
	var blocker := _attack_blocker(room.player, target)
	if blocker == "out_of_range":
		room.player.pa = 0
		var stand := target.pos.move_toward(room.player.pos, room.player.radius + target.radius + 2.0 + float(room.player.weapon["max_range"]) * 0.5)
		room._order_move(stand)
		return
	if blocker != "":
		room.player.pa = 0
		_reject(blocker)
		return
	room.path = PackedVector2Array()
	room.pending_door = false
	var r := room.rules.attack(room.player, target, room._sight_blockers(), room.covers, true)
	room.player.pa = 0
	room._show_attack(room.player, target, r)
	if target.is_alive():
		room._start_combat()


# Monta os participantes (todos os inimigos vivos da sala) e ordena a iniciativa.
# surprise_side: lado que pegou o outro desprevenido e age todo na rodada 1 (-1 = ninguém).
func _start_combat(surprise_side: int = -1) -> void:
	room.mode = TestRoom.Mode.COMBAT
	room.combat_started_ms = Time.get_ticks_msec()
	room.combat_log.clear()
	room.cam_pan = Vector2.ZERO
	Engine.time_scale = 2.0 if room.options.values["fast_combat"] else 1.0  # P7: combate rápido (Opções)
	room.path = PackedVector2Array()
	room.moving_unit = null
	room.pending_door = false
	room.hud.on_combat_started()
	room.audio.on_combat_started()
	room.turns = TurnManager.new(int(room.cfg.value("pa_per_turn")))
	room.turns.turn_effects = func(u: Combatant) -> bool:
		var fx := room.rules.start_turn_effects(u)
		if fx.damage > 0:
			_popup(u.pos, "-%d" % fx.damage, "damage")
		if fx.skip and u.is_alive():
			_popup(u.pos, "Atordoado")
		return fx.skip
	room.turns.turn_started.connect(_on_turn_started)
	room.turns.turn_ended.connect(func(_u: Combatant) -> void: room.hud.on_turn_ended())
	room.turns.combat_ended.connect(room._on_combat_ended)
	room.follow_paths.clear()
	var units: Array[Combatant] = []
	for m in room.party:
		if m.is_alive():
			units.append(m)
	for e in room.enemies:
		if e.is_alive():
			units.append(e)
	room.san.start_combat(room.party, room.turns)
	room.turns.start(units, surprise_side)
	for e in room.enemies:  # o grupo vê quem entrou no combate: o primeiro de cada tipo assusta
		if e.is_alive():
			Fraquezas.ver(e.kind)  # entra na seção CRIATURAS do diário
			_san_report(room.san.enemy_seen(e, room.party), "vê %s" % e.name)
	room.queue_redraw()


func _on_turn_started(unit: Combatant) -> void:
	room.rules.units = room._living_units()  # M4: quem está em campo, para achar o flanqueador
	room.queue_redraw()
	_log("Vez de %s" % unit.name)
	if unit.side == Combatant.Side.PLAYER:
		room.player = unit
		room.hud.on_turn_started(unit.name, unit.pa, room.turns.turn_pa(room.player))
		room.audio.play_sfx("turn_start")
	else:
		room._run_enemy_turn.call_deferred(unit)


func _on_combat_ended(result: TurnManager.Result) -> void:
	Engine.time_scale = 1.0
	room.hud.on_turn_ended()
	room.audio.on_combat_ended()
	RitualRules.clear_buffs(room.party)  # Armadura de Sangue e Amaldiçoar Arma acabam com o combate
	if result == TurnManager.Result.VICTORY:
		room.mode = TestRoom.Mode.EXPLORATION
		room.hud.on_combat_ended()
		var died: Array = []
		for m in room.party:
			if not m.is_alive() and not m.dead:
				m.dead = true  # Léo: caído sem reanimação até o fim do combate morre
				_popup(m.pos, "Morreu")
				died.append(m)
		room.san.end_combat(room.party)
		for m in died:
			_san_report(room.san.ally_down(m, room.party, true), "perde %s" % m.name)
		if room.player.dead:
			for m in room.party:
				if not m.dead:
					room.player = m
					break
	else:
		room.san.end_combat(room.party)
		room.mode = TestRoom.Mode.GAME_OVER
		_game_over_fade()
	room.queue_redraw()


# Game Over (Léo): sem tela própria; a tela escurece bem devagar e o jogo volta ao último save.
func _game_over_fade() -> void:
	room.fade_layer.layer = 100
	room.fade.color = Color(0, 0, 0, 0)
	room.fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not room.fade.get_parent():
		room.fade_layer.add_child(room.fade)
		room.add_child(room.fade_layer)
	var tween := room.create_tween()
	tween.tween_property(room.fade, "color:a", 1.0, room.cfg.value("game_over_fade_seconds"))
	await tween.finished
	if room.get_tree().current_scene == room:
		room._voltar_ao_save()


func _combat_click(click: Vector2) -> void:
	if not room._player_ready():
		return
	var target := _enemy_at(click)
	if target:
		if _reloading(room.player):
			_reject("reloading")
			return
		if room.rules.needs_reload(room.player):  # carregador vazio: recarrega sozinho (Léo); fora disso só com a tecla G
			_reload()
			return
		room._show_attack(room.player, target, room.rules.attack(room.player, target, room._sight_blockers(), room.covers))
		_after_player_action()
		return
	var fallen := _fallen_at(click)
	if fallen:
		_revive(fallen)
		return
	if _cover_at(click):
		return  # coberturas não podem ser destruídas por enquanto (Léo)
	await _player_move(click)


# Kit de primeiros socorros (Léo): aliado encostado no caído, 2 PA, volta com metade do PV,
# um uso por kit.
func _revive(fallen: Combatant) -> void:
	var kit := room.cfg.game_data.get_entry("itens", "kit_primeiros_socorros")
	var cost := int(room.cfg.regra("custo_reanimar_pa", kit["custo_pa_combate"]))  # regras.json (GDD #12)
	if room.inventory.count(TestRoom.KIT_ID) <= 0:
		_reject("requirement")
		room.hud.show_notice("Sem kit de primeiros socorros")
	elif CombatRules.gap(room.player, fallen) > TestRoom.REVIVE_REACH:
		_reject("out_of_range")
		room.hud.show_notice("Chegue mais perto de %s para reanimar" % fallen.name)
	elif not room.turns.spend(room.player, cost):
		_reject("no_pa")
	else:
		room.inventory.remove(TestRoom.KIT_ID)
		fallen.pv = maxi(floori(fallen.max_pv * float(room.cfg.regra("reanimar_pv_percentual", kit["valor"]))), 1)
		room.audio.play_sfx("item_use")
		_popup(fallen.pos, "REANIMADO", "heal")
	_after_player_action()


# Ícone do kit na barra de combate: reanima o aliado caído que está encostado no controlado.
func _use_kit_button() -> void:
	if not room._player_ready():
		return
	for m in room.party:
		if m != room.player and not m.is_alive() and not m.dead and CombatRules.gap(room.player, m) <= TestRoom.REVIVE_REACH:
			_revive(m)
			return
	_reject("out_of_range")
	room.hud.show_notice("Nenhum aliado caído encostado em %s" % room.player.name)


func _fallen_at(p: Vector2) -> Combatant:
	for m in room.party:
		if not m.is_alive() and not m.dead and m.pos.distance_to(p) <= m.radius + 4.0:
			return m
	return null


func _player_move(click: Vector2) -> void:
	var full := room.pathfinder.find_path(room.player.pos, click, room._obstacles(room.player), room.player.radius)
	if full.is_empty():
		await _player_unstick(click)
		return  # destino inacessível
	var plan := room.rules.plan_move(full, room.player.pa, room.player.moved_px)
	if CombatRules.path_length(plan.path) < 1.0:
		if plan.cost == 0 and room.rules.move_cost(CombatRules.path_length(full), room.player.moved_px) > 0:
			_reject("no_pa")
		return
	if plan.cost > room.player.pa or (plan.cost > 0 and not room.turns.spend(room.player, plan.cost)):
		_reject("no_pa")
		return
	room.player.moved_px += CombatRules.path_length(plan.path)
	room.hud.on_pa_changed(room.player.pa, room.turns.turn_pa(room.player))
	room.busy = true
	room._start_move(room.player, plan.path)
	await room.move_finished
	room.busy = false
	_after_player_action()


# P9: se o controlado está preso (dentro de um obstáculo ou separado de todo o grupo) e o destino é um
# ponto livre, salta, sem gastar PA, para o ponto livre mais perto do destino com caminho até ele.
# Fora disso o clique em destino inacessível continua sendo ignorado.
func _player_unstick(click: Vector2) -> void:
	if not Pathfinder.is_free(click, room._obstacles(room.player), room.player.radius) or not _player_trapped():
		return
	var spot := room.ai.spot_toward(room.player, click, 0.0, true)
	if spot == Vector2.INF:
		return
	room.busy = true
	room._start_move(room.player, PackedVector2Array([room.player.pos, spot]))
	await room.move_finished
	room.busy = false
	room.queue_redraw()


func _player_trapped() -> bool:
	var obstacles := room._obstacles(room.player)
	if not Pathfinder.is_free(room.player.pos, obstacles, room.player.radius):
		return true
	var others := 0
	for m in room.party:
		if m != room.player and m.is_alive():
			others += 1
			if not room.pathfinder.find_path(room.player.pos, m.pos, room._obstacles(room.player), room.player.radius).is_empty():
				return false
	return others > 0


func _after_player_action() -> void:
	if room.turns.is_turn_of(room.player):
		room.hud.on_pa_changed(room.player.pa, room.turns.turn_pa(room.player))
	room.turns.action_done()
	room.queue_redraw()


func _player_pass() -> void:
	if room._player_ready():
		room.turns.pass_turn()


# Troca a arma em mãos pela reserva: 1 PA em combate (GDD #18), grátis fora dele.
func _swap_weapon() -> void:
	var id := room._reserve_id()
	if id == "" or not room.player.is_alive():
		return
	if room.mode == TestRoom.Mode.COMBAT:
		if not room._player_ready():
			return
		if not room.turns.spend(room.player, int(room.cfg.regra("custo_trocar_arma_pa", 1))):
			_reject("no_pa")
			return
	room.gear[room.player]["secundaria"] = room.gear[room.player]["principal"]
	room.gear[room.player]["principal"] = id
	room.player.weapon = room.cfg.weapon(id)
	room.hud.show_notice("Empunhou: %s" % room.cfg.game_data.get_entry("armas", id).get("nome", id))
	room.queue_redraw()


# Recarrega a arma em mãos: completa o carregador com a reserva da mochila. 1 PA em combate, grátis fora dele.
func _reload() -> void:
	if not room.player.is_alive() or _reloading(room.player):
		return
	var size := int(room.player.weapon.get("mag_size", 0))
	if size <= 0:
		return
	var wid := str(room.player.weapon["id"])
	var have := int(room.player.mag.get(wid, 0))
	var stock := room.inventory.count(room.ammo_item(wid))
	if have >= size:
		_reject("mag_full")
		return
	if stock <= 0:
		_reject("no_reserve")
		return
	if room.mode == TestRoom.Mode.COMBAT:
		if not room._player_ready():
			return
		if not room.turns.spend(room.player, int(room.cfg.regra("custo_recarga_pa", 1))):
			_reject("no_pa")
			return
	var take := mini(size - have, stock)
	room.inventory.remove(room.ammo_item(wid), take)
	room.player.mag[wid] = have + take
	if room.use_3d and room._sheet3d(room.player) != null and not room.fx.animating():
		room.nikolai_clock[room.player] = {"anim": "reload", "start": Time.get_ticks_msec()}
	room.audio.play_sfx("reload")
	_popup(room.player.pos, "Recarregou")
	room.queue_redraw()


func _player_delay() -> void:
	if not room._player_ready():
		return
	if not room.turns.delay():
		_reject("requirement")
	else:
		room.hud.show_notice("Atrasou")


# Vigilância (tecla F, Léo 15/11): paga os PA de um tiro e, no turno dos inimigos, atira no primeiro que se
# mover à vista e ao alcance. Só em combate, na vez do controlado; dura até o próximo turno dele.
func _overwatch() -> void:
	if not room._player_ready():
		return
	if _reloading(room.player):
		_reject("reloading")
		return
	var reason := room.rules.start_overwatch(room.player, _overwatch_aim())
	if reason != "":
		_reject(reason)
		return
	room.facing8[room.player] = CharacterSheet.dir_from_vector(room._iso(room.player.pos + room.player.overwatch_dir) - room._iso(room.player.pos))
	_popup(room.player.pos, "Vigilância")
	_log("%s vigia" % room.player.name)
	_after_player_action()


# Direção do cone: para o mouse, se ele está no cenário (não no rodapé); senão para o inimigo vivo mais perto.
func _overwatch_aim() -> Vector2:
	if not room._mouse_on_hud(room.get_viewport().get_mouse_position()):
		var aim := room._resolve_click(room.get_global_mouse_position()) - room.player.pos
		if aim.length() > room.player.radius * 2.0:
			return aim
	var best := Vector2.ZERO
	var best_d := INF
	for e in room.enemies:
		if e.is_alive() and e.pos.distance_to(room.player.pos) < best_d:
			best_d = e.pos.distance_to(room.player.pos)
			best = e.pos - room.player.pos
	return best


# Chamado a cada passo de um inimigo em combate: se um vigia o enxerga ao alcance, o tiro de reação sai na hora
# (e o inimigo para onde está). Retorna true quando houve tiro.
func _overwatch_fire(mover: Combatant) -> bool:
	room.rules.units = room._living_units()
	var watcher := room.rules.overwatch_watcher(mover, room._sight_blockers(), room.covers)
	if watcher == null:
		return false
	_popup(watcher.pos, "Vigilância")
	room._show_attack(watcher, mover, room.rules.overwatch_shot(watcher, mover, room._sight_blockers(), room.covers))
	return true


func _reject(reason: String) -> void:
	room.hud.on_action_rejected(reason)
	room.audio.play_sfx("action_rejected")


func _enemy_at(p: Vector2) -> Combatant:
	for e in room.enemies:
		if e.is_alive() and e.pos.distance_to(p) <= e.radius + 4.0:
			return e
	return null


func _cover_at(p: Vector2) -> Cover:
	for c: Cover in room.covers:
		if not c.is_destroyed() and c.rect.has_point(p):
			return c
	return null


# O ataque já foi resolvido pelas regras; aqui só se encena: mira de 0,6 s e, no impacto, os efeitos
# do modelo B (CombatFx) e os textos (_on_fx_impact). A barra de vida do alvo fica no valor antigo até lá.
func _show_attack(attacker: Combatant, target: Combatant, r: Dictionary) -> void:
	if not r.ok:
		_reject(r.reason)
		return
	if room.party.has(attacker):
		Dicas.marcar("atacar")
	var before := mini(target.pv + int(r.get("damage", 0)), target.max_pv) if r.get("hit", false) else target.pv
	# Quem ataca vira para o alvo (antes atirava para onde estivesse olhando: Léo, 08/11, "combate dessincronizado").
	if target.pos != attacker.pos:
		room.facing8[attacker] = CharacterSheet.dir_from_vector(room._iso(target.pos) - room._iso(attacker.pos))  # direção vista na tela
	room.audio.play_attack(attacker.weapon)
	var aim := room._attack_aim(attacker)
	room.fx.start(attacker, target, r, before, aim)
	room._attack_started(attacker, target, aim)
	room.queue_redraw()


# Duração da mira até o impacto (o golpe acerta no fim dela).
func _attack_aim(attacker: Combatant) -> float:
	if room._has_creatures() and room.enemies.has(attacker):
		return TestRoom.CREATURE_ATTACK_SECONDS
	if room.use_3d and room._sheet3d(attacker) != null:
		return TestRoom.NIKOLAI_ATTACK_SECONDS
	return CombatFx.AIM_SECONDS


# P3: registro curto do combate no canto inferior esquerdo (as últimas linhas somem sozinhas).
func _log(text: String) -> void:
	room.combat_log.append({"text": text, "time": TestRoom.LOG_SECONDS})
	while room.combat_log.size() > TestRoom.LOG_MAX:
		room.combat_log.pop_front()
	room.queue_redraw()


func _on_fx_impact(job: Dictionary) -> void:
	var target: Combatant = job["target"]
	var r: Dictionary = job["r"]
	var attacker: Combatant = job["attacker"]
	room.audio.play_impact(r, target.defense > 0.0, not target.is_alive())
	if r.get("blocked", false):
		_log("%s atira em %s: bloqueado" % [attacker.name, target.name])
	elif not r.get("hit", false):
		_log("%s erra %s" % [attacker.name, target.name])
	else:
		_log("%s acerta %s: %d%s" % [attacker.name, target.name, int(r.damage), " (crítico)" if r.get("crit", false) else ""])
	if not target.is_alive():
		_log("%s %s" % [target.name, "foi abatido" if target.side == Combatant.Side.ENEMY else "caiu"])
	if r.get("blocked", false):
		_popup(target.pos, "BLOQUEADO", "blocked")
	elif not r.get("hit", false):
		_popup(target.pos, "ERROU", "miss")
	else:
		if target.pos != attacker.pos and target.is_alive():
			room.facing8[target] = CharacterSheet.dir_from_vector(room._iso(attacker.pos) - room._iso(target.pos))  # o atingido vira para quem bateu
		_popup(target.pos, "-%d" % r.damage, "crit" if r.crit else "damage")
		_afinidade(target, r)
		room.hit_shake[target] = TestRoom.CRIT_SHAKE_SECONDS if r.crit else TestRoom.HIT_SHAKE_SECONDS
		if target.is_alive() and room._sheet3d(target) != null and not room.enemies.has(target):
			room.nikolai_clock[target] = {"anim": "hit", "start": Time.get_ticks_msec()}  # reação ao golpe (Nikolai 3D)
	if not target.is_alive() and not target.insane:
		_popup(target.pos, "ABATIDO" if target.side == Combatant.Side.ENEMY else "CAIU", "down")
		if target.side == Combatant.Side.ENEMY and not target.looted:
			target.looted = true
			room._loot_enemy(target)
	if room.party.has(target) and r.get("hit", false):
		if r.get("crit", false) and target.is_alive():
			_san_report({target: room.san.crit_taken(target)}, "leva o golpe")
		if not target.is_alive() and not target.insane:
			_san_report(room.san.ally_down(target, room.party), "vê %s cair" % target.name)
	room.queue_redraw()


# Mostra o que a SAN fez (resultado de SanRules por personagem): "-N SAN", ruptura, loucura, e a causa no registro.
# Visual provisório (texto); o aviso escolhido pelo Léo entre os 3 modelos entra por cima disto.
func _san_report(results: Dictionary, cause: String) -> void:
	for m: Combatant in results:
		var r: Dictionary = results[m]
		if r.resisted:
			_popup(m.pos, "Resistiu", "info")
			continue
		if r.lost > 0:
			room.san_fx.scare(r.rupture)
			_popup(m.pos, "-%d SAN" % r.lost, "san")
			_log("%s %s: -%d SAN" % [m.name, cause, r.lost])
		if r.rupture:
			_popup(m.pos, "RUPTURA", "san")
			_log("%s entra em RUPTURA" % m.name)
		if r.insane:
			room.san_fx.madness()
			_popup(m.pos, "ENLOUQUECEU", "down")
			_log("%s enlouqueceu" % m.name)
			_san_report(room.san.ally_down(m, room.party, true), "perde %s" % m.name)
			if room.turns and room.turns.current == m:
				room.turns.end_turn.call_deferred()


# `at` é um ponto da sala; o texto nasce na altura da cabeça e sobe enquanto some.
# kind: damage, crit, miss, blocked, down, heal ou info (estilos em POPUP_STYLES).
# Golpe que pegou fraqueza ou resistência do inimigo: mostra FRAQUEZA/RESISTE e, na primeira vez, anota no diário.
func _afinidade(target: Combatant, r: Dictionary) -> void:
	var f := Fraquezas.ao_acertar(room.rules.cfg.game_data, target, r)
	if f["popup"] == "":
		return
	_popup(target.pos, f["popup"], "crit" if f["popup"] == "FRAQUEZA" else "blocked")
	if f["nova"]:
		_log("Diário: %s" % Fraquezas.titulo(room.rules.cfg.game_data, target.kind, str(r["tipo_dano"])))


func _popup(at: Vector2, text: String, kind := "info") -> void:
	var stacked := room.popups.filter(func(p: Dictionary) -> bool: return p.anchor.distance_to(at) < 1.0).size()
	room.popups.append({"anchor": at, "pos": room._iso(at) + Vector2(0, -CharacterSheet.HEIGHT - 14 - 18 * stacked), "text": text, "kind": kind, "time": TestRoom.POPUP_SECONDS})
