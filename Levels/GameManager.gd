extends Node
class_name GameManager

## Liga o tabuleiro 3D ao estado da partida.
##
## O snapshot do servidor é a fonte da verdade: a cada `game.state` o tabuleiro
## é reconstruído a partir da FEN. As regras locais (ChessRules) servem só para
## destacar os lances legais e evitar enviar um lance obviamente ilegal — quem
## decide é o backend.

@export var piece_scene: PackedScene = preload("res://Entities/Pieces/Piece.tscn")

const COLOR_SELECTED := Color(0.20, 0.60, 0.95, 0.75)
const COLOR_MOVE := Color(0.10, 0.80, 0.45, 0.55)
const COLOR_CAPTURE := Color(0.95, 0.35, 0.25, 0.60)
const COLOR_LAST_MOVE := Color(0.95, 0.80, 0.20, 0.35)
const COLOR_CHECK := Color(0.95, 0.15, 0.15, 0.70)

const MARKER_HEIGHT := 0.02

var state: Dictionary = {}            # posição atual (ChessRules)
var my_side: String = ""              # "w" / "b"
var is_my_turn: bool = false
var game_status: String = ""

var _selected: Vector2i = Vector2i(-1, -1)
var _legal_from_selected: Array[Dictionary] = []
var _markers: Node3D
var _pending_promotion: Dictionary = {}

signal promotion_requested(from: Vector2i, to: Vector2i)
signal move_rejected(code: String, message: String)

func _ready() -> void:
	add_to_group("game_manager")
	WsClient.game_state_updated.connect(_on_game_snapshot)
	WsClient.game_error_received.connect(_on_game_error)
	call_deferred("_check_initial_snapshot")

func _check_initial_snapshot() -> void:
	_markers = Node3D.new()
	_markers.name = "Highlights"
	if Board.instance != null:
		Board.instance.add_child(_markers)

	if not RestClient.current_game_snapshot.is_empty():
		_on_game_snapshot(RestClient.current_game_snapshot)
	_setup_camera()

func _setup_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and camera is CameraControls:
		# O padrão (0.0) olha do lado das Pretas; giramos 180° para as Brancas.
		if RestClient.my_side == "WHITE":
			camera._target_yaw = PI
			camera._current_yaw = PI
		else:
			camera._target_yaw = 0.0
			camera._current_yaw = 0.0

# ==========================================================================
# ENTRADA DO JOGADOR
# ==========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if game_status != "ACTIVE" or state.is_empty():
		return

	var coords := _coords_under_mouse(event.position)
	if coords.x < 0:
		return
	_handle_click(coords)

## Projeta o clique no plano do tabuleiro e devolve a casa, ou (-1,-1).
func _coords_under_mouse(screen_pos: Vector2) -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if camera == null or Board.instance == null:
		return Vector2i(-1, -1)

	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, Board.instance.global_position.y)
	var hit = plane.intersects_ray(origin, dir)
	if hit == null:
		return Vector2i(-1, -1)

	var coords: Vector2i = Board.instance.get_coordinates_from_position(hit)
	if coords.x < 0 or coords.x > 7 or coords.y < 0 or coords.y > 7:
		return Vector2i(-1, -1)
	return coords

func _handle_click(coords: Vector2i) -> void:
	# Já havia uma peça selecionada: tenta mover para a casa clicada.
	if _selected.x >= 0:
		for mv in _legal_from_selected:
			if mv["to"] == coords:
				_try_move(mv)
				return

	# Senão, seleciona a peça própria que está ali.
	var piece := ChessRules.piece_at(state, coords)
	if piece != "" and ChessRules._side_of(piece) == my_side and is_my_turn:
		_select(coords)
	else:
		_clear_selection()

func _select(coords: Vector2i) -> void:
	_selected = coords
	_legal_from_selected = ChessRules.moves_from(state, coords)
	_refresh_highlights()

func _clear_selection() -> void:
	_selected = Vector2i(-1, -1)
	_legal_from_selected = []
	_refresh_highlights()

## Envia o lance; se for promoção, pede a escolha antes.
func _try_move(move: Dictionary) -> void:
	var promo: String = move.get("promotion", "")
	if promo != "":
		# Há quatro lances para a mesma casa (dama, torre, bispo, cavalo).
		_pending_promotion = {"from": move["from"], "to": move["to"]}
		promotion_requested.emit(move["from"], move["to"])
		return
	_send(move["uci"])

## Chamado pela UI depois que o jogador escolhe a peça da promoção ("q","r","b","n").
func confirm_promotion(piece: String) -> void:
	if _pending_promotion.is_empty():
		return
	var from: Vector2i = _pending_promotion["from"]
	var to: Vector2i = _pending_promotion["to"]
	_pending_promotion = {}
	_send(ChessNotation.pos_to_uci(from) + ChessNotation.pos_to_uci(to) + piece)

func cancel_promotion() -> void:
	_pending_promotion = {}
	_clear_selection()

func _send(uci: String) -> void:
	if not WsClient.send_move(uci):
		move_rejected.emit("OFFLINE", "Sem conexão com o servidor.")
		return
	# Não aplicamos o lance localmente: esperamos o game.state do servidor,
	# que é quem decide. Só tiramos os destaques.
	_clear_selection()

func _on_game_error(code: String, message: String) -> void:
	move_rejected.emit(code, message)
	_clear_selection()

# ==========================================================================
# RECONSTRUÇÃO DO TABULEIRO (FEN)
# ==========================================================================

func _on_game_snapshot(payload: Dictionary) -> void:
	game_status = payload.get("status", "")

	var position_data = payload.get("position")
	if typeof(position_data) != TYPE_DICTIONARY:
		return
	var fen: String = position_data.get("fen", "")
	if fen.is_empty():
		return

	var parsed := ChessRules.from_fen(fen)
	if parsed.is_empty():
		printerr("FEN inválida recebida do servidor: ", fen)
		return
	state = parsed

	if my_side.is_empty() and not RestClient.my_side.is_empty():
		my_side = ChessRules.side_from_contract(RestClient.my_side)
	is_my_turn = (ChessRules.side_to_move(state) == my_side)

	_rebuild_pieces()
	_clear_selection()
	_highlight_last_move(position_data.get("lastMoveUci"))

func _rebuild_pieces() -> void:
	for piece in Piece.all_pieces.duplicate():
		piece.queue_free()
	await get_tree().process_frame

	for y in range(8):
		for x in range(8):
			var code: String = ChessRules.piece_at(state, Vector2i(x, y))
			if code != "":
				_spawn_piece(code, Vector2i(x, y))

func _spawn_piece(type: String, coords: Vector2i) -> void:
	if Board.instance == null:
		printerr("Board não instanciado!")
		return

	var piece: Piece = piece_scene.instantiate()
	Board.instance.add_child(piece)

	var is_white := (type == type.to_upper())
	piece.is_white = is_white
	piece.setup_type_label(type)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9) if is_white else Color(0.15, 0.15, 0.15)
	var mesh_node := piece.get_node_or_null("MeshInstance3D")
	if mesh_node and mesh_node is MeshInstance3D:
		mesh_node.set_surface_override_material(0, mat)

	var pos_3d = Board.instance.get_position_in_board(coords)
	if pos_3d != null:
		piece.global_position = pos_3d
		piece.board_coordinates = coords

func _get_piece_at(coords: Vector2i) -> Piece:
	for piece in Piece.all_pieces:
		if piece.board_coordinates == coords:
			return piece
	return null

# ==========================================================================
# DESTAQUES
# ==========================================================================

func _refresh_highlights() -> void:
	if _markers == null:
		return
	for child in _markers.get_children():
		child.queue_free()

	if _selected.x >= 0:
		_add_marker(_selected, COLOR_SELECTED)
		for mv in _legal_from_selected:
			var to: Vector2i = mv["to"]
			var is_capture := ChessRules.piece_at(state, to) != ""
			# En passant também é captura, ainda que a casa esteja vazia.
			if not is_capture and to == state.get("ep", Vector2i(-1, -1)):
				is_capture = ChessRules.piece_at(state, _selected).to_lower() == "p"
			_add_marker(to, COLOR_CAPTURE if is_capture else COLOR_MOVE)

	if not state.is_empty() and ChessRules.in_check(state, ChessRules.side_to_move(state)):
		var king := "K" if ChessRules.side_to_move(state) == "w" else "k"
		for y in range(8):
			for x in range(8):
				if ChessRules.piece_at(state, Vector2i(x, y)) == king:
					_add_marker(Vector2i(x, y), COLOR_CHECK)

func _highlight_last_move(last_uci) -> void:
	if last_uci == null or str(last_uci).length() < 4 or _markers == null:
		return
	var uci := str(last_uci)
	_add_marker(ChessNotation.uci_to_pos(uci.substr(0, 2)), COLOR_LAST_MOVE)
	_add_marker(ChessNotation.uci_to_pos(uci.substr(2, 2)), COLOR_LAST_MOVE)

func _add_marker(coords: Vector2i, color: Color) -> void:
	if _markers == null or Board.instance == null:
		return
	var pos_3d = Board.instance.get_position_in_board(coords)
	if pos_3d == null:
		return

	var marker := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.9)
	marker.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.set_surface_override_material(0, mat)

	_markers.add_child(marker)
	marker.global_position = pos_3d + Vector3(0, MARKER_HEIGHT, 0)
