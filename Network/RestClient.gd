extends Node

var session_token: String = ""
var current_game_snapshot: Dictionary = {} # Guarda os dados da partida atual

signal on_login_completed(success: bool, data: Dictionary)
signal on_game_created(success: bool, data: Dictionary)
signal on_public_games_fetched(success: bool, data: Dictionary)
signal on_game_joined(success: bool, data: Dictionary)

func _create_request_node() -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	return http

# A API exige X-Session-Token em vez de Authorization: Bearer
func _get_headers(include_auth: bool = true) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if include_auth and not session_token.is_empty():
		headers.append("X-Session-Token: " + session_token)
	return headers

func _parse_response(body: PackedByteArray) -> Variant:
	if body.is_empty(): return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed != null else {}

# ==========================================
# ENDPOINTS
# ==========================================

# POST /v1/sessions (O corpo é vazio na nova API)
func login_guest(_username: String) -> void:
	var http := _create_request_node()
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		if code == 200 or code == 201:
			session_token = response.get("recoveryToken", "")
			on_login_completed.emit(true, response)
		else:
			on_login_completed.emit(false, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/v1/sessions", _get_headers(false), HTTPClient.METHOD_POST, "")

# GET /v1/games
func fetch_public_games() -> void:
	var http := _create_request_node()
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		on_public_games_fetched.emit(code == 200, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/v1/games?page=0&size=20", _get_headers(), HTTPClient.METHOD_GET)

# POST /v1/games
func create_game(is_private: bool, time_ms: int) -> void:
	var http := _create_request_node()
	var visibility = "PRIVATE" if is_private else "PUBLIC"
	var payload = {
		"visibility": visibility,
		"timeControl": {"initialTimeMs": time_ms, "incrementMs": 0}
	}
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		if code == 201:
			current_game_snapshot = response
			on_game_created.emit(true, response)
		else:
			on_game_created.emit(false, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/v1/games", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))

# POST /v1/games/join (Para entrada via CÓDIGO de sala privada, sem saber o gameId)
func join_game_by_code(entry_code: String) -> void:
	var http := _create_request_node()
	var payload = {"entryCode": entry_code}
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		if code == 200:
			current_game_snapshot = response
			on_game_joined.emit(true, response)
		else:
			on_game_joined.emit(false, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/v1/games/join", _get_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))

# POST /v1/games/{gameId}/join (Para entrada pública por ID ou privada quando já se tem o gameId)
func join_game(game_id: String, entry_code: String = "") -> void:
	var http := _create_request_node()
	var payload_str = ""
	
	if not entry_code.is_empty():
		payload_str = JSON.stringify({"entryCode": entry_code})
		
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		if code == 200:
			current_game_snapshot = response
			on_game_joined.emit(true, response)
		else:
			on_game_joined.emit(false, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/v1/games/" + game_id + "/join", _get_headers(), HTTPClient.METHOD_POST, payload_str)
