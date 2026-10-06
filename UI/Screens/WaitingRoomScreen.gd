extends Control
class_name WaitingRoomScreen

@export var background: ColorRect
@export var card_panel: PanelContainer
@export var title_label: Label
@export var input_code: LineEdit
@export var btn_copy: Button
@export var btn_cancel: Button
@export var btn_mock_join: Button

func _ready() -> void:
	_apply_modern_theme()
	
	if btn_copy: btn_copy.pressed.connect(_on_copy_pressed)
	if btn_cancel: btn_cancel.pressed.connect(_on_cancel_pressed)
	if btn_mock_join: btn_mock_join.pressed.connect(_on_mock_join_pressed)
	
	# Simula o recebimento de um código da API
	_set_room_code("XYZ-1234")
	
	# Aqui você iniciaria um "Polling" (consultar a API de X em X segundos)
	# ou aguardaria um evento de WebSocket para saber quando o outro jogador entrou.

func _set_room_code(code: String) -> void:
	if input_code:
		input_code.text = code

func _on_copy_pressed() -> void:
	# Copia o texto para a área de transferência do Sistema Operacional
	DisplayServer.clipboard_set(input_code.text)
	btn_copy.text = "Copiado!"
	
	# Volta o texto para "Copiar" após 2 segundos
	await get_tree().create_timer(2.0).timeout
	if btn_copy: btn_copy.text = "Copiar"

func _on_cancel_pressed() -> void:
	print("Cancelando sala...")
	# Exemplo: RestClient.cancel_room(input_code.text)
	Router.navigate_to("Lobby")

func _on_mock_join_pressed() -> void:
	# Este botão serve apenas para testar a navegação.
	# Quando o WebSocket/API avisar que o jogador 2 entrou, você chama esta mesma rota.
	print("Oponente conectado! Iniciando partida...")
	Router.navigate_to("GameUI")

func _apply_modern_theme() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if background:
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.color = Color("#181820")
		
	if card_panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color("#22222d")
		panel_style.corner_radius_top_left = 16
		panel_style.corner_radius_top_right = 16
		panel_style.corner_radius_bottom_left = 16
		panel_style.corner_radius_bottom_right = 16
		card_panel.add_theme_stylebox_override("panel", panel_style)
		
	if title_label:
		title_label.add_theme_font_size_override("font_size", 28)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if input_code:
		var line_edit_style = StyleBoxFlat.new()
		line_edit_style.bg_color = Color("#181820")
		line_edit_style.corner_radius_top_left = 8
		line_edit_style.corner_radius_bottom_left = 8
		line_edit_style.content_margin_left = 15
		line_edit_style.content_margin_right = 15
		input_code.add_theme_stylebox_override("normal", line_edit_style)
		input_code.add_theme_stylebox_override("read_only", line_edit_style)
		
	# Estilo do Botão Copiar (Azul)
	var copy_style = StyleBoxFlat.new()
	copy_style.bg_color = Color("#3d73ff")
	copy_style.corner_radius_top_right = 8
	copy_style.corner_radius_bottom_right = 8
	copy_style.content_margin_left = 20
	copy_style.content_margin_right = 20
	if btn_copy:
		btn_copy.add_theme_stylebox_override("normal", copy_style)
		btn_copy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Estilo Cancelar (Vermelho escuro)
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color("#991b1b")
	cancel_style.corner_radius_top_left = 8
	cancel_style.corner_radius_top_right = 8
	cancel_style.corner_radius_bottom_left = 8
	cancel_style.corner_radius_bottom_right = 8
	cancel_style.content_margin_top = 12
	cancel_style.content_margin_bottom = 12
	if btn_cancel:
		btn_cancel.add_theme_stylebox_override("normal", cancel_style)
		btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Estilo Mock (Verde, só pra teste)
	var mock_style = cancel_style.duplicate()
	mock_style.bg_color = Color("#10b981")
	if btn_mock_join:
		btn_mock_join.add_theme_stylebox_override("normal", mock_style)
		btn_mock_join.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
