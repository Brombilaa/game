# Render 3D do Nikolai (D3)

Gera as folhas `assets/sprites/personagens/nikolai3d/nikolai3d_<animação>_<dir>.png` a partir do FBX "With Skin" do Mixamo
(`/mnt/project-files/arte/modelo3d/fbx_with_skin/`) e dos FBX de animação só de movimento.

1. Servir a pasta com `render2.html`, `skin.fbx`, os FBX e `three/` (three.js 0.160) em `python3 -m http.server 8125`.
2. Renderizar cada animação (cor e normais, 5 direções): `PAGE=render2.html node frames2.js "hp=12&lift=16&ref=first" "Shooting" 8 0,1,2,3,4 r/pistol_shoot`.
   `ref=first` ancora o quadro inicial (ataques, morte), `ref=last` o final (levantar); sem `ref` o movimento é centrado pela média (andar, correr).
   Quadro maior (soco, chute, morte, levantar): acrescentar `w=1728` (morte `w=2112`).
3. `python3 -I build_combate.py r <saída>` pixeliza (paleta de `r/walk`, `r/idle`, `r/run`, contorno na cor do tecido) e alinha os pés em 368.

Quadros: 384×384; soco, chute e levantar 576×512; morte 704×512 (ver `AnimSheet.FRAME_OF`).
