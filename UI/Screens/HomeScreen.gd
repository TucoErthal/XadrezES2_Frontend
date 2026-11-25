extends Control
class_name HomeScreen

# Referências exportadas (arraste os nós correspondentes no Inspector)
@export var background: ColorRect
@export var title_label: Label
@export var btn_pvp: Button
@export var btn_pve: Button
@export var btn_eve: Button

## Mesmo tempo da opcao "Rapida" na tela de criacao de sala.
const TEMPO_PADRAO_MS := 600000

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
	# 1. Cor de fundo escuro (Dark Mode)
	if background:
		background.color = Color("#181820")
	
	# 2. Estilo do Título (Grande, com sombra e cor de destaque)
	if title_label:
		title_label.add_theme_font_size_override("font_size", 64)
		title_label.add_theme_color_override("font_color", Color("#ffffff"))
		title_label.add_theme_color_override("font_shadow_color", Color("#000000"))
		title_label.add_theme_constant_override("shadow_offset_x", 4)
		title_label.add_theme_constant_override("shadow_offset_y", 4)

	# 3. Criar o visual dos botões
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#2a2a35") # Cinza escuro azulado
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.content_margin_top = 16
	normal_style.content_margin_bottom = 16
	normal_style.content_margin_left = 32
	normal_style.content_margin_right = 32
	
	# 4. Criar o visual de "Hover" (quando passa o mouse por cima)
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color("#3d73ff") # Azul vibrante de destaque
	
	# 5. Aplicar estilos aos botões
	var buttons = [btn_pvp, btn_pve, btn_eve]
	for btn in buttons:
		if btn:
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("pressed", normal_style)
			btn.add_theme_font_size_override("font_size", 24)
			# Muda o mouse para a "mãozinha" ao passar por cima
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# --- Funções de Navegação ---

func _on_pvp_pressed() -> void:
	Router.navigate_to("Lobby")

## Partidas com IA nascem ACTIVE: nao passam pela sala de espera.
## O GameUI assina o WebSocket sozinho, a partir do snapshot da criacao.
func _on_pve_pressed() -> void:
	_criar_partida_com_ia("HUMAN_VS_AI")

func _on_eve_pressed() -> void:
	_criar_partida_com_ia("AI_VS_AI")

func _criar_partida_com_ia(mode: String) -> void:
	_set_botoes_ia_ativos(false)
	RestClient.on_game_created.connect(_on_partida_com_ia_criada, CONNECT_ONE_SHOT)
	RestClient.create_game(false, TEMPO_PADRAO_MS, mode, "WHITE")

func _on_partida_com_ia_criada(success: bool, data: Dictionary) -> void:
	_set_botoes_ia_ativos(true)
	if success:
		Router.navigate_to("GameUI")
	else:
		printerr("Erro ao criar partida com IA: ", data)

func _set_botoes_ia_ativos(ativos: bool) -> void:
	if btn_pve: btn_pve.disabled = not ativos
	if btn_eve: btn_eve.disabled = not ativos
