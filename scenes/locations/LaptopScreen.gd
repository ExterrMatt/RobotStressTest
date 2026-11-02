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
const LIMB_ORDER: Array[String] = ["ARM", "LEG", "CHEST", "STOMACH", "HEAD"]

## Per-limb icon + component checklist. Each component names how to look it up in
## the player's inventory (kind/id); kind "none" is a not-yet-implemented part that
## always reads as missing (leg segments, the head's "ridiculous" features).
const LIMBS: Dictionary = {
	"ARM": {
		"icon": "arm_no_hand",
		"components": [
			{"label": "UPPER ARM", "icon": "upper_arm", "kind": "ingredient", "id": "upper_arm"},
			{"label": "FOREARM", "icon": "forearm", "kind": "ingredient", "id": "forearm"},
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
	# The chest and stomach each scan for the segments the workshop builds them from
	# (see WorkshopMinigame.CRAFTABLE_PARTS), like the arm and leg.
	"CHEST": {
		"icon": "chest",
		"components": [
			{"label": "RIB CAGE", "icon": "ribcage", "kind": "ingredient", "id": "ribcage"},
			{"label": "UPPER PLATING", "icon": "upper_plating", "kind": "ingredient", "id": "upper_plating"},
			{"label": "LOWER PLATING", "icon": "lower_plating", "kind": "ingredient", "id": "lower_plating"},
		],
	},
	"STOMACH": {
		"icon": "torso",
		"components": [
			{"label": "PELVIS", "icon": "pelvis", "kind": "ingredient", "id": "pelvis"},
			{"label": "OUTER PLATING", "icon": "outer_plating", "kind": "ingredient", "id": "outer_plating"},
			# Optional internals: scanned and shown, but not needed to unlock the limb.
			{"label": "TANK", "icon": "tank", "kind": "ingredient", "id": "tank", "optional": true},
			{"label": "PUMP", "icon": "pump", "kind": "ingredient", "id": "pump", "optional": true},
			{"label": "HUGE BATTERY", "icon": "huge_battery", "kind": "ingredient", "id": "huge_battery", "optional": true},
			{"label": "EXTERNAL", "icon": "external", "kind": "ingredient", "id": "external", "optional": true},
		],
	},
	# The hand is its own part (not built into the arm): its scan just checks for a crafted
	# hand. It isn't on the builder's limb-select; its LIMB SCAN is reached from its page.
	"HAND": {
		"icon": "hand",
		"right_art": true,
		"components": [
			{"label": "HAND", "icon": "hand", "kind": "part", "id": "hand"},
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
## The page to boot into instead of the app's top level - a page state as page_changed
## reports it (see _show_page). The desktop uses it to reopen an exact page: going back
## through its history, or returning from a LIMB SCAN.
@export var initial_page: Dictionary = {}

## (Nothing emits this now: the assembly app's button unlocks / locks the limb itself.)
## Emitted by the assembly app's LIMB SCAN button so the host desktop can open the builder
## already scanning `limb_id` (a LIMBS key: "ARM"/"LEG"/"CHEST"/"STOMACH"/"HEAD");
## `origin_page` is the assembly page it was launched from, so back can return exactly there.
signal open_builder_for_limb(limb_id: String, origin_page: Dictionary)
## Emitted when backing out of a maintenance-launched build scan: reopen the maintenance app
## at `page` (the page the LIMB SCAN was pressed on).
signal return_to_maintenance(page: Dictionary)
## Emitted whenever a page is shown, with a state _show_page can rebuild it from. The desktop
## keeps these for its universal back button.
signal page_changed(page: Dictionary)

var _root: Control = null
var _selected_limb: String = ""
## The side being scanned ("LEFT" / "RIGHT") for a paired limb (arm, leg, hand); "" for the
## rest. The scan's checks, unlock and lock all apply to this side only.
var _scan_side: String = ""
## On a scan launched from maintenance, the assembly page to return to when backing out of
## it (so back goes to the very page LIMB SCAN was pressed on, not the limb-select).
var _scan_return_page: Dictionary = {}
## The page on screen now, as page_changed last reported it.
var _current_page: Dictionary = {}
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

	_show_page(initial_page)


## Rebuilds the page a page_changed state describes; an empty or unknown state opens the
## app's top level. States:
##   build:    {"page": "select"}, {"page": "scan", "limb", "side", "return": assembly page or {}}
##   assembly: {"page": "assembly"}, {"page": "side_select", "index"},
##             {"page": "part", "index", "side"}, {"page": "segment", "index", "seg", "side"}
func _show_page(page: Dictionary) -> void:
	var index := int(page.get("index", -1))
	var valid_index := index >= 0 and index < ASSEMBLY_PARTS.size()
	var side := String(page.get("side", ""))
	if app_mode == "assembly":
		var kind := String(page.get("page", "")) if valid_index else ""
		if kind == "side_select":
			_show_assembly_side_select(index)
		elif kind == "part":
			_show_assembly_part(index, side)
		elif kind == "segment":
			var seg := int(page.get("seg", -1))
			if seg >= 0 and seg < (ASSEMBLY_PARTS[index].get("segments", []) as Array).size():
				_show_assembly_segment(index, seg, side)
			else:
				_show_assembly_part(index, side)
		else:
			_show_assembly()
		return
	var limb := String(page.get("limb", ""))
	if String(page.get("page", "")) == "scan" and LIMBS.has(limb):
		# LIMB SCAN entry: jump straight into this limb's scan. One launched from maintenance
		# scans the side its page was opened on.
		_scan_return_page = page.get("return", {})
		_selected_limb = limb
		_show_scan(limb, String(page.get("side", _scan_return_page.get("side", ""))))
	else:
		_show_select()


## Records `page` as the one on screen and tells the desktop.
func _page_shown(page: Dictionary) -> void:
	_current_page = page
	page_changed.emit(page)


# =============================================================================
# BUILD APP - select screen
# =============================================================================

func _show_select() -> void:
	_teardown_terminal()
	_clear_root()
	_scan_return_page = {}
	_page_shown({"page": "select"})

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
	# Measured once it's in the tree, so it uses the laptop's own font.
	_fit_label_width(header, _app_width() - 12.0)

	# Three per row: two rows of limb buttons fit above the taskbar (three rows didn't).
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)

	for limb_id in LIMB_ORDER:
		grid.add_child(_make_limb_button(limb_id))


## A limb tile on the builder's limb-select. A paired limb (arm, leg) is scanned one side at
## a time, so its tile isn't pressable itself: it carries an L and an R button instead.
func _make_limb_button(limb_id: String) -> Button:
	var paired := GameState.is_paired_part(limb_id.to_lower())
	var hot := _panel_style() if paired else _panel_style(Color(0.35, 1.0, 0.5, 0.95))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 74)
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if paired else Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _panel_style())
	btn.add_theme_stylebox_override("hover", hot)
	btn.add_theme_stylebox_override("pressed", hot)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not paired:
		btn.pressed.connect(_on_limb_picked.bind(limb_id, ""))

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

	if paired:
		icon.custom_minimum_size = Vector2(0, 30)
		var sides := HBoxContainer.new()
		sides.alignment = BoxContainer.ALIGNMENT_CENTER
		sides.add_theme_constant_override("separation", 4)
		sides.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sides)
		for side in ["LEFT", "RIGHT"]:
			var side_btn := _small_button(side.left(1))
			side_btn.custom_minimum_size = Vector2(26, 0)
			side_btn.pressed.connect(_on_limb_picked.bind(limb_id, side))
			sides.add_child(side_btn)

	return btn


func _on_limb_picked(limb_id: String, side: String) -> void:
	_selected_limb = limb_id
	_show_scan(limb_id, side)


# =============================================================================
# BUILD APP - scan screen
# =============================================================================

## Scan layout: name + scrolling terminal on the left; the LIMB SCAN checklist (with the
## limb's picture in a square box under it) over the SUMMARY on the right. `side` is the
## side of a paired limb being scanned ("LEFT" / "RIGHT"); ignored for the rest.
func _show_scan(limb_id: String, side: String = "") -> void:
	_teardown_terminal()
	_clear_root()
	_scan_marks.clear()
	_toggle_mode = ""
	_toggle_limb = ""
	_toggle_button = null
	_scan_side = side if GameState.is_paired_part(limb_id.to_lower()) else ""
	_page_shown({"page": "scan", "limb": limb_id, "side": _scan_side, "return": _scan_return_page})

	var columns := _two_column_layout()

	# --- left column: name row + terminal filling the rest ---
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	left.add_theme_constant_override("separation", 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)

	# The limb's name in the same bordered slot as the assembly app's detail pages.
	var title := limb_id if _scan_side == "" else "%s %s" % [_scan_side, limb_id]
	left.add_child(_detail_name_slot(title, _on_scan_back))

	left.add_child(_build_terminal_box())

	# --- right column: scan checklist (top, fills) + summary (bottom) ---
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)

	right.add_child(_build_scan_box(limb_id))
	right.add_child(_build_summary_box(limb_id))


## Limbs with more components than this get the compact checklist (smaller rows), so the
## list and summary still fit the column above the taskbar.
const SCAN_COMPACT_ROWS: int = 3

## Detaching a limb takes SCAN_ANIM_SECONDS: the summary reads "DETACHING" with its dots
## running . .. ... twice, while the checklist re-scans the parts one at a time - each mark
## flickering (SCAN_PENDING_MARK) until its turn, then landing on its tick (or cross). Then
## the limb comes off, and the summary shows the result.
const SCAN_ANIM_SECONDS: float = 1.8
const SCAN_DOT_STEPS: int = 6
const SCAN_FLICKER_SECONDS: float = 0.09
const SCAN_PENDING_MARK: String = "?"
## Each checklist mark sits in a slot this size (by font size) that fits all of ✓, ✗ and
## the pending mark - they're different sizes, and the row mustn't change as they swap.
const SCAN_MARK_SLOT: Dictionary = {11: Vector2(10, 15), 12: Vector2(11, 17)}
## The summary's result line ("SUCCESS ... ATTACHED", or "DETACHING ..." meanwhile), one
## fixed height whatever's on it.
const SUMMARY_RESULT_ROW_HEIGHT: float = 17.0
## During the stress test a limb can only be unlocked or locked again this long after the
## last time; meanwhile its button is darkened with the seconds left showing over it.
const TOGGLE_COOLDOWN_SECONDS: float = 30.0
const TOGGLE_COOLDOWN_TINT: Color = Color(0.4, 0.4, 0.4)
## When each limb can next be detached (Time.get_ticks_msec), kept across laptop
## openings for the night.
static var _toggle_ready_at_ms: Dictionary = {}

## The scan page's checklist marks, [Label, final text, final colour] per row, and its
## summary's contents.
var _scan_marks: Array = []
var _summary_vbox: VBoxContainer = null
## The detach under way: the limb, "detach" ("" when none), seconds in.
var _toggle_limb: String = ""
var _toggle_mode: String = ""
var _toggle_time: float = 0.0
var _toggle_status_label: Label = null
## The DETACH button on screen (the scan summary's, or an assembly page's), the
## countdown over it, and the _toggle_ready_at_ms key it waits on.
var _toggle_button: Button = null
var _toggle_timer_label: Label = null
var _toggle_button_key: String = ""


func _build_scan_box(limb_id: String) -> Control:
	var box := _box()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var comps: Array = LIMBS[limb_id].get("components", [])
	var compact := comps.size() > SCAN_COMPACT_ROWS

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1 if compact else 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)

	var title := _label("LIMB SCAN:", 12, SCREEN_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	# Checklist: [spacer][icon][name][spacer][mark]. The two expanding spacer columns share
	# the slack equally, so the icon+name block sits centred with names left-aligned and every
	# mark pinned to the right edge.
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 0 if compact else 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grid)
	var needed := _scan_needed_count(limb_id)
	for comp in comps:
		_add_component_cells(grid, comp, compact, needed)

	# The limb's picture in its own square sub-box, taking whatever height the list leaves.
	# Hidden when that's too little to read (the long head / stomach lists). The holder is a
	# plain Control and places the square itself, so the box adds no minimum height.
	var art := Control.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)
	var sub := _box(Color(0.3, 0.9, 0.45, 0.6))
	sub.clip_contents = true
	art.add_child(sub)
	var big_icon := TextureRect.new()
	big_icon.texture = _icon_tex(String(LIMBS[limb_id].get("icon", "")))
	big_icon.flip_h = _side_flip(bool(LIMBS[limb_id].get("right_art", false)), _scan_side)
	big_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_child(big_icon)
	art.resized.connect(func() -> void:
		var side := minf(art.size.x, art.size.y)
		sub.visible = side >= 36.0
		sub.size = Vector2(side, side)
		sub.position = (art.size - sub.size) * 0.5)

	return box


## One checklist row's five grid cells (see _build_scan_box). `needed` is how many of the
## component this side's scan wants (see _scan_needed_count).
func _add_component_cells(grid: GridContainer, comp: Dictionary, compact: bool, needed: int = 1) -> void:
	var present := _component_present(comp, needed)

	grid.add_child(_expand_cell())

	var icon_px := 12 if compact else 16
	var icon := TextureRect.new()
	icon.texture = _icon_tex(String(comp.get("icon", "")))
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(icon)

	var optional := bool(comp.get("optional", false))
	var label_text := String(comp.get("label", "?"))
	if optional:
		label_text += " (OPT)"
	grid.add_child(_label(label_text, 10 if compact else 11, SCREEN_DIM if optional else SCREEN_GREEN))

	grid.add_child(_expand_cell())

	# A missing optional component isn't a failure, so it gets a dim mark instead of red.
	var mark_color: Color = OK_GREEN if present else (SCREEN_DIM if optional else ERR_RED)
	var mark_text := "✓" if present else "✗"
	var mark_size := 11 if compact else 12
	var mark := _label(mark_text, mark_size, mark_color)
	mark.custom_minimum_size = SCAN_MARK_SLOT[mark_size]
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid.add_child(mark)
	_scan_marks.append([mark, mark_text, mark_color])


func _expand_cell() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


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

	_summary_vbox = VBoxContainer.new()
	_summary_vbox.add_theme_constant_override("separation", 3)
	_summary_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_summary_vbox)
	_fill_summary(limb_id)
	return box


## (Re)fills the summary: the scan's result, then the button that detaches the limb (greyed
## out while none of it is on her). While a detach is running it reads "DETACHING" instead
## (see SCAN_ANIM_SECONDS).
func _fill_summary(limb_id: String) -> void:
	if _summary_vbox == null or not is_instance_valid(_summary_vbox):
		return
	for child in _summary_vbox.get_children():
		_summary_vbox.remove_child(child)
		child.queue_free()
	_toggle_button = null
	_toggle_status_label = null
	_summary_vbox.add_child(_label("SUMMARY", 16, SCREEN_GREEN))

	if _toggle_mode != "":
		_toggle_status_label = _label("", 13, SCREEN_GREEN)
		_toggle_status_label.custom_minimum_size.y = SUMMARY_RESULT_ROW_HEIGHT
		_summary_vbox.add_child(_toggle_status_label)
		_update_toggle_status()
		# An unseen stand-in for the button keeps the box its height, so the checklist and
		# picture above don't move.
		var hold := _small_button(" ")
		hold.disabled = true
		hold.modulate.a = 0.0
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_summary_vbox.add_child(hold)
		return

	var missing := _missing_components(limb_id, _scan_needed_count(limb_id))
	var attached := GameState.has_detachable(limb_id.to_lower(), _scan_side.to_lower())
	if missing.is_empty():
		# The limb's state shares the result's line, so the box is the same height attached,
		# detached or mid-detach - and the picture above keeps its size.
		var result_row := HBoxContainer.new()
		result_row.custom_minimum_size.y = SUMMARY_RESULT_ROW_HEIGHT
		result_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result_row.add_child(_label("SUCCESS", 13, OK_GREEN))
		result_row.add_child(_expand_cell())
		result_row.add_child(_label("ATTACHED", 11, OK_GREEN) if attached else _label("DETACHED", 11, SCREEN_DIM))
		_summary_vbox.add_child(result_row)
	else:
		_summary_vbox.add_child(_label("FAILURE", 13, ERR_RED))
		# One wrapped line rather than a line per part, so the head's six fit too.
		var missing_label := _label("MISSING: " + ", ".join(missing), 10, ERR_RED)
		missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_summary_vbox.add_child(missing_label)
	_summary_vbox.add_child(_make_detach_button(limb_id, attached))


## The summary's DETACH LIMB button, with a countdown laid over its right end for the stress
## test's cooldown (see TOGGLE_COOLDOWN_SECONDS). Greyed out (does nothing) while none of the
## limb is on her (`attached` false).
func _make_detach_button(limb_id: String, attached: bool) -> Button:
	var btn := _small_button("DETACH LIMB")
	if not attached:
		btn.disabled = true
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		btn.modulate = UNLOCK_UNAVAILABLE_TINT
		return btn
	btn.pressed.connect(_on_detach_pressed.bind(limb_id))
	_track_toggle_button(btn, _scan_key(limb_id))
	return btn


## Lays the cooldown countdown over `btn`'s right end and makes it the button the cooldown
## darkens, waiting on `key` (see TOGGLE_COOLDOWN_SECONDS).
func _track_toggle_button(btn: Button, key: String) -> void:
	var timer := _label("", 11, SCREEN_GREEN)
	timer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timer.offset_right = -6.0
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(timer)
	_toggle_button = btn
	_toggle_timer_label = timer
	_toggle_button_key = key
	_update_toggle_cooldown()


func _on_detach_pressed(limb_id: String) -> void:
	if _toggle_mode != "" or _cooldown_left(_scan_key(limb_id)) > 0.0:
		return
	if _awaiting_detach_confirm(_toggle_button, limb_id.to_lower(), _scan_side.to_lower(), ""):
		return
	_toggle_mode = "detach"
	_toggle_limb = limb_id
	_toggle_time = 0.0
	_fill_summary(limb_id)
	_advance_toggle(0.0)


func _process(delta: float) -> void:
	if _toggle_mode != "":
		_advance_toggle(delta)
	_update_toggle_cooldown()


## Runs the detach: the checklist marks flicker and land one by one, the status
## dots tick over, and at the end the change is made.
func _advance_toggle(delta: float) -> void:
	_toggle_time += delta
	var rows := _scan_marks.size()
	for i in rows:
		var mark: Label = _scan_marks[i][0]
		if not is_instance_valid(mark):
			continue
		var lands_at := SCAN_ANIM_SECONDS * float(i + 1) / float(rows + 1)
		if _toggle_time >= lands_at:
			mark.text = _scan_marks[i][1]
			mark.add_theme_color_override("font_color", _scan_marks[i][2])
			mark.modulate.a = 1.0
		else:
			mark.text = SCAN_PENDING_MARK
			mark.add_theme_color_override("font_color", SCREEN_DIM)
			mark.modulate.a = 1.0 if int(_toggle_time / SCAN_FLICKER_SECONDS) % 2 == 0 else 0.25
	_update_toggle_status()
	if _toggle_time >= SCAN_ANIM_SECONDS:
		_finish_toggle()


func _update_toggle_status() -> void:
	if _toggle_status_label == null or not is_instance_valid(_toggle_status_label):
		return
	var step := mini(int(_toggle_time / (SCAN_ANIM_SECONDS / SCAN_DOT_STEPS)), SCAN_DOT_STEPS - 1)
	var dots := ".".repeat(step % 3 + 1)
	_toggle_status_label.text = "DETACHING " + dots


func _finish_toggle() -> void:
	var limb_id := _toggle_limb
	_toggle_mode = ""
	_toggle_limb = ""
	_unlock_limb(limb_id.to_lower(), _scan_side.to_lower())
	_start_cooldown(_scan_key(limb_id))
	_fill_summary(limb_id)


## Unlocks `side`'s `part_id` limb: whatever of it is on her comes off into the inventory,
## with the sound of it coming away (see _play_detach_sounds).
func _unlock_limb(part_id: String, side: String) -> void:
	var end_piece := not GameState.limb_has_attachments(part_id, side)
	GameState.prepare_limb(GameState.limb_key(part_id, side))
	# A limb only part-built on this side falls apart: its segments drop back in the inventory.
	var dropped := GameState.drop_limb_segments(part_id, side)
	# The one already on the robot (on this side, for a paired limb) comes off to make way
	# for the fresh one - it falls to the floor and goes back in the inventory as a loose part.
	var had_stomach := GameState.get_attached_part_count("stomach") >= 1
	var removed := GameState.detach_robot_part(part_id, side)
	if dropped.is_empty() and removed.is_empty():
		return
	var falls := _segment_fall_sounds(dropped)
	if not removed.is_empty():
		falls.append_array(_fall_sounds(part_id, removed, had_stomach))
	_play_detach_sounds(falls, end_piece, part_id == "hand" or removed.is_empty())


## Seconds before the limb / segment `key` can be detached again (only ever above
## 0 during the stress test).
func _cooldown_left(key: String) -> float:
	if not _in_stress_test():
		return 0.0
	return maxf(0.0, float(int(_toggle_ready_at_ms.get(key, 0)) - Time.get_ticks_msec()) / 1000.0)


## After a detach during the stress test, `key` waits TOGGLE_COOLDOWN_SECONDS.
func _start_cooldown(key: String) -> void:
	if _in_stress_test():
		_toggle_ready_at_ms[key] = Time.get_ticks_msec() + int(TOGGLE_COOLDOWN_SECONDS * 1000.0)


## Darkens the summary's button with the seconds left over it while it's cooling down.
func _update_toggle_cooldown() -> void:
	if _toggle_button == null or not is_instance_valid(_toggle_button):
		return
	var left := _cooldown_left(_toggle_button_key)
	var cooling := left > 0.0
	_toggle_button.disabled = cooling
	_toggle_button.self_modulate = TOGGLE_COOLDOWN_TINT if cooling else Color.WHITE
	if _toggle_timer_label != null and is_instance_valid(_toggle_timer_label):
		_toggle_timer_label.visible = cooling
		_toggle_timer_label.text = "%ds" % ceili(left)


func _in_stress_test() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group("stress_test_scene") != null


## Where the falling-part sounds live, and the gap between a limb's pieces landing.
const FALL_SOUND_DIR: String = "res://assets/sounds/maintenance_fall/"
const FALL_PIECE_DELAY: float = 0.12
## The fall sounds play at half the volume of their files.
const FALL_SOUND_VOLUME_LINEAR: float = 0.5
## A part coming off her plays maintenance's place sounds (Maintenance.LIMB_PLACE_SOUNDS and
## the rest - the same files): its decompress hiss, then for an end piece its metal thunk
## (see _play_detach_sounds).
const DETACH_SOUND_DIR: String = "res://assets/sounds/maintenance_place/"
const DETACH_THUNK_SOUNDS: Array[String] = ["heavy_limb_place_1.mp3", "heavy_limb_place_2.mp3"]
const DETACH_DECOMPRESS_SOUNDS: Array[String] = ["decompress.mp3"]
const DETACH_SMALL_THUNK_SOUNDS: Array[String] = ["small_limb_place_1.mp3", "small_limb_place_2.mp3"]
const DETACH_SMALL_DECOMPRESS_SOUNDS: Array[String] = ["small_decompress.mp3", "small_decompress_2.mp3"]
const DETACH_SOUND_DELAY: float = 0.05
const DETACH_PITCH_VARIATION_PERCENT: int = 10


## The sounds of a detached part hitting the floor: [file in FALL_SOUND_DIR, seconds
## after the first], in order. An arm lands then its forearm; a leg its shin then its
## foot; the head thumps heavily onto a stomach, or softly with none there; the stomach
## falls with however many legs hang from it.
func _fall_sounds(part_id: String, removed: Dictionary, had_stomach: bool) -> Array:
	match part_id:
		"arm":
			return [["arm_fall_%d.mp3" % (1 + randi() % 2), 0.0], ["forearm_fall.mp3", FALL_PIECE_DELAY]]
		"leg":
			return [["shin_fall.mp3", 0.0], ["foot_fall.mp3", FALL_PIECE_DELAY]]
		"hand":
			return [["hand_fall.mp3", 0.0]]
		"head":
			return [["robot_head_thump_heavy.mp3" if had_stomach else "robot_head_thump_soft.mp3", 0.0]]
		"stomach":
			var legs := int(removed.get("leg", 0))
			var file := "robot_stomach_legs_falling_2legs.mp3" if legs >= 2 \
					else ("robot_stomach_legs_falling_1leg.mp3" if legs == 1 else "robot_stomach_else.mp3")
			return [[file, 0.0]]
		"chest":
			return [["robot_stomach_thump.mp3", 0.0]]
	return []


## The sounds of a part-built limb's segments hitting the floor, FALL_PIECE_DELAY apart.
func _segment_fall_sounds(segments: Array[String]) -> Array:
	var out := []
	for segment in segments:
		var file: String
		match segment:
			"upper_arm":
				file = "arm_fall_%d.mp3" % (1 + randi() % 2)
			"forearm":
				file = "forearm_fall.mp3"
			"foot":
				file = "foot_fall.mp3"
			_:
				file = "shin_fall.mp3"
		out.append([file, FALL_PIECE_DELAY * out.size()])
	return out


## Something coming off her lets its air out with a decompress hiss, then DETACH_SOUND_DELAY
## later comes the sound of it coming away: `falls` (see _fall_sounds) when it brings more
## down with it, or for one `end_piece` with nothing hanging from it just the metal thunk
## maintenance plays when a part goes on. `small` picks the small thunk and hiss (a hand or a
## limb segment) over the heavy ones. Thunk and hiss play at a random pitch, as in maintenance.
func _play_detach_sounds(falls: Array, end_piece: bool, small: bool) -> void:
	var hisses: Array[String] = DETACH_SMALL_DECOMPRESS_SOUNDS if small else DETACH_DECOMPRESS_SOUNDS
	_play_sound(DETACH_SOUND_DIR + hisses[randi() % hisses.size()], 0.0, 1.0, _random_detach_pitch())
	if not end_piece:
		_play_fall_entries(falls, DETACH_SOUND_DELAY)
		return
	var thunks: Array[String] = DETACH_SMALL_THUNK_SOUNDS if small else DETACH_THUNK_SOUNDS
	_play_sound(DETACH_SOUND_DIR + thunks[randi() % thunks.size()], DETACH_SOUND_DELAY, 1.0, _random_detach_pitch())


## Up or down by a whole percent, at most DETACH_PITCH_VARIATION_PERCENT.
func _random_detach_pitch() -> float:
	var percent := randi_range(-DETACH_PITCH_VARIATION_PERCENT, DETACH_PITCH_VARIATION_PERCENT)
	return 1.0 + float(percent) / 100.0


## Plays fall sounds ([file in FALL_SOUND_DIR, delay] entries), all `after` seconds later.
func _play_fall_entries(entries: Array, after: float = 0.0) -> void:
	for entry in entries:
		_play_sound(FALL_SOUND_DIR + String(entry[0]), after + float(entry[1]), FALL_SOUND_VOLUME_LINEAR)


## Plays the sound at `path` `delay` seconds from now. The player hangs off the scene root, so
## the sound carries on if the laptop is closed straight after.
func _play_sound(path: String, delay: float, volume_linear: float = 1.0, pitch: float = 1.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var tree := get_tree()
	var play := func() -> void:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = linear_to_db(volume_linear)
		player.pitch_scale = pitch
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
	if delay <= 0.0:
		play.call()
	else:
		tree.create_timer(delay).timeout.connect(play)


# =============================================================================
# ASSEMBLY APP - body-part / segment browser
# =============================================================================

## Arm segments, shared by LEFT ARM and RIGHT ARM (edit here to change both sides at once).
## Each segment's "id" points at a craftable item in WorkshopMinigame.CRAFTABLE_PARTS; the
## recipe shown is looked up live from there (the real source of truth), not stored here.
const _ARM_SEGMENTS: Array = [
	{"name": "UPPER ARM", "icon": "upper_arm", "id": "upper_arm"},
	{"name": "FOREARM", "icon": "forearm", "id": "forearm"},
]

## The body parts shown in the assembly app. Each part has an icon + a list of segments,
## and each segment an "id" of the real craftable item whose recipe it shows. Parts marked
## `sides` (ARM, LEG) first offer LEFT / RIGHT (they share the same segments), then drop into
## the normal (identical) segment view. `build_limb` names the limb the DETACH
## button works on for this part. A part with a `recipe_id` instead of segments (the hand,
## which is crafted straight from ingredients) shows that item's recipe on its own page.
## `right_art` marks a part whose icon is drawn as the RIGHT side, so the side-select mirrors
## its LEFT card instead of its RIGHT one.
const ASSEMBLY_PARTS: Array = [
	{"name": "ARM", "icon": "arm_no_hand", "sides": true, "build_limb": "ARM", "segments": _ARM_SEGMENTS},
	{"name": "HAND", "icon": "hand", "sides": true, "right_art": true, "build_limb": "HAND", "recipe_id": "hand"},
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
	{"name": "CHEST", "icon": "chest", "build_limb": "CHEST", "segments": [
		{"name": "RIB CAGE", "icon": "ribcage", "id": "ribcage"},
		{"name": "UPPER PLATING", "icon": "upper_plating", "id": "upper_plating"},
		{"name": "LOWER PLATING", "icon": "lower_plating", "id": "lower_plating"},
	]},
	{"name": "STOMACH", "icon": "torso", "build_limb": "STOMACH", "segments": [
		# The pelvis is made in the same craft as the outer plating.
		{"name": "PELVIS", "icon": "pelvis", "id": "outer_plating"},
		{"name": "OUTER PLATING", "icon": "outer_plating", "id": "outer_plating"},
		{"name": "TANK", "icon": "tank", "id": "tank"},
		{"name": "PUMP", "icon": "pump", "id": "pump"},
		{"name": "HUGE BATTERY", "icon": "huge_battery", "id": "huge_battery"},
		{"name": "EXTERNAL", "icon": "external", "id": "external"},
	]},
]

## Laptop-context top-level order for the recycled limb menu (three tiles per row).
const ASSEMBLY_LAPTOP_ORDER: Array[String] = ["LEG", "ARM", "HAND", "CHEST", "STOMACH", "HEAD"]
## Laptop-menu tiles that can always be opened. The rest are greyed out until the player
## has that part (in the inventory or on her, whole or part-built).
const ASSEMBLY_LAPTOP_ENABLED: Array[String] = ["HEAD", "CHEST"]

## A part's RECIPE list with at most this many segments shows their names at the DETACH
## button's size (UNLOCK_BUTTON_TITLE_SIZE); longer lists keep the small size to fit.
const LARGE_RECIPE_SEGMENT_MAX: int = 3

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
	_page_shown({"page": "assembly"})

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
			row.add_child(_maintenance_grid_button(i))
			_add_expand_spacer(row, 0.5)
			i += 1
		else:
			row.add_child(_maintenance_grid_button(i))
			row.add_child(_maintenance_grid_button(i + 1))
			i += 2


## A part button for the maintenance grid, greyed out like the laptop's menu tiles.
func _maintenance_grid_button(index: int) -> Button:
	var btn := _make_assembly_part_button(index)
	_grey_out_if_unavailable(btn, index)
	return btn


## Laptop context: the recycled limb-select look — rows of 3 tiles (a short last row is
## centred), in ASSEMBLY_LAPTOP_ORDER. Tiles expand to fill the column width (a third each) so
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
## Parts not in ASSEMBLY_LAPTOP_ENABLED are greyed out and can't be opened.
func _menu_tile(index: int) -> Button:
	var btn := _make_assembly_part_button(index)
	btn.custom_minimum_size = Vector2(0, 70)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_grey_out_if_unavailable(btn, index)
	return btn


## Greys out (and disables) a part button whose part isn't in ASSEMBLY_LAPTOP_ENABLED and
## that the player doesn't have - the same in the laptop and in maintenance.
func _grey_out_if_unavailable(btn: Button, index: int) -> void:
	var part_name := String(ASSEMBLY_PARTS[index].get("name", ""))
	if ASSEMBLY_LAPTOP_ENABLED.has(part_name) or _player_has_part(part_name.to_lower()):
		return
	btn.disabled = true
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
	btn.add_theme_stylebox_override("disabled", _panel_style())
	btn.modulate = UNLOCK_UNAVAILABLE_TINT


## Whether the player has part `part_id`: in the inventory, or on her whole or part-built.
func _player_has_part(part_id: String) -> bool:
	if GameState.get_owned_part_count(part_id) > 0:
		return true
	for side in GameState.PART_SIDES:
		if not GameState.get_limb_segments(part_id, side).is_empty():
			return true
	return false


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
	_page_shown({"page": "side_select", "index": index})
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

	# A prompt, then a card per side, centred in the space below.
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(stack)
	var prompt := _label("SELECT A SIDE", 10, SCREEN_DIM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SIDE_CARD_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(row)
	for side in ["LEFT", "RIGHT"]:
		row.add_child(_side_card(index, side))


## The side-select's cards: SIDE_CARD_SIZE each, SIDE_CARD_GAP apart, the part's picture
## SIDE_ICON_SIZE square in the middle.
const SIDE_CARD_SIZE: Vector2 = Vector2(128, 128)
const SIDE_CARD_GAP: int = 14
const SIDE_ICON_SIZE: float = 60.0
const SIDE_CARD_HOT_BORDER: Color = Color(0.35, 1.0, 0.5, 0.95)
const SIDE_CARD_HOT_FILL: Color = Color(0.03, 0.16, 0.08, 0.75)


## One side's card on the side-select: its letter in the top corner, the part's picture
## (mirrored on the right, so the pair reads like a body), "LEFT ARM" and whether the robot
## has that side's part on right now. It lights up under the mouse; a click opens the part.
## A side with nothing of the part on her is greyed out like the menu tiles.
func _side_card(index: int, side: String) -> Button:
	var part: Dictionary = ASSEMBLY_PARTS[index]
	var part_name := String(part.get("name", "?"))
	var card := Button.new()
	card.custom_minimum_size = SIDE_CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", _panel_style())
	for state in ["hover", "pressed"]:
		var hot := _panel_style(SIDE_CARD_HOT_BORDER)
		hot.bg_color = SIDE_CARD_HOT_FILL
		card.add_theme_stylebox_override(state, hot)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(_show_assembly_part.bind(index, side))

	var left := side == "LEFT"
	var tag := _label(side.left(1), 14, SCREEN_DIM)
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag.offset_left = 7.0
	tag.offset_top = 4.0
	tag.offset_right = -7.0
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(tag)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)

	var icon := TextureRect.new()
	icon.texture = _icon_tex(String(part.get("icon", "")))
	icon.custom_minimum_size = Vector2(SIDE_ICON_SIZE, SIDE_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.flip_h = _side_flip(bool(part.get("right_art", false)), side)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)

	var title := _glow_label("%s %s" % [side, part_name], 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var attached := GameState.is_part_attached_on(part_name.to_lower(), side.to_lower())
	var status := _label("● ATTACHED" if attached else "○ EMPTY", 10, OK_GREEN if attached else SCREEN_DIM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(status)

	# Under the mouse the picture and letter brighten with the border.
	card.draw.connect(func() -> void:
		var hot := card.is_hovered()
		icon.modulate = Color.WHITE if hot else Color(0.78, 0.82, 0.78)
		tag.add_theme_color_override("font_color", OK_GREEN if hot else SCREEN_DIM))

	if not _part_on_side(part_name.to_lower(), side.to_lower()):
		card.disabled = true
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
		card.add_theme_stylebox_override("disabled", _panel_style())
		card.modulate = UNLOCK_UNAVAILABLE_TINT
	return card


## Whether any of part `part_id` is on her on `side`, whole or part-built. A spare in the
## inventory doesn't count - the side is still missing its limb.
func _part_on_side(part_id: String, side: String) -> bool:
	return GameState.is_part_attached_on(part_id, side) \
			or not GameState.get_limb_segments(part_id, side).is_empty()


## One body part: its name slot (top-left) + picture (bottom-left), and RECIPE = its list of
## clickable segments (right), with a DETACH LIMB button pinned at the bottom-right. `side`
## (for ARM) is shown in the header only — the segments are identical on both sides.
func _show_assembly_part(index: int, side: String = "") -> void:
	_teardown_terminal()
	_clear_root()
	_assembly_part_index = index
	_assembly_segment_index = -1
	_page_shown({"page": "part", "index": index, "side": side})
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
	left.add_child(_detail_image_box(String(part.get("icon", "")), shared,
			_side_flip(bool(part.get("right_art", false)), side)))
	var grid := _make_grid_widget()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(grid)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)

	if part.has("recipe_id"):
		# Crafted straight from ingredients: show the recipe itself, DETACH right below it.
		right.add_child(_build_recipe_box(String(part["recipe_id"])))
		right.add_child(_make_unlock_button(index, side, -1, true))
		return

	# The recipe box fills the column above DETACH and its segment buttons share that
	# height, so any number of segments (up to the head's six) fits without running past
	# the taskbar.
	var recipe_box := _box(Color(0.3, 0.9, 0.45, 0.7))
	recipe_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var recipe_vbox := VBoxContainer.new()
	recipe_vbox.add_theme_constant_override("separation", 2)
	recipe_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_box.add_child(recipe_vbox)
	recipe_vbox.add_child(_label("RECIPE", 13, SCREEN_GREEN))
	var segments: Array = part.get("segments", [])
	for si in segments.size():
		var seg: Dictionary = segments[si]
		var seg_btn := _recipe_button(String(seg.get("name", "?")))
		seg_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# A short list has tall buttons, so their names read as big as the button below.
		if segments.size() <= LARGE_RECIPE_SEGMENT_MAX:
			seg_btn.add_theme_font_size_override("font_size", UNLOCK_BUTTON_TITLE_SIZE)
		seg_btn.pressed.connect(_show_assembly_segment.bind(index, si, side))
		recipe_vbox.add_child(seg_btn)
	right.add_child(recipe_box)

	right.add_child(_make_unlock_button(index, side))


## One segment: its name slot (top-left) + picture (bottom-left), and its crafting RECIPE
## (right). Code panel fills the leftover space. `side` is the side its part was opened on,
## so back returns to that same side's part view.
func _show_assembly_segment(part_index: int, seg_index: int, side: String = "") -> void:
	_teardown_terminal()
	_clear_root()
	_assembly_part_index = part_index
	_assembly_segment_index = seg_index
	_page_shown({"page": "segment", "index": part_index, "seg": seg_index, "side": side})
	var part: Dictionary = ASSEMBLY_PARTS[part_index]
	var seg: Dictionary = (part.get("segments", []) as Array)[seg_index]

	var columns := _two_column_layout()

	var shared: Array = [-1, -1]
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)
	left.add_child(_detail_name_slot(String(seg.get("name", "?")), _show_assembly_part.bind(part_index, side)))
	left.add_child(_detail_image_box(String(seg.get("icon", "")), shared))
	var grid := _make_grid_widget()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(grid)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)

	right.add_child(_build_recipe_box(String(seg.get("id", ""))))

	right.add_child(_make_unlock_button(part_index, side, seg_index, true))


# --- assembly helpers ---

## The RECIPE box for one craftable item: a row per ingredient with its quantity.
func _build_recipe_box(item_id: String) -> Control:
	var recipe_box := _box(Color(0.3, 0.9, 0.45, 0.7))
	recipe_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var recipe_vbox := VBoxContainer.new()
	recipe_vbox.add_theme_constant_override("separation", 3)
	recipe_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recipe_box.add_child(recipe_vbox)
	recipe_vbox.add_child(_label("RECIPE", 13, SCREEN_GREEN))
	var recipe: Array = _real_recipe_rows(item_id)
	if recipe.is_empty():
		recipe_vbox.add_child(_label("— no recipe —", 10, SCREEN_DIM))
	else:
		for item in recipe:
			recipe_vbox.add_child(_make_recipe_row(item))
	return recipe_box


## The DETACH button, sat right under the recipe. On a part's page it detaches the whole
## limb on that side (whatever of it is on her comes off into the inventory); on a segment's
## page it does the same for that segment - it and the segments below it (and an arm's hand)
## come off, the ones above stay on. Under a short recipe it fills the rest
## of the column (`fill`); under a segment list, which fills the column itself, it keeps to
## UNLOCK_BUTTON_MIN_HEIGHT. A plain title and corner brackets (UnlockButtonDecor); it
## brightens under the mouse. Unavailable (greyed out, does nothing) where there's nothing
## that can come off her: her head, the segments of a part not built onto her piece by piece
## (only an arm's or a leg's are), and anything not on her right now.
const UNLOCK_BUTTON_MIN_HEIGHT: float = 40.0
const UNLOCK_BUTTON_TITLE_SIZE: int = 16
## Parts that can't be unlocked: her head never comes off (see GameState._keep_head_on).
const NO_UNLOCK_PARTS: Array[String] = ["HEAD"]
const UNLOCK_UNAVAILABLE_TINT: Color = Color(1.0, 1.0, 1.0, 0.35)


func _make_unlock_button(part_index: int, side: String, seg_index: int = -1, fill: bool = false) -> Button:
	var target := _unlock_target(part_index, side, seg_index)
	var available := not target.is_empty() \
			and GameState.has_detachable(String(target[0]), String(target[1]), String(target[2]))
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	btn.custom_minimum_size = Vector2(0, UNLOCK_BUTTON_MIN_HEIGHT)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL if fill else Control.SIZE_SHRINK_BEGIN
	btn.add_theme_stylebox_override("normal", _panel_style())
	btn.add_theme_stylebox_override("disabled", _panel_style())
	for state in ["hover", "pressed"]:
		var hot := _panel_style(SIDE_CARD_HOT_BORDER)
		hot.bg_color = SIDE_CARD_HOT_FILL
		btn.add_theme_stylebox_override(state, hot)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.disabled = not available
	btn.modulate = Color.WHITE if available else UNLOCK_UNAVAILABLE_TINT
	btn.pressed.connect(_on_unlock_button_pressed.bind(part_index, side, seg_index))

	var decor := UnlockButtonDecor.new()
	decor.color = SCREEN_DIM
	decor.hot_color = OK_GREEN
	btn.add_child(decor)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(col)
	var title := _label("DETACH LIMB%s" % (" SEGMENT" if seg_index >= 0 else ""), UNLOCK_BUTTON_TITLE_SIZE, SCREEN_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	btn.set_meta("title", title)
	btn.set_meta("decor", decor)

	btn.draw.connect(func() -> void:
		var hot := btn.is_hovered() and not btn.disabled
		decor.hot = hot
		var colour := OK_GREEN if hot else SCREEN_GREEN
		if btn == _detach_confirm_button:
			colour = ERR_RED
		title.add_theme_color_override("font_color", colour))
	# During the stress test it waits out the cooldown, the seconds left over it.
	if available:
		_track_toggle_button(btn, _unlock_target_key(target))
	return btn


## DETACH on a limb with something still hanging from it (GameState.limb_has_attachments)
## asks first: the button turns red and reads DETACH_CONFIRM_TEXT, and only a second press of
## it goes ahead. It goes back to normal once the mouse leaves it. An end piece (a hand, a
## foot, or whatever is last on its limb now) comes off on the first press.
const DETACH_CONFIRM_TEXT: String = "CONFIRM DETACH"
const DETACH_CONFIRM_BORDER: Color = Color(1.0, 0.35, 0.32, 0.95)
const DETACH_CONFIRM_FILL: Color = Color(0.2, 0.03, 0.03, 0.75)
const DETACH_CONFIRM_STATES: Array[String] = ["normal", "hover", "pressed"]
const DETACH_CONFIRM_FONT_COLOURS: Array[String] = ["font_color", "font_hover_color", "font_pressed_color"]
## The button asking for the confirm, null when none is.
var _detach_confirm_button: Button = null


## Whether the DETACH press on `btn` (for `side`'s `part_id` limb, or only its `segment`)
## has to wait for a confirm - if so `btn` now asks for it. A press while it's asking is the
## confirm.
func _awaiting_detach_confirm(btn: Button, part_id: String, side: String, segment: String) -> bool:
	if btn == null or not is_instance_valid(btn):
		return false
	if btn == _detach_confirm_button:
		_detach_confirm_button = null
		_show_detach_confirm(btn, false)
		return false
	if not GameState.limb_has_attachments(part_id, side, segment):
		return false
	_detach_confirm_button = btn
	_show_detach_confirm(btn, true)
	var on_exit := _on_detach_confirm_mouse_exited.bind(btn)
	if not btn.mouse_exited.is_connected(on_exit):
		btn.mouse_exited.connect(on_exit, CONNECT_ONE_SHOT)
	return true


func _on_detach_confirm_mouse_exited(btn: Button) -> void:
	if btn != _detach_confirm_button:
		return
	_detach_confirm_button = null
	if is_instance_valid(btn):
		_show_detach_confirm(btn, false)


## Turns `btn` red with DETACH_CONFIRM_TEXT on it (`on`), or back to how it was. Works on the
## summary's plain button and on an assembly page's (its "title" label and "decor" trim).
func _show_detach_confirm(btn: Button, on: bool) -> void:
	var title := btn.get_meta("title", null) as Label
	var decor := btn.get_meta("decor", null) as UnlockButtonDecor
	if not btn.has_meta("detach_look"):
		var saved := {"text": btn.text, "title": title.text if title != null else ""}
		for state in DETACH_CONFIRM_STATES:
			saved[state] = btn.get_theme_stylebox(state)
		for colour in DETACH_CONFIRM_FONT_COLOURS:
			saved[colour] = btn.get_theme_color(colour)
		if decor != null:
			saved["decor"] = [decor.color, decor.hot_color]
		btn.set_meta("detach_look", saved)
	var look: Dictionary = btn.get_meta("detach_look")
	for state in DETACH_CONFIRM_STATES:
		var red := _panel_style(DETACH_CONFIRM_BORDER)
		red.bg_color = DETACH_CONFIRM_FILL
		btn.add_theme_stylebox_override(state, red if on else look[state])
	for colour in DETACH_CONFIRM_FONT_COLOURS:
		btn.add_theme_color_override(colour, ERR_RED if on else look[colour])
	if btn.text != "" or String(look["text"]) != "":
		btn.text = DETACH_CONFIRM_TEXT if on else String(look["text"])
	if title != null:
		title.text = DETACH_CONFIRM_TEXT if on else String(look["title"])
	if decor != null:
		decor.color = ERR_RED if on else look["decor"][0]
		decor.hot_color = ERR_RED if on else look["decor"][1]
		decor.queue_redraw()
	btn.queue_redraw()


## The DETACH button's trim: an L-shaped bracket in each corner, brighter while `hot`
## (hovered).
class UnlockButtonDecor extends Control:
	const BRACKET_LENGTH: float = 6.0
	const INSET: float = 4.0
	var hot: bool = false:
		set(value):
			if hot != value:
				hot = value
				queue_redraw()
	var color: Color = Color.WHITE
	var hot_color: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var c := hot_color if hot else color
		var box := Rect2(Vector2.ONE * INSET, size - Vector2.ONE * INSET * 2.0)
		if box.size.x <= BRACKET_LENGTH * 2.0 or box.size.y <= BRACKET_LENGTH * 2.0:
			return
		for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
			var along_x := BRACKET_LENGTH if corner.x == box.position.x else -BRACKET_LENGTH
			var along_y := BRACKET_LENGTH if corner.y == box.position.y else -BRACKET_LENGTH
			draw_line(corner, corner + Vector2(along_x, 0.0), c, 1.0)
			draw_line(corner, corner + Vector2(0.0, along_y), c, 1.0)


## What a page's DETACH button works on: [part id, side, segment id - "" for the whole
## limb], or [] when there's nothing it can (see _make_unlock_button). `side` is the page's
## ("LEFT" / "RIGHT", "" for an unpaired part).
func _unlock_target(part_index: int, side: String, seg_index: int) -> Array:
	var part: Dictionary = ASSEMBLY_PARTS[part_index]
	var limb := String(part.get("build_limb", ""))
	if limb == "" or NO_UNLOCK_PARTS.has(limb):
		return []
	var part_id := limb.to_lower()
	if seg_index < 0:
		return [part_id, side.to_lower(), ""]
	var segments: Array = part.get("segments", [])
	var seg_id := String(segments[seg_index].get("id", "")) if seg_index < segments.size() else ""
	if GameState.limb_for_segment(seg_id) != part_id:
		return []
	return [part_id, side.to_lower(), seg_id]


## The target's _toggle_ready_at_ms key: the limb's (as the scan's) or the segment's.
func _unlock_target_key(target: Array) -> String:
	if String(target[2]) == "":
		return GameState.limb_key(target[0], target[1])
	return GameState.segment_key(target[0], target[1], target[2])


## DETACH pressed: takes it off her straight away (falling parts and all), then redraws the
## page with the button's new state.
func _on_unlock_button_pressed(part_index: int, side: String, seg_index: int) -> void:
	var target := _unlock_target(part_index, side, seg_index)
	if target.is_empty() or _cooldown_left(_unlock_target_key(target)) > 0.0:
		return
	var part_id := String(target[0])
	var s := String(target[1])
	var segment := String(target[2])
	if not GameState.has_detachable(part_id, s, segment):
		return
	if _awaiting_detach_confirm(_toggle_button, part_id, s, segment):
		return
	if segment == "":
		_unlock_limb(part_id, s)
	else:
		var end_piece := not GameState.limb_has_attachments(part_id, s, segment)
		var removed := GameState.unlock_limb_segment(part_id, s, segment)
		if not removed.is_empty():
			var dropped: Array[String] = []
			dropped.assign(removed.get("segments", []))
			var sounds := _segment_fall_sounds(dropped)
			if removed.has("hand"):
				sounds.append(["hand_fall.mp3", FALL_PIECE_DELAY * sounds.size()])
			_play_detach_sounds(sounds, end_piece, true)
	_start_cooldown(_unlock_target_key(target))
	_show_page(_current_page)


## Scan back: return to the exact maintenance page the scan was launched from (the part,
## side or segment view), otherwise fall back to the builder's own limb-select.
func _on_scan_back() -> void:
	if not _scan_return_page.is_empty():
		return_to_maintenance.emit(_scan_return_page)
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
			# A paired limb's id carries its side ("arm_left" reads LEFT ARM).
			var key_parts := String(limb_key).split("_")
			var limb_name := String(limb_key)
			var side_name := ""
			if key_parts.size() == 2 and key_parts[1] in GameState.PART_SIDES:
				limb_name = key_parts[0]
				side_name = key_parts[1].to_upper() + " "
			var prep_row := HBoxContainer.new()
			prep_row.add_theme_constant_override("separation", 4)
			prep_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pic := TextureRect.new()
			pic.texture = _icon_tex(String(LIMBS.get(limb_name.to_upper(), {}).get("icon", "")))
			pic.custom_minimum_size = Vector2(18, 18)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			prep_row.add_child(pic)
			prep_row.add_child(_label(side_name + limb_name.to_upper(), 11, SCREEN_GREEN))
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


## Side of a detail view's square picture box (and the height of the widget beside it).
const DETAIL_ART_SIZE: float = 100.0


## The top block of a detail view's left column: a fixed SQUARE icon container (hard-left)
## and, as its own separate container beside it, a cycling widget (slot 0 of `shared`).
## `flip` mirrors the picture (the other side of a paired part).
func _detail_image_box(icon_name: String, shared: Array, flip: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Square icon container - fixed size so it stays square and never moves. Sized so the
	# widget beside it gets ~70px, enough for every widget type's text.
	var img_box := _box(Color(0.3, 0.9, 0.45, 0.6))
	img_box.custom_minimum_size = Vector2(DETAIL_ART_SIZE, DETAIL_ART_SIZE)
	img_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	img_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	img_box.clip_contents = true
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img_box.add_child(center)
	var pic := TextureRect.new()
	pic.texture = _icon_tex(icon_name)
	pic.flip_h = flip
	pic.custom_minimum_size = Vector2(DETAIL_ART_SIZE - 16, DETAIL_ART_SIZE - 16)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(pic)
	row.add_child(img_box)

	# Its own separate container beside it: fixed height, fills the remaining width.
	var widget := _make_filler_widget(shared, 0)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	widget.custom_minimum_size = Vector2(0, DETAIL_ART_SIZE)
	row.add_child(widget)
	return row


## An assembly part button (expand-fill): the icon fills the whole button, centred on its
## visible pixels, with the name pinned to the top-left over it. ARM / LEG parts route through
## the LEFT/RIGHT side-select first; the rest go straight to their segment view.
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

	var icon := TextureRect.new()
	icon.texture = _trimmed_tex(_icon_tex(String(part.get("icon", ""))))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	btn.add_child(icon)

	# Added after the icon so it draws on top; the outline keeps it readable over the sprite.
	var name_label := _label(String(part.get("name", "?")), 16, SCREEN_GREEN)
	name_label.add_theme_color_override("font_outline_color", PANEL_FILL)
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.position = Vector2(6, 3)
	btn.add_child(name_label)
	# Narrow tiles (the laptop's 3-wide row) would let long names like STOMACH run past the
	# border, so step the size down only as far as the tile needs.
	btn.resized.connect(func() -> void:
		var font := name_label.get_theme_font("font")
		var size := 16
		while size > 8 and font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > btn.size.x - 12:
			size -= 1
		name_label.add_theme_font_size_override("font_size", size))
	return btn


## Cache for _trimmed_tex, keyed by the source texture's resource path.
var _trimmed_cache: Dictionary = {}


## `tex` cropped to its non-transparent pixels, so KEEP_ASPECT_CENTERED centres what you
## actually see rather than the art's padding (e.g. the arm icon, which is empty where its
## hand used to be). Falls back to `tex` if its pixels can't be read.
func _trimmed_tex(tex: Texture2D) -> Texture2D:
	if tex == null:
		return tex
	var key := tex.resource_path
	if key != "" and _trimmed_cache.has(key):
		return _trimmed_cache[key]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var out: Texture2D = tex
	if used.size.x > 0 and used.size.y > 0 and used.size != img.get_size():
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(used)
		out = atlas
	if key != "":
		_trimmed_cache[key] = out
	return out


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
##
## The slot is a plain Control (not a Container), so its minimum size is only what the caller
## sets: the widgets differ in natural width, and a Container slot would pass that up and
## resize the surrounding columns every time the widget swapped.
func _make_filler_widget(shared: Array = [], my_slot: int = 0) -> Control:
	var slot := Control.new()
	slot.clip_contents = true
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


## Builds widget type `t` sized to fill its filler slot.
func _widget_for_type(t: int) -> Control:
	var w: Control
	match t:
		0:
			w = _make_status_widget()
		1:
			w = _make_meter_widget()
		2:
			w = _make_progress_widget()
		3:
			w = _make_wave_widget()
		_:
			w = _make_alert_widget()
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return w


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
		# Fixed width, so the ticking value is shown in full without the row resizing.
		var val := _label("--", 9, SCREEN_GREEN)
		val.clip_text = true
		val.custom_minimum_size = Vector2(28, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	# Small minimum so the detail views' left column (title, picture, then this) always fits
	# above the taskbar; it grows into whatever height is left.
	canvas.custom_minimum_size = Vector2(0, 24)
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


## Whether the player has `needed` of `comp` (cosmetics are owned or not, so just one).
func _component_present(comp: Dictionary, needed: int = 1) -> bool:
	match String(comp.get("kind", "none")):
		"part":
			return GameState.get_owned_part_count(String(comp.get("id", ""))) >= needed
		"ingredient":
			return int(GameState.ingredients.get(String(comp.get("id", "")), 0)) >= needed
		"cosmetic":
			return GameState.has_cosmetic_item(String(comp.get("id", "")))
		"cosmetic_any":
			for id in comp.get("ids", []):
				if GameState.has_cosmetic_item(String(id)):
					return true
			return false
		_:
			return false


func _missing_components(limb_id: String, needed: int = 1) -> Array[String]:
	var missing: Array[String] = []
	for comp in LIMBS.get(limb_id, {}).get("components", []):
		if not bool(comp.get("optional", false)) and not _component_present(comp, needed):
			missing.append(String(comp.get("label", "?")))
	return missing


## The prepared_limbs id the scan works on: the limb plus its side for a paired one.
func _scan_key(limb_id: String) -> String:
	return GameState.limb_key(limb_id.to_lower(), _scan_side.to_lower())


## How many of each component a scan of `limb_id` on _scan_side needs: one for this side,
## plus one for the other side if that's already been unlocked (its parts are spoken for),
## so both sides of a pair can't pass on a single set of parts.
func _scan_needed_count(limb_id: String) -> int:
	var part_id := limb_id.to_lower()
	if _scan_side == "" or not GameState.is_paired_part(part_id):
		return 1
	var needed := 1
	for side in GameState.PART_SIDES:
		if side != _scan_side.to_lower() and GameState.is_limb_prepared(GameState.limb_key(part_id, side)):
			needed += 1
	return needed


## Whether a paired part's picture is mirrored for `side` ("LEFT" / "RIGHT"; "" never is).
## Art drawn as the left side is mirrored for the right, and art drawn as the right side
## (`right_art`, e.g. the hand) for the left.
func _side_flip(right_art: bool, side: String) -> bool:
	if side == "":
		return false
	return (side == "LEFT") == right_art


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


## Shrinks a label's font until its text fits `max_width`, so a long line never runs off
## the side of the screen.
func _fit_label_width(label: Label, max_width: float) -> void:
	var font: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	while size > 8 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	label.add_theme_font_size_override("font_size", size)


## The app's width on screen (the laptop app area is 370 wide once laid out).
func _app_width() -> float:
	return _root.size.x if _root != null and _root.size.x > 0.0 else 370.0


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
