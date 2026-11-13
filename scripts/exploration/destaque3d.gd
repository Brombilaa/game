class_name Destaque3D
extends RefCounted
# Brilho dourado e borda branca nas malhas de um objeto examinável (modelo B do Léo, 13/11). Usado pelo Cenario3D
# (lugares da missão 1) e pelo Parque3D.

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
	for no in raizes:
		for m in (no as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree() or r.has(mi):
				continue
			if not nomes.is_empty():
				if nomes.has(str(mi.name)):
					r.append(mi)
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


# `contorno` e `brilho` vão de 0 a 1. Cria as cópias na primeira vez e depois só muda a opacidade.
func aplicar(pai: Node, chave: String, malhas: Array, contorno: float, brilho: float) -> void:
	if not _destaques.has(chave):
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.cull_mode = BaseMaterial3D.CULL_FRONT
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
			var bb: AABB = mi.global_transform * mi.get_aabb()
			var plano := bb.size.y < 0.05
			var c := bb.get_center()
			var borda := 0.05
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
		(mat as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 1.0, contorno)
	(d["brilho"] as StandardMaterial3D).albedo_color = Color(0.95, 0.72, 0.36, brilho * 0.6)
	for n in d["nos"]:
		var t := str(n.get_meta("tipo"))
		(n as Node3D).visible = (t == "contorno" and contorno > 0.01) or (t == "brilho" and brilho > 0.01)
