class_name ChessRules
extends RefCounted

## Regras de xadrez do lado do cliente.
##
## Serve só para a experiência de jogo: destacar os lances legais da peça
## selecionada e evitar enviar ao servidor um lance que já sabemos ser ilegal.
## O backend continua sendo a autoridade — se as duas opiniões divergirem,
## vale a do servidor, que responde com `game.error`.
##
## O estado é um Dictionary:
##   squares  Array[String] de 64 posições, índice = y * 8 + x
##            ("" = casa vazia; maiúscula = brancas, minúscula = pretas)
##   side     "w" ou "b"
##   castling String com as letras KQkq que ainda valem ("-" vira "")
##   ep       Vector2i da casa de en passant, ou Vector2i(-1, -1)
##   halfmove int, fullmove int

const EMPTY := ""

static func _index(x: int, y: int) -> int:
	return y * 8 + x

static func _inside(x: int, y: int) -> bool:
	return x >= 0 and x < 8 and y >= 0 and y < 8

static func _is_white_piece(p: String) -> bool:
	return p != EMPTY and p == p.to_upper()

static func _side_of(p: String) -> String:
	if p == EMPTY:
		return ""
	return "w" if _is_white_piece(p) else "b"

static func _opponent(side: String) -> String:
	return "b" if side == "w" else "w"

## Lê uma FEN completa e devolve o estado. Em caso de FEN inválida devolve {}.
static func from_fen(fen: String) -> Dictionary:
	var parts := fen.strip_edges().split(" ", false)
	if parts.size() < 1:
		return {}

	var squares: Array[String] = []
	squares.resize(64)
	squares.fill(EMPTY)

	var rows := parts[0].split("/")
	if rows.size() != 8:
		return {}

	for row_idx in range(8):
		var y := 7 - row_idx
		var x := 0
		for ch in rows[row_idx]:
			if ch.is_valid_int():
				x += ch.to_int()
			else:
				if not _inside(x, y):
					return {}
				squares[_index(x, y)] = ch
				x += 1
		if x != 8:
			return {}

	var side := parts[1] if parts.size() > 1 else "w"
	var castling := parts[2] if parts.size() > 2 else "-"
	if castling == "-":
		castling = ""
	var ep := Vector2i(-1, -1)
	if parts.size() > 3 and parts[3] != "-":
		ep = ChessNotation.uci_to_pos(parts[3])

	return {
		"squares": squares,
		"side": side,
		"castling": castling,
		"ep": ep,
		"halfmove": int(parts[4]) if parts.size() > 4 else 0,
		"fullmove": int(parts[5]) if parts.size() > 5 else 1,
	}

## Peça na casa, ou "" se vazia / fora do tabuleiro.
static func piece_at(state: Dictionary, pos: Vector2i) -> String:
	if state.is_empty() or not _inside(pos.x, pos.y):
		return EMPTY
	return state["squares"][_index(pos.x, pos.y)]

## De quem é a vez ("w" ou "b").
static func side_to_move(state: Dictionary) -> String:
	return state.get("side", "w")

## Converte "WHITE"/"BLACK" do contrato para "w"/"b".
static func side_from_contract(side: String) -> String:
	return "w" if side == "WHITE" else "b"

# ==========================================================================
# Geração de lances
# ==========================================================================

## Todos os lances legais da cor que está na vez.
static func legal_moves(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state.is_empty():
		return out
	var side: String = state["side"]
	for y in range(8):
		for x in range(8):
			var p: String = state["squares"][_index(x, y)]
			if p != EMPTY and _side_of(p) == side:
				out.append_array(moves_from(state, Vector2i(x, y)))
	return out

## Lances legais de uma casa específica. Vazio se a casa não tem peça da vez.
static func moves_from(state: Dictionary, from: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state.is_empty() or not _inside(from.x, from.y):
		return out

	var piece := piece_at(state, from)
	var side: String = state["side"]
	if piece == EMPTY or _side_of(piece) != side:
		return out

	for mv in _pseudo_moves_from(state, from):
		var after := apply(state, mv)
		if not in_check(after, side):
			out.append(mv)
	return out

static func _make_move(from: Vector2i, to: Vector2i, promo: String = "") -> Dictionary:
	return {
		"from": from,
		"to": to,
		"promotion": promo,
		"uci": ChessNotation.pos_to_uci(from) + ChessNotation.pos_to_uci(to) + promo,
	}

static func _pseudo_moves_from(state: Dictionary, from: Vector2i) -> Array[Dictionary]:
	var piece := piece_at(state, from)
	var kind := piece.to_lower()
	match kind:
		"p":
			return _pawn_moves(state, from)
		"n":
			return _step_moves(state, from, [
				Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
				Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
			])
		"b":
			return _slide_moves(state, from, _DIAGONALS)
		"r":
			return _slide_moves(state, from, _ORTHOGONALS)
		"q":
			return _slide_moves(state, from, _DIAGONALS + _ORTHOGONALS)
		"k":
			var out := _step_moves(state, from, _DIAGONALS + _ORTHOGONALS)
			out.append_array(_castle_moves(state, from))
			return out
	return [] as Array[Dictionary]

static var _DIAGONALS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(-1, 1),
]
static var _ORTHOGONALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

static func _step_moves(state: Dictionary, from: Vector2i, deltas: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side := _side_of(piece_at(state, from))
	for d in deltas:
		var to: Vector2i = from + d
		if not _inside(to.x, to.y):
			continue
		var target := piece_at(state, to)
		if target == EMPTY or _side_of(target) != side:
			out.append(_make_move(from, to))
	return out

static func _slide_moves(state: Dictionary, from: Vector2i, deltas: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side := _side_of(piece_at(state, from))
	for d in deltas:
		var to: Vector2i = from + d
		while _inside(to.x, to.y):
			var target := piece_at(state, to)
			if target == EMPTY:
				out.append(_make_move(from, to))
			else:
				if _side_of(target) != side:
					out.append(_make_move(from, to))
				break
			to += d
	return out

static func _pawn_moves(state: Dictionary, from: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side := _side_of(piece_at(state, from))
	var dir := 1 if side == "w" else -1
	var start_rank := 1 if side == "w" else 6
	var promo_rank := 7 if side == "w" else 0

	var one := Vector2i(from.x, from.y + dir)
	if _inside(one.x, one.y) and piece_at(state, one) == EMPTY:
		_append_pawn(out, from, one, promo_rank)
		var two := Vector2i(from.x, from.y + dir * 2)
		if from.y == start_rank and piece_at(state, two) == EMPTY:
			out.append(_make_move(from, two))

	for dx in [-1, 1]:
		var cap := Vector2i(from.x + dx, from.y + dir)
		if not _inside(cap.x, cap.y):
			continue
		var target := piece_at(state, cap)
		if target != EMPTY and _side_of(target) != side:
			_append_pawn(out, from, cap, promo_rank)
		elif target == EMPTY and cap == state.get("ep", Vector2i(-1, -1)):
			out.append(_make_move(from, cap))
	return out

static func _append_pawn(out: Array[Dictionary], from: Vector2i, to: Vector2i, promo_rank: int) -> void:
	if to.y == promo_rank:
		for p in ["q", "r", "b", "n"]:
			out.append(_make_move(from, to, p))
	else:
		out.append(_make_move(from, to))

static func _castle_moves(state: Dictionary, from: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side := _side_of(piece_at(state, from))
	var castling: String = state.get("castling", "")
	var home_rank := 0 if side == "w" else 7
	if from != Vector2i(4, home_rank):
		return out
	if in_check(state, side):
		return out

	var king_flag := "K" if side == "w" else "k"
	var queen_flag := "Q" if side == "w" else "q"
	var enemy := _opponent(side)

	# Roque curto: f e g vazias, e e f não atacadas.
	if castling.contains(king_flag):
		if piece_at(state, Vector2i(5, home_rank)) == EMPTY \
		and piece_at(state, Vector2i(6, home_rank)) == EMPTY \
		and not is_square_attacked(state, Vector2i(5, home_rank), enemy):
			out.append(_make_move(from, Vector2i(6, home_rank)))

	# Roque longo: b, c e d vazias, c e d não atacadas.
	if castling.contains(queen_flag):
		if piece_at(state, Vector2i(1, home_rank)) == EMPTY \
		and piece_at(state, Vector2i(2, home_rank)) == EMPTY \
		and piece_at(state, Vector2i(3, home_rank)) == EMPTY \
		and not is_square_attacked(state, Vector2i(3, home_rank), enemy):
			out.append(_make_move(from, Vector2i(2, home_rank)))
	return out

# ==========================================================================
# Xeque e ataques
# ==========================================================================

## Aplica um lance e devolve o novo estado. Não valida legalidade.
static func apply(state: Dictionary, move: Dictionary) -> Dictionary:
	var squares: Array[String] = (state["squares"] as Array[String]).duplicate()
	var from: Vector2i = move["from"]
	var to: Vector2i = move["to"]
	var piece: String = squares[_index(from.x, from.y)]
	var side := _side_of(piece)
	var kind := piece.to_lower()

	squares[_index(from.x, from.y)] = EMPTY

	# En passant: a peça capturada não está na casa de destino.
	if kind == "p" and to == state.get("ep", Vector2i(-1, -1)) and squares[_index(to.x, to.y)] == EMPTY:
		var victim_y := to.y - (1 if side == "w" else -1)
		squares[_index(to.x, victim_y)] = EMPTY

	# Roque: a torre acompanha o rei.
	if kind == "k" and absi(to.x - from.x) == 2:
		var rank := from.y
		if to.x == 6:
			squares[_index(5, rank)] = squares[_index(7, rank)]
			squares[_index(7, rank)] = EMPTY
		else:
			squares[_index(3, rank)] = squares[_index(0, rank)]
			squares[_index(0, rank)] = EMPTY

	var promo: String = move.get("promotion", "")
	if promo != "":
		squares[_index(to.x, to.y)] = promo.to_upper() if side == "w" else promo.to_lower()
	else:
		squares[_index(to.x, to.y)] = piece

	# Direitos de roque perdidos pelo rei, pela torre ou pela torre capturada.
	var castling: String = state.get("castling", "")
	if kind == "k":
		castling = castling.replace("K" if side == "w" else "k", "")
		castling = castling.replace("Q" if side == "w" else "q", "")
	for corner in [
		{"sq": Vector2i(0, 0), "flag": "Q"}, {"sq": Vector2i(7, 0), "flag": "K"},
		{"sq": Vector2i(0, 7), "flag": "q"}, {"sq": Vector2i(7, 7), "flag": "k"},
	]:
		if from == corner["sq"] or to == corner["sq"]:
			castling = castling.replace(corner["flag"], "")

	# Nova casa de en passant, só após avanço duplo de peão.
	var new_ep := Vector2i(-1, -1)
	if kind == "p" and absi(to.y - from.y) == 2:
		new_ep = Vector2i(from.x, (from.y + to.y) / 2)

	return {
		"squares": squares,
		"side": _opponent(side),
		"castling": castling,
		"ep": new_ep,
		"halfmove": 0 if kind == "p" else int(state.get("halfmove", 0)) + 1,
		"fullmove": int(state.get("fullmove", 1)) + (1 if side == "b" else 0),
	}

## O rei da cor dada está em xeque?
static func in_check(state: Dictionary, side: String) -> bool:
	var king := "K" if side == "w" else "k"
	for i in range(64):
		if state["squares"][i] == king:
			return is_square_attacked(state, Vector2i(i % 8, i / 8), _opponent(side))
	return false # sem rei no tabuleiro: posição de teste

## A casa é atacada por alguma peça da cor `by_side`?
static func is_square_attacked(state: Dictionary, sq: Vector2i, by_side: String) -> bool:
	# Peões: olhamos de onde eles capturariam para chegar aqui.
	var pawn_dir := -1 if by_side == "w" else 1
	var pawn := "P" if by_side == "w" else "p"
	for dx in [-1, 1]:
		var src := Vector2i(sq.x + dx, sq.y + pawn_dir)
		if _inside(src.x, src.y) and piece_at(state, src) == pawn:
			return true

	var knight := "N" if by_side == "w" else "n"
	for d in [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
	]:
		var src: Vector2i = sq + d
		if _inside(src.x, src.y) and piece_at(state, src) == knight:
			return true

	var king := "K" if by_side == "w" else "k"
	for d in _DIAGONALS + _ORTHOGONALS:
		var src: Vector2i = sq + d
		if _inside(src.x, src.y) and piece_at(state, src) == king:
			return true

	if _attacked_by_slider(state, sq, _DIAGONALS, by_side, "b"):
		return true
	if _attacked_by_slider(state, sq, _ORTHOGONALS, by_side, "r"):
		return true
	return false

static func _attacked_by_slider(state: Dictionary, sq: Vector2i, deltas: Array, by_side: String, kind: String) -> bool:
	var piece := kind.to_upper() if by_side == "w" else kind
	var queen := "Q" if by_side == "w" else "q"
	for d in deltas:
		var cur: Vector2i = sq + d
		while _inside(cur.x, cur.y):
			var p := piece_at(state, cur)
			if p != EMPTY:
				if p == piece or p == queen:
					return true
				break
			cur += d
	return false
