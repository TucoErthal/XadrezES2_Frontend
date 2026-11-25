extends Control
class_name HomeScreen

# Referências exportadas (arraste os nós correspondentes no Inspector)
@export var background: ColorRect
@export var title_label: Label
@export var btn_pvp: Button
@export var btn_pve: Button
@export var btn_eve: Button

func _ready() -> void:
	_apply_modern_theme()
	
	if btn_pvp: btn_pvp.pressed.connect(_on_pvp_pressed)
	if btn_pve: btn_pve.pressed.connect(_on_pve_pressed)
	if btn_eve: btn_eve.pressed.connect(_on_eve_pressed)
	
	RestClient.login_guest("tester")
	
	# No Godot 4, o await retorna um Array com os parâmetros do signal
	var login_result = await RestClient.on_login_completed
	var success = login_result[0]
	var data = login_result[1]
	
	if success:
		print("[OK] Login realizado! Token: ", RestClient.session_token)
	else:
		print("[ERRO] Falha no login: ", data)

func _apply_modern_theme() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if background:
		background.visible = false

	UITheme.apply_chess_background(self)
	UITheme.apply_font(self)

	if title_label:
		UITheme.style_title(title_label, true)
		title_label.add_theme_font_size_override("font_size", 56)
		var vbox := title_label.get_parent()
		if vbox is VBoxContainer:
			(vbox as VBoxContainer).add_theme_constant_override("separation", 18)

	if btn_pvp:
		UITheme.style_button(btn_pvp, "gold")
		btn_pvp.add_theme_font_size_override("font_size", 20)
		btn_pvp.custom_minimum_size = Vector2(320, 54)

	if btn_pve:
		UITheme.style_button(btn_pve, "primary")
		btn_pve.add_theme_font_size_override("font_size", 20)
		btn_pve.custom_minimum_size = Vector2(320, 54)

	if btn_eve:
		UITheme.style_button(btn_eve, "secondary")
		btn_eve.add_theme_font_size_override("font_size", 20)
		btn_eve.custom_minimum_size = Vector2(320, 54)

# --- Funções de Navegação ---

func _on_pvp_pressed() -> void:
	Router.navigate_to("Lobby")

func _on_pve_pressed() -> void:
	print("Iniciando modo JxIA...")
	# Adicione a navegação futura aqui
	
func _on_eve_pressed() -> void:
	print("Iniciando modo IAxIA...")
	# Adicione a navegação futura aqui
