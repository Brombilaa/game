# Convenções de arte

Regra geral: `assets/<tipo>/<categoria>/<assunto>/<nome>`. Nomes em minúsculas, `snake_case`, sem acento, sem espaços. Arte é versionada com Git LFS (ver `.gitattributes`); arquivos `.import` acompanham o original e são movidos junto com `git mv`.

## Pastas

| Pasta | Conteúdo |
|---|---|
| `assets/3d/parque/` | cenário 3D do parque (`parque_cenario.glb`) e `tons_materiais.gd` |
| `assets/3d/personagens/` | modelos 3D (`<personagem>.glb`, `<personagem>_estatico.glb`) |
| `assets/3d/animacoes/` | FBX do Mixamo só com esqueleto: `<personagem>_<animacao>.fbx` |
| `assets/3d/shaders/` | todos os `.gdshader` do visual "PC antigo" |
| `assets/sprites/personagens/nikolai3d/` | folhas renderizadas do Nikolai 3D: `nikolai3d_<animacao>_<direcao>[_<quadro>].png` |
| `assets/sprites/personagens/criatura_sangue/` | idem para a Criatura: `criatura_<animacao>_<direcao>.png` |
| `assets/sprites/personagens/legado_2d/` | sprites 2D antigos (Fernando, Miguel, Nikolai, cultista), ainda usados na tecla V e nos testes: `<personagem>_<direcao>.png` |
| `assets/sprites/retratos/` | `<personagem>_64.png` e `<personagem>_128.png` |
| `assets/sprites/ui/acoes/`, `ui/condicoes/` | ícones 64x64, nome = id no código (`pistola`, `sangrando`) |
| `assets/sprites/ui/inv/` | peças do inventário, incluindo `moldura.png` |
| `assets/sprites/menu/` | fundo do menu |
| `assets/sprites/cenario/parque/` | parque 2D antigo (`fundo*.png`, `oclusao/`) lido por `data/cenarios/parque.json` |
| `assets/sprites/cenario/salas_2d/` | tiles de sala 2D (`chao_N`, `parede_x|y_<tipo>`, `movel_<nome>`) e seus `.json` |
| `assets/fonts/`, `assets/audio/`, `assets/palettes/` | fontes (com a licença ao lado), áudio e paletas |

## Nomes

- Direções: `n`, `ne`, `e`, `se`, `s` (as outras três são espelhadas no código).
- Animações em inglês de Mixamo (`idle`, `walk`, `pistol_shoot`...), nomes de personagem e itens em português, como no `data/`.
- Sufixos `_prov` marcam arte provisória; `_raw` fica fora do jogo (originais em `/mnt/project-files/arte/`).
- Original de trabalho (PSD, GIF, HTML de protótipo, FBX bruto) não entra no repositório; vive em `arte/` dos arquivos do projeto.

## Ao mover ou criar arte

1. Use `git mv` (mantém histórico e o `.import`) e acerte `source_file` no `.import`.
2. Atualize caminhos em `scripts/`, `data/` e `tools/`.
3. Rode `tests/test_art_layout.gd`: ele falha se algum `res://assets/...` do código ou dos dados não existir.
