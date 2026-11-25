extends RefCounted
class_name UITheme

const FONT_PATH := "res://UI/Fonts/Fonte.ttf"

const CHESS_BG_SHADER := """
shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec2 grid = floor((uv * vec2(12.0, 7.0)) + vec2(TIME * 0.04, TIME * 0.02));
	float checker = mod(grid.x + grid.y, 2.0);

	vec3 col_dark = vec3(0.045, 0.058, 0.095);
	vec3 col_light = vec3(0.068, 0.086, 0.135);
	vec3 base = mix(col_dark, col_light, checker);

	float dist = distance(uv, vec2(0.5, 0.45));
	float glow = smoothstep(0.85, 0.0, dist);
	vec3 gold_tint = vec3(0.85, 0.70, 0.37) * glow * 0.08;

	float vignette = smoothstep(1.15, 0.25, dist);
	COLOR = vec4((base + gold_tint) * (0.65 + 0.35 * vignette), 1.0);
}
"""

static var _cached_shader: Shader = null
static var _cached_font: Font = null
static var _font_checked: bool = false


static func _get_font() -> Font:
	if not _font_checked:
		_font_checked = true
		if ResourceLoader.exists(FONT_PATH):
			var loaded: Resource = ResourceLoader.load(FONT_PATH)
			if loaded is Font:
				_cached_font = loaded
	return _cached_font


static func apply_font(root: Node) -> void:
	var font: Font = _get_font()
	if font == null or root == null:
		return
	_apply_font_recursive(root, font)


static func _apply_font_recursive(node: Node, font: Font) -> void:
	if node is Control:
		(node as Control).add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)


static func apply_chess_background(root: Control) -> void:
	if root == null:
		return

	# Esconde ColorRects opacos de tela cheia que tampariam o shader
	for child in root.get_children():
		if child is ColorRect and child.name != "ChessShaderBG":
			var rect: ColorRect = child as ColorRect
			if rect.anchor_right >= 1.0 and rect.anchor_bottom >= 1.0 and rect.color.a >= 0.99:
				rect.visible = false

	var existing: Node = root.get_node_or_null("ChessShaderBG")
	if existing != null:
		root.move_child(existing, 0)
		return

	if _cached_shader == null:
		_cached_shader = Shader.new()
		_cached_shader.code = CHESS_BG_SHADER

	var mat := ShaderMaterial.new()
	mat.shader = _cached_shader

	var bg := ColorRect.new()
	bg.name = "ChessShaderBG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = mat

	root.add_child(bg)
	root.move_child(bg, 0)


static func _make_box(
	bg_color: Color,
	border_color: Color,
	border_width: int = 1,
	radius: int = 10,
	pad_x: int = 20,
	pad_y: int = 12
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = border_color
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


static func style_card(panel: PanelContainer, pad_x: int = 24, pad_y: int = 20) -> void:
	if panel == null:
		return

	var has_margin := false
	for child in panel.get_children():
		if child is MarginContainer:
			has_margin = true
			break

	var final_x: int = 0 if has_margin else pad_x
	var final_y: int = 0 if has_margin else pad_y

	var box := _make_box(
		Color("#131824EE"),
		Color("#D9B25F44"),
		1,
		14,
		final_x,
		final_y
	)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", box)


static func style_title(label: Label, gold: bool = false) -> void:
	if label == null:
		return
	# LabelSettings sobrescreve theme overrides no Godot 4
	label.label_settings = null
	var color := Color("#E8C97A") if gold else Color("#F3F5F9")
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func style_input(input: LineEdit) -> void:
	if input == null:
		return
	var normal := _make_box(Color("#0D111AE6"), Color("#D9B25F44"), 1, 8, 14, 10)
	var focus := _make_box(Color("#121826FF"), Color("#E8C97ACC"), 2, 8, 14, 10)
	var read_only := _make_box(Color("#0D111ACC"), Color("#D9B25F33"), 1, 8, 14, 10)

	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", focus)
	input.add_theme_stylebox_override("read_only", read_only)
	input.add_theme_color_override("font_color", Color("#F3F5F9"))
	input.add_theme_color_override("font_uneditable_color", Color("#E8C97A"))
	input.add_theme_color_override("font_placeholder_color", Color("#7C879E"))
	input.add_theme_font_size_override("font_size", 16)


static func style_option_button(opt: OptionButton) -> void:
	if opt == null:
		return
	var normal := _make_box(Color("#1A2233"), Color("#D9B25F55"), 1, 8, 14, 10)
	var hover := _make_box(Color("#232E45"), Color("#E8C97AAA"), 1, 8, 14, 10)
	opt.add_theme_stylebox_override("normal", normal)
	opt.add_theme_stylebox_override("hover", hover)
	opt.add_theme_stylebox_override("pressed", hover)
	opt.add_theme_stylebox_override("focus", hover)
	opt.add_theme_color_override("font_color", Color("#F3F5F9"))
	opt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func style_checkbox(cb: CheckBox) -> void:
	if cb == null:
		return
	cb.add_theme_color_override("font_color", Color("#E2E8F0"))
	cb.add_theme_color_override("font_hover_color", Color("#E8C97A"))
	cb.add_theme_color_override("font_pressed_color", Color("#E8C97A"))
	cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func style_button(btn: Button, variant: String = "primary") -> void:
	if btn == null:
		return

	var bg_normal: Color
	var bg_hover: Color
	var bg_pressed: Color
	var border_col: Color
	var text_col := Color("#F8FAFC")

	match variant:
		"gold":
			bg_normal = Color("#C9A24B")
			bg_hover = Color("#DEB963")
			bg_pressed = Color("#A88437")
			border_col = Color("#F5DF9D")
			text_col = Color("#0D111A")
		"primary":
			bg_normal = Color("#2C5BD4")
			bg_hover = Color("#3B6FF0")
			bg_pressed = Color("#2249AD")
			border_col = Color("#6C95FF88")
		"success":
			bg_normal = Color("#0E9F6E")
			bg_hover = Color("#14B881")
			bg_pressed = Color("#0B7F58")
			border_col = Color("#6EE7B766")
		"danger":
			bg_normal = Color("#B91C1C")
			bg_hover = Color("#DC2626")
			bg_pressed = Color("#991B1B")
			border_col = Color("#FCA5A566")
		"ghost":
			bg_normal = Color("#13182488")
			bg_hover = Color("#1E293BCC")
			bg_pressed = Color("#0F172ACC")
			border_col = Color("#D9B25F44")
		_: # "secondary"
			bg_normal = Color("#1E2638")
			bg_hover = Color("#29344D")
			bg_pressed = Color("#161C2B")
			border_col = Color("#D9B25F55")

	var normal := _make_box(bg_normal, border_col, 1, 10, 22, 12)
	var hover := _make_box(bg_hover, border_col.lightened(0.2), 1, 10, 22, 12)
	var pressed := _make_box(bg_pressed, border_col, 1, 10, 22, 12)
	var disabled := _make_box(Color("#1A202C88"), Color("#47556944"), 1, 10, 22, 12)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color("#64748B"))

	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if not btn.has_meta("ui_theme_hover"):
		btn.set_meta("ui_theme_hover", true)
		btn.mouse_entered.connect(func() -> void:
			if btn.disabled or not btn.is_inside_tree():
				return
			if btn.has_meta("ui_tween"):
				var old_tw: Variant = btn.get_meta("ui_tween")
				if old_tw is Tween and (old_tw as Tween).is_valid():
					(old_tw as Tween).kill()
			btn.pivot_offset = btn.size * 0.5
			var tw: Tween = btn.create_tween()
			btn.set_meta("ui_tween", tw)
			tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)
		btn.mouse_exited.connect(func() -> void:
			if not btn.is_inside_tree():
				return
			if btn.has_meta("ui_tween"):
				var old_tw: Variant = btn.get_meta("ui_tween")
				if old_tw is Tween and (old_tw as Tween).is_valid():
					(old_tw as Tween).kill()
			btn.pivot_offset = btn.size * 0.5
			var tw: Tween = btn.create_tween()
			btn.set_meta("ui_tween", tw)
			tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		)
