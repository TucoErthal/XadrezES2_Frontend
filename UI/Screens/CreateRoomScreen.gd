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

func _populate_options() -> void:
	if opt_difficulty:
		opt_difficulty.add_item("Fácil")
		opt_difficulty.add_item("Médio")
		opt_difficulty.add_item("Difícil")

func _on_cancel_pressed() -> void:
	# Volta para o Lobby
	Router.navigate_to("Lobby")

func _on_confirm_pressed() -> void:
	# Coleta os dados configurados
	var diff_selected = opt_difficulty.get_item_text(opt_difficulty.selected)
	var is_private = check_private.button_pressed
	
	print("Solicitando criação de sala:")
	print("- Dificuldade: ", diff_selected)
	print("- Privada: ", is_private)
	
	# Aqui você chama a API:
	# var response = await RestClient.create_room(diff_selected, is_private)
	# if response.success:
	#     Se for privada, você pode mostrar um popup com o código gerado, 
	#     ou já pular para a GameUI com um painel de "Aguardando Oponente".
	# Router.navigate_to("GameUI")

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
