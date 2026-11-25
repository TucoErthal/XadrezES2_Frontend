extends Control
class_name GameUI

@onready var lbl_turn: Label = $HUD/TopBar/TurnIndicator
@onready var lbl_player_timer: Label = $HUD/TopBar/PlayerPanel/Margin/VBox/Timer
@onready var lbl_opponent_timer: Label = $HUD/TopBar/OpponentPanel/Margin/VBox/Timer
@onready var btn_resign: Button = $HUD/BottomActions/BtnResign

# Popup de confirmação de abandono
@onready var resign_confirm_overlay: ColorRect = $HUD/ResignConfirmOverlay
@onready var resign_card_panel: PanelContainer = $HUD/ResignConfirmOverlay/Center/CardPanel
@onready var lbl_resign_message: Label = $HUD/ResignConfirmOverlay/Center/CardPanel/Margin/VBox/Message
@onready var btn_cancel_resign: Button = $HUD/ResignConfirmOverlay/Center/CardPanel/Margin/VBox/Buttons/BtnCancelResign
@onready var btn_confirm_resign: Button = $HUD/ResignConfirmOverlay/Center/CardPanel/Margin/VBox/Buttons/BtnConfirmResign

# Popup de fim de jogo (vitória / derrota / empate)
@onready var game_over_overlay: ColorRect = $HUD/GameOverOverlay
@onready var game_over_card_panel: PanelContainer = $HUD/GameOverOverlay/Center/CardPanel
@onready var lbl_game_over_title: Label = $HUD/GameOverOverlay/Center/CardPanel/Margin/VBox/Title
@onready var lbl_game_over_subtitle: Label = $HUD/GameOverOverlay/Center/CardPanel/Margin/VBox/Subtitle
@onready var lbl_game_over_reason: Label = $HUD/GameOverOverlay/Center/CardPanel/Margin/VBox/Reason
@onready var btn_exit_match: Button = $HUD/GameOverOverlay/Center/CardPanel/Margin/VBox/BtnExitMatch

@onready var player_panel: PanelContainer = $HUD/TopBar/PlayerPanel
@onready var opponent_panel: PanelContainer = $HUD/TopBar/OpponentPanel

const DEFAULT_RESIGN_MSG := "Se você abandonar agora, a partida será encerrada e contará como derrota."

const REASON_LABELS := {
	"CHECKMATE": "Xeque-mate",
	"RESIGNATION": "Por desistência",
	"TIMEOUT": "Tempo esgotado",
	"DRAW_AGREED": "Empate acordado",
	"STALEMATE": "Afogamento",
	"INSUFFICIENT_MATERIAL": "Material insuficiente",
	"THREEFOLD_REPETITION": "Repetição de posição",
	"FIFTY_MOVE_RULE": "Regra dos 50 lances",
	"ABANDONED": "Partida abandonada",
	"ABANDONMENT": "Partida abandonada",
}

var my_side: String = ""
var active_side: String = ""
var player_time_ms: float = 0.0
var opponent_time_ms: float = 0.0
var is_game_active: bool = false
var _waiting_resign_response: bool = false

func _ready() -> void:
	_apply_theme()

	if btn_resign:
		btn_resign.pressed.connect(_on_resign_pressed)
	if btn_cancel_resign:
		btn_cancel_resign.pressed.connect(_on_cancel_resign_pressed)
	if btn_confirm_resign:
		btn_confirm_resign.pressed.connect(_on_confirm_resign_pressed)
	if btn_exit_match:
		btn_exit_match.pressed.connect(_on_exit_match_pressed)

	# Conecta para receber snapshots e erros do WebSocket
	WsClient.game_state_updated.connect(_on_game_state_updated)
	WsClient.game_error_received.connect(_on_game_error_received)

	var snap = RestClient.current_game_snapshot
	_sync_with_snapshot(snap)

	var game_id = snap.get("gameId", "")
	if not game_id.is_empty():
		WsClient.connect_and_subscribe(game_id)

	Router.load_level("res://Levels/Level.tscn")

func _exit_tree() -> void:
	if WsClient.game_state_updated.is_connected(_on_game_state_updated):
		WsClient.game_state_updated.disconnect(_on_game_state_updated)
	if WsClient.game_error_received.is_connected(_on_game_error_received):
		WsClient.game_error_received.disconnect(_on_game_error_received)

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

func _on_game_error_received(code: String, message: String) -> void:
	if not _waiting_resign_response:
		return

	_waiting_resign_response = false
	btn_confirm_resign.disabled = false
	btn_cancel_resign.disabled = false
	btn_resign.disabled = false
	lbl_resign_message.text = "Não foi possível abandonar (%s): %s" % [code, message]

func _sync_with_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return

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
	lbl_player_timer.text = _format_ms_to_clock(int(player_time_ms))
	lbl_opponent_timer.text = _format_ms_to_clock(int(opponent_time_ms))

func _format_ms_to_clock(ms: int) -> String:
	var total_seconds = ms / 1000
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

# ==========================================================================
# Abandonar / Desistir da partida
# ==========================================================================

func _on_resign_pressed() -> void:
	if not is_game_active:
		return
	lbl_resign_message.text = DEFAULT_RESIGN_MSG
	btn_confirm_resign.disabled = false
	btn_cancel_resign.disabled = false
	resign_confirm_overlay.visible = true

func _on_cancel_resign_pressed() -> void:
	resign_confirm_overlay.visible = false

func _on_confirm_resign_pressed() -> void:
	_waiting_resign_response = true
	btn_confirm_resign.disabled = true
	btn_cancel_resign.disabled = true
	btn_resign.disabled = true

	var sent := WsClient.send_resign()
	if not sent:
		_waiting_resign_response = false
		btn_confirm_resign.disabled = false
		btn_cancel_resign.disabled = false
		btn_resign.disabled = false
		lbl_resign_message.text = "Sem conexão com o servidor. Tente novamente em instantes."

# ==========================================================================
# Fim de jogo e saída da partida
# ==========================================================================

func _show_game_over(snap: Dictionary) -> void:
	is_game_active = false
	_waiting_resign_response = false
	resign_confirm_overlay.visible = false
	btn_resign.disabled = true
	btn_resign.visible = false

	var result = snap.get("result")
	if typeof(result) != TYPE_DICTIONARY:
		result = {}

	var raw_outcome = result.get("outcome")
	var outcome: String = str(raw_outcome).to_upper() if raw_outcome != null else ""

	var raw_reason = result.get("reason")
	var reason: String = str(raw_reason).to_upper() if raw_reason != null else ""

	var raw_winner = result.get("winnerSide", result.get("winner"))
	var winner_side: String = _extract_winner_side(outcome, raw_winner)

	# Define título, subtítulo e cor do popup
	if winner_side == "DRAW":
		lbl_game_over_title.text = "EMPATE"
		lbl_game_over_title.add_theme_color_override("font_color", Color("#94a3b8"))
		lbl_game_over_subtitle.text = "A partida terminou empatada."
	elif winner_side == "WHITE" or winner_side == "BLACK":
		var winner_pt := "As Brancas" if winner_side == "WHITE" else "As Pretas"
		if my_side == winner_side:
			lbl_game_over_title.text = "VITÓRIA!"
			lbl_game_over_title.add_theme_color_override("font_color", Color("#ffd700"))
			lbl_game_over_subtitle.text = "Parabéns! Você venceu a partida."
		elif not my_side.is_empty():
			lbl_game_over_title.text = "DERROTA"
			lbl_game_over_title.add_theme_color_override("font_color", Color("#ef4444"))
			lbl_game_over_subtitle.text = "%s venceram a partida." % winner_pt
		else:
			lbl_game_over_title.text = "FIM DE JOGO"
			lbl_game_over_title.add_theme_color_override("font_color", Color("#ffd700"))
			lbl_game_over_subtitle.text = "%s venceram a partida." % winner_pt
	else:
		lbl_game_over_title.text = "FIM DE JOGO"
		lbl_game_over_title.add_theme_color_override("font_color", Color("#ffd700"))
		lbl_game_over_subtitle.text = outcome if not outcome.is_empty() else "A partida foi encerrada."

	# Motivo formatado
	var reason_text: String = REASON_LABELS.get(reason, "")
	if reason_text.is_empty():
		if not reason.is_empty():
			reason_text = reason.capitalize()
		elif snap.get("status", "") == "ABANDONED":
			reason_text = "Partida abandonada"

	lbl_game_over_reason.visible = not reason_text.is_empty()
	lbl_game_over_reason.text = reason_text

	lbl_turn.text = "FIM DE JOGO"
	lbl_turn.add_theme_color_override("font_color", Color("#ffd700"))

	game_over_overlay.visible = true

func _extract_winner_side(outcome: String, raw_winner: Variant) -> String:
	if raw_winner != null:
		var w := str(raw_winner).to_upper()
		if w == "WHITE" or w == "BLACK":
			return w

	if outcome in ["WHITE_WIN", "WHITE_WINS", "WHITE", "1-0"]:
		return "WHITE"
	if outcome in ["BLACK_WIN", "BLACK_WINS", "BLACK", "0-1"]:
		return "BLACK"
	if outcome in ["DRAW", "TIE", "1/2-1/2"]:
		return "DRAW"
	return ""

func _on_exit_match_pressed() -> void:
	btn_exit_match.disabled = true
	WsClient.disconnect_from_game()
	RestClient.current_game_snapshot = {}
	RestClient.my_side = ""
	Router.unload_level()
	Router.navigate_to("Lobby")

# ==========================================================================
# Tema visual
# ==========================================================================

func _apply_theme() -> void:
	UITheme.apply_font(self)

	if player_panel:
		UITheme.style_card(player_panel)
	if opponent_panel:
		UITheme.style_card(opponent_panel)
	if resign_card_panel:
		UITheme.style_card(resign_card_panel)
	if game_over_card_panel:
		UITheme.style_card(game_over_card_panel)

	if lbl_turn:
		UITheme.style_title(lbl_turn, false)

	if btn_resign:
		UITheme.style_button(btn_resign, "danger")
	if btn_cancel_resign:
		UITheme.style_button(btn_cancel_resign, "secondary")
	if btn_confirm_resign:
		UITheme.style_button(btn_confirm_resign, "danger")
	if btn_exit_match:
		UITheme.style_button(btn_exit_match, "gold")

func _make_button_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
