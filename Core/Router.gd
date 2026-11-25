extends Node

var ui_container: Node
var level_container: Node3D

var _current_view: Node
var _current_level: Node
var _current_route: String = ""
var _history: Array[String] = []

const NON_RETURNABLE_ROUTES: Array[String] = ["GameUI", "WaitingRoom"]

var _routes: Dictionary = {
	"Home": "res://UI/Screens/Home.tscn",
	"Login": "res://UI/Screens/LoginScreen.tscn",
	"Lobby": "res://UI/Screens/LobbyScreen.tscn",
	"CreateRoom": "res://UI/Screens/CreateRoomScreen.tscn",
	"WaitingRoom": "res://UI/Screens/WaitingRoomScreen.tscn",
	"GameUI": "res://UI/Screens/GameUI.tscn"
}

func navigate_to(route_name: String, record_history: bool = true) -> void:
	if not _routes.has(route_name):
		printerr("Rota '%s' não configurada no dicionário." % route_name)
		return

	if ui_container == null:
		return

	# Atualiza o histórico evitando ciclos (ex.: Lobby -> CreateRoom -> Lobby)
	var existing_idx := _history.find(route_name)
	if existing_idx != -1:
		_history = _history.slice(0, existing_idx)
	elif record_history and not _current_route.is_empty() and _current_route != route_name:
		if not (_current_route in NON_RETURNABLE_ROUTES):
			_history.append(_current_route)

	_mount_route(route_name)

func go_back(fallback_route: String = "Home") -> void:
	if not _history.is_empty():
		var previous_route: String = _history.pop_back()
		_mount_route(previous_route)
	else:
		navigate_to(fallback_route, false)

func clear_history() -> void:
	_history.clear()

func _mount_route(route_name: String) -> void:
	if _current_view != null:
		_current_view.queue_free()
		_current_view = null

	var scene: PackedScene = load(_routes[route_name])
	_current_view = scene.instantiate()
	_current_route = route_name
	ui_container.add_child(_current_view)

	# Transição suave de entrada em qualquer Control
	if _current_view is Control:
		var ctrl := _current_view as Control
		ctrl.modulate.a = 0.0
		var tween := ctrl.create_tween()
		tween.tween_property(ctrl, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func load_level(level_path: String) -> void:
	if level_container == null:
		printerr("LevelContainer não foi definido no Router.")
		return

	unload_level()

	var scene: PackedScene = load(level_path)
	_current_level = scene.instantiate()
	level_container.add_child(_current_level)

func unload_level() -> void:
	if _current_level != null:
		_current_level.queue_free()
		_current_level = null
