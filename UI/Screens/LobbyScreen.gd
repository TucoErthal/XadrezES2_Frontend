extends Control
class_name LobbyScreen

@export var create_game_button: Button
@export var refresh_button: Button
@export var matches_container: VBoxContainer
@export var join_code_input: LineEdit
@export var join_code_button: Button

func _ready() -> void:
	create_game_button.pressed.connect(_on_create_game)
	refresh_button.pressed.connect(_refresh_list)
	join_code_button.pressed.connect(_on_join_by_code)
	
	# Escuta as respostas do servidor
	RestClient.on_public_games_fetched.connect(_on_games_list_received)
	RestClient.on_game_created.connect(_on_game_joined_or_created)
	RestClient.on_game_joined.connect(_on_game_joined_or_created)
	
	_refresh_list()

func _refresh_list() -> void:
	refresh_button.disabled = true
	RestClient.fetch_public_games()

func _on_games_list_received(success: bool, games: Array) -> void:
	refresh_button.disabled = false
	
	# Limpa a lista atual na tela
	for child in matches_container.get_children():
		child.queue_free()
		
	if not success:
		print("Erro ao carregar partidas.")
		return
		
	# Cria um botão na interface para cada partida encontrada
	for game in games:
		var btn = Button.new()
		btn.text = "Sala: " + game.get("id", "Desconhecida")
		btn.pressed.connect(func(): _on_join_room_clicked(game.get("id")))
		matches_container.add_child(btn)

func _on_create_game() -> void:
	create_game_button.disabled = true
	# Pode passar configurações se sua API exigir (ex: tempo, cor)
	RestClient.create_game({"is_public": true})

func _on_join_by_code() -> void:
	var code = join_code_input.text.strip_edges()
	if not code.is_empty():
		RestClient.join_by_code(code)

func _on_join_room_clicked(game_id: String) -> void:
	RestClient.join_game(game_id)

func _on_game_joined_or_created(success: bool, data: Dictionary) -> void:
	create_game_button.disabled = false
	if success:
		var game_id = data.get("id", "")
		print("Entrando no jogo ", game_id)
		
		# Conecta no WebSocket imediatamente usando o ID da sala
		WsClient.connect_to_game(game_id)
		
		# Manda para a cena 3D do jogo
		Router.navigate_to("Level")
	else:
		printerr("Erro ao entrar/criar sala: ", data)
