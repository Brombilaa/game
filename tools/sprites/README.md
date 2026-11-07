# Conversor de sprites do ChatGPT

Transforma a folha de poses gerada no ChatGPT (fundo magenta, grade de 4×2 por padrão)
em quadros prontos para o jogo. Segue `docs/guia-sprites-chatgpt.md`.

```
pip install numpy scipy pillow
python3 -I tools/sprites/converter.py saida/ se=nikolai_se_raw.png e=nikolai_e_raw.png ne=nikolai_ne_raw.png \
    s=nikolai_s_raw.png n=nikolai_n_raw.png --prefixo nikolai --altura 128 --quadro 192 --pes 12 --cores 32
```

Cada entrada é `direção=arquivo`. Para cada uma sai `<prefixo>_<direção>.png`, uma fila de 8 quadros (2 parado, 6 andando).

- `--altura`: altura final do personagem em pixels. A escala é única: a altura média do quadro parado de todas as direções vira esse valor, para o personagem não mudar de tamanho ao girar.
- `--quadro`: lado do quadro final; os pés ficam no centro, `--pes` px acima da borda de baixo (o jogo usa quadro 192 e pés 12; o pivô de `CharacterSheet` acompanha).
- `--cores`: tamanho da paleta única, compartilhada por todas as direções.

O jogo lê as cinco folhas (SE, E, NE, S, N) e espelha SE, E e NE para obter SO, O e NO (`CharacterSheet`).
Com o Nikolai (29/10/2026) as alturas de origem variaram menos de 3% entre as direções; o conversor avisa quando passa de 8%.

## Peças de cenário (`cenario.py`)

Folhas de chão, paredes e móveis do ChatGPT (originais em `/mnt/project-files/arte/cenario_originais/`):

```
python3 -I tools/sprites/cenario.py chao  assets/sprites/cenario/salas_2d chao_raw.png --prefixo chao --ignorar 4
python3 -I tools/sprites/cenario.py parede assets/sprites/cenario/salas_2d paredes_raw.png --prefixo parede --largura 96 \
    --nomes x_lisa,x_janela,x_vao,x_quebrada,y_lisa,y_janela,y_vao,y_quebrada
python3 -I tools/sprites/cenario.py movel assets/sprites/cenario/salas_2d moveis_raw.png --prefixo movel \
    --nomes estante,escrivaninha,cadeira,cama,caixote,guarda_roupa,candelabro,porta,mesa_redonda \
    --ajustes cadeira=0.65,caixote=0.6,mesa_redonda=0.6,cama=0.85,escrivaninha=0.8,porta=0.85,estante=0.9
```

- `chao`: cada losango vira um tile exato de 96×48. `--ignorar N` pula o N-ésimo (o carpete, em ordem de leitura, foi descartado a pedido do Léo).
- `parede`: escala única pela largura média (96 px = 2 losangos ao longo do eixo). `x_*` corre pelo eixo x (parede norte), `y_*` pelo eixo y (oeste e parede da porta).
- `movel`: a primeira figura da folha é o herói de referência (128 px) e dá a escala; `--ajustes` corrige móveis que o ChatGPT desenhou grandes demais.
- Cada folha gera um JSON com a âncora da peça (meio da base da parede, pés do móvel) (o cenário em arte saiu da sala de teste em 05/11/2026).
