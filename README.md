# Pacto Carmesim

RPG tático de investigação paranormal em turnos, feito na Godot 4. Protótipo: missão 1 em Aurora (RS).

## Estrutura

- `scenes/`: cenas da Godot (.tscn).
- `scripts/core/`: regras puras, sem nós de tela (PA, dano, acerto, PV/SAN).
- `scripts/exploration/`: movimento por clique, portas, interação e furtividade.
- `scripts/combat/`: iniciativa, turnos e ações.
- `scripts/ui/`: HUD e telas; só mostram estado confirmado.
- `scripts/art/`: arte provisória gerada por código (paleta de teste, inimigos, chão) e `CharacterSheet`, que desenha as folhas de poses reais em `assets/sprites/personagens/`.
- `tools/sprites/`: conversor das imagens do ChatGPT em folhas de sprites do jogo.
- `scripts/audio/`: efeitos e música por evento sonoro (`data/audio_cues.json`).
- `assets/`: arte, áudio e fontes (versionados com Git LFS). Pastas e nomes em `docs/convencoes-arte.md`.
- `data/`: valores de balanceamento editáveis (armas, inimigos, itens).
- `tests/`: testes automatizados das regras. Rodam no GitHub Actions a cada PR (`.github/workflows/tests.yml`); localmente: `godot --headless --path . -s tests/test_<nome>.gd`.

## Engine

Godot 4 com GDScript. Renderer de compatibilidade, pixel art com filtro nearest.
Resolução interna 960×540, janela de 1920×1080. Direção visual em `docs/direcao-visual.md`.

## Build

O build de Windows roda sob demanda (Actions > build > Run workflow) e pode publicar o `.zip` no release "latest". Detalhes em `docs/save-e-build.md`.
