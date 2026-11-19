class_name ControlesCaderno
extends Control
# Mapa de controles nas Opções (Léo, 19/11/2026): teclado e mouse desenhados numa página do caderno de campo, em
# tons de pergaminho e tinta. Cada tecla usada mostra a função; passar o mouse (ou clicar) numa tecla abre a ficha no
# pé da página com o que ela faz, quando vale e o custo. Os filtros Tudo, Explorar, Combate e Painéis apagam o resto,
# para consultar só o que importa naquele momento. Só mostra; não remapeia as teclas.
# Itens de combate e rituais vêm de Atalhos e de data/ (nome, PA,
# SAN), então o mapa acompanha o balanceamento. Quem mudar outra tecla do jogo atualiza `mapa()`.

signal voltar  # botão direito: o menu volta um passo

const INK := Color(0.05, 0.037, 0.03, 0.97)
const PAPER := Color(0.91, 0.87, 0.79)
const MUTED := Color(0.62, 0.56, 0.46)
const FAINT := Color(0.34, 0.29, 0.23)
const BRONZE := Color(0.353, 0.255, 0.149)
const GOLD := Color(0.839, 0.678, 0.361)
const BLOOD := Color(0.72, 0.2, 0.18)
const FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")

const FILTERS := [["all", "Tudo"], ["mover", "Explorar"], ["combate", "Combate"], ["painel", "Painéis"]]
const KEY := 36.0
const GAP := 3.0
const PAD := 18.0
const TOP := 56.0
const PAGE_W := 820.0
const PAGE_H := 432.0
const CARD_H := 104.0

# Teclado: [rótulo, coluna (em teclas), linha, largura (em teclas)].
const LAYOUT := [
	["Esc", 0.0, 0, 1.0], ["F3", 2.0, 0, 1.0],
	["1", 0.0, 1, 1.0], ["2", 1.0, 1, 1.0], ["3", 2.0, 1, 1.0], ["4", 3.0, 1, 1.0], ["5", 4.0, 1, 1.0],
	["6", 5.0, 1, 1.0], ["7", 6.0, 1, 1.0], ["8", 7.0, 1, 1.0], ["9", 8.0, 1, 1.0], ["0", 9.0, 1, 1.0],
	["Tab", 0.0, 2, 1.5], ["Q", 1.5, 2, 1.0], ["W", 2.5, 2, 1.0], ["E", 3.5, 2, 1.0], ["R", 4.5, 2, 1.0],
	["T", 5.5, 2, 1.0], ["Y", 6.5, 2, 1.0], ["U", 7.5, 2, 1.0], ["I", 8.5, 2, 1.0], ["O", 9.5, 2, 1.0], ["P", 10.5, 2, 1.0],
	["A", 1.75, 3, 1.0], ["S", 2.75, 3, 1.0], ["D", 3.75, 3, 1.0], ["F", 4.75, 3, 1.0], ["G", 5.75, 3, 1.0],
	["H", 6.75, 3, 1.0], ["J", 7.75, 3, 1.0], ["K", 8.75, 3, 1.0], ["L", 9.75, 3, 1.0], ["Enter", 10.75, 3, 1.75],
	["Shift", 0.0, 4, 2.25], ["Z", 2.25, 4, 1.0], ["X", 3.25, 4, 1.0], ["C", 4.25, 4, 1.0], ["V", 5.25, 4, 1.0],
	["B", 6.25, 4, 1.0], ["N", 7.25, 4, 1.0], ["M", 8.25, 4, 1.0],
	["Espaço", 2.5, 5, 6.5],
	["Home", 13.25, 1, 1.0], ["Del", 14.25, 1, 1.0], ["↑", 13.75, 4, 1.0], ["↓", 13.75, 5, 1.0],
]
# Botões do mouse (retângulos relativos ao desenho do mouse): [id, x, y, w, h].
const MOUSE_PARTS := [["Esq", 2.0, 2.0, 32.0, 40.0], ["Dir", 36.0, 2.0, 32.0, 40.0], ["Meio", 30.0, 10.0, 10.0, 22.0], ["Roda", 0.0, 46.0, 70.0, 56.0]]

const SHORT := {"granada_luz": "granada", "sinalizador": "sinal", "armadura_sangue": "armadura", "amaldicoar_arma": "maldição", "eletrocussao": "choque", "cicatrizacao": "curar"}

static var _data: GameData

var mapped := {}  # rótulo -> ficha
var filter := "all"
var selected := ""  # tecla (ou "M:Esq") aberta na ficha
var hover := ""


func _init() -> void:
	mapped = mapa()
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(PAGE_W, PAGE_H)


# Dados de balanceamento (custos), carregados uma vez.
static func data() -> GameData:
	if _data == null:
		_data = GameData.new()
		_data.load_dir()
	return _data


# Ficha: {cat, curto, titulo, quando, texto, custo}. `cat` decide o filtro: mover, combate ou painel.
static func _ficha(cat: String, curto: String, titulo: String, quando: String, texto: String, custo := "") -> Dictionary:
	return {"cat": cat, "curto": curto, "titulo": titulo, "quando": quando, "texto": texto, "custo": custo}


# Rótulo da tecla -> ficha. Duas funções na mesma tecla viram uma ficha só, com as duas.
static func mapa() -> Dictionary:
	var m := {}
	_add(m, "Esc", _ficha("painel", "pausa", "Pausa", "Em qualquer lugar", "Abre o menu de pausa: salvar, carregar e opções. Dentro de um painel, fecha o painel."))
	_add(m, "F3", _ficha("painel", "perf.", "Desempenho", "Em qualquer lugar", "Mostra na tela os quadros por segundo e outros números técnicos."))
	_add(m, "B", _ficha("painel", "mochila", "Mochila", "Fora de falas", "Abre o inventário compartilhado e o equipamento de cada personagem. O tempo para enquanto estiver aberta."))
	_add(m, "J", _ficha("painel", "diário", "Diário de pistas", "Fora de falas", "Mostra as pistas que o grupo examinou e o próximo objetivo. O tempo para enquanto estiver aberto."))
	_add(m, "E", _ficha("painel", "equipar", "Equipar ou usar", "Na mochila", "Equipa a arma ou o colete escolhido, ou usa o consumível."))
	_add(m, "Del", _ficha("painel", "descartar", "Descartar", "Na mochila", "Joga fora o item escolhido. Ele some e não volta."))
	_add(m, "Enter", _ficha("painel", "ligar", "Ligar pistas", "No diário", "Confirma a ligação entre duas pistas. Também avança as falas."))
	_add(m, "↑", _ficha("painel", "diário", "Subir na lista", "No diário", "Move a escolha para a pista de cima."))
	_add(m, "↓", _ficha("painel", "diário", "Descer na lista", "No diário", "Move a escolha para a pista de baixo."))
	_add(m, "L", _ficha("mover", "lanterna", "Lanterna", "À noite, explorando", "Liga e desliga a lanterna do líder. No diário, L abre o modo de ligar pistas."))
	_add(m, "Tab", _ficha("mover", "trocar", "Trocar de personagem", "Explorar e combate", "Passa o controle para o próximo do grupo. Os outros seguem o controlado."))
	for n in ["1", "2", "3"]:
		_add(m, n, _ficha("mover", "escolher", "Escolher o personagem " + n, "Explorar e combate", "Passa o controle direto para o personagem " + n + " do grupo."))
	_add(m, "C", _ficha("mover", "agachar", "Agachar", "Explorar; em combate na sua vez", "Alterna agachado. Agachado, os inimigos só percebem o grupo na metade da distância, e um ataque sem alerta ganha bônus."))
	_add(m, "Home", _ficha("combate", "câmera", "Recentrar a câmera", "Combate", "Traz a câmera de volta ao grupo depois de arrastá-la com o botão do meio."))
	var rules := data()
	_add(m, "Espaço", _ficha("combate", "passar turno", "Passar o turno", "Combate", "Encerra o turno do personagem controlado. Fora do combate, avança as falas."))
	_add(m, "D", _ficha("combate", "atrasar", "Atrasar", "Combate", "Adia a vez do personagem para mais tarde na mesma rodada."))
	_add(m, "Q", _ficha("combate", "trocar arma", "Trocar de arma", "Combate", "Alterna entre a arma principal e a reserva.", _pa(rules.rule("custo_trocar_arma_pa"))))
	_add(m, "G", _ficha("combate", "recarga", "Recarregar", "Combate", "Enche o pente com a munição da mochila.", _pa(rules.rule("custo_recarga_pa"))))
	_add(m, "F", _ficha("combate", "vigia", "Vigilância", "Combate", "Fica de guarda e atira no primeiro inimigo que se mover dentro do cone.", "mesmo PA do ataque da arma"))
	_add(m, "Shift", _ficha("combate", "acelerar", "Acelerar o turno inimigo", "Combate", "Segure durante a jogada dos inimigos para vê-la mais rápido."))
	var item_keys := Atalhos.ITEM_KEYS
	var ritual_keys := Atalhos.RITUAL_KEYS
	var item_tips := Atalhos.ITEM_TIPS
	for iid in item_keys:
		var item := rules.get_entry("itens", iid)
		var custo := _pa(item.get("custo_pa_combate"))
		_add(m, item_keys[iid], _ficha("combate", SHORT.get(iid, str(item.get("nome", iid)).to_lower()), str(item.get("nome", iid)), "Combate, na sua vez", _cap(str(item_tips.get(iid, "item de uso em combate"))) + ".", custo))
	for rid in ritual_keys:
		var r := rules.get_entry("rituais", rid)
		var curto: String = SHORT.get(rid, str(r.get("nome", rid)).to_lower())
		_add(m, ritual_keys[rid], _ficha("combate", curto, str(r.get("nome", rid)), "Combate · só o Ocultista", str(r.get("descricao", "")), "%s · %s SAN" % [_pa(r.get("custo_pa")), str(r.get("custo_san", "?"))]))
	m["M:Esq"] = _ficha("mover", "", "Botão esquerdo", "Explorar e combate", "Move o grupo, examina objetos e abre portas. Em combate move, ataca o inimigo sob o cursor ou escolhe o alvo. Clicar num retrato troca de personagem.")
	m["M:Dir"] = _ficha("painel", "", "Botão direito", "Menus", "Volta um passo nos menus e painéis.")
	m["M:Meio"] = _ficha("combate", "", "Botão do meio", "Combate", "Arraste para mover a câmera. Clicar (ou Home) recentra.")
	m["M:Roda"] = _ficha("mover", "", "Roda do mouse", "Em qualquer lugar", "Aproxima e afasta a câmera.")
	return m


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


static func _pa(v: Variant) -> String:
	return "%s PA" % (str(int(v)) if v != null else "?")


static func _add(m: Dictionary, key: String, f: Dictionary) -> void:
	if not m.has(key):
		m[key] = f
		return
	var old: Dictionary = m[key]  # a mesma tecla serve a duas coisas: junta as duas na ficha
	m[key] = _ficha(old["cat"], str(old["curto"]) + " · " + str(f["curto"]), str(old["titulo"]) + " / " + str(f["titulo"]), str(old["quando"]) + " · " + str(f["quando"]),
		str(old["texto"]) + " | " + str(f["texto"]), str(old["custo"]) + (" · " if old["custo"] != "" and f["custo"] != "" else "") + str(f["custo"]))


func _kx(col: float) -> float:
	return PAD + col * (KEY + GAP)


func _ky(row: int) -> float:
	return TOP + row * (KEY + GAP) + (8.0 if row > 0 else 0.0)


func _key_rect(k: Array) -> Rect2:
	return Rect2(_kx(k[1]), _ky(k[2]), k[3] * KEY + (k[3] - 1.0) * GAP, KEY)


func _mouse_origin() -> Vector2:
	return Vector2(size.x - 120.0, TOP + 4.0)


func _filter_rect(i: int) -> Rect2:
	var x := size.x - PAD - 4.0 * 78.0 + i * 78.0
	return Rect2(x, 8.0, 74.0, 22.0)


func _card_rect() -> Rect2:
	return Rect2(PAD, size.y - CARD_H - 14.0, size.x - PAD * 2.0, CARD_H)


func _active(id: String) -> bool:
	if not mapped.has(id):
		return false
	return filter == "all" or mapped[id]["cat"] == filter or (filter == "combate" and mapped[id]["cat"] == "uso")


# Quem está sob o mouse: rótulo de tecla ou "M:parte".
func _target_at(p: Vector2) -> String:
	for k in LAYOUT:
		if _key_rect(k).has_point(p):
			return k[0]
	var o := _mouse_origin() + Vector2(25, 0)
	for part in MOUSE_PARTS:
		if Rect2(o + Vector2(part[1], part[2]), Vector2(part[3], part[4])).has_point(p) and part[0] != "Roda":
			return "M:" + part[0]
	if Rect2(o, Vector2(70, 110)).has_point(p):
		return "M:Roda" if Rect2(o + Vector2(0, 46), Vector2(70, 64)).has_point(p) else ""
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var t := _target_at(event.position)
		if t != hover:
			hover = t
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			voltar.emit()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in FILTERS.size():
			if _filter_rect(i).has_point(event.position):
				filter = FILTERS[i][0]
				queue_redraw()
				return
		var t := _target_at(event.position)
		if t != "":
			selected = t
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != "":
		hover = ""
		queue_redraw()


func _shown() -> String:
	return hover if hover != "" and mapped.has(hover) else selected


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_rect(Rect2(Vector2.ZERO, size), BRONZE, false, 2.0)
	draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), Color(BRONZE, 0.35), false, 1.0)  # filete interno de caderno
	draw_string(FONT, Vector2(PAD, 28.0), "CADERNO DE CAMPO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
	draw_string(FONT, Vector2(PAD, 44.0), "controles do jogo · passe o mouse numa tecla", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
	for i in FILTERS.size():
		var r := _filter_rect(i)
		var on: bool = FILTERS[i][0] == filter
		if on:
			draw_rect(r, Color(PAPER, 0.12))
		draw_rect(r, Color(PAPER if on else BRONZE, 0.9 if on else 0.7), false, 1.0)
		draw_string(FONT, r.position + Vector2(0, 15.0), FILTERS[i][1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, PAPER if on else MUTED)
	for k in LAYOUT:
		_draw_key(k)
	_draw_mouse()
	_draw_card()


func _draw_key(k: Array) -> void:
	var label: String = k[0]
	var r := _key_rect(k)
	var used := mapped.has(label)
	var on := used and _active(label)
	var picked: bool = label == _shown()
	var edge := BLOOD.lightened(0.15) if picked else (PAPER if on else (FAINT if used else Color(FAINT, 0.55)))
	draw_rect(r, Color(PAPER, 0.22) if picked else (Color(PAPER, 0.07) if on else Color(0, 0, 0, 0.25)))
	draw_rect(r, edge, false, 1.5 if picked else 1.0)
	if on:
		draw_rect(Rect2(r.position + Vector2(3, KEY - 4.0), Vector2(r.size.x - 6.0, 1.0)), Color(PAPER, 0.35))  # sublinhado de tecla em uso
	var big := label.length() <= 2 or label == "Home"
	var ink := PAPER if on else (FAINT if used else Color(FAINT, 0.8))
	draw_string(FONT, r.position + Vector2(0, 14.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11 if big else 9, ink)
	if used:
		var lines := _wrap(str(mapped[label]["curto"]), r.size.x + 2.0, 7)
		for i in mini(lines.size(), 2):
			draw_string(FONT, r.position + Vector2(-1.0, 22.0 + i * 8.0), lines[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 2.0, 7, ink if on else FAINT)


static func _wrap(text: String, w: float, fsize: int) -> Array:
	var lines: Array = []
	var cur := ""
	for word in text.split(" "):
		var next: String = word if cur == "" else cur + " " + word
		if FONT.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > w and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = next
	lines.append(cur)
	return lines


func _draw_mouse() -> void:
	var o := _mouse_origin() + Vector2(25, 0)
	var body := Rect2(o, Vector2(70, 110))
	draw_rect(body, Color(0, 0, 0, 0.3))
	draw_rect(body, Color(PAPER, 0.5), false, 1.2)
	for part in MOUSE_PARTS:
		if part[0] == "Roda":
			continue
		var id: String = "M:" + part[0]
		var r := Rect2(o + Vector2(part[1], part[2]), Vector2(part[3], part[4]))
		var on := _active(id)
		var picked: bool = id == _shown()
		draw_rect(r, Color(PAPER, 0.25) if picked else (Color(PAPER, 0.1) if on else Color(0, 0, 0, 0.2)))
		draw_rect(r, BLOOD.lightened(0.15) if picked else (PAPER if on else FAINT), false, 1.0)
	draw_line(o + Vector2(0, 44), o + Vector2(70, 44), Color(PAPER, 0.35), 1.0)
	draw_string(FONT, o + Vector2(2, 26), "esq.", HORIZONTAL_ALIGNMENT_CENTER, 32, 8, PAPER if _active("M:Esq") else FAINT)
	draw_string(FONT, o + Vector2(36, 26), "dir.", HORIZONTAL_ALIGNMENT_CENTER, 32, 8, PAPER if _active("M:Dir") else FAINT)
	draw_string(FONT, o + Vector2(0, 60), "mover · atacar · menus", HORIZONTAL_ALIGNMENT_CENTER, 70, 6, MUTED)
	var roda := "M:Roda" == _shown()
	var rr := Rect2(o + Vector2(0, 68), Vector2(70, 38))
	draw_rect(rr, Color(PAPER, 0.2) if roda else Color(0, 0, 0, 0.0))
	draw_string(FONT, o + Vector2(0, 80), "roda: zoom", HORIZONTAL_ALIGNMENT_CENTER, 70, 8, PAPER if _active("M:Roda") else FAINT)
	draw_string(FONT, o + Vector2(0, 92), "meio: câmera", HORIZONTAL_ALIGNMENT_CENTER, 70, 8, PAPER if _active("M:Meio") else FAINT)
	draw_string(FONT, o + Vector2(0, 124), "MOUSE", HORIZONTAL_ALIGNMENT_CENTER, 70, 8, MUTED)


# Ficha no pé da página: a tecla grande, o nome, quando vale, o custo e o texto.
func _draw_card() -> void:
	var r := _card_rect()
	draw_rect(r, Color(PAPER, 0.045))
	draw_rect(r, Color(BRONZE, 0.9), false, 1.0)
	var id: String = _shown()
	if id == "" or not mapped.has(id):
		draw_string(FONT, r.position + Vector2(20, 40), "Passe o mouse numa tecla para ver o que ela faz.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
		draw_string(FONT, r.position + Vector2(20, 62), "Teclas acesas estão em uso; as apagadas não fazem nada. Use os filtros para ver só explorar, combate ou painéis.", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0, 9, FAINT)
		draw_string(FONT, r.position + Vector2(20, 90), "Só leitura: as teclas ainda não podem ser trocadas.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FAINT)
		return
	var f: Dictionary = mapped[id]
	var cap := Rect2(r.position + Vector2(16, 16), Vector2(64, 64))
	draw_rect(cap, Color(PAPER, 0.1))
	draw_rect(cap, PAPER, false, 1.5)
	draw_rect(Rect2(cap.position + Vector2(5, 59), Vector2(54, 1)), Color(PAPER, 0.4))
	var cap_text := id.trim_prefix("M:") if id.begins_with("M:") else id
	draw_string(FONT, cap.position + Vector2(0, 40), cap_text, HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 22 if cap_text.length() <= 2 else 13, PAPER)
	if id.begins_with("M:"):
		draw_string(FONT, cap.position + Vector2(0, 54), "mouse", HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, 8, MUTED)
	var x := r.position.x + 96.0
	draw_string(FONT, Vector2(x, r.position.y + 28.0), str(f["titulo"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 120.0, 15, GOLD)
	var tag_y := r.position.y + 44.0
	var tx := x
	for tag in [["QUANDO", str(f["quando"])], ["CUSTO", str(f["custo"])]]:
		if tag[1] == "":
			continue
		var s: String = tag[0] + "  " + tag[1]
		var w := FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 14.0
		draw_rect(Rect2(tx, tag_y - 10.0, w, 15.0), Color(BLOOD, 0.18) if tag[0] == "CUSTO" else Color(PAPER, 0.08))
		draw_rect(Rect2(tx, tag_y - 10.0, w, 15.0), Color(BLOOD.lightened(0.2), 0.8) if tag[0] == "CUSTO" else Color(BRONZE, 0.9), false, 1.0)
		draw_string(FONT, Vector2(tx + 7.0, tag_y + 1.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, PAPER)
		tx += w + 8.0
	var lines := _wrap(str(f["texto"]), r.size.x - 120.0, 10)
	for i in mini(lines.size(), 3):
		draw_string(FONT, Vector2(x, r.position.y + 66.0 + i * 13.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PAPER)
