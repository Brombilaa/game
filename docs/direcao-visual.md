# Direção visual e arte

Fonte: GDD técnico v0.2 (27/10/2026), seções 1, 2, 12, 13, 14.1 e Anexo F.
Este documento só registra o que o GDD aprova e o que já existe no repositório.
Tudo o que o GDD não cobre está em **Pendências**, com uma recomendação do Claude
quando houver, que só vale depois de aprovada pelo Léo.

## 1. Decisões aprovadas no GDD

| Tema | Decisão | Origem |
| --- | --- | --- |
| Estilo | Pixel art. | §13 |
| Referência visual | Enigma do Medo, como referência e não como cópia. | §1, §13 |
| Pilar | Pixel art com animações específicas e feedback legível. | §2 |
| Animação de interação | Cada tipo de interação tem animação própria, não uma genérica. | §13, B.4 |
| Animação de combate | Armas semelhantes podem compartilhar animações básicas; habilidades especiais podem ter animações próprias. | §13 |
| Descanso | Tem animação/passagem de tempo (duração pendente). | §11, §13 |
| Diálogo | Texto na tela, sem dublagem; sons vocais não verbais permitidos. | §13, B.4 |
| HUD de exploração | Retratos dos protagonistas, PV, SAN, estados, itens rápidos, minimapa, objetivo atual e acesso ao inventário/mapa. | §12 |
| Navegação | Sem linha de caminho no chão; direção do objetivo só no minimapa. | §12 |
| Minimapa | Mostra direção dos objetivos principais; inimigos só quando vistos por um protagonista. | §12, B.12 |
| Mapa completo | Revelado aos poucos; principais já marcados, secundários após descoberta. | §12 |
| Transição de área | Tela com o nome do local. | §12 |
| Cenários | Majoritariamente planos, com elevações ocasionais (afeta a leitura visual de altura). | §6.5 |

## 2. Configuração técnica já no repositório

Estas são escolhas de implementação feitas no esqueleto do projeto (PR #2), não
decisões de arte. Podem mudar quando as pendências abaixo forem fechadas.

- Godot 4.3, renderer GL Compatibility.
- Janela base 1280×720, stretch `canvas_items`, aspecto `keep`.
- Filtro de textura padrão `nearest` (sem borrar pixels).
- Arte versionada com Git LFS em `assets/sprites/`, `assets/fonts/`, `assets/audio/`.
- A sala de teste usa formas geométricas como placeholder; não há sprite ainda.

## 3. Pendências para o Léo

O GDD marca a especificação de assets como PENDENTE (§13: resoluções, formatos,
proporções, spritesheets, transparência, perspectiva, nomenclatura e organização).
Cada item abaixo precisa de uma resposta antes da produção ampla de sprites.

| # | Pergunta | Recomendação do Claude (não aprovada) |
| --- | --- | --- |
| V-01 | Perspectiva da câmera: vista de cima, 3/4 (estilo Enigma do Medo) ou isométrica? | 3/4 vista de cima. Combina com a referência e simplifica pathfinding, linha de visão e cobertura em 2D. Isométrica custa mais em arte e em ordenação de profundidade. |
| V-02 | Resolução interna (a "tela" em pixels de arte antes de ampliar). | 640×360 com escala inteira (×2 = 1280×720, ×3 = 1920×1080). Hoje o projeto escala 1280×720 direto, o que não garante pixels nítidos. |
| V-03 | Tamanho do personagem e do tile. | Tile de 16×16 e personagem com cerca de 16×32. Dá leitura boa em 640×360 sem exigir arte muito detalhada. |
| V-04 | Quantas direções cada personagem anima (4 ou 8)? | 4 direções no protótipo; avaliar 8 depois do vertical slice. |
| V-05 | Paleta: tamanho e tom. Paleta fechada (ex.: 32 cores) ou livre? | Paleta fechada definida antes dos primeiros sprites, com base escura e cores de destaque para leitura de PV, SAN, perigo e interação. |
| V-06 | Os elementos de Ordem Paranormal (Sangue, Conhecimento, Morte, Energia) terão cor própria no jogo? | O GDD diz para não atribuir elementos ao jogo sem confirmação, então fica com o Léo. |
| V-07 | Cada missão (Brasil, Roma, bunker na Rússia, Nordeste, ilha) terá tileset e paleta própria? | Sim, um tileset por missão sobre a mesma paleta base, começando pela missão do Brasil. |
| V-08 | Iluminação: luz dinâmica e sombras (lanterna, escuridão) fazem parte do estilo? | Testar no protótipo de exploração antes de decidir; afeta furtividade e desempenho. |
| V-09 | Estilo e tamanho dos retratos do HUD e das falas. | Retratos de 48×48 ou 64×64 em pixel art, com variações de expressão a definir. |
| V-10 | Fonte de UI: pixel font ou fonte comum? Precisa de acentos do português. | Pixel font com licença livre e suporte a acentos, em tamanho inteiro da resolução interna. |
| V-11 | Layout detalhado do HUD e do inventário (§12 deixa para a etapa de UI/UX). | Aguardar mockup de UX (papel do ChatGPT no GDD) e implementar depois. |
| V-12 | Feedback de combate: números, ícones e efeitos de acerto, erro e crítico (B.6). | Números flutuantes e ícones simples no protótipo; FX finais depois. |
| V-13 | Feedback de falha de interação (porta trancada, objeto inacessível) (B.4). | Fala curta do personagem em texto mais um som não verbal. |
| V-14 | Ferramenta de arte e formato de entrega. | Aseprite, exportando spritesheet PNG com transparência e JSON de frames. |
| V-15 | Nomenclatura e pastas dos assets. | `assets/sprites/<categoria>/<nome>_<acao>_<direcao>.png`, ex.: `personagens/nikolai_andar_sul.png`. |
| V-16 | Quem produz a arte final (Léo, artista contratado, assets de terceiros)? | Decisão do Léo; muda prazo e o nível de detalhe viável. |
| V-17 | Formato da introdução (cutscene, imagens, texto ou combinação) (§3.1). | Decisão de narrativa do Léo; afeta quantas ilustrações grandes serão necessárias. |

## 4. Próximos passos

1. Léo responde V-01 a V-05 (bloqueiam qualquer sprite).
2. Claude ajusta o projeto para a resolução interna aprovada e cria um sprite e um tile de teste na sala de exploração.
3. Registrar cada resposta no formato do Anexo H (DEC-AAAA-MM-DD-NN) e mover o item para a seção 1.
