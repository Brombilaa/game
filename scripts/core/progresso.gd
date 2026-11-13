class_name Progresso
extends RefCounted
# O que vai dentro do save (o "data" do SaveGame) e como volta para o jogo.
#   current_area: id do cenário (parque, delegacia_17h...); rotulo: nome do lugar para o menu.
#   missao: Missao1 (local, chegada, marcas); pistas: pistas já vistas no lugar atual.
#   grupo: PV, SAN, caído/morto e equipamento de cada membro, pelo nome; lider: índice do controlado.
#   mochila: os 20 espaços do inventário compartilhado.
# O save guarda o lugar como ele estava ao chegar (ou no início do combate): carregar abre o lugar pela
# mesma chegada, com o grupo e a mochila daquele momento. Posição exata e inimigos vivos não vão (a cena
# os recria dos dados do lugar). Se o save foi feito no início de um combate disparado por uma pista, essa
# pista sai da lista, para o combate acontecer de novo ao examiná-la (Game Over volta para antes dele).

const CENA_PARQUE := "res://scenes/exploration/parque.tscn"

static var pendente := {}  # save lido no menu, à espera de a cena do lugar abrir e aplicá-lo
static var dir := SaveSlots.DIR  # pasta dos saves (os testes usam outra)
static var autosave_ativo := true


# Novo jogo: missão do começo, sem save pendente, no parque.
static func novo_jogo(tree: SceneTree) -> bool:
	Missao1.reiniciar()
	pendente = {}
	return Scenes.go(tree, CENA_PARQUE)


# Lê o slot e abre o lugar salvo; a cena aplica o resto em _ready (tomar_pendente). false se não deu.
static func carregar(tree: SceneTree, slot: String, pasta := "") -> bool:
	var data := SaveSlots.load_slot(slot, pasta if pasta != "" else dir)
	if data.is_empty():
		return false
	var cena := preparar_missao(data)
	if cena == "":
		return false
	pendente = data
	if not Scenes.go(tree, cena):
		pendente = {}
		return false
	return true


static func tomar_pendente() -> Dictionary:
	var d := pendente
	pendente = {}
	return d


# Autosave (DEC-2026-10-29-01): ao chegar em um lugar e no início do combate.
static func autosalvar(room: Node, area: String, rotulo: String, pista_do_combate := "") -> Error:
	if not autosave_ativo:
		return OK
	return SaveSlots.save(SaveSlots.AUTO, capturar(room, area, rotulo, pista_do_combate), dir)


# Fotografa a sala (parque.gd ou local3d.gd). `pista_do_combate`: pista que disparou o combate em curso.
static func capturar(room: Node, area: String, rotulo: String, pista_do_combate := "") -> Dictionary:
	var pistas: Array = []
	for c in room.seen_clues:
		if c != pista_do_combate:
			pistas.append(c)
	var grupo: Array = []
	for m in room.party:
		grupo.append({
			"nome": m.name,
			"pv": m.pv,
			"max_pv": m.max_pv,
			"san": m.san,
			"max_san": m.max_san,
			"morto": m.dead,
			"equip": (room.gear.get(m, {}) as Dictionary).duplicate(),
		})
	var mochila: Array = []
	for s in room.inventory.slots:
		mochila.append(s.duplicate())
	return {
		"current_area": area,
		"rotulo": rotulo,
		"missao": {"local": Missao1.local, "chegada": Missao1.chegada, "marcas": Missao1.marcas.keys()},
		"pistas": pistas,
		"grupo": grupo,
		"lider": maxi(room.party.find(room.player), 0),
		"mochila": mochila,
	}


# Põe a missão de volta antes de abrir a cena (o lugar e a chegada decidem o que a cena monta).
# Devolve a cena a abrir, ou "" se o save não tiver o mínimo para isso.
static func preparar_missao(data: Dictionary) -> String:
	if not data.get("missao") is Dictionary or not data.get("current_area") is String:
		return ""
	var m: Dictionary = data["missao"]
	Missao1.reiniciar()
	Missao1.local = str(m.get("local", ""))
	Missao1.chegada = str(m.get("chegada", ""))
	for marca in m.get("marcas", []):
		Missao1.marcar(str(marca))
	return CENA_PARQUE if Missao1.local == "" else Missao1.CENA_LOCAL


# Devolve à sala já montada o grupo, a mochila e as pistas do save. Campos que faltam ficam como estão.
static func aplicar(room: Node, data: Dictionary) -> void:
	for c in data.get("pistas", []):
		if not room.seen_clues.has(str(c)):
			room.seen_clues.append(str(c))
	for g in data.get("grupo", []):
		var m: Combatant = null
		for p in room.party:
			if p.name == str(g.get("nome", "")):
				m = p
		if m == null:
			continue
		m.max_pv = int(g.get("max_pv", m.max_pv))
		m.pv = clampi(int(g.get("pv", m.pv)), 0, m.max_pv)
		m.max_san = int(g.get("max_san", m.max_san))
		m.san = clampi(int(g.get("san", m.san)), 0, m.max_san)
		m.dead = bool(g.get("morto", false))
		var equip = g.get("equip")
		if equip is Dictionary and room.gear.has(m):
			for slot in room.gear[m]:
				room.gear[m][slot] = str(equip.get(slot, room.gear[m][slot]))
			var main: String = room.gear[m]["principal"]
			m.weapon = room.cfg.weapon(main if _arma_existe(room, main) else "soco")
			var colete: String = room.gear[m]["colete"]
			m.defense = float(room.cfg.game_data.get_entry("itens", colete).get("valor", 0.0)) if colete != "" else 0.0
	var mochila = data.get("mochila")
	if mochila is Array:
		for i in room.inventory.slots.size():
			var s = mochila[i] if i < mochila.size() else {}
			room.inventory.slots[i] = {"id": str(s["id"]), "qty": int(s.get("qty", 1))} if s is Dictionary and s.has("id") else {}
	var lider := int(data.get("lider", 0))
	if lider >= 0 and lider < room.party.size() and not room.party[lider].dead:
		room.player = room.party[lider]


static func _arma_existe(room: Node, id: String) -> bool:
	return id != "" and not room.cfg.game_data.get_entry("armas", id).is_empty()
