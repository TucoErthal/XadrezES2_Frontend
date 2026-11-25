extends Node

## Cliente WebSocket da partida.
##
## As mensagens de ENTRADA (`game.state`, `game.error`) e a inscrição
## (`game.subscribe`) seguem o contrato publicado em `docs/API.md` do backend.
##
## As mensagens de SAÍDA de jogo — lance, desistência e empate — ainda não
## fazem parte daquele contrato ("Comandos de movimento, abandono e empate não
## fazem parte deste contrato WebSocket nesta versão"). O formato usado aqui é
## a proposta descrita em `docs/contrato-jogo-proposto.md`, e está concentrado
## nos métodos de envio abaixo: quando o grupo fechar o formato definitivo,
## só estes métodos mudam.

var socket := WebSocketPeer.new()
var _last_state := WebSocketPeer.STATE_CLOSED
var current_subscribed_game: String = ""

## Revisão autoritativa conhecida da partida, usada para travar envios
## concorrentes (o servidor responde STALE_REVISION se estiver vencida).
var current_revision: int = -1

var _request_seq: int = 0
var _reconnect_delay: float = 0.0

const RECONNECT_DELAY_S := 2.0

signal game_state_updated(snapshot: Dictionary)
signal game_error_received(code: String, message: String)
signal game_became_active() # Atalho para a tela de espera
signal connection_changed(connected: bool)

func _process(delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and _last_state != WebSocketPeer.STATE_OPEN:
		_reconnect_delay = 0.0
		connection_changed.emit(true)
		if not current_subscribed_game.is_empty():
			_send_subscribe(current_subscribed_game)

	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			_parse_message(packet.get_string_from_utf8())

	# Queda de conexão: tenta reconectar e reassinar a partida.
	if state == WebSocketPeer.STATE_CLOSED and _last_state == WebSocketPeer.STATE_OPEN:
		connection_changed.emit(false)
		_reconnect_delay = RECONNECT_DELAY_S

	if _reconnect_delay > 0.0 and not current_subscribed_game.is_empty():
		_reconnect_delay -= delta
		if _reconnect_delay <= 0.0:
			connect_and_subscribe(current_subscribed_game)

	_last_state = state

func is_connected_to_game() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func connect_and_subscribe(game_id: String) -> void:
	current_subscribed_game = game_id
	var url: String = Env.ws_url + "/ws"
	socket.set_handshake_headers(["X-Session-Token: " + RestClient.session_token])
	socket.connect_to_url(url)

func disconnect_from_game() -> void:
	current_subscribed_game = ""
	current_revision = -1
	_reconnect_delay = 0.0
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close()

func _next_request_id(prefix: String) -> String:
	_request_seq += 1
	return "%s-%d" % [prefix, _request_seq]

func _send(message: Dictionary) -> bool:
	if not is_connected_to_game():
		push_warning("WS não conectado; mensagem descartada: " + str(message.get("type", "")))
		return false
	socket.send_text(JSON.stringify(message))
	return true

func _send_subscribe(game_id: String) -> void:
	_send({
		"type": "game.subscribe",
		"requestId": _next_request_id("sub"),
		"gameId": game_id,
	})

# ==========================================================================
# Comandos de jogo (contrato proposto — ver cabeçalho)
# ==========================================================================
var mock_send_move: Callable
## Envia um lance em UCI ("e2e4", "e7e8q"). Devolve false se não deu para enviar.
func send_move(uci: String) -> bool:
	if mock_send_move.is_valid():
		return bool(mock_send_move.call(uci))
	if current_subscribed_game.is_empty() or uci.is_empty():
		return false
	return _send({
		"type": "game.move",
		"requestId": _next_request_id("mv"),
		"gameId": current_subscribed_game,
		"revision": current_revision,
		"uci": uci,
	})

func send_resign() -> bool:
	if current_subscribed_game.is_empty():
		return false
	return _send({
		"type": "game.abandon",
		"requestId": _next_request_id("rs"),
		"gameId": current_subscribed_game,
	})

func send_draw_offer() -> bool:
	if current_subscribed_game.is_empty():
		return false
	return _send({
		"type": "draw.offer",
		"requestId": _next_request_id("do"),
		"gameId": current_subscribed_game,
	})

func send_draw_respond(accept: bool) -> bool:
	if current_subscribed_game.is_empty():
		return false
	return _send({
		"type": "draw.respond",
		"requestId": _next_request_id("dr"),
		"gameId": current_subscribed_game,
		"accept": accept,
	})

# ==========================================================================

func _parse_message(text: String) -> void:
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		return

	var msg_type: String = data.get("type", "")
	if msg_type == "game.state":
		var snapshot = data.get("snapshot", {})
		if typeof(snapshot) != TYPE_DICTIONARY:
			return
		RestClient.current_game_snapshot = snapshot

		var rev = snapshot.get("revision")
		if rev != null:
			current_revision = int(rev)

		game_state_updated.emit(snapshot)

		if snapshot.get("status") == "ACTIVE":
			game_became_active.emit()

	elif msg_type == "game.error":
		game_error_received.emit(data.get("code", ""), data.get("message", ""))
