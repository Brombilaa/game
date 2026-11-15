class_name LuzFurtividade
extends Node
# Luz e furtividade (modelo C do dossiê V-08; sugestão 12 da revisão da missão 1, 15/11/2026).
# Nas cenas noturnas, mede quanta luz cai sobre cada agente e grava em `Combatant.iluminacao` (0 = sombra,
# 1 = luz cheia). CombatRules.perception_range usa esse valor: na sombra o inimigo percebe pela metade,
# na luz uma vez e meia (fatores em combat.json). A lanterna acesa denuncia quem a carrega.
# De dia a luz não conta: iluminacao fica -1.
# Criada pela LuzDinamica (luz_dinamica.gd), que já conhece as luzes do cenário e a lanterna.

const LUZ_CHEIA := 0.8  # soma de luz (energia × queda) que já conta como luz cheia (provisório, medido na fazenda)
const LUZ_MINIMA := 0.12  # abaixo disso é sombra total
const ALTURA_PEITO := 1.0  # mede a luz à altura do peito, em metros acima do chão
const ESCONDIDO_ATE := 0.34  # estados para o indicador: abaixo disso ESCONDIDO, acima de VISIVEL_DESDE visível
const VISIVEL_DESDE := 0.66

enum Estado { DIA, ESCONDIDO, PENUMBRA, VISIVEL }

var luz: LuzDinamica


# Queda de uma luz omni no Godot 4 (mesma fórmula do renderizador): (1 - (d/r)^4)^2 · d^-q.
static func queda(d: float, alcance: float, q: float) -> float:
	var nd := d / alcance
	nd = maxf(1.0 - nd * nd * nd * nd, 0.0)
	return nd * nd * pow(maxf(d, 0.5), -q)


# Luz num ponto, de 0 a 1, somando as luzes acesas do cenário (sem paredes: provisório).
static func luz_no_ponto(p: Vector3, luzes: Array, energias: Dictionary) -> float:
	var soma := 0.0
	for o in luzes:
		var l := o as OmniLight3D
		if l == null or not is_instance_valid(l) or not l.is_visible_in_tree():
			continue
		var d := l.global_position.distance_to(p)
		if d >= l.omni_range:
			continue
		soma += float(energias.get(l, l.light_energy)) * queda(d, l.omni_range, l.omni_attenuation)
	return clampf((soma - LUZ_MINIMA) / (LUZ_CHEIA - LUZ_MINIMA), 0.0, 1.0)


static func estado_de(i: float) -> Estado:
	if i < 0.0:
		return Estado.DIA
	if i < ESCONDIDO_ATE:
		return Estado.ESCONDIDO
	return Estado.VISIVEL if i >= VISIVEL_DESDE else Estado.PENUMBRA


func _process(_delta: float) -> void:
	if luz == null or not luz._pronto:
		return
	var host := luz.host
	var grupo: Array = host.get("party") if host.get("party") != null else []
	for m in grupo:
		medir(m as Combatant)


# Grava a iluminação de um agente: luzes do cenário, mais a lanterna (quem carrega fica sempre na luz;
# quem está dentro do cone, na proporção da distância).
func medir(u: Combatant) -> void:
	if not luz.noturno:
		u.iluminacao = -1.0
		return
	var host := luz.host
	var chao: float = host._altura(u.pos) if host.has_method("_altura") else 0.0
	var p := Vector3(u.pos.x / 64.0, chao + ALTURA_PEITO, u.pos.y / 64.0)
	var i := luz_no_ponto(p, luz._omnis, luz._base)
	if lanterna_acesa():
		if u == host.player:
			i = 1.0
		else:
			i = maxf(i, 0.7 * _no_cone(p))  # o feixe ilumina quem está à frente, mas não tanto quanto quem segura
	u.iluminacao = i


func lanterna_acesa() -> bool:
	return luz.ligada and luz._spot != null and luz._spot.visible


func _no_cone(p: Vector3) -> float:
	var s := luz._spot
	var v := p - s.global_position
	var d := v.length()
	if d >= s.spot_range or d < 0.01:
		return 0.0
	var frente := -s.global_transform.basis.z
	if rad_to_deg(frente.angle_to(v / d)) > s.spot_angle:
		return 0.0
	return 1.0 - d / s.spot_range


# Estado do líder, para o indicador na tela.
func estado_lider() -> Estado:
	var lider: Combatant = luz.host.player
	return estado_de(lider.iluminacao)


# Indicador (modelo B, marca no chão): anel sob os pés de cada agente. Tracejado e frio na sombra,
# cheio e âmbar com brilho na luz, intermediário na penumbra. O círculo vermelho de percepção dos
# inimigos (parque.gd) já cresce e encolhe com a luz, pela própria regra.
const ANEL_RAIO := 22.0  # px do mundo
const COR_ESCONDIDO := Color(0.59, 0.67, 0.82)
const COR_VISIVEL := Color(0.91, 0.64, 0.29)


func desenhar(c: CanvasItem) -> void:
	for m in luz.host.party:
		var u := m as Combatant
		if u.is_alive():
			_anel(c, u)


func _anel(c: CanvasItem, u: Combatant) -> void:
	var e := estado_de(u.iluminacao)
	if e == Estado.DIA:
		return
	var pts := PackedVector2Array()
	for i in 49:
		pts.append(luz.host._iso(u.pos + Vector2.from_angle(TAU * i / 48.0) * ANEL_RAIO))
	match e:
		Estado.ESCONDIDO:
			for i in range(0, 48, 4):  # tracejado: 12 traços
				c.draw_polyline(pts.slice(i, i + 3), Color(COR_ESCONDIDO, 0.8), 1.0)
		Estado.PENUMBRA:
			c.draw_polyline(pts, Color(COR_ESCONDIDO.lerp(COR_VISIVEL, 0.5), 0.7), 1.0)
		Estado.VISIVEL:
			c.draw_polyline(pts, Color(COR_VISIVEL, 0.18), 4.0)  # brilho
			c.draw_polyline(pts, Color(COR_VISIVEL, 0.95), 1.5)
