class_name Destaque3D
extends RefCounted
# Brilho dourado e borda branca nas malhas de um objeto examinável (modelo B do Léo, 13/11). Usado pelo Cenario3D
# (lugares da missão 1) e pelo Parque3D.

const BORDA_ALFA := 0.6  # opacidade máxima da borda branca (com o mouse em cima)

var _decalques := {}  # "png|caixa" -> MeshInstance3D do contorno pintado
var _destaques := {}  # chave -> {"nos": Array[MeshInstance3D], "contorno": Array, "brilho": Material}


# Malhas visíveis, dentro de `raizes`, escolhidas pelo "destaque" da pista (`spec`): "nomes" (lista de nomes das malhas, vale
# em qualquer lugar) ou o retângulo no chão a até "raio" m do ponto `p` (px / 64), com "mat" no material e tamanho no chão
# menor que "max" (padrão 6 m); "sem" lista marcas de material a ignorar (ex.: "unlit", "add").
func selecionar(raizes: Array, p: Vector3, spec: Dictionary) -> Array:
	var r: Array = []
	var nomes: Array = spec.get("nomes", [])
	var raio := float(spec.get("raio", 0.0))
	var maximo := float(spec.get("max", 6.0))
	var mat_marca := str(spec.get("mat", ""))
	if spec.has("decalque"):  # marcas pintadas no chão, sem malha própria: um contorno pronto (PNG) sobre o chão
		var dec := _decalque(raizes[0] as Node, spec["decalque"])
		return [dec] if dec != null else []
	for no in raizes:
		for m in (no as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree() or r.has(mi):
				continue
			if not nomes.is_empty():
				if nomes.has(str(mi.name)):
					var parte := _parte_na_caixa(mi, spec["caixa"]) if spec.has("caixa") else mi
					if parte != null:
						r.append(parte)
				continue
			var bb: AABB = mi.global_transform * mi.get_aabb()
			var d := Vector2(maxf(maxf(bb.position.x - p.x, 0.0), p.x - bb.end.x), maxf(maxf(bb.position.z - p.z, 0.0), p.z - bb.end.z)).length()
			if d > raio or bb.size.x >= maximo or bb.size.z >= maximo:
				continue
			var mt := mi.mesh.surface_get_material(0) if mi.mesh.get_surface_count() > 0 else null
			var nome_mat := mt.resource_name if mt != null else ""
			if mat_marca != "" and not nome_mat.contains(mat_marca):
				continue
			var excluir := false
			for x in spec.get("sem", []):
				excluir = excluir or nome_mat.contains(str(x))
			if excluir:
				continue
			r.append(mi)
	return r


# Plano no chão com o PNG do contorno. {"png": "res://...", "min": [x, z], "max": [x, z], "y": 0.03} em metros do mundo 3D.
func _decalque(raiz: Node, d: Dictionary) -> MeshInstance3D:
	var chave := "%s|%s|%s" % [d["png"], d["min"], d["max"]]
	if _decalques.has(chave) and is_instance_valid(_decalques[chave]):
		return _decalques[chave]
	var tex := load(str(d["png"])) as Texture2D
	if tex == null:
		return null
	var lo: Array = d["min"]
	var hi: Array = d["max"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.render_priority = 12
	m.disable_fog = true
	m.disable_receive_shadows = true
	var plano := PlaneMesh.new()
	plano.size = Vector2(float(hi[0]) - float(lo[0]), float(hi[1]) - float(lo[1]))
	var mi := MeshInstance3D.new()
	mi.mesh = plano
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.set_meta("decalque", true)
	raiz.add_child(mi)
	mi.global_position = Vector3((float(lo[0]) + float(hi[0])) * 0.5, float(d.get("y", 0.03)), (float(lo[1]) + float(hi[1])) * 0.5)
	_decalques[chave] = mi
	return mi


# Malha fundida com vários objetos (os bancos do parque): copia só os triângulos cujo centro cai na caixa do mundo
# {"min": [x, y, z], "max": [x, y, z]}, numa malha escondida ao lado da original. null se a caixa não pegar nada.
func _parte_na_caixa(mi: MeshInstance3D, caixa: Dictionary) -> MeshInstance3D:
	var lo: Array = caixa["min"]
	var hi: Array = caixa["max"]
	var box := AABB(Vector3(lo[0], lo[1], lo[2]), Vector3(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
	var novo := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		else:
			idx.resize(vs.size())
			for i in vs.size():
				idx[i] = i
		var fica := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var c := (vs[idx[t]] + vs[idx[t + 1]] + vs[idx[t + 2]]) / 3.0
			if box.has_point(mi.global_transform * c):
				fica.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
		if fica.is_empty():
			continue
		arr[Mesh.ARRAY_INDEX] = fica
		novo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if novo.get_surface_count() == 0:
		return null
	var parte := MeshInstance3D.new()
	parte.mesh = novo
	parte.visible = false
	mi.get_parent().add_child(parte)
	parte.transform = mi.transform
	return parte


# `contorno` e `brilho` vão de 0 a 1. Cria as cópias na primeira vez e depois só muda a opacidade.
func aplicar(pai: Node, chave: String, malhas: Array, contorno: float, brilho: float) -> void:
	if not _destaques.has(chave):
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.cull_mode = BaseMaterial3D.CULL_FRONT
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # borda translúcida (Léo, 13/11: fina e suave, só para indicar o clique)
		cm.render_priority = 12
		cm.disable_fog = true
		var cp := cm.duplicate() as StandardMaterial3D
		cp.cull_mode = BaseMaterial3D.CULL_DISABLED
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.render_priority = 12  # depois do quadro da névoa, como os outros materiais com alfa
		bm.disable_fog = true
		bm.disable_receive_shadows = true
		var nos: Array = []
		for m in malhas:
			var mi := m as MeshInstance3D
			if mi.has_meta("decalque"):
				mi.set_meta("tipo", "decalque")
				nos.append(mi)
				continue
			var bb: AABB = mi.global_transform * mi.get_aabb()
			var plano := bb.size.y < 0.05
			var c := bb.get_center()
			var borda := 0.022  # 2,2 cm para cada lado (era 5 cm)
			var s := Vector3(1.0 + 2.0 * borda / maxf(bb.size.x, 0.05), 1.0 if plano else 1.0 + 2.0 * borda / maxf(bb.size.y, 0.05), 1.0 + 2.0 * borda / maxf(bb.size.z, 0.05))
			var xf := Transform3D(Basis.from_scale(s), c) * Transform3D(Basis.IDENTITY, -c) * mi.global_transform
			var o := MeshInstance3D.new()
			o.mesh = mi.mesh
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			o.material_override = cp if plano else cm
			pai.add_child(o)
			o.global_transform = xf
			if plano:
				o.global_position.y -= 0.004
			o.set_meta("tipo", "contorno")
			var g := MeshInstance3D.new()
			g.mesh = mi.mesh
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.material_override = bm
			pai.add_child(g)
			g.global_transform = mi.global_transform
			g.global_position.y += 0.006 if plano else 0.0
			g.set_meta("tipo", "brilho")
			nos.append(o)
			nos.append(g)
		_destaques[chave] = {"nos": nos, "contorno": [cm, cp], "brilho": bm}
	var d: Dictionary = _destaques[chave]
	for mat in d["contorno"]:
		(mat as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 1.0, contorno * BORDA_ALFA)
	(d["brilho"] as StandardMaterial3D).albedo_color = Color(0.95, 0.72, 0.36, brilho * 0.35)
	for n in d["nos"]:
		var t := str(n.get_meta("tipo"))
		if t == "decalque":  # contorno pintado: suave parado, mais firme com o mouse em cima
			var a := clampf(contorno * BORDA_ALFA + brilho * 0.5, 0.0, BORDA_ALFA)
			((n as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 1.0, a)
			(n as Node3D).visible = a > 0.01
			continue
		(n as Node3D).visible = (t == "contorno" and contorno > 0.01) or (t == "brilho" and brilho > 0.01)


# Tira da cena os triângulos cujo centro cai numa caixa (coordenadas do mundo 3D), sem mexer no glb: serve para
# limpar a folhagem que tapa um objeto (o arbusto na frente do tronco). `excluir` poupa malhas pelo nome.
# Caixa: {"min": [x, y, z], "max": [x, y, z], "excluir": ["Mesh3", ...]}.
static func recortar(raiz: Node, caixas: Array) -> void:
	for caixa in caixas:
		var lo: Array = caixa["min"]
		var hi: Array = caixa["max"]
		var box := AABB(Vector3(lo[0], lo[1], lo[2]), Vector3(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))
		var poupar: Array = caixa.get("excluir", [])
		for n in raiz.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or poupar.has(String(mi.name)) or mi.get_parent() is Skeleton3D:
				continue
			if not (mi.global_transform * mi.get_aabb()).intersects(box):
				continue
			var novo := ArrayMesh.new()
			var tirou := false
			for s in mi.mesh.get_surface_count():
				var arr: Array = mi.mesh.surface_get_arrays(s)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array
				if arr[Mesh.ARRAY_INDEX] != null:
					idx = arr[Mesh.ARRAY_INDEX]
				else:
					idx = PackedInt32Array()
					idx.resize(vs.size())
					for i in vs.size():
						idx[i] = i
				var fica := PackedInt32Array()
				for t in range(0, idx.size() - 2, 3):
					var c := (vs[idx[t]] + vs[idx[t + 1]] + vs[idx[t + 2]]) / 3.0
					if box.has_point(mi.global_transform * c):
						tirou = true
					else:
						fica.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
				arr[Mesh.ARRAY_INDEX] = fica
				novo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				novo.surface_set_material(s, mi.mesh.surface_get_material(s))
			if tirou:
				mi.mesh = novo
