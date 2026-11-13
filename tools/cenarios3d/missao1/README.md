# Cenários 3D da missão 1 (delegacia, subsolo, biblioteca, Fazenda Ghular)

Os cenários nascem nos protótipos three.js aprovados pelo Léo em 12/11/2026
(`/mnt/project-files/arte/cenarios-missao1/fonte/`: kit.js, props.js, arq.js, cidade.js, delegacia.js,
biblioteca.js, fazenda.js, cena.html, serve.js). Os scripts desta pasta vão junto com essas fontes.

## 1. Exportar a cena (glb + json)

Com `node serve.js` (porta 8123) rodando na pasta das fontes:

    node exp.js <cena> <vista> <hora> <nome>      # ex.: node exp.js delegacia dentro 21 delegacia_21h
    node finalizar.mjs exp/<nome>.glb exp/f_<nome>.glb   # repete para cada exp/<nome>_<estado>.glb

`exp.js` abre `cena.html?s=<cena>&v=<vista>&h=<hora>&exp=1` e chama `window.EXPORT()` (`exportar.js`): um glb
da base, um glb por grupo `estado_*` (tapete, alçapão) e um json com hora, luzes, brilhos, caixas que só fazem
sombra e névoa. Como o Godot 4.3 não lê `extras`, as marcas do material vão no nome
(`k12__add_unlit_semnevoa_semsombra_dentro_emi120`). `finalizar.mjs` (gltf-transform) junta malhas, tira o metal
e gera normais chapadas onde o protótipo usa `flatShading`. Copie para `assets/3d/missao1/` e rode
`godot --headless --path . --import` (senão o Godot usa o cache antigo).

## 2. Colisão e dados do jogo

    node col.js                                     # grava out/colj_<id>.png e .json
    cp out/colj_<id>.json tools/cenarios3d/missao1/colisao/<id>.json
    python3 tools/cenarios3d/missao1/gerar_dados.py # grava data/cenarios/<id>.json

O mapa é um corte da própria cena entre 35 cm e 1,75 m do piso, visto de cima (degraus e tapetes não bloqueiam;
portas ficam livres). `gerar_dados.py` converte para unidades da sala (64 por metro, origem no canto da área) e
acrescenta início, saídas, pistas, zonas, invasão e inimigos. Os textos e posições marcados `provisorio` são
escolhas do Claude.

### Delegacia ampliada (13/11/2026)

O Léo achou a delegacia apertada no jogo (salas de 4,4 a 5,2 m, portas de 1,2 m) e escolheu o modelo B entre três:
a mesma planta do modelo C com tudo 35% maior, portas internas de 1,8 m e os móveis altos só nas paredes do fundo.
Em `delegacia.js` as paredes e os pisos escalam e os móveis são agrupados por sala e mantêm a distância até a parede
(até 1 m); `?am=A|B|C|O` troca o modelo (O = planta de 12/11, guardada também em `delegacia_v1.js`). As grades das
celas ganharam uma travessa a 1 m, senão o mapa de colisão não as via e o grupo atravessava. Os pontos de jogo
(pistas, alçapão, chegadas, invasão, saída) saem já convertidos em `PONTOS`, que `col.js` grava no json da colisão e
`gerar_dados.py` usa.

## 3. No jogo

- `scripts/exploration/cenario3d.gd`: carrega o glb e o json, monta luzes, névoa e o filtro PC antigo.
- `scripts/exploration/local3d.gd` + `scenes/exploration/local3d.tscn`: herda o parque (grupo, pistas, combate)
  e lê o lugar em `Missao1.local` (`scripts/core/missao1.gd`).
- `scripts/exploration/pathfinder_grade.gd`: caminho em grade (A* nativo) para mapas com centenas de obstáculos.
- Captura: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_local3d.gd -- saida.png <id> [marca] [chegada=subsolo] [zoom=1]`
  e, só o cenário na vista do protótipo, `tools/capturar_cenario3d.gd`.
- Teste: `godot --headless --path . -s tests/test_local3d.gd`.

## Luz: o que foi medido (Compatibility 4.3)

- O SubViewport entrega a imagem já em sRGB (não linear): o filtro recebe `entrada_srgb = true`.
- three.js divide o difuso por pi e o Godot não: sol, ambiente, céu e luzes pontuais × 0,34.
- A queda das luzes pontuais é a mesma fórmula do three.js (use o `decay` de cada luz como `omni_attenuation`).
- A luz com sombra soma num passe em sRGB e sai clara demais: o sol é corrigido para um chão de cor média 0,1.
- Transparência mistura em sRGB: aditivos ×1,3, halos ×2,2, camadas claras sem luz (névoa rasteira, teias) com
  alfa^0,7 (`sobreposto.gdshader`); a névoa de distância lê a tela e mistura em linear (`neblina_exata.gdshader`).
- glTF BLEND chega como ALPHA_DEPTH_PRE_PASS: trocar para ALPHA (no protótipo os decalques não escrevem profundidade).
- Diferença média da imagem final contra o protótipo: delegacia 17h 4,0; 21h 5,2; subsolo 2,3; biblioteca 3,6; fazenda 4,7.
