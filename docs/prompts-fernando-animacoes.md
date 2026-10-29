# Prompts do Fernando: ataques (pistola, escopeta, soco), dano e morte (para colar no ChatGPT)

Anexe a ficha do Fernando (a mesma das folhas de andar) e cole o bloco de regras abaixo mais UMA das poses. Uma direção por imagem, sempre na mesma conversa, como nas folhas de andar. Comece pela direção SE e me mande para testar antes de pedir as outras quatro (E, NE, S, N).

**Armas (decisão do Léo para o GDD):** o Fernando usa **pistola** e **escopeta**, e o corpo a corpo é um **soco** padrão. Por isso são três folhas de ataque por direção (pistola, escopeta, soco), mais a folha de dano e morte. Comece pela direção SE de cada uma e me mande antes de pedir as outras quatro (E, NE, S, N).

## Bloco de regras (cole em TODO pedido)

```
Pixel art game sprite for a dark horror / noir isometric tactical RPG (1930s-40s feeling).
Use the attached character reference sheet: keep EXACTLY the same character design, outfit, colors and proportions (black jumpsuit with belts, beard, boots).

Style rules:
- Pixel art with chunky, clearly visible pixels and hard edges. NO anti-aliasing, NO blur, NO gradients, NO painterly look, NO 3D render look.
- 1-pixel dark outline around the whole silhouette. Shading in flat blocks of color. Light from the top-left.
- Dark, desaturated palette, at most about 24 colors for the whole character. Warm colors only on skin and leather.
- Realistic proportions, about 7 heads tall. Not chibi, not cartoon.
- Classic isometric RPG camera: looking down at the character from about 30 degrees above.
- Keep the SAME pixel size and the SAME character height as in the walking sheets: a standing figure is as tall as in the idle pose of those sheets.

Image rules:
- Background: one flat solid pure magenta (#FF00FF) and nothing else. No floor, no ground shadow, no gradient, no vignette. Never use magenta on the character.
- No text, no labels, no numbers, no grid lines, no cell borders, no watermark.
- Every figure has the SAME scale. The feet (or the lowest point of the body) of every figure rest on the same horizontal line. Figures never touch each other or the image edges.
- The outfit, colors and details must be identical in every pose.
- Muzzle flash and impact effects stay small, inside the cell, drawn in flat pixel colors (no glow, no blur).
```

## Pose A1: ataque com pistola

```
Make a sprite sheet of this character on one 1536x1024 image: a grid of 4 columns x 2 rows, 8 poses, each in a cell of 384x512, centered in its cell, feet on a line about 90% down the cell.
The character faces [DIRECTION].
He holds a small semi-automatic pistol (1930s-40s style) in his right hand. Poses, in reading order (left to right, top to bottom):
1. Ready: pistol lowered at his side, weight on both feet.
2. Raise: pistol coming up, body turning slightly toward the target.
3. Aim: arm extended, pistol pointing at the target, feet braced.
4. Fire: same aim, small muzzle flash at the barrel, shoulders pushed back a little.
5. Recoil: pistol kicked up, arm bent, head slightly back.
6. Recover: pistol coming back down, arm bending.
7. Lower: pistol almost at his side.
8. Ready again: same as pose 1 (the loop closes).
Same character in all 8 poses.
```

## Pose A2: ataque com escopeta

```
Make a sprite sheet of this character on one 1536x1024 image: a grid of 4 columns x 2 rows, 8 poses, each in a cell of 384x512, centered in its cell, feet on a line about 90% down the cell.
The character faces [DIRECTION].
He holds a double-barrel or pump-action shotgun (1930s-40s style) with both hands. Poses, in reading order (left to right, top to bottom):
1. Ready: shotgun held across the body at low ready, weight on both feet.
2. Raise: shotgun coming up to the shoulder, body turning toward the target.
3. Aim: stock against the shoulder, cheek on the stock, feet braced wide.
4. Fire: same aim, bigger muzzle flash at the barrel, whole body pushed back.
5. Recoil: barrel kicked up, shoulders thrown back, head up.
6. Rack: pump or reload motion, shotgun lowered a little, one hand sliding on the fore-end.
7. Lower: shotgun coming down to low ready.
8. Ready again: same as pose 1 (the loop closes).
Same character in all 8 poses.
```

## Pose A3: soco (corpo a corpo padrão)

```
Make a sprite sheet of this character on one 1536x1024 image: a grid of 4 columns x 2 rows, 8 poses, each in a cell of 384x512, centered in its cell, feet on a line about 90% down the cell.
The character faces [DIRECTION].
He fights bare-handed. Poses, in reading order (left to right, top to bottom):
1. Guard: fists raised near his chin, knees slightly bent.
2. Wind-up: weight shifts to the back foot, right fist pulled back, shoulders turning.
3. Step in: front foot steps forward, body leaning into the punch.
4. Impact: right arm fully extended in a straight punch, body stretched forward, a tiny flat impact mark at the fist.
5. Follow-through: arm still extended, back foot lifted on its toes.
6. Pull back: arm returning, weight coming back.
7. Reset: guard rising again, feet coming back to the start.
8. Guard again: same as pose 1 (the loop closes).
Same character in all 8 poses.
```

## Pose B: dano e morte

```
Make a sprite sheet of this character on one 1536x1024 image: a grid of 4 columns x 2 rows, 8 poses, each in a cell of 384x512, centered in its cell, the standing feet on a line about 90% down the cell.
The character faces [DIRECTION].
Poses, in reading order (left to right, top to bottom):
1. Hit: struck from the front, head and chest thrown back, one arm flung out.
2. Stagger: bent forward, one hand pressed to his torso, feet scrambling to stay up.
3. Recover: straightening up, breathing hard, shoulders heavy.
4. Collapse 1: knees giving way, one hand on the ground, head down.
5. Collapse 2: falling to his knees, body tilting sideways.
6. Collapse 3: toppling to the ground, one shoulder touching it.
7. Collapse 4: lying on his side, limbs loose.
8. Dead: lying still on the ground, face turned slightly away. Keep him inside his cell.
Same character in all 8 poses. No blood pools or gore: at most a few small dark red pixels on the clothes.
```

Poses 1 a 3 são o "dano" (tomar um golpe e se recuperar); 4 a 8 são a morte, que o GDD pede roteirizada no fim da primeira missão. Se você quiser só o dano agora, peça a imagem e eu uso só os três primeiros quadros.

## Direções (mesma tabela do guia)

| Direção | Valor para `[DIRECTION]` |
| --- | --- |
| SE | `SOUTH-EAST: toward the lower-right corner of the screen, three-quarter front view` |
| NE | `NORTH-EAST: toward the upper-right corner of the screen, three-quarter back view, mostly his back and right shoulder` |
| E | `EAST: toward the right of the screen, pure side view` |
| S | `SOUTH: toward the camera, straight front view` |
| N | `NORTH: away from the camera, straight back view` |

Nome dos arquivos: `fernando_pistola_se.png`, `fernando_escopeta_se.png`, `fernando_soco_se.png`, `fernando_dano_se.png` e assim por diante.
