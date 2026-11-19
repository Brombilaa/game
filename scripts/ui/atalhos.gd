class_name Atalhos
extends RefCounted
# Teclas dos itens de combate e dos rituais, como o mapa de controles (ControlesCaderno) as mostra. É uma cópia
# deliberada de RoomItems.KEY_LABELS, RoomActionBar.RITUAL_KEYS e RoomActionBar.ITEM_TIPS: aqueles scripts
# dependem da sala inteira e carregá-los a partir do menu cria dependência circular. tests/test_atalhos.gd confere
# que as cópias continuam iguais; quem trocar uma tecla no jogo atualiza aqui e o teste avisa se esquecer.

const ITEM_KEYS := {"granada_luz": "H", "sinalizador": "U"}
const RITUAL_KEYS := {"armadura_sangue": "Z", "amaldicoar_arma": "X", "eletrocussao": "T", "cicatrizacao": "Y"}
const ITEM_TIPS := {
	"granada_luz": "atordoa os inimigos perto do ponto",
	"sinalizador": "luz no chão: +acerto contra quem está nela",
}
