class_name CombatFx
extends RefCounted
# Animação de combate, modelo B (Léo, 01/11/2026). Só estado e tempo: o desenho fica na sala.
# O ataque já foi resolvido pelas regras; aqui ele é "encenado": mira de 0,6 s e, no impacto,
# clarão, parada, tremor, zoom, alvo arremessado, cápsula, fumaça, sangue, flash vermelho,
# barra de vida com rastro e número de dano. Os quadros reais de ataque entram depois (arte);
# até lá o clarão, o alvo branco e as partículas são desenhados por código.
#
# Valores do modelo B: mira 0,6 s; clarão 2 quadros; parada 90 ms; tremor 4 px (7 px no crítico);
# zoom 8% por 0,45 s; arremesso 10 px (18 px no crítico); flash vermelho 0,22 s; rastro da barra 0,6 s;
# erro: o alvo desvia 10 px.

signal impact(job: Dictionary)

const AIM_SECONDS := 0.6
const MUZZLE_SECONDS := 0.08  # 2 quadros a 25 quadros/s
const HITSTOP_SECONDS := 0.09
const SHAKE_PX := 4.0
const SHAKE_CRIT_PX := 7.0
const SHAKE_SECONDS := 0.25
const ZOOM_PULSE := 0.08
const ZOOM_SECONDS := 0.45
const KNOCK_PX := 10.0
const KNOCK_CRIT_PX := 18.0
const KNOCK_SECONDS := 0.3
const DODGE_PX := 10.0
const FLASH_RED_SECONDS := 0.22
const WHITE_SECONDS := 0.12
const TRAIL_SECONDS := 0.6
const GRAVITY := 380.0

var jobs: Array = []  # mira em andamento: {attacker, target, r, from_pv, time}
var hold_pv := {}  # Combatant -> PV mostrado enquanto o tiro ainda não bateu
var trail := {}  # Combatant -> {"from": PV antes, "time": segundos restantes}
var kicks := {}  # Combatant -> {"dir": Vector2, "dist": float, "time": float, "total": float}
var linger := {}  # Combatant abatido que ainda aparece até o arremesso terminar
var white := {}  # Combatant -> segundos restantes do alvo branco
var muzzles: Array = []  # {"pos": Vector2, "dir": Vector2, "time": float}
var particles: Array = []  # {"pos","vel","life","max","kind","size"}
var flash_red := 0.0
var flash_strength := 1.0
var shake_time := 0.0
var shake_px := 0.0
var hitstop := 0.0
var zoom_time := 0.0
var iso: Callable  # posição da sala -> posição de desenho
var rng := RandomNumberGenerator.new()


func active() -> bool:
	return not jobs.is_empty()


# Enfileira a encenação de um ataque já resolvido. `pv_before` é o PV do alvo antes do golpe.
func start(attacker: Combatant, target: Combatant, r: Dictionary, pv_before: int) -> void:
	hold_pv[target] = pv_before
	jobs.append({"attacker": attacker, "target": target, "r": r, "from_pv": pv_before, "time": 0.0})


# Progresso da mira (0 a 1) do trabalho.
static func aim_progress(job: Dictionary) -> float:
	return clampf(job["time"] / AIM_SECONDS, 0.0, 1.0)


# Abatidos que ainda estão sendo encenados (mira pendente ou arremesso em curso).
func dying() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for u in hold_pv.keys():
		if not u.is_alive():
			out.append(u)
	for u in linger.keys():
		if not u.is_alive() and not out.has(u):
			out.append(u)
	return out


func displayed_pv(u: Combatant) -> int:
	return int(hold_pv[u]) if hold_pv.has(u) else u.pv


# Deslocamento de desenho do alvo: arremesso para longe do atirador ou desvio de lado.
func offset_of(u: Combatant) -> Vector2:
	if not kicks.has(u):
		return Vector2.ZERO
	var k: Dictionary = kicks[u]
	var p: float = 1.0 - k["time"] / k["total"]
	return k["dir"] * k["dist"] * sin(PI * p)


func white_alpha(u: Combatant) -> float:
	return clampf(white.get(u, 0.0) / WHITE_SECONDS, 0.0, 1.0)


# Fator de zoom do pulso (1 = normal).
func zoom_factor() -> float:
	if zoom_time <= 0.0:
		return 1.0
	return 1.0 + ZOOM_PULSE * sin(PI * (1.0 - zoom_time / ZOOM_SECONDS))


func shake_offset() -> Vector2:
	if shake_time <= 0.0:
		return Vector2.ZERO
	var k := shake_time / SHAKE_SECONDS
	return Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_px * k


func update(delta: float) -> void:
	for d in [trail, kicks, white, linger]:
		for u in d.keys():
			if d is Dictionary:
				var v = d[u]
				if v is Dictionary:
					v["time"] -= delta
					if v["time"] <= 0.0:
						d.erase(u)
				else:
					d[u] = v - delta
					if d[u] <= 0.0:
						d.erase(u)
	for m in muzzles:
		m["time"] -= delta
	muzzles = muzzles.filter(func(m: Dictionary) -> bool: return m["time"] > 0.0)
	for p in particles:
		p["life"] -= delta
		p["vel"] += Vector2(0.0, GRAVITY if p["kind"] != "smoke" else -18.0) * delta
		p["pos"] += p["vel"] * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)
	flash_red = maxf(flash_red - delta, 0.0)
	shake_time = maxf(shake_time - delta, 0.0)
	zoom_time = maxf(zoom_time - delta, 0.0)
	# Por último: o que nasce no impacto só começa a envelhecer no próximo quadro.
	for job in jobs.duplicate():
		job["time"] += delta
		if job["time"] >= AIM_SECONDS:
			jobs.erase(job)
			_impact(job)


# O tiro bate (ou erra): dispara tudo de uma vez e avisa a sala, que cria o número de dano.
func _impact(job: Dictionary) -> void:
	var attacker: Combatant = job["attacker"]
	var target: Combatant = job["target"]
	var r: Dictionary = job["r"]
	var from := _screen(attacker.pos) + Vector2(0, -60)
	var to := _screen(target.pos) + Vector2(0, -60)
	var dir := (to - from).normalized() if to != from else Vector2.RIGHT
	hold_pv.erase(target)
	if not attacker.weapon.get("melee", false):
		muzzles.append({"pos": from + dir * 22.0, "dir": dir, "time": MUZZLE_SECONDS})
		hitstop = HITSTOP_SECONDS
		for i in 6:  # fumaça do cano
			particles.append({"pos": from + dir * 24.0, "vel": dir * rng.randf_range(8.0, 30.0) + Vector2(rng.randf_range(-8, 8), -rng.randf_range(10, 26)), "life": 0.7, "max": 0.7, "kind": "smoke", "size": rng.randf_range(3.0, 6.0)})
		particles.append({"pos": from + Vector2(0, 4), "vel": Vector2(-dir.x * 40.0, -90.0), "life": 0.6, "max": 0.6, "kind": "casing", "size": 2.0})  # cápsula
	if r.get("blocked", false):
		impact.emit(job)
		return
	if not r.get("hit", false):
		var side := dir.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
		kicks[target] = {"dir": side, "dist": DODGE_PX, "time": KNOCK_SECONDS, "total": KNOCK_SECONDS}
		impact.emit(job)
		return
	var crit: bool = r.get("crit", false)
	if not target.is_alive():
		linger[target] = KNOCK_SECONDS + 0.1
	shake_time = SHAKE_SECONDS
	shake_px = SHAKE_CRIT_PX if crit else SHAKE_PX
	zoom_time = ZOOM_SECONDS
	flash_red = FLASH_RED_SECONDS
	flash_strength = 1.4 if crit else 1.0
	white[target] = WHITE_SECONDS
	kicks[target] = {"dir": dir, "dist": KNOCK_CRIT_PX if crit else KNOCK_PX, "time": KNOCK_SECONDS, "total": KNOCK_SECONDS}
	trail[target] = {"from": int(job["from_pv"]), "time": TRAIL_SECONDS}
	for i in (16 if crit else 10):  # sangue
		particles.append({"pos": to, "vel": dir * rng.randf_range(40.0, 140.0) + Vector2(rng.randf_range(-50, 50), rng.randf_range(-90, -10)), "life": 0.55, "max": 0.55, "kind": "blood", "size": rng.randf_range(1.5, 3.0)})
	impact.emit(job)


func _screen(p: Vector2) -> Vector2:
	return iso.call(p) if iso.is_valid() else p
