# Cenário 3D do parque para o Godot (opção 3 do Léo, 06/11/2026)

O cenário nasce no protótipo three.js `/mnt/project-files/arte/estilo-pc-antigo/parque3d_bake_estilo_c.html`: caminho de acesso C (asfalto, meio-fio, calçada;
na página o parâmetro `?v=C` é o padrão), folhagem C, copas refeitas e casas refeitas. Sem o caminho C a rua da van volta ao modelo antigo.
O caminho de acesso é uma fita curva com textura própria (asfalto que se mistura com terra e grama) e a laje antiga foi
apagada do chão: use `arte/estilo-pc-antigo/chao_sem_laje_flip.jpg` como `chao.jpg` no passo 3.
Para levar ao Godot:

1. Insira `exportScene.js` no HTML do protótipo (e o import do `GLTFExporter`), sirva a pasta por HTTP
   (com `node_modules/three@0.160`) e rode `exportar_cenario.js` (playwright). Ele chama `bake` (para aplicar a mesma
   visibilidade da câmera do jogo), exporta só o que está na janela x −16..36, z −14..30 e grava `parque_cenario.glb` (~22 MB).
2. Reduza com `@gltf-transform/cli`: `dedup`, `flatten`, `join`, `weld` (22 MB → ~11 MB, 89 malhas).
3. `node finalizar_cenario.mjs entrada.glb saida.glb chao.jpg` (depois de trocar o glb, rode `godot --headless --path . --import`, senão o Godot usa o cache antigo): tira o metal padrão do exportador (0,5) e escurece o vidro
   (metal real) como o three.js faz sem mapa de ambiente; troca a textura do chão pela original (o exportador limita a
   1024 px; `chao.jpg` é o JPEG `planTex` do HTML invertido na vertical); gera normais chapadas, viradas para fora, nos
   materiais marcados com `extras.flat`; e dá a cada material o nome `mN`.
4. Copie para `assets/3d/parque/parque_cenario.glb`.
5. Tons: capture as vistas com e sem `IDMAT=1` (`tools/capturar_parque3d.gd`) e rode `tools/calibrar_tons.py`, que grava
   `assets/3d/parque/tons_materiais.gd` comparando cada material com a referência do JS (com o filtro CSS aplicado).

Personagem: FBX "With Skin" do Mixamo → importado pelo Godot → gravado como glb (`GLTFDocument.append_from_scene`) →
`resize 1024`, `weld`, `simplify --ratio 0.07 --error 0.01` (224 mil → 17 mil vértices, 3,5 MB).
As animações vêm dos FBX do Mixamo (só esqueleto) em `assets/3d/animacoes/`; as trilhas usam `Skeleton3D:mixamorig_*`.

Captura: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_parque3d.gd -- saida.png [graus]`.

Visual: `assets/3d/pc_antigo.gdshader` (o filtro do JS: lavagem, 16 bits com dithering, saturação/contraste do CSS, grão),
`assets/3d/neblina.gdshader` (Fog do JS, 41 a 81 com smoothstep), `assets/3d/oclusao.gdshader` (SSAO) e
`assets/3d/personagem_facetado.gdshader`. Luz: sol 0,22; céu/chão do HemisphereLight = ambiente 0,10 + luz de cima 0,07 + luz de baixo -0,07;
postes 14 com queda 2,2. Tudo medido contra a página do JS.

Copas: as esferas das copas (`jit` no protótipo) agora deslocam cada vértice pela posição, não por triângulo; antes os cantos compartilhados se separavam e a copa saía facetada e com frestas. As copas levam textura de folhas e mais cartões de folhas (gerador próprio de números aleatórios, para não mexer na posição das árvores). O protótipo atualizado está em `arte/estilo-pc-antigo/parque3d_bake_estilo_c.html`.
Vista da van: árvores do entorno que ficam entre a câmera do jogo e a van (corredor de 16 de largura, em coordenadas do protótipo) não entram no cenário, para a copa não cobrir a van.
