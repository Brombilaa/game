# Dados do jogo

Valores de balanceamento e conteúdo, editáveis sem mexer em código. Cada tabela é um JSON;
o esquema está em `scripts/core/data_schema.gd` e o carregador em `scripts/core/game_data.gd`.

```gdscript
var data := GameData.new()
if not data.load_dir():        # lê res://data
	push_error("\n".join(data.errors))
data.rule("pa_por_turno")      # 3
data.get_entry("armas", "pistola_teste")["dano"]  # [8, 12]
```

## Convenções

- **`null` = PENDENTE.** O GDD ainda não definiu o valor. O carregador aceita e lista em
  `data.pending`. Campos que não podem ficar pendentes (ids, nomes, tipos) dão erro se forem null.
- **`"provisorio": true`** marca entradas inventadas só para testar sistemas (`pistola_teste`,
  `cultista_teste`, as três classes). Ficam listadas em `data.provisional` e devem ser
  substituídas pelo conteúdo real.
- **Chaves começando com `_`** são comentários e são ignoradas.
- Campos desconhecidos dão erro, para pegar erro de digitação.
- Percentuais vão de `0.0` a `1.0`. Distâncias em metros. Faixas são `[min, max]`.
- Ids citados em outra tabela (classe, arma inicial, efeitos críticos, ataques de inimigo,
  árvores) precisam existir.

## Tabelas

| Arquivo | Conteúdo |
| --- | --- |
| `regras.json` | Constantes globais: PA, limites de acerto, custos de ação, crítico, cobertura, altura, descanso, ganho de PV/SAN por nível. |
| `atributos.json` | FOR, AGI, INT, PRE, VIG. |
| `classes.json` | PV, SAN e iniciativa base por classe. |
| `personagens.json` | Fernando, Rafael, Miguel, Nikolai: classe, atributos, arma inicial, árvores exclusivas. |
| `condicoes.json` | As seis condições aprovadas: duração, efeito, acúmulo, remoção. |
| `armas.json` | Tipo, dano, precisão base, alcance, distância ideal, carregador, reserva, efeitos críticos. |
| `itens.json` | Categoria, tamanho na grade, pilha, custo em PA no combate, efeito e valor. |
| `inimigos.json` | PV, PA, iniciativa, ataques, comportamento, resistências, fraquezas, fases de chefe. |
| `arvores.json` | Cinco árvores compartilhadas (uma por atributo) e uma exclusiva por personagem do trio. |

Estado de execução (PV atual, munição no carregador, condições ativas) não fica aqui: estes
arquivos são só definições estáticas, como recomenda o Anexo C do GDD.

Ao exportar o jogo, incluir `data/*.json` no filtro de recursos não importados do preset.
