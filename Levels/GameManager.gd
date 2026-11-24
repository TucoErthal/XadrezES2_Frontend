extends Node
class_name GameManager

## Liga o tabuleiro 3D ao estado da partida.
##
## O snapshot do servidor é a fonte da verdade: a cada `game.state` o tabuleiro
## é reconstruído a partir da FEN. As regras locais (ChessRules) servem só para
## destacar os lances legais e evitar enviar um lance obviamente ilegal — quem
## decide é o backend.

@export var piece_scene: PackedScene = preload("res://Entities/Pieces/Piece.tscn")

var state: Dictionary = {}            # posição atual (ChessRules)
var my_side: String = ""              # "w" / "b"
var is_my_turn: bool = false
var game_status: String = ""

func _ready() -> void:
	WsClient.game_state_updated.connect(_on_game_snapshot)
	call_deferred("_check_initial_snapshot")

func _check_initial_snapshot() -> void:
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