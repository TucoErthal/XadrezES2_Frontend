extends Node

var session_token: String = ""

signal on_login_completed(success: bool, data: Dictionary)
signal on_game_created(success: bool, data: Dictionary)
signal on_public_games_fetched(success: bool, data: Array)
signal on_game_fetched(success: bool, data: Dictionary)
signal on_game_joined(success: bool, data: Dictionary)

func _create_request_node() -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	return http

func _get_headers(include_auth: bool = true) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if include_auth and not session_token.is_empty():
		headers.append("Authorization: Bearer " + session_token)
	return headers

func _parse_response(body: PackedByteArray) -> Variant:
	if body.is_empty(): return {}
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	return parsed if parsed != null else {}

# ==========================================
# ENDPOINTS DE SESSÃO
# ==========================================

# POST /api/v1/sessions/guest
func login_guest(username: String) -> void:
	var http := _create_request_node()
	var body := JSON.stringify({"username": username})
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		if code == 200 or code == 201:
			session_token = response.get("token", "")
			on_login_completed.emit(true, response)
		else:
			on_login_completed.emit(false, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/api/v1/sessions/guest", _get_headers(false), HTTPClient.METHOD_POST, body)

# ==========================================
# ENDPOINTS DE JOGO
# ==========================================

# POST /api/v1/games
func create_game(config_data: Dictionary = {}) -> void:
	var http := _create_request_node()
	var body := JSON.stringify(config_data)
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		on_game_created.emit(code == 200 or code == 201, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/api/v1/games", _get_headers(), HTTPClient.METHOD_POST, body)

# GET /api/v1/games/public
func fetch_public_games() -> void:
	var http := _create_request_node()
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		var games_array: Array = response if response is Array else response.get("games", [])
		on_public_games_fetched.emit(code == 200, games_array)
		http.queue_free()
	)
	http.request(Env.api_url + "/api/v1/games/public", _get_headers(), HTTPClient.METHOD_GET)

# GET /api/v1/games/{gameId}
func get_game(game_id: String) -> void:
	var http := _create_request_node()
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		on_game_fetched.emit(code == 200, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/api/v1/games/" + game_id, _get_headers(), HTTPClient.METHOD_GET)

# POST /api/v1/games/{gameId}/join
func join_game(game_id: String) -> void:
	var http := _create_request_node()
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		on_game_joined.emit(code == 200, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/api/v1/games/" + game_id + "/join", _get_headers(), HTTPClient.METHOD_POST, "")

# POST /api/v1/games/code/{code}/join
func join_by_code(room_code: String) -> void:
	var http := _create_request_node()
	
	http.request_completed.connect(func(_res: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		on_game_joined.emit(code == 200, response)
		http.queue_free()
	)
	http.request(Env.api_url + "/api/v1/games/code/" + room_code + "/join", _get_headers(), HTTPClient.METHOD_POST, "")
