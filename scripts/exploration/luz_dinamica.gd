class_name LuzDinamica
extends Node
# Luz dinâmica dos cenários 3D (modelos A + B escolhidos pelo Léo em 14/11/2026, item V-08 do dossiê visual).
# A, lanterna do líder: nas cenas noturnas (hora >= HORA_NOITE) o ambiente e o sol escurecem e um cone de luz
#    quente sai da frente do líder, virado para onde ele olha (o líder fica fora do cone; Léo, 14/11). Tecla L liga e desliga. Só atmosfera, sem efeito de regra.
# B, luzes vivas: as luzes do cenário tremem (algumas com defeito, que caem de vez em quando) e cada disparo
#    acende um clarão curto na arma. Valores provisórios do Claude, para o Léo calibrar.
# Fica ao lado do Parque (parque.gd) e só mexe no mundo 3D (`host.world3d.mundo`).

const HORA_NOITE := 20
const ESCURO := 0.45  # fração do ambiente e do sol que sobra com a lanterna ligada (provisório)
const TREME := 0.07  # amplitude do tremor das luzes (fração da energia)
const CLARAO_SEGUNDOS := 0.12
const CLARAO_ENERGIA := 16.0
const SPOT_ENERGIA := 14.0
const SPOT_ALCANCE := 8.0
const SPOT_ANGULO := 38.0
const ORIGEM_FRENTE := 1.0  # a luz nasce à frente do líder, para ele não entrar no cone
const COR_LANTERNA := Color(1.0, 0.86, 0.62)

var host: Node  # Parque (parque.gd)
var ligada := true
var noturno := false
var intensidade := 1.0  # 0 desliga o tremor
var _mundo: SubViewport
var _omnis: Array[OmniLight3D] = []
var _base := {}  # luz -> energia original
var _fase := {}  # luz -> [fase, defeito]
var _ambientes: Array[Environment] = []
var _ambiente_base := {}
var _sois: Array[DirectionalLight3D] = []
var _sol_base := {}
var _escuro := 0.0  # 0 = cena normal, 1 = lanterna ligada (suavizado)
var _spot: SpotLight3D
var _alvo_dir := Vector3(0, 0, 1)
var _dir := Vector3(0, 0, 1)
var _claroes: Array[Dictionary] = []  # {"luz": OmniLight3D, "t": float}
var _t := 0.0
var _pronto := false  # o _ready espera um quadro pelas luzes do cenário


func _ready() -> void:
	_mundo = host.world3d.mundo
	var info: Variant = host.world3d.get("info")
	noturno = info is Dictionary and int(info.get("hora", 0)) >= HORA_NOITE
	await get_tree().process_frame  # o cenário monta as luzes no próprio _ready
	for l in _mundo.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		_omnis.append(o)
		_base[o] = o.light_energy
		var h := hash(str(o.get_path()) + str(o.position))
		_fase[o] = [float(h % 628) / 100.0, h % 3 == 0]
	for we in _mundo.find_children("*", "WorldEnvironment", true, false):
		var e: Environment = (we as WorldEnvironment).environment
		_ambientes.append(e)
		_ambiente_base[e] = e.ambient_light_energy
	for d in _mundo.find_children("*", "DirectionalLight3D", true, false):
		_sois.append(d as DirectionalLight3D)
		_sol_base[d] = (d as DirectionalLight3D).light_energy
	if noturno:
		_criar_lanterna()
		_escuro = 1.0
	_pronto = true
	if host.get("fx") != null:
		var original: Callable = host.fx.muzzle_at
		host.fx.muzzle_at = func(a: Combatant) -> Vector2:
			if not a.weapon.get("melee", false):
				clarao(Vector3(a.pos.x / 64.0, 1.3, a.pos.y / 64.0))
			return original.call(a) if original.is_valid() else Vector2.INF


func _criar_lanterna() -> void:
	_spot = SpotLight3D.new()
	_spot.light_color = COR_LANTERNA
	_spot.light_energy = SPOT_ENERGIA
	_spot.spot_range = SPOT_ALCANCE
	_spot.spot_angle = SPOT_ANGULO
	_spot.spot_angle_attenuation = 1.6
	_spot.spot_attenuation = 1.0
	_spot.shadow_enabled = true
	_spot.light_specular = 0.0
	_mundo.add_child(_spot)


func alternar() -> void:
	ligada = not ligada


# Clarão do disparo: luz quente curta em volta da arma.
func clarao(pos: Vector3) -> void:
	if _mundo == null:
		return
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.88, 0.62)
	o.light_energy = CLARAO_ENERGIA
	o.omni_range = 7.0
	o.omni_attenuation = 1.6
	o.light_specular = 0.0
	_mundo.add_child(o)
	o.position = pos
	_claroes.append({"luz": o, "t": CLARAO_SEGUNDOS})


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_L and noturno:
		alternar()
		get_viewport().set_input_as_handled()


# Energia da luz no instante t: soma de senos lentos mais um mergulho raro nas luzes com defeito.
func _fator(o: OmniLight3D) -> float:
	var f: Array = _fase[o]
	var p: float = f[0]
	var v := 1.0 + intensidade * TREME * (sin(_t * 7.3 + p) * 0.6 + sin(_t * 17.1 + p * 2.0) * 0.4)
	if f[1] and intensidade > 0.0:
		var c := fmod(_t * 0.31 + p, 1.0)
		if c < 0.05:
			v *= 0.25 + 0.75 * absf(c - 0.025) / 0.025
	return v


func _process(delta: float) -> void:
	if not _pronto:
		return
	_t += delta
	for o in _omnis:
		if is_instance_valid(o):
			o.light_energy = _base[o] * _fator(o)
	for c in _claroes:
		c["t"] -= delta
		var luz: OmniLight3D = c["luz"]
		luz.light_energy = CLARAO_ENERGIA * clampf(c["t"] / CLARAO_SEGUNDOS, 0.0, 1.0)
		if c["t"] <= 0.0:
			luz.queue_free()
	_claroes = _claroes.filter(func(c: Dictionary) -> bool: return c["t"] > 0.0)
	if not noturno:
		return
	_escuro = move_toward(_escuro, 1.0 if ligada else 0.0, delta * 3.0)
	var k := lerpf(1.0, ESCURO, _escuro)
	for e in _ambientes:
		e.ambient_light_energy = _ambiente_base[e] * k
	for d in _sois:
		d.light_energy = _sol_base[d] * k
	_spot.visible = _escuro > 0.01
	if not _spot.visible:
		return
	var lider: Combatant = host.player
	var chao := Vector3(lider.pos.x / 64.0, 0.0, lider.pos.y / 64.0)
	_alvo_dir = _direcao(lider)
	_dir = _dir.slerp(_alvo_dir, clampf(delta * 8.0, 0.0, 1.0)).normalized()
	_spot.light_energy = SPOT_ENERGIA * _escuro
	_spot.position = chao + Vector3(0, 1.2, 0) + _dir * ORIGEM_FRENTE
	_spot.look_at(chao + _dir * (ORIGEM_FRENTE + 2.4), Vector3.UP)


# Para onde o líder olha, no chão do cenário 3D.
func _direcao(u: Combatant) -> Vector3:
	var d: int = host.facing8.get(u, CharacterSheet.Dir.SE)
	var dd: Vector2 = host.DIR_TELA[d]
	var a: Vector2 = host._iso(u.pos)
	var v: Vector2 = host._uniso(a + dd * 32.0) - u.pos
	if v.length() < 0.01:
		return _alvo_dir
	v = v.normalized()
	return Vector3(v.x, 0.0, v.y)
