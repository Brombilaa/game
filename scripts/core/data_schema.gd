extends RefCounted
# Esquema dos arquivos em data/. Cada tabela é um arquivo JSON: uma lista de entradas com
# "id" único, exceto "regras", que é um objeto só. Detalhes e convenções em data/README.md.
#
# Campo: {"t": tipo, "nulo": aceita null (= PENDENTE), ...}
#   t: "int", "num", "texto", "bool", "faixa" ([min, max]), "tamanho" ([largura, altura]),
#      "lista" (lista de textos/ids), "dict_lista" (lista de objetos livres), "atributos" (FOR/AGI/... -> int ou null).
#   valores: lista de textos aceitos.        ref: tabela onde o id (ou cada id da lista) existe.
#   min / max: limites numéricos.             inteiro: faixa de inteiros.

const TABLES := ["regras", "atributos", "classes", "personagens", "condicoes", "armas", "itens", "inimigos", "arvores"]

const PERCENT := {"t": "num", "nulo": true, "min": 0.0, "max": 1.0}
const PA := {"t": "int", "nulo": true, "min": 0}

const FIELDS := {
	"regras": {
		"atrasar_por_rodada": {"t": "int", "nulo": false, "min": 0},
		"turnos_chefe_por_rodada_max": {"t": "int", "nulo": false, "min": 1},
		"custo_recarga_pa": PA,
		"custo_ataque_distancia_pa": PA,
		"custo_mira_pa": PA,
		"bonus_mira_precisao": PERCENT,
		"custo_corpo_a_corpo_pa": PA,
		"dano_corpo_a_corpo": {"t": "faixa", "nulo": true, "inteiro": true},
		"precisao_corpo_a_corpo": PERCENT,
		"bonus_altura": {"t": "num", "nulo": true, "min": 0.0},
		"pv_ganho_por_nivel_por_vig": {"t": "num", "nulo": true, "min": 0.0},
		"san_ganho_por_nivel_por_pre": {"t": "num", "nulo": true, "min": 0.0},
		"descanso_normal_percentual": PERCENT,
		"descanso_completo_percentual": PERCENT,
	},
	"atributos": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"descricao": {"t": "texto", "nulo": false},
	},
	"classes": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"pv_base": {"t": "int", "nulo": true, "min": 1},
		"pv_por_nivel": {"t": "int", "nulo": true, "min": 0},  # fixo; o Vigor soma de novo a cada nível
		"san_base": {"t": "int", "nulo": true, "min": 0},
		"san_por_nivel": {"t": "int", "nulo": true, "min": 0},
		"iniciativa_base": {"t": "int", "nulo": true},
	},
	"personagens": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"papel": {"t": "texto", "nulo": false},
		"classe": {"t": "texto", "nulo": true, "ref": "classes"},
		"arma_inicial": {"t": "texto", "nulo": true, "ref": "armas"},
		"arma_secundaria": {"t": "texto", "nulo": true, "ref": "armas"},
		"atributos": {"t": "atributos", "nulo": false},
		"arvores_exclusivas": {"t": "lista", "nulo": false, "ref": "arvores"},
		"morte_roteirizada": {"t": "bool", "nulo": false},
		"trio_final": {"t": "bool", "nulo": false},
	},
	"condicoes": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"duracao": {"t": "texto", "nulo": true, "valores": ["rodadas", "ate_remocao", "situacional"]},
		"rodadas": {"t": "int", "nulo": true, "min": 1},
		"efeito": {"t": "texto", "nulo": true},
		"acumula": {"t": "bool", "nulo": true},
		"remocao": {"t": "texto", "nulo": true},
	},
	"armas": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"tipo": {"t": "texto", "nulo": false, "valores": ["distancia", "corpo_a_corpo"]},
		"arma_longa": {"t": "bool", "nulo": false},
		"dano": {"t": "faixa", "nulo": true, "inteiro": true},
		"custo_pa": PA,
		"bonus_mira": PERCENT,  # por arma; null = vale bonus_mira_precisao de regras
		"precisao_base": PERCENT,
		"alcance_maximo": {"t": "num", "nulo": true, "min": 0.0},
		"distancia_ideal": {"t": "faixa", "nulo": true},
		"carregador": {"t": "int", "nulo": true, "min": 0},
		"reserva_maxima": {"t": "int", "nulo": true, "min": 0},
		"efeitos_criticos": {"t": "lista", "nulo": false, "ref": "condicoes"},
	},
	"itens": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"categoria": {"t": "texto", "nulo": false, "valores": ["consumivel", "equipamento", "missao", "recurso"]},
		"consumivel": {"t": "bool", "nulo": false},
		"tamanho": {"t": "tamanho", "nulo": true},
		"pilha_max": {"t": "int", "nulo": true, "min": 1},
		"custo_pa_combate": PA,
		"efeito": {"t": "texto", "nulo": true},
		"valor": {"t": "num", "nulo": true},
	},
	"inimigos": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"pv": {"t": "int", "nulo": true, "min": 1},
		"pa": {"t": "int", "nulo": true, "min": 0},
		"iniciativa": {"t": "int", "nulo": true},
		"precisao": {"t": "int", "nulo": true},
		"defesa": {"t": "int", "nulo": true},
		"ataques": {"t": "lista", "nulo": false, "ref": "armas"},
		"comportamento": {"t": "texto", "nulo": true},
		"resistencias": {"t": "lista", "nulo": false},
		"fraquezas": {"t": "lista", "nulo": false},
		"chefe": {"t": "bool", "nulo": false},
		"fases": {"t": "dict_lista", "nulo": false},
	},
	"arvores": {
		"id": {"t": "texto", "nulo": false},
		"nome": {"t": "texto", "nulo": false},
		"tipo": {"t": "texto", "nulo": false, "valores": ["compartilhada", "exclusiva"]},
		"atributo": {"t": "texto", "nulo": true, "ref": "atributos"},
		"personagem": {"t": "texto", "nulo": true, "ref": "personagens"},
		"habilidades": {"t": "dict_lista", "nulo": false},
	},
}

# Campos opcionais aceitos em qualquer entrada de tabela.
const OPTIONAL := {
	"provisorio": {"t": "bool", "nulo": false},
}
