extends Node
class_name GameManager

@export var piece_scene: PackedScene = preload("res://Entities/Pieces/Piece.tscn")

func _ready() -> void:
	# Conecta aos sinais globais do WebSocket
	WsClient.game_snapshot.connect(_on_game_snapshot)
	WsClient.game_move_applied.connect(_on_game_move_applied)

# ==========================================
# RECONSTRUÇÃO DO TABULEIRO (FEN)
# ==========================================
func _on_game_snapshot(payload: Dictionary) -> void:
	var fen = payload.get("fen", "")
	if fen.is_empty():
		return
		
	print("Snapshot recebido. Reconstruindo tabuleiro: ", fen)
	
	# 1. Destruir as peças antigas do tabuleiro
	for piece in Piece.all_pieces.duplicate():
		piece.queue_free()
		
	# Espera um frame para garantir a limpeza na engine
	await get_tree().process_frame
	
	# 2. Converter o FEN para um mapa de peças e instanciar
	var pieces_data = ChessNotation.parse_fen_board(fen)
	for data in pieces_data:
		_spawn_piece(data["piece"], data["pos"])

func _spawn_piece(type: String, coords: Vector2i) -> void:
	if Board.instance == null:
		printerr("Board não instanciado!")
		return
		
	var piece: Piece = piece_scene.instantiate()
	Board.instance.add_child(piece)
	
	# Converte as coordenadas lógicas para o posicionamento 3D local/global
	var pos_3d = Board.instance.get_position_in_board(coords)
	if pos_3d != null:
		piece.global_position = pos_3d
		piece.board_coordinates = coords
		
	# (Futuro) Pode usar a string 'type' para mudar o mesh/material (ex: "K" vs "q")

# ==========================================
# APLICAÇÃO DE JOGADAS
# ==========================================
func _on_game_move_applied(payload: Dictionary) -> void:
	var from_uci = payload.get("from", "")
	var to_uci = payload.get("to", "")
	
	if from_uci.is_empty() or to_uci.is_empty():
		return
		
	var from_coords = ChessNotation.uci_to_pos(from_uci)
	var to_coords = ChessNotation.uci_to_pos(to_uci)
	
	# 1. Verifica se existe uma peça na casa destino para capturar (remover)
	var captured_piece = _get_piece_at(to_coords)
	if captured_piece != null:
		captured_piece.queue_free()
		
	# 2. Move fisicamente a peça de origem para a casa de destino
	var moved_piece = _get_piece_at(from_coords)
	if moved_piece != null:
		var dest_3d = Board.instance.get_position_in_board(to_coords)
		if dest_3d != null:
			# Em jogos reais, você pode usar um Tween aqui para animar o movimento
			moved_piece.global_position = dest_3d
			moved_piece.board_coordinates = to_coords

# Busca uma peça registrada na posição lógica específica
func _get_piece_at(coords: Vector2i) -> Piece:
	for piece in Piece.all_pieces:
		if piece.board_coordinates == coords:
			return piece
	return null
