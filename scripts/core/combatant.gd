class_name Combatant
extends RefCounted
# Ficha de uma unidade em combate (protagonista ou inimigo). Só dados, sem nó de tela.

enum Side { PLAYER, ENEMY }

var name := ""
var side := Side.PLAYER
var max_pv := 1
var pv := 1
var initiative := 0
var precision := 0
var defense := 0
var weapon: Dictionary = {}
var radius := 10.0
var pos := Vector2.ZERO
var pa := 0
var pa_per_turn := -1  # PA da ficha; -1 usa o padrão do combate (3 para protagonistas)


func is_alive() -> bool:
	return pv > 0


func take_damage(amount: int) -> void:
	pv = maxi(pv - amount, 0)
