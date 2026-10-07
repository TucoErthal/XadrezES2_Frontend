extends Node
class_name GameManager

@export var piece_scene: PackedScene = preload("res://Entities/Pieces/Piece.tscn")

func _ready() -> void:
	# Conecta aos sinais globais do WebSocket
	WsClient.game_state_updated.connect(_on_game_snapshot)
	#WsClient.game_move_applied.connect(_on_game_move_applied)
	call_deferred("_check_initial_snapshot")

func _check_initial_snapshot() -> void:
	if not RestClient.current_game_snapshot.is_empty():
		_on_game_snapshot(RestClient.current_game_snapshot)

# ==========================================
# RECONSTRUÇÃO DO TABULEIRO (FEN)
# ==========================================
func _on_game_snapshot(payload: Dictionary) -> void:
	# 1. Pega o dicionário 'position' e depois extrai o 'fen' dele
	var position_data = payload.get("position")
	if typeof(position_data) != TYPE_DICTIONARY:
		return
		
	var fen = position_data.get("fen", "")
	if fen.is_empty():
		return
		
	print("Snapshot recebido. Reconstruindo tabuleiro: ", fen)
	
	# 2. Destruir as peças antigas do tabuleiro
	for piece in Piece.all_pieces.duplicate():
		piece.queue_free()
		
	# Espera um frame para garantir a limpeza na engine
	await get_tree().process_frame
	
	# 3. Usa o seu ChessNotation.gd para instanciar!
	var pieces_data = ChessNotation.parse_fen_board(fen)
	for data in pieces_data:
		_spawn_piece(data["piece"], data["pos"])

func _spawn_piece(type: String, coords: Vector2i) -> void:
	if Board.instance == null:
		printerr("Board não instanciado!")
		return
		
	var piece: Piece = piece_scene.instantiate()
	Board.instance.add_child(piece)
	
	var is_white = (type == type.to_upper())
	var mat = StandardMaterial3D.new()
	if is_white:
		mat.albedo_color = Color(0.9, 0.9, 0.9) # Quase branco
	else:
		mat.albedo_color = Color(0.15, 0.15, 0.15) # Cinza escuro/Preto
		
	var mesh_node = piece.get_node_or_null("MeshInstance3D")
	if mesh_node and mesh_node is MeshInstance3D:
		mesh_node.material_override = mat
	
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
