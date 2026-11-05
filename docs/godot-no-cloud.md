# Godot no ambiente de nuvem do Claude

A Godot não vem instalada. Todo container novo precisa instalar de novo (o disco é descartado).
Sem credencial: o binário vem do GitHub Releases público; a rede do ambiente precisa permitir `github.com`.

## Instalar (uma vez por sessão, ~30 s)

    tools/setup_godot_cloud.sh

Baixa a Godot 4.3-stable para `/opt/godot`, linka em `/usr/local/bin/godot`, faz `git lfs pull` e importa o projeto.
`xvfb-run` já existe no ambiente (necessário para capturas).

## Testes

    tools/setup_godot_cloud.sh test
    # ou um só: godot --headless --path . -s tests/test_combat.gd

Cada teste imprime `Falhas: 0` quando passa. Avisos de "leaked" ou `RenderingServer null` no fim são ruído conhecido.

## Capturas

    tools/setup_godot_cloud.sh shots /mnt/project-files/capturas

Gera menu, parque, sala de exploração e sala de combate (1920x1080) via `tools/capture_scenes.gd`.
Precisa de janela virtual (`xvfb-run`, `--rendering-driver opengl3`); não funciona em `--headless`.
