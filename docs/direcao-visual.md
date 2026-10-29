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
| DEC-2026-10-29-06 | Fonte da interface (V-10) | PENDENTE (§14.1) | Usar a Special Elite (Google Fonts, Apache 2.0) em todo o texto do jogo, a pedido do Léo ("gostei da fonte, aplique no jogo também"). Aplicada por `gui/theme/custom_font` em `project.godot`; cobre todos os acentos do português. Para legibilidade, textos pequenos ficam em 8 a 9 px da resolução interna. | Todo o HUD e os textos desenhados na sala. Pode precisar de outra fonte só para números pequenos, se a leitura ficar ruim. |
| DEC-2026-10-29-07 | Tamanho do personagem testado (DEC-05) | Proposto, aguardando teste | Léo viu o personagem de 32×48 e achou o tamanho "aceitável", mas quer mais detalhes. O tamanho segue como está até a nova referência ser analisada (ver V-18 e V-19). | Sprites finais, retratos. |
| DEC-2026-10-29-08 | Vista isométrica (V-18) | DEC-2026-10-29-01: vista de cima em 3/4 | Vista **isométrica**, como na referência da Mansão Rossi ("isométrica é melhor"). Refina a DEC-01. Projeção 2:1 e tile 64×32 são proposta (V-21). A sala de teste continua em 3/4 ortogonal até o protótipo isométrico. | Tiles em losango, ordenação de profundidade, colisão e pathfinding na tela, sprites em direções isométricas. |
| DEC-2026-10-29-09 | Produção da arte final (V-16) | PENDENTE | Os sprites finais serão gerados pelo Léo no ChatGPT. O Claude escreve os prompts (`guia-sprites-chatgpt.md`) e converte as imagens para o jogo. | Pipeline de conversão, paleta única, nomes de arquivo, Git LFS. |

## 3. Configuração técnica já no repositório

Estas são escolhas de implementação feitas no esqueleto do projeto (PR #2), não
decisões de arte. Podem mudar quando as pendências abaixo forem fechadas.

- Godot 4.3, renderer GL Compatibility.
- Janela base 1280×720, stretch `canvas_items`, aspecto `keep`.
- Filtro de textura padrão `nearest` (sem borrar pixels).
- Fonte do jogo: Special Elite (`assets/fonts/`). Exceção ao LFS: o `.ttf` (150 KB) vai direto no Git porque o envio ao LFS foi recusado (403) no ambiente da nuvem; migrar depois com `git lfs migrate import`.
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
| V-11 | Layout detalhado do HUD e do inventário (§12 deixa para a etapa de UI/UX). | Aguardar mockup de UX (papel do ChatGPT no GDD) e implementar depois. |
| V-12 | Feedback de combate: números, ícones e efeitos de acerto, erro e crítico (B.6). | Números flutuantes e ícones simples no protótipo; FX finais depois. |
| V-13 | Feedback de falha de interação (porta trancada, objeto inacessível) (B.4). | Fala curta do personagem em texto mais um som não verbal. |
| V-14 | Ferramenta de arte e formato de entrega. | Aseprite, exportando spritesheet PNG com transparência e JSON de frames. |
| V-15 | Nomenclatura e pastas dos assets. | `assets/sprites/<categoria>/<nome>_<acao>_<direcao>.png`, ex.: `personagens/nikolai_andar_sul.png`. |
| V-17 | Formato da introdução (cutscene, imagens, texto ou combinação) (§3.1). | Decisão de narrativa do Léo; afeta quantas ilustrações grandes serão necessárias. |
| V-19 | Altura do personagem. Na referência ele ocupa cerca de 18% da altura da tela, uns 65 px em 640×360 (hoje 48 px). | Subir para ~64 px, com quadro de 96×96. Léo achou os 48 px aceitáveis; confirmar depois do primeiro sprite real. |
| V-20 | Ordem de implementação do HUD da referência (ver seção 6). | Começar por retratos com PV/SAN, minimapa circular e lista de objetivos, depois barra de itens, menu de interação e aviso do diário. |
| V-21 | Projeção e tamanho do tile isométrico. | Losango 2:1 de 64×32, com personagem de ~64 px. Define o tamanho das peças de chão, parede e cobertura. |
| V-22 | Na vista isométrica, as "4 direções iniciais" (DEC-03) são as 4 diagonais da tela (SE, SW, NW, NE) ou as 4 retas (S, W, N, E)? | As diagonais, que são os eixos do chão isométrico e exigem só 2 desenhos (SE e NE) mais espelho. As retas entram depois, para dar fluidez. |
| V-23 | Git LFS: o envio de PNG é recusado (403) no ambiente da nuvem. | Folhas pequenas vão sem LFS por ora (como a fonte). Se crescer, liberar o host do LFS na rede do ambiente. |

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

## 6. Referência de HUD, mapa e ambiente (Mansão Rossi)

Imagem enviada pelo Léo em 29/10/2026 como "o que eu tinha pensado" para personagens, HUD e mapa:
`arte/referencias/hud-mapa-personagens-mansao-rossi.png` (pasta de arquivos do projeto, fora do Git).
É uma ilustração de conceito: **os números nela (PV 100/110/95, SAN 70/60/65, munição 12/36 e 5/10) são
exemplos e não valem como balanceamento**; o GDD segue como fonte das regras.

O que a referência mostra, e como encaixa no GDD (§12):

| Elemento | Na referência | Situação |
| --- | --- | --- |
| Retratos | Coluna no canto superior esquerdo com os três protagonistas (Miguel, Nikolai, Fernando): retrato, nome, barra vermelha de PV, barra azul de SAN com valor e 3 espaços de habilidade/estado. | Bate com o HUD de exploração do GDD (retratos, PV, SAN, estados). |
| Minimapa | Círculo no canto superior direito com a planta do andar e o marcador do grupo; acima dele, local e andar ("MANSÃO ROSSI / TÉRREO"). | Bate com o GDD (minimapa que indica direção dos objetivos). |
| Objetivos | Lista abaixo do minimapa, com losango dourado para o principal e vazado para o secundário. | Bate com "objetivo atual" do HUD. |
| Itens rápidos | Barra centrada embaixo: pistola 12/36, espingarda 5/10, faca, kit médico ×2, frasco ×1, corda ×1, lanterna ×1, com teclas Q e E nas pontas. | Bate com "itens rápidos". Teclas Q/E e quantidades são só da imagem; input e inventário seguem PENDENTES. |
| Menu de interação | Lupa sobre a porta e menu "Examinar / Abrir / Usar chave / Forçar (Necessário Ferramenta) / Cancelar", com opções indisponíveis em cinza. | Mostra o feedback de falha que o GDD deixou pendente (V-13): a opção aparece desativada e diz o que falta. |
| Aviso de diário | Cartão no canto inferior direito: "Diário atualizado / Nova anotação: Mansão Rossi", tecla TAB. | O GDD não descreve diário; é ideia nova do Léo, a confirmar como sistema. |
| Seleção | Anel branco em elipse sob o personagem selecionado. | Já temos um anel dourado no turno de combate; unificar. |
| Ambiente | Vista isométrica, luz quente de lampiões sobre fundo muito escuro, piso molhado com reflexo, vegetação e textura de pedra. | Vista em V-18; iluminação dinâmica em V-08. |
| Texto | Títulos em serifa clássica dourada, texto claro; painéis escuros com borda fina. | A fonte do jogo hoje é a Special Elite (DEC-06); a referência usa serifa comum. Confirmar se títulos terão outra fonte. |

## 7. Próximos passos

1. Léo gera o primeiro teste no ChatGPT (Nikolai, direção SE) seguindo `guia-sprites-chatgpt.md` e envia o PNG.
2. Claude cria a conversão (fundo, recorte, alinhamento, redução, paleta) e mostra o sprite no jogo.
3. Léo responde V-21 e V-22; Claude monta um protótipo isométrico da sala de teste para comparar com a vista atual.
4. Depois disso, o HUD da referência na ordem da V-20.
5. Cada nova resposta do Léo entra na seção 2 no formato do Anexo H.
