extends Control
class_name LobbyScreen

@export var background: ColorRect
@export var title_label: Label
@export var btn_refresh: Button
@export var btn_create: Button
@export var match_list_container: VBoxContainer
@export var input_code: LineEdit
@export var btn_join_code: Button
@export var btn_back: Button

func _ready() -> void:
	print("=> [LobbyScreen] Iniciando _ready...")
	_apply_modern_theme()
	
	if btn_refresh: btn_refresh.pressed.connect(_on_refresh_pressed)
	if btn_create: btn_create.pressed.connect(_on_create_pressed)
	if btn_join_code: btn_join_code.pressed.connect(_on_join_code_pressed)
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
		# UITheme.style_button(btn_back, "ghost")
	
	# Verifica se já não estava conectado antes para evitar bugs de duplicação
	if not RestClient.on_public_games_fetched.is_connected(_on_games_fetched):
		RestClient.on_public_games_fetched.connect(_on_games_fetched)
		
	if not RestClient.on_game_joined.is_connected(_on_game_joined_result):
		RestClient.on_game_joined.connect(_on_game_joined_result)
	
	print("=> [LobbyScreen] Sinais conectados. Chamando fetch...")
	_fetch_matches()

func _fetch_matches() -> void:
	print("=> [LobbyScreen] Solicitando partidas ao RestClient...")
	RestClient.fetch_public_games()

func _on_games_fetched(success: bool, data: Dictionary) -> void:
	if not success:
		print("Erro ao buscar partidas: ", data)
		_populate_match_list([])
		return
		
	var games = data.get("games", [])
	var formatted_matches = []
	
	# 3. Mapeia os dados do backend para o formato que a UI espera
	for g in games:
		formatted_matches.append({
			"id": g.get("gameId", ""),
			"host": g.get("creatorUsername", "Oponente"),
			"status": g.get("status", "Aguardando"),
			"players": "1/2" # Normalmente só partidas aguardando são listadas
		})
		
	_populate_match_list(formatted_matches)

func _populate_match_list(matches: Array) -> void:
	# 1. Limpa a lista atual
	for child in match_list_container.get_children():
		child.queue_free()
		
	# 2. Se não houver partidas
	if matches.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Nenhuma partida encontrada."
		empty_label.add_theme_color_override("font_color", Color("#888899"))
		match_list_container.add_child(empty_label)
		return
		
	# 3. Cria o visual para cada partida
	for match_data in matches:
		var item = _create_match_ui_item(match_data)
		match_list_container.add_child(item)

func _create_match_ui_item(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_card(panel, 20, 14)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var info_label := Label.new()
	info_label.text = "Sala de " + data["host"] + "  •  [" + data["players"] + "]"
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.add_theme_color_override("font_color", Color("#F3F5F9"))
	info_label.add_theme_font_size_override("font_size", 17)
	hbox.add_child(info_label)

	var btn_join := Button.new()
	btn_join.text = "Entrar" if data["players"] == "1/2" else "Cheia"
	btn_join.disabled = (data["players"] != "1/2")
	UITheme.style_button(btn_join, "success" if not btn_join.disabled else "secondary")
	btn_join.pressed.connect(_on_join_pressed.bind(data["id"]))
	hbox.add_child(btn_join)

	UITheme.apply_font(panel)
	return panel


# --- Ações dos Botões ---

func _on_refresh_pressed() -> void:
	_fetch_matches()

func _on_create_pressed() -> void:
	Router.navigate_to("CreateRoom")

# Clique no botão 'Entrar' de uma partida da lista pública
func _on_join_pressed(match_id: String) -> void:
	print("Entrando na sala pública com gameId: ", match_id)
	RestClient.join_game(match_id)

# Clique no botão 'Entrar com Código'
func _on_join_code_pressed() -> void:
	var code = input_code.text.strip_edges()
	if code.is_empty():
		print("Por favor, digite um código!")
		return
		
	print("Entrando na sala privada via código: ", code)
	btn_join_code.disabled = true
	RestClient.join_game_by_code(code)

func _on_game_joined_result(success: bool, data: Dictionary) -> void:
	if btn_refresh: btn_refresh.disabled = false
	if btn_join_code: btn_join_code.disabled = false
	
	if success:
		print("Entrou na partida com sucesso!")
		# Se sucesso, transita para a tela de jogo
		Router.navigate_to("GameUI")
	else:
		print("Erro ao entrar na sala: ", data)
		# Opcional: Você pode colocar uma Label na tela para mostrar o erro ao usuário

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	# Volta para a tela anterior no histórico (ou "Home" como fallback)
	Router.go_back("Home")

# --- Estilização Geral da Tela ---

func _apply_modern_theme() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if background:
		background.visible = false

	UITheme.apply_chess_background(self)
	UITheme.apply_font(self)

	if match_list_container:
		match_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if title_label:
		UITheme.style_title(title_label, true)
		title_label.add_theme_font_size_override("font_size", 28)

	if btn_back:
		UITheme.style_button(btn_back, "ghost")
		btn_back.add_theme_font_size_override("font_size", 18)

	if btn_refresh:
		UITheme.style_button(btn_refresh, "secondary")
		btn_refresh.add_theme_font_size_override("font_size", 16)

	if btn_create:
		UITheme.style_button(btn_create, "gold")
		btn_create.add_theme_font_size_override("font_size", 16)

	if input_code:
		UITheme.style_input(input_code)

	if btn_join_code:
		UITheme.style_button(btn_join_code, "success")
		btn_join_code.add_theme_font_size_override("font_size", 16)
