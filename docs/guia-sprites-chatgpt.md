# Guia para gerar sprites no ChatGPT

Para o Léo. Explica o que pedir ao ChatGPT para gerar os personagens e o cenário do jogo,
em vista isométrica, de um jeito que o Claude consiga converter em sprites do jogo.
Decisões que sustentam este guia: DEC-2026-10-29-08 e 09 em `direcao-visual.md`.

Os valores marcados como **proposta** ainda não foram aprovados e estão em V-21 e V-22.
Os prompts estão em inglês porque o gerador de imagens obedece melhor assim.

## 1. Como o processo funciona

1. Você pede ao ChatGPT as imagens, usando a ficha do personagem como referência (a ficha do detetive noir é o modelo).
2. Você me envia os PNGs aqui na thread, um por direção, com o nome combinado (seção 6).
3. Eu removo o fundo, recorto cada quadro, alinho os pés, reduzo para o tamanho do jogo, troco as cores por uma paleta única e monto a folha de sprites.
4. Eu mostro o resultado dentro do jogo e a gente ajusta o que ficou estranho.

O ChatGPT não desenha pixels exatos nem respeita grade com precisão. Por isso o prompt pede fundo magenta chapado,
e eu corrijo escala, alinhamento e paleta depois. Comece **só com o Nikolai, direção sudeste** (seção 5): com essa primeira
imagem eu ajusto o processo e o prompt antes de você gastar tempo com os outros.

## 2. Especificação (proposta)

| Item | Valor |
| --- | --- |
| Vista | Isométrica 2:1, câmera olhando de cima uns 30 graus (como Baldur's Gate ou Fallout 2) |
| Altura final do personagem | 96 px na tela interna de 960×540 (DEC-2026-10-29-10) |
| Quadro final | 144×144 px, pés no centro, 8 px acima da borda de baixo |
| Direções | 8 no total, mas só 5 são desenhadas (S, SE, E, NE, N); as outras 3 são o espelho |
| Primeira leva (DEC-03) | As 4 diagonais da tela (SE, SW, NW, NE) = só 2 desenhos: SE e NE |
| Animações da primeira leva | Parado (2 quadros) e andando (6 quadros) |
| Tile do chão | Losango 96×48 (2:1) |

O espelho tem um custo: o coldre e a bolsa trocam de lado nas direções espelhadas. Se isso importar para algum personagem, desenhe a direção espelhada à parte.

## 3. Bloco de regras (cole em TODO pedido)

```
Pixel art game sprite for a dark horror / noir isometric tactical RPG (1930s-40s feeling).
Use the attached character reference sheet: keep EXACTLY the same character design, outfit, colors and proportions.

Style rules:
- Pixel art with chunky, clearly visible pixels and hard edges. NO anti-aliasing, NO blur, NO gradients, NO painterly look, NO 3D render look.
- 1-pixel dark outline around the whole silhouette. Shading in flat blocks of color. Light from the top-left.
- Dark, desaturated palette, at most about 24 colors for the whole character. Warm colors only on skin and leather.
- Realistic proportions, about 7 heads tall. Not chibi, not cartoon.
- Classic isometric RPG camera: looking down at the character from about 30 degrees above.

Image rules:
- Background: one flat solid pure magenta (#FF00FF) and nothing else. No floor, no ground shadow, no gradient, no vignette. Never use magenta on the character.
- No text, no labels, no numbers, no grid lines, no cell borders, no watermark.
- Every figure has the SAME scale. The feet of every figure rest on the same horizontal line. Figures never touch each other or the image edges.
- The outfit, colors and details must be identical in every pose.
```

## 4. Bloco de pose (cole depois das regras)

Troque `[DIRECTION]` pela linha da tabela. Peça uma direção por imagem, sempre na mesma conversa em que você enviou a ficha.

```
Make a sprite sheet of this character on one 1536x1024 image: a grid of 4 columns x 2 rows, 8 poses, each in a cell of 384x512, centered in its cell, feet on a line about 90% down the cell.
The character faces [DIRECTION].
Poses, in reading order (left to right, top to bottom):
1. Idle: standing relaxed.
2. Idle: same stance, chest slightly raised as if breathing (almost identical to pose 1).
3. Walk cycle frame 1: contact, front foot on the ground, arms swinging opposite to the legs.
4. Walk cycle frame 2: weight goes down on the front leg, body at its lowest.
5. Walk cycle frame 3: passing, legs together, body at its highest.
6. Walk cycle frame 4: contact with the other foot forward, arms swapped.
7. Walk cycle frame 5: weight goes down on the other leg.
8. Walk cycle frame 6: passing, legs together.
The coat sways slightly with each step. Same character in all 8 poses.
```

| Direção | Valor para `[DIRECTION]` | Fase |
| --- | --- | --- |
| SE | `SOUTH-EAST: toward the lower-right corner of the screen, three-quarter front view` | 1ª leva |
| NE | `NORTH-EAST: toward the upper-right corner of the screen, three-quarter back view, mostly his back and right shoulder` | 1ª leva |
| E | `EAST: toward the right of the screen, pure side view` | depois |
| S | `SOUTH: toward the camera, straight front view` | depois |
| N | `NORTH: away from the camera, straight back view` | depois |

## 5. Primeiro teste

Envie ao ChatGPT a ficha do Nikolai, cole o bloco de regras (seção 3), o bloco de pose (seção 4) com a direção SE, e me mande a imagem.
Vou mostrar no jogo e dizer se a escala, o alinhamento e a paleta ficaram bons. Se o ChatGPT trocar a roupa entre os quadros,
peça "regenerate keeping exactly the same outfit as pose 1".

Resultado do primeiro teste (Nikolai, 29/10/2026), já convertido e no jogo: o fundo magenta, as 8 poses na grade e o alinhamento funcionaram e a
conversão ficou boa (`tools/sprites/converter.py`). A imagem veio virada para **leste** (de lado, para a direita) e não para
sudeste, então vale como a direção E; para SE, acrescente ao pedido "we see his chest and both shoulders, body turned toward the camera".

## 6. Nome dos arquivos

`<personagem>_<direção>.png`, tudo em minúsculas, sem acento. Exemplos: `nikolai_se.png`, `nikolai_ne.png`, `miguel_se.png`.
Se refizer uma imagem, acrescente `_v2`. Personagens: `rafael`, `miguel`, `nikolai`, `fernando`, e um nome por inimigo.

## 7. Chão e cenário (proposta, depende da V-21)

```
Isometric 2:1 pixel art floor tile set for a dark horror game, flat solid magenta (#FF00FF) background, no text, no grid lines.
6 variations of a dark worn wooden plank floor, one tile each, in a grid of 3 columns x 2 rows, each tile a perfect diamond twice as wide as it is tall (256x128 px).
Chunky visible pixels, hard edges, no anti-aliasing, no gradients, dark desaturated warm brown palette, light from the top-left.
The four edge pixels of each tile must continue seamlessly into a neighboring tile of the same set.
```

Para paredes, portas e coberturas, use o mesmo formato trocando a descrição, e diga a altura em tiles (por exemplo, "a wall segment 2 tiles tall").
Antes de gerar muitas peças, confirme comigo o tamanho do tile (V-21).

## 8. Problemas comuns

- **Pixels de tamanhos diferentes na mesma imagem.** Eu corrijo reduzindo a imagem; peça "all pixels the same size" se estiver muito ruim.
- **Fundo que não é magenta puro, ou com sombra no chão.** Peça de novo. Sombra eu desenho no jogo.
- **Personagem que muda de roupa ou de rosto entre quadros.** Peça de novo na mesma conversa, anexando a ficha.
- **Pés em alturas diferentes.** Eu alinho, desde que cada quadro tenha o personagem inteiro e separado dos outros.
- **Mãos e armas deformadas.** Anote qual quadro e me avise; talvez eu consiga corrigir pixel a pixel.

## 9. O que ainda não funciona

Enviar PNGs para o repositório usa o Git LFS, e o envio é recusado (403) no ambiente da nuvem. Enquanto isso, as folhas
de sprites pequenas (algumas centenas de KB) vão direto no Git, como foi feito com a fonte. Se o volume crescer, será
preciso liberar o LFS nas configurações de rede do ambiente.
