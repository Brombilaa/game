class_name FimCapitulo
extends CanvasLayer
# Fim do capítulo 1 (Léo, 15/11 e 19/11/2026): depois da conversa com a Ordem no celeiro, a tela escurece, corta para
# a igreja na Itália (o cliffhanger grande) e, por fim, entra o cartão AURORA (CartaoCapitulo, modelo A, 16/11).
# A igreja é desenhada no jogo (CenaItalia) até existir a cutscene externa: quando o vídeo (`video`, Ogg Theora, o
# formato que a Godot toca) estiver no projeto, ele toca no lugar dela. Qualquer tecla ou clique pula os dois.
# Quem chama decide o que vem depois (`terminou`): a sala marca o capítulo e volta ao menu.

signal terminou

const ESCURECER := 1.4  # s até a tela ficar preta (provisório)
const PAUSA := 0.6  # s de preto antes do vídeo ou do cartão (provisório)
const PASTA_VIDEO := "res://assets/cutscenes/"  # o dado traz só o nome: <nome>.ogv nesta pasta

var video := ""
var titulo := "AURORA"
var legenda := "CAPÍTULO 1"
var tocou_video := false  # o vídeo existia e começou (os testes leem)
var italia: CenaItalia  # a cena da igreja, quando não há vídeo
var cartao: CartaoCapitulo
var _preto: ColorRect
var _player: VideoStreamPlayer


static func tocar(pai: Node, dados: Dictionary) -> FimCapitulo:
	var f := FimCapitulo.new()
	var nome := str(dados.get("video", ""))
	f.video = PASTA_VIDEO + nome + ".ogv" if nome != "" else ""
	f.titulo = str(dados.get("titulo", "AURORA"))
	f.legenda = str(dados.get("legenda", "CAPÍTULO 1"))
	pai.add_child(f)
	f._sequencia.call_deferred()
	return f


static func tem_video(caminho: String) -> bool:
	return caminho != "" and ResourceLoader.exists(caminho)


func _ready() -> void:
	layer = 99  # acima do cinema (95) e abaixo do cartão (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preto = ColorRect.new()
	_preto.color = Color(0, 0, 0, 0)
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_preto)


func _sequencia() -> void:
	var t := create_tween()
	t.tween_property(_preto, "color:a", 1.0, ESCURECER)
	t.tween_interval(PAUSA)
	await t.finished
	if tem_video(video):
		await _tocar_video()
	else:
		italia = CenaItalia.new()
		add_child(italia)
		await italia.terminou
		italia.queue_free()
	cartao = CartaoCapitulo.tocar(self, titulo, legenda)
	await cartao.terminou
	terminou.emit()


func _tocar_video() -> void:
	var stream: VideoStream = load(video)
	if stream == null:
		return
	tocou_video = true
	_player = VideoStreamPlayer.new()
	_player.stream = stream
	_player.expand = true
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player)
	_player.play()
	while is_instance_valid(_player) and _player.is_playing():
		await get_tree().process_frame
	if is_instance_valid(_player):
		_player.queue_free()


func _input(event: InputEvent) -> void:
	var pressionou: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if pressionou and _player != null and is_instance_valid(_player) and _player.is_playing():
		get_viewport().set_input_as_handled()
		_player.stop()  # pula a cutscene externa
