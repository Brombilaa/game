extends Node
# Autoload "Game": estado que vale para o jogo inteiro, em um lugar só.
# Hoje guarda as opções (uma única cópia para menu e jogo) e qual slot de save
# o jogador escolheu no menu. Quem precisa das opções chama GameOptions.shared().

var options: GameOptions
var pending_slot := ""  # slot escolhido em Carregar; "" = novo jogo


func _ready() -> void:
	options = GameOptions.load_from()
	options.apply()


# Grava as opções; chamado a cada mudança, para nada se perder se a janela fechar.
func save_options() -> Error:
	return options.save()
