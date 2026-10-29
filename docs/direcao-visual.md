# Direção visual e arte

Fonte: GDD técnico v0.2 (27/10/2026), seções 1, 2, 12, 13, 14.1 e Anexo F.
Este documento registra o que o GDD aprova, o que o Léo decidiu depois e o que já existe no repositório.
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

## 2. Decisões do Léo (registro no formato do Anexo H)

Confirmadas pelo Léo em 29/10/2026 na thread de direção visual. Status de
implementação de todas: **não implementado**.

| ID | Assunto | Estado anterior | Nova decisão | Impactos |
| --- | --- | --- | --- | --- |
| DEC-2026-10-29-01 | Perspectiva da câmera (V-01) | PENDENTE (§13, Anexo F) | Vista de cima em 3/4. | Sprites, tilesets, ordenação de profundidade, LOS, cobertura. |
| DEC-2026-10-29-02 | Resolução interna (V-02) | PENDENTE (§14.1) | Começar em 640×360. Resoluções internas maiores podem vir depois, então a arte não deve depender de 640×360 ser definitivo. | `project.godot`, sala de teste (hoje desenhada em coordenadas 1280×720), HUD. |
| DEC-2026-10-29-03 | Direções de animação (V-04) | PENDENTE (Anexo F) | 4 direções inicialmente; diagonais entram depois para dar fluidez (8 no total). | Spritesheets, nomenclatura, escolha de direção no movimento. |
| DEC-2026-10-29-04 | Paleta (V-05) | PENDENTE (§13) | Paleta fechada e escura para a fase de testes; a paleta final continua aberta. | Todos os sprites e tiles de teste, UI. |
| DEC-2026-10-29-05 | Estilo e tamanho do personagem (V-03) | PENDENTE (§13, Anexo F) | Seguir o estilo da referência `arte/referencias/personagem-detetive-noir.png` (pasta de arquivos do projeto, fora do Git) (inspiração, não cópia), em versão menor. Tamanho derivado pelo Claude a partir da referência: personagem com cerca de 48 px de altura (quadro de 32×48) e tile de 16×16 em 640×360. Léo pode ajustar depois do primeiro sprite de teste. | Spritesheets, colisão/raio dos personagens, escala do cenário, retratos. |

## 3. Configuração técnica já no repositório

Estas são escolhas de implementação feitas no esqueleto do projeto (PR #2), não
decisões de arte. Podem mudar quando as pendências abaixo forem fechadas.

- Godot 4.3, renderer GL Compatibility.
- Janela base 1280×720, stretch `canvas_items`, aspecto `keep`.
- Filtro de textura padrão `nearest` (sem borrar pixels).
- Arte versionada com Git LFS em `assets/sprites/`, `assets/fonts/`, `assets/audio/`.
- A sala de teste usa formas geométricas como placeholder; não há sprite ainda.

## 4. Pendências para o Léo

O GDD marca a especificação de assets como PENDENTE (§13: resoluções, formatos,
proporções, spritesheets, transparência, perspectiva, nomenclatura e organização).
Cada item abaixo precisa de uma resposta antes da produção ampla de sprites.

| # | Pergunta | Recomendação do Claude (não aprovada) |
| --- | --- | --- |
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

## 5. Leitura da referência de personagem

O que a referência (`arte/referencias/personagem-detetive-noir.png` (pasta de arquivos do projeto, fora do Git)) pede, e como isso
vira regra de produção:

- **Proporção realista**, cerca de 7 cabeças de altura, sem estilo chibi. Por isso o
  personagem precisa de uns 48 px de altura: com 32 px a silhueta vira boneco e
  some o detalhe de roupa.
- **Silhueta forte** (chapéu, sobretudo longo, ombros). Em 48 px o que identifica o
  personagem é a silhueta e um ou dois acessórios de cor (o coldre marrom), não o rosto.
- **Rosto e expressão ficam nos retratos** do HUD e das falas (V-09), onde cabem
  bigode, olhar e textura de pele como nos closes da referência.
- **Paleta escura e quente**: pretos e cinzas para roupa, marrom de couro como
  destaque, bege de pele, fundo sépia. Bate com a DEC-2026-10-29-04 e serve de base
  para a paleta de teste.
- **Sombreamento por blocos de cor, sem anti-aliasing suave** e contorno escuro,
  para ler bem sobre um chão escuro.
- **Ficha de virada** (frente, lado, costas) já casa com as 4 direções da
  DEC-2026-10-29-03.

## 6. Próximos passos

1. Claude ajusta o projeto para 640×360 com escala inteira e adapta a sala de teste a essa resolução.
2. Claude cria a paleta escura de teste e um personagem placeholder de 32×48 em 4 direções, mais um tile de chão 16×16.
3. Léo avalia o sprite de teste na sala e confirma ou ajusta o tamanho.
4. Cada nova resposta do Léo entra na seção 2 no formato do Anexo H.
