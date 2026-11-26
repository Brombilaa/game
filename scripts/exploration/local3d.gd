extends "res://scripts/exploration/parque.gd"
# Os outros lugares da missão 1 (delegacia 17h e 21h, subsolo, biblioteca, Fazenda Ghular) com o cenário 3D
# exportado dos protótipos (cenario3d.gd). Herda o parque inteiro: grupo, pistas, combate, câmera, cartões 3D.
# O que muda vem dos dados (data/cenarios/<id>.json, gerados por tools/cenarios3d/missao1/gerar_dados.py):
#   - cena3d: qual glb abrir, onde fica o canto da área (o plano da sala começa em 0) e o estado inicial;
#   - zonas: áreas no chão que levam a outro lugar ao entrar (com "requer", só depois de uma marca);
#   - gatilhos do tipo "estado": depois de uma pista, liga e desliga partes do cenário (tapete -> alçapão);
#   - inimigos: já no lugar ao chegar (celeiro); invasao: entram ao chegar por um lado (saída do subsolo).
# Cripta (Léo, 14/11), tudo vindo dos dados:
#   - zonas com acao "estado": revelam um trecho do cenário (glb à parte) e acordam os inimigos dele;
#   - visao: o que barra a visão quando é menos do que o que barra o passo (parapeito, fosso, altar);
#   - niveis: áreas elevadas; só mudam a altura em que cada um é desenhado (e o clique acha o piso certo);
#   - chefe: Roberto Ghular se mata com pouca vida e a Dama de Sangue surge dele, no mesmo combate;
#   - a luta da Dama (7 flores, pendurados, fases) é do ChefeDama (scripts/combat/chefe_dama.gd);
#   - fim: com a Dama em 15% de vida ou menos (limite em cripta.json), logo depois do turno do Fernando, toca a cutscene
#     da morte dele pelo tentáculo (cena_tentaculo.gd);
#   - grupos: marca gravada quando todos os inimigos de um grupo caem (não voltam ao carregar o save).
# O lugar aberto vem de Missao1.local (ou de `local_id`, para abrir a cena direto no editor).

const CENARIO3D := preload("res://scripts/exploration/cenario3d.gd")

@export var local_id := "delegacia_17h"

var dados := {}  # o JSON do cenário inteiro (zonas, cena3d, invasão...), além do que o Scenario lê
var dentro_de := {}  # id da zona -> o líder já estava dentro dela (só dispara ao entrar)
var invadindo := false  # a invasão (flashbang + inimigos) já começou
var visao: Array[Rect2] = []  # o que barra a visão, quando os dados trazem (vazio = as paredes)
var niveis: Array = []  # áreas elevadas: {"h", "rampa", "ret": Rect2 + "dir"} ou {"arco": [...], "de", "ate"}
var adormecidos := {}  # trecho -> fichas dos inimigos que esperam o trecho ser revelado
var ficha_de := {}  # inimigo -> a ficha dele nos dados (grupo, trecho)
var chefe_virou := false  # a Dama de Sangue já surgiu
var chefe_dama: ChefeDama  # a luta da Dama (flores, pendurados, fases); nulo até ela surgir
var portas := {}  # id -> {"rect": Rect2, "chave": item, "no": MeshInstance3D}: portas trancadas que ainda não abriram
var porta_avisada := ""  # a porta cujo aviso "Trancada" já apareceu nesta aproximação
signal teste_escolhido(escolha: Dictionary)
var menu_teste: CanvasLayer  # a escolha de quem rola o teste de perícia (nulo = fechada)
var menu_destinos: CanvasLayer  # a escolha entre os três lugares livres (nulo = fechada)
var fim_tocou := false  # a cutscene do tentáculo (fim da missão 1) já começou
var fim_capitulo: FimCapitulo  # cutscene externa e cartão AURORA, no fim do celeiro
const CENA_MENU := "res://scenes/menu/main_menu.tscn"
const PX_ALTURA := 62.855  # px do desenho por unidade de altura (PX_UNIT * cos(elevação da câmera))
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
		_portas_visual(w)
		if Missao1.tem("alcapao"):
			w.estado("tapete", false)
			w.estado("alcapao", true)
		for z in dados.get("zonas", []):  # trechos já revelados antes de salvar
			if str(z.get("acao", "")) == "estado" and z.has("marca") and Missao1.tem(str(z["marca"])):
				for e in z["estados"]:
					w.estado(e, z["estados"][e]))
	return w


# Porta trancada: uma folha de madeira simples no vão (provisório, até o Léo escolher o modelo).
func _portas_visual(w: Node3D) -> void:
	for id in portas:
		var r: Rect2 = portas[id]["rect"]
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(r.size.x / 64.0, 2.1, r.size.y / 64.0)
		m.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.2, 0.11)
		m.material_override = mat
		var c := r.get_center()
		m.position = Vector3(c.x / 64.0, 1.05, c.y / 64.0)
		w.mundo.add_child(m)
		portas[id]["no"] = m


# Com a chave na mochila e alguém perto, a porta abre sozinha; sem a chave, aparece "Trancada" uma vez por aproximação.
func _portas() -> void:
	var perto_de := ""
	for id in portas.keys():
		var pt: Dictionary = portas[id]
		var r: Rect2 = pt["rect"]
		var alcance := r.grow(48.0)
		var alguem := false
		for m in party:
			if alcance.has_point(m.pos):
				alguem = true
		if not alguem:
			continue
		perto_de = id
		if inventory.count(str(pt["chave"])) > 0:
			walls.erase(r)
			(pathfinder as PathfinderGrade).configurar(walls, scenario.size)
			if pt["no"] != null and is_instance_valid(pt["no"]):
				pt["no"].queue_free()
			Missao1.marcar("porta_" + id)
			portas.erase(id)
			_show_dialog("", "A chave serve. A porta se abre.", "")
			return
		if porta_avisada != id:
			porta_avisada = id
			_show_dialog("", str(pt["texto"]), "")
			return
	if perto_de == "":
		porta_avisada = ""


func _ready() -> void:
	super()
	DiarioMiguel.esteve(local_id)  # a página deste lugar aparece no caderno do Miguel
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
	_fernando_morto()
	if dados.has("cena_ao_chegar") or dados.has("fim_capitulo"):
		_pos_combate.call_deferred()
	var inv: Dictionary = dados.get("invasao", {})
	if not inv.is_empty() and str(inv.get("quando", "")) == "chegada_subsolo" and Missao1.chegada == "subsolo" and not Missao1.tem(str(inv["marca"])):
		_invasao.call_deferred(inv)


# O Fernando morreu na cripta (cutscene do tentáculo): nos lugares seguintes ele não volta de pé, mesmo sem save.
func _fernando_morto() -> void:
	if not Missao1.tem("fernando_morreu"):
		return
	for m in party:
		if m.name == "Fernando":
			m.pv = 0
			m.dead = true
	if player.dead:
		for m in party:
			if not m.dead:
				player = m
				break
	_reset_follow_offsets(Vector2.RIGHT)


# Pós-combate (celeiro): a conversa com a Ordem toca ao chegar e depois vem o fim do capítulo. Carregar um save
# feito depois da conversa vai direto ao fim; depois do fim do capítulo, o lugar fica livre.
func _pos_combate() -> void:
	var c: Dictionary = dados.get("cena_ao_chegar", {})
	if not c.is_empty() and not Missao1.tem(str(c.get("marca", ""))) and CenaRoteiro.existe(str(c["cena"])):
		await tocar_cena(str(c["cena"]))
		if c.has("marca"):
			Missao1.marcar(str(c["marca"]))
	var fim: Dictionary = dados.get("fim_capitulo", {})
	if not fim.is_empty() and not Missao1.tem(str(fim.get("marca", ""))):
		iniciar_fim_capitulo(fim)


func iniciar_fim_capitulo(fim: Dictionary) -> void:
	if fim_capitulo != null:
		return
	mode = Mode.CUTSCENE
	busy = true
	path = PackedVector2Array()
	fim_capitulo = FimCapitulo.tocar(self, fim)
	await fim_capitulo.terminou
	Missao1.marcar(str(fim.get("marca", "capitulo1_fim")))
	Progresso.autosalvar(self, _area_id(), _place_label())
	if is_inside_tree() and get_tree().current_scene == self:
		Scenes.go(get_tree(), CENA_MENU)


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
	portas.clear()
	porta_avisada = ""
	for pt in dados.get("portas", []):
		if Missao1.tem("porta_" + str(pt["id"])):
			continue
		var pr := _ret(pt)
		walls.append(pr)
		portas[str(pt["id"])] = {"rect": pr, "chave": str(pt["chave"]), "texto": str(pt.get("texto", "Trancada.")), "no": null}
	(pathfinder as PathfinderGrade).configurar(walls, size)
	visao.clear()
	for r in dados.get("visao", []):
		visao.append(Rect2(r[0], r[1], r[2], r[3]))
	niveis.clear()
	for n in dados.get("niveis", []):
		var e: Dictionary = (n as Dictionary).duplicate()
		if e.has("ret"):
			e["ret"] = Rect2(e["ret"][0], e["ret"][1], e["ret"][2], e["ret"][3])
		niveis.append(e)
	enemies.clear()
	adormecidos.clear()
	ficha_de.clear()
	var grupos: Dictionary = dados.get("grupos", {})
	for spec in dados.get("inimigos", []):
		var grupo := str(spec.get("grupo", ""))
		if grupos.has(grupo) and Missao1.tem(str(grupos[grupo]["marca"])):
			continue  # esse grupo já foi vencido antes do save
		var trecho := int(spec.get("trecho", 1))
		if trecho > 1 and not Missao1.tem("%s_trecho%d" % [local_id, trecho]):
			if not adormecidos.has(trecho):
				adormecidos[trecho] = []
			adormecidos[trecho].append(spec)
			continue
		_por_inimigo(spec)
	var inicio: Array = dados.get("chegadas", {}).get(Missao1.chegada, [])
	for i in party.size():
		party[i].pos = Vector2(inicio[i][0], inicio[i][1]) if i < inicio.size() else scenario.party_start[i]


# Põe em cena o inimigo de uma ficha dos dados ("percepcao_fator": de costas, percebe menos; "olha": para onde está virado).
func _por_inimigo(spec: Dictionary) -> Combatant:
	var p: Array = spec["pos"]
	var tipo := str(spec["tipo"])
	var chefe: Dictionary = dados.get("chefe", {})
	if not chefe.is_empty() and tipo == str(chefe["tipo"]) and Missao1.tem(str(chefe["marca"])):
		tipo = str(chefe["vira"])  # save feito depois de a Dama surgir: ela já está no lugar dele
		chefe_virou = true
	var u := cfg.make_enemy(tipo, Vector2(p[0], p[1]))
	if chefe_virou and tipo == str(chefe.get("vira", "")):
		chefe_dama = ChefeDama.new(self, u, chefe.get("corpos", []))  # save depois de ela surgir: a luta recomeça inteira
	u.perception *= float(spec.get("percepcao_fator", 1.0))
	u.em_ritual = bool(spec.get("ritual", false))  # salão da cripta: só luta se for atacado (Léo, 19/11)
	if spec.has("olha"):
		var o: Array = spec["olha"]
		facing8[u] = CharacterSheet.dir_from_vector(_iso(u.pos + Vector2(o[0], o[1]) * 32.0) - _iso(u.pos))
	enemies.append(u)
	ficha_de[u] = spec
	return u


# Revela um trecho: os inimigos que esperavam nele entram em cena.
func _acordar(trecho: int) -> void:
	for spec in adormecidos.get(trecho, []):
		_por_inimigo(spec)
	adormecidos.erase(trecho)


# Visão e passo separados (cripta): atira-se por cima do parapeito, do fosso e do altar, mas não se atravessa.
func _sight_blockers() -> Array[Rect2]:
	if visao.is_empty():
		return super()
	return visao


func _obstacles(mover: Combatant = null, with_units := true) -> Array[Rect2]:
	if visao.is_empty():
		return super(mover, with_units)
	var out: Array[Rect2] = []
	out.append_array(walls)
	for u in _living_units() if with_units else []:
		if u != mover:
			out.append(Rect2(u.pos - Vector2(u.radius, u.radius), Vector2(u.radius, u.radius) * 2))
	return out


# --- Área elevada (cripta) --------------------------------------------------------------------
# O plano do jogo continua um só; quem está no terraço é desenhado 1,5 m acima e, nas escadas, a meio caminho.

func _altura(p: Vector2) -> float:
	var alt := 0.0
	for n in niveis:
		var t := -1.0  # posição ao longo da rampa: 0 no alto, 1 no chão
		if n.has("ret"):
			var r: Rect2 = n["ret"]
			if not r.has_point(p):
				continue
			match str(n.get("dir", "")):
				"z-": t = (p.y - r.position.y) / r.size.y
				"z+": t = (r.end.y - p.y) / r.size.y
				"x-": t = (p.x - r.position.x) / r.size.x
				"x+": t = (r.end.x - p.x) / r.size.x
		else:
			var a: Array = n["arco"]  # [cx, cz, a, b, t0, t1, largura]: faixa junto à parede de uma elipse
			var u := (p.x - float(a[0])) / float(a[2])
			var v := (p.y - float(a[1])) / float(a[3])
			var ui := (p.x - float(a[0])) / (float(a[2]) - float(a[6]))
			var vi := (p.y - float(a[1])) / (float(a[3]) - float(a[6]))
			if u * u + v * v > 1.0 or ui * ui + vi * vi < 1.0:
				continue
			var ang := atan2(v, u)
			while ang < float(a[4]):
				ang += TAU
			if ang > float(a[5]):
				continue
			if n["rampa"]:
				t = (ang - float(n["de"])) / (float(n["ate"]) - float(n["de"]))
		if n["rampa"]:
			return float(n["h"]) * (1.0 - clampf(t, 0.0, 1.0))
		alt = float(n["h"])
	return alt


func _iso(p: Vector2) -> Vector2:
	var s := super(p)
	return s if niveis.is_empty() else s - Vector2(0.0, _altura(p) * PX_ALTURA)


# Ponto da tela -> ponto da sala. O piso alto fica na frente do chão que está atrás dele, então vale primeiro o
# ponto do alto (ou da escada) que cai nesse lugar da tela; se não houver, o do chão.
func _uniso(s: Vector2) -> Vector2:
	var chao := super(s)
	if niveis.is_empty():
		return chao
	var topo := 0.0
	for n in niveis:
		topo = maxf(topo, float(n["h"]))
	var p := super(s + Vector2(0.0, topo * PX_ALTURA))
	for i in 5:
		var h := _altura(p)
		if h <= 0.0:
			return chao
		var q := super(s + Vector2(0.0, h * PX_ALTURA))
		if q.distance_to(p) < 0.5:
			return q
		p = q
	return p if _altura(p) > 0.0 else chao


# Fora de casa (fazenda) o passo é de terra e grama; delegacia, biblioteca e cripta são piso duro.
func _step_surface() -> String:
	return "grass" if local_id == "fazenda" or local_id == "casa_geraldo" else "floor"


func _place_label() -> String:
	return "%s · %dh" % [str(dados.get("rotulo", local_id.to_upper())), int(dados.get("hora", 0))]


func _diario_lugar() -> String:
	return _place_label()


# Variante pelo nome da ficha (Léo, 13/11: todos atiradores); o atirador usa a figura do cultista e o retrato próprio.
# A Dama de Sangue usa a figura do Zumbi de Sangue e Roberto Ghular a do atirador, até os modelos deles existirem.
func _enemy_variant(i: int) -> String:
	if i >= enemies.size():
		return "cultista"
	if enemies[i].name == "Dama de Sangue" or enemies[i].name == "Zumbi de Sangue":  # o zumbi do necrotério (22/11)
		return CREATURE_VARIANT
	return "atirador" if enemies[i].name == "Atirador" or enemies[i].name == "Roberto Ghular" else "cultista"


func _proximo_apos_vitoria() -> String:
	return ""


func _process(delta: float) -> void:
	super(delta)
	if chefe_dama != null:
		chefe_dama.visual.sync()
	if mode == Mode.EXPLORATION and indo_para == "" and not _dialogo_aberto():
		_zonas()
		_portas()


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
		if str(z.get("acao", "")) in ["ir", "destinos"] and z.has("cena") and CenaRoteiro.existe(str(z["cena"])) and not Missao1.tem(str(z["cena"])):
			Missao1.marcar(str(z["cena"]))  # a Ju tranca a biblioteca e sai de moto antes de o grupo seguir
			await tocar_cena(str(z["cena"]))
		if str(z.get("acao", "")) == "ir":
			_ir_para(str(z["para"]), str(z.get("chegada", "")), str(z.get("texto", "")))
			return
		if str(z.get("acao", "")) == "destinos":  # saída para a escolha dos três lugares livres (Léo, 20/11)
			_saida_para_destinos(str(z.get("texto", "")))
			return
		if str(z.get("acao", "")) == "estado":  # revela um trecho do cenário (cripta)
			if z.has("marca") and Missao1.tem(str(z["marca"])):
				continue
			if z.has("cena") and CenaRoteiro.existe(str(z["cena"])) and not Missao1.tem(str(z["cena"])):  # o trecho abre com uma cena (o discurso do Ghular no salão); a marca da cena é o id dela
				_revelar_com_cena(z)
				return
			for e in z["estados"]:
				world3d.estado(e, z["estados"][e])
			if z.has("marca"):
				Missao1.marcar(str(z["marca"]))
			_acordar(int(z.get("trecho", 0)))
			queue_redraw()
			continue
		if str(z.get("acao", "")) == "invasao":
			var inv: Dictionary = dados.get("invasao", {})
			if not inv.is_empty() and not Missao1.tem(str(inv["marca"])):
				_invasao(inv)
				return


# Revela o trecho, toca a cena da zona e só então acorda os inimigos dele (o combate não atropela o discurso).
func _revelar_com_cena(z: Dictionary) -> void:
	if not bool(z.get("estados_pela_cena", false)):  # com "estados_pela_cena" a própria cena muda o estado (passo "estado")
		for e in z["estados"]:
			world3d.estado(e, z["estados"][e])
	if z.has("marca"):
		Missao1.marcar(str(z["marca"]))
	Missao1.marcar(str(z["cena"]))
	queue_redraw()
	await tocar_cena(str(z["cena"]))
	_acordar(int(z.get("trecho", 0)))
	queue_redraw()


static func _ret(z: Dictionary) -> Rect2:
	var r: Array = z["ret"]
	return Rect2(r[0], r[1], r[2], r[3])


func _inspect(cid: String) -> void:
	var c: Dictionary = scenario.clues[cid]
	for bruto in dados.get("pistas", []):  # "requer": só depois de uma marca (a Letícia só acorda depois da Dama)
		if str(bruto["id"]) == cid and bruto.has("requer") and not Missao1.tem(str(bruto["requer"])):
			_show_dialog("", str(bruto.get("texto_antes", "Ainda não.")), "")
			return
	if _trancada(c):
		_show_dialog("", c.texto_trancado, "")
		return
	for bruto in dados.get("pistas", []):  # "teste": camada com teste de perícia (d20); passou = texto completo, falhou = o superficial
		if str(bruto["id"]) == cid and bruto.has("teste"):
			var t: Dictionary = bruto["teste"]
			if not t.has("texto_base"):
				t["texto_base"] = c["texto"]  # o texto do cenário é o superficial; guarda para não trocar duas vezes
			var r: Dictionary = await _tentar_teste("%s_%s" % [local_id, cid], t)
			c["texto"] = ("%s\n\n%s" % [TestePericia.texto(r), str(t["completo"]) if r.get("passou", false) else str(t["texto_base"])])
			break
	_show_dialog(c.inspecao, c.texto, cid)


# Rola (uma vez) o teste de `t` ({"pericias": [...], "dt": n}). O jogador escolhe quem rola antes do dado, vendo a DT e o
# bônus de cada agente (Léo, 22/11). Se o teste já foi feito, devolve o resultado salvo sem perguntar.
func _tentar_teste(id: String, t: Dictionary) -> Dictionary:
	var grupo: Array = []
	for u in party:
		grupo.append({"nome": u.name, "atributos": u.atributos, "ocultista": Ficha.classe_de(rules.cfg.game_data, u.personagem) == "ocultista"})
	var pericias: Array = t.get("pericias", [])
	var dt := int(t.get("dt", 12))
	var escolha := {}
	if not TestePericia.feito(id) and not grupo.is_empty():
		escolha = await _escolher_quem_rola(pericias, dt, grupo)
	var r := TestePericia.tentar(id, pericias, dt, grupo, _rng_teste(), 0, escolha)
	if TestePericia.animar and r.has("dado") and not r.get("salvo", false):
		await _mostrar_dado(r)
	return r


# A tela do d20 rolando (TelaD20): o jogador vê o dado parar e a conta antes de ler o texto da pista.
func _mostrar_dado(r: Dictionary) -> void:
	busy = true
	var tela := TelaD20.new()
	add_child(tela)
	tela.montar(r)
	await tela.fechada
	busy = false


func _escolher_quem_rola(pericias: Array, dt: int, grupo: Array) -> Dictionary:
	if menu_teste != null:
		return {}
	busy = true
	path = PackedVector2Array()
	moving_unit = null
	menu_teste = CanvasLayer.new()
	menu_teste.layer = 86
	add_child(menu_teste)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.62)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_teste.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 8)
	caixa.custom_minimum_size = Vector2(460, 0)
	centro.add_child(caixa)
	var nomes: Array = []
	for p in pericias:
		nomes.append("%s (%s)" % [TestePericia.PERICIAS[str(p)]["nome"], TestePericia.PERICIAS[str(p)]["atr"]])
	var tit := Label.new()
	tit.text = "Teste de %s · DT %d\nQuem rola o d20?" % [" ou ".join(nomes), dt]
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	caixa.add_child(tit)
	for o in TestePericia.opcoes(pericias, grupo):
		var b := Button.new()
		b.text = "%s · %s  (bônus %+d)" % [o["quem"], TestePericia.PERICIAS[o["pericia"]]["nome"], int(o["bonus"])]
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(func(): teste_escolhido.emit(o))
		caixa.add_child(b)
	var escolha: Dictionary = await teste_escolhido
	menu_teste.queue_free()
	menu_teste = null
	busy = false
	return escolha


func _rng_teste() -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.randomize()
	return g


# Baú num trecho que ainda não foi revelado (cripta) fica invisível até o líder pisar na faixa do trecho.
func _pista_oculta(cid: String) -> bool:
	for bruto in dados.get("pistas", []):
		if str(bruto["id"]) == cid and int(bruto.get("trecho", 1)) > 1:
			return not Missao1.tem("%s_trecho%d" % [local_id, int(bruto["trecho"])])
	return false


func _run_trigger(trigger: Dictionary) -> void:
	if str(trigger["tipo"]) == "cena":  # depois da pista toca uma cena com roteiro (data/cenas), uma vez (a marca impede repetir)
		var cena_id := str(trigger.get("cena", ""))
		var m := str(trigger.get("marca", ""))
		if CenaRoteiro.existe(cena_id) and (m == "" or not Missao1.tem(m)):
			if m != "":
				Missao1.marcar(m)
			if trigger.has("teste"):  # a cena depende de um teste de perícia (Geraldo): falhou = a versão curta ("cena_falha")
				var r: Dictionary = await _tentar_teste("%s_%s" % [local_id, cena_id], trigger["teste"])
				_show_dialog("", TestePericia.texto(r), "")
				while dialog_layer.visible:
					await get_tree().process_frame
				if not r.get("passou", false) and CenaRoteiro.existe(str(trigger["teste"].get("cena_falha", ""))):
					cena_id = str(trigger["teste"]["cena_falha"])
			await tocar_cena(cena_id)
		return
	if str(trigger["tipo"]) == "ir":  # depois da pista, o grupo segue para outro lugar (o poço leva à cripta)
		_ir_para(str(trigger["para"]), str(trigger.get("chegada", "")), str(trigger.get("texto", "")))
		return
	if str(trigger["tipo"]) != "estado":
		super(trigger)
		return
	var estados: Dictionary = trigger.get("estados", {})
	for e in estados:
		world3d.estado(e, estados[e])
	if trigger.has("marca"):
		Missao1.marcar(str(trigger["marca"]))
	queue_redraw()


# Saída de um lugar livre (ou da delegacia das 17h): o grupo escolhe o próximo destino entre os que ainda não visitou;
# quando não sobra nenhum, volta à delegacia (21h). Com um só restante, vai direto.
func _saida_para_destinos(texto_saida: String) -> void:
	var livres := Missao1.destinos_livres()
	if livres.is_empty():
		_ir_para("delegacia_21h", "", "O grupo volta para a delegacia.")
		return
	if livres.size() == 1:
		_ir_para(str(livres[0]["id"]), "", str(livres[0]["texto"]))
		return
	_abrir_menu_destinos(livres, texto_saida)


func _abrir_menu_destinos(livres: Array, titulo: String) -> void:
	if menu_destinos != null:
		return
	busy = true
	path = PackedVector2Array()
	moving_unit = null
	menu_destinos = CanvasLayer.new()
	menu_destinos.layer = 85
	add_child(menu_destinos)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.62)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_destinos.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.add_child(centro)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	caixa.custom_minimum_size = Vector2(420, 0)
	centro.add_child(caixa)
	var t := Label.new()
	t.text = "Para onde o grupo vai agora?"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	caixa.add_child(t)
	for d in livres:
		var b := Button.new()
		b.text = "%s\n%s" % [str(d["rotulo"]), str(d["detalhe"])]
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(_escolher_destino.bind(d))
		caixa.add_child(b)
	var ficar := Button.new()
	ficar.text = "Ficar mais um pouco"
	ficar.pressed.connect(_fechar_menu_destinos)
	caixa.add_child(ficar)


func _escolher_destino(d: Dictionary) -> void:
	_fechar_menu_destinos()
	_ir_para(str(d["id"]), "", str(d["texto"]))


func _fechar_menu_destinos() -> void:
	if menu_destinos != null:
		menu_destinos.queue_free()
		menu_destinos = null
	busy = false


# Invasão da delegacia às 21h (Léo, 13/11): depois do subsolo, ao entrar na recepção, uma flashbang estoura pela
# porta da frente (tela branca e tremida), os atiradores entram e o combate começa quando a vista volta.
func _invasao(inv: Dictionary) -> void:
	if invadindo:
		return
	invadindo = true
	var cena_morte := str(inv.get("cena_antes", ""))  # a morte do Túlio: porta trancada por fora, tiros e vidros, antes da flashbang
	if cena_morte != "" and CenaRoteiro.existe(cena_morte) and not Missao1.tem(cena_morte):
		Missao1.marcar(cena_morte)
		await tocar_cena(cena_morte)
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
	if result == TurnManager.Result.VICTORY and chefe_dama != null:
		chefe_dama.encerrar()  # flores, tentáculos e prisões que sobraram somem
	super(result)
	var inv: Dictionary = dados.get("invasao", {})
	if result == TurnManager.Result.VICTORY and not inv.is_empty():
		Missao1.marcar(str(inv["marca"]))
	if result == TurnManager.Result.VICTORY:
		_marcar_grupos()
	var apos: Dictionary = dados.get("cena_apos_combate", {})  # o grupo comenta o zumbi (necrotério, 22/11)
	if result == TurnManager.Result.VICTORY and not apos.is_empty() and CenaRoteiro.existe(str(apos["cena"])) \
			and not Missao1.tem(str(apos["marca"])) and (not apos.has("requer") or Missao1.tem(str(apos["requer"]))):
		Missao1.marcar(str(apos["marca"]))
		await get_tree().create_timer(1.0).timeout
		await tocar_cena(str(apos["cena"]))
	var depois := str(inv.get("cena_depois", ""))  # a ligação da Juliana, logo depois do ataque
	if result == TurnManager.Result.VICTORY and depois != "" and CenaRoteiro.existe(depois) and not Missao1.tem("ligacao_juliana"):
		Missao1.marcar("ligacao_juliana")
		await get_tree().create_timer(1.0).timeout  # o último golpe termina antes de a cena começar
		await tocar_cena(depois)


# Grupo vencido: todos os inimigos dele em cena caíram e nenhum espera num trecho escondido.
func _marcar_grupos() -> void:
	var grupos: Dictionary = dados.get("grupos", {})
	for g in grupos:
		var gd: Dictionary = grupos[g]
		if Missao1.tem(str(gd["marca"])) or (gd.has("requer") and not Missao1.tem(str(gd["requer"]))):
			continue
		var vivo := false
		var algum := false
		for e in enemies:
			if str((ficha_de.get(e, {}) as Dictionary).get("grupo", "")) == g:
				algum = true
				vivo = vivo or e.is_alive()
		for t in adormecidos:
			for spec in adormecidos[t]:
				vivo = vivo or str(spec.get("grupo", "")) == g
		if algum and not vivo:
			Missao1.marcar(str(gd["marca"]))
	Progresso.autosalvar(self, _area_id(), _place_label())
	queue_redraw()


# Chefe da cripta (Léo, 14/11): com pouca vida, Roberto Ghular se mata e a Dama de Sangue surge dele. O ataque já
# foi resolvido pelas regras quando chega aqui, então a troca acontece antes de o combate conferir se acabou.
func _show_attack(attacker: Combatant, target: Combatant, r: Dictionary) -> void:
	super(attacker, target, r)
	_depois_do_dano(target)


# Ritual ou item de combate que atingiu alguém: as mesmas conferências do golpe, e as flores e tentáculos da Dama.
func _apos_efeito(alvo: Combatant) -> void:
	_depois_do_dano(alvo)
	if chefe_dama != null:
		chefe_dama.ao_impacto(alvo)


func _depois_do_dano(target: Combatant) -> void:
	if _e_a_dama(target) and not target.is_alive() and not dados.get("fim", {}).is_empty() and not fim_tocou:
		target.pv = 1  # a Dama não morre antes da cutscene do fim (Léo, 15/11): um golpe que a mataria a deixa por um fio
	if _e_a_dama(target) and not target.is_alive():
		_romper_ritual()
	var chefe: Dictionary = dados.get("chefe", {})
	if chefe.is_empty() or chefe_virou or not enemies.has(target):
		return
	if str((ficha_de.get(target, {}) as Dictionary).get("tipo", "")) != str(chefe["tipo"]):
		return
	if float(target.pv) > float(chefe["limite"]) * float(target.max_pv):
		return
	chefe_virou = true
	target.pv = 0
	var dama := cfg.make_enemy(str(chefe["vira"]), target.pos)
	facing8[dama] = facing8.get(target, CharacterSheet.Dir.SW)
	enemies.append(dama)
	ficha_de[dama] = {"tipo": str(chefe["vira"]), "grupo": str((ficha_de[target] as Dictionary).get("grupo", ""))}
	Missao1.marcar(str(chefe["marca"]))
	if mode == Mode.COMBAT and turns != null:
		turns.add_unit(dama)
	chefe_dama = ChefeDama.new(self, dama, chefe.get("corpos", []))  # pendurados e flor Vermelha surgem com ela
	_log(str(chefe["texto"]))
	_popup(target.pos, "A DAMA DE SANGUE SURGE", "down")
	audio.on_boss_appeared()
	fx.shake_time = 0.5
	fx.shake_px = 6.0
	queue_redraw()


# A Dama morreu: quem ainda estava no ritual (Léo, 19/11: só luta se for atacado) cai junto e o combate acaba.
# Provisório do Claude (19/11), para a luta não continuar contra seis que nem lutavam.
func _romper_ritual() -> void:
	var algum := false
	for e in enemies:
		if e.em_ritual and e.is_alive():
			e.pv = 0
			algum = true
	if algum:
		_log("O ritual se rompe com a Dama: os que o mantinham caem.")


func _e_a_dama(u: Combatant) -> bool:
	return enemies.has(u) and u.name == "Dama de Sangue"  # surgida de Roberto ou já no lugar dele (save)


# Cada impacto pode murchar uma flor, salvar um pendurado, soltar um preso ou levar a Dama à fase 2.
func _on_fx_impact(job: Dictionary) -> void:
	super(job)
	if chefe_dama != null:
		chefe_dama.ao_impacto(job["target"])


func _run_enemy_turn(unit: Combatant) -> void:
	if chefe_dama != null and unit == chefe_dama.dama:
		await chefe_dama.run_turn()
		return
	await super(unit)


func _start_combat(surprise_side: int = -1) -> void:
	super(surprise_side)
	if turns != null and not turns.turn_ended.is_connected(_ao_fim_do_turno):
		turns.turn_ended.connect(_ao_fim_do_turno)


# Fim da missão 1 (Léo, 20/11): com a Dama em 15% de vida ou menos (fim.limite de cripta.json), a cutscene do
# tentáculo toca logo depois do turno do Fernando, sempre; se ele está caído, no fim do turno em que ela chegou lá.
func _ao_fim_do_turno(u: Combatant) -> void:
	var fim: Dictionary = dados.get("fim", {})
	if fim.is_empty() or fim_tocou or mode != Mode.COMBAT:
		return
	var dama: Combatant = null
	for e in enemies:
		if _e_a_dama(e) and e.is_alive():
			dama = e
	if dama == null or float(dama.pv) > float(fim["limite"]) * float(dama.max_pv):
		return
	var fernando: Combatant = null
	for m in party:
		if m.name == "Fernando":
			fernando = m
	if fernando != null and fernando.is_alive() and u != fernando:
		return
	iniciar_fim(dama)


func iniciar_fim(dama: Combatant) -> void:
	fim_tocou = true
	var cena := CenaTentaculo.new()
	add_child(cena)
	cena.iniciar(self, dama, dados["fim"])


# Durante a cutscene não há HUD, barras de vida nem pausa.
func _draw_hud(font: Font) -> void:
	if mode != Mode.CUTSCENE:
		super(font)


# Flores e tentáculos da Dama: o objeto 3D é do DamaVisual; aqui só a barra de vida de quem dá para ferir agora.
func _draw_unit(u: Combatant) -> void:
	if not u.objeto:
		super(u)
		return
	if mode == Mode.COMBAT and u.is_alive() and not u.protegido:
		_draw_health_bar(u, _iso(u.pos))


func _draw_health_bar(u: Combatant, at: Vector2) -> void:
	if mode != Mode.CUTSCENE and not u.dead:
		super(u, at)


# O Fernando morto (cutscene do tentáculo) continua deitado na cena.
func _drawn_units() -> Array[Combatant]:
	var out := super()
	for m in party:
		if m.dead and m.name == "Fernando" and Missao1.tem("fernando_morreu") and local_id == "cripta" and not out.has(m):
			out.append(m)
	return out


func can_pause() -> bool:
	return mode != Mode.CUTSCENE and super()


# Objetivos do HUD vêm dos dados: cada um feito ao ver a pista ou ao ganhar a marca; "requer" só mostra depois de outra marca.
func _objectives() -> Array[Dictionary]:
	return Objectives.from_data(dados.get("objetivos", []), seen_clues, Missao1.tem, mode == Mode.COMBAT)


# Minimapa: o lugar inteiro conta como visto (como no parque); na cripta, só os trechos já revelados.
func _known_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var trechos: Dictionary = dados.get("trechos", {})
	if trechos.is_empty():
		out.append(Rect2(Vector2.ZERO, scenario.size))
		return out
	for t in trechos:
		if int(t) > 1 and not Missao1.tem("%s_trecho%d" % [local_id, int(t)]):
			continue
		for r in trechos[t]:
			out.append(Rect2(r[0], r[1], r[2], r[3]))
	return out
