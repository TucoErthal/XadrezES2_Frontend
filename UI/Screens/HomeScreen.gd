extends Control
class_name HomeScreen

@export var btn_pvp: Button
@export var btn_pve: Button
@export var btn_eve: Button

func _ready() -> void:
	# Conecta os botões da interface aos métodos correspondentes
	if btn_pvp: btn_pvp.pressed.connect(_on_pvp_pressed)
	if btn_pve: btn_pve.pressed.connect(_on_pve_pressed)
	if btn_eve: btn_eve.pressed.connect(_on_eve_pressed)

func _on_pvp_pressed() -> void:
	# Modo Jogador vs Jogador (Online)
	# Inicia o fluxo Guest mandando o usuário para a tela de Login
	Router.navigate_to("Login")

func _on_pve_pressed() -> void:
	# Modo Jogador vs IA
	print("Iniciando modo JxIA...")
	# Futuro: Router.load_level("res://Levels/Level.tscn") e configurar motor de IA
	
func _on_eve_pressed() -> void:
	# Modo IA vs IA
	print("Iniciando modo IAxIA...")
	# Futuro: Router.load_level("res://Levels/Level.tscn") e colocar duas IAs jogando
