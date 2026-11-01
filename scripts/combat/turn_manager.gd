class_name TurnManager
extends RefCounted
# Ordem de turnos do combate (GDD B.5): turnos individuais por iniciativa, PA próprios
# por turno sem acúmulo, atrasar uma vez por rodada, passar e fim imediato do combate.

signal turn_started(unit: Combatant)
signal turn_ended(unit: Combatant)
signal round_started(number: int)
signal combat_ended(result: Result)

enum State { IDLE, ACTIVE, ENDED }
enum Result { NONE, VICTORY, GAME_OVER }

var pa_per_turn := 3
var state := State.IDLE
var result := Result.NONE
var round_number := 0
var order: Array[Combatant] = []  # iniciativa fixa durante o combate
var current: Combatant = null
var _queue: Array[Combatant] = []
var _delayed: Array[Combatant] = []
var _acted: Array[Combatant] = []  # já gastaram PA neste turno (não podem mais atrasar)
# Efeitos do início do turno (condições). Recebe a unidade e retorna true se ela perde o turno.
var turn_effects: Callable = Callable()


func _init(pa: int = 3) -> void:
	pa_per_turn = pa


# Monta participantes e ordena a iniciativa (maior primeiro). Empate residual, que o GDD
# diz que não deve ocorrer: protagonista antes de inimigo, depois a ordem da lista.
func start(units: Array[Combatant]) -> void:
	order = units.duplicate()
	var index := {}
	for i in units.size():
		index[units[i]] = i
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		if a.side != b.side:
			return a.side == Combatant.Side.PLAYER
		return index[a] < index[b])
	state = State.ACTIVE
	result = Result.NONE
	round_number = 0
	if not _check_end():
		_next_round()
		_advance()


func is_turn_of(unit: Combatant) -> bool:
	return state == State.ACTIVE and unit == current


# Gasta PA do protagonista ativo. Recusa se não for o turno dele ou se faltar saldo.
func spend(unit: Combatant, amount: int) -> bool:
	if not is_turn_of(unit) or amount > unit.pa:
		return false
	unit.pa -= amount
	if amount > 0 and not _acted.has(unit):
		_acted.append(unit)
	return true


# Chamar depois de cada ação resolvida: encerra o combate se for o caso e passa a vez
# quando os PA do ativo acabarem.
func action_done() -> void:
	if state != State.ACTIVE:
		return
	if current and not _acted.has(current) and current.pa < turn_pa(current):
		_acted.append(current)  # PA gastos fora de spend(), ex.: CombatRules.attack
	if _check_end():
		return
	if current == null or not current.is_alive() or current.pa <= 0:
		end_turn()


# Encerra o turno; PA restantes são perdidos.
func end_turn() -> void:
	if state != State.ACTIVE or current == null:
		return
	var finished := current
	finished.pa = 0
	current = null
	turn_ended.emit(finished)
	_advance()


# Passar: abre mão do resto da rodada. Volta a agir só na rodada seguinte.
func pass_turn() -> void:
	end_turn()


# Atrasar: uma vez por rodada, antes de gastar PA; a unidade age depois das demais.
func delay() -> bool:
	if state != State.ACTIVE or current == null:
		return false
	if _delayed.has(current) or _acted.has(current) or _queue.is_empty():
		return false
	var unit := current
	_delayed.append(unit)
	_queue.append(unit)
	unit.pa = 0
	current = null
	turn_ended.emit(unit)
	_advance()
	return true


func can_delay(unit: Combatant) -> bool:
	return is_turn_of(unit) and not _delayed.has(unit) and not _acted.has(unit) and not _queue.is_empty()


# PA com que a unidade começa cada turno: o da ficha, se houver, senão o padrão.
func turn_pa(unit: Combatant) -> int:
	return unit.pa_per_turn if unit.pa_per_turn >= 0 else pa_per_turn


func _advance() -> void:
	if state != State.ACTIVE or _check_end():
		return
	while true:
		if _queue.is_empty():
			_next_round()
		var unit: Combatant = _queue.pop_front()
		if unit.is_alive() and turn_effects.is_valid():
			var skip: bool = turn_effects.call(unit)
			if _check_end():
				return
			if skip:
				continue  # atordoado: perde o turno
		if unit.is_alive():
			current = unit
			unit.pa = turn_pa(unit)
			unit.moved_px = 0.0
			turn_started.emit(unit)
			return


func _next_round() -> void:
	round_number += 1
	_delayed.clear()
	_acted.clear()
	_queue.clear()
	for u in order:
		if u.is_alive():
			_queue.append(u)
	round_started.emit(round_number)


# Fim imediato: sem inimigos vivos é vitória; sem protagonistas vivos é Game Over.
func _check_end() -> bool:
	var players := false
	var enemies := false
	for u in order:
		if u.is_alive():
			if u.side == Combatant.Side.PLAYER:
				players = true
			else:
				enemies = true
	if enemies and players:
		return false
	state = State.ENDED
	result = Result.VICTORY if not enemies else Result.GAME_OVER
	current = null
	combat_ended.emit(result)
	return true
