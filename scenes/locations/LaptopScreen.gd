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
## Head part art lives with the workshop assembly pieces (no icon-sized versions), so the
## head scan uses these full paths directly (see _icon_tex's res:// passthrough).
const HEAD_TEX_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot head/"
const GlowingLabelScript: GDScript = preload("res://scenes/ui/GlowingLabel.gd")

const SCREEN_GREEN: Color = Color(0.6, 1.0, 0.62)
const SCREEN_DIM: Color = Color(0.4, 0.72, 0.45)
const OK_GREEN: Color = Color(0.45, 1.0, 0.55)
const ERR_RED: Color = Color(1.0, 0.45, 0.42)
const GLOW_GREEN: Color = Color(0.15, 1.0, 0.35, 1.0)
const BORDER_GREEN: Color = Color(0.2, 0.85, 0.4, 0.75)
const PANEL_FILL: Color = Color(0.0, 0.04, 0.02, 0.55)

## Limb button order on the select screen.
const LIMB_ORDER: Array[String] = ["ARM", "LEG", "STOMACH", "HEAD"]

## Per-limb icon + component checklist. Each component names how to look it up in
## the player's inventory (kind/id); kind "none" is a not-yet-implemented part that
## always reads as missing (leg segments, the head's "ridiculous" features).
const LIMBS: Dictionary = {
	"ARM": {
		"icon": "arm",
		"components": [
			{"label": "UPPER ARM", "icon": "upper_arm", "kind": "ingredient", "id": "upper_arm"},
			{"label": "FOREARM", "icon": "forearm", "kind": "ingredient", "id": "forearm"},
			{"label": "HAND", "icon": "hand", "kind": "part", "id": "hand"},
		],
	},
	"LEG": {
		"icon": "leg",
		"components": [
			{"label": "THIGH", "icon": "thighs", "kind": "ingredient", "id": "thigh"},
			{"label": "SHIN", "icon": "shin", "kind": "ingredient", "id": "shin"},
			{"label": "FOOT", "icon": "foot", "kind": "ingredient", "id": "foot"},
		],
	},
	"STOMACH": {
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
			{"label": "EYES", "icon": HEAD_TEX_DIR + "left_eye.png", "kind": "none"},
			{"label": "NOSE", "icon": HEAD_TEX_DIR + "nose.png", "kind": "none"},
			{"label": "MOUTH", "icon": HEAD_TEX_DIR + "mouth.png", "kind": "none"},
			{"label": "EARS", "icon": HEAD_TEX_DIR + "left_ear.png", "kind": "none"},
			{"label": "SKULL", "icon": HEAD_TEX_DIR + "metal_head.png", "kind": "none"},
			{"label": "BRAIN", "icon": "brain", "kind": "none"},
		],
	},
}

## Curated flavour lines for the scan "terminal". Most terminal output is instead generated
## on the fly by _random_code_line so it stays varied and rarely repeats.
const CODE_LINES: Array[String] = [
	"boot: initializing limb bus...",
	"scan> reading component manifest",
	"linking actuator drivers [##--]",
	"net: handshake with spine node",
	"warn: tolerance drift +0.3mm",
	"assembling kinematic chain...",
	"flash: writing firmware blob",
	"ok: subsystem online",
	"grip> torque nominal",
	"pose: T-stance locked",
	"dma: burst xfer complete",
	"sched: yield to isr#12",
	"crypto: rotating session key",
	"fs: mount /dev/limb0 ro",
	"panic averted: watchdog fed",
	"decode: opcode stream valid",
	"pll: locked @ 144MHz",
	"irq: servo fault cleared",
	"thermal: 41.2C within limits",
	"stack: unwinding frame 0x1a",
]

## Fragments the generator recombines into varied fake-code lines.
const CODE_SYMBOLS: Array[String] = [
	"actuator", "servo", "spine", "gyro", "hydraulic", "cortex", "limbctl", "kinematic",
	"telemetry", "firmware", "chassis", "joint", "sensor", "driver", "encoder", "solenoid",
]
const CODE_VERBS: Array[String] = [
	"bind", "flush", "probe", "map", "seal", "arm", "sync", "patch", "spin", "halt",
]
const CODE_KEYWORDS: Array[String] = [
	"for", "while", "if", "return", "yield", "await", "goto", "call",
]
const HEX_DIGITS: String = "0123456789ABCDEF"

## Which build app screen (or "assembly") this app boots into.
@export var app_mode: String = "build"
## Where this screen is hosted, which changes the assembly app's top-level picker:
## "maintenance" (the maintenance scene) keeps the 2-column grid, "laptop" (the standalone
## laptop) uses the recycled 3-top/2-bottom limb menu. Set by the desktop that spawns it.
@export var desktop_context: String = "laptop"
## When set on a build-mode screen, boot straight into that limb's scan (skipping the
## limb-select), used by the maintenance app's LIMB SCAN button.
@export var initial_build_limb: String = ""
## On a build-mode screen launched from maintenance, the assembly PART name to return to when
## backing out of the scan (so back goes to that limb's maintenance view, not the limb-select).
@export var builder_return_part: String = ""
## When set on an assembly-mode screen, boot straight into this part's view (its side-select
## for arm/leg, else its segment list) instead of the top-level picker.
@export var initial_assembly_part: String = ""

## Emitted by the assembly app's LIMB SCAN button so the host desktop can open the builder
## already scanning `limb_id` (a LIMBS key: "ARM"/"LEG"/"HEAD"/"STOMACH"); `origin_part` is
## the assembly PART name it was launched from, so back can return exactly there.
signal open_builder_for_limb(limb_id: String, origin_part: String)
## Emitted when backing out of a maintenance-launched build scan: reopen the maintenance app
## at `part_name`.
signal return_to_maintenance(part_name: String)

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
		if initial_assembly_part != "":
			_open_assembly_part_by_name(initial_assembly_part)
		else:
			_show_assembly()
	elif initial_build_limb != "":
		# LIMB SCAN entry: jump straight into this limb's scan.
		_selected_limb = initial_build_limb
		_show_scan(initial_build_limb)
	else:
		_show_select()


## Boots the assembly app straight into a named part's view: its side-select for arm/leg,
## otherwise its segment list. Falls back to the top-level picker if the name is unknown.
func _open_assembly_part_by_name(part_name: String) -> void:
	var idx := _assembly_index_by_name(part_name)
	if idx < 0:
		_show_assembly()
		return
	if bool(ASSEMBLY_PARTS[idx].get("sides", false)):
		_show_assembly_side_select(idx)
	else:
		_show_assembly_part(idx)


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
	back_btn.pressed.connect(_on_scan_back)
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
	_hide_scrollbar(_terminal_label)

	_terminal_lines = PackedStringArray()
	_terminal_label.text = ""

	var timer := Timer.new()
	timer.name = "TerminalTimer"
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_terminal_tick)
	box.add_child(timer)
	return box


func _terminal_tick() -> void:
	if _terminal_label == null or not is_instance_valid(_terminal_label):
		return
	_terminal_lines.append("> " + _random_code_line(_terminal_rng))
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
# ASSEMBLY APP - body-part / segment browser
# =============================================================================

## Arm segments, shared by LEFT ARM and RIGHT ARM (edit here to change both sides at once).
## Each segment's "id" points at a craftable item in WorkshopMinigame.CRAFTABLE_PARTS; the
## recipe shown is looked up live from there (the real source of truth), not stored here.
const _ARM_SEGMENTS: Array = [
	{"name": "UPPER ARM", "icon": "upper_arm", "id": "upper_arm"},
	{"name": "FOREARM", "icon": "forearm", "id": "forearm"},
	{"name": "HAND", "icon": "hand", "id": "hand"},
]

## The body parts shown in the assembly app. Each part has an icon + a list of segments,
## and each segment an "id" of the real craftable item whose recipe it shows. Parts marked
## `sides` (ARM, LEG) first offer LEFT / RIGHT (they share the same segments), then drop into
## the normal (identical) segment view. `build_limb` names the builder limb the LIMB SCAN
## button opens for this part.
const ASSEMBLY_PARTS: Array = [
	{"name": "ARM", "icon": "arm", "sides": true, "build_limb": "ARM", "segments": _ARM_SEGMENTS},
	{"name": "LEG", "icon": "leg", "sides": true, "build_limb": "LEG", "segments": [
		{"name": "THIGH", "icon": "thighs", "id": "thigh"},
		{"name": "SHIN", "icon": "shin", "id": "shin"},
		{"name": "FOOT", "icon": "foot", "id": "foot"},
	]},
	{"name": "HEAD", "icon": "head", "build_limb": "HEAD", "segments": [
		{"name": "EYES", "icon": HEAD_TEX_DIR + "left_eye.png", "id": "head"},
		{"name": "NOSE", "icon": HEAD_TEX_DIR + "nose.png", "id": "head"},
		{"name": "MOUTH", "icon": HEAD_TEX_DIR + "mouth.png", "id": "head"},
		{"name": "EARS", "icon": HEAD_TEX_DIR + "left_ear.png", "id": "head"},
		{"name": "SKULL", "icon": HEAD_TEX_DIR + "metal_head.png", "id": "head"},
		{"name": "BRAIN", "icon": "brain", "id": "head"},
	]},
	{"name": "CHEST", "icon": "chest", "build_limb": "STOMACH", "segments": [
		{"name": "RIB CAGE", "icon": "ribcage", "id": "ribcage"},
		{"name": "UPPER PLATING", "icon": "upper_plating", "id": "upper_plating"},
		{"name": "LOWER PLATING", "icon": "lower_plating", "id": "lower_plating"},
	]},
	{"name": "STOMACH", "icon": "torso", "build_limb": "STOMACH", "segments": [
		{"name": "TANK", "icon": "", "id": "tank"},
		{"name": "PUMP", "icon": "", "id": "pump"},
		{"name": "HUGE BATTERY", "icon": "battery", "id": "huge_battery"},
	]},
]

## Laptop-context top-level order for the recycled limb menu (3 on top, 2 on bottom centered).
const ASSEMBLY_LAPTOP_ORDER: Array[String] = ["LEG", "ARM", "CHEST", "STOMACH", "HEAD"]

## Which part / segment is being viewed (-1 = the top-level part list).
var _assembly_part_index: int = -1
var _assembly_segment_index: int = -1


## Top level: prepared limbs over a code panel (left) and just the body-part picker (right,
## with nothing filling the space below it).
func _show_assembly() -> void:
	_teardown_terminal()
	_clear_root()
	_assembly_part_index = -1
	_assembly_segment_index = -1

	var columns := _two_column_layout()

	# Left: prepared limbs, with a code panel filling the space below (bottom-left = code).
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)
	left.add_child(_build_prepared_limbs_box())
	var code_panel := _make_code_terminal()
	code_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(code_panel)

	# Right: just the part picker. The box fills the column height (buttons sit at the top).
	var right := _box(Color(0.3, 0.9, 0.45, 0.7))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 5)
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(right_box)
	right_box.add_child(_label("ASSEMBLY", 14, SCREEN_GREEN))
	if desktop_context == "laptop":
		_populate_assembly_menu_laptop(right_box)
	else:
		_populate_assembly_grid_maintenance(right_box)


## Maintenance context: the 2-column grid, but with a lonely trailing (odd) button centered
## in its own row instead of stuck to the left with an empty cell beside it.
func _populate_assembly_grid_maintenance(container: VBoxContainer) -> void:
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(rows)

	var count := ASSEMBLY_PARTS.size()
	var i := 0
	while i < count:
		var lone := i == count - 1  # a final odd button
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(row)
		if lone:
			# Center the lone button at the same width as a grid cell: it takes half the row
			# (stretch 1.0) with a quarter-width spacer on each side (0.5 each).
			_add_expand_spacer(row, 0.5)
			row.add_child(_make_assembly_part_button(i))
			_add_expand_spacer(row, 0.5)
			i += 1
		else:
			row.add_child(_make_assembly_part_button(i))
			row.add_child(_make_assembly_part_button(i + 1))
			i += 2


## Laptop context: the recycled limb-select look — 3 tiles on the top row and 2 centered
## below, in ASSEMBLY_LAPTOP_ORDER. Tiles expand to fill the column width (a third each) so
## the row never overruns the right edge.
func _populate_assembly_menu_laptop(container: VBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(col)

	var ordered: Array[int] = []
	for name in ASSEMBLY_LAPTOP_ORDER:
		var idx := _assembly_index_by_name(String(name))
		if idx >= 0:
			ordered.append(idx)

	# Vertically centre the two rows.
	_add_vexpand_spacer(col)
	var per_top := 3
	var made := 0
	while made < ordered.size():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(row)
		var upto := mini(made + per_top, ordered.size())
		# A short final row (the 2 on the bottom) is centred at the same tile width by
		# flanking it with half-width spacers.
		var short := (upto - made) < per_top
		if short:
			_add_expand_spacer(row, 0.5)
		for k in range(made, upto):
			row.add_child(_menu_tile(ordered[k]))
		if short:
			_add_expand_spacer(row, 0.5)
		made = upto
	_add_vexpand_spacer(col)


## One flexible limb tile for the laptop menu: fills its share of the row width, fixed height.
func _menu_tile(index: int) -> Button:
	var btn := _make_assembly_part_button(index)
	btn.custom_minimum_size = Vector2(0, 74)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return btn


func _add_vexpand_spacer(col: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)


func _assembly_index_by_name(part_name: String) -> int:
	for i in ASSEMBLY_PARTS.size():
		if String(ASSEMBLY_PARTS[i].get("name", "")) == part_name:
			return i
	return -1


func _add_expand_spacer(row: HBoxContainer, stretch_ratio: float = 1.0) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = stretch_ratio
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)


## A `sides` part (ARM, LEG) first offers LEFT / RIGHT — they share the same segments; picking
## a side drops into the normal part view with the side shown in the header. The name slot
## stays anchored at the top (like every other detail screen); the two buttons sit centered
## in the space below it.
func _show_assembly_side_select(index: int) -> void:
	_teardown_terminal()
	_clear_root()
	_assembly_part_index = index
	_assembly_segment_index = -1
	var part: Dictionary = ASSEMBLY_PARTS[index]
	var part_name := String(part.get("name", "?"))

	var margin := _screen_margin()
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# Header pinned at the top.
	var header := _detail_name_slot(part_name, _show_assembly)
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_child(header)

	# LEFT / RIGHT centered in the remaining space.
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	for side in ["LEFT", "RIGHT"]:
		var btn := _recipe_button("%s %s" % [side, part_name])
		btn.custom_minimum_size = Vector2(110, 56)
		btn.pressed.connect(_show_assembly_part.bind(index, side))
		row.add_child(btn)


## One body part: its name slot (top-left) + picture (bottom-left), and RECIPE = its list of
## clickable segments (right), with a LIMB SCAN button pinned at the bottom-right. `side`
## (for ARM) is shown in the header only — the segments are identical on both sides.
func _show_assembly_part(index: int, side: String = "") -> void:
	_teardown_terminal()
	_clear_root()
	_assembly_part_index = index
	_assembly_segment_index = -1
	var part: Dictionary = ASSEMBLY_PARTS[index]
	var title: String = String(part.get("name", "?"))
	if side != "":
		title = "%s %s" % [side, title]
	# A `sides` part backs out to the side-select; everything else to the top-level picker.
	var on_back: Callable = _show_assembly_side_select.bind(index) \
		if bool(part.get("sides", false)) else Callable(_show_assembly)

	var columns := _two_column_layout()

	var shared: Array = [-1, -1]
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)
	left.add_child(_detail_name_slot(title, on_back))
	left.add_child(_detail_image_box(String(part.get("icon", "")), shared))
	var grid := _make_grid_widget()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(grid)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)

	# Recipe box fills the remaining height above the LIMB SCAN button, so its buttons stay
	# inside the app (the old decorative filler here overflowed behind the taskbar).
	var recipe_box := _box(Color(0.3, 0.9, 0.45, 0.7))
	recipe_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_box.clip_contents = true
	var recipe_vbox := VBoxContainer.new()
	recipe_vbox.add_theme_constant_override("separation", 2)
	recipe_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_box.add_child(recipe_vbox)
	recipe_vbox.add_child(_label("RECIPE", 13, SCREEN_GREEN))
	var segments: Array = part.get("segments", [])
	for si in segments.size():
		var seg: Dictionary = segments[si]
		var seg_btn := _recipe_button(String(seg.get("name", "?")))
		seg_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		seg_btn.pressed.connect(_show_assembly_segment.bind(index, si))
		recipe_vbox.add_child(seg_btn)
	right.add_child(recipe_box)

	right.add_child(_make_limb_scan_button(index))


## One segment: its name slot (top-left) + picture (bottom-left), and its crafting RECIPE
## (right). Code panel fills the leftover space.
func _show_assembly_segment(part_index: int, seg_index: int) -> void:
	_teardown_terminal()
	_clear_root()
	_assembly_part_index = part_index
	_assembly_segment_index = seg_index
	var part: Dictionary = ASSEMBLY_PARTS[part_index]
	var seg: Dictionary = (part.get("segments", []) as Array)[seg_index]

	var columns := _two_column_layout()

	var shared: Array = [-1, -1]
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)
	left.add_child(_detail_name_slot(String(seg.get("name", "?")), _show_assembly_part.bind(part_index)))
	left.add_child(_detail_image_box(String(seg.get("icon", "")), shared))
	var grid := _make_grid_widget()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(grid)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)

	var recipe_box := _box(Color(0.3, 0.9, 0.45, 0.7))
	recipe_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var recipe_vbox := VBoxContainer.new()
	recipe_vbox.add_theme_constant_override("separation", 3)
	recipe_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_box.add_child(recipe_vbox)
	recipe_vbox.add_child(_label("RECIPE", 13, SCREEN_GREEN))
	var recipe: Array = _real_recipe_rows(String(seg.get("id", "")))
	if recipe.is_empty():
		recipe_vbox.add_child(_label("— no recipe —", 10, SCREEN_DIM))
	else:
		for item in recipe:
			recipe_vbox.add_child(_make_recipe_row(item))
	right.add_child(recipe_box)

	# Fill the gap, then pin the LIMB SCAN button at the bottom-right.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)
	right.add_child(_make_limb_scan_button(part_index))


# --- assembly helpers ---

## The bottom-right LIMB SCAN button: opens the builder already scanning this part's limb
## (the old build limb-select is skipped). Fixed height so it never clips behind the taskbar.
func _make_limb_scan_button(part_index: int) -> Button:
	var btn := _recipe_button("LIMB SCAN ›")
	btn.custom_minimum_size = Vector2(0, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_END
	btn.pressed.connect(_on_limb_scan_pressed.bind(part_index))
	return btn


func _on_limb_scan_pressed(part_index: int) -> void:
	var part: Dictionary = ASSEMBLY_PARTS[part_index]
	var limb := String(part.get("build_limb", ""))
	if limb != "":
		open_builder_for_limb.emit(limb, String(part.get("name", "")))


## Scan back: return to the launching limb's maintenance view when opened from there,
## otherwise fall back to the builder's own limb-select.
func _on_scan_back() -> void:
	if builder_return_part != "":
		return_to_maintenance.emit(builder_return_part)
	else:
		_show_select()


## Full-rect margin + an HBox of two equal columns, added to _root. Returns the HBox.
func _two_column_layout() -> HBoxContainer:
	var margin := _screen_margin()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 6)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(columns)
	return columns


func _screen_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)
	return margin


func _build_prepared_limbs_box() -> Control:
	var box := _box()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	vbox.add_child(_label("PREPARED LIMBS", 14, SCREEN_GREEN))
	if GameState.prepared_limbs.is_empty():
		vbox.add_child(_label("— none —", 11, SCREEN_DIM))
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
			vbox.add_child(prep_row)
	return box


## A back button + title in a bordered "slot" - the top-left name box of a detail view.
func _detail_name_slot(title: String, on_back: Callable) -> Control:
	var box := _box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var back := _small_button("‹")
	back.pressed.connect(on_back)
	row.add_child(back)
	row.add_child(_glow_label(title, 16))
	return box


## A compact button for the recipe segment list, so all segments (up to the head's six)
## fit alongside the widget below without running off the bottom.
func _recipe_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", SCREEN_GREEN)
	btn.add_theme_color_override("font_hover_color", OK_GREEN)
	for state in ["normal", "hover", "pressed"]:
		var hot: bool = state != "normal"
		var sb: StyleBoxFlat = _panel_style(Color(0.35, 1.0, 0.5, 0.95)) if hot else _panel_style()
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


## The top block of a detail view's left column: a fixed SQUARE icon container (hard-left)
## and, as its own separate container beside it, a cycling widget (slot 0 of `shared`).
func _detail_image_box(icon_name: String, shared: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Square icon container - fixed size so it stays square and never moves.
	var img_box := _box(Color(0.3, 0.9, 0.45, 0.6))
	img_box.custom_minimum_size = Vector2(118, 118)
	img_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	img_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	img_box.clip_contents = true
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_box.add_child(center)
	var pic := TextureRect.new()
	pic.texture = _icon_tex(icon_name)
	pic.custom_minimum_size = Vector2(102, 102)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(pic)
	row.add_child(img_box)

	# Its own separate container beside it: fixed height, fills the remaining width.
	var widget := _make_filler_widget(shared, 0)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	widget.custom_minimum_size = Vector2(0, 118)
	row.add_child(widget)
	return row


## An assembly part button (icon over label, expand-fill). ARM / LEG parts route through the
## LEFT/RIGHT side-select first; the rest go straight to their segment view.
func _make_assembly_part_button(index: int) -> Button:
	var part: Dictionary = ASSEMBLY_PARTS[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _panel_style())
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if bool(part.get("sides", false)):
		btn.pressed.connect(_show_assembly_side_select.bind(index))
	else:
		btn.pressed.connect(_show_assembly_part.bind(index))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(box)

	var icon := TextureRect.new()
	icon.texture = _icon_tex(String(part.get("icon", "")))
	icon.custom_minimum_size = Vector2(0, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_label := _label(String(part.get("name", "?")), 11, SCREEN_GREEN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return btn


## The real crafting recipe for a craftable item id, read live from the workshop's recipe
## registry (WorkshopMinigame.CRAFTABLE_PARTS) - the single source of truth. Returns rows of
## {label, icon, qty}; empty if the id isn't craftable.
func _real_recipe_rows(item_id: String) -> Array:
	var rows: Array = []
	if item_id == "":
		return rows
	var parts: Dictionary = WorkshopMinigame.CRAFTABLE_PARTS
	var data: Dictionary = parts.get(item_id, {})
	# Composite limb (arm/leg/chest): its "recipe" is one of each segment item.
	var segments: Array = data.get("segments", [])
	if not segments.is_empty():
		for seg_id in segments:
			var seg_data: Dictionary = parts.get(String(seg_id), {})
			rows.append({
				"label": String(seg_data.get("display_name", String(seg_id).replace("_", " "))).to_upper(),
				"icon": String(seg_id),
				"qty": 1,
			})
		return rows
	var recipe: Dictionary = data.get("recipe", {})
	for ing_id in recipe:
		rows.append({
			"label": String(ing_id).replace("_", " ").to_upper(),
			"icon": String(ing_id),
			"qty": int(recipe[ing_id]),
		})
	return rows


## One line of a segment's crafting recipe: icon + material name + quantity.
func _make_recipe_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture = _icon_tex(String(item.get("icon", "")))
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_label := _label(String(item.get("label", "?")), 11, SCREEN_GREEN)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	row.add_child(_label("x%d" % int(item.get("qty", 1)), 11, SCREEN_DIM))
	return row


## Picks one of several ambient "hacker" filler widgets at random - a system monitor, a
## signal meter, a fault alert, a progress readout, or a scope - to dress the empty space.
## Deliberately a VARIETY, not more scrolling code.
## A slot that shows a random widget and swaps it for a different one after a while. `shared`
## + `my_slot` let sibling slots coordinate: two on the same screen never show the same
## widget type at once. Call with no args for a standalone slot.
func _make_filler_widget(shared: Array = [], my_slot: int = 0) -> Control:
	var slot := MarginContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	while shared.size() <= my_slot:
		shared.append(-1)
	var others := func() -> Array:
		var ex: Array = []
		for i in shared.size():
			if i != my_slot and int(shared[i]) >= 0:
				ex.append(int(shared[i]))
		return ex
	var t: int = _random_widget_type(others.call())
	shared[my_slot] = t
	var current: Array = [_widget_for_type(t)]
	slot.add_child(current[0])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var timer := Timer.new()
	timer.wait_time = rng.randf_range(9.0, 16.0)
	timer.autostart = true
	slot.add_child(timer)
	var swap := func() -> void:
		if not is_instance_valid(slot):
			return
		if current[0] != null and is_instance_valid(current[0]):
			current[0].queue_free()
		var nt: int = _random_widget_type(others.call())
		shared[my_slot] = nt
		current[0] = _widget_for_type(nt)
		slot.add_child(current[0])
		timer.wait_time = rng.randf_range(9.0, 16.0)
	timer.timeout.connect(swap)
	return slot


## Weighted random widget-type index, never one of `exclude`. Fault (4) is rare (1 in 9).
func _random_widget_type(exclude: Array) -> int:
	var bag: Array = [0, 0, 1, 1, 2, 2, 3, 3, 4]  # status/meter/progress/wave x2, alert x1
	var pool: Array = []
	for t in bag:
		if not (t in exclude):
			pool.append(t)
	if pool.is_empty():
		pool = [0, 1, 2, 3]
	return int(pool[randi() % pool.size()])


func _widget_for_type(t: int) -> Control:
	match t:
		0:
			return _make_status_widget()
		1:
			return _make_meter_widget()
		2:
			return _make_progress_widget()
		3:
			return _make_wave_widget()
		_:
			return _make_alert_widget()


## System-monitor panel: a few named readouts whose values tick over.
func _make_status_widget() -> Control:
	var box := _box(Color(0.3, 0.9, 0.45, 0.6))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	vbox.add_child(_label("● SYS MONITOR", 10, SCREEN_GREEN))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var specs := [
		{"name": "CORE", "unit": "C", "lo": 34, "hi": 58},
		{"name": "LINK", "unit": "%", "lo": 82, "hi": 100},
		{"name": "LOAD", "unit": "%", "lo": 4, "hi": 96},
		{"name": "MEM", "unit": "MB", "lo": 180, "hi": 820},
	]
	var rows: Array = []
	for spec in specs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_label(String(spec["name"]), 9, SCREEN_DIM))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
		var val := _label("--", 9, SCREEN_GREEN)
		val.clip_text = true
		row.add_child(val)
		rows.append({"label": val, "spec": spec})
		vbox.add_child(row)
	var update := func() -> void:
		for r in rows:
			var lbl: Label = r["label"]
			if not is_instance_valid(lbl):
				return
			var s: Dictionary = r["spec"]
			lbl.text = "%d%s" % [rng.randi_range(int(s["lo"]), int(s["hi"])), String(s["unit"])]
	update.call()
	var timer := Timer.new()
	timer.wait_time = 0.55
	timer.autostart = true
	timer.timeout.connect(update)
	box.add_child(timer)
	return box


## Signal meter: a row of bars with animated heights (drawn each frame).
func _make_meter_widget() -> Control:
	var box := _box(Color(0.3, 0.9, 0.45, 0.6))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	vbox.add_child(_label("▮ SIGNAL", 10, SCREEN_GREEN))
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(0, 42)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(canvas)
	var bar_count := 14
	var cur: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in bar_count:
		cur.append(rng.randf())
	var draw_fn := func() -> void:
		var w := canvas.size.x
		var h := canvas.size.y
		if w <= 0.0 or h <= 0.0:
			return
		var bw := w / float(bar_count)
		for i in bar_count:
			var bh := h * float(cur[i])
			canvas.draw_rect(Rect2(i * bw + 1.0, h - bh, maxf(1.0, bw - 2.0), bh), Color(0.3, 1.0, 0.45, 0.85), true)
	canvas.draw.connect(draw_fn)
	var tick := func() -> void:
		if not is_instance_valid(canvas):
			return
		for i in bar_count:
			cur[i] = clampf(float(cur[i]) + rng.randf_range(-0.55, 0.55), 0.05, 1.0)
		canvas.queue_redraw()
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(tick)
	box.add_child(timer)
	return box


## Fault alert: a red panel with a blinking indicator and a changing error code / retry.
func _make_alert_widget() -> Control:
	var box := _box(ERR_RED)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_label("⚠ FAULT", 12, ERR_RED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	var blink := _label("●", 12, ERR_RED)
	head.add_child(blink)
	vbox.add_child(head)
	var code := _label("code 0x----", 10, SCREEN_DIM)
	vbox.add_child(code)
	var retry := _label("retry 0/5", 10, SCREEN_DIM)
	vbox.add_child(retry)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var state := {"on": true, "n": 0}
	var tick := func() -> void:
		if not is_instance_valid(blink):
			return
		state["on"] = not bool(state["on"])
		blink.modulate = Color(1, 1, 1, 1.0) if bool(state["on"]) else Color(1, 1, 1, 0.15)
		state["n"] = (int(state["n"]) + 1) % 6
		retry.text = "retry %d/5" % int(state["n"])
		code.text = "code 0x%s" % _hex_str(rng, 4)
	tick.call()
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(tick)
	box.add_child(timer)
	return box


## Progress readout: an ASCII bar that fills and resets under a cycling task label.
func _make_progress_widget() -> Control:
	var box := _box(Color(0.3, 0.9, 0.45, 0.6))
	box.clip_contents = true
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	# clip_text: the '#'/'-' bar and the changing title have different pixel widths, so
	# without this the container would resize as the text changes. Clipping keeps it fixed.
	var title := _label("DECRYPTING", 10, SCREEN_GREEN)
	title.clip_text = true
	vbox.add_child(title)
	var bar := _label("[            ] 0%", 10, OK_GREEN)
	bar.clip_text = true
	vbox.add_child(bar)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var verbs := ["DECRYPTING", "COMPILING", "UPLINK", "PATCHING", "SCANNING", "FLASHING"]
	var segs := 12
	var state := {"pct": rng.randi_range(0, 60)}
	var tick := func() -> void:
		if not is_instance_valid(bar):
			return
		var pct := int(state["pct"]) + rng.randi_range(3, 11)
		if pct >= 100:
			pct = 0
			title.text = String(verbs[rng.randi_range(0, verbs.size() - 1)])
		state["pct"] = pct
		var filled := int(round(float(pct) / 100.0 * float(segs)))
		var s := ""
		for i in segs:
			s += ("#" if i < filled else "-")
		bar.text = "[%s] %3d%%" % [s, pct]
	tick.call()
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(tick)
	box.add_child(timer)
	return box


## Scope: a scrolling oscilloscope-style waveform (drawn each frame).
func _make_wave_widget() -> Control:
	var box := _box(Color(0.3, 0.9, 0.45, 0.6))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	vbox.add_child(_label("∿ SCOPE", 10, SCREEN_GREEN))
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(0, 42)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(canvas)
	var phase := [0.0]
	var draw_fn := func() -> void:
		var w := canvas.size.x
		var h := canvas.size.y
		if w <= 2.0 or h <= 0.0:
			return
		var mid := h * 0.5
		# Faint grid behind the trace.
		var gcol := Color(0.3, 0.85, 0.4, 0.22)
		var gx := 0.0
		while gx <= w:
			canvas.draw_line(Vector2(gx, 0.0), Vector2(gx, h), gcol, 1.0)
			gx += 12.0
		var gy := 0.0
		while gy <= h:
			canvas.draw_line(Vector2(0.0, gy), Vector2(w, gy), gcol, 1.0)
			gy += 12.0
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= w:
			var t := x / 22.0 + float(phase[0])
			var y := mid + sin(t) * mid * 0.55 + sin(t * 2.7) * mid * 0.18
			pts.append(Vector2(x, clampf(y, 1.0, h - 1.0)))
			x += 3.0
		if pts.size() >= 2:
			canvas.draw_polyline(pts, Color(0.3, 1.0, 0.45, 0.9), 1.0)
	canvas.draw.connect(draw_fn)
	var tick := func() -> void:
		if not is_instance_valid(canvas):
			return
		phase[0] = float(phase[0]) + 0.45
		canvas.queue_redraw()
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	timer.timeout.connect(tick)
	box.add_child(timer)
	return box


## A rectangular grid panel with a scan line sweeping down it - static hacker-terminal filler.
func _make_grid_widget() -> Control:
	var box := _box(Color(0.3, 0.9, 0.45, 0.6))
	box.clip_contents = true
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(0, 40)
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(canvas)
	var scan := [0.0]
	var draw_fn := func() -> void:
		var w := canvas.size.x
		var h := canvas.size.y
		if w <= 0.0 or h <= 0.0:
			return
		var col := Color(0.3, 0.85, 0.4, 0.3)
		var gx := 0.0
		while gx <= w:
			canvas.draw_line(Vector2(gx, 0.0), Vector2(gx, h), col, 1.0)
			gx += 12.0
		var gy := 0.0
		while gy <= h:
			canvas.draw_line(Vector2(0.0, gy), Vector2(w, gy), col, 1.0)
			gy += 12.0
		var sy := float(scan[0]) * h
		canvas.draw_line(Vector2(0.0, sy), Vector2(w, sy), Color(0.4, 1.0, 0.55, 0.85), 1.0)
	canvas.draw.connect(draw_fn)
	var tick := func() -> void:
		if not is_instance_valid(canvas):
			return
		scan[0] = fmod(float(scan[0]) + 0.02, 1.0)
		canvas.queue_redraw()
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	timer.timeout.connect(tick)
	box.add_child(timer)
	return box


## Radar: a ring with a rotating sweep line and a few blips (drawn each frame).
func _make_radar_widget() -> Control:
	var box := _box(Color(0.3, 0.9, 0.45, 0.6))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	vbox.add_child(_label("◎ RADAR", 10, SCREEN_GREEN))
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(0, 46)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(canvas)
	var angle := [0.0]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var blips: Array = []
	for _i in 4:
		blips.append(Vector2(rng.randf_range(0.0, TAU), rng.randf_range(0.2, 0.95)))
	var dim := Color(0.3, 0.85, 0.4, 0.5)
	var lit := Color(0.35, 1.0, 0.5, 0.95)
	var draw_fn := func() -> void:
		var w := canvas.size.x
		var h := canvas.size.y
		if w <= 4.0 or h <= 4.0:
			return
		var c := Vector2(w * 0.5, h * 0.5)
		var rad := minf(w, h) * 0.5 - 2.0
		canvas.draw_arc(c, rad, 0.0, TAU, 40, dim, 1.0)
		canvas.draw_arc(c, rad * 0.5, 0.0, TAU, 28, dim, 1.0)
		var a: float = float(angle[0])
		canvas.draw_line(c, c + Vector2(cos(a), sin(a)) * rad, lit, 1.0)
		for b in blips:
			var bv: Vector2 = b
			var p := c + Vector2(cos(bv.x), sin(bv.x)) * (bv.y * rad)
			canvas.draw_circle(p, 1.5, lit)
	canvas.draw.connect(draw_fn)
	var tick := func() -> void:
		if not is_instance_valid(canvas):
			return
		angle[0] = fmod(float(angle[0]) + 0.16, TAU)
		if rng.randf() < 0.08:
			blips[rng.randi_range(0, blips.size() - 1)] = Vector2(rng.randf_range(0.0, TAU), rng.randf_range(0.2, 0.95))
		canvas.queue_redraw()
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	timer.timeout.connect(tick)
	box.add_child(timer)
	return box


## A compact scrolling code panel (no scrollbar). Used where code fits better than a widget
## - e.g. the assembly main menu's right side. Does not cycle.
func _make_code_terminal(font_size: int = 9) -> Control:
	var box := _box(Color(0.25, 0.8, 0.4, 0.6))
	box.clip_contents = true
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = false
	rt.scroll_active = true
	rt.scroll_following = true
	rt.fit_content = false
	rt.clip_contents = true
	rt.custom_minimum_size = Vector2(0, 30)
	rt.add_theme_font_size_override("normal_font_size", font_size)
	rt.add_theme_color_override("default_color", Color(0.45, 0.95, 0.5))
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rt)
	_hide_scrollbar(rt)
	var lines: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in 8:
		lines.append("> " + _random_code_line(rng))
	rt.text = "\n".join(lines) + "\n> _"
	var tick := func() -> void:
		if not is_instance_valid(rt):
			return
		lines.append("> " + _random_code_line(rng))
		while lines.size() > 40:
			lines.remove_at(0)
		rt.text = "\n".join(lines) + "\n> _"
	var timer := Timer.new()
	timer.wait_time = rng.randf_range(0.35, 0.7)
	timer.autostart = true
	timer.timeout.connect(tick)
	box.add_child(timer)
	return box


## Makes a RichTextLabel's vertical scrollbar invisible (kept active so auto-follow works).
func _hide_scrollbar(rt: RichTextLabel) -> void:
	var vbar := rt.get_v_scroll_bar()
	if vbar != null:
		vbar.modulate = Color(1, 1, 1, 0)
		vbar.custom_minimum_size = Vector2.ZERO
		vbar.mouse_filter = Control.MOUSE_FILTER_IGNORE


## One varied line of hacker-flavour fake code: a mix of curated flavour and recombined
## hex dumps / pseudo-asm / calls, so the terminals rarely repeat.
func _random_code_line(rng: RandomNumberGenerator) -> String:
	match rng.randi_range(0, 11):
		0, 1, 2:
			return CODE_LINES[rng.randi_range(0, CODE_LINES.size() - 1)]
		3:
			return "0x%s: %s %s %s %s" % [_hex_str(rng, 4), _hex_str(rng, 2), _hex_str(rng, 2), _hex_str(rng, 2), _hex_str(rng, 2)]
		4:
			return "mov r%d, 0x%s" % [rng.randi_range(0, 15), _hex_str(rng, 2)]
		5:
			return "%s.%s(0x%s)" % [_pick(CODE_SYMBOLS, rng), _pick(CODE_VERBS, rng), _hex_str(rng, 4)]
		6:
			return "alloc %db @ 0x%s" % [rng.randi_range(16, 8192), _hex_str(rng, 4)]
		7:
			return "calib %s torque=%.2f" % [_pick(CODE_SYMBOLS, rng), rng.randf_range(0.10, 1.60)]
		8:
			return "%s %s in bus[%d]" % [_pick(CODE_KEYWORDS, rng), _pick(CODE_VERBS, rng), rng.randi_range(0, 31)]
		9:
			return "hash %s %s %s %s" % [_hex_str(rng, 4), _hex_str(rng, 4), _hex_str(rng, 4), _hex_str(rng, 4)]
		10:
			return "verify %s range 0-%ddeg" % [_pick(CODE_SYMBOLS, rng), rng.randi_range(30, 180)]
		_:
			return "%s: %d%% [%s]" % [_pick(CODE_SYMBOLS, rng), rng.randi_range(0, 100), _hex_str(rng, 6)]


func _pick(arr: Array, rng: RandomNumberGenerator) -> String:
	return String(arr[rng.randi_range(0, arr.size() - 1)])


func _hex_str(rng: RandomNumberGenerator, digits: int) -> String:
	var s := ""
	for _i in digits:
		s += HEX_DIGITS[rng.randi_range(0, 15)]
	return s


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
		# A full res:// path is used verbatim (e.g. workshop head textures); a bare name
		# resolves against the icon folder.
		var path := icon_name if icon_name.begins_with("res://") else ICON_DIR + icon_name + ".png"
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
