class_name Atalhos
extends RefCounted
# Teclas dos itens de combate e dos rituais: fonte única para a sala (RoomItems.KEY_LABELS, RoomActionBar) e para o
# mapa de controles (ControlesCaderno). Fica num script sem dependências porque RoomItems e RoomActionBar dependem da
# sala inteira, e carregá-los a partir do menu criava dependência circular de scripts. Troque as teclas aqui.

const ITEM_KEYS := {"granada_luz": "H", "sinalizador": "U"}
const RITUAL_KEYS := {"armadura_sangue": "Z", "amaldicoar_arma": "X", "eletrocussao": "T", "cicatrizacao": "Y"}
const ITEM_TIPS := {
	"granada_luz": "atordoa os inimigos perto do ponto",
	"sinalizador": "luz no chão: +acerto contra quem está nela",
}
