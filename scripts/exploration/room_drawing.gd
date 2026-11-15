class_name RoomDrawing
extends RefCounted
# Desenho da sala (extraído de test_room.gd): chão, paredes e coberturas por profundidade, unidades
# (folhas 2D, Nikolai/Fernando/Miguel 3D, Criatura), barras de vida, efeitos do CombatFx, prévia de
# movimento e de tiro, pop-ups, tinta da SAN, registro do combate, medidor F3 e HUD.
# Tudo é desenhado na sala (`room.draw_*`) durante o _draw dela; os pontos de override seguem na sala.

var room: TestRoom  # a sala de teste (test_room.gd) ou uma área derivada (parque, local3d)


func _init(owner_room: TestRoom) -> void:
	room = owner_room


static var _soft_shadow: Texture2D  # sombra suave, criada uma vez (_soft_shadow_texture)


# Cone de visão da vigilância (modelo A, Léo 15/11): leque vermelho no chão com o alcance da arma e um olho
# sobre a cabeça de quem vigia. Some quando o tiro dispara ou no próximo turno de quem vigia.
func _draw_overwatch() -> void:
	if room.mode != TestRoom.Mode.COMBAT:
		return
	for u in room.party:
		if not u.overwatch or not u.is_alive():
			continue
		var reach: float = float(u.weapon["max_range"]) + u.radius
		var half := deg_to_rad(room.cfg.value("overwatch_half_angle_deg"))
		var rim := PackedVector2Array()
		rim.append(room._iso(u.pos))
		for i in 25:
			rim.append(room._iso(u.pos + u.overwatch_dir.rotated(lerpf(-half, half, i / 24.0)) * reach))
		var blood := PlaceholderArt.color("sangue_claro")
		room.draw_colored_polygon(rim, Color(blood, 0.13))
		var edge := rim.duplicate()
		edge.append(rim[0])
		room.draw_polyline(edge, Color(blood, 0.55), 1.0)
		var eye := room._iso(u.pos) + Vector2(0, -CharacterSheet.HEIGHT - 16)
		ItemIcons.draw_rows(room, Rect2(eye - Vector2(8, 8), Vector2(16, 16)), ItemIcons.PIXEL_ROWS["vigilancia"], true)


func _draw() -> void:
	var _draw_t0 := Time.get_ticks_usec()
	var font := ThemeDB.fallback_font
	_draw_floor()
	if room.mode == TestRoom.Mode.EXPLORATION:
		for e in room.enemies:
			if e.is_alive() and room._visible(e.pos):
				_draw_range(e.pos, room.rules.perception_range(e, room.player), Color(PlaceholderArt.color("sangue_claro"), 0.35))
	_draw_overwatch()
	# Peças ordenadas por profundidade: quanto maior x + y, mais perto da câmera.
	var items: Array = []
	for w in room.walls:
		var front: bool = w.end.y >= TestRoom.ROOM_SIZE.y or w.end.x >= TestRoom.ROOM_SIZE.x
		for piece in _pieces(w):
			if room._visible(piece.get_center()):
				items.append({"key": piece.get_center().x + piece.get_center().y, "block": piece, "color": TestRoom.WALL_COLOR, "height": TestRoom.FRONT_WALL_HEIGHT if front else TestRoom.WALL_HEIGHT})
	if not room.door_open:
		items.append({"key": room.door.get_center().x + room.door.get_center().y + 0.5, "block": room.door, "color": TestRoom.DOOR_COLOR, "height": TestRoom.WALL_HEIGHT})
	for c: Cover in room.covers:
		if not room._visible(c.rect.get_center()):
			continue
		if c.is_destroyed():
			_draw_outline(c.rect, PlaceholderArt.color("chao_claro"))
			continue
		items.append({"key": c.rect.get_center().x + c.rect.get_center().y, "block": c.rect, "color": TestRoom.COVER_COLORS[c.kind], "height": TestRoom.COVER_HEIGHTS[c.kind], "cover": c})
	for u in room._drawn_units():
		if room._visible(u.pos):
			items.append({"key": u.pos.x + u.pos.y, "unit": u})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.key < b.key)
	for it in items:
		if it.has("unit"):
			room._draw_unit(it.unit)
			continue
		_draw_box(it.block, it.color, it.height)
		if it.has("cover"):
			var c: Cover = it.cover
			var label := "P" if c.kind == "partial" else "C"
			room.draw_string(font, room._iso(c.rect.get_center()) + Vector2(-4, -it.height - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	if room.mode == TestRoom.Mode.COMBAT:
		_draw_preview(font)
	_draw_fx()
	_draw_san_tint()
	var tr_view := room.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, room.get_viewport_rect().size)
	room.draw_rect(tr_view, Color(0.95, 0.5, 0.18, 0.04))  # luz quente leve das 17h na sala de teste
	room._draw_hud(font)
	for p in room.popups:
		_draw_popup(font, p)
	room._draw_usec = Time.get_ticks_usec() - _draw_t0


# 1.0 com a SAN cheia, 0.0 na ruptura (só para quem tem SAN).
func _san_ratio() -> float:
	if room.player == null or room.player.max_san <= 0:
		return 1.0
	return clampf(float(room.player.san) / float(room.player.max_san), 0.0, 1.0)


# P4 (modelo B, Léo 02/11/2026): quanto menos SAN, mais a cor some (cinza por cima do mundo, antes do
# HUD) e, na ruptura, a tela pulsa devagar em escuro. Só aviso visual: a regra da ruptura é outra tarefa.
func _draw_san_tint() -> void:
	var ratio := _san_ratio()
	if ratio >= 1.0:
		return
	var inv := room.get_canvas_transform().affine_inverse()
	var screen := Rect2(inv * Vector2.ZERO, inv.basis_xform(room.get_viewport_rect().size))
	room.draw_rect(screen, Color(0.42, 0.42, 0.42, (1.0 - ratio) * 0.5))
	if room.player.san <= 0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		room.draw_rect(screen, Color(0, 0, 0, 0.12 + 0.18 * pulse))


# P3 (modelo A): até 4 linhas no canto inferior esquerdo, esmaecendo com o tempo.
func _draw_combat_log(font: Font) -> void:
	if room.mode != TestRoom.Mode.COMBAT or room.combat_log.is_empty():
		return
	var to_world := room._hud_to_world()
	var top := 540.0 - 14.0 - 15.0 * TestRoom.LOG_MAX
	room.draw_rect(Rect2(to_world * Vector2(8, top - 6), Vector2(250, 15.0 * TestRoom.LOG_MAX + 10)), Color(0.04, 0.03, 0.02, 0.5))
	for i in room.combat_log.size():
		var l: Dictionary = room.combat_log[i]
		var a := clampf(l.time / 2.0, 0.0, 1.0)
		room.draw_string(font, to_world * Vector2(14, top + 12 + 15.0 * (TestRoom.LOG_MAX - room.combat_log.size() + i)), l.text, HORIZONTAL_ALIGNMENT_LEFT, 236, 11, Color(0.95, 0.9, 0.82, a))


# P11: medidor F3 (só teste): quadros por segundo, rotas calculadas e tempo do desenho.
func _update_perf(delta: float) -> void:
	if not room.perf_on:
		return
	room._perf_time += delta
	if room._perf_time >= 1.0:
		var usec := room.pathfinder.usec_total - room._perf_path_usec
		var calls := room.pathfinder.calls_total - room._perf_path_calls
		room._perf_path_usec = room.pathfinder.usec_total
		room._perf_path_calls = room.pathfinder.calls_total
		room.perf_text = "%d FPS · rotas %d (%.1f ms) · desenho %.1f ms" % [Engine.get_frames_per_second(), calls, usec / 1000.0, room._draw_usec / 1000.0]
		room._perf_time = 0.0
	room.queue_redraw()


func _draw_perf(font: Font) -> void:
	if not room.perf_on:
		return
	var at := room._hud_to_world() * Vector2(500, 14)
	room.draw_rect(Rect2(at + Vector2(-4, -11), Vector2(330, 16)), Color(0, 0, 0, 0.6))
	room.draw_string(font, at, room.perf_text if room.perf_text != "" else "medindo…", HORIZONTAL_ALIGNMENT_LEFT, 322, 11, Color(0.6, 1.0, 0.6))


# Pop-ups só com o número, na máquina de escrever (Léo, 13/11: "essa é a fonte que usaremos para a maioria das coisas
# in game"): levemente tortos, contorno escuro fino, sem placa nem etiqueta; o crítico é maior, dourado e torto para o outro lado.
func _draw_popup(_font: Font, p: Dictionary) -> void:
	var style: Dictionary = TestRoom.POPUP_STYLES.get(p.kind, TestRoom.POPUP_STYLES.info)
	var age: float = 1.0 - p.time / TestRoom.POPUP_SECONDS
	var alpha: float = clampf(p.time / TestRoom.POPUP_SECONDS * 2.5, 0.0, 1.0)
	var size: int = style.size
	if p.kind == "crit" and age < 0.15:
		size = int(size * (1.5 - age * 3.3))  # o crítico cresce e assenta no primeiro instante
	var width := TestRoom.POPUP_FONT.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at: Vector2 = p.pos + Vector2(0, -28.0 * age)
	var color: Color = style.color
	room.draw_set_transform(at, -0.06 if p.kind != "crit" else 0.05, Vector2.ONE)
	room.draw_string_outline(TestRoom.POPUP_FONT, Vector2(-width * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.05, 0.03, 0.02, alpha))
	room.draw_string(TestRoom.POPUP_FONT, Vector2(-width * 0.5, 0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.lerp(Color(0.93, 0.89, 0.78), 0.45), alpha))
	room.draw_set_transform(Vector2.ZERO)


# Chão liso e cinza. A sala é dividida pela parede do meio; cada metade só aparece quando está visível
# (porta fechada esconde o outro lado) e a abertura da porta aparece com ela aberta.
func _draw_floor() -> void:
	for r in [Rect2(0, 0, 600, TestRoom.ROOM_SIZE.y), Rect2(624, 0, TestRoom.ROOM_SIZE.x - 624, TestRoom.ROOM_SIZE.y)]:
		if room._visible(r.get_center()):
			_draw_floor_rect(r)
	if room.door_open:
		_draw_floor_rect(Rect2(600, 0, 24, TestRoom.ROOM_SIZE.y))


func _draw_floor_rect(r: Rect2) -> void:
	room.draw_colored_polygon(PackedVector2Array([room._iso(r.position), room._iso(Vector2(r.end.x, r.position.y)), room._iso(r.end), room._iso(Vector2(r.position.x, r.end.y))]), TestRoom.FLOOR_COLOR)


# Divide um retângulo longo em peças de no máximo um losango, para a ordem de desenho.
func _pieces(r: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var nx := maxi(1, int(ceil(r.size.x / TestRoom.TILE_WORLD)))
	var ny := maxi(1, int(ceil(r.size.y / TestRoom.TILE_WORLD)))
	for ix in nx:
		for iy in ny:
			var step := Vector2(r.size.x / nx, r.size.y / ny)
			out.append(Rect2(r.position + Vector2(step.x * ix, step.y * iy), step))
	return out


# Caixa vista de lado: faces voltadas para a câmera (+x e +y) e o topo claro.
func _draw_box(r: Rect2, color: Color, height: float) -> void:
	var lift := Vector2(0, -height)
	var a := room._iso(r.position)  # canto de trás
	var b := room._iso(Vector2(r.end.x, r.position.y))  # canto da direita
	var c := room._iso(r.end)  # canto da frente
	var d := room._iso(Vector2(r.position.x, r.end.y))  # canto da esquerda
	room.draw_colored_polygon(PackedVector2Array([d, c, c + lift, d + lift]), color.darkened(0.12))  # face +y
	room.draw_colored_polygon(PackedVector2Array([c, b, b + lift, c + lift]), color.darkened(0.3))  # face +x
	room.draw_colored_polygon(PackedVector2Array([a + lift, b + lift, c + lift, d + lift]), color.lightened(0.1))


func _draw_outline(r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array([room._iso(r.position), room._iso(Vector2(r.end.x, r.position.y)), room._iso(r.end), room._iso(Vector2(r.position.x, r.end.y)), room._iso(r.position)])
	room.draw_polyline(pts, color, 1.0)


# Círculo no chão (alcance): vira uma elipse deitada na tela.
func _draw_range(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 97:
		pts.append(room._iso(center + Vector2.from_angle(TAU * i / 96.0) * radius))
	room.draw_polyline(pts, color, 1.0)


# Textura radial com queda suave (centro cheio, borda transparente), criada uma vez.
static func _soft_shadow_texture() -> Texture2D:
	if _soft_shadow == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := (n - 1) * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x - c, y - c).length() / c
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 - smoothstep(0.0, 1.0, d)))
		_soft_shadow = ImageTexture.create_from_image(img)
	return _soft_shadow


func _draw_cast_shadow(at: Vector2, _height: float, radius: float) -> void:
	var r := radius * TestRoom.SHADOW_SCALE
	var center := at + TestRoom.SHADOW_OFFSET * radius * 0.8
	room.draw_texture_rect(_soft_shadow_texture(), Rect2(center - Vector2(r, r * 0.5), Vector2(r * 2.0, r)), false, TestRoom.SHADOW_COLOR)


# Figura provisória (corpo, cabeça e nome), como a do Caio e da Letícia no parque.
func _draw_member_placeholder(u: Combatant, at: Vector2) -> void:
	var color: Color = TestRoom.MEMBER_COLORS.get(room.looks.get(u, 0), Color("#6a6a6a"))
	room.draw_rect(Rect2(at + Vector2(-11, -66), Vector2(22, 60)), color)
	room.draw_rect(Rect2(at + Vector2(-8, -86), Vector2(16, 18)), Color("#d6b292"))
	if room.turns:
		return  # em combate o nome já aparece sobre a barra de vida
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	room.draw_string_outline(font, at + Vector2(-width * 0.5, -94), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.05, 0.03, 0.02))
	room.draw_string(font, at + Vector2(-width * 0.5, -94), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.93, 0.89, 0.8))


func _draw_unit(u: Combatant) -> void:
	var at := room._iso(u.pos)
	at += room.fx.offset_of(u)  # arremessado pelo tiro ou desviando dele
	room._draw_cast_shadow(at, CharacterSheet.HEIGHT, 26.0)
	if room.turns and u == room.turns.current:
		room.draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		room.draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, PlaceholderArt.color("destaque"), 2.0)
		room.draw_set_transform(Vector2.ZERO)
	var walking: bool = u == room.moving_unit or not room.follow_paths.get(u, PackedVector2Array()).is_empty()
	if not walking:
		room.walk_dist.erase(u)  # a próxima caminhada recomeça no primeiro quadro
	var walk_n := int(room.walk_dist.get(u, 0.0) / TestRoom.WALK_FRAME_PIXELS)
	var i := room.enemies.find(u)
	if i < 0:
		if room.use_3d and _sheet3d(u) != null:  # Nikolai e Fernando: mesmas animações
			var sheet := _sheet3d(u)
			var anim := "walk" if walking else "idle"
			if u.crouched:  # agachado (tecla C): parado ou andando agachado
				anim = "crouch_walk" if walking else "crouch_idle"
			if room.anim3d_pick >= 0:
				anim = AnimSheet.NAMES[room.anim3d_pick]
			var count := sheet.frame_count(anim)
			var f := int(Time.get_ticks_msec() / 1000.0 * AnimSheet.FPS[anim]) % count
			if walking and room.anim3d_pick < 0:
				f = int(room.walk_dist.get(u, 0.0) / (TestRoom.NIKOLAI_WALK_CYCLE_PIXELS / count)) % count  # passo por distância
			var pose := _nikolai_pose(u) if room.anim3d_pick < 0 else []
			if not pose.is_empty():
				anim = pose[0]
				f = pose[1]
			sheet.draw(room, at, anim, f, room.facing8.get(u, CharacterSheet.Dir.SE))
		elif room.use_3d:
			_draw_member_placeholder(u, at)  # Miguel: figura provisória até a arte 3D existir
		else:
			var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
			var n := walk_n % frames.size() if walking else room.idle_frame
			room.agent_sheets[room.looks.get(u, 0)].draw(room, at, frames[n], room.facing8.get(u, CharacterSheet.Dir.SE))
		if not u.is_alive() and not u.dead:
			room.draw_string(ThemeDB.fallback_font, at + Vector2(-22, -CharacterSheet.HEIGHT - 14), "CAÍDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.4, 0.4))
	else:
		var variant := room._enemy_variant(i)
		if variant == TestRoom.CREATURE_VARIANT:
			room._draw_creature(u, at, walking, room.walk_dist.get(u, 0.0))
		elif room.enemy_sheets.has(variant):
			var frames: Array = CharacterSheet.WALK_FRAMES if walking else CharacterSheet.IDLE_FRAMES
			var n := walk_n % frames.size() if walking else room.idle_frame
			room.enemy_sheets[variant].draw(room, at, frames[n], room.facing8.get(u, CharacterSheet.Dir.SW))
		else:
			var frame := 1 + walk_n % 2 if walking else 0
			var tex := PlaceholderArt.character_texture(variant, room.facing.get(u, PlaceholderArt.Dir.SOUTH), frame)
			var size := Vector2(PlaceholderArt.FRAME_SIZE * TestRoom.PLACEHOLDER_SCALE)
			room.draw_texture_rect(tex, Rect2((at - PlaceholderArt.PIVOT * TestRoom.PLACEHOLDER_SCALE).round(), size), false)
	var flash := room.fx.white_alpha(u)
	if flash > 0.0 and not room._flash_in_3d(u):  # alvo pisca branco (até a arte entregar os quadros de dano)
		room.draw_set_transform(at + Vector2(0, -CharacterSheet.HEIGHT * 0.5), 0.0, Vector2(0.55, 1.0))
		room.draw_circle(Vector2.ZERO, CharacterSheet.HEIGHT * 0.42, Color(1, 1, 1, 0.75 * flash))
		room.draw_set_transform(Vector2.ZERO)
	if room.mode != TestRoom.Mode.EXPLORATION:
		room._draw_health_bar(u, at)


# Folha 3D do personagem (Nikolai ou Fernando); null para quem ainda não tem arte 3D.
func _sheet3d(u: Combatant) -> AnimSheet:
	if room.enemies.has(u):
		return null
	match room.looks.get(u, 0):
		1:
			return room.nikolai3d
		0:
			return room.fernando3d
		2:
			return room.miguel3d if room._modelos_3d() and Agente3D.tem_modelo("miguel3d") else null
	return null


# Pose de combate do Nikolai 3D: [animação, quadro] ou [] quando vale parado/andando.
# Morte (fica no último quadro até reanimar), levantar, dano e a mira do ataque (durante a mira do CombatFx).
func _nikolai_pose(u: Combatant) -> Array:
	var sheet := _sheet3d(u)
	var now := Time.get_ticks_msec()
	if not u.is_alive() and not room.fx.hold_pv.has(u):  # o tombo espera o impacto do tiro
		if room.nikolai_clock.get(u, {}).get("anim", "") != "death":
			room.nikolai_clock[u] = {"anim": "death", "start": now}
		var n := sheet.frame_count("death")
		return ["death", mini(int((now - room.nikolai_clock[u]["start"]) / 1000.0 * AnimSheet.FPS["death"]), n - 1)]
	if room.nikolai_clock.has(u):
		var c: Dictionary = room.nikolai_clock[u]
		if c["anim"] == "death":
			room.nikolai_clock[u] = {"anim": "getup", "start": now}  # reanimado: levanta
			c = room.nikolai_clock[u]
		var anim: String = c["anim"]
		var f := int((now - c["start"]) / 1000.0 * AnimSheet.FPS[anim])
		if f < sheet.frame_count(anim):
			return [anim, f]
		room.nikolai_clock.erase(u)
	for job in room.fx.jobs:
		if job["attacker"] == u and TestRoom.ATTACK_ANIM.has(str(u.weapon["id"])):
			var attack: String = TestRoom.ATTACK_ANIM[str(u.weapon["id"])]
			var n := sheet.frame_count(attack)
			return [attack, mini(int(CombatFx.aim_progress(job) * n), n - 1)]
	return []


func _has_creatures() -> bool:
	return not room.enemies.is_empty() and room._enemy_variant(0) == TestRoom.CREATURE_VARIANT


# Escolhe a animação da Criatura de Sangue: morte, ataque (durante a mira), transição ao entrar em
# combate, andar ou parada.
func _draw_creature(u: Combatant, at: Vector2, walking: bool, dist: float) -> void:
	var now := Time.get_ticks_msec()
	var dir: CharacterSheet.Dir = room.facing8.get(u, CharacterSheet.Dir.SW)
	var anim := "idle"
	var f := 0
	if not u.is_alive():
		if not room.creature_clock.has(u):
			room.creature_clock[u] = now
		anim = "death"
		f = mini(int((now - room.creature_clock[u]) / 1000.0 * CreatureSheet.FPS["death"]), room.creature.frame_count("death") - 1)
	else:
		room.creature_clock.erase(u)
		var attacking := false
		for job in room.fx.jobs:
			if job["attacker"] == u:
				anim = "attack"
				var n := room.creature.frame_count("attack")
				f = mini(int(CombatFx.aim_progress(job) * n), n - 1)
				attacking = true
				break
		if not attacking:
			var since := (now - room.combat_started_ms) / 1000.0
			if room.mode == TestRoom.Mode.COMBAT and since < TestRoom.TRANSITION_SECONDS:
				anim = "transition"
				f = mini(int(since * CreatureSheet.FPS["transition"]), room.creature.frame_count("transition") - 1)
			elif walking:
				anim = "walk"
				f = int(dist / (TestRoom.CREATURE_WALK_CYCLE_PIXELS / room.creature.frame_count("walk"))) % room.creature.frame_count("walk")
			else:
				f = int(now / 1000.0 * CreatureSheet.FPS["idle"]) % room.creature.frame_count("idle")
	room.creature.draw(room, at, anim, f, dir)


# Barra de vida com nome (modelo B): desce no impacto e deixa um rastro claro por 0,6 s.
func _draw_health_bar(u: Combatant, at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var bar := Rect2(at + Vector2(-26, -CharacterSheet.HEIGHT - 8), Vector2(52, 6))
	if _under_hud_panel(bar.get_center()):  # o nome e a barra não aparecem através do vidro fosco do HUD
		return
	var shown := float(room.fx.displayed_pv(u)) / maxf(u.max_pv, 1)
	room.draw_string_outline(font, bar.position + Vector2(0, -3), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0.05, 0.03, 0.02))
	room.draw_string(font, bar.position + Vector2(0, -3), u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.93, 0.89, 0.8))
	room.draw_rect(bar.grow(1.0), Color(0.05, 0.03, 0.02))
	room.draw_rect(bar, Color(0.2, 0.2, 0.2))
	if room.fx.trail.has(u):
		var t: Dictionary = room.fx.trail[u]
		var from := clampf(float(t["from"]) / maxf(u.max_pv, 1), 0.0, 1.0)
		room.draw_rect(Rect2(bar.position, Vector2(bar.size.x * from, bar.size.y)), Color(1, 1, 1, 0.85 * clampf(t["time"] / CombatFx.TRAIL_SECONDS, 0.0, 1.0)))
	var color := Color(0.3, 0.85, 0.35) if u.side == Combatant.Side.PLAYER else Color(0.85, 0.28, 0.25)
	room.draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown, bar.size.y)), color)


# Vivos mais os abatidos que o tiro ainda está encenando.
func _drawn_units() -> Array[Combatant]:
	var out := room._living_units()
	for u in room.fx.dying():
		out.append(u)
	return out


# Mira, clarão, partículas e flash vermelho do modelo B, por cima da cena e por baixo do HUD.
func _draw_fx() -> void:
	# Sem linha durante a animação do ataque (Léo, 13/11): a única linha é a da prévia, ao apontar/clicar no alvo.
	for m in room.fx.muzzles:  # clarão de 2 quadros
		var big: bool = m["time"] > CombatFx.MUZZLE_SECONDS * 0.5
		var r := 9.0 if big else 5.0
		room.draw_circle(m["pos"], r, Color(1.0, 0.85, 0.45, 0.95))
		room.draw_circle(m["pos"], r * 0.5, Color(1, 1, 0.9))
	for pt in room.fx.particles:
		var k: float = clampf(pt["life"] / pt["max"], 0.0, 1.0)
		match pt["kind"]:
			"smoke":
				room.draw_circle(pt["pos"], pt["size"] * (1.6 - k), Color(0.75, 0.75, 0.75, 0.35 * k))
			"casing":
				room.draw_rect(Rect2(pt["pos"], Vector2(3, 2)), Color(0.9, 0.7, 0.25, k))
			_:
				room.draw_circle(pt["pos"], pt["size"], Color(0.7, 0.05, 0.05, k))
	if room.fx.flash_red > 0.0:  # flash vermelho de 0,22 s na tela
		var view := room.get_canvas_transform().affine_inverse() * Rect2(Vector2.ZERO, room.get_viewport_rect().size)
		room.draw_rect(view, Color(0.8, 0.05, 0.05, 0.28 * room.fx.flash_strength * room.fx.flash_red / CombatFx.FLASH_RED_SECONDS))


func _preview_route(mouse: Vector2) -> PackedVector2Array:
	var key := "%s|%s|%s" % [room.player.pos, mouse.round(), room._living_units().map(func(u: Combatant) -> Vector2: return u.pos)]
	if key != room._route_key:
		room._route_key = key
		room._route_cache = room.pathfinder.find_path(room.player.pos, mouse, room._obstacles(room.player), room.player.radius)
	return room._route_cache


# Prévia sob o cursor no turno do agente: chance de acerto no inimigo ou custo do movimento.
func _draw_preview(font: Font) -> void:
	if not room._player_ready() or room._mouse_on_hud(room.get_viewport().get_mouse_position()):
		return
	var screen_mouse := room.get_global_mouse_position()
	var mouse := room._resolve_click(screen_mouse)
	var target := room._enemy_at(mouse)
	var text := ""
	if target:
		var blocker := room._attack_blocker(room.player, target)
		if blocker != "":
			text = HudText.rejection_message(blocker)
		else:
			_draw_hit_label(font, screen_mouse, target)  # P1: etiqueta de acerto, dano e cobertura
		_draw_fire_line(font, target, blocker)
	elif room._cover_at(mouse) == null:
		var route := _preview_route(mouse)
		if route.is_empty():
			text = "Inacessível"
		else:
			var cost := room.rules.move_cost(CombatRules.path_length(route), room.player.moved_px)
			var plan := room.rules.plan_move(route, room.player.pa, room.player.moved_px)
			_draw_move_path(font, route, plan["path"], int(plan["cost"]), cost > room.player.pa)
	if text != "":
		room.draw_string(font, screen_mouse + Vector2(14, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


# P1 (modelo A, Léo 02/11/2026): etiqueta junto da mira com a chance de acerto, a faixa de dano e,
# quando há, a cobertura que pesa na conta.
func _draw_hit_label(font: Font, at: Vector2, target: Combatant) -> void:
	var lines: Array[String] = ["Acerto %d%%" % roundi(room.rules.hit_chance(room.player, target, room.covers) * 100.0), "Dano %d a %d" % [int(room.player.weapon["damage_min"]), int(room.player.weapon["damage_max"])]]
	if room.rules.flanker(room.player, target) != null:
		lines.append("Flanco +%d%%" % roundi(room.cfg.value("flank_hit_bonus") * 100.0))
	var c := room.rules.cover_between(room.player.pos, target, room.covers)
	if c:
		if c.kind == "partial":
			lines.append("Cobertura −%d%%" % roundi(float(room.cfg.cover("partial")["hit_penalty"]) * 100.0))
		else:
			lines.append("Cobertura completa")
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var box := Rect2(at + Vector2(16, -24 - 15 * lines.size()), Vector2(w + 12, 8 + 15 * lines.size()))
	_draw_tag_box(box, Color(1, 1, 1, 0.22))
	for i in lines.size():
		var col := Color(0.89, 0.69, 0.3) if i == 0 else (Color(0.88, 0.55, 0.35) if i == 2 else Color(0.95, 0.9, 0.82))
		room.draw_string(font, box.position + Vector2(6, 14 + 15 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if i == 0 else 11, col)


# Etiqueta do jogo no mundo no estilo do HUD: placa escura, contorno preto e uma linha fina por dentro.
func _draw_tag_box(box: Rect2, line: Color) -> void:
	room.draw_rect(box, Color(0.04, 0.04, 0.05, 0.94))
	room.draw_rect(box.grow(1.0), Color.BLACK, false, 1.0)
	room.draw_rect(box.grow(-0.5), line, false, 0.75)


# P2 (modelo B): linha de tiro tracejada; a cobertura que pesa ganha um escudo com a penalidade e a
# parede (sem linha de visão) uma marca de bloqueio no meio da linha.
func _draw_fire_line(font: Font, target: Combatant, blocker: String) -> void:
	var from := room._iso(room.player.pos) + Vector2(0, -30)
	var to := room._iso(target.pos) + Vector2(0, -30)
	var red := Color(0.85, 0.33, 0.31, 0.9)
	room.draw_dashed_line(from, to, red, 1.5, 6.0)
	if blocker == "no_line_of_sight":
		var mid := (from + to) * 0.5
		room.draw_line(mid + Vector2(-5, -5), mid + Vector2(5, 5), red, 2.0)
		room.draw_line(mid + Vector2(-5, 5), mid + Vector2(5, -5), red, 2.0)
		return
	var c := room.rules.cover_between(room.player.pos, target, room.covers)
	if c and c.kind == "partial":
		var k := clampf(Geometry2D.get_closest_point_to_segment(room._iso(c.rect.get_center()) + Vector2(0, -30), from, to).distance_to(from) / maxf(from.distance_to(to), 1.0), 0.0, 1.0)
		var at := from.lerp(to, k)
		var label := "−%d%%" % roundi(float(room.cfg.cover("partial")["hit_penalty"]) * 100.0)
		var r := Rect2(at + Vector2(-17, -26), Vector2(34, 16))
		_draw_tag_box(r, Color(0.88, 0.55, 0.35, 0.6))
		room.draw_string(font, r.position + Vector2(3, 12), label, HORIZONTAL_ALIGNMENT_CENTER, 28, 11, Color(0.88, 0.55, 0.35))


# Caminho do movimento antes do clique (modelo C, Léo, 30/10/2026): marcas de passo em ouro até
# onde os PA chegam, o resto apagado em vermelho, e o ladrilho aceso no destino com o custo em cima.
# `route` é a rota inteira, `reach` o trecho que os PA pagam e `over` diz se o destino passa do saldo.
func _draw_move_path(font: Font, route: PackedVector2Array, reach: PackedVector2Array, cost: int, over: bool) -> void:
	var gold := Color(0.96, 0.78, 0.36)
	var dim := Color(0.8, 0.28, 0.25, 0.5)
	var total := CombatRules.path_length(route)
	var reach_len := CombatRules.path_length(reach)
	var end_room: Vector2 = reach[reach.size() - 1] if reach.size() > 0 else route[route.size() - 1]
	var d := 0.0
	var side := 1.0
	while d < total:
		var a := room._iso(_point_along(route, d))
		var b := room._iso(_point_along(route, minf(d + 4.0, total)))
		var dir := (b - a).normalized()
		var off := dir.orthogonal() * side * 3.0
		room.draw_line(a + off, a + off + dir * 4.0, Color(gold, 0.8) if d < reach_len else dim, 1.5 if d < reach_len else 1.0)
		side = -side
		d += 12.0
	_draw_floor_halo(room._iso(end_room), 13.0, gold)
	var text := "%d PA%s" % [cost, " (parcial)" if over else ""]
	var w := 36.0 if not over else 78.0
	var tag := room._iso(end_room) + Vector2(0, -20)
	_draw_tag_box(Rect2(tag - Vector2(w * 0.5, 9), Vector2(w, 16)), Color(gold, 0.55))
	room.draw_string(font, tag + Vector2(-w * 0.5 + 2, 3), text, HORIZONTAL_ALIGNMENT_CENTER, w - 4, 10, gold)


# Ponto de `route` a `dist` pixels do começo (o último, se passar do fim).
func _point_along(route: PackedVector2Array, dist: float) -> Vector2:
	var left := dist
	for i in range(1, route.size()):
		var seg := route[i - 1].distance_to(route[i])
		if left <= seg and seg > 0.0:
			return route[i - 1].lerp(route[i], left / seg)
		left -= seg
	return route[route.size() - 1]


# Halo pequeno no chão (destino do movimento): anéis de luz achatados na proporção do chão
# isométrico (2:1), mais fortes no centro, com um aro fino de ouro.
func _draw_floor_halo(c: Vector2, radius: float, color: Color) -> void:
	for i in 5:
		var t := 1.0 - i / 5.0
		_draw_ellipse(c, radius * (0.45 + 0.55 * t), Color(color, 0.07 + 0.05 * (1.0 - t)), true)
	_draw_ellipse(c, radius * 0.9, Color(color, 0.85), false)
	room.draw_circle(c, 1.2, Color(1, 0.92, 0.7, 0.9))


func _draw_ellipse(c: Vector2, radius: float, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * radius, sin(a) * radius * 0.5))
	if filled:
		room.draw_colored_polygon(pts, color)
	else:
		room.draw_polyline(pts + PackedVector2Array([pts[0]]), color, 0.75)


# HUD da ideia A (Léo, 29/10/2026) na moldura A, bronze gótico (Léo escolheu, 30/10/2026): fichas do
# grupo à esquerda, ordem dos turnos no topo, radar à direita e, no turno do jogador, PA, ações e
# fim do turno no rodapé. Desenhado em pixels da tela (960×540).
func _draw_hud(font: Font) -> void:
	var to_world := room._hud_to_world()
	for i in room.party.size():
		room.party_hud._draw_sheet(font, room.party[i], i, to_world)
	room.party_hud._draw_links(font, to_world)
	room.minimap._draw_minimap(font, to_world)
	room.objectives_hud._draw_objectives(font, to_world, room._objectives())
	room.dicas_hud._draw_dica(font, to_world)
	if room.mode == TestRoom.Mode.COMBAT and room.turns:
		room.party_hud._draw_turn_order(font, to_world)
		if room._player_ready():
			room.action_bar._draw_actions(font, to_world)
	_draw_combat_log(font)
	_draw_perf(font)


# Ponto do mundo que cai sobre uma placa de vidro fosco do HUD (com uma folga de 10 px).
func _under_hud_panel(world: Vector2) -> bool:
	var p := room.get_canvas_transform() * world
	for r in room._hud_blur_rects():
		if r.grow(10.0).has_point(p):
			return true
	return false
