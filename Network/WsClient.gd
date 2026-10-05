extends Node

var socket := WebSocketPeer.new()
var _last_state := WebSocketPeer.STATE_CLOSED

# Sinais de Conexão
signal connected
signal disconnected(code: int, reason: String)

# Sinais de Eventos (Backend -> Cliente)
signal game_snapshot(payload: Dictionary)
signal game_started(payload: Dictionary)
signal game_move_applied(payload: Dictionary)
signal draw_offered(payload: Dictionary)
signal draw_declined(payload: Dictionary)
signal game_ended(payload: Dictionary)
signal action_rejected(payload: Dictionary)

func _process(_delta: float) -> void:
	# O WebSocketPeer no Godot 4 exige que a função poll() seja chamada a cada frame
	socket.poll()
	var state = socket.get_ready_state()
	
	# Detecta quando a conexão abriu
	if state == WebSocketPeer.STATE_OPEN and _last_state != WebSocketPeer.STATE_OPEN:
		print("WebSocket Conectado!")
		connected.emit()
	
	# Processa mensagens recebidas
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			_parse_message(packet.get_string_from_utf8())
			
	# Detecta quando a conexão fechou
	if state == WebSocketPeer.STATE_CLOSED and _last_state != WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("WebSocket Desconectado. Código: ", code, " Motivo: ", reason)
		disconnected.emit(code, reason)
		
	_last_state = state

# ==========================================
# CONTROLE DE CONEXÃO
# ==========================================

func connect_to_game(game_id: String) -> void:
	# Passamos o token por query string, que é o padrão para autenticar WS em navegadores
	var url = Env.ws_url + "/ws/v1/games/" + game_id + "?token=" + RestClient.session_token
	print("Conectando WS em: ", url)
	
	var err = socket.connect_to_url(url)
	if err != OK:
		printerr("Erro ao tentar iniciar a conexão WebSocket.")

func disconnect_from_game() -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()

# ==========================================
# PARSER DE RECEBIMENTO (Backend -> Cliente)
# ==========================================

func _parse_message(text: String) -> void:
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		return
		
	# Assumindo que a sua API retorna no formato: {"type": "game.move_applied", "payload": {...}}
	var event_type = data.get("type", "")
	var payload = data.get("payload", {})
	
	match event_type:
		"game.snapshot":     game_snapshot.emit(payload)
		"game.started":      game_started.emit(payload)
		"game.move_applied": game_move_applied.emit(payload)
		"draw.offered":      draw_offered.emit(payload)
		"draw.declined":     draw_declined.emit(payload)
		"game.ended":        game_ended.emit(payload)
		"action.rejected":   action_rejected.emit(payload)
		_:
			print("Aviso: Evento WS desconhecido recebido -> ", event_type)

# ==========================================
# FUNÇÕES DE ENVIO (Cliente -> Backend)
# ==========================================

func _send_event(event_type: String, payload: Dictionary = {}) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		printerr("Tentou enviar evento '", event_type, "' mas o WS não está conectado.")
		return
		
	var message = {
		"type": event_type,
		"payload": payload
	}
	socket.send_text(JSON.stringify(message))

# Ações mapeadas da sua API
func send_move(from_square: String, to_square: String, promotion: String = "") -> void:
	_send_event("game.move", {
		"from": from_square, 
		"to": to_square, 
		"promotion": promotion
	})

func send_abandon() -> void:
	_send_event("game.abandon")

func send_draw_offer() -> void:
	_send_event("draw.offer")

func send_draw_respond(accept: bool) -> void:
	_send_event("draw.respond", {"accept": accept})
