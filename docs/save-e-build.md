# Salvamento e build: plano

Estado: formato do save e build de Windows implementados. Política de save
aprovada pelo Léo em 2026-10-29 (DEC-2026-10-29-01, seção 5), ainda não
implementada.

## 1. Formato do save

- Um arquivo JSON por slot em `user://saves/` (no Windows:
  `%APPDATA%\Godot\app_userdata\Ordem Paranormal\saves\`).
- Envelope com versão: `{ "version": 1, "saved_at": <unix>, "data": {...} }`.
  Save de versão mais nova que o jogo é recusado; versões antigas passam por
  migração (`SaveGame._migrate`), uma versão por vez.
- Gravação atômica: escreve `.tmp`, guarda o save anterior como `.bak` e troca.
  Se o principal corromper, a leitura usa o `.bak`.
- JSON e não `Resource`/`var_to_bytes`: legível, fácil de comparar em bug
  report e não executa código ao carregar.

Implementado em `scripts/core/save_game.gd`, testado em
`tests/test_save_game.gd`.

## 2. O que entra no save

Segue a recomendação do GDD (Anexo C): definições estáticas (`data/`) ficam
fora; só o estado mutável entra, referenciando definições por id.

```
data
├─ current_area: "brasil_galpao"
├─ party
│  └─ rafael: { pv, san, condicoes, equipamento, municao }
├─ inventory: [ { item_id, qtd } ]
├─ areas
│  └─ <area_id>: { doors: { <door_id>: true }, safe_zones: [...],
│                  revealed: [...], dropped_items: [...], dead_enemies: [...] }
└─ missions
   └─ <mission_id>: { state, objectives: { <obj_id>: "found" | "done" } }
```

Regras que já valem pelo GDD: PV e SAN persistem entre combates; porta aberta
fica aberta na área. Ainda pendentes e marcados como tal no GDD: persistência
de itens descartados e de portas ao sair e voltar à área.

Proposta: tudo que muda em uma área vive em `areas.<area_id>` desde já, mesmo
na sessão atual. Assim, sair e voltar à sala usa o mesmo caminho que carregar
o save, e a decisão pendente vira só "gravar ou não em disco".

## 3. Carregamento entre salas

- Um autoload `GameState` guarda o dicionário `data` em memória.
- Ao sair de uma sala, a cena escreve seu estado em `areas.<area_id>`
  (evento `AreaExited`); ao entrar, lê de lá antes do primeiro quadro
  (`AreaEntered`, Anexo D).
- Salvar em disco é só `SaveGame.write(slot, GameState.data)`.
- Próximo passo concreto: a sala de teste passa a gravar `door_open` em
  `GameState`. Fica para depois da segunda sala existir, para não brigar com
  o trabalho de exploração em andamento.

## 4. Build e distribuição

- Alvo inicial: Windows x86_64 (PC primeiro, plataforma ainda PENDENTE no
  GDD). Linux sai pelo mesmo pipeline se quisermos.
- `export_presets.cfg` versionado, preset "Windows Desktop", `.pck` embutido
  no `.exe`; `tests/` e `docs/` ficam fora do build.
- `.github/workflows/build.yml`: baixa Godot 4.3 e o template de Windows,
  roda todos os `tests/test_*.gd`, exporta e gera o `.zip`.
  - Tag `v*` (ex.: `git tag v0.1.0 && git push origin v0.1.0`): publica o
    `.zip` no GitHub Releases.
  - Rodar manualmente pela aba Actions: só gera o artifact, sem release.
- Builds nunca entram no Git (`build/`, `*.exe`, `*.pck` já ignorados).
- Build local: `godot --headless --path . --export-release "Windows Desktop" build/windows/OrdemParanormal.exe`
  (precisa do export template 4.3 instalado no editor).

## 5. Decisões

| ID | Assunto | Decisão | Status |
| --- | --- | --- | --- |
| DEC-2026-10-29-01 | Política de save | Autosave ao entrar em área ou zona segura + 3 slots manuais fora de combate. Sem save no meio do combate; autosave no início dele para tentar de novo. Morte do grupo volta ao último autosave. Aprovado por Léo. | Não implementado |
