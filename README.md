# game

## Estrutura

- `scenes/`: cenas da Godot (.tscn).
- `scripts/core/`: regras puras, sem nós de tela (PA, dano, acerto, PV/SAN).
- `scripts/exploration/`: movimento por clique, portas, interação e furtividade.
- `scripts/combat/`: iniciativa, turnos e ações.
- `scripts/ui/`: HUD e telas; só mostram estado confirmado.
- `scripts/audio/`: efeitos e música por evento sonoro (`data/audio_cues.json`).
- `assets/`: arte, áudio e fontes (versionados com Git LFS).
- `data/`: valores de balanceamento editáveis (armas, inimigos, itens).
- `tests/`: testes automatizados das regras. Rodam no GitHub Actions a cada PR (`.github/workflows/tests.yml`); localmente: `godot --headless --path . -s tests/test_<nome>.gd`.

## Engine

Godot 4 com GDScript. Renderer de compatibilidade, pixel art com filtro nearest.

## Build

Tag `v*` gera o build de Windows e publica o `.zip` no GitHub Releases. Detalhes em `docs/save-e-build.md`.
