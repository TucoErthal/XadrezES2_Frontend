extends Node

var socket := WebSocketPeer.new()
var _last_state := WebSocketPeer.STATE_CLOSED
var current_subscribed_game: String = ""

signal game_state_updated(snapshot: Dictionary)
signal game_error_received(code: String, message: String)
signal game_became_active() # Atalho para a tela de espera

func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN and _last_state != WebSocketPeer.STATE_OPEN:
		print("WS Conectado!")
		if not current_subscribed_game.is_empty():
			_send_subscribe(current_subscribed_game)
			
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			_parse_message(packet.get_string_from_utf8())
			
	_last_state = state

func connect_and_subscribe(game_id: String) -> void:
	current_subscribed_game = game_id
	var url = Env.ws_url + "/ws"
	
	# Godot 4 permite setar headers para o handshake do WS
	socket.set_handshake_headers(["X-Session-Token: " + RestClient.session_token])
	socket.connect_to_url(url)

func _send_subscribe(game_id: String) -> void:
	var msg = {
		"type": "game.subscribe",
		"requestId": "sub-" + str(Time.get_unix_time_from_system()),
		"gameId": game_id
	}
	socket.send_text(JSON.stringify(msg))

func _parse_message(text: String) -> void:
	var data = JSON.parse_string(text)
	if not data is Dictionary: return
	
	var msg_type = data.get("type", "")
	if msg_type == "game.state":
		var snapshot = data.get("snapshot", {})
		RestClient.current_game_snapshot = snapshot # Mantém atualizado
		game_state_updated.emit(snapshot)
		
		# Verifica se a partida começou (Transição de WAITING para ACTIVE)
		if snapshot.get("status") == "ACTIVE":
			game_became_active.emit()
			
	elif msg_type == "game.error":
		game_error_received.emit(data.get("code", ""), data.get("message", ""))
