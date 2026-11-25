extends Node
class_name FrontendSandbox

## Simula o backend localmente para testar tabuleiro 3D, câmera, destaques e UI
## sem precisar de servidor REST/WebSocket rodando.

enum PlayMode {
	HOTSEAT,    ## Você joga com Brancas e Pretas alternadamente
	RANDOM_BOT, ## Você joga com um lado e o sandbox responde com lances legais aleatórios
}

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const PROMO_FEN := "8/P7/8/8/8/8/8/4K2k w - - 0 1"
const CHECK_FEN := "4k3/8/8/8/8/8/4Q3/4K3 w - - 0 1"
const SPECIAL_FEN := "r3k2r/ppp1pppp/8/3pP3/8/8/PPPP1PPP/R3K2R w KQkq d6 0 1"

@export var play_mode: PlayMode = PlayMode.HOTSEAT
@export_enum("WHITE", "BLACK") var starting_side: String = "WHITE"
@export var fake_latency_sec: float = 0.12
@export var bot_think_sec: float = 0.35

var _current_fen: String = START_FEN
var _force_next_error: bool = false
var _rng := RandomNumberGenerator.new()

func _enter_tree() -> void:
	# Roda antes do _ready() dos nós da cena para o GameManager já encontrar o snapshot inicial
	RestClient.my_side = starting_side
	RestClient.current_game_snapshot = _make_snapshot(START_FEN, "ACTIVE", null)

func _ready() -> void:
	_rng.randomize()
	WsClient.mock_send_move = _on_mock_send_move
	print("[Sandbox] Ativo (%s). F1=Reset | F2=Promoção | F3=Xeque | F4=Roque/EP | F5=Erro no próximo lance | F6=Fim de jogo" % PlayMode.keys()[play_mode])

func _exit_tree() -> void:
	if WsClient.mock_send_move == _on_mock_send_move:
		WsClient.mock_send_move = Callable()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			_load_scenario(START_FEN, "WHITE", "ACTIVE")
		KEY_F2:
			_load_scenario(PROMO_FEN, "WHITE", "ACTIVE")
		KEY_F3:
			_load_scenario(CHECK_FEN, "WHITE", "ACTIVE")
		KEY_F4:
			_load_scenario(SPECIAL_FEN, "WHITE", "ACTIVE")
		KEY_F5:
			_force_next_error = true
			print("[Sandbox] O próximo lance será recusado com game.error.")
		KEY_F6:
			_emit_snapshot(_current_fen, "FINISHED", null)
			print("[Sandbox] Partida encerrada (status=FINISHED).")

func _load_scenario(fen: String, side_contract: String, status: String) -> void:
	_force_next_error = false
	_current_fen = fen
	_sync_player_side(side_contract)
	_emit_snapshot(fen, status, null)

func _on_mock_send_move(uci: String) -> bool:
	_process_move_async(uci)
	return true

func _process_move_async(uci: String) -> void:
	if fake_latency_sec > 0.0:
		await get_tree().create_timer(fake_latency_sec).timeout

	if _force_next_error:
		_force_next_error = false
		WsClient.game_error_received.emit("ILLEGAL_MOVE", "Erro simulado pelo sandbox para " + uci)
		return

	_current_fen = apply_uci_to_fen(_current_fen, uci)

	if play_mode == PlayMode.HOTSEAT:
		var next_side_code := _current_fen.split(" ")[1]
		_sync_player_side("WHITE" if next_side_code == "w" else "BLACK")

	_emit_snapshot(_current_fen, "ACTIVE", uci)

	if play_mode == PlayMode.RANDOM_BOT:
		_maybe_play_bot_turn()

func _maybe_play_bot_turn() -> void:
	var state := ChessRules.from_fen(_current_fen)
	if state.is_empty():
		return
	var bot_side := ChessRules.side_to_move(state)
	var player_side := ChessRules.side_from_contract(starting_side)
	if bot_side == player_side:
		return

	await get_tree().create_timer(bot_think_sec).timeout

	var legal_ucis: Array[String] = []
	for y in range(8):
		for x in range(8):
			var from := Vector2i(x, y)
			var piece := ChessRules.piece_at(state, from)
			if piece == "" or (piece == piece.to_upper()) != (bot_side == "w"):
				continue
			for mv in ChessRules.moves_from(state, from):
				var to: Vector2i = mv["to"]
				var uci := ChessNotation.pos_to_uci(from) + ChessNotation.pos_to_uci(to)
				if piece.to_lower() == "p" and (to.y == 7 or to.y == 0):
					uci += "q"
				if not legal_ucis.has(uci):
					legal_ucis.append(uci)

	if legal_ucis.is_empty():
		_emit_snapshot(_current_fen, "FINISHED", null)
		return

	var chosen := legal_ucis[_rng.randi_range(0, legal_ucis.size() - 1)]
	_current_fen = apply_uci_to_fen(_current_fen, chosen)
	_emit_snapshot(_current_fen, "ACTIVE", chosen)

func _sync_player_side(side_contract: String) -> void:
	RestClient.my_side = side_contract
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm != null:
		gm.my_side = ChessRules.side_from_contract(side_contract)

func _emit_snapshot(fen: String, status: String, last_move_uci) -> void:
	var snap := _make_snapshot(fen, status, last_move_uci)
	RestClient.current_game_snapshot = snap
	WsClient.game_state_updated.emit(snap)

func _make_snapshot(fen: String, status: String, last_move_uci) -> Dictionary:
	return {
		"status": status,
		"position": {
			"fen": fen,
			"lastMoveUci": last_move_uci,
		},
	}

## Aplica um lance UCI em uma FEN (cobre capturas, roque, en passant e promoção).
static func apply_uci_to_fen(fen: String, uci: String) -> String:
	var parts := fen.split(" ")
	if parts.size() < 6 or uci.length() < 4:
		return fen

	var grid: Array = []
	for _y in range(8):
		var row: Array[String] = []
		row.resize(8)
		row.fill("")
		grid.append(row)

	var fen_rows := parts[0].split("/")
	for row_idx in range(8):
		var y := 7 - row_idx
		var x := 0
		for ch in fen_rows[row_idx]:
			if ch.is_valid_int():
				x += int(ch)
			else:
				grid[y][x] = ch
				x += 1

	var from_x := uci.unicode_at(0) - 97
	var from_y := int(uci[1]) - 1
	var to_x := uci.unicode_at(2) - 97
	var to_y := int(uci[3]) - 1
	var promo := uci.substr(4, 1) if uci.length() >= 5 else ""

	var side := parts[1]
	var castling := parts[2]
	var halfmove := int(parts[4])
	var fullmove := int(parts[5])

	var piece: String = grid[from_y][from_x]
	var captured: String = grid[to_y][to_x]

	# En passant
	if piece.to_lower() == "p" and from_x != to_x and captured == "":
		grid[from_y][to_x] = ""
		captured = "p"

	# Roque
	if piece.to_lower() == "k" and abs(to_x - from_x) == 2:
		if to_x == 6:
			grid[from_y][5] = grid[from_y][7]
			grid[from_y][7] = ""
		elif to_x == 2:
			grid[from_y][3] = grid[from_y][0]
			grid[from_y][0] = ""

	var placed := piece
	if not promo.is_empty():
		placed = promo.to_upper() if side == "w" else promo.to_lower()

	grid[to_y][to_x] = placed
	grid[from_y][from_x] = ""

	# Atualiza direitos de roque
	if piece == "K":
		castling = castling.replace("K", "").replace("Q", "")
	elif piece == "k":
		castling = castling.replace("k", "").replace("q", "")
	for sq in [Vector2i(from_x, from_y), Vector2i(to_x, to_y)]:
		if sq == Vector2i(0, 0): castling = castling.replace("Q", "")
		if sq == Vector2i(7, 0): castling = castling.replace("K", "")
		if sq == Vector2i(0, 7): castling = castling.replace("q", "")
		if sq == Vector2i(7, 7): castling = castling.replace("k", "")
	if castling.is_empty():
		castling = "-"

	# Atualiza alvo en passant
	var ep := "-"
	if piece.to_lower() == "p" and abs(to_y - from_y) == 2:
		ep = char(97 + from_x) + str((from_y + to_y) / 2 + 1)

	halfmove = 0 if (piece.to_lower() == "p" or not captured.is_empty()) else halfmove + 1
	if side == "b":
		fullmove += 1
	var next_side := "b" if side == "w" else "w"

	# Reconstrói string da posição
	var out_rows: PackedStringArray = []
	for y in range(7, -1, -1):
		var line := ""
		var empty := 0
		for x in range(8):
			var p: String = grid[y][x]
			if p.is_empty():
				empty += 1
			else:
				if empty > 0:
					line += str(empty)
					empty = 0
				line += p
		if empty > 0:
			line += str(empty)
		out_rows.append(line)

	return "%s %s %s %s %d %d" % ["/".join(out_rows), next_side, castling, ep, halfmove, fullmove]