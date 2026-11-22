class_name CenaRoteiro
extends Node
# Cenas dentro do jogo conduzidas por roteiro (Léo, 15/11/2026: sugestão 5 da revisão da missão 1). Câmera, personagens,
# falas e efeitos seguem uma lista de passos em data/cenas/<id>.json, no modo cinema com faixas (Cinema, o mesmo
# enquadramento que o Léo escolheu para a cutscene do Fernando). A primeira cena é a morte do Caio, no parque.
# Filho da sala (parque.gd ou local3d.gd): o _process dele roda depois do da sala e manda na câmera.
#
# Cada passo é um dicionário com "faz" e os campos dele. Os que levam tempo esperam terminar, salvo "junto": true
# (o passo começa e o roteiro segue para o próximo na mesma hora).
#   cinema   {"estado": "entrar" | "sair"}                          barras do cinema
#   camera   {"em": ator | [x, y], "zoom": z | "jogador", "altura": a}  câmera desliza até o ponto (altura em px da tela)
#   andar    {"quem": ator, "ate": ator | [x, y], "perto": px, "correr": bool, "de_costas": bool, "vel": px/s}
#   olhar    {"quem": ator, "para": ator | [x, y]}
#   anim     {"quem": ator, "anim": nome, "tempo": s, "laco": bool}  anima o modelo 3D (morte, dano, ataque...); "" volta ao normal
#   saltar   {"quem": ator, "sobre": ator | [x, y], "tempo": s, "altura": u, "perto": px}  salto em arco até o alvo
#   choque   {"quem": ator, "sim": bool}                             o NPC treme no lugar (em choque)
#   cair     {"quem": ator}                                          o corpo tomba e fica no chão
#   fala     {"quem": "Letícia", "texto": "...", "tempo": s}         legenda com o nome de quem fala
#   legenda  {"texto": "...", "tempo": s}
#   dialogo  {"falas": [{"quem": id, "texto": "..."}, ...]}          conversa na caixa com retrato (CaixaFala); clique avança
#   esperar  {"tempo": s}
#   tremor   {"forca": px, "tempo": s}
#   flash    {"forca": 0..1}                                         clarão vermelho na tela
#   sangue   {"em": ator, "qtd": n, "altura": px}                    respingos
#   poca     {"em": ator, "tamanho": m}                              poça de sangue que cresce no chão
#   surgir   {"id": nome, "tipo": "criatura_sangue", "pos": [x, y]}  criatura que só existe na cena
#   sumir    {"quem": ator}                                          tira o ator da cena (NPC ou criatura da cena)
#   marca    {"id": nome}                                            Missao1.marcar
#   estado   {"nome": estado, "valor": bool}                          liga/desliga um estado do cenário 3D (local3d)
#   acordar  {"trecho": n}                                           os inimigos que esperavam o trecho n entram em cena (local3d)
# Atores: id de NPC do cenário ("caio", "leticia"), nome do membro do grupo ("Fernando", "Nikolai", "Miguel"),
# "lider" (o controlado), "inimigo:N" (N-ésimo inimigo do gatilho) ou o id de algo que surgiu na cena.

signal terminou

const PASTA := "res://data/cenas/"
const VEL_ANDAR := 150.0  # px da sala por segundo (o grupo anda a 180 no jogo; na cena, um pouco mais devagar)
const VEL_CORRER := 290.0
const ALTURA_PEITO := 70.0  # px do desenho acima do pé

var room  # parque.gd (ou local3d.gd)
var id := ""
var passos: Array = []
var cinema: Cinema
var _cam_alvo := Vector2.ZERO
var _zoom_alvo := 1.5
var _cam_pos := Vector2.ZERO
var _zoom := 1.5
var _zoom_jogador := 1.5  # zoom de antes da cena: volta a ele no fim (a roda do mouse é do jogador)
var _andando := {}  # ator -> {"rota": PackedVector2Array, "vel": float}
var _surgidos := {}  # id -> Combatant criado pela cena
var tocando := false


static func carregar(cena_id: String) -> Array:
	var f := FileAccess.open(PASTA + cena_id + ".json", FileAccess.READ)
	if f == null:
		return []
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d.get("passos", []) if d is Dictionary else []


static func existe(cena_id: String) -> bool:
	return FileAccess.file_exists(PASTA + cena_id + ".json")


func iniciar(sala, cena_id: String) -> void:
	room = sala
	id = cena_id
	passos = carregar(cena_id)
	var cam: Camera2D = room.camera
	_cam_alvo = cam.position
	_cam_pos = cam.position
	_zoom_alvo = cam.zoom.x
	_zoom = cam.zoom.x
	_zoom_jogador = cam.zoom.x
	tocar()


func _process(delta: float) -> void:
	if room == null or not tocando:
		return
	_andar(delta)
	# A sala reposiciona a câmera no próprio _process (que roda antes deste): a cena guarda a dela e sobrescreve.
	var cam: Camera2D = room.camera
	_cam_pos = _cam_pos.lerp(_cam_alvo, 1.0 - exp(-2.6 * delta))
	_zoom = lerpf(_zoom, _zoom_alvo * float(Cinema.ZOOM_REL[cinema.modo]) if cinema else _zoom_alvo, 1.0 - exp(-2.2 * delta))
	cam.position = _cam_pos.round()
	cam.zoom = Vector2(_zoom, _zoom)
	room.queue_redraw()


func tocar() -> void:
	tocando = true
	cinema = Cinema.new(Cinema.Modo.FAIXAS)
	room.add_child(cinema)
	for p in passos:
		var passo: Dictionary = p
		if passo.get("junto", false):
			_executar(passo)
		else:
			await _executar(passo)
	if cinema.progresso > 0.0:
		await cinema.sair()
	_limpar()
	tocando = false
	terminou.emit()


func _executar(p: Dictionary) -> void:
	match str(p.get("faz", "")):
		"cinema":
			if p.get("estado", "entrar") == "entrar":
				await cinema.entrar(float(p.get("tempo", 0.9)))
			else:
				await cinema.sair(float(p.get("tempo", 0.7)))
		"camera":
			_cam_alvo = _ponto_tela(p.get("em", "lider")) + Vector2(0, -float(p.get("altura", ALTURA_PEITO)))
			if p.has("zoom"):
				_zoom_alvo = _zoom_jogador if str(p["zoom"]) == "jogador" else float(p["zoom"])
			await _esperar(float(p.get("tempo", 0.0)))
		"andar":
			await _ir(p)
		"olhar":
			room.cena_virar(_ator(p["quem"]), _ponto(p["para"]))
		"anim":
			room.cena_anim(_ator(p["quem"]), str(p.get("anim", "")), float(p.get("tempo", 1.5)), bool(p.get("laco", false)))
			await _esperar(float(p.get("tempo", 0.0)) if p.get("espera", false) else 0.0)
		"saltar":
			var q: Variant = _ator(p["quem"])
			var alvo := _ponto(p["sobre"])
			var perto := float(p.get("perto", 0.0))
			var de: Vector2 = room.cena_pos(q)
			if perto > 0.0 and de.distance_to(alvo) > perto:
				alvo += (de - alvo).normalized() * perto
			await room.cena_salto(q, alvo, float(p.get("tempo", 0.6)), float(p.get("altura", 1.0)))
		"choque":
			room.cena_choque(_ator(p["quem"]), bool(p.get("sim", true)))
		"cair":
			room.cena_anim(_ator(p["quem"]), "death", float(p.get("tempo", 1.4)))
			await _esperar(float(p.get("tempo", 1.4)))
		"fala":
			var quem := str(p.get("quem", ""))
			cinema.legenda(("%s: %s" % [quem, p["texto"]]) if quem != "" else str(p["texto"]), float(p.get("tempo", 2.2)))
			await _esperar(float(p.get("tempo", 2.2)) + 1.1)
		"legenda":
			cinema.legenda(str(p["texto"]), float(p.get("tempo", 2.4)))
			await _esperar(float(p.get("tempo", 2.4)) + 1.1)
		"dialogo":
			await _dialogo(p.get("falas", []))
		"esperar":
			await _esperar(float(p.get("tempo", 1.0)))
		"tremor":
			room.fx.shake_time = float(p.get("tempo", 0.4))
			room.fx.shake_px = float(p.get("forca", 6.0))
		"flash":
			room.fx.flash_red = float(p.get("forca", 0.5))
			room.fx.flash_strength = 1.4
		"sangue":
			_sangue(_ponto_tela(p.get("em", "lider")) + Vector2(0, -float(p.get("altura", ALTURA_PEITO))), int(p.get("qtd", 24)))
		"poca":
			room.cena_poca(_ponto(p.get("em", "lider")), float(p.get("tamanho", 2.0)))
		"surgir":
			var c: Combatant = room.cena_surgir(str(p.get("tipo", "criatura_sangue")), _vec(p["pos"]))
			_surgidos[str(p["id"])] = c
		"sumir":
			room.cena_sumir(_ator(p["quem"]))
		"marca":
			Missao1.marcar(str(p["id"]))
		"estado":  # liga ou desliga um estado do cenário 3D no meio da cena (a gaveta do necrotério que arrebenta)
			if room.get("world3d") != null:
				room.world3d.estado(str(p["nome"]), bool(p.get("valor", true)))
				room.queue_redraw()
		"acordar":  # os inimigos que esperavam um trecho escondido entram em cena (o zumbi, depois da gaveta)
			if room.has_method("_acordar"):
				room._acordar(int(p.get("trecho", 0)))
		_:
			push_warning("cena %s: passo desconhecido %s" % [id, p])


# --- Atores -------------------------------------------------------------------------------------

# Ator: id de NPC (String), membro do grupo ou criatura da cena (Combatant).
func _ator(nome: Variant) -> Variant:
	var n := str(nome)
	if _surgidos.has(n):
		return _surgidos[n]
	if n == "lider":
		return room.player
	if n.begins_with("inimigo:") and int(n.get_slice(":", 1)) < room.enemies.size():
		return room.enemies[int(n.get_slice(":", 1))]  # inimigos que o gatilho já pôs no mapa, na ordem dos dados
	for m in room.party:
		if m.name == n:
			return m
	if room.scenario.npcs.has(n):
		return n
	push_warning("cena %s: ator desconhecido %s" % [id, n])
	return room.player


func _vec(v: Variant) -> Vector2:
	return Vector2(float(v[0]), float(v[1]))


# Posição na sala (px do plano) de um ator ou de um ponto [x, y].
func _ponto(alvo: Variant) -> Vector2:
	if alvo is Array:
		return _vec(alvo)
	return room.cena_pos(_ator(alvo))


func _ponto_tela(alvo: Variant) -> Vector2:
	return room._iso(_ponto(alvo))


func _esperar(s: float) -> void:
	if s > 0.0:
		await get_tree().create_timer(s).timeout


# Anda até o ponto (ou até `perto` px de outro ator), pela rota do pathfinder quando houver.
func _ir(p: Dictionary) -> void:
	var quem: Variant = _ator(p["quem"])
	var de: Vector2 = room.cena_pos(quem)
	var ate := _ponto(p["ate"])
	var perto := float(p.get("perto", 0.0))
	if perto > 0.0 and de.distance_to(ate) > perto:
		ate = ate + (de - ate).normalized() * perto
	var rota: PackedVector2Array = room.pathfinder.find_path(de, ate, room._obstacles(quem if quem is Combatant else null, false), 12.0)
	if rota.is_empty():
		rota = PackedVector2Array([de, ate])
	rota.remove_at(0)
	var vel := VEL_CORRER if p.get("correr", false) else VEL_ANDAR
	_andando[quem] = {"rota": rota, "vel": float(p.get("vel", vel)), "de_costas": p.get("de_costas", false)}
	room.cena_andando(quem, true)
	while _andando.has(quem):
		await get_tree().process_frame


func _andar(delta: float) -> void:
	for quem in _andando.keys():
		var a: Dictionary = _andando[quem]
		var rota: PackedVector2Array = a["rota"]
		if rota.is_empty():
			_andando.erase(quem)
			room.cena_andando(quem, false)
			continue
		var de: Vector2 = room.cena_pos(quem)
		var nova := de.move_toward(rota[0], float(a["vel"]) * delta)
		if not a.get("de_costas", false):  # de costas: anda sem se virar (recua olhando para a frente)
			room.cena_virar(quem, rota[0])
		room.cena_mover(quem, nova)
		if nova.is_equal_approx(rota[0]):
			rota.remove_at(0)
		a["rota"] = rota


# Conversa da cena na caixa com retrato (a mesma das pistas). A caixa sobe acima das barras do cinema enquanto fala.
func _dialogo(falas: Array) -> void:
	var caixa: CaixaFala = room.caixa
	if caixa == null or falas.is_empty():
		return
	var camada := caixa.layer
	caixa.layer = cinema.layer + 1
	await caixa.sequencia(falas)
	caixa.layer = camada


func _sangue(ponto: Vector2, qtd: int) -> void:
	var rng := RandomNumberGenerator.new()
	for i in qtd:
		room.fx.particles.append({"pos": ponto, "vel": Vector2(rng.randf_range(-90, 90), rng.randf_range(-140, 10)), "life": 0.9, "max": 0.9, "kind": "blood", "size": rng.randf_range(1.5, 3.5)})


func _limpar() -> void:
	room.camera.zoom = Vector2(_zoom_jogador, _zoom_jogador)
	for n in _surgidos:
		room.cena_sumir(_surgidos[n])
	_surgidos.clear()
	if cinema:
		cinema.queue_free()
