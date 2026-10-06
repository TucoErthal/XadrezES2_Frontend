extends Control
class_name LobbyScreen

# Referências exportadas (arraste do Inspector)
@export var background: ColorRect
@export var title_label: Label
@export var btn_refresh: Button
@export var btn_create: Button
@export var match_list_container: VBoxContainer
@export var input_code: LineEdit
@export var btn_join_code: Button

func _ready() -> void:
	_apply_modern_theme()
	
	if btn_refresh: btn_refresh.pressed.connect(_on_refresh_pressed)
	if btn_create: btn_create.pressed.connect(_on_create_pressed)
	if btn_join_code: btn_join_code.pressed.connect(_on_join_code_pressed)
	
	_fetch_matches()

# --- Comunicação com o Servidor (Mock) ---

func _fetch_matches() -> void:
	# Aqui você chamará o seu RestClient. Ex: RestClient.get_rooms()
	print("Buscando partidas no servidor...")
	
	# Simulando dados recebidos da API (Mock Data)
	var mock_api_response = [
		{"id": "101", "host": "Jogador123", "status": "Aguardando", "players": "1/2"},
		{"id": "102", "host": "MestreXadrez", "status": "Aguardando", "players": "1/2"},
		{"id": "103", "host": "Visitante_99", "status": "Em Jogo", "players": "2/2"}
	]
	
	_populate_match_list(mock_api_response)

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
	var panel = PanelContainer.new()
	
	# Estilo do painel da partida
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#22222d") # Fundo um pouco mais claro que a tela
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 15
	panel_style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Info da Partida
	var info_label = Label.new()
	info_label.text = "Sala de " + data["host"] + " - [" + data["players"] + "]"
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(info_label)
	
	# Botão Entrar
	var btn_join = Button.new()
	btn_join.text = "Entrar" if data["players"] == "1/2" else "Cheia"
	btn_join.disabled = (data["players"] != "1/2")
	btn_join.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if !btn_join.disabled else Control.CURSOR_ARROW
	
	# Estilização do Botão Entrar
	var normal_btn = StyleBoxFlat.new()
	normal_btn.bg_color = Color("#2a2a35")
	normal_btn.corner_radius_top_left = 6
	normal_btn.corner_radius_top_right = 6
	normal_btn.corner_radius_bottom_left = 6
	normal_btn.corner_radius_bottom_right = 6
	normal_btn.content_margin_left = 20
	normal_btn.content_margin_right = 20
	
	var hover_btn = normal_btn.duplicate()
	hover_btn.bg_color = Color("#10b981") # Verde para indicar ação positiva
	
	btn_join.add_theme_stylebox_override("normal", normal_btn)
	btn_join.add_theme_stylebox_override("hover", hover_btn)
	btn_join.add_theme_stylebox_override("pressed", normal_btn)
	btn_join.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	
	# Conecta o clique passando o ID da partida (usando bind)
	btn_join.pressed.connect(_on_join_pressed.bind(data["id"]))
	hbox.add_child(btn_join)
	
	return panel


# --- Ações dos Botões ---

func _on_refresh_pressed() -> void:
	_fetch_matches()

func _on_create_pressed() -> void:
	# Agora o botão criar apenas navega para a nova tela
	Router.navigate_to("CreateRoom")

func _on_join_pressed(match_id: String) -> void:
	print("Tentando entrar na partida: ", match_id)
	# Exemplo: RestClient.join_room(match_id)
	# Após o sucesso da API:
	# Router.navigate_to("GameUI")

func _on_join_code_pressed() -> void:
	var code = input_code.text.strip_edges()
	if code.is_empty():
		print("Por favor, digite um código!")
		return
		
	print("Tentando entrar na sala privada com código: ", code)
	# Ex: RestClient.join_private_room(code)
	# Router.navigate_to("GameUI")

# --- Estilização Geral da Tela ---

func _apply_modern_theme() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	if background:
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.color = Color("#181820")
		
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color("#ffffff"))
	
	# Estilo para os botões do cabeçalho
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#3d73ff")
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_left = 24
	btn_style.content_margin_right = 24
	btn_style.content_margin_top = 10
	btn_style.content_margin_bottom = 10
	
	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color("#5a8bff")
	
	for btn in [btn_refresh, btn_create]:
		if btn:
			btn.add_theme_stylebox_override("normal", btn_style)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("pressed", btn_style)
			btn.add_theme_font_size_override("font_size", 18)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Estilo do campo de código (LineEdit)
	if input_code:
		var line_edit_style = StyleBoxFlat.new()
		line_edit_style.bg_color = Color("#22222d")
		line_edit_style.corner_radius_top_left = 8
		line_edit_style.corner_radius_top_right = 8
		line_edit_style.corner_radius_bottom_left = 8
		line_edit_style.corner_radius_bottom_right = 8
		line_edit_style.content_margin_left = 15
		line_edit_style.content_margin_right = 15
		
		input_code.add_theme_stylebox_override("normal", line_edit_style)
		input_code.add_theme_stylebox_override("focus", line_edit_style)
		input_code.add_theme_font_size_override("font_size", 16)
	
	# Estilo do Botão Entrar com Código (Verde)
	if btn_join_code:
		var join_code_style = StyleBoxFlat.new()
		join_code_style.bg_color = Color("#10b981")
		join_code_style.corner_radius_top_left = 8
		join_code_style.corner_radius_top_right = 8
		join_code_style.corner_radius_bottom_left = 8
		join_code_style.corner_radius_bottom_right = 8
		join_code_style.content_margin_left = 20
		join_code_style.content_margin_right = 20
		
		var join_code_hover = join_code_style.duplicate()
		join_code_hover.bg_color = Color("#34d399")
		
		btn_join_code.add_theme_stylebox_override("normal", join_code_style)
		btn_join_code.add_theme_stylebox_override("hover", join_code_hover)
		btn_join_code.add_theme_font_size_override("font_size", 16)
		btn_join_code.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
