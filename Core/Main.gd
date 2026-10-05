extends Node
class_name Main

@export var level_container: Node3D
@export var ui_container: CanvasLayer

func _ready() -> void:
	# Informa ao Router onde pendurar as telas e as fases
	Router.ui_container = ui_container
	Router.level_container = level_container

	# Inicia o aplicativo na tela Home
	Router.navigate_to("Home")
