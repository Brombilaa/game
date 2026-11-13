extends "res://scripts/exploration/parque.gd"
# Os outros lugares da missão 1 (delegacia 17h e 21h, subsolo, biblioteca, Fazenda Ghular) com o cenário 3D
# exportado dos protótipos (cenario3d.gd). Herda o parque inteiro: grupo, pistas, combate, câmera, cartões 3D.
# O que muda vem dos dados (data/cenarios/<id>.json, gerados por tools/cenarios3d/missao1/gerar_dados.py):
#   - cena3d: qual glb abrir, onde fica o canto da área (o plano da sala começa em 0) e o estado inicial;
#   - zonas: áreas no chão que levam a outro lugar ao entrar (com "requer", só depois de uma marca);
#   - gatilhos do tipo "estado": depois de uma pista, liga e desliga partes do cenário (tapete -> alçapão);
#   - inimigos: já no lugar ao chegar (celeiro); invasao: entram ao chegar por um lado (saída do subsolo).
# O lugar aberto vem de Missao1.local (ou de `local_id`, para abrir a cena direto no editor).

const CENARIO3D := preload("res://scripts/exploration/cenario3d.gd")

@export var local_id := "delegacia_17h"

var dados := {}  # o JSON do cenário inteiro (zonas, cena3d, invasão...), além do que o Scenario lê
var dentro_de := {}  # id da zona -> o líder já estava dentro dela (só dispara ao entrar)
var invadindo := false  # a invasão (flashbang + inimigos) já começou
const FLASH_SOBE := 0.06  # flashbang: segundos até a tela ficar branca (provisório)
const FLASH_SEGURA := 0.45  # segundos de tela branca (provisório)
const FLASH_DESCE := 1.8  # segundos até a vista voltar (provisório)


func _scenario_id() -> String:
	if Missao1.local != "":
		local_id = Missao1.local
	dados = JSON.parse_string(FileAccess.get_file_as_string(Scenario.DIR + local_id + ".json"))
	return local_id


func _novo_pathfinder() -> Pathfinder:
	return PathfinderGrade.new()


func _area_id() -> String:
	return local_id


func _criar_mundo3d() -> Node3D:
	var c: Dictionary = dados["cena3d"]
	var w: Node3D = CENARIO3D.new()
	w.id = str(c["id"])
	w.embutido = true
	var o: Array = c["origem"]
	w.deslocamento = Vector3(-float(o[0]), 0.0, -float(o[1]))
	w.ready.connect(func() -> void:
		var estados: Dictionary = c.get("estados", {})
		for e in estados:
			w.estado(e, estados[e])
		if Missao1.tem("alcapao"):
			w.estado("tapete", false)
			w.estado("alcapao", true))
	return w


func _ready() -> void:
	super()
	if dados.has("marca_ao_chegar"):
		Missao1.marcar(str(dados["marca_ao_chegar"]))
	# Cômodo menor que a tela (subsolo): a câmera pode centralizar em vez de encostar no canto.
	var meia := get_viewport_rect().size * 0.5
	camera.limit_left -= int(meia.x)
	camera.limit_right += int(meia.x)
	camera.limit_top -= int(meia.y)
	camera.limit_bottom += int(meia.y)
	if Missao1.tem("alcapao") and not seen_clues.has("tapete") and scenario.clues.has("tapete"):
		seen_clues.append("tapete")
	for z in dados.get("zonas", []):
		dentro_de[z["id"]] = _ret(z).has_point(player.pos)
	var inv: Dictionary = dados.get("invasao", {})
	if not inv.is_empty() and str(inv.get("quando", "")) == "chegada_subsolo" and Missao1.chegada == "subsolo" and not Missao1.tem(str(inv["marca"])):
		_invasao.call_deferred(inv)


# Tudo o que o mapa de colisão marca é sólido e bloqueia a visão (paredes, móveis, moitas); não há porta.
func _load_layout() -> void:
	var size := scenario.size
	walls.clear()
	walls.append(Rect2(-BOUNDS_PAD, -BOUNDS_PAD, size.x + BOUNDS_PAD * 2.0, BOUNDS_PAD))
	walls.append(Rect2(-BOUNDS_PAD, size.y, size.x + BOUNDS_PAD * 2.0, BOUNDS_PAD))
	walls.append(Rect2(-BOUNDS_PAD, 0, BOUNDS_PAD, size.y))
	walls.append(Rect2(size.x, 0, BOUNDS_PAD, size.y))
	for cid in scenario.colliders:
		walls.append(scenario.colliders[cid])
	covers.clear()
	door = Rect2(-1000, -1000, 1, 1)
	door_open = true
	(pathfinder as PathfinderGrade).configurar(walls, size)
	enemies.clear()
	for spec in dados.get("inimigos", []):
		var p: Array = spec["pos"]
		enemies.append(cfg.make_enemy(str(spec["tipo"]), Vector2(p[0], p[1])))
	var inicio: Array = dados.get("chegadas", {}).get(Missao1.chegada, [])
	for i in party.size():
		party[i].pos = Vector2(inicio[i][0], inicio[i][1]) if i < inicio.size() else scenario.party_start[i]


func _place_label() -> String:
	return "%s · %dh" % [str(dados.get("rotulo", local_id.to_upper())), int(dados.get("hora", 0))]


# Variante pelo nome da ficha (Léo, 13/11: todos atiradores); o atirador usa a figura do cultista e o retrato próprio.
func _enemy_variant(i: int) -> String:
	return "atirador" if i < enemies.size() and enemies[i].name == "Atirador" else "cultista"


func _proximo_apos_vitoria() -> String:
	return ""


func _process(delta: float) -> void:
	super(delta)
	if mode == Mode.EXPLORATION and indo_para == "" and not dialog_layer.visible:
		_zonas()


# Zona: dispara quando o líder entra (quem nasce dentro precisa sair e voltar).
func _zonas() -> void:
	for z in dados.get("zonas", []):
		var agora := _ret(z).has_point(player.pos)
		var antes: bool = dentro_de.get(z["id"], agora)
		dentro_de[z["id"]] = agora
		if not agora or antes:
			continue
		if z.has("requer") and not Missao1.tem(str(z["requer"])):
			continue
		if str(z.get("acao", "")) == "ir":
			_ir_para(str(z["para"]), str(z.get("chegada", "")), str(z.get("texto", "")))
			return
		if str(z.get("acao", "")) == "invasao":
			var inv: Dictionary = dados.get("invasao", {})
			if not inv.is_empty() and not Missao1.tem(str(inv["marca"])):
				_invasao(inv)
				return


static func _ret(z: Dictionary) -> Rect2:
	var r: Array = z["ret"]
	return Rect2(r[0], r[1], r[2], r[3])


func _inspect(cid: String) -> void:
	var c: Dictionary = scenario.clues[cid]
	_show_dialog(c.inspecao, c.texto, cid)


func _run_trigger(trigger: Dictionary) -> void:
	if str(trigger["tipo"]) != "estado":
		super(trigger)
		return
	var estados: Dictionary = trigger.get("estados", {})
	for e in estados:
		world3d.estado(e, estados[e])
	if trigger.has("marca"):
		Missao1.marcar(str(trigger["marca"]))
	queue_redraw()


# Invasão da delegacia às 21h (Léo, 13/11): depois do subsolo, ao entrar na recepção, uma flashbang estoura pela
# porta da frente (tela branca e tremida), os atiradores entram e o combate começa quando a vista volta.
func _invasao(inv: Dictionary) -> void:
	if invadindo:
		return
	invadindo = true
	busy = true
	path = PackedVector2Array()
	moving_unit = null
	var camada := CanvasLayer.new()
	camada.layer = 80
	add_child(camada)
	var branco := ColorRect.new()
	branco.color = Color(1.0, 0.98, 0.92, 0.0)
	branco.set_anchors_preset(Control.PRESET_FULL_RECT)
	branco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(branco)
	var t := create_tween()
	t.tween_property(branco, "color:a", 1.0, FLASH_SOBE)
	await t.finished
	for spec in inv["inimigos"]:
		var p: Array = spec["pos"]
		enemies.append(cfg.make_enemy(str(spec["tipo"]), Vector2(p[0], p[1])))
	fx.shake_time = FLASH_SEGURA  # tremor da tela (o mesmo do crítico, mais longo)
	fx.shake_px = 7.0
	await get_tree().create_timer(FLASH_SEGURA).timeout
	busy = false
	_start_combat(Combatant.Side.ENEMY)  # emboscada: os inimigos agem todos primeiro
	var volta := create_tween()
	volta.tween_property(branco, "color:a", 0.0, FLASH_DESCE).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await volta.finished
	camada.queue_free()


func _on_combat_ended(result: TurnManager.Result) -> void:
	super(result)
	var inv: Dictionary = dados.get("invasao", {})
	if result == TurnManager.Result.VICTORY and not inv.is_empty():
		Missao1.marcar(str(inv["marca"]))


# Objetivos do HUD vêm dos dados: cada um feito ao ver a pista ou ao ganhar a marca; "requer" só mostra depois de outra marca.
func _objectives() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in dados.get("objetivos", []):
		if o.has("requer") and not Missao1.tem(str(o["requer"])):
			continue
		var feito: bool = (o.has("pista") and seen_clues.has(str(o["pista"]))) or (o.has("marca") and Missao1.tem(str(o["marca"])))
		out.append({"texto": str(o["texto"]), "feito": feito, "atual": false, "detalhe": ""})
	if mode == Mode.COMBAT:
		out.append({"texto": Objectives.COMBAT_TEXT, "feito": false, "atual": true, "detalhe": ""})
		return out
	for item in out:
		if not item["feito"]:
			item["atual"] = true
			break
	return out


# Minimapa: o lugar inteiro conta como visto (como no parque).
func _known_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append(Rect2(Vector2.ZERO, scenario.size))
	return out
