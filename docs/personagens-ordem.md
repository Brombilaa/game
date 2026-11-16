# Personagens da Ordem (pós-combate da missão 1)

Design para revisão do Léo, em 16/11/2026. Página com os 3 visuais: https://claude.ai/artifact/Vavw5kLPxFPpQXnWHQ4Y8s. Tudo aqui é **provisório do Claude** até o Léo aprovar: nomes, idades, falas e visual. Nada disso virou modelo 3D nem entrou no jogo ainda.

## Onde eles entram

Depois da Dama de Sangue morta e da Letícia salva, o grupo (Nikolai e Miguel, já sem o Fernando) vai ao celeiro da Fazenda Ghular e encontra a equipe de campo da Ordem, a organização que chamou os agentes para Aurora (GDD #8). A Ordem é "do bem": chega tarde, limpa o local e cuida de quem sobrou. É a única cena do jogo com eles. Eles não são jogáveis, não entram em combate e não têm ficha (`personagens.json` fica como está). A cena fecha com a cutscene externa e o fim do capítulo.

Nome da organização: o Léo chama de "a Ordem". Como o jogo saiu de "Ordem Paranormal" por direitos autorais, fica em aberto se "a Ordem" fica como nome de tela ou se ganha outro nome no jogo. Nas falas abaixo uso só "a Ordem".

## A equipe (4 pessoas, silhuetas bem diferentes)

| id | Nome | Papel na cena | Silhueta |
|---|---|---|---|
| `marta` | Marta Quintela, 54 | Coordenadora de campo, líder da equipe | alta, casaco longo cinza-chumbo, cabelo grisalho preso, rádio no ombro |
| `otavio` | Dr. Otávio Brandão, 41 | Médico de campo, cuida da Letícia | médio, jaleco claro sobre colete, maleta, óculos redondos |
| `ivo` | Ivo Salgueiro, 33 | Técnico de selamento (poço, cripta, símbolo) | baixo e largo, macacão cheio de bolsos, lanterna de cabeça, mochila de apetrechos |
| `bia` | Bia Camargo, 26 | Batedora e motorista de apoio | magra, jaqueta curta e boné, fuzil às costas, luvas |

Cada um tem uma função na história, para a cena não ser quatro pessoas dizendo a mesma coisa: Marta dá o contexto e o próximo passo, Otávio mostra o custo humano, Ivo explica o sobrenatural, Bia faz a ponte com o grupo.

### Marta Quintela (`marta`)
- **Quem é:** veterana da Ordem, já viu o que a Ordem esconde. Fala baixo, não pergunta duas vezes. Foi ela quem mandou o chamado a Aurora.
- **Papel:** assume o local, pergunta o que aconteceu, reconhece a morte do Fernando e encerra o capítulo apontando para o próximo caso.
- **Falas-chave:**
  - Ao chegar: "Cheguei tarde. Isso me pesa mais do que vocês imaginam."
  - Sobre o Fernando: "Ele pediu para ir na frente? Então sabia o que estava fazendo. Isso não diminui nada."
  - Sobre a delegacia: "Três semanas de barulho e nenhuma viatura. Alguém em Aurora escolheu não ver. Eu vou descobrir quem."
  - Fecho do capítulo: "Descansem. Amanhã eu conto o que vem depois de Aurora."

### Dr. Otávio Brandão (`otavio`)
- **Quem é:** médico que larga o consultório quando a Ordem chama. Calmo demais, de propósito: é a voz de quem trata gente em choque.
- **Papel:** cuida da Letícia (ferida, em choque pela morte do Caio e pelo que viu embaixo) e olha o estado do Nikolai e do Miguel. Conecta com a SAN do jogo.
- **Falas-chave:**
  - Sobre a Letícia: "Ela vai ficar bem do corpo. O resto leva mais tempo, e não depende de remédio."
  - Para o grupo: "Vocês dois estão sangrando e fingindo que não. Sentem. Agora."
  - Sobre a SAN: "Quem passa uma noite assim nunca volta igual. Volta inteiro, se tiver quem sente ao lado."

### Ivo Salgueiro (`ivo`)
- **Quem é:** técnico que sela lugares. Tagarela quando está nervoso, seco quando trabalha. Não gosta de poços.
- **Papel:** sela o poço e a cripta, comenta o símbolo da árvore e as ruínas, dá o único pedaço de explicação sobrenatural da cena (sem entregar o mistério todo).
- **Falas-chave:**
  - No poço: "Linha de sal, lacre de ferro, e rezar para o ferro aguentar. É o que eu sei fazer."
  - Sobre o símbolo: "Esse desenho não é de quem cultua. É de quem convoca. Alguém abriu uma porta e esqueceu de fechar."
  - Para o Miguel: "Você leu o símbolo no parque? Então já sabe mais do que eu queria que soubesse."

### Bia Camargo (`bia`)
- **Quem é:** motorista e batedora, a mais próxima da idade do grupo. Sarcástica por defesa. Respeita quem chegou vivo.
- **Papel:** traz o grupo da fazenda até a van, comenta a luta, é quem cobre o Fernando com a lona.
- **Falas-chave:**
  - Ao ver a Dama: "Isso estava aqui embaixo e vocês saíram andando? Eu já teria saído correndo."
  - Para o Nikolai: "Vi seus tiros na lateral do celeiro. Deixou a minha mira com vergonha."
  - Sobre o Fernando: "Eu cubro ele. Podem ir, eu ajeito a lona e fico até o fim."

## Ordem sugerida da cena (para o roteiro do pós-combate)

1. Entrada no celeiro: as luzes da van e a Bia viram a lanterna para o grupo.
2. Marta se apresenta e pergunta pelo Fernando.
3. Otávio assume a Letícia; o Nikolai e o Miguel são "forçados" a sentar.
4. Ivo vai ao poço e comenta o símbolo; o Miguel responde uma fala curta.
5. Bia cobre o Fernando.
6. Marta fecha o dia; corte para a cutscene externa e fim do capítulo.

Uso: as threads "Fazenda versão 2 com agentes da Ordem" e "Roteiro do pós-combate e tela final" podem usar os ids `marta`, `otavio`, `ivo` e `bia`, e reaproveitar as falas acima como rascunho.

## Em aberto (precisa do Léo)

1. Aprovar ou trocar a equipe: quantidade (4), nomes, papéis.
2. Escolher o visual (3 modelos na página de comparação): A farda da Ordem, B civis com um detalhe em comum, C equipamento de campo com marca em vermelho.
3. Nome da organização em tela.
4. Júlia, Tristan e Senhor Veríssimo (da lista de modelos 3D futuros) são pessoas da Ordem? Se forem, troco os nomes aqui sem mudar os papéis.

## Depois da aprovação

Um modelo 3D por pessoa no mesmo pipeline do Mixamo (rig humanoide, texturas 512 px, estilo PC antigo), animações só de idle, andar e falar (sem combate). Retratos para a caixa de fala (`assets/sprites/retratos`) ficam para a thread de retratos.
