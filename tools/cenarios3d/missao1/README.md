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

### Paredes inteiras e limite de cada lugar (13/11/2026)

O corte de colisão olha de cima, então parede inteira (3,8 m) atravessava a câmera do corte e só mostrava as faces
de perfil: as paredes do fundo e da lateral da delegacia e da biblioteca não bloqueavam. Agora `colisao.js` achata
para dentro da faixa as caixas e os cilindros em pé que cruzam o topo do corte. O subsolo continua com o mapa
antigo (a escada é uma caixa alta e fecharia a saída). `gerar_dados.py` também fecha tudo fora do limite de cada lugar
(prédio mais a calçada da frente; no celeiro, o terreiro), para o grupo não dar a volta pela rua.

### Cripta (14/11/2026)

O Léo escolheu o modelo C (Fosso de sangue) entre três, na 3ª rodada. As fontes do protótipo ficam em
`/mnt/project-files/arte/cripta/jogo/` (`cripta.js`, que roda com as fontes acima).

    node exp.js cripta dentro 23 cripta                       # base + cripta_trecho2..4 (grupos `estado_trecho*`)
    node finalizar.mjs exp/cripta.glb exp/f_cripta.glb 7      # repete para cada trecho; 7 = célula de 7 m
    node col_cripta.js                                        # out/colj_cripta.json -> colisao/cripta.json

- **Trechos:** cada trecho é um glb à parte, desligado até o líder pisar numa faixa (`zonas` com `acao: estado`).
- **Células:** a cripta tem 41 luzes e o Compatibility ilumina cada malha com um número limitado delas
  (`max_lights_per_object`, subido para 24 no projeto). `finalizar.mjs` com o terceiro argumento só junta malhas
  dentro de cada célula do chão.
- **Dois níveis:** `colisao2.js` corta a cena no chão e a 1,5 m (terraço e galeria) e une os dois pelas escadas
  (`nivel(x,z)` em `cripta.js`). Para o jogo sai um plano só: `retangulos` é o que barra o passo (inclui a borda
  entre o alto e o chão) e `visao` é o que barra a visão (sem parapeito, fosso, altar, sarcófago e banco, marcados
  com `userData.baixo`). `pontos.niveis` leva as áreas elevadas, que no jogo só mudam a altura do desenho.

### Necrotério e casa do Velho Geraldo (22/11/2026)

Dois lugares novos, livres depois da delegacia das 17h (o grupo escolhe a ordem, em qualquer sequência). As fontes ficam
em `/mnt/project-files/arte/cenarios-missao1/fonte/` (`necrotorio.js`, `casa_geraldo.js`; o `kit.js` ganhou as horas 18 e 20
e a cor opcional em `glow`). O `cena.html` precisa do `ni_lp.glb` ao lado (está em `/mnt/project-files/arte/estilo-pc-antigo/`).

    node exp.js necrotorio dentro 18 necrotorio        # base + necrotorio_arrombada (gaveta aberta, porta amassada, sangue)
    node exp.js casa_geraldo fora 20 casa_geraldo      # exterior inteiro; a casa não se explora por dentro
    node finalizar.mjs exp/<nome>.glb exp/f_<nome>.glb # para cada glb
    node colnew.js                                     # colisão dos dois (a casa usa a vista `fora`)

- **Necrotério (18h):** escritório do legista (mesa, arquivos, estante) e sala de autópsia montada a partir do mapa de referência do
  Léo (`historia/referencias/mapa-necroterio.jpg`): seis gavetas de inox no fundo, mesa com pia, três banquinhos, armário alto, carrinho
  tombado, bancada e o balde rosado de luz verde. O estado `arrombada` entra no meio da cena do Tutu (passo `estado` do CenaRoteiro).
- **Casa do Geraldo (20h):** terreno cercado com buracos, casa vermelha de janelas tapadas, varanda com cadeira de balanço e lampião,
  árvores secas. A porta da casa é um retângulo de colisão extra (as portas ficam livres no mapa).
- **Escolha de destino:** zonas `acao: "destinos"` (delegacia 17h, biblioteca, necrotério, casa) abrem o menu `Missao1.DESTINOS_LIVRES`;
  cada lugar marca `visitou_<id>` ao chegar; com os três vistos a saída leva à delegacia das 21h.
- **Provisório:** horas fixas (necrotério 18h, biblioteca 19h, casa 20h, não pela ordem de visita), subida de atitude do Geraldo fixa
  (o teste de Diplomacia DT 20 não existe), textos das pistas, posições, despedida da Letícia.

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
