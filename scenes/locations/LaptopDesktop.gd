extends Control
class_name LaptopDesktop
## The laptop's tiny "OS": a desktop of app icons over a taskbar, hosted inside the
## laptop screen region. Clicking an icon swaps the desktop for that app; the taskbar's
## HOME button returns to the desktop. Closing the laptop itself is still the shell's job
## (the LEAVE button, or clicking off the laptop in overlay mode).
##
## Apps:
##   MAINTENANCE - the READ-ONLY recipe browser (LaptopScreen in "assembly" mode): you can
##                 only look at recipes here, no equipping or unlocking.
##   BUILDER     - the limb scanner / prepare tool (LaptopScreen in "build" mode), kept so
##                 the unlock path stays reachable.
##   THOUGHTS    - a live monitor of the robot's inner thoughts (ThoughtsApp).

const LAPTOP_SCREEN_SCENE: PackedScene = preload("res://scenes/locations/LaptopScreen.tscn")
const ICON_DIR: String = "res://assets/textures/icons/"
const PLACEHOLDER_ICON: String = "res://assets/textures/icons/placeholder_item.png"

const GREEN: Color = Color(0.6, 1.0, 0.62)
const DIM: Color = Color(0.4, 0.72, 0.45)
const BORDER: Color = Color(0.2, 0.85, 0.4, 0.75)
const FILL: Color = Color(0.0, 0.04, 0.02, 0.55)
const DESKTOP_BG: Color = Color(0.02, 0.06, 0.03, 1.0)

## The app catalog. `mode` is the LaptopScreen app_mode; "" means a native desktop app
## dispatched by id in _instantiate_app.
const APPS: Array = [
	{"id": "maintenance", "name": "MAINTENANCE", "icon": "screwdriver", "mode": "assembly"},
	{"id": "builder", "name": "BUILDER", "icon": "gear", "mode": "build"},
	{"id": "delivery", "name": "DELIVERY", "icon": "store_example", "mode": ""},
	{"id": "thoughts", "name": "THOUGHTS", "icon": "brain", "mode": ""},
	{"id": "drone", "name": "PATROL", "icon": "res://assets/textures/characters/drone/drone.png", "mode": ""},
	{"id": "history", "name": "STRESS LOG", "icon": "tesseract", "mode": ""},
	{"id": "profile", "name": "IDENTITY", "icon": "head", "mode": ""},
	{"id": "save", "name": "SAVE", "icon": "battery", "mode": ""},
]

const PHASE_NAMES: Array[String] = ["MORNING", "EVENING", "NIGHT"]

## Where this desktop is hosted, which decides the root screen:
##   "maintenance" / "laptop" - a restricted two-button root ([MAINTENANCE] [SETTINGS]);
##   "admin"                   - the full app grid (debug Shift+Tab "Open Laptop").
## Set by the Laptop shell before this node enters the tree.
var context: String = "laptop"

var _content: Control = null
var _home_btn: Button = null
var _title_label: Label = null
var _clock_label: Label = null
var _open_app_id: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Desktop wallpaper.
	var bg := ColorRect.new()
	bg.color = DESKTOP_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	# App area (fills) + taskbar (fixed strip at the bottom).
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_content)
	col.add_child(_build_taskbar())

	_show_desktop()

	# Keep the clock's day/phase readout live.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_clock)
	add_child(timer)


# =============================================================================
# DESKTOP
# =============================================================================

## The context root: HOME lands here. Admin gets the full app grid; the restricted
## contexts (maintenance / laptop) get the two-button [MAINTENANCE] [SETTINGS] menu.
func _show_desktop() -> void:
	_open_app_id = ""
	_clear_content()
	if _home_btn != null:
		_home_btn.disabled = true
	if _title_label != null:
		_title_label.text = "DESKTOP"
	if context == "admin":
		_build_app_grid()
	else:
		_build_root_menu()


## The retro-desktop root for the maintenance / laptop contexts. Laptop also gets the STORE;
## maintenance stays maintenance + settings only.
func _build_root_menu() -> void:
	var entries: Array = [
		{"label": "MAINTENANCE", "icon": "screwdriver", "action": _open_maintenance},
	]
	if context == "laptop":
		entries.append({"label": "STORE", "icon": "store_example", "action": _open_store})
	entries.append({"label": "SETTINGS", "icon": "gear", "action": _show_settings_menu})
	_build_desktop_content("HOME", entries)


## The SETTINGS sub-menu: identity + save only. Reached from the root; HOME returns to root.
func _show_settings_menu() -> void:
	_open_app_id = "settings"
	_clear_content()
	if _home_btn != null:
		_home_btn.disabled = false
	_build_desktop_content("SETTINGS", [
		{"label": "IDENTITY", "icon": "head", "action": func(): _open_app_control("IDENTITY", ProfileApp.new())},
		{"label": "SAVE", "icon": "battery", "action": func(): _open_app_control("SAVE", SaveApp.new())},
	])


## The online store (DeliveryApp) — laptop scene only.
func _open_store() -> void:
	_open_app_control("STORE", DeliveryApp.new())


## Lays out a retro-terminal "desktop": a branded header + divider up top, the app tiles
## centered in the middle, and a faux shell prompt along the bottom.
func _build_desktop_content(title: String, entries: Array) -> void:
	if _title_label != null:
		_title_label.text = title

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# --- header ---
	col.add_child(_label("R O B O · O S   v0.2", 18, GREEN))
	col.add_child(_label("> %s session — select a module" % title.to_lower(), 10, DIM))
	var divider := ColorRect.new()
	divider.color = BORDER
	divider.custom_minimum_size = Vector2(0, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(divider)

	# --- app tiles, centered in the leftover space ---
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	for entry in entries:
		row.add_child(_make_menu_button(
			String(entry.get("label", "")), String(entry.get("icon", "")), entry["action"]))

	# --- faux shell prompt ---
	col.add_child(_label("guest@robo:~$ _", 10, DIM))


## A recycled desktop-style icon button (icon over label) wired to an arbitrary callable.
func _make_menu_button(label: String, icon_name: String, action: Callable) -> Button:
	var btn := _make_icon({"id": "", "name": label, "icon": icon_name})
	btn.custom_minimum_size = Vector2(96, 78)
	# _make_icon wired an _open_app to the (empty) id; replace it with our action.
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(action)
	return btn


## The full app grid (admin context only).
func _build_app_grid() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Center the grid within the desktop.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	center.add_child(grid)

	for app in APPS:
		grid.add_child(_make_icon(app))


func _make_icon(app: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 60)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _panel_style())
	btn.add_theme_stylebox_override("hover", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_open_app.bind(String(app["id"])))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(box)

	var icon := TextureRect.new()
	icon.texture = LaptopUI.icon_tex(String(app.get("icon", "")))
	icon.custom_minimum_size = Vector2(0, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_label := _label(String(app.get("name", "?")), 10, GREEN)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return btn


# =============================================================================
# APPS
# =============================================================================

func _open_app(app_id: String) -> void:
	var app := _app_by_id(app_id)
	if app.is_empty():
		return
	_open_app_id = app_id
	_clear_content()
	if _home_btn != null:
		_home_btn.disabled = false
	if _title_label != null:
		_title_label.text = String(app.get("name", "APP"))

	var node: Control = _instantiate_app(app)
	if node == null:
		_show_desktop()
		return
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(node)


## Builds the app's root control. LaptopScreen-backed apps ("build"/"assembly") reuse the
## existing screen; the rest are native desktop controls dispatched by id.
func _instantiate_app(app: Dictionary) -> Control:
	var mode := String(app.get("mode", ""))
	if mode != "":
		return _make_screen(mode)
	match String(app.get("id", "")):
		"thoughts": return ThoughtsApp.new()
		"delivery": return DeliveryApp.new()
		"profile": return ProfileApp.new()
		"drone": return DroneApp.new()
		"history": return StressHistoryApp.new()
		"save": return SaveApp.new()
	return null


## A LaptopScreen in the given app mode, carrying this desktop's context and wired so its
## assembly LIMB SCAN button opens the builder here.
func _make_screen(mode: String) -> LaptopScreen:
	var screen := LAPTOP_SCREEN_SCENE.instantiate() as LaptopScreen
	if screen == null:
		return null
	screen.app_mode = mode
	screen.desktop_context = context
	if not screen.open_builder_for_limb.is_connected(_open_builder):
		screen.open_builder_for_limb.connect(_open_builder)
	if not screen.return_to_maintenance.is_connected(_open_maintenance_at):
		screen.return_to_maintenance.connect(_open_maintenance_at)
	return screen


## Swaps `node` into the content area as a titled app (enables HOME, sets the title).
func _open_app_control(title: String, node: Control) -> void:
	_open_app_id = title.to_lower()
	_clear_content()
	if _home_btn != null:
		_home_btn.disabled = false
	if _title_label != null:
		_title_label.text = title
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(node)


## Root-menu MAINTENANCE button: the assembly app (context-styled top-level picker).
func _open_maintenance() -> void:
	var screen := _make_screen("assembly")
	if screen != null:
		_open_app_control("MAINTENANCE", screen)


## Reopen the maintenance app already at a given part's view (used when backing out of a
## LIMB SCAN so you land on the limb you came from, not the top-level picker).
func _open_maintenance_at(part_name: String) -> void:
	var screen := _make_screen("assembly")
	if screen != null:
		screen.initial_assembly_part = part_name
		_open_app_control("MAINTENANCE", screen)


## LIMB SCAN target: the builder, booted straight into `limb`'s scan; `origin_part` is the
## assembly part it was launched from, so the scan's back button returns there.
func _open_builder(limb: String, origin_part: String = "") -> void:
	var screen := _make_screen("build")
	if screen != null:
		screen.initial_build_limb = limb
		screen.builder_return_part = origin_part
		_open_app_control("BUILDER", screen)


# =============================================================================
# TASKBAR
# =============================================================================

func _build_taskbar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.09, 0.05, 0.95)
	sb.border_color = BORDER
	sb.border_width_top = 1
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	bar.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	# HOME: returns to the desktop from an app (disabled while already on the desktop).
	_home_btn = Button.new()
	_home_btn.text = "▚ HOME"
	_home_btn.focus_mode = Control.FOCUS_NONE
	_home_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_home_btn.add_theme_font_size_override("font_size", 10)
	_home_btn.add_theme_color_override("font_color", GREEN)
	_home_btn.add_theme_color_override("font_hover_color", Color(0.45, 1.0, 0.55))
	_home_btn.add_theme_color_override("font_disabled_color", DIM)
	_home_btn.add_theme_stylebox_override("normal", _panel_style())
	_home_btn.add_theme_stylebox_override("hover", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	_home_btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.35, 1.0, 0.5, 0.95)))
	_home_btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.2, 0.45, 0.28, 0.5)))
	_home_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_home_btn.pressed.connect(_show_desktop)
	row.add_child(_home_btn)

	_title_label = _label("DESKTOP", 10, GREEN)
	row.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_clock_label = _label("", 10, DIM)
	row.add_child(_clock_label)
	_refresh_clock()
	return bar


func _refresh_clock() -> void:
	if _clock_label == null or not is_instance_valid(_clock_label):
		return
	var phase: int = clampi(int(GameState.phase), 0, PHASE_NAMES.size() - 1)
	_clock_label.text = "DAY %d · %s" % [int(GameState.day), PHASE_NAMES[phase]]


# =============================================================================
# HELPERS
# =============================================================================

func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _app_by_id(app_id: String) -> Dictionary:
	for app in APPS:
		if String(app.get("id", "")) == app_id:
			return app
	return {}


func _icon_tex(icon_name: String) -> Texture2D:
	if icon_name != "":
		var path := ICON_DIR + icon_name + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return load(PLACEHOLDER_ICON) as Texture2D


func _label(text: String, size: int = 12, color: Color = GREEN) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style(border: Color = BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FILL
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 6
	sb.content_margin_top = 5
	sb.content_margin_right = 6
	sb.content_margin_bottom = 5
	return sb
