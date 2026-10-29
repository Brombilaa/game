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
