extends Node
class_name GameManager

## Liga o tabuleiro 3D ao estado da partida.
##
## O snapshot do servidor é a fonte da verdade: a cada `game.state` o tabuleiro
## é reconstruído a partir da FEN. As regras locais (ChessRules) servem só para
## destacar os lances legais e evitar enviar um lance obviamente ilegal — quem
## decide é o backend.
##
## Entrada do jogador (clique e clique): seleciona uma peça própria, escolhe uma
## das casas oferecidas e o lance é enviado ao servidor. A peça só se move
## quando chega o `game.state` novo; se o servidor recusar (`game.error`), a
## seleção continua e o jogador pode escolher outra casa.

@export var piece_scene: PackedScene = preload("res://Entities/Pieces/Piece.tscn")

enum InputState {
	IDLE,      ## nenhuma peça selecionada
	SELECTED,  ## peça própria selecionada, esperando a casa de destino
	AWAITING,  ## lance enviado, esperando o servidor aceitar ou recusar
}

const NO_SQUARE := Vector2i(-1, -1)

var state: Dictionary = {}            # posição atual (ChessRules)
var my_side: String = ""              # "w" / "b"
var is_my_turn: bool = false
var game_status: String = ""

var _input_state: InputState = InputState.IDLE
var _selected: Vector2i = NO_SQUARE
var _targets: Array[Vector2i] = []    # casas oferecidas para a peça selecionada
var _pending_promotion: Dictionary = {}
var _last_fen: String = ""

## Um peão chegou à última fileira: a UI deve perguntar a peça e responder com
## confirm_promotion() ou cancel_promotion(). Sem ninguém conectado, promove
## para dama.
signal promotion_requested(from: Vector2i, to: Vector2i)
## O lance não foi aceito (recusado pelo servidor ou sem conexão).
signal move_rejected(code: String, message: String)

func _ready() -> void:
	add_to_group("game_manager")
	WsClient.game_state_updated.connect(_on_game_snapshot)
	WsClient.game_error_received.connect(_on_game_error)
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
# ENTRADA DO JOGADOR
# ==========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("select"):
		return
	if game_status != "ACTIVE" or state.is_empty():
		return

	var coords := _square_under_mouse(get_viewport().get_mouse_position())
	if coords == NO_SQUARE:
		return
	get_viewport().set_input_as_handled()
	_handle_click(coords)

## Projeta o ponto da tela na face de cima do tabuleiro e devolve a casa, ou
## NO_SQUARE se o clique caiu fora dele.
func _square_under_mouse(screen_pos: Vector2) -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if camera == null or Board.instance == null:
		return NO_SQUARE

	var top := Board.instance.to_global(Vector3(0, Board.instance.get_aabb().end.y, 0))
	var plane := Plane(Board.instance.global_transform.basis.y.normalized(), top)
	var hit = plane.intersects_ray(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
	if hit == null:
		return NO_SQUARE

	var coords: Vector2i = Board.instance.get_coordinates_from_position(hit)
	if coords.x < 0 or coords.x > 7 or coords.y < 0 or coords.y > 7:
		return NO_SQUARE
	return coords

func _handle_click(coords: Vector2i) -> void:
	if _input_state == InputState.AWAITING or not _pending_promotion.is_empty():
		return

	if _input_state == InputState.SELECTED:
		if coords == _selected:
			_clear_selection()
			return
		if _targets.has(coords):
			_try_move(_selected, coords)
			return

	if is_my_turn and _is_own_piece(coords):
		_select(coords)
	else:
		_clear_selection()

## Casas oferecidas ao jogador para a peça em `from`.
##
## TEMPORÁRIO: usa as regras locais (ChessRules) só para filtrar e destacar;
## quem valida é o backend. Quando a validação ficar só no servidor, basta
## trocar esta função (por exemplo, lendo os lances legais do snapshot).
func _candidate_targets(from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for mv in ChessRules.moves_from(state, from):
		var to: Vector2i = mv["to"]
		if not out.has(to):
			out.append(to) # a promoção gera quatro lances para a mesma casa
	return out

func _is_own_piece(coords: Vector2i) -> bool:
	var piece := ChessRules.piece_at(state, coords)
	return piece != "" and (piece == piece.to_upper()) == (my_side == "w")

func _is_promotion(from: Vector2i, to: Vector2i) -> bool:
	var piece := ChessRules.piece_at(state, from)
	if piece.to_lower() != "p":
		return false
	return to.y == (7 if piece == "P" else 0)

func _select(coords: Vector2i) -> void:
	_clear_selection()
	_selected = coords
	_targets = _candidate_targets(coords)
	_input_state = InputState.SELECTED
	var piece := _get_piece_at(coords)
	if piece:
		piece.select()

func _clear_selection() -> void:
	for piece in Piece.all_pieces:
		piece.deselect()
	_selected = NO_SQUARE
	_targets = []
	_pending_promotion = {}
	_input_state = InputState.IDLE

func _try_move(from: Vector2i, to: Vector2i) -> void:
	var uci := ChessNotation.pos_to_uci(from) + ChessNotation.pos_to_uci(to)
	if not _is_promotion(from, to):
		_send_move(uci)
	elif promotion_requested.get_connections().is_empty():
		_send_move(uci + "q") # ainda não há tela de escolha da peça
	else:
		_pending_promotion = {"from": from, "to": to}
		promotion_requested.emit(from, to)

## Chamado pela UI com a peça escolhida para a promoção ("q", "r", "b" ou "n").
func confirm_promotion(piece: String) -> void:
	if _pending_promotion.is_empty():
		return
	var uci := ChessNotation.pos_to_uci(_pending_promotion["from"]) + ChessNotation.pos_to_uci(_pending_promotion["to"])
	_pending_promotion = {}
	_send_move(uci + piece)

## Chamado pela UI quando o jogador desiste da promoção; a peça continua selecionada.
func cancel_promotion() -> void:
	_pending_promotion = {}

func _send_move(uci: String) -> void:
	if not WsClient.send_move(uci):
		move_rejected.emit("OFFLINE", "Sem conexão com o servidor.")
		return
	# Não aplicamos o lance localmente: a peça só se move com o game.state.
	_input_state = InputState.AWAITING

func _on_game_error(code: String, message: String) -> void:
	# O sinal não traz o requestId; um erro durante a espera é tomado como
	# recusa do lance. A seleção continua para o jogador escolher outra casa.
	if _input_state != InputState.AWAITING:
		return
	_input_state = InputState.SELECTED
	move_rejected.emit(code, message)

# ==========================================================================
# RECONSTRUÇÃO DO TABULEIRO (FEN)
# ==========================================================================

func _on_game_snapshot(payload: Dictionary) -> void:
	game_status = payload.get("status", "")
	if game_status != "ACTIVE":
		_clear_selection()

	var position_data = payload.get("position")
	if typeof(position_data) != TYPE_DICTIONARY:
		return
	var fen: String = position_data.get("fen", "")
	if fen.is_empty() or fen == _last_fen:
		return

	var parsed := ChessRules.from_fen(fen)
	if parsed.is_empty():
		printerr("FEN inválida recebida do servidor: ", fen)
		return
	state = parsed
	_last_fen = fen

	if my_side.is_empty() and not RestClient.my_side.is_empty():
		my_side = ChessRules.side_from_contract(RestClient.my_side)
	is_my_turn = (ChessRules.side_to_move(state) == my_side)

	_clear_selection()
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
	var mat = StandardMaterial3D.new()
	if is_white:
		mat.albedo_color = Color(0.9, 0.9, 0.9) # Quase branco
	else:
		mat.albedo_color = Color(0.15, 0.15, 0.15) # Cinza escuro/Preto
		
	var mesh_node = piece.get_node_or_null("MeshInstance3D")
	# if mesh_node and mesh_node is MeshInstance3D:
		# mesh_node.set_surface_override_material(0, mat)
	
	# Converte as coordenadas lógicas para o posicionamento 3D local/global
	var pos_3d = Board.instance.get_position_in_board(coords)
	if pos_3d != null:
		piece.global_position = pos_3d
		piece.board_coordinates = coords

func _get_piece_at(coords: Vector2i) -> Piece:
	for piece in Piece.all_pieces:
		if piece.board_coordinates == coords:
			return piece
	return null