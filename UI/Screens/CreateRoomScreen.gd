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
		background.visible = false

	UITheme.apply_chess_background(self)
	UITheme.apply_font(self)

	if card_panel:
		UITheme.style_card(card_panel)

	if title_label:
		UITheme.style_title(title_label, true)
		title_label.add_theme_font_size_override("font_size", 28)

	if btn_confirm:
		UITheme.style_button(btn_confirm, "primary")

	if btn_cancel:
		UITheme.style_button(btn_cancel, "secondary")

	if opt_difficulty:
		UITheme.style_option_button(opt_difficulty)

	if check_private:
		UITheme.style_checkbox(check_private)
