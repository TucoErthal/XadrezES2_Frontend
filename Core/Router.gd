extends Node

# Containers que vão segurar as telas e o mundo 3D
var ui_container: Node
var level_container: Node3D

var _current_view: Node
var _current_level: Node

var _routes: Dictionary = {
	"Home": "res://UI/Screens/Home.tscn",
	"Lobby": "res://UI/Screens/Lobby.tscn",
	"GameUI": "res://UI/Screens/GameUI.tscn"
}

func navigate_to(route_name: String) -> void:
	if not _routes.has(route_name):
		printerr("Rota '%s' não configurada no dicionário." % route_name)
		return

	if ui_container == null:
		return

	if _current_view != null:
		_current_view.queue_free()
		_current_view = null

	var scene: PackedScene = load(_routes[route_name])
	_current_view = scene.instantiate()
	ui_container.add_child(_current_view)

func load_level(level_path: String) -> void:
	if level_container == null:
		printerr("LevelContainer não foi definido no Router.")
		return

	if _current_level != null:
		_current_level.queue_free()
		_current_level = null

	var scene: PackedScene = load(level_path)
	_current_level = scene.instantiate()
	level_container.add_child(_current_level)
