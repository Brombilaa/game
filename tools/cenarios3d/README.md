# Cenário 3D do parque para o Godot (opção 3 do Léo, 06/11/2026)

O cenário v16 nasce no protótipo three.js (`/mnt/project-files/arte/estilo-pc-antigo/parque3d_bake.html`).
Para levar ao Godot:

1. Insira `exportScene.js` no HTML do protótipo (e o import do `GLTFExporter`), sirva a pasta por HTTP
   (com `node_modules/three@0.160`) e rode `exportar_cenario.js` (playwright). Ele chama `bake` (para aplicar a mesma
   visibilidade da câmera do jogo), exporta só o que está na janela x −16..36, z −14..30 e grava `parque_cenario.glb` (~22 MB).
2. Reduza com `@gltf-transform/cli`: `dedup`, `flatten`, `join`, `weld` (22 MB → ~11 MB, 89 malhas).
3. Copie para `assets/3d/parque/parque_cenario.glb`.

Personagem: FBX "With Skin" do Mixamo → importado pelo Godot → gravado como glb (`GLTFDocument.append_from_scene`) →
`resize 1024`, `weld`, `simplify --ratio 0.07 --error 0.01` (224 mil → 17 mil vértices, 3,5 MB).
As animações vêm dos FBX do Mixamo (só esqueleto) em `assets/3d/animacoes/`; as trilhas usam `Skeleton3D:mixamorig_*`.

Captura: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s tools/capturar_parque3d.gd -- saida.png [graus]`.

Depois do `join`/`weld`, troque `metallicFactor` 0.5 por 0 e `roughnessFactor` 0.5 por 1 no JSON do glb (o exportador usa 0.5; sem isso o Godot escurece tudo).
Visual: shader `assets/3d/pc_antigo.gdshader` (névoa 15%, lavagem leve, 16 bits com dithering). Luz do Godot: sol 0,25 e ambiente 0,3, ajustadas por comparação numérica com o render de referência do three.js.
