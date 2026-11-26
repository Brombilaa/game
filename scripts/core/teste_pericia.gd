class_name TestePericia
extends RefCounted
# Teste de perícia de investigação (Léo, 20/11, roteiro "REGRAS DO TESTE"): d20 + atributo ligado contra uma DT visível
# (8 fácil, 12 média, 15 difícil). 20 natural passa, 1 natural falha. Passou = informação completa; falhou = superficial.
# Uma tentativa por pista: o resultado fica salvo nas marcas ("teste_<id>_passou" ou "teste_<id>_falhou"), que vão no save.
#
# Perícias do jogo (Léo): Ocultismo, Religião, Tecnologia (INT); Diplomacia, Intuição, Intimidação (PRE, correção de 20/11).
# Ocultista soma +2 em Ocultismo (Léo).
# Quem rola (Léo, 22/11: "jogador escolhe"): a tela de escolha lista cada agente com a perícia e o bônus antes do dado
# (opcoes). Sem escolha (testes, ou se a tela não abrir), rola o agente de maior bônus (melhor).

const PERICIAS := {
	"ocultismo": {"nome": "Ocultismo", "atr": "INT"},
	"religiao": {"nome": "Religião", "atr": "PRE"},
	"tecnologia": {"nome": "Tecnologia", "atr": "INT"},
	"diplomacia": {"nome": "Diplomacia", "atr": "PRE"},
	"intuicao": {"nome": "Intuição", "atr": "PRE"},
	"intimidacao": {"nome": "Intimidação", "atr": "PRE"},
}
const BONUS_OCULTISTA := 2

# A tela do dado rolando (TelaD20) aparece depois da escolha; os testes automáticos a desligam.
static var animar := true

# Detalhes da rolagem desta sessão (id do teste -> resultado). O que vai no save é só passou/falhou, nas marcas.
static var rolados := {}


static func reiniciar() -> void:
	rolados = {}


# Bônus de quem rola: o atributo ligado à perícia (+2 de Ocultista em Ocultismo).
static func bonus(pericia: String, atributos: Dictionary, ocultista: bool) -> int:
	var b := int(atributos.get(str(PERICIAS[pericia]["atr"]), 0))
	if pericia == "ocultismo" and ocultista:
		b += BONUS_OCULTISTA
	return b


# Opções da tela de escolha: um item por agente e perícia, com o bônus de cada um.
static func opcoes(pericias: Array, grupo: Array) -> Array:
	var out: Array = []
	for m in grupo:
		for p in pericias:
			out.append({"pericia": str(p), "quem": str(m.get("nome", "")), "bonus": bonus(str(p), m.get("atributos", {}), bool(m.get("ocultista", false)))})
	return out


# Quem rola entre `grupo` (lista de {"nome", "atributos", "ocultista"}) e com qual perícia de `pericias`: o maior bônus.
static func melhor(pericias: Array, grupo: Array) -> Dictionary:
	var best := {}
	var best_b := -999
	for p in pericias:
		for m in grupo:
			var b := bonus(str(p), m.get("atributos", {}), bool(m.get("ocultista", false)))
			if b > best_b:
				best_b = b
				best = {"pericia": str(p), "quem": str(m.get("nome", "")), "bonus": b}
	return best


# Uma rolagem (sem guardar). `dado` 0 = sorteia (rng); valor de 1 a 20 = dado já rolado (testes).
static func rolar(pericias: Array, dt: int, grupo: Array, rng: RandomNumberGenerator, dado := 0, escolha := {}) -> Dictionary:
	var m := escolha.duplicate() if not escolha.is_empty() else melhor(pericias, grupo)
	if m.is_empty():
		return {}
	var d := dado if dado > 0 else rng.randi_range(1, 20)
	var total := d + int(m["bonus"])
	var passou := d == 20 or (d != 1 and total >= dt)
	m.merge({"dado": d, "total": total, "dt": dt, "passou": passou})
	return m


# Já foi rolado (ou falhou/passou num save anterior)?
static func feito(id: String) -> bool:
	return Missao1.tem("teste_%s_passou" % id) or Missao1.tem("teste_%s_falhou" % id)


# Teste de uma pista ou cena: uma tentativa só. Repetir devolve o resultado salvo.
static func tentar(id: String, pericias: Array, dt: int, grupo: Array, rng: RandomNumberGenerator, dado := 0, escolha := {}) -> Dictionary:
	if Missao1.tem("teste_%s_passou" % id) or Missao1.tem("teste_%s_falhou" % id):
		var g: Dictionary = rolados.get(id, {})
		g["passou"] = Missao1.tem("teste_%s_passou" % id)
		g["salvo"] = true
		g["dt"] = dt
		if not g.has("pericia"):
			g["pericia"] = str(pericias[0])
		return g
	var r := rolar(pericias, dt, grupo, rng, dado, escolha)
	if r.is_empty():
		return r
	rolados[id] = r
	Missao1.marcar("teste_%s_%s" % [id, "passou" if r["passou"] else "falhou"])
	return r


# Linha para o jogador, em português, com a DT visível: "Ocultismo (INT) DT 12 · Miguel: d20 14 + 3 = 17. Passou."
static func texto(r: Dictionary) -> String:
	if r.is_empty():
		return ""
	var p: Dictionary = PERICIAS.get(str(r.get("pericia", "")), {"nome": "", "atr": ""})
	var cab := "%s (%s) DT %d" % [p["nome"], p["atr"], int(r.get("dt", 0))]
	if r.has("dado"):
		var nat := ""
		if int(r["dado"]) == 20:
			nat = " (20 natural)"
		elif int(r["dado"]) == 1:
			nat = " (1 natural)"
		return "%s · %s: d20 %d + %d = %d%s. %s." % [cab, r.get("quem", ""), int(r["dado"]), int(r["bonus"]), int(r["total"]), nat, "Passou" if r["passou"] else "Falhou"]
	return "%s · resultado salvo: %s." % [cab, "passou" if r["passou"] else "falhou"]
