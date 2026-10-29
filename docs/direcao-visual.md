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
| V-16 | Quem produz a arte final (Léo, artista contratado, assets de terceiros)? | Decisão do Léo; muda prazo e o nível de detalhe viável. |
| V-17 | Formato da introdução (cutscene, imagens, texto ou combinação) (§3.1). | Decisão de narrativa do Léo; afeta quantas ilustrações grandes serão necessárias. |
| V-18 | A referência de ambiente (`arte/referencias/hud-mapa-personagens-mansao-rossi.png`) usa vista **isométrica diagonal** (paredes e pisos em diagonal), não a vista ortogonal em 3/4 que a sala de teste usa hoje. A vista desejada é a da referência? | Se sim, a DEC-2026-10-29-01 passa a ser "isométrica 2:1". Isso muda tiles (losangos), ordenação de profundidade, colisão e pathfinding na tela, e deve ser decidido antes de desenhar qualquer cenário. Posso montar um protótipo curto da sala em isométrica para você comparar. |
| V-19 | Nível de detalhe e tamanho. Na referência o personagem ocupa cerca de 18% da altura da tela, o que daria uns 65 px em 640×360 (hoje 48 px, 13%), com roupa, rosto e sombreamento bem mais ricos. | Subir o personagem para ~64 px e produzir sprites desenhados à mão (V-16). Detalhe assim não sai de arte gerada por código; os placeholders continuam só para testar mecânica. |
| V-20 | Ordem de implementação do HUD da referência (ver seção 6). | Começar por retratos com PV/SAN, minimapa circular e lista de objetivos, depois barra de itens, menu de interação e aviso do diário. |

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

1. ~~Claude ajusta o projeto para 640×360 com escala inteira e adapta a sala de teste.~~ Feito: resolução interna 640×360, janela 1280×720, escala inteira; câmera segue a unidade em foco e a sala de 1280×720 rola.
2. ~~Claude cria a paleta escura de teste, um personagem placeholder de 32×48 em 4 direções e um tile de chão 16×16.~~ Feito em `scripts/art/placeholder_art.gd` (gerado por código, sem PNG) e `assets/palettes/paleta_teste.gpl` (importável no Aseprite).
3. ~~Léo avalia o personagem de teste.~~ Feito: tamanho aceitável, quer mais detalhe (DEC-07).
4. Léo responde V-18 (vista isométrica?) e V-19 (tamanho e produção da arte). Bloqueiam o cenário e os sprites finais.
5. Depois da V-18, Claude monta o HUD da referência na ordem da V-20.
6. Cada nova resposta do Léo entra na seção 2 no formato do Anexo H.
