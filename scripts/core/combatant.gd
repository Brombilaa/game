class_name Combatant
extends RefCounted
# Ficha de uma unidade em combate (protagonista ou inimigo). Só dados, sem nó de tela.

enum Side { PLAYER, ENEMY }

var name := ""
var personagem := ""  # id em personagens.json (agentes); vazio para inimigos
var atributos: Dictionary = {}  # VIG, FOR, INT, AGI, PRE da ficha (Ficha); vazio para inimigos
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
var drops: Array = []  # tabela de saque da ficha (inimigos): {item, qtd, chance}
var loot: Array = []  # saque sorteado que ainda está no corpo, esperando ser examinado: {item, qtd} (provisório do Claude)
var behavior := "agressivo"  # papel do inimigo (M3): agressivo, cerca ou atirador
var pa_per_turn := -1
var ruptured := false  # SAN chegou a 0: debuffs até ritual de cura, perk ou zona segura (GDD #11)
var ruptures_in_combat := 0  # vezes que chegou a 0 neste combate; 2 = loucura
var insane := false  # enlouqueceu: morte do personagem (GDD #11)
var conditions: Dictionary = {}  # id -> {"stacks": int, "rounds": int (-1 = até remover)}  # PA da ficha; -1 usa o padrão do combate (3 para protagonistas)
var prepared: Dictionary = {}  # id do ritual -> cargas preparadas no ponto de descanso (dispensam o componente e reforçam o efeito)
var em_ritual := false  # Léo (19/11): inimigo do salão da cripta focado no ritual; só luta depois de ser atacado (provoke)
var buffs: Dictionary = {}  # id do ritual -> {"rounds": turnos restantes, "defesa": fração, "dano": extra por ataque}
# Alvos sem turno da Dama de Sangue (flores, tentáculos que seguram os pendurados e prendem o grupo): atacáveis,
# não agem, não seguram o combate nem flanqueiam (ChefeDama).
var objeto := false
var aceita: Array = []  # objeto: só o ferem estes tipos de dano, armas ou itens (vazio = qualquer um)
var protegido := false  # objeto que não pode ser ferido agora (flor fora da janela de vulnerabilidade)
var pa_menos := 0  # PA a menos neste turno (confuso, derrubado), contados no início do turno
var preso := false  # não anda neste turno (Prisão de Tentáculos)
var sem_resistencias := false  # perdeu as resistências da ficha (Dama de Sangue com a flor Vermelha murcha)


func is_alive() -> bool:
	return pv > 0


func take_damage(amount: int) -> void:
	pv = maxi(pv - amount, 0)
	provoke()


# Atacado (tiro, golpe, ritual, granada ou condição, mesmo que erre): larga o ritual e passa a lutar.
func provoke() -> void:
	em_ritual = false


func has_condition(id: String) -> bool:
	return conditions.has(id)


# Redução de dano total: colete + rituais ativos (Armadura de Sangue). Nunca passa de 90%.
func defense_total() -> float:
	var d := defense
	for b: Dictionary in buffs.values():
		d += float(b.get("defesa", 0.0))
	return clampf(d, 0.0, 0.9)


# Dano extra por ataque dos rituais ativos (Amaldiçoar Arma de Sangue).
func damage_bonus() -> int:
	var d := 0
	for b: Dictionary in buffs.values():
		d += int(b.get("dano", 0))
	return d


# O dano deste tipo (Fraquezas: balistico, corpo_a_corpo, ritual, fogo) vindo desta origem (id da arma ou do item) fere?
func fere(tipo: String, origem := "") -> bool:
	if protegido:
		return false
	return aceita.is_empty() or aceita.has(tipo) or (origem != "" and aceita.has(origem))
