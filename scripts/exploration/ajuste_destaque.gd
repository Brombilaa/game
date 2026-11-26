class_name AjusteDestaque
extends Node
# Ferramenta de ajuste das caixas de borda (F9). Algumas pistas da delegacia não têm malha própria (o objeto é parte da
# parede ou do balcão); a borda delas vai numa caixa invisível. Aqui o Léo vê cada caixa em vermelho, move, redimensiona e
# grava. Os valores ficam em data/ajustes_destaque.json e valem para o jogo todo; a borda nova aparece ao reentrar na cena.
#
#   F9 liga/desliga     , e . trocam de pista     setas movem (x e z)     PgUp/PgDn sobem e descem
#   Z/X largura   C/V profundidade   B/N altura da caixa     Shift = passo grande     F10 grava

const ARQUIVO := "res://data/ajustes_destaque.json"
const PASSO := 0.05

var sala: Node  # o lugar (parque.gd)
var ativo := false
var ids: Array = []
var atual := 0
var valores := {}  # cid -> {"dx", "dz", "y", "tam": [l, a, p]}
var rotulo: Label
var aviso := ""


static func carregar() -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO):
		return {}
	var f := FileAccess.open(ARQUIVO, FileAccess.READ)
	var j = JSON.parse_string(f.get_as_text())
	return j if j is Dictionary else {}


# `destaque` da pista com o ajuste gravado por cima (só vale para destaque "proxy").
static func com_ajuste(destaque: Dictionary, local: String, cid: String) -> Dictionary:
	if not destaque.has("proxy"):
		return destaque
	var aj: Dictionary = carregar().get(local, {}).get(cid, {})
	if aj.is_empty():
		return destaque
	var px: Dictionary = (destaque["proxy"] as Dictionary).duplicate()
	for k in aj:
		px[k] = aj[k]
	return {"proxy": px}


func _ready() -> void:
	sala = get_parent()
	var camada := CanvasLayer.new()
	camada.layer = 90
	add_child(camada)
	rotulo = Label.new()
	rotulo.position = Vector2(90, 6)
	rotulo.add_theme_font_size_override("font_size", 8)
	rotulo.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	rotulo.add_theme_constant_override("outline_size", 4)
	rotulo.visible = false
	camada.add_child(rotulo)


func _unhandled_key_input(ev: InputEvent) -> void:
	var e := ev as InputEventKey
	if e == null or not e.pressed:
		return
	if e.keycode == KEY_F9:
		_alternar()
		get_viewport().set_input_as_handled()
		return
	if not ativo:
		return
	var passo := PASSO * (5.0 if e.shift_pressed else 1.0)
	var id: String = ids[atual]
	var v: Dictionary = valores[id]
	var t: Array = v["tam"]
	match e.keycode:
		KEY_COMMA: _ir(-1)
		KEY_PERIOD: _ir(1)
		KEY_LEFT: v["dx"] = float(v["dx"]) - passo
		KEY_RIGHT: v["dx"] = float(v["dx"]) + passo
		KEY_UP: v["dz"] = float(v["dz"]) - passo
		KEY_DOWN: v["dz"] = float(v["dz"]) + passo
		KEY_PAGEUP: v["y"] = float(v["y"]) + passo
		KEY_PAGEDOWN: v["y"] = float(v["y"]) - passo
		KEY_X: t[0] = float(t[0]) + passo
		KEY_Z: t[0] = maxf(float(t[0]) - passo, 0.05)
		KEY_V: t[2] = float(t[2]) + passo
		KEY_C: t[2] = maxf(float(t[2]) - passo, 0.05)
		KEY_N: t[1] = float(t[1]) + passo
		KEY_B: t[1] = maxf(float(t[1]) - passo, 0.05)
		KEY_F10: _gravar()
		_: return
	_aplicar(id)
	_texto()
	get_viewport().set_input_as_handled()


func _alternar() -> void:
	ativo = not ativo
	if ativo:
		ids.clear()
		valores.clear()
		for cid in sala.scenario.clues:
			var d: Dictionary = AjusteDestaque.com_ajuste(sala.scenario.clues[cid].get("destaque", {}), sala._scenario_id(), cid)
			if not d.has("proxy"):
				continue
			var px: Dictionary = d["proxy"]
			ids.append(cid)
			valores[cid] = {"dx": float(px.get("dx", 0.0)), "dz": float(px.get("dz", 0.0)), "y": float(px["y"]), "tam": (px["tam"] as Array).duplicate()}
			_aplicar(cid)
		atual = 0
		if ids.is_empty():
			ativo = false
			return
		_ir(0)
	else:
		for cid in ids:
			_caixa(cid).visible = false
		rotulo.visible = false


func _ir(passo: int) -> void:
	atual = posmod(atual + passo, ids.size())
	var c: Dictionary = sala.scenario.clues[ids[atual]]
	sala.player.pos = c.pos + Vector2(0, 90)  # o líder vai para perto: a câmera segue
	for cid in ids:
		_aplicar(cid)
	_texto()


func _caixa(cid: String) -> MeshInstance3D:
	return sala._malhas_pista(cid)[0] as MeshInstance3D


func _aplicar(cid: String) -> void:
	var v: Dictionary = valores[cid]
	var c: Dictionary = sala.scenario.clues[cid]
	var cx := _caixa(cid)
	var t: Array = v["tam"]
	(cx.mesh as BoxMesh).size = Vector3(float(t[0]), float(t[1]), float(t[2]))
	cx.global_position = Vector3(c.pos.x / 64.0 + float(v["dx"]), float(v["y"]), c.pos.y / 64.0 + float(v["dz"]))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 12  # depois do quadro da névoa
	m.disable_fog = true
	m.no_depth_test = true
	m.albedo_color = Color(1.0, 0.85, 0.1, 0.55) if cid == ids[atual] else Color(1.0, 0.1, 0.1, 0.25)
	cx.material_override = m
	cx.visible = true


func _texto() -> void:
	var id: String = ids[atual]
	var v: Dictionary = valores[id]
	var t: Array = v["tam"]
	rotulo.text = "AJUSTE DE BORDA   pista %d/%d: %s\n" % [atual + 1, ids.size(), id]
	rotulo.text += "x %+.2f   z %+.2f   altura %.2f   caixa %.2f x %.2f x %.2f (largura x altura x profundidade)\n" % [v["dx"], v["dz"], v["y"], t[0], t[1], t[2]]
	rotulo.text += ", e . trocam de pista | setas movem | PgUp/PgDn sobem e descem | Shift = passo grande\n"
	rotulo.text += "Z/X largura | C/V profundidade | B/N altura da caixa | F10 grava | F9 sai\n"
	rotulo.text += aviso
	rotulo.visible = true


func _gravar() -> void:
	var tudo := carregar()
	var local: String = sala._scenario_id()
	var doLocal: Dictionary = tudo.get(local, {})
	for cid in ids:
		var v: Dictionary = valores[cid]
		doLocal[cid] = {"dx": snappedf(float(v["dx"]), 0.01), "dz": snappedf(float(v["dz"]), 0.01), "y": snappedf(float(v["y"]), 0.01), "tam": [snappedf(float(v["tam"][0]), 0.01), snappedf(float(v["tam"][1]), 0.01), snappedf(float(v["tam"][2]), 0.01)]}
	tudo[local] = doLocal
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f == null:
		aviso = "NÃO GRAVOU: a pasta do jogo é só leitura (abra o projeto pelo editor da Godot)."
		return
	f.store_string(JSON.stringify(tudo, "  "))
	f.close()
	aviso = "Gravado em " + ProjectSettings.globalize_path(ARQUIVO)
