extends CanvasLayer
class_name Hud

const Catalog := preload("res://scripts/level_catalog.gd")
## Interface do jogo: HUD, menu inicial, pausa e tela de vitória.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal quit_pressed
signal levels_pressed
signal level_chosen(level_id: int)

const FONT_REG: FontFile = preload("res://assets/fonts/LiberationSans-Regular.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/LiberationSans-Bold.ttf")

const CREAM := Color("f6efe2")
const MUTED := Color("a9b2cc")
const TEAL := Color("5cf0cc")
const ORANGE := Color("ffa53d")
const RED := Color("ff6262")
const PANEL_BG := Color(0.045, 0.058, 0.10, 0.86)
const PANEL_BORDER := Color(0.32, 0.85, 0.76, 0.35)

var timer_label: Label
var deaths_label: Label
var fish_label: Label
var checkpoint_label: Label
var best_label: Label
var notify_label: Label
var hint_label: Label
var start_overlay: Control
var pause_overlay: Control
var win_overlay: Control
var level_overlay: Control
var win_time_label: Label
var win_deaths_label: Label
var win_fish_label: Label
var win_record_label: Label
var start_best_label: Label
var current_level_label: Label
var win_level_label: Label
var _flash: ColorRect
var _fade: ColorRect
var _notify_tween: Tween
var _root: Control
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _lang_buttons: Dictionary = {}
var _level_buttons: Dictionary = {}
var _level_best_labels: Dictionary = {}
var _level_best_values: Dictionary = {}
var _selected_level := 1
var _selected_level_name_key := "level_1_name"
var _time_value := 0.0
var _deaths_value := 0
var _fish_value := 0
var _fish_total := 0
var _checkpoint_value := 0
var _checkpoint_total := 0
var _best_value := 0.0
var _win_time_value := 0.0
var _win_deaths_value := 0
var _win_fish_value := 0
var _win_fish_total := 0
var _win_best_value := 0.0
var _win_new_record := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	Loc.locale_changed.connect(_on_locale_changed)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---------------------------------------------------------------- topo esquerdo
	var left_panel := _panel(Vector2(22, 22), Vector2(430, 122))
	_left_panel = left_panel
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 0)
	left_panel.add_child(left_box)
	timer_label = _label(left_box, "00:00.00", 42, CREAM, true, 8)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	left_box.add_child(stats)
	deaths_label = _label(stats, Loc.t("hud_deaths", [0]), 15, MUTED)
	fish_label = _label(stats, Loc.t("hud_fish", [0, 0]), 15, ORANGE)
	checkpoint_label = _label(stats, Loc.t("hud_checkpoint", [0, 5]), 15, TEAL)

	# ---------------------------------------------------------------- topo direito
	var right_panel := _panel(Vector2(-262, 22), Vector2(240, 92), Control.PRESET_TOP_RIGHT)
	_right_panel = right_panel
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right_box := VBoxContainer.new()
	right_box.alignment = BoxContainer.ALIGNMENT_END
	right_panel.add_child(right_box)
	var best_title := _label(right_box, Loc.t("hud_best_title"), 12, MUTED)
	Loc.bind_text(best_title, "hud_best_title")
	best_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label = _label(right_box, "--:--.--", 24, CREAM, true)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ---------------------------------------------------------------- notificação
	notify_label = _label(_root, "", 56, TEAL, true, 12)
	notify_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notify_label.offset_left = 0
	notify_label.offset_right = 0
	notify_label.offset_top = 150
	notify_label.offset_bottom = 230
	notify_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notify_label.modulate.a = 0.0

	hint_label = _label(_root, Loc.t("hud_hint"), 16, MUTED)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -520
	hint_label.offset_right = 520
	hint_label.offset_top = -54
	hint_label.offset_bottom = -22
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(hint_label, "hud_hint")

	# ---------------------------------------------------------------- efeitos
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.15, 0.12, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.025, 0.05, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	# ---------------------------------------------------------------- overlays
	_build_start_overlay()
	_build_pause_overlay()
	_build_win_overlay()
	_build_level_overlay()

	start_overlay.visible = false
	pause_overlay.visible = false
	win_overlay.visible = false
	level_overlay.visible = false


func _build_start_overlay() -> void:
	var overlay := _overlay()
	start_overlay = overlay
	var panel := _center_panel(overlay, Vector2(720, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var kicker := _label(box, Loc.t("menu_kicker"), 14, TEAL, true)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(kicker, "menu_kicker")
	var title := _label(box, "TUX OBBY 3D", 68, CREAM, true, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("b65416"))
	var subtitle := _label(box, Loc.t("menu_subtitle"), 20, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(subtitle, "menu_subtitle")
	_box_gap(box, 4)

	# Seletor de idioma: a escolha e imediata e fica salva entre partidas.
	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 8)
	box.add_child(lang_row)
	var lang_label := _label(lang_row, Loc.t("language"), 13, MUTED, true)
	lang_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Loc.bind_text(lang_label, "language")
	for entry in [["pt_BR", "PORTUGUÊS"], ["en", "ENGLISH"], ["es", "ESPAÑOL"]]:
		_lang_button(lang_row, entry[1], entry[0])
	_update_language_buttons()
	var lang_spacer := Control.new()
	lang_spacer.custom_minimum_size = Vector2(10, 0)
	lang_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lang_row.add_child(lang_spacer)
	var levels_button := _chip_button(lang_row, Loc.t("menu_levels"), func() -> void: show_levels())
	Loc.bind_text(levels_button, "menu_levels")

	_box_gap(box, 10)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	_control_row(grid, "key_wasd", "menu_controls_move")
	_control_row(grid, "key_mouse", "menu_controls_camera")
	_control_row(grid, "key_space", "menu_controls_jump")
	_control_row(grid, "key_shift", "menu_controls_sprint")
	_control_row(grid, "key_r", "menu_controls_checkpoint")
	_control_row(grid, "key_esc", "menu_controls_pause")

	_box_gap(box, 8)
	current_level_label = _label(box, "", 14, TEAL, true)
	current_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box_gap(box, 6)
	var play := _button(box, Loc.t("menu_play"), func() -> void: play_pressed.emit())
	Loc.bind_text(play, "menu_play")
	play.add_theme_font_size_override("font_size", 26)
	play.custom_minimum_size = Vector2(0, 56)
	start_best_label = _label(box, Loc.t("menu_best", ["--:--.--"]), 15, MUTED)
	start_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tip := _label(box, Loc.t("menu_tip"), 14, Color("7d89a8"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(tip, "menu_tip")
	var pulse := _label(box, Loc.t("menu_good_luck"), 16, ORANGE, true)
	pulse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(pulse, "menu_good_luck")
	var tween := create_tween().set_loops()
	tween.tween_property(pulse, "modulate:a", 0.25, 1.1)
	tween.tween_property(pulse, "modulate:a", 1.0, 1.1)


func _build_pause_overlay() -> void:
	var overlay := _overlay()
	pause_overlay = overlay
	var panel := _center_panel(overlay, Vector2(520, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := _label(box, Loc.t("pause_title"), 54, CREAM, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(title, "pause_title")
	var subtitle := _label(box, Loc.t("pause_subtitle"), 16, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(subtitle, "pause_subtitle")
	_box_gap(box, 10)
	var cont := _button(box, Loc.t("pause_resume"), func() -> void: resume_pressed.emit())
	Loc.bind_text(cont, "pause_resume")
	cont.add_theme_font_size_override("font_size", 22)
	var restart := _button(box, Loc.t("pause_restart"), func() -> void: restart_pressed.emit())
	Loc.bind_text(restart, "pause_restart")
	restart.add_theme_font_size_override("font_size", 22)
	var levels := _button(box, Loc.t("pause_levels"), func() -> void: levels_pressed.emit())
	Loc.bind_text(levels, "pause_levels")
	levels.add_theme_font_size_override("font_size", 20)
	var quit := _button(box, Loc.t("pause_quit"), func() -> void: quit_pressed.emit())
	Loc.bind_text(quit, "pause_quit")
	quit.add_theme_font_size_override("font_size", 22)
	var hint := _label(box, Loc.t("pause_hint"), 14, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(hint, "pause_hint")


func _build_win_overlay() -> void:
	var overlay := _overlay()
	win_overlay = overlay
	var panel := _center_panel(overlay, Vector2(640, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var kicker := _label(box, Loc.t("win_kicker"), 14, TEAL, true)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(kicker, "win_kicker")
	var title := _label(box, Loc.t("win_title"), 52, CREAM, true, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("b65416"))
	Loc.bind_text(title, "win_title")
	var subtitle := _label(box, Loc.t("win_subtitle"), 16, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(subtitle, "win_subtitle")
	win_level_label = _label(box, "", 14, TEAL, true)
	win_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box_gap(box, 14)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 30)
	stats.add_theme_constant_override("v_separation", 6)
	box.add_child(stats)
	_add_stat_row(stats, "win_time")
	_add_stat_row(stats, "win_deaths")
	_add_stat_row(stats, "win_fish")
	win_record_label = _label(box, "", 18, ORANGE, true)
	win_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_box_gap(box, 14)
	var again := _button(box, Loc.t("win_again"), func() -> void: restart_pressed.emit())
	Loc.bind_text(again, "win_again")
	again.add_theme_font_size_override("font_size", 24)
	var levels := _button(box, Loc.t("win_levels"), func() -> void: levels_pressed.emit())
	Loc.bind_text(levels, "win_levels")
	levels.add_theme_font_size_override("font_size", 20)
	var quit := _button(box, Loc.t("win_quit"), func() -> void: quit_pressed.emit())
	Loc.bind_text(quit, "win_quit")
	quit.add_theme_font_size_override("font_size", 20)
	var hint := _label(box, Loc.t("win_hint"), 14, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(hint, "win_hint")


func _build_level_overlay() -> void:
	var overlay := _overlay()
	level_overlay = overlay
	var panel := _center_panel(overlay, Vector2(880, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var kicker := _label(box, Loc.t("levels_kicker"), 13, TEAL, true)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(kicker, "levels_kicker")
	var title := _label(box, Loc.t("levels_title"), 46, CREAM, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(title, "levels_title")
	var subtitle := _label(box, Loc.t("levels_subtitle"), 15, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Loc.bind_text(subtitle, "levels_subtitle")
	_box_gap(box, 8)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for entry in Catalog.LEVELS:
		_level_card(grid, entry)

	_box_gap(box, 8)
	var back := _button(box, Loc.t("levels_back"), func() -> void: hide_levels())
	Loc.bind_text(back, "levels_back")
	back.add_theme_font_size_override("font_size", 18)
	back.custom_minimum_size = Vector2(0, 42)


func _level_card(parent: GridContainer, entry: Dictionary) -> void:
	var level_id := int(entry["id"])
	var accent: Color = entry["accent"]
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(370, 158)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = Loc.t("level_play_tooltip", [level_id])
	_style_level_card(button, accent)
	button.pressed.connect(func() -> void: _on_level_card_pressed(level_id))
	parent.add_child(button)
	_level_buttons[level_id] = button

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	button.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	var number := _label(top, "%02d" % level_id, 26, accent, true, 4)
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stars := _label(top, _difficulty_text(int(entry["difficulty"])), 14, accent, true, 2)
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var name_label := _label(box, Loc.t(str(entry["name"])), 21, CREAM, true, 3)
	Loc.bind_text(name_label, str(entry["name"]))
	var tagline := _label(box, Loc.t(str(entry["tagline"])), 13, MUTED)
	Loc.bind_text(tagline, str(entry["tagline"]))
	var stats := _label(box, "", 12, MUTED)
	Loc.bind_text(stats, "level_stats", [int(entry["checkpoints"]), int(entry["fish"])])
	_box_gap(box, 4)
	var best := _label(box, Loc.t("level_no_record"), 13, accent, true, 3)
	_level_best_labels[level_id] = best


func _difficulty_text(difficulty: int) -> String:
	var filled := clampi(difficulty, 0, 4)
	return "★".repeat(filled) + "☆".repeat(4 - filled)


func _on_level_card_pressed(level_id: int) -> void:
	level_overlay.visible = false
	level_chosen.emit(level_id)


func _chip_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_override("font", FONT_BOLD)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.16, 0.19, 0.95)
	normal.border_color = Color(0.55, 1.0, 0.9, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.24, 0.25, 1.0)
	hover.border_color = TEAL
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.06, 0.12, 0.14, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", TEAL)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _style_level_card(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.07, 0.115, 0.96)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(16)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.105, 0.165, 1.0)
	hover.border_color = accent
	hover.set_border_width_all(2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.045, 0.06, 0.10, 1.0)
	pressed.border_color = accent.lightened(0.25)
	pressed.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


func _add_stat_row(grid: GridContainer, key: String) -> void:
	var key_label := _label(grid, Loc.t(key), 16, MUTED)
	Loc.bind_text(key_label, key)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var value := _label(grid, "—", 22, CREAM, true)
	match key:
		"win_time": win_time_label = value
		"win_deaths": win_deaths_label = value
		"win_fish": win_fish_label = value


# ---------------------------------------------------------------- helpers de UI

func _label(parent: Node, text: String, size: int, color: Color, bold := false, outline := 4) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_BOLD if bold else FONT_REG)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _panel(pos: Vector2, size: Vector2, preset := Control.PRESET_TOP_LEFT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)
	if preset == Control.PRESET_TOP_LEFT:
		panel.position = pos
		panel.size = size
	else:
		panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		panel.position = pos
		panel.size = size
	return panel


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	return style


func _overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.055, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	_root.add_child(overlay)
	return overlay


func _center_panel(overlay: Control, min_size: Vector2) -> PanelContainer:
	var center := overlay.get_child(1) as CenterContainer
	var style := _panel_style()
	style.bg_color = Color(0.04, 0.052, 0.09, 0.94)
	style.border_color = Color(0.35, 0.9, 0.8, 0.5)
	style.set_corner_radius_all(24)
	style.content_margin_left = 52
	style.content_margin_right = 52
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = min_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	return panel


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_override("font", FONT_BOLD)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("062019"))
	button.add_theme_color_override("font_hover_color", Color("02120e"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("5cf0cc")
	normal.set_corner_radius_all(12)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("8affdd")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("38c6a7")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _control_row(grid: GridContainer, key_key: String, description_key: String) -> void:
	var key_label := _label(grid, Loc.t(key_key), 18, TEAL, true, 3)
	Loc.bind_text(key_label, key_key)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_label.custom_minimum_size = Vector2(110, 0)
	var desc := _label(grid, Loc.t(description_key), 17, CREAM)
	Loc.bind_text(desc, description_key)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _box_gap(box: VBoxContainer, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)


# ---------------------------------------------------------------- API pública

static func format_time(seconds: float) -> String:
	var clamped := maxf(0.0, seconds)
	var minutes := int(clamped / 60.0)
	var secs := int(clamped) % 60
	var cents := int((clamped - floor(clamped)) * 100.0)
	return "%02d:%02d.%02d" % [minutes, secs, cents]


func set_time(seconds: float) -> void:
	_time_value = seconds
	timer_label.text = format_time(seconds)


func set_deaths(value: int) -> void:
	_deaths_value = value
	deaths_label.text = Loc.t("hud_deaths", [value])


func set_fish(value: int, total: int) -> void:
	_fish_value = value
	_fish_total = total
	fish_label.text = Loc.t("hud_fish", [value, total])


func set_checkpoint(value: int, total: int) -> void:
	_checkpoint_value = value
	_checkpoint_total = total
	checkpoint_label.text = Loc.t("hud_checkpoint", [value, total])


func set_best(seconds: float) -> void:
	_best_value = seconds
	var text := "--:--.--" if seconds <= 0.0 else format_time(seconds)
	best_label.text = text
	start_best_label.text = Loc.t("menu_best", [text])


func set_level(level_id: int, name_key: String) -> void:
	_selected_level = level_id
	_selected_level_name_key = name_key
	_update_level_texts()


func set_level_records(bests: Dictionary) -> void:
	_level_best_values = bests.duplicate()
	_update_level_records()


func _update_level_texts() -> void:
	if current_level_label:
		current_level_label.text = Loc.t("menu_current_level", [_selected_level, Loc.t(_selected_level_name_key)])
	if win_level_label:
		win_level_label.text = Loc.t("win_level", [_selected_level, Loc.t(_selected_level_name_key)])
	for level_id in _level_buttons:
		var button: Button = _level_buttons[level_id]
		if is_instance_valid(button):
			button.tooltip_text = Loc.t("level_play_tooltip", [level_id])


func _update_level_records() -> void:
	for level_id in _level_best_labels:
		var label: Label = _level_best_labels[level_id]
		if not is_instance_valid(label):
			continue
		var seconds := float(_level_best_values.get(level_id, 0.0))
		if seconds <= 0.0:
			label.text = Loc.t("level_no_record")
		else:
			label.text = Loc.t("level_record", [format_time(seconds)])


func _on_locale_changed(_locale: String) -> void:
	_update_language_buttons()
	set_time(_time_value)
	set_deaths(_deaths_value)
	set_fish(_fish_value, _fish_total)
	set_checkpoint(_checkpoint_value, _checkpoint_total)
	set_best(_best_value)
	_update_level_texts()
	_update_level_records()
	if win_overlay.visible:
		_apply_win_texts()


func _apply_win_texts() -> void:
	win_time_label.text = format_time(_win_time_value)
	win_deaths_label.text = str(_win_deaths_value)
	win_fish_label.text = "%d/%d" % [_win_fish_value, _win_fish_total]
	win_record_label.text = Loc.t("win_new_record") if _win_new_record else Loc.t("win_best", [format_time(_win_best_value)])
	win_record_label.add_theme_color_override("font_color", ORANGE if _win_new_record else MUTED)
	if win_level_label:
		win_level_label.text = Loc.t("win_level", [_selected_level, Loc.t(_selected_level_name_key)])


func _lang_button(parent: Node, text: String, code: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_override("font", FONT_BOLD)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: Loc.set_locale(code))
	parent.add_child(button)
	_lang_buttons[code] = button
	_style_lang_button(button, false)
	return button


func _style_lang_button(button: Button, active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = TEAL if active else Color(0.09, 0.12, 0.19, 0.92)
	normal.border_color = Color(0.55, 1.0, 0.9, 0.8) if active else Color(0.4, 0.55, 0.7, 0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("8affdd") if active else Color(0.15, 0.2, 0.29, 0.98)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("38c6a7") if active else Color(0.12, 0.16, 0.24, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	var fg := Color("062019") if active else MUTED
	var fg_hover := Color("02120e") if active else CREAM
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg_hover)
	button.add_theme_color_override("font_pressed_color", fg_hover)
	button.add_theme_color_override("font_focus_color", fg_hover)


func _update_language_buttons() -> void:
	for code in _lang_buttons:
		var button: Button = _lang_buttons[code]
		if is_instance_valid(button):
			_style_lang_button(button, code == Loc.current_locale)


func notify(text: String, color: Color = TEAL) -> void:
	notify_label.text = text
	notify_label.add_theme_color_override("font_color", color)
	notify_label.modulate.a = 0.0
	notify_label.position.y = 0.0
	if _notify_tween and _notify_tween.is_valid():
		_notify_tween.kill()
	_notify_tween = create_tween()
	_notify_tween.set_parallel(true)
	_notify_tween.tween_property(notify_label, "modulate:a", 1.0, 0.13)
	_notify_tween.tween_property(notify_label, "position:y", -10.0, 0.25)
	_notify_tween.chain().tween_interval(1.0)
	_notify_tween.chain().tween_property(notify_label, "modulate:a", 0.0, 0.5)


func flash_death() -> void:
	_flash.color.a = 0.34
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.55)


func fade_black(duration: float, target := 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", target, maxf(duration, 0.01))


func show_start(best: float) -> void:
	start_overlay.visible = true
	pause_overlay.visible = false
	win_overlay.visible = false
	level_overlay.visible = false
	hint_label.visible = false
	_left_panel.visible = false
	_right_panel.visible = false
	set_best(best)
	_update_level_texts()


func hide_start() -> void:
	start_overlay.visible = false
	level_overlay.visible = false
	_left_panel.visible = true
	_right_panel.visible = true
	hint_label.visible = true
	hint_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(9.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.5)


func show_levels() -> void:
	Sfx.play("click", -14.0)
	start_overlay.visible = false
	pause_overlay.visible = false
	win_overlay.visible = false
	level_overlay.visible = true
	_left_panel.visible = false
	_right_panel.visible = false
	hint_label.visible = false
	_update_level_texts()
	_update_level_records()


func hide_levels(return_to_start := true) -> void:
	level_overlay.visible = false
	if return_to_start:
		start_overlay.visible = true
		_left_panel.visible = false
		_right_panel.visible = false
		hint_label.visible = false
		Sfx.play("click", -14.0)


func show_pause() -> void:
	pause_overlay.visible = true


func hide_pause() -> void:
	pause_overlay.visible = false


func show_win(time: float, deaths: int, fish: int, total: int, new_record: bool, best: float) -> void:
	win_overlay.visible = true
	pause_overlay.visible = false
	start_overlay.visible = false
	level_overlay.visible = false
	hint_label.visible = false
	_left_panel.visible = false
	_right_panel.visible = false
	_win_time_value = time
	_win_deaths_value = deaths
	_win_fish_value = fish
	_win_fish_total = total
	_win_new_record = new_record
	_win_best_value = best
	_apply_win_texts()


func hide_win() -> void:
	win_overlay.visible = false
