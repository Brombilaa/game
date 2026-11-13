class_name HudText
extends RefCounted
# Textos do HUD sem nós de tela, para poder testar em modo headless.

# Motivos de ação rejeitada (GDD Anexo D: ActionRejected deve explicar falta de PA,
# alcance ou requisito). Textos provisórios até a etapa de UI/UX.
const REJECTION_MESSAGES := {
	"no_pa": "PA insuficientes",
	"out_of_range": "Fora de alcance",
	"no_line_of_sight": "Sem linha de visão",
	"reloading": "Recarregando",
	"requirement": "Requisito não atendido",
}
const UNKNOWN_REJECTION := "Ação inválida"


static func mode_label(in_combat: bool) -> String:
	return "COMBATE" if in_combat else "EXPLORAÇÃO"


static func pa_label(pa: int, max_pa: int) -> String:
	return "PA %d/%d" % [clampi(pa, 0, max_pa), max_pa]


static func rejection_message(reason: String) -> String:
	return REJECTION_MESSAGES.get(reason, UNKNOWN_REJECTION)
