extends Control
class_name LoginScreen

@export var username_input: LineEdit
@export var login_button: Button
@export var error_label: Label

func _ready() -> void:
	# Conecta os sinais do botão e da API
	login_button.pressed.connect(_on_login_pressed)
	RestClient.on_login_completed.connect(_on_api_login_completed)
	_apply_modern_theme()
	if error_label:
		error_label.text = ""

func _apply_modern_theme() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	UITheme.apply_chess_background(self)
	UITheme.apply_font(self)

	for child in find_children("*", "PanelContainer", true, false):
		UITheme.style_card(child)

	for child in find_children("*", "Label", true, false):
		if child.name.to_lower().contains("title"):
			UITheme.style_title(child, true)
		else:
			UITheme.style_subtitle(child)

	if username_input:
		UITheme.style_input(username_input)

	if login_button:
		UITheme.style_button(login_button, "gold")

func _on_login_pressed() -> void:
	var username = username_input.text.strip_edges()
	if username.is_empty():
		return
		
	login_button.disabled = true
	if error_label: error_label.text = "Conectando..."
	
	# Chama o Autoload do REST
	RestClient.login_guest(username)

func _on_api_login_completed(success: bool, data: Dictionary) -> void:
	login_button.disabled = false
	
	if success:
		print("Login OK! Token salvo no RestClient.")
		# Navega para a tela do Lobby usando a chave correta do Router
		Router.navigate_to("Lobby") 
	else:
		if error_label: error_label.text = "Erro ao entrar."
		printerr("Falha no login: ", data)
