extends Node

var base_url: String = "http://localhost:3000/api" # Substitua pela URL da sua API depois
var session_token: String = ""

# Sinais que a Interface de Usuário vai escutar
signal on_login_completed(success: bool, data: Dictionary)
signal on_matches_fetched(success: bool, data: Array)

# Cria um nó temporário para cada requisição para permitir requisições simultâneas
func _create_request_node() -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	return http

# Endpoint 1: Entrar como Convidado
func login_guest(username: String) -> void:
	var http := _create_request_node()
	var url := base_url + "/auth/guest"
	var body := JSON.stringify({"username": username})
	var headers := ["Content-Type: application/json"]
	
	# Conecta o sinal dinamicamente usando uma função anônima (Lambda)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		
		if response_code == 200 or response_code == 201:
			if response.has("token"):
				session_token = response["token"]
			on_login_completed.emit(true, response)
		else:
			printerr("Erro no Login: ", response_code)
			on_login_completed.emit(false, response)
			
		http.queue_free() # Limpa o nó após o uso
	)
	
	http.request(url, headers, HTTPClient.METHOD_POST, body)

# Endpoint 2: Buscar partidas no Lobby
func fetch_matches() -> void:
	var http := _create_request_node()
	var url := base_url + "/matches"
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + session_token
	]
	
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray):
		var response = _parse_response(body_bytes)
		
		if response_code == 200:
			# Assumindo que a API retorna um array de salas
			var matches: Array = response if response is Array else response.get("matches", [])
			on_matches_fetched.emit(true, matches)
		else:
			printerr("Erro ao buscar partidas: ", response_code)
			on_matches_fetched.emit(false, [])
			
		http.queue_free()
	)
	
	http.request(url, headers, HTTPClient.METHOD_GET)

# Função utilitária para converter os bytes da resposta da API em um Dicionário ou Array
func _parse_response(body: PackedByteArray) -> Variant:
	if body.is_empty():
		return {}
	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	return parsed if parsed != null else {}
