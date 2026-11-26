# Dados do jogo

Valores de balanceamento e conteúdo, editáveis sem mexer em código. Cada tabela é um JSON;
o esquema está em `scripts/core/data_schema.gd` e o carregador em `scripts/core/game_data.gd`.

```gdscript
var data := GameData.new()
if not data.load_dir():        # lê res://data
	push_error("\n".join(data.errors))
data.rule("turnos_chefe_por_rodada_max")  # 2
data.get_entry("armas", "pistola")["dano"]  # [3, 5]
```

## Convenções

- **`null` = PENDENTE.** O GDD ainda não definiu o valor. O carregador aceita e lista em
  `data.pending`. Campos que não podem ficar pendentes (ids, nomes, tipos) dão erro se forem null.
- **`"provisorio": true`** marca entradas inventadas só para testar sistemas (quase todas as armas e inimigos,
  a distribuição sugerida de atributos). Ficam listadas em `data.provisional` e devem ser
  substituídas pelo conteúdo real.
- **Chaves começando com `_`** são comentários e são ignoradas.
- Campos desconhecidos dão erro, para pegar erro de digitação.
- Percentuais vão de `0.0` a `1.0`. Distâncias em metros. Faixas são `[min, max]`.
- Ids citados em outra tabela (classe, arma inicial, efeitos críticos, ataques de inimigo,
  árvores) precisam existir.

## Tabelas

| Arquivo | Conteúdo |
| --- | --- |
| `regras.json` | Constantes globais: atrasar, turnos de chefe, custos de ação (recarga, corpo a corpo, item, troca de arma, reanimar, mira), atributos iniciais, espaços do inventário, altura, descanso, ganho de PV/SAN por nível. O custo de ataque de cada arma fica em `armas.json` (`custo_pa`). |
| `atributos.json` | FOR, AGI, INT, PRE, VIG. |
| `classes.json` | PV e SAN base e por nível de cada classe. O código monta a ficha em `scripts/core/ficha.gd` (`Ficha`). |
| `personagens.json` | Fernando, Rafael, Miguel, Nikolai: classe, atributos sugeridos (o jogador redistribui antes da campanha), arma inicial, árvores exclusivas. |
| `condicoes.json` | As seis condições aprovadas: duração, efeito, acúmulo, remoção. |
| `armas.json` | Tipo, dano, precisão base, alcance, distância ideal, carregador, reserva, efeitos críticos. |
| `itens.json` | Categoria, tamanho na grade, pilha, custo em PA no combate, efeito, valor e `elemento` (só nos componentes de ritual: sangue, energia, morte ou conhecimento, categorias do Léo de 19/11). |
| `inimigos.json` | PV, PA, iniciativa, precisão, defesa, ataques, comportamento, resistências, fraquezas, fases de chefe. |
| `rituais.json` | Os quatro rituais do Miguel (Armadura de Sangue, Amaldiçoar Arma, Eletrocussão, Cicatrização): classe, alvo, custo de PA e SAN, alcance, efeito, duração. `elemento` e `componentes`: cada conjuração gasta esse número de itens do elemento (qualquer um) da mochila; sem componente o ritual não sai. Regras em `scripts/core/ritual_rules.gd`; INT soma por `Ficha.bonus_ritual`. Todos provisórios. |
| `arvores.json` | Cinco árvores compartilhadas (uma por atributo) e uma exclusiva por personagem do trio. |

Estado de execução (PV atual, munição no carregador, condições ativas) não fica aqui: estes
arquivos são só definições estáticas, como recomenda o Anexo C do GDD.

`combat.json` e `audio_cues.json` são lidos por outros sistemas (`CombatConfig` e `AudioDirector`) e
não passam por este carregador. O combate lê armas e inimigos destas tabelas via `GameData` (`CombatConfig.weapon` e
`CombatConfig.make_enemy`), convertendo metros em pixels por `pixels_per_meter` de `combat.json`. PA por turno, limites de acerto, crítico, cobertura e distância
por PA estão em `combat.json` por enquanto.

Ao exportar o jogo, incluir `data/*.json` no filtro de recursos não importados do preset.

`falas_soltas.json` guarda as falas do grupo na exploração (Fernando, Nikolai e Miguel conversando sobre as pistas). Cada item tem `id`, `area` (id do cenário), `falas` (1 a 2 linhas `quem`/`texto`) e, se quiser, `requer` (marca). A lógica de quando falar está em `FalasSoltas` e as falas tocam uma vez por jogo; este arquivo não passa pelo `GameData`.

`fraquezas.json` guarda os multiplicadores de fraqueza (+50%) e resistência (−50%), os nomes dos tipos de dano (`balistico`, `corpo_a_corpo`, `ritual`; `fogo` e `sal` reservados para itens) e de que pista vem cada descoberta. Quem tem o quê fica nos campos `fraquezas` e `resistencias` de `inimigos.json` (`atordoado` em `resistencias` continua sendo imunidade a atordoar). As regras estão em `Fraquezas` (`scripts/core/fraquezas.gd`); a descoberta é uma entrada do diário no lugar "INIMIGOS". Tudo provisório. Este arquivo não passa pelo `GameData`.

`data/cenarios/*.json`, testes de perícia (d20): uma pista pode ter `teste` (uma camada) ou `testes` (várias, da mais fácil à mais difícil). Cada camada tem `pericias` (ids de `TestePericia.PERICIAS`: ocultismo, religiao, tecnologia, diplomacia, intuicao, intimidacao), `dt` (8 fácil, 12 média, 15 difícil), `completo` (o texto de quem passou) e, em `testes`, um `id`. O `texto` da pista é o superficial, que quem falha lê. Cada camada tem uma tentativa só, com o resultado salvo nas marcas (`teste_<lugar>_<pista>_<camada>_passou` ou `_falhou`); passar abre a próxima camada. No gatilho de combate do parque, `teste_depois` (com `cena_falha`) faz o teste dos restos dos zumbis quando o combate termina e escolhe a versão da cena `cutscene_depois`. Num gatilho de cena (`tipo: "cena"`), `teste` com `cena_falha` troca a cena quando falha (Geraldo e Ju: falhou = informação superficial ou negativa). Bônus de quem rola: atributo ligado + 2 se a perícia é a da classe (combatente: Intimidação, especialista: Tecnologia, ocultista: Ocultismo; provisório). A tela mostra só o bônus de cada agente, nunca a chance.
