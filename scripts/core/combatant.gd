class_name Combatant
extends RefCounted
# Ficha de uma unidade em combate (protagonista ou inimigo). Só dados, sem nó de tela.

enum Side { PLAYER, ENEMY }

var name := ""
var kind := ""  # id da ficha em inimigos.json (inimigos); usado pelo terror ao ver
var side := Side.PLAYER
var max_pv := 1
var pv := 1
var max_san := 0  # sanidade (protagonistas); inimigos ficam com 0
var san := 0
var initiative := 0  # = AGI: define a ordem dos turnos (maior primeiro)
var defense := 0.0  # redução percentual do dano recebido (colete; 0.1 = 10%)
var hit_bonus := 0.0  # bônus temporário de acerto (ex.: mira), somado à chance
var weapon: Dictionary = {}
var mag: Dictionary = {}  # id da arma -> balas no carregador (só armas com mag_size > 0)
var radius := 10.0
var pos := Vector2.ZERO
var pa := 0
var moved_px := 0.0  # distância andada neste turno (os primeiros 5 m são grátis)
var perception := 0.0  # alcance de percepção em pixels (inimigos)
var crouched := false
var iluminacao := -1.0  # luz sobre a unidade, 0 (sombra) a 1 (luz); -1 = a luz não conta (dia). Modelo C, luz_furtividade.gd
var overwatch_dir := Vector2.RIGHT  # direção do cone da vigilância (plano da sala)
var overwatch := false  # em vigilância: atira no primeiro inimigo que se mover à vista (dura até o próximo turno dele)
var dead := false  # caído que não foi reanimado até o fim do combate (membro do grupo)  # agachado: inimigos percebem a metade da distância
var looted := false
var drops: Array = []  # itens que larga ao morrer (inimigos): {item, qtd, chance}
var behavior := "agressivo"  # papel do inimigo (M3): agressivo, cerca ou atirador
var pa_per_turn := -1
var ruptured := false  # SAN chegou a 0: debuffs até ritual de cura, perk ou zona segura (GDD #11)
var ruptures_in_combat := 0  # vezes que chegou a 0 neste combate; 2 = loucura
var insane := false  # enlouqueceu: morte do personagem (GDD #11)
var conditions: Dictionary = {}  # id -> {"stacks": int, "rounds": int (-1 = até remover)}  # PA da ficha; -1 usa o padrão do combate (3 para protagonistas)


func is_alive() -> bool:
	return pv > 0


func take_damage(amount: int) -> void:
	pv = maxi(pv - amount, 0)


func has_condition(id: String) -> bool:
	return conditions.has(id)
