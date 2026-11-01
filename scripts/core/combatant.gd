class_name Combatant
extends RefCounted
# Ficha de uma unidade em combate (protagonista ou inimigo). Só dados, sem nó de tela.

enum Side { PLAYER, ENEMY }

var name := ""
var side := Side.PLAYER
var max_pv := 1
var pv := 1
var max_san := 0  # sanidade (protagonistas); inimigos ficam com 0
var san := 0
var initiative := 0  # = AGI: define a ordem dos turnos (maior primeiro)
var defense := 0.0  # redução percentual do dano recebido (colete; 0.1 = 10%)
var hit_bonus := 0.0  # bônus temporário de acerto (ex.: mira), somado à chance
var weapon: Dictionary = {}
var radius := 10.0
var pos := Vector2.ZERO
var pa := 0
var moved_px := 0.0  # distância andada neste turno (os primeiros 5 m são grátis)
var perception := 0.0  # alcance de percepção em pixels (inimigos)
var crouched := false
var dead := false  # caído que não foi reanimado até o fim do combate (membro do grupo)  # agachado: inimigos percebem a metade da distância
var pa_per_turn := -1
var conditions: Dictionary = {}  # id -> {"stacks": int, "rounds": int (-1 = até remover)}  # PA da ficha; -1 usa o padrão do combate (3 para protagonistas)


func is_alive() -> bool:
	return pv > 0


func take_damage(amount: int) -> void:
	pv = maxi(pv - amount, 0)


func has_condition(id: String) -> bool:
	return conditions.has(id)
