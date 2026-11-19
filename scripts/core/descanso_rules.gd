class_name DescansoRules
extends RefCounted
# Ponto de descanso na zona segura (GDD #25, Léo 29/10): descansar recupera PV e SAN do grupo, tira a ruptura e salva o jogo,
# sem gastar tempo. Rituais preparados (Miguel, 19/11; RitualRules.prepare) também se fazem aqui.
# Só regras: a sala abre o painel (DescansoPanel), chama `rest` e depois salva (Progresso.autosalvar).

# Descansa o grupo: PV cheio, SAN cheia, ruptura e condições curadas. Quem morreu (caído sem reanimação) ou enlouqueceu não volta.
# Retorna {nome -> {pv, san, ruptura}} do que cada um recuperou, só para quem mudou.
static func rest(party: Array, san: SanRules) -> Dictionary:
	var out := {}
	for m: Combatant in party:
		if m.dead or m.insane:
			continue
		var got := {"pv": m.max_pv - m.pv, "san": m.max_san - m.san, "ruptura": m.ruptured}
		m.pv = m.max_pv
		san.rest(m)
		m.conditions.clear()
		m.buffs.clear()
		if got.pv > 0 or got.san > 0 or got.ruptura:
			out[m.name] = got
	return out
