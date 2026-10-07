extends Control
class_name LoginScreen

@export var username_input: LineEdit
@export var login_button: Button
@export var error_label: Label

func _ready() -> void:
	# Conecta os sinais do botão e da API
	login_button.pressed.connect(_on_login_pressed)
	RestClient.on_login_completed.connect(_on_api_login_completed)
	
	if error_label:
		error_label.text = ""

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
