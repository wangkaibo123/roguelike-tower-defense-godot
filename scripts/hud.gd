extends CanvasLayer
## In-game HUD for roguelike tower defense. Portrait mode (480x854).
## Builds all UI nodes programmatically in _ready().

signal restart_requested()
signal pause_requested()

# --- Node references (created in _ready) ---
var timer_label: Label
var wave_label: Label
var pause_button: Button
var health_bar: ProgressBar
var health_label: Label
var score_label: Label
var wave_announce_label: Label
var game_over_overlay: ColorRect

# --- Colors / Style constants ---
const COLOR_CRIMSON_DARK := Color(0.15, 0.02, 0.04)
const COLOR_CRIMSON := Color(0.55, 0.08, 0.12)
const COLOR_HEALTH_GREEN := Color(0.2, 0.85, 0.2)
const COLOR_HEALTH_RED := Color(0.85, 0.1, 0.1)
const COLOR_TEXT := Color.WHITE
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.6)
const COLOR_PANEL_BG := Color(0.0, 0.0, 0.0, 0.45)

const SCREEN_W := 480
const SCREEN_H := 854


func _ready() -> void:
	layer = 1
	_build_top_area()
	_build_health_bar()
	_build_score_area()
	_build_wave_announcement()


# ============================================================
#  UI CONSTRUCTION
# ============================================================

func _build_top_area() -> void:
	# --- Top bar background ---
	var top_bg := ColorRect.new()
	top_bg.color = COLOR_PANEL_BG
	top_bg.custom_minimum_size = Vector2(SCREEN_W, 48)
	top_bg.size = Vector2(SCREEN_W, 48)
	top_bg.position = Vector2.ZERO
	add_child(top_bg)

	# --- Wave label (top-left) ---
	wave_label = _make_label("Wave 1", 14)
	wave_label.position = Vector2(12, 10)
	wave_label.size = Vector2(120, 28)
	add_child(wave_label)

	# --- Timer label (top-center) ---
	timer_label = _make_label("00:00", 18)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.position = Vector2(SCREEN_W / 2.0 - 60, 8)
	timer_label.size = Vector2(120, 32)
	add_child(timer_label)

	# --- Pause button (top-right) ---
	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.custom_minimum_size = Vector2(44, 38)
	pause_button.size = Vector2(44, 38)
	pause_button.position = Vector2(SCREEN_W - 52, 5)
	_style_button(pause_button)
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)


func _build_health_bar() -> void:
	# --- Container panel ---
	var panel := ColorRect.new()
	panel.color = COLOR_PANEL_BG
	panel.custom_minimum_size = Vector2(160, 46)
	panel.size = Vector2(160, 46)
	panel.position = Vector2(8, 58)
	add_child(panel)

	# --- ProgressBar ---
	health_bar = ProgressBar.new()
	health_bar.min_value = 0
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(144, 18)
	health_bar.size = Vector2(144, 18)
	health_bar.position = Vector2(16, 62)

	# Style the bar with a flat fill and background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_HEALTH_GREEN
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", fill_style)

	add_child(health_bar)

	# --- HP text ---
	health_label = _make_label("HP: 100/100", 12)
	health_label.position = Vector2(16, 82)
	health_label.size = Vector2(144, 20)
	add_child(health_label)


func _build_score_area() -> void:
	var panel := ColorRect.new()
	panel.color = COLOR_PANEL_BG
	panel.custom_minimum_size = Vector2(SCREEN_W, 40)
	panel.size = Vector2(SCREEN_W, 40)
	panel.position = Vector2(0, SCREEN_H - 40)
	add_child(panel)

	score_label = _make_label("Score: 0", 16)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.position = Vector2(0, SCREEN_H - 36)
	score_label.size = Vector2(SCREEN_W, 32)
	add_child(score_label)


func _build_wave_announcement() -> void:
	wave_announce_label = Label.new()
	wave_announce_label.text = ""
	wave_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_announce_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_announce_label.position = Vector2(0, SCREEN_H / 2.0 - 40)
	wave_announce_label.size = Vector2(SCREEN_W, 80)
	wave_announce_label.add_theme_font_size_override("font_size", 36)
	wave_announce_label.add_theme_color_override("font_color", COLOR_TEXT)
	wave_announce_label.add_theme_color_override("font_shadow_color", COLOR_SHADOW)
	wave_announce_label.add_theme_constant_override("shadow_offset_x", 2)
	wave_announce_label.add_theme_constant_override("shadow_offset_y", 2)
	wave_announce_label.modulate.a = 0.0
	wave_announce_label.z_index = 10
	add_child(wave_announce_label)


# ============================================================
#  PUBLIC API
# ============================================================

func update_health(current: int, max_val: int) -> void:
	health_bar.max_value = max_val
	health_bar.value = current
	health_label.text = "HP: %d/%d" % [current, max_val]

	# Interpolate bar color from red to green based on ratio
	var ratio := clampf(float(current) / float(max_val), 0.0, 1.0)
	var bar_color := COLOR_HEALTH_RED.lerp(COLOR_HEALTH_GREEN, ratio)
	var fill_style: StyleBoxFlat = health_bar.get_theme_stylebox("fill").duplicate()
	fill_style.bg_color = bar_color
	health_bar.add_theme_stylebox_override("fill", fill_style)


func update_timer(time: float) -> void:
	var total_seconds := int(time)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func update_wave(wave_num: int) -> void:
	wave_label.text = "Wave %d" % wave_num


func update_score(score: int) -> void:
	score_label.text = "Score: %d" % score


func show_wave_announcement(wave_num: int) -> void:
	wave_announce_label.text = "Wave %d" % wave_num
	wave_announce_label.modulate.a = 0.0

	var tween := create_tween()
	# Fade in
	tween.tween_property(wave_announce_label, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	# Hold
	tween.tween_interval(1.2)
	# Fade out
	tween.tween_property(wave_announce_label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)


func show_game_over(final_score: int, wave: int) -> void:
	if game_over_overlay and is_instance_valid(game_over_overlay):
		game_over_overlay.queue_free()

	# --- Dark overlay ---
	game_over_overlay = ColorRect.new()
	game_over_overlay.color = Color(0.05, 0.0, 0.02, 0.82)
	game_over_overlay.position = Vector2.ZERO
	game_over_overlay.size = Vector2(SCREEN_W, SCREEN_H)
	game_over_overlay.z_index = 50
	add_child(game_over_overlay)

	# --- VBoxContainer centered ---
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = Vector2(SCREEN_W, SCREEN_H)
	vbox.position = Vector2.ZERO
	game_over_overlay.add_child(vbox)

	# Spacer top
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, SCREEN_H * 0.28)
	vbox.add_child(spacer_top)

	# "GAME OVER" title
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title)

	# Spacer
	var gap1 := Control.new()
	gap1.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(gap1)

	# Final score
	var score_lbl := Label.new()
	score_lbl.text = "Final Score: %d" % final_score
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 22)
	score_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	score_lbl.add_theme_color_override("font_shadow_color", COLOR_SHADOW)
	score_lbl.add_theme_constant_override("shadow_offset_x", 2)
	score_lbl.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(score_lbl)

	# Wave reached
	var wave_lbl := Label.new()
	wave_lbl.text = "Wave Reached: %d" % wave
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.add_theme_font_size_override("font_size", 18)
	wave_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	wave_lbl.add_theme_color_override("font_shadow_color", COLOR_SHADOW)
	wave_lbl.add_theme_constant_override("shadow_offset_x", 2)
	wave_lbl.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(wave_lbl)

	# Spacer
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(gap2)

	# Restart button (centered via HBox)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size = Vector2(160, 50)
	_style_button(restart_btn, 20)
	restart_btn.pressed.connect(_on_restart_pressed)
	hbox.add_child(restart_btn)


# ============================================================
#  HELPERS
# ============================================================

func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", COLOR_TEXT)
	lbl.add_theme_color_override("font_shadow_color", COLOR_SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


func _style_button(btn: Button, font_size: int = 16) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", COLOR_TEXT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_CRIMSON
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = COLOR_CRIMSON.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = COLOR_CRIMSON.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)


# ============================================================
#  SIGNAL CALLBACKS
# ============================================================

func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()
