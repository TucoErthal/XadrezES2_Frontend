extends Node
class_name GameAudio

## Efeitos sonoros da partida.
##
## Só reage ao sinal do GameManager; não conhece FEN nem regras do xadrez. Os
## áudios são opcionais: sem o arquivo, o efeito fica mudo.

const CAPTURE_PATH := "res://Assets/Audio/capture.mp3"
const CHECK_PATH := "res://Assets/Audio/check.mp3"

@export var game_manager_path: NodePath = ^"../GameManager"

var _capture := AudioStreamPlayer.new()
var _check := AudioStreamPlayer.new()

func _ready() -> void:
	_setup_player(_capture, CAPTURE_PATH)
	_setup_player(_check, CHECK_PATH)

	var game_manager: GameManager = get_node(game_manager_path)
	game_manager.position_changed.connect(_on_position_changed)

func _setup_player(player: AudioStreamPlayer, path: String) -> void:
	if ResourceLoader.exists(path):
		player.stream = load(path)
	add_child(player)

## Uma captura que também dá xeque toca só o som de xeque.
func _on_position_changed(captured: bool, own_check: bool) -> void:
	if own_check and _check.stream != null:
		_check.play()
	elif captured and _capture.stream != null:
		_capture.play()
