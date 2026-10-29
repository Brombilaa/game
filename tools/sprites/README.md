# Conversor de sprites do ChatGPT

Transforma a folha de poses gerada no ChatGPT (fundo magenta, grade de 4×2 por padrão)
em quadros prontos para o jogo. Segue `docs/guia-sprites-chatgpt.md`.

```
pip install numpy scipy pillow
python3 -I tools/sprites/converter.py nikolai_e_raw.png saida/ --altura 96 --quadro 144 --cores 24
```

- `--altura`: altura final do personagem em pixels (a mesma escala vale para todas as poses).
- `--quadro`: lado do quadro final; os pés ficam no centro, 8 px acima da borda de baixo.
- `--cores`: tamanho da paleta única de todos os quadros.

Saída: `quadro_0.png` a `quadro_7.png` e `folha.png` (os 8 quadros em fila). Primeiro teste, com o Nikolai
em 29/10/2026: as 8 poses saíram alinhadas, e a diferença de altura entre parado (440 px) e andando (~422 px)
é natural, por isso a escala é única.
