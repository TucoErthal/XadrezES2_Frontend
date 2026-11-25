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
	
	var snap = RestClient.current_game_snapshot
	var game_id = snap.get("gameId", "")
	var code = snap.get("entryCode", "")
	
	if snap.get("visibility") == "PUBLIC":
		if input_code:
			var container = input_code.get_parent().get_parent()
			if container:
				container.visible = false
	else:
		_set_room_code(code if code != null else "ERRO")
		
	WsClient.game_became_active.connect(_on_game_started, CONNECT_ONE_SHOT)
	WsClient.connect_and_subscribe(game_id)

func _on_game_started() -> void:
	print("Oponente entrou! A partida é ACTIVE.")
	Router.navigate_to("GameUI")

func _set_room_code(code: String) -> void:
	if input_code: input_code.text = code

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(input_code.text)
	btn_copy.text = "Copiado!"
	await get_tree().create_timer(2.0).timeout
	if btn_copy: btn_copy.text = "Copiar"

func _on_cancel_pressed() -> void:
	Router.navigate_to("Lobby")

func _on_mock_join_pressed() -> void:
	Router.navigate_to("GameUI")

func _apply_modern_theme() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if background:
		background.visible = false

	UITheme.apply_chess_background(self)
	UITheme.apply_font(self)

	if card_panel:
		card_panel.custom_minimum_size = Vector2(420, 0)
		UITheme.style_card(card_panel)

	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_title(title_label, true)
		title_label.add_theme_font_size_override("font_size", 26)

	if input_code:
		input_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_input(input_code)
		var code_row := input_code.get_parent()
		if code_row is HBoxContainer:
			(code_row as HBoxContainer).add_theme_constant_override("separation", 10)

	if btn_copy:
		btn_copy.text = "Copiar"
		UITheme.style_button(btn_copy, "primary")

	if btn_cancel:
		btn_cancel.text = "Cancelar"
		UITheme.style_button(btn_cancel, "danger")

	if btn_mock_join:
		UITheme.style_button(btn_mock_join, "secondary")
