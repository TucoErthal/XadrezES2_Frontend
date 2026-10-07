extends Control
class_name CreateRoomScreen

@export var background: ColorRect
@export var card_panel: PanelContainer
@export var title_label: Label
@export var opt_difficulty: OptionButton
@export var check_private: CheckBox
@export var btn_cancel: Button
@export var btn_confirm: Button

func _ready() -> void:
	_apply_modern_theme()
	_populate_options()
	
	if btn_cancel: btn_cancel.pressed.connect(_on_cancel_pressed)
	if btn_confirm: btn_confirm.pressed.connect(_on_confirm_pressed)

var tempos_ms = [0, 600000, 3600000] # 0=Sem limite, 10 min, 60 min (conforme API)

func _populate_options() -> void:
	if opt_difficulty:
		opt_difficulty.clear()
		opt_difficulty.add_item("Sem limite de tempo")
		opt_difficulty.add_item("Rápida (10 minutos)")
		opt_difficulty.add_item("Clássica (60 minutos)")

func _on_confirm_pressed() -> void:
	btn_confirm.disabled = true
	var time_ms = tempos_ms[opt_difficulty.selected]
	var is_private = check_private.button_pressed
	
	# Conecta temporariamente para ouvir a resposta
	RestClient.on_game_created.connect(_on_api_created, CONNECT_ONE_SHOT)
	print(is_private, time_ms)
	RestClient.create_game(is_private, time_ms)

func _on_api_created(success: bool, _data: Dictionary) -> void:
	btn_confirm.disabled = false
	if success:
		Router.navigate_to("WaitingRoom")
	else:
		print("Erro ao criar sala!", _data)

func _on_cancel_pressed() -> void:
	# Volta para o Lobby
	Router.navigate_to("Lobby")

func _apply_modern_theme() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	if background:
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.color = Color("#181820")
		
	# Fundo do "Card" central
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
	
	# Estilo Botão Confirmar (Azul)
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color("#3d73ff")
	confirm_style.corner_radius_top_left = 8
	confirm_style.corner_radius_top_right = 8
	confirm_style.corner_radius_bottom_left = 8
	confirm_style.corner_radius_bottom_right = 8
	confirm_style.content_margin_left = 30
	confirm_style.content_margin_right = 30
	confirm_style.content_margin_top = 12
	confirm_style.content_margin_bottom = 12
	
	# Estilo Botão Cancelar (Cinza Escuro)
	var cancel_style = confirm_style.duplicate()
	cancel_style.bg_color = Color("#3a3a4a")

	if btn_confirm:
		btn_confirm.add_theme_stylebox_override("normal", confirm_style)
		btn_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
	if btn_cancel:
		btn_cancel.add_theme_stylebox_override("normal", cancel_style)
		btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
