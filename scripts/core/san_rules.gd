class_name SanRules
extends RefCounted
# SAN como medidor de terror: perda, ruptura e loucura (GDD #11, Léo 29/10/2026).
#   - SAN chega a 0: ruptura. Debuffs (combat.json > sanidade) até ritual de cura, perk ou zona segura.
#   - Chegar a 0 duas vezes no mesmo combate: loucura = morte do personagem.
# PROVISÓRIO do Claude (15/11/2026): perder SAN já em ruptura conta como chegar a 0 de novo; fora de combate
# ninguém enlouquece; quanto cada susto tira; PRE dá chance de resistir a sustos (não a custo de ritual).
# Só regras: a sala chama os eventos (inimigo visto, aliado caído, pista lida) e mostra o resultado.

const ESTAGIO_CALMO := 0
const ESTAGIO_ABALADO := 1
const ESTAGIO_BEIRA := 2
const ESTAGIO_RUPTURA := 3

var cfg: CombatConfig
var rng: RandomNumberGenerator
var in_combat := false
var _seen_kinds: Dictionary = {}  # tipos de inimigo que já assustaram o grupo neste combate
var pre := {}  # Combatant -> PRE (atributo); quem não está aqui conta como PRE 1


func _init(config: CombatConfig, random: RandomNumberGenerator = null) -> void:
	cfg = config
	rng = random if random else RandomNumberGenerator.new()


# --- Ciclo do combate -----------------------------------------------------------

func start_combat(party: Array, turns: TurnManager = null) -> void:
	in_combat = true
	_seen_kinds.clear()
	for m: Combatant in party:
		m.ruptures_in_combat = 0
	if turns:
		turns.rupture_pa = int(cfg.san("ruptura_pa"))


# A ruptura continua depois do combate (só sai com cura, perk ou zona segura); a contagem para loucura zera.
func end_combat(party: Array) -> void:
	in_combat = false
	_seen_kinds.clear()
	for m: Combatant in party:
		m.ruptures_in_combat = 0


# --- Perda ---------------------------------------------------------------------

# Tira `amount` de SAN de `unit`. `scare`: é um susto (PRE pode resistir); false para custo de ritual.
# Retorna {lost, resisted, rupture, insane}: rupture = entrou em ruptura agora; insane = enlouqueceu agora.
func lose(unit: Combatant, amount: int, scare := true) -> Dictionary:
	var out := {"lost": 0, "resisted": false, "rupture": false, "insane": false}
	if amount <= 0 or unit.max_san <= 0 or unit.insane or not unit.is_alive():
		return out
	if scare and rng.randf() < resist_chance(unit):
		out.resisted = true
		return out
	if unit.san > 0:
		out.lost = mini(amount, unit.san)
		unit.san -= out.lost
		if unit.san > 0:
			return out
		out.rupture = not unit.ruptured
		unit.ruptured = true
	elif not in_combat:
		return out  # já em ruptura fora de combate: nada piora
	if in_combat:
		unit.ruptures_in_combat += 1
		if unit.ruptures_in_combat >= int(cfg.san("rupturas_para_loucura")):
			_go_insane(unit)
			out.insane = true
			out.rupture = false
	return out


func resist_chance(unit: Combatant) -> float:
	var p := int(pre.get(unit, unit.atributos.get("PRE", 1)))  # PRE da ficha (Ficha); `pre` sobrepõe (testes)
	return maxi(p - 1, 0) * float(cfg.san("resistir_por_pre"))


func _go_insane(unit: Combatant) -> void:
	unit.insane = true
	unit.ruptured = false
	unit.pv = 0
	unit.dead = true  # morte do personagem, não caído: não há reanimação


# --- Eventos que assustam --------------------------------------------------------

# O grupo vê `enemy` pela primeira vez neste combate (por tipo). Retorna {Combatant: resultado de lose}.
func enemy_seen(enemy: Combatant, party: Array) -> Dictionary:
	if enemy.kind == "" or _seen_kinds.has(enemy.kind):
		return {}
	_seen_kinds[enemy.kind] = true
	return _hit_group(party, int(cfg.san("terror_ao_ver").get(enemy.kind, 0)), null)


# Um aliado caiu (PV 0) ou morreu (sem reanimação, ou loucura): quem está vivo no grupo perde SAN.
func ally_down(fallen: Combatant, party: Array, died := false) -> Dictionary:
	return _hit_group(party, int(cfg.san("perdas")["aliado_morto" if died else "aliado_caido"]), fallen)


# O personagem levou um crítico.
func crit_taken(unit: Combatant) -> Dictionary:
	return lose(unit, int(cfg.san("perdas")["critico_recebido"]))


# Perda de uma pista (cenarios/*.json): "perda_san": N, ou "perturbadora": true para o padrão.
# Só quem lê perde (o líder). Pistas não enlouquecem fora de combate.
func clue_loss(clue: Dictionary) -> int:
	if clue.has("perda_san"):
		return int(clue["perda_san"])
	return int(cfg.san("perdas")["pista_perturbadora"]) if clue.get("perturbadora", false) else 0


func clue_read(reader: Combatant, clue: Dictionary) -> Dictionary:
	return lose(reader, clue_loss(clue))


func _hit_group(party: Array, amount: int, skip: Combatant) -> Dictionary:
	var out := {}
	if amount <= 0:
		return out
	for m: Combatant in party:
		if m != skip and m.is_alive() and not m.dead:
			out[m] = lose(m, amount)
	return out


# --- Recuperação -----------------------------------------------------------------

# Ritual de cura, perk ou item: devolve SAN. A ruptura só sai com `clear_rupture` (ritual/perk) ou descanso.
func recover(unit: Combatant, amount: int, clear_rupture := false) -> void:
	if unit.insane or unit.max_san <= 0:
		return
	unit.san = clampi(unit.san + maxi(amount, 0), 0, unit.max_san)
	if clear_rupture:
		unit.ruptured = false


# Descanso na zona segura: SAN cheia e ruptura curada (GDD #25).
func rest(unit: Combatant) -> void:
	if unit.insane:
		return
	unit.san = unit.max_san
	unit.ruptured = false


# --- Leitura para tela, som e falas -------------------------------------------------

func stage(unit: Combatant) -> int:
	if unit.max_san <= 0:
		return ESTAGIO_CALMO
	if unit.ruptured or unit.san <= 0:
		return ESTAGIO_RUPTURA
	var ratio := float(unit.san) / float(unit.max_san)
	var limits: Array = cfg.san("estagios")
	if ratio < float(limits[1]):
		return ESTAGIO_BEIRA
	if ratio < float(limits[0]):
		return ESTAGIO_ABALADO
	return ESTAGIO_CALMO
