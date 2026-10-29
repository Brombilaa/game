class_name Combatant
extends RefCounted
# Ficha de uma unidade em combate (protagonista ou inimigo). Só dados, sem nó de tela.

enum Side { PLAYER, ENEMY }

var name := ""
var side := Side.PLAYER
var max_pv := 1
var pv := 1
var initiative := 0  # = AGI: define a ordem dos turnos (maior primeiro)
var defense := 0.0  # redução percentual do dano recebido (colete; 0.1 = 10%)
var hit_bonus := 0.0  # bônus temporário de acerto (ex.: mira), somado à chance
var weapon: Dictionary = {}
var radius := 10.0
var pos := Vector2.ZERO
var pa := 0
var perception := 0.0  # alcance de percepção em pixels (inimigos)
var crouched := false  # agachado: inimigos percebem a metade da distância
var pa_per_turn := -1  # PA da ficha; -1 usa o padrão do combate (3 para protagonistas)


func is_alive() -> bool:
	return pv > 0


func take_damage(amount: int) -> void:
	pv = maxi(pv - amount, 0)
