extends CanvasLayer
## Roguelike card-selection screen shown between waves.
## Displays 3 random upgrade cards for the player to choose from.

signal upgrade_selected(upgrade_data: Dictionary)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const CARD_W: float = 130.0
const CARD_H: float = 180.0
const CARD_GAP: float = 16.0
const CARD_BG := Color("#4A1A1A")
const CARD_BORDER := Color("#8B3A3A")
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.72)
const STAR_CHAR := "\u2605"  # filled star
const STAR_EMPTY := "\u2606"  # empty star

static var ALL_UPGRADES: Array[Dictionary] = [
	{
		"id": "emp",
		"name": "EMP",
		"description": "Slow and Vulnerable\nenemy",
		"icon_text": "\u26A1",
		"icon_color": Color("#5BC0EB"),
		"max_stacks": 3,
		"stars": 2,
		"color": Color("#5BC0EB"),
	},
	{
		"id": "shotgun",
		"name": "Shotgun",
		"description": "Get Shotgun\n3-way spread shot",
		"icon_text": "\u2734",
		"icon_color": Color("#E8AA14"),
		"max_stacks": 1,
		"stars": 3,
		"color": Color("#E8AA14"),
	},
	{
		"id": "grenade",
		"name": "Grenade",
		"description": "Get Grenade\nAOE explosion",
		"icon_text": "\uD83D\uDCA3",
		"icon_color": Color("#FF6B35"),
		"max_stacks": 1,
		"stars": 3,
		"color": Color("#FF6B35"),
	},
	{
		"id": "rapid_fire",
		"name": "Rapid Fire",
		"description": "Increase fire rate\nby 20%",
		"icon_text": "\u23E9",
		"icon_color": Color("#7BC950"),
		"max_stacks": 5,
		"stars": 1,
		"color": Color("#7BC950"),
	},
	{
		"id": "damage_up",
		"name": "Damage Up",
		"description": "Increase damage\nby 25%",
		"icon_text": "\u2694",
		"icon_color": Color("#E84855"),
		"max_stacks": 5,
		"stars": 2,
		"color": Color("#E84855"),
	},
	{
		"id": "pierce",
		"name": "Piercing",
		"description": "Bullets pierce\nthrough 1 enemy",
		"icon_text": "\u279B",
		"icon_color": Color("#C77DFF"),
		"max_stacks": 3,
		"stars": 2,
		"color": Color("#C77DFF"),
	},
	{
		"id": "heal",
		"name": "Shield Repair",
		"description": "Restore 30 HP\nto tower",
		"icon_text": "\uD83D\uDEE1",
		"icon_color": Color("#43AA8B"),
		"max_stacks": 99,
		"stars": 1,
		"color": Color("#43AA8B"),
	},
	{
		"id": "speed_bullet",
		"name": "Velocity",
		"description": "Bullet speed\n+30%",
		"icon_text": "\uD83D\uDCA8",
		"icon_color": Color("#90DBF4"),
		"max_stacks": 3,
		"stars": 1,
		"color": Color("#90DBF4"),
	},
]

# ---------------------------------------------------------------------------
# Node references (built in _ready)
# ---------------------------------------------------------------------------

var _overlay: ColorRect
var _title_label: Label
var _card_container: HBoxContainer
var _card_buttons: Array[Button] = []
var _current_choices: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 100
	visible = false
	_build_ui()


func _build_ui() -> void:
	# --- Full-screen overlay ---
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# --- Centred VBox that holds title + cards ---
	var root_vbox := VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	root_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_theme_constant_override("separation", 18)
	_overlay.add_child(root_vbox)

	# --- Title ---
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "UPGRADE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	root_vbox.add_child(_title_label)

	# --- HBox for cards ---
	_card_container = HBoxContainer.new()
	_card_container.name = "CardContainer"
	_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_container.add_theme_constant_override("separation", int(CARD_GAP))
	root_vbox.add_child(_card_container)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func show_upgrades() -> void:
	_pick_random_upgrades(3)
	_populate_cards()
	visible = true


func hide_ui() -> void:
	visible = false


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _pick_random_upgrades(count: int) -> void:
	var pool := ALL_UPGRADES.duplicate(true)
	pool.shuffle()
	_current_choices.clear()
	for i in mini(count, pool.size()):
		_current_choices.append(pool[i])


func _populate_cards() -> void:
	# Remove old cards
	for child in _card_container.get_children():
		child.queue_free()
	_card_buttons.clear()

	for i in _current_choices.size():
		var card := _create_card(_current_choices[i], i)
		_card_container.add_child(card)
		_card_buttons.append(card)


func _create_card(upgrade_data: Dictionary, index: int) -> Button:
	var btn := Button.new()
	btn.name = "Card_%d" % index
	btn.custom_minimum_size = Vector2(CARD_W, CARD_H)
	btn.clip_text = false
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# --- StyleBox for normal state ---
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = CARD_BG
	style_normal.border_color = CARD_BORDER
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	style_normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style_normal)

	# --- Hover ---
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = CARD_BG.lightened(0.12)
	style_hover.border_color = Color.WHITE
	style_hover.set_border_width_all(3)
	btn.add_theme_stylebox_override("hover", style_hover)

	# --- Pressed ---
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = CARD_BG.lightened(0.22)
	style_pressed.border_color = upgrade_data.get("color", Color.WHITE)
	style_pressed.set_border_width_all(3)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# --- Focus (match hover) ---
	btn.add_theme_stylebox_override("focus", style_hover.duplicate())

	# Remove built-in text – we layer our own labels via a child VBox
	btn.text = ""

	# --- Inner layout ---
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# Icon circle area
	var icon_label := Label.new()
	icon_label.text = upgrade_data.get("icon_text", "?")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.add_theme_color_override("font_color", upgrade_data.get("icon_color", Color.WHITE))
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_label)

	# Separator spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# Name
	var name_label := Label.new()
	name_label.text = upgrade_data.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = upgrade_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	# Star rating
	var stars_count: int = upgrade_data.get("stars", 1)
	var star_text := ""
	for s in 3:
		star_text += STAR_CHAR if s < stars_count else STAR_EMPTY
	var star_label := Label.new()
	star_label.text = star_text
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.add_theme_font_size_override("font_size", 14)
	star_label.add_theme_color_override("font_color", Color("#FFD700"))
	star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(star_label)

	# Connect press signal (bind upgrade data)
	btn.pressed.connect(_on_card_pressed.bind(upgrade_data))
	return btn


func _on_card_pressed(upgrade_data: Dictionary) -> void:
	upgrade_selected.emit(upgrade_data)
	hide_ui()
