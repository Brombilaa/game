class_name Cover
extends RefCounted
# Estrutura de cobertura: parcial ou completa, sólida para movimento. A parcial protege
# quem está encostado nela (-20% de acerto); a completa bloqueia o tiro (ver CombatRules).
# O hp fica para quando a destruição entrar no jogo (Léo: nenhuma é destrutível ainda).

var rect := Rect2()
var kind := "partial"  # "partial" ou "full", chaves de "cover" em combat.json
var hp := 1


func _init(r: Rect2 = Rect2(), k: String = "partial", structure_hp: int = 1) -> void:
	rect = r
	kind = k
	hp = structure_hp


func is_destroyed() -> bool:
	return hp <= 0


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
