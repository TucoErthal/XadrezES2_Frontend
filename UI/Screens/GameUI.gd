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

var btn_draw: Button
var _overlay: PanelContainer
var _overlay_label: Label
var _overlay_actions: HBoxContainer
var _toast_label: Label
var _toast_timer: float = 0.0
var _game_manager: GameManager

func _ready() -> void:
	_apply_theme()
	
	if btn_resign:
		btn_resign.pressed.connect(_on_resign_pressed)

	_build_extra_ui()

	# Conecta para receber snapshots do WebSocket
	WsClient.game_state_updated.connect(_on_game_state_updated)
	WsClient.game_error_received.connect(_on_ws_error)
	WsClient.connection_changed.connect(_on_connection_changed)
	
	var snap = RestClient.current_game_snapshot
	_sync_with_snapshot(snap)
	
	var game_id = snap.get("gameId", "")
	if not game_id.is_empty():
		WsClient.connect_and_subscribe(game_id)
	
	Router.load_level("res://Levels/Level.tscn")

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_label != null:
			_toast_label.visible = false

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
	_sync_draw_offer(snap)

	if status == "FINISHED" or status == "ABANDONED":
		_show_game_over(snap)
	elif is_game_active and btn_resign:
		btn_resign.disabled = false

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
	_confirm("Desistir da partida?", func():
		if WsClient.send_resign():
			btn_resign.disabled = true
		else:
			_toast("Sem conexão com o servidor.")
	)

func _on_draw_pressed() -> void:
	_confirm("Propor empate ao adversário?", func():
		if WsClient.send_draw_offer():
			btn_draw.disabled = true
		else:
			_toast("Sem conexão com o servidor.")
	)

func _show_game_over(snap: Dictionary) -> void:
	is_game_active = false
	if btn_resign: btn_resign.disabled = true
	if btn_draw: btn_draw.disabled = true

	var result = snap.get("result")
	if typeof(result) != TYPE_DICTIONARY:
		result = {}
	var texto := _translate_outcome(result.get("outcome", ""), result.get("reason", ""))
	if snap.get("status") == "ABANDONED" and texto.strip_edges().is_empty():
		texto = "Partida abandonada"

	lbl_turn.text = "FIM DE JOGO"
	lbl_turn.add_theme_color_override("font_color", Color("#ffd700"))

	_show_overlay("Fim de jogo\n" + texto, [
		{"text": "Voltar ao menu", "action": func():
			_hide_overlay()
			WsClient.disconnect_from_game()
			Router.navigate_to("Lobby")},
	])

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

# ==========================================================================
# UI construída em código (empate, promoção, avisos e fim de jogo)
# ==========================================================================

func _build_extra_ui() -> void:
	# Botão de empate, ao lado do de desistir.
	var actions := get_node_or_null("HUD/BottomActions")
	if actions != null:
		btn_draw = Button.new()
		btn_draw.text = "Propor empate"
		btn_draw.pressed.connect(_on_draw_pressed)
		actions.add_child(btn_draw)
		actions.move_child(btn_draw, 0)

	# Sobreposição central: promoção, oferta de empate e fim de jogo.
	_overlay = PanelContainer.new()
	_overlay.visible = false
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	_overlay.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_overlay.add_child(vbox)

	_overlay_label = Label.new()
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_overlay_label)

	_overlay_actions = HBoxContainer.new()
	_overlay_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_actions.add_theme_constant_override("separation", 12)
	vbox.add_child(_overlay_actions)

	add_child(_overlay)

	# Aviso temporário (erros do servidor).
	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_color", Color("#fca5a5"))
	add_child(_toast_label)

	# O GameManager pede a escolha da promoção.
	call_deferred("_bind_game_manager")

func _bind_game_manager() -> void:
	for node in get_tree().get_nodes_in_group("game_manager"):
		_game_manager = node
	if _game_manager == null:
		var level := get_tree().get_first_node_in_group("level")
		if level != null:
			_game_manager = level.get_node_or_null("GameManager")
	if _game_manager == null:
		return
	if not _game_manager.promotion_requested.is_connected(_on_promotion_requested):
		_game_manager.promotion_requested.connect(_on_promotion_requested)
	if not _game_manager.move_rejected.is_connected(_on_move_rejected):
		_game_manager.move_rejected.connect(_on_move_rejected)

func _show_overlay(text: String, buttons: Array) -> void:
	for child in _overlay_actions.get_children():
		child.queue_free()
	_overlay_label.text = text
	for b in buttons:
		var btn := Button.new()
		btn.text = b["text"]
		btn.pressed.connect(b["action"])
		_overlay_actions.add_child(btn)
	_overlay.visible = true

func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.visible = false

func _confirm(question: String, on_yes: Callable) -> void:
	_show_overlay(question, [
		{"text": "Confirmar", "action": func():
			_hide_overlay()
			on_yes.call()},
		{"text": "Cancelar", "action": _hide_overlay},
	])

## Promoção: o jogador escolhe a peça antes do lance ser enviado.
func _on_promotion_requested(_from: Vector2i, _to: Vector2i) -> void:
	var escolhas := [
		{"text": "Dama", "piece": "q"},
		{"text": "Torre", "piece": "r"},
		{"text": "Bispo", "piece": "b"},
		{"text": "Cavalo", "piece": "n"},
	]
	var buttons := []
	for e in escolhas:
		var piece: String = e["piece"]
		buttons.append({"text": e["text"], "action": func():
			_hide_overlay()
			if _game_manager != null:
				_game_manager.confirm_promotion(piece)})
	buttons.append({"text": "Cancelar", "action": func():
		_hide_overlay()
		if _game_manager != null:
			_game_manager.cancel_promotion()})
	_show_overlay("Promover o peão para:", buttons)

## Oferta de empate vinda do snapshot.
func _sync_draw_offer(snap: Dictionary) -> void:
	var offer = snap.get("drawOffer")
	if typeof(offer) != TYPE_DICTIONARY:
		if btn_draw != null and is_game_active:
			btn_draw.disabled = false
		return

	var offered_by: String = offer.get("offeredBy", "")
	if offered_by == my_side:
		if btn_draw != null:
			btn_draw.disabled = true
		return

	_show_overlay("O adversário propôs empate.", [
		{"text": "Aceitar", "action": func():
			_hide_overlay()
			WsClient.send_draw_respond(true)},
		{"text": "Recusar", "action": func():
			_hide_overlay()
			WsClient.send_draw_respond(false)},
	])

func _on_ws_error(code: String, message: String) -> void:
	_toast(_translate_error(code, message))

func _on_move_rejected(code: String, message: String) -> void:
	_toast(_translate_error(code, message))

func _on_connection_changed(connected: bool) -> void:
	if not connected:
		_toast("Conexão perdida. Tentando reconectar...")

func _translate_error(code: String, message: String) -> String:
	match code:
		"ILLEGAL_MOVE":
			return "Lance ilegal."
		"STALE_REVISION":
			return "A partida mudou; tente de novo."
		"NOT_A_PARTICIPANT":
			return "Você não participa desta partida."
		"INVALID_GAME_STATE":
			return "A partida não aceita esse comando agora."
		"GAME_NOT_FOUND":
			return "Partida não encontrada."
		"SESSION_INVALID", "SESSION_EXPIRED":
			return "Sessão expirada. Entre novamente."
		"UNSUPPORTED_MESSAGE":
			return "O servidor ainda não aceita esse comando."
		"OFFLINE":
			return "Sem conexão com o servidor."
	return message if not message.is_empty() else code

func _toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.visible = true
	_toast_timer = 3.5

func _translate_outcome(outcome: String, reason: String) -> String:
	var quem := ""
	match outcome:
		"WHITE_WIN":
			quem = "Brancas vencem"
		"BLACK_WIN":
			quem = "Pretas vencem"
		"DRAW":
			quem = "Empate"
		_:
			quem = outcome
	var motivo := ""
	match reason:
		"CHECKMATE": motivo = "xeque-mate"
		"STALEMATE": motivo = "afogamento"
		"INSUFFICIENT_MATERIAL": motivo = "material insuficiente"
		"DRAW_AGREED": motivo = "empate acordado"
		"RESIGNATION": motivo = "desistência"
		"TIMEOUT": motivo = "tempo esgotado"
		_: motivo = reason.to_lower()
	return quem + (" (" + motivo + ")" if not motivo.is_empty() else "")
