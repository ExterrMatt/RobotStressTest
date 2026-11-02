extends Control
class_name LaptopDesktop
## The laptop's tiny "OS": a home screen of module tiles (LaptopHome) over a taskbar, hosted
## inside the laptop screen region. Clicking a tile swaps the home screen for that app; the
## taskbar's HOME button returns to it. Closing the laptop itself is still the shell's job
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
	{"id": "maintenance", "name": "MAINTENANCE", "icon": "screwdriver", "mode": "assembly",
			"desc": "browse limb recipes"},
	{"id": "builder", "name": "BUILDER", "icon": "gear", "mode": "build",
			"desc": "scan and unlock limbs"},
	{"id": "delivery", "name": "DELIVERY", "icon": "store_example", "mode": "",
			"desc": "order supplies for delivery"},
	{"id": "thoughts", "name": "THOUGHTS", "icon": "brain", "mode": "",
			"desc": "the robot's inner thoughts"},
	{"id": "drone", "name": "PATROL", "icon": "res://assets/textures/characters/drone/drone.png", "mode": "",
			"desc": "live feed from the patrol drone"},
	{"id": "history", "name": "STRESS LOG", "icon": "tesseract", "mode": "",
			"desc": "past stress test results"},
	{"id": "profile", "name": "IDENTITY", "icon": "head", "mode": "",
			"desc": "change your name"},
	{"id": "save", "name": "SAVE", "icon": "battery", "mode": "",
			"desc": "save your progress"},
]

const PHASE_NAMES: Array[String] = ["MORNING", "EVENING", "NIGHT"]

## The taskbar's HOME button: centred in the bar (22 tall), "HOME" in its middle with the
## home symbol at each end, HOME_MARK_INSET in from the edge. The symbol (two squares
## corner to corner, like ▚) is drawn rather than typed, so it fits inside the button:
## each square HOME_MARK_SQUARE across.
const HOME_BUTTON_SIZE: Vector2 = Vector2(150, 16)
const HOME_BUTTON_FONT_SIZE: int = 13
const HOME_MARK_SQUARE: float = 4.0
const HOME_MARK_INSET: float = 8.0
const HOME_HOVER_COLOR: Color = Color(0.45, 1.0, 0.55)
## The BACK and FULLSCREEN buttons either side of HOME, NAV_BUTTON_GAP from it, each with
## its symbol drawn NAV_ICON_SIZE across in its middle.
const NAV_BUTTON_SIZE: Vector2 = Vector2(22, 16)
const NAV_BUTTON_GAP: int = 4
const NAV_ICON_SIZE: float = 8.0

## How many earlier pages BACK remembers (the oldest drop off first).
const HISTORY_LIMIT: int = 10

## FULLSCREEN pressed: the host laptop zooms its screen to fill the display (or back out).
signal fullscreen_toggle_requested

## Where this desktop is hosted, which decides the root screen:
##   "maintenance" / "laptop" - a restricted two-button root ([MAINTENANCE] [SETTINGS]);
##   "stresstest"              - [MAINTENANCE] [PATROL] [STORE] (the stress test's laptop);
##   "admin"                   - the full app grid (debug Shift+Tab "Open Laptop").
## Set by the Laptop shell before this node enters the tree.
var context: String = "laptop"
## Whether the host can go fullscreen (the Laptop shell); without it the FULLSCREEN button
## is hidden, its space kept so HOME stays centred. Set before this node enters the tree.
var fullscreen_supported: bool = false
## Whether the host is fullscreen now, which flips the FULLSCREEN symbol to "shrink".
var fullscreen_active: bool = false:
	set(value):
		fullscreen_active = value
		if _fullscreen_btn != null:
			_fullscreen_btn.queue_redraw()

var _content: Control = null
var _home_btn: Button = null
var _back_btn: Button = null
var _fullscreen_btn: Button = null
var _title_label: Label = null
var _clock_label: Label = null
var _open_app_id: String = ""

## Universal BACK: the pages visited before this one, oldest first, as
## {"key": String, "open": Callable} (calling `open` rebuilds that page). Lives only as long
## as this desktop, so it starts empty every time the laptop opens.
var _history: Array[Dictionary] = []
## The page on screen now, in the same shape (empty before the first page).
var _page: Dictionary = {}
## True while BACK is reopening a page, so that page isn't pushed as a new visit.
var _going_back: bool = false
## Whether the home screen has played its boot intro (once per laptop opening).
var _intro_played: bool = false


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

## The context root: HOME lands here - the ROBO-OS home screen with this context's modules.
func _show_desktop() -> void:
	_record_page("desktop", _show_desktop)
	_open_app_id = ""
	_clear_content()
	if _home_btn != null:
		_home_btn.disabled = true
	_build_desktop_content("HOME", _admin_entries() if context == "admin" else _root_entries())


## The home modules for the maintenance / laptop / stresstest contexts. Laptop also gets
## the STORE; maintenance stays maintenance + settings only; the stress test's laptop is
## maintenance + the patrol-drone monitor + the store, with no settings.
func _root_entries() -> Array:
	var entries: Array = [_maintenance_entry()]
	if context == "stresstest":
		entries.append({"label": "PATROL", "icon": "res://assets/textures/characters/drone/drone.png",
				"action": _open_patrol, "desc": "live feed from the patrol drone",
				"info": func() -> String: return "LIVE FEED"})
		entries.append(_store_entry())
		return entries
	if context == "laptop":
		entries.append(_store_entry())
	entries.append(_settings_entry())
	return entries


## Admin (the debug Shift+Tab laptop): every app, plus settings.
func _admin_entries() -> Array:
	var entries: Array = []
	for app in APPS:
		entries.append({"label": String(app["name"]), "icon": String(app["icon"]),
				"action": _open_app.bind(String(app["id"])), "desc": String(app.get("desc", ""))})
	entries.append(_settings_entry())
	return entries


func _maintenance_entry() -> Dictionary:
	return {"label": "MAINTENANCE", "icon": "screwdriver", "action": _open_maintenance,
			"desc": "browse limb recipes and scan parts",
			"info": func() -> String: return "%d LIMBS READY" % GameState.prepared_limbs.size()}


func _store_entry() -> Dictionary:
	return {"label": "STORE", "icon": "store_example", "action": _open_store,
			"desc": "order supplies for delivery",
			"info": func() -> String: return "BAL $%d" % int(GameState.money)}


func _settings_entry() -> Dictionary:
	return {"label": "SETTINGS", "icon": "gear", "action": _open_settings,
			"desc": "display, audio, camera, profile and saving",
			"info": func() -> String: return "SYSTEM CONFIG"}


## The SETTINGS app, open on `category` (its first one by default). Each category picked
## inside it goes into the BACK history; its own back button returns home.
func _open_settings(category: String = "") -> void:
	var app := SettingsApp.new()
	if category != "":
		app.category = category
	_record_page("settings:" + app.category, _open_settings.bind(app.category))
	app.back_requested.connect(_show_desktop)
	app.category_changed.connect(func(cat: String) -> void:
		_record_page("settings:" + cat, _open_settings.bind(cat)))
	_open_app_control("SETTINGS", app)


## The stress test's patrol-drone monitor.
func _open_patrol() -> void:
	_record_page("app:PATROL", _open_patrol)
	_open_app_control("PATROL", DroneApp.new())


## The online store (DeliveryApp) — laptop scene only.
func _open_store() -> void:
	_record_page("app:STORE", _open_store)
	_open_app_control("STORE", DeliveryApp.new())


## Shows the ROBO-OS home screen with `entries` as its module tiles (see LaptopHome). The
## boot intro plays the first time per opening, except on the stress test's laptop, which
## gets opened in a hurry.
func _build_desktop_content(title: String, entries: Array) -> void:
	if _title_label != null:
		_title_label.text = title
	var home := LaptopHome.new()
	home.entries = entries
	home.session = title.to_lower()
	home.play_intro = not _intro_played and context != "stresstest"
	_intro_played = true
	_content.add_child(home)


# =============================================================================
# APPS
# =============================================================================

func _open_app(app_id: String) -> void:
	var app := _app_by_id(app_id)
	if app.is_empty():
		return
	# LaptopScreen-backed apps record their own pages (see _on_screen_page_changed).
	if String(app.get("mode", "")) == "":
		_record_page("app:" + app_id, _open_app.bind(app_id))
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
		"profile":
			var profile := ProfileApp.new()
			profile.back_requested.connect(_show_desktop)
			return profile
		"drone": return DroneApp.new()
		"history": return StressHistoryApp.new()
		"save": return SaveApp.new()
	return null


## A LaptopScreen in the given app mode, carrying this desktop's context and wired so its
## assembly LIMB SCAN button opens the builder here, and so each page it shows lands in the
## BACK history. `page` is the page it boots into (see LaptopScreen._show_page).
func _make_screen(mode: String, page: Dictionary = {}) -> LaptopScreen:
	var screen := LAPTOP_SCREEN_SCENE.instantiate() as LaptopScreen
	if screen == null:
		return null
	screen.app_mode = mode
	screen.desktop_context = context
	screen.initial_page = page
	screen.open_builder_for_limb.connect(_open_builder)
	screen.return_to_maintenance.connect(_open_maintenance_at)
	screen.page_changed.connect(_on_screen_page_changed.bind(mode))
	return screen


## A LaptopScreen showed a page: remember it so BACK can reopen it exactly.
func _on_screen_page_changed(page: Dictionary, mode: String) -> void:
	_record_page("screen:%s:%s" % [mode, JSON.stringify(page)], _open_screen_page.bind(mode, page))


## Opens a LaptopScreen app (maintenance or builder) straight at `page`.
func _open_screen_page(mode: String, page: Dictionary) -> void:
	var screen := _make_screen(mode, page)
	if screen != null:
		_open_app_control("MAINTENANCE" if mode == "assembly" else "BUILDER", screen)


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
	_open_screen_page("assembly", {})


## Reopen the maintenance app at the page a LIMB SCAN was launched from (used when backing
## out of the scan, so you land on the very page you left - side, segment and all).
func _open_maintenance_at(page: Dictionary) -> void:
	_open_screen_page("assembly", page)


## LIMB SCAN target: the builder, booted straight into `limb`'s scan; `origin_page` is the
## assembly page it was launched from, so the scan's back button returns there.
func _open_builder(limb: String, origin_page: Dictionary = {}) -> void:
	_open_screen_page("build", {"page": "scan", "limb": limb, "return": origin_page})


# =============================================================================
# HISTORY (universal BACK)
# =============================================================================

## Notes that the page `key` is now on screen (`open` rebuilds it). The page that was showing
## goes onto the BACK history, unless BACK itself is reopening this one or it's the same page.
func _record_page(key: String, open: Callable) -> void:
	if not _page.is_empty() and String(_page["key"]) == key:
		return
	if not _going_back and not _page.is_empty():
		_history.append(_page)
		while _history.size() > HISTORY_LIMIT:
			_history.pop_front()
	_page = {"key": key, "open": open}
	_refresh_back_button()


## BACK: reopens the most recent earlier page.
func _go_back() -> void:
	if _history.is_empty():
		return
	var previous: Dictionary = _history.pop_back()
	_going_back = true
	(previous["open"] as Callable).call()
	_going_back = false
	_refresh_back_button()


func _refresh_back_button() -> void:
	if _back_btn != null:
		_back_btn.disabled = _history.is_empty()
		_back_btn.queue_redraw()


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

	# The app's title on the left, the clock on the right...
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	# ...and HOME big in the middle of the bar, on its own over that row. It returns to the
	# desktop from an app (disabled while already on the desktop). BACK sits just left of it,
	# FULLSCREEN just right.
	var home_centre := CenterContainer.new()
	home_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(home_centre)
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", NAV_BUTTON_GAP)
	nav_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home_centre.add_child(nav_row)
	# BACK wears the same ‹ as the apps' own back buttons (e.g. the maintenance name slot).
	_back_btn = _make_nav_button()
	_back_btn.text = "‹"
	_back_btn.add_theme_font_size_override("font_size", HOME_BUTTON_FONT_SIZE)
	_back_btn.add_theme_color_override("font_color", GREEN)
	_back_btn.add_theme_color_override("font_hover_color", HOME_HOVER_COLOR)
	_back_btn.add_theme_color_override("font_pressed_color", HOME_HOVER_COLOR)
	_back_btn.add_theme_color_override("font_disabled_color", DIM)
	_back_btn.pressed.connect(_go_back)
	nav_row.add_child(_back_btn)
	_refresh_back_button()
	_home_btn = Button.new()
	_home_btn.text = "HOME"
	_home_btn.custom_minimum_size = HOME_BUTTON_SIZE
	_home_btn.focus_mode = Control.FOCUS_NONE
	_home_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_home_btn.add_theme_font_size_override("font_size", HOME_BUTTON_FONT_SIZE)
	_home_btn.add_theme_color_override("font_color", GREEN)
	_home_btn.add_theme_color_override("font_hover_color", HOME_HOVER_COLOR)
	_home_btn.add_theme_color_override("font_disabled_color", DIM)
	_home_btn.add_theme_stylebox_override("normal", _home_style())
	_home_btn.add_theme_stylebox_override("hover", _home_style(Color(0.35, 1.0, 0.5, 0.95)))
	_home_btn.add_theme_stylebox_override("pressed", _home_style(Color(0.35, 1.0, 0.5, 0.95)))
	_home_btn.add_theme_stylebox_override("disabled", _home_style(Color(0.2, 0.45, 0.28, 0.5)))
	_home_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_home_btn.pressed.connect(_show_desktop)
	nav_row.add_child(_home_btn)
	_fullscreen_btn = _make_nav_button(_draw_fullscreen_icon)
	_fullscreen_btn.pressed.connect(func() -> void: fullscreen_toggle_requested.emit())
	if not fullscreen_supported:
		# Keeps its space so HOME stays centred, but can't be seen or pressed.
		_fullscreen_btn.disabled = true
		_fullscreen_btn.modulate.a = 0.0
		_fullscreen_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_row.add_child(_fullscreen_btn)
	# The home symbol at each end, vertically centred, coloured with the text as the button
	# changes state.
	var marks: Array[Control] = []
	var mark_size := Vector2.ONE * HOME_MARK_SQUARE * 2.0
	for left in [true, false]:
		var mark := Control.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.anchor_left = 0.0 if left else 1.0
		mark.anchor_right = mark.anchor_left
		mark.anchor_top = 0.5
		mark.anchor_bottom = 0.5
		mark.offset_left = HOME_MARK_INSET if left else -HOME_MARK_INSET - mark_size.x
		mark.offset_right = mark.offset_left + mark_size.x
		mark.offset_top = -mark_size.y * 0.5
		mark.offset_bottom = mark_size.y * 0.5
		mark.draw.connect(func() -> void:
			var color := DIM if _home_btn.disabled else (HOME_HOVER_COLOR if _home_btn.is_hovered() else GREEN)
			mark.draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * HOME_MARK_SQUARE), color)
			mark.draw_rect(Rect2(Vector2.ONE * HOME_MARK_SQUARE, Vector2.ONE * HOME_MARK_SQUARE), color))
		_home_btn.add_child(mark)
		marks.append(mark)
	_home_btn.draw.connect(func() -> void:
		for mark in marks:
			mark.queue_redraw())

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


## A small square taskbar button in HOME's style. If given, `draw_icon(button, colour)`
## draws its symbol centred on it, coloured like HOME's text as the button changes state.
func _make_nav_button(draw_icon: Callable = Callable()) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = NAV_BUTTON_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _home_style())
	btn.add_theme_stylebox_override("hover", _home_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("pressed", _home_style(Color(0.35, 1.0, 0.5, 0.95)))
	btn.add_theme_stylebox_override("disabled", _home_style(Color(0.2, 0.45, 0.28, 0.5)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if draw_icon.is_valid():
		btn.draw.connect(func() -> void:
			var color := DIM if btn.disabled else (HOME_HOVER_COLOR if btn.is_hovered() else GREEN)
			draw_icon.call(btn, color))
	return btn


## FULLSCREEN's symbol: four corner brackets, opening outward to go fullscreen and pointing
## inward (corners at the middle) to come back out.
func _draw_fullscreen_icon(btn: Button, color: Color) -> void:
	var c := (btn.size * 0.5).round()
	var h := NAV_ICON_SIZE * 0.5
	var arm := 3.0
	for dir in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner: Vector2 = c + dir * h
		# Brackets hug the outer corners when expanding; when shrinking they sit `arm` in from
		# the corners, their arms pointing back out.
		var toward: Vector2 = -dir if not fullscreen_active else dir
		if fullscreen_active:
			corner -= dir * arm
		btn.draw_line(corner, corner + Vector2(toward.x * arm, 0.0), color, 1.0)
		btn.draw_line(corner, corner + Vector2(0.0, toward.y * arm), color, 1.0)


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


## The taskbar's HOME button: the panel look, with its text sitting tight top and bottom
## so the button can nearly fill the bar's height.
func _home_style(border: Color = BORDER) -> StyleBoxFlat:
	var sb := _panel_style(border)
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


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
