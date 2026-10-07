class_name ChessNotation
extends RefCounted

# Converte uma coordenada Vector2i(0, 0) para Notação UCI ("a1")
# Assume que X(0..7) = a..h e Y(0..7) = 1..8
static func pos_to_uci(pos: Vector2i) -> String:
	if pos.x < 0 or pos.x > 7 or pos.y < 0 or pos.y > 7:
		return ""
	
	var file_char = String.chr(pos.x + 97) # 97 é o código ASCII para 'a'
	var rank_char = str(pos.y + 1)
	
	return file_char + rank_char

# Converte Notação UCI ("e4") para Vector2i(4, 3)
static func uci_to_pos(uci: String) -> Vector2i:
	if uci.length() < 2:
		return Vector2i(-1, -1)
		
	var x = uci.unicode_at(0) - 97
	var y = uci.substr(1, 1).to_int() - 1
	
	return Vector2i(x, y)

# Lê a string FEN e devolve um Array de Dicionários com as peças e posições
# Exemplo de retorno: [{"piece": "r", "pos": Vector2i(0, 7)}, {"piece": "P", "pos": Vector2i(4, 1)}, ...]
static func parse_fen_board(fen_string: String) -> Array[Dictionary]:
	var pieces_data: Array[Dictionary] = []
	
	# O FEN contém várias partes separadas por espaço. A 1ª é a posição do tabuleiro.
	var board_part = fen_string.split(" ")[0]
	var rows = board_part.split("/")
	
	# No FEN, a primeira linha (índice 0) é a fileira 8 (Y = 7)
	for row_idx in range(rows.size()):
		var y = 7 - row_idx
		var x = 0
		
		var row_string = rows[row_idx]
		for char_idx in range(row_string.length()):
			var c = row_string[char_idx]
			
			if c.is_valid_int():
				# Se for número, são casas vazias. Avançamos o X.
				x += c.to_int()
			else:
				# Se for letra, é uma peça. Adicionamos à lista e avançamos 1 casa.
				pieces_data.append({
					"piece": c,
					"pos": Vector2i(x, y)
				})
				x += 1
				
	return pieces_data
