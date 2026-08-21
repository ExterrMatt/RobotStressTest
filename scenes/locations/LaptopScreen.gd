extends Control
class_name LaptopScreen
## The "app" that runs on the laptop's screen. It is deliberately self-contained —
## it fills whatever container it is dropped into (the black region of the laptop
## screen today; potentially a fullscreen scene of its own later) and never
## assumes anything about the laptop shell around it.
##
## Two apps live here, chosen by `app_mode`:
##   "build"    - pick a limb, then scan it: a component checklist against the
##                player's inventory, a cosmetic scrolling "terminal", and a
##                success/failure summary that can unlock the limb for assembly.
##   "assembly" - list the limbs prepared in the build app and a simplified robot
##                diagram whose arm + torso-socket locks must both be opened before
##                the arm can be connected.

const ICON_DIR: String = "res://assets/textures/icons/"
const PLACEHOLDER_ICON: String = "res://assets/textures/icons/placeholder_item.png"
const GlowingLabelScript: GDScript = preload("res://scenes/ui/GlowingLabel.gd")

const SCREEN_GREEN: Color = Color(0.6, 1.0, 0.62)
const SCREEN_DIM: Color = Color(0.4, 0.72, 0.45)
const OK_GREEN: Color = Color(0.45, 1.0, 0.55)
const ERR_RED: Color = Color(1.0, 0.45, 0.42)
const GLOW_GREEN: Color = Color(0.15, 1.0, 0.35, 1.0)
const BORDER_GREEN: Color = Color(0.2, 0.85, 0.4, 0.75)
const PANEL_FILL: Color = Color(0.0, 0.04, 0.02, 0.55)

## Limb button order on the select screen.
const LIMB_ORDER: Array[String] = ["ARM", "LEG", "TORSO", "HEAD"]

## Per-limb icon + component checklist. Each component names how to look it up in
## the player's inventory (kind/id); kind "none" is a not-yet-implemented part that
## always reads as missing (leg segments, the head's "ridiculous" features).
const LIMBS: Dictionary = {
	"ARM": {
		"icon": "arm",
		"components": [
			{"label": "UPPER ARM", "icon": "upper_arm", "kind": "ingredient", "id": "upper_arm"},
			{"label": "FOREARM", "icon": "", "kind": "none"},
			{"label": "HAND", "icon": "hand", "kind": "part", "id": "hand"},
		],
	},
	"LEG": {
		"icon": "leg",
		"components": [
			{"label": "THIGH", "icon": "", "kind": "none"},
			{"label": "SHIN", "icon": "", "kind": "none"},
			{"label": "FOOT", "icon": "", "kind": "none"},
		],
	},
	"TORSO": {
		"icon": "torso",
		"components": [
			{"label": "CHEST", "icon": "chest", "kind": "part", "id": "chest"},
			{"label": "STOMACH", "icon": "", "kind": "part", "id": "stomach"},
			{"label": "COCONUTS", "icon": "big_coconuts", "kind": "cosmetic_any", "ids": ["big_coconuts", "small_coconuts"]},
			{"label": "CHEST COVER", "icon": "chest_cover", "kind": "cosmetic", "id": "big_chest_cover"},
		],
	},
	"HEAD": {
		"icon": "head",
		"components": [
			{"label": "EYES", "icon": "", "kind": "none"},
			{"label": "NOSE", "icon": "", "kind": "none"},
			{"label": "MOUTH", "icon": "", "kind": "none"},
			{"label": "EARS", "icon": "", "kind": "none"},
			{"label": "SKULL", "icon": "", "kind": "none"},
			{"label": "BRAIN", "icon": "", "kind": "none"},
		],
	},
}

## Fake source lines the scan "terminal" scrolls through for flavour.
const CODE_LINES: Array[String] = [
	"boot: initializing limb bus...",
	"scan> reading component manifest",
	"0x1F3A: checksum ok",
	"linking actuator drivers [##--]",
	"calibrating servo torque=0.82",
	"mem: alloc 4096b @ 0x00A1",
	"net: handshake with spine node",
	"warn: tolerance drift +0.3mm",
	"assembling kinematic chain...",
	"verify: joint range 0-142deg",
	"flash: writing firmware blob",
	"for i in limbs: bind(i)",
	"trace 0x7ffe 0x1a 0xff 0x00",
	"ok: subsystem online",
	"sync: telemetry 60hz",
	"hash 9f2c a1b8 44de 01cc",
	"grip> torque nominal",
	"pose: T-stance locked",
]

## Which build app screen (or "assembly") this app boots into.
@export var app_mode: String = "build"

var _root: Control = null
var _selected_limb: String = ""
var _terminal_label: RichTextLabel = null
var _terminal_lines: PackedStringArray = PackedStringArray()
var _terminal_rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terminal_rng.randomize()

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	if app_mode == "assembly":
		_show_assembly()
	else:
		_show_select()


# =============================================================================
# BUILD APP - select screen
# =============================================================================

func _show_select() -> void:
	_teardown_terminal()
	_clear_root()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	# Header: "Select Limb: X" — an em dash until a limb has been picked, like the
	# bedroom's blank-until-chosen selection line.
	var selected_text: String = _selected_limb if _selected_limb != "" else "—"
	var header := _glow_label("Select Limb: " + selected_text, 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)

	for limb_id in LIMB_ORDER:
		grid.add_child(_make_limb_button(limb_id))


func _make_limb_button(limb_id: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 74)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _panel_style())
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_on_limb_picked.bind(limb_id))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(box)

	var icon := TextureRect.new()
	icon.texture = _icon_tex(String(LIMBS[limb_id].get("icon", "")))
	icon.custom_minimum_size = Vector2(0, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_label := _label(limb_id, 12, SCREEN_GREEN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	return btn


func _on_limb_picked(limb_id: String) -> void:
	_selected_limb = limb_id
	_show_scan(limb_id)


# =============================================================================
# BUILD APP - scan screen
# =============================================================================

func _show_scan(limb_id: String) -> void:
	_teardown_terminal()
	_clear_root()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(columns)

	# --- left column: top-left name + large scan box ---
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	left.add_theme_constant_override("separation", 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(name_row)
	var back_btn := _small_button("‹")
	back_btn.pressed.connect(_show_select)
	name_row.add_child(back_btn)
	name_row.add_child(_glow_label(limb_id, 18))

	left.add_child(_build_scan_box(limb_id))

	# --- right column: terminal (top) + summary (bottom) ---
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)

	right.add_child(_build_terminal_box())
	right.add_child(_build_summary_box(limb_id))


func _build_scan_box(limb_id: String) -> Control:
	var box := _box()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)

	# Limb icon inside its own sub-box (box in a box).
	var sub := _box(Color(0.3, 0.9, 0.45, 0.6))
	sub.custom_minimum_size = Vector2(64, 0)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var big_icon := TextureRect.new()
	big_icon.texture = _icon_tex(String(LIMBS[limb_id].get("icon", "")))
	big_icon.custom_minimum_size = Vector2(56, 60)
	big_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_child(big_icon)
	row.add_child(sub)

	# Checklist of components.
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(list)

	list.add_child(_label("LIMB SCAN:", 12, SCREEN_GREEN))
	for comp in LIMBS[limb_id].get("components", []):
		list.add_child(_build_component_row(comp))

	return box


func _build_component_row(comp: Dictionary) -> Control:
	var present := _component_present(comp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture = _icon_tex(String(comp.get("icon", "")))
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_label := _label(String(comp.get("label", "?")), 11, SCREEN_GREEN)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var mark := _label("✓" if present else "✗", 12, OK_GREEN if present else ERR_RED)
	row.add_child(mark)
	return row


func _build_terminal_box() -> Control:
	var box := _box(Color(0.25, 0.8, 0.4, 0.6))
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_terminal_label = RichTextLabel.new()
	_terminal_label.bbcode_enabled = false
	_terminal_label.scroll_active = true
	_terminal_label.scroll_following = true
	_terminal_label.fit_content = false
	_terminal_label.clip_contents = true
	_terminal_label.add_theme_font_size_override("normal_font_size", 9)
	_terminal_label.add_theme_color_override("default_color", Color(0.45, 0.95, 0.5))
	_terminal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_terminal_label)

	_terminal_lines = PackedStringArray()
	_terminal_label.text = ""

	var timer := Timer.new()
	timer.name = "TerminalTimer"
	timer.wait_time = 0.13
	timer.autostart = true
	timer.timeout.connect(_terminal_tick)
	box.add_child(timer)
	return box


func _terminal_tick() -> void:
	if _terminal_label == null or not is_instance_valid(_terminal_label):
		return
	var line := CODE_LINES[_terminal_rng.randi_range(0, CODE_LINES.size() - 1)]
	_terminal_lines.append("> " + line)
	while _terminal_lines.size() > 40:
		_terminal_lines.remove_at(0)
	_terminal_label.text = "\n".join(_terminal_lines) + "\n> _"


func _build_summary_box(limb_id: String) -> Control:
	var box := _box(Color(0.3, 0.9, 0.45, 0.7))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)

	vbox.add_child(_label("SUMMARY", 16, SCREEN_GREEN))

	var missing := _missing_components(limb_id)
	if missing.is_empty():
		vbox.add_child(_label("SUCCESS", 13, OK_GREEN))
		var limb_key := limb_id.to_lower()
		if GameState.is_limb_prepared(limb_key):
			vbox.add_child(_label("PREPARED ✓", 11, OK_GREEN))
		else:
			var unlock_btn := _small_button("UNLOCK LIMB")
			unlock_btn.pressed.connect(_on_unlock_pressed.bind(limb_id))
			vbox.add_child(unlock_btn)
	else:
		vbox.add_child(_label("FAILURE", 13, ERR_RED))
		for label_text in missing:
			vbox.add_child(_label("- MISSING " + label_text, 10, ERR_RED))

	return box


func _on_unlock_pressed(limb_id: String) -> void:
	GameState.prepare_limb(limb_id.to_lower())
	# Rebuild the scan so the summary flips to PREPARED.
	_show_scan(limb_id)


# =============================================================================
# ASSEMBLY APP
# =============================================================================

func _show_assembly() -> void:
	_teardown_terminal()
	_clear_root()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(columns)

	# Left: prepared limbs.
	var left := _box()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 3)
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(left_box)
	left_box.add_child(_label("PREPARED LIMBS", 14, SCREEN_GREEN))
	if GameState.prepared_limbs.is_empty():
		left_box.add_child(_label("— none —", 11, SCREEN_DIM))
	else:
		for limb_key in GameState.prepared_limbs:
			var prep_row := HBoxContainer.new()
			prep_row.add_theme_constant_override("separation", 4)
			prep_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pic := TextureRect.new()
			pic.texture = _icon_tex(String(LIMBS.get(String(limb_key).to_upper(), {}).get("icon", "")))
			pic.custom_minimum_size = Vector2(18, 18)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			prep_row.add_child(pic)
			prep_row.add_child(_label(String(limb_key).to_upper(), 11, SCREEN_GREEN))
			left_box.add_child(prep_row)

	columns.add_child(left)

	# Right: simplified robot diagram + locks.
	var right := _box(Color(0.3, 0.9, 0.45, 0.7))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 3)
	right_box.alignment = BoxContainer.ALIGNMENT_CENTER
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(right_box)

	right_box.add_child(_label("ASSEMBLY", 14, SCREEN_GREEN))

	var diagram := TextureRect.new()
	diagram.texture = _icon_tex("torso")
	diagram.custom_minimum_size = Vector2(0, 56)
	diagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(diagram)

	var arm_lock := _small_button(_lock_label("ARM LOCK", GameState.arm_lock_open))
	arm_lock.pressed.connect(_on_toggle_arm_lock)
	right_box.add_child(arm_lock)

	var socket_lock := _small_button(_lock_label("SOCKET LOCK", GameState.torso_socket_lock_open))
	socket_lock.pressed.connect(_on_toggle_socket_lock)
	right_box.add_child(socket_lock)

	if GameState.arm_connected:
		right_box.add_child(_label("ARM CONNECTED ✓", 12, OK_GREEN))
	else:
		var can_connect := GameState.arm_lock_open and GameState.torso_socket_lock_open
		var connect_btn := _small_button("CONNECT ARM")
		connect_btn.disabled = not can_connect
		connect_btn.pressed.connect(_on_connect_arm)
		right_box.add_child(connect_btn)
		if not can_connect:
			right_box.add_child(_label("open both locks to connect", 9, SCREEN_DIM))


	columns.add_child(right)


func _lock_label(name: String, is_open: bool) -> String:
	return "%s: %s" % [name, "OPEN" if is_open else "LOCKED"]


func _on_toggle_arm_lock() -> void:
	GameState.arm_lock_open = not GameState.arm_lock_open
	_show_assembly()


func _on_toggle_socket_lock() -> void:
	GameState.torso_socket_lock_open = not GameState.torso_socket_lock_open
	_show_assembly()


func _on_connect_arm() -> void:
	if GameState.arm_lock_open and GameState.torso_socket_lock_open:
		GameState.arm_connected = true
	_show_assembly()


# =============================================================================
# HELPERS
# =============================================================================

func _clear_root() -> void:
	for child in _root.get_children():
		child.queue_free()


func _teardown_terminal() -> void:
	_terminal_label = null


func _component_present(comp: Dictionary) -> bool:
	match String(comp.get("kind", "none")):
		"part":
			return GameState.get_robot_part_count(String(comp.get("id", ""))) >= 1
		"ingredient":
			return int(GameState.ingredients.get(String(comp.get("id", "")), 0)) >= 1
		"cosmetic":
			return GameState.has_cosmetic_item(String(comp.get("id", "")))
		"cosmetic_any":
			for id in comp.get("ids", []):
				if GameState.has_cosmetic_item(String(id)):
					return true
			return false
		_:
			return false


func _missing_components(limb_id: String) -> Array[String]:
	var missing: Array[String] = []
	for comp in LIMBS.get(limb_id, {}).get("components", []):
		if not _component_present(comp):
			missing.append(String(comp.get("label", "?")))
	return missing


func _icon_tex(icon_name: String) -> Texture2D:
	if icon_name != "":
		var path := ICON_DIR + icon_name + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return load(PLACEHOLDER_ICON) as Texture2D


func _label(text: String, size: int = 12, color: Color = SCREEN_GREEN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _glow_label(text: String, size: int = 18) -> Label:
	var l := Label.new()
	l.set_script(GlowingLabelScript)
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", SCREEN_GREEN)
	l.set("glow_color", GLOW_GREEN)
	l.set("glow_radius_px", 20.0)
	l.set("glow_strength", 1.4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _small_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", SCREEN_GREEN)
	btn.add_theme_color_override("font_hover_color", OK_GREEN)
	btn.add_theme_color_override("font_disabled_color", SCREEN_DIM)
	btn.add_theme_stylebox_override("normal", _panel_style())
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.25, 0.5, 0.3, 0.5)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


func _box(border: Color = BORDER_GREEN) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _panel_style(border))
	return p


func _panel_style(border: Color = BORDER_GREEN) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_FILL
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_top = 5
	sb.content_margin_right = 6
	sb.content_margin_bottom = 5
	return sb
