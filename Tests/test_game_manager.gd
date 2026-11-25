extends Node

const GAME_SCENE_PATH := "res://Levels/Level.tscn" # <-- ajuste para o caminho real da sua cena

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
const AFTER_E4_FEN := "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
const PROMO_FEN := "8/P7/8/8/8/8/8/4K2k w - - 0 1"
const CHECK_FEN := "4k3/4Q3/8/8/8/8/8/4K3 b - - 0 1"

var _passed := 0
var _failed := 0
var _sent_moves: Array[String] = []
var _mock_online := true

func _ready() -> void:
	_run_all()

func _run_all() -> void:
	WsClient.mock_send_move = func(uci: String) -> bool:
		if not _mock_online:
			return false
		_sent_moves.append(uci)
		return true

	var scene_res := load(GAME_SCENE_PATH) as PackedScene
	if scene_res == null:
		printerr("FALHA: não foi possível carregar ", GAME_SCENE_PATH)
		get_tree().quit(1)
		return

	RestClient.my_side = "WHITE"
	RestClient.current_game_snapshot = {}

	var level := scene_res.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm == null:
		printerr("FALHA: nenhum nó no grupo 'game_manager' encontrado em ", GAME_SCENE_PATH)
		get_tree().quit(1)
		return

	await _test_initial_fen_and_pieces(gm)
	await _test_selection_and_highlights(gm)
	await _test_send_move_and_server_rejection(gm)
	await _test_offline_rejection(gm)
	await _test_promotion_auto_and_ui_flow(gm)
	await _test_check_and_last_move_highlights(gm)
	await _test_game_finished_clears_selection(gm)

	WsClient.mock_send_move = Callable()
	print("\n=== Resultado: %d passaram, %d falharam ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

# ==========================================================================
# CASOS DE TESTE
# ==========================================================================

func _test_initial_fen_and_pieces(gm: GameManager) -> void:
	await _push_snapshot(START_FEN, "ACTIVE", null)
	_assert_eq(Piece.all_pieces.size(), 32, "FEN inicial deve gerar 32 peças")
	_assert_eq(gm.my_side, "w", "my_side deve converter WHITE -> w")
	_assert_eq(gm.is_my_turn, true, "Brancas começam jogando")

func _test_selection_and_highlights(gm: GameManager) -> void:
	# Peça adversária em e7 (4, 6) não deve selecionar
	gm._handle_click(Vector2i(4, 6))
	_assert_eq(gm._input_state, GameManager.InputState.IDLE, "Não deve selecionar peça adversária")

	# Peão branco em e2 (4, 1)
	gm._handle_click(Vector2i(4, 1))
	_assert_eq(gm._input_state, GameManager.InputState.SELECTED, "Deve entrar em SELECTED ao clicar em peça própria")

	var highlighted := _highlighted_coords()
	_assert_true(highlighted.has(Vector2i(4, 1)), "Casa selecionada e2 deve ter marcador")
	_assert_true(highlighted.has(Vector2i(4, 2)), "Destino e3 deve ter marcador")
	_assert_true(highlighted.has(Vector2i(4, 3)), "Destino e4 deve ter marcador")

func _test_send_move_and_server_rejection(gm: GameManager) -> void:
	_sent_moves.clear()
	_mock_online = true

	var rejected := []
	var on_reject := func(code: String, msg: String): rejected.append([code, msg])
	gm.move_rejected.connect(on_reject)

	# Clica em e4 (4, 3) com e2 já selecionado
	gm._handle_click(Vector2i(4, 3))
	_assert_eq(_sent_moves, ["e2e4"], "Deve enviar UCI e2e4 ao servidor")
	_assert_eq(gm._input_state, GameManager.InputState.AWAITING, "Deve aguardar resposta do servidor")

	# Simula recusa do backend: mantém seleção para o jogador escolher outra casa
	WsClient.game_error_received.emit("ILLEGAL_MOVE", "Recusado")
	_assert_eq(gm._input_state, GameManager.InputState.SELECTED, "Erro durante AWAITING deve voltar para SELECTED")
	_assert_eq(rejected.size(), 1, "Deve emitir move_rejected")
	_assert_eq(rejected[0][0], "ILLEGAL_MOVE", "Código do erro deve ser repassado")

	gm.move_rejected.disconnect(on_reject)

	# Agora o servidor aceita enviando a nova FEN
	await _push_snapshot(AFTER_E4_FEN, "ACTIVE", "e2e4")
	_assert_eq(gm._input_state, GameManager.InputState.IDLE, "Novo snapshot deve limpar seleção")
	_assert_eq(gm.is_my_turn, false, "Após lance das Brancas, turno passa às Pretas")

func _test_offline_rejection(gm: GameManager) -> void:
	await _push_snapshot(START_FEN, "ACTIVE", null)
	_sent_moves.clear()
	_mock_online = false

	var rejected_codes: Array[String] = []
	var on_reject := func(code: String, _msg: String): rejected_codes.append(code)
	gm.move_rejected.connect(on_reject)

	gm._handle_click(Vector2i(4, 1))
	gm._handle_click(Vector2i(4, 3))

	_assert_eq(rejected_codes, ["OFFLINE"], "send_move() == false deve emitir move_rejected('OFFLINE')")
	_assert_eq(gm._input_state, GameManager.InputState.SELECTED, "Falha offline não deve travar em AWAITING")

	gm.move_rejected.disconnect(on_reject)
	_mock_online = true

func _test_promotion_auto_and_ui_flow(gm: GameManager) -> void:
	await _push_snapshot(PROMO_FEN, "ACTIVE", null)
	_sent_moves.clear()

	# 1) Sem UI conectada em promotion_requested -> promove automaticamente para dama
	gm._handle_click(Vector2i(0, 6)) # a7
	gm._handle_click(Vector2i(0, 7)) # a8
	_assert_eq(_sent_moves, ["a7a8q"], "Sem listener de promoção, deve enviar a7a8q")

	# Recusa apenas para voltar ao estado SELECTED sem mudar FEN
	WsClient.game_error_received.emit("TEST_RESET", "Reset")
	_sent_moves.clear()

	# 2) Com UI conectada -> cancela e depois confirma cavalo ('n')
	var promo_events := []
	var on_promo := func(from: Vector2i, to: Vector2i): promo_events.append([from, to])
	gm.promotion_requested.connect(on_promo)

	gm._handle_click(Vector2i(0, 7))
	_assert_eq(promo_events.size(), 1, "Com listener conectado, deve emitir promotion_requested")
	_assert_eq(_sent_moves.size(), 0, "Não deve enviar lance antes da confirmação da UI")

	gm.cancel_promotion()
	_assert_eq(_sent_moves.size(), 0, "cancel_promotion não deve enviar lance")

	gm._handle_click(Vector2i(0, 7))
	gm.confirm_promotion("n")
	_assert_eq(_sent_moves, ["a7a8n"], "confirm_promotion('n') deve enviar a7a8n")

	gm.promotion_requested.disconnect(on_promo)

func _test_check_and_last_move_highlights(gm: GameManager) -> void:
	await _push_snapshot(CHECK_FEN, "ACTIVE", "e2e7")
	var highlighted := _highlighted_coords()
	_assert_true(highlighted.has(Vector2i(4, 1)), "Origem do último lance (e2) deve estar marcada")
	_assert_true(highlighted.has(Vector2i(4, 6)), "Destino do último lance (e7) deve estar marcado")
	_assert_true(highlighted.has(Vector2i(4, 7)), "Rei preto em xeque (e8) deve estar marcado")

func _test_game_finished_clears_selection(gm: GameManager) -> void:
	await _push_snapshot(START_FEN, "ACTIVE", null)
	gm._handle_click(Vector2i(4, 1))
	_assert_eq(gm._input_state, GameManager.InputState.SELECTED, "Peça selecionada antes do encerramento")

	await _push_snapshot(START_FEN, "FINISHED", null)
	_assert_eq(gm.game_status, "FINISHED", "game_status deve atualizar mesmo se a FEN repetir")
	_assert_eq(gm._input_state, GameManager.InputState.IDLE, "Snapshot não-ACTIVE deve limpar a seleção")

# ==========================================================================
# HELPERS
# ==========================================================================

func _push_snapshot(fen: String, status: String, last_move_uci) -> void:
	WsClient.game_state_updated.emit({
		"status": status,
		"position": {
			"fen": fen,
			"lastMoveUci": last_move_uci,
		},
	})
	# Dois frames para cobrir queue_free() + await process_frame em _rebuild_pieces()
	await get_tree().process_frame
	await get_tree().process_frame

func _highlighted_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if Board.instance == null:
		return coords
	var markers := Board.instance.get_node_or_null("Highlights")
	if markers == null:
		return coords
	for child in markers.get_children():
		if child.has_meta("coords"):
			coords.append(child.get_meta("coords"))
	return coords

func _assert_eq(actual, expected, label: String) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] ", label)
	else:
		_failed += 1
		printerr("[FAIL] %s | esperado=%s, obtido=%s" % [label, str(expected), str(actual)])

func _assert_true(cond: bool, label: String) -> void:
	_assert_eq(cond, true, label)
