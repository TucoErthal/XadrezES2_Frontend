extends Control
class_name GameUI

@onready var lbl_turn: Label = $HUD/TopBar/TurnIndicator
@onready var lbl_player_timer: Label = $HUD/TopBar/PlayerPanel/Margin/VBox/Timer
@onready var lbl_opponent_timer: Label = $HUD/TopBar/OpponentPanel/Margin/VBox/Timer
@onready var btn_resign: Button = $HUD/BottomActions/BtnResign

var my_side: String = ""
var active_side: String = ""
var player_time_ms: float = 0.0
var opponent_time_ms: float = 0.0
var is_game_active: bool = false

func _ready() -> void:
	_apply_theme()
	
	if btn_resign:
		btn_resign.pressed.connect(_on_resign_pressed)
		
	# Conecta para receber snapshots do WebSocket
	WsClient.game_state_updated.connect(_on_game_state_updated)
	
	# Assim que a tela carrega, tentamos puxar o estado atual do RestClient
	_sync_with_snapshot(RestClient.current_game_snapshot)
	
	# Renderiza o tabuleiro 3D em background se ainda não estiver instanciado
	Router.load_level("res://Levels/Level.tscn")

func _process(delta: float) -> void:
	if not is_game_active or active_side.is_empty():
		return
		
	# Decrementa localmente o relógio de quem está na vez
	var delta_ms = delta * 1000.0
	if active_side == my_side:
		player_time_ms = maxf(0.0, player_time_ms - delta_ms)
	else:
		opponent_time_ms = maxf(0.0, opponent_time_ms - delta_ms)
		
	_update_clock_labels()

func _on_game_state_updated(snapshot: Dictionary) -> void:
	_sync_with_snapshot(snapshot)

func _sync_with_snapshot(snap: Dictionary) -> void:
	if snap.is_empty(): return
	
	var status = snap.get("status", "")
	is_game_active = (status == "ACTIVE")
	
	# 1. Garante que 'clock' seja tratado como dicionário, mesmo se vier nulo do servidor
	var clock = snap.get("clock")
	if typeof(clock) != TYPE_DICTIONARY:
		clock = {}
	
	# 2. Faz uma extração segura (null-safe) para não quebrar a tipagem estrita do GDScript
	var raw_active = clock.get("activeSide")
	active_side = raw_active if raw_active != null else ""
	
	var w_time = clock.get("whiteRemainingMs")
	var b_time = clock.get("blackRemainingMs")
	var white_ms = float(w_time if w_time != null else 0)
	var black_ms = float(b_time if b_time != null else 0)
	
	if my_side.is_empty(): 
		my_side = RestClient.my_side
		
	if my_side == "WHITE":
		player_time_ms = white_ms
		opponent_time_ms = black_ms
	else:
		player_time_ms = black_ms
		opponent_time_ms = white_ms
		
	var has_time_limit = (white_ms > 0 or black_ms > 0)
	lbl_player_timer.visible = has_time_limit
	lbl_opponent_timer.visible = has_time_limit
		
	_update_turn_label()
	_update_clock_labels()
	
	if status == "FINISHED" or status == "ABANDONED":
		_show_game_over(snap)

func _update_turn_label() -> void:
	if active_side.is_empty():
		lbl_turn.text = "Aguardando..."
		lbl_turn.add_theme_color_override("font_color", Color("#aaaaaa"))
		return
		
	if active_side == my_side:
		lbl_turn.text = "SUA VEZ"
		lbl_turn.add_theme_color_override("font_color", Color("#10b981")) # Verde
	else:
		lbl_turn.text = "Vez do Adversário"
		lbl_turn.add_theme_color_override("font_color", Color("#ef4444")) # Vermelho

func _update_clock_labels() -> void:
	lbl_player_timer.text = _format_ms_to_clock(player_time_ms)
	lbl_opponent_timer.text = _format_ms_to_clock(opponent_time_ms)

func _format_ms_to_clock(ms: int) -> String:
	var total_seconds = ms / 1000
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _on_resign_pressed() -> void:
	print("Enviando pedido de desistência...")
	# Exemplo futuro: WsClient.send_resign()
	btn_resign.disabled = true

func _show_game_over(snap: Dictionary) -> void:
	is_game_active = false
	var result = snap.get("result", {})
	var outcome = result.get("outcome", "Desconhecido")
	var reason = result.get("reason", "")
	
	lbl_turn.text = "FIM DE JOGO\n" + outcome + " (" + reason + ")"
	lbl_turn.add_theme_color_override("font_color", Color("#ffd700")) # Dourado

func _apply_theme() -> void:
	# Estilização limpa para os painéis não bloquearem a visão
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.8) # Fundo escuro semi-transparente
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	
	$HUD/TopBar/PlayerPanel.add_theme_stylebox_override("panel", panel_style)
	$HUD/TopBar/OpponentPanel.add_theme_stylebox_override("panel", panel_style)
	
	var btn_style = panel_style.duplicate()
	btn_style.bg_color = Color(0.7, 0.2, 0.2, 0.9)
	btn_resign.add_theme_stylebox_override("normal", btn_style)
