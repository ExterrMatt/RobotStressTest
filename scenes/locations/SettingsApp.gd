extends Control
class_name SettingsApp
## Laptop SETTINGS app: the game's settings (the same ones the pause menu has) in the
## laptop's green-terminal look, plus the player's name and saving. Category tabs down the
## left, the chosen category's rows on the right; every change applies at once. A hint line
## along the bottom says what the row under the mouse does.

## The header's back button: the desktop goes home.
signal back_requested
## A different category was picked (the desktop keeps these for its BACK button).
signal category_changed(category: String)

const GlowingLabelScript: GDScript = preload("res://scenes/ui/GlowingLabel.gd")

const CATEGORIES: Array = [
	{"id": "display", "name": "DISPLAY", "desc": "window, brightness and scanlines. changes apply instantly."},
	{"id": "audio", "name": "AUDIO", "desc": "master and music volume. changes apply instantly."},
	{"id": "camera", "name": "CAMERA", "desc": "how the view moves. changes apply instantly."},
	{"id": "gameplay", "name": "GAMEPLAY", "desc": "assists. changes apply instantly."},
	{"id": "profile", "name": "PROFILE", "desc": "who's logged in. press enter or APPLY to rename."},
	{"id": "system", "name": "SYSTEM", "desc": "save your progress and check the system."},
]
## GameState.WindowMode order.
const WINDOW_MODE_NAMES: Array[String] = ["WINDOWED", "BORDERLESS", "FULLSCREEN"]
const PHASE_NAMES: Array[String] = ["MORNING", "EVENING", "NIGHT"]
const HOT: Color = Color(0.35, 1.0, 0.5, 0.95)
const TAB_WIDTH: float = 80.0
const ROW_HEIGHT: float = 20.0
const LABEL_WIDTH: float = 88.0
const SLIDER_STEP: float = 5.0

## The category to open on (one of CATEGORIES' ids). Set before this enters the tree.
var category: String = "display"

var _tabs: Dictionary = {}
var _rows: VBoxContainer = null
var _section_title: Label = null
var _hint: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _category_info(category).is_empty():
		category = String(CATEGORIES[0]["id"])

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	LaptopUI.screen_margin(self, 6).add_child(col)
	col.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	body.add_child(_build_tabs())

	var panel := LaptopUI.box()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)

	_section_title = LaptopUI.label("", 12, LaptopUI.GREEN)
	inner.add_child(_section_title)
	var rule := ColorRect.new()
	rule.color = LaptopUI.BORDER
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(rule)

	_rows = VBoxContainer.new()
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_rows)

	_hint = LaptopUI.label("", 9, LaptopUI.DIM)
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(_hint)

	_show_category(category)


## The name slot up top, like the maintenance app's: back button, title, and the section.
func _build_header() -> Control:
	var box := LaptopUI.box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var back := LaptopUI.button("‹", 11)
	back.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(back)

	var title := Label.new()
	title.set_script(GlowingLabelScript)
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", LaptopUI.GREEN)
	title.set("glow_color", Color(0.15, 1.0, 0.35, 1.0))
	title.set("glow_radius_px", 20.0)
	title.set("glow_strength", 1.4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var tag := LaptopUI.label("CFG.SYS", 9, LaptopUI.DIM)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag)
	return box


func _build_tabs() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(TAB_WIDTH, 0)
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cat in CATEGORIES:
		var id := String(cat["id"])
		var tab := Button.new()
		tab.text = String(cat["name"])
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.focus_mode = Control.FOCUS_NONE
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_font_size_override("font_size", 11)
		tab.pressed.connect(_on_tab_pressed.bind(id))
		col.add_child(tab)
		_tabs[id] = tab
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	col.add_child(LaptopUI.label("ROBO-OS v0.2", 8, Color(LaptopUI.DIM, 0.7)))
	return col


## Restyles the tabs so `selected` reads as the open one: filled, with a marker.
func _style_tabs(selected: String) -> void:
	for id in _tabs:
		var tab: Button = _tabs[id]
		var on: bool = id == selected
		var caption := String(_category_info(id).get("name", ""))
		tab.text = ("> " if on else "  ") + caption
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := LaptopUI.panel_style(HOT if on or state == "hover" or state == "pressed" else LaptopUI.BORDER)
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
			sb.content_margin_left = 4
			if on:
				sb.bg_color = Color(0.03, 0.2, 0.09, 0.9)
			elif state == "hover":
				sb.bg_color = Color(0.02, 0.12, 0.06, 0.8)
			if state == "focus":
				tab.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			else:
				tab.add_theme_stylebox_override(state, sb)
		tab.add_theme_color_override("font_color", LaptopUI.OK if on else LaptopUI.DIM)
		tab.add_theme_color_override("font_hover_color", LaptopUI.OK)
		tab.add_theme_color_override("font_pressed_color", LaptopUI.OK)


func _on_tab_pressed(id: String) -> void:
	if id == category:
		return
	_show_category(id)
	category_changed.emit(id)


func _show_category(id: String) -> void:
	category = id
	_style_tabs(id)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_section_title.text = "// " + String(_category_info(id).get("name", ""))
	_set_hint("")
	match id:
		"display":
			_add_selector_row("WINDOW MODE", WINDOW_MODE_NAMES, int(GameState.window_mode),
					func(i: int) -> void: GameState.window_mode = i,
					"windowed, borderless fullscreen or fullscreen")
			_add_slider_row("BRIGHTNESS", GameState.brightness_value,
					func(v: float) -> void: GameState.brightness_value = v, "how bright the whole game is")
			_add_toggle_row("SCANLINES", GameState.scanlines_enabled,
					func(on: bool) -> void: GameState.scanlines_enabled = on, "the CRT scanline overlay")
		"audio":
			_add_slider_row("MASTER VOLUME", GameState.volume_value,
					func(v: float) -> void: GameState.volume_value = v, "everything you hear")
			_add_slider_row("MUSIC VOLUME", GameState.music_volume_value,
					func(v: float) -> void: GameState.music_volume_value = v, "just the music")
		"camera":
			_add_toggle_row("CAMERA TILT", GameState.camera_roll_enabled,
					func(on: bool) -> void: GameState.camera_roll_enabled = on,
					"the view tilts on the stress test's long pans")
			_add_toggle_row("CAMERA SWAY", GameState.camera_mouse_follow_enabled,
					func(on: bool) -> void: GameState.camera_mouse_follow_enabled = on,
					"the view drifts a little toward the cursor")
		"gameplay":
			_add_toggle_row("EASY WORKSHOP", GameState.easy_workshop_enabled,
					func(on: bool) -> void: GameState.easy_workshop_enabled = on,
					"the workshop flashes where each piece goes")
			# Like the pause menu: only offered while debug is on, so it can be turned off
			# but never on from here.
			if GameState.debug_mode_enabled:
				_add_toggle_row("DEBUG MODE", true, _on_debug_toggled, "turn off debug mode (can't be turned back on here)")
		"profile":
			_build_profile()
		"system":
			_build_system()


func _on_debug_toggled(on: bool) -> void:
	GameState.debug_mode_enabled = on
	if not on:
		# The row goes once debug is off.
		_show_category.call_deferred("gameplay")


func _set_hint(desc: String) -> void:
	if _hint == null:
		return
	_hint.text = "> " + (desc if desc != "" else String(_category_info(category).get("desc", "")))


func _category_info(id: String) -> Dictionary:
	for cat in CATEGORIES:
		if String(cat["id"]) == id:
			return cat
	return {}


# =============================================================================
# ROWS
# =============================================================================

## A settings row: its name on the left and room for a control, with a dotted rule under
## it. Hovering it puts `desc` on the hint line.
func _add_row(caption: String, desc: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_entered.connect(_set_hint.bind(desc))
	row.mouse_exited.connect(_set_hint.bind(""))
	row.draw.connect(func() -> void:
		var x := 0.0
		while x < row.size.x:
			row.draw_rect(Rect2(x, row.size.y - 1.0, 1.0, 1.0), Color(LaptopUI.DIM, 0.35))
			x += 3.0)
	var label := LaptopUI.label(caption, 11, LaptopUI.GREEN)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	_rows.add_child(row)
	return row


func _add_slider_row(caption: String, value: float, on_change: Callable, desc: String) -> void:
	var row := _add_row(caption, desc)
	var slider := SegmentSlider.new()
	slider.value = snappedf(value, SLIDER_STEP)
	slider.step = SLIDER_STEP
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(50, 10)
	row.add_child(slider)
	var readout := LaptopUI.label("%d%%" % int(slider.value), 10, LaptopUI.OK)
	readout.custom_minimum_size = Vector2(28, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = "%d%%" % int(v)
		on_change.call(v))


func _add_toggle_row(caption: String, on: bool, on_change: Callable, desc: String) -> void:
	var row := _add_row(caption, desc)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var toggle := ToggleSwitch.new()
	toggle.button_pressed = on
	toggle.custom_minimum_size = Vector2(46, 12)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggled.connect(on_change)
	row.add_child(toggle)


## ‹ VALUE › - the arrows step through `options` (wrapping round).
func _add_selector_row(caption: String, options: Array[String], selected: int, on_change: Callable, desc: String) -> void:
	var row := _add_row(caption, desc)
	var current: Array[int] = [clampi(selected, 0, options.size() - 1)]
	var value := LaptopUI.label(options[current[0]], 10, LaptopUI.OK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var step := func(dir: int) -> void:
		current[0] = posmod(current[0] + dir, options.size())
		value.text = options[current[0]]
		on_change.call(current[0])
	row.add_child(_arrow_button("‹", step.bind(-1)))
	row.add_child(value)
	row.add_child(_arrow_button("›", step.bind(1)))


func _arrow_button(glyph: String, on_press: Callable) -> Button:
	var btn := LaptopUI.button(glyph, 11)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := btn.get_theme_stylebox(state) as StyleBoxFlat
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		sb.content_margin_left = 5
		sb.content_margin_right = 5
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if on_press.is_valid():
		btn.pressed.connect(on_press)
	return btn


# =============================================================================
# PROFILE / SYSTEM
# =============================================================================

func _build_profile() -> void:
	var row := _add_row("OPERATOR", "the name you go by - shown in dialogue and on the shell")
	var field := LineEdit.new()
	field.text = GameState.get_player_name()
	field.max_length = 24
	field.placeholder_text = "enter a name"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.add_theme_font_size_override("font_size", 11)
	field.add_theme_color_override("font_color", LaptopUI.GREEN)
	field.add_theme_color_override("caret_color", LaptopUI.GREEN)
	field.add_theme_color_override("font_placeholder_color", Color(LaptopUI.DIM, 0.55))
	for state in ["normal", "focus"]:
		var sb := LaptopUI.panel_style(HOT if state == "focus" else LaptopUI.BORDER)
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		field.add_theme_stylebox_override(state, sb)
	row.add_child(field)

	var status := LaptopUI.label("", 10, LaptopUI.OK)
	var apply := func() -> void:
		if GameState.normalize_player_name(field.text).is_empty():
			status.add_theme_color_override("font_color", LaptopUI.ERR)
			status.text = "enter at least one letter."
			return
		GameState.set_player_name(field.text)
		field.text = GameState.get_player_name()
		field.release_focus()
		status.add_theme_color_override("font_color", LaptopUI.OK)
		status.text = "operator renamed to %s." % GameState.get_player_name()
	field.text_submitted.connect(func(_t: String) -> void: apply.call())
	var confirm := _arrow_button("APPLY", apply)
	row.add_child(confirm)
	_rows.add_child(status)


func _build_system() -> void:
	var row := _add_row("SAVE GAME", "write your progress to disk")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var status := LaptopUI.label("", 10, LaptopUI.DIM)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status)
	var save_btn := _arrow_button("SAVE", Callable())
	row.add_child(save_btn)

	var save_file := _info_row("SAVE FILE", "FOUND" if GameState.has_save() else "NONE")
	_info_row("OPERATOR", GameState.get_player_name().to_upper())
	var phase: int = clampi(int(GameState.phase), 0, PHASE_NAMES.size() - 1)
	_info_row("SESSION", "DAY %d · %s" % [int(GameState.day), PHASE_NAMES[phase]])
	_info_row("SYSTEM", "ROBO-OS v0.2")

	save_btn.pressed.connect(func() -> void:
		if GameState.save_game():
			status.add_theme_color_override("font_color", LaptopUI.OK)
			status.text = "SAVED"
			save_file.text = "FOUND"
		else:
			status.add_theme_color_override("font_color", LaptopUI.ERR)
			status.text = "SAVE FAILED")


## A read-only "NAME ........ VALUE" line; returns the value label.
func _info_row(caption: String, value: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := LaptopUI.label(caption, 10, LaptopUI.DIM)
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(label)
	var value_label := LaptopUI.label(value, 10, LaptopUI.GREEN)
	row.add_child(value_label)
	_rows.add_child(row)
	return value_label


# =============================================================================
# WIDGETS
# =============================================================================

## A volume-style bar of segments. Click or drag to set it, or scroll over it; it snaps to
## `step` and lights the segments up to the value.
class SegmentSlider extends Control:
	signal value_changed(value: float)

	const SEGMENTS: int = 12
	const GAP: float = 1.0

	var value: float = 50.0
	var step: float = 5.0
	var _dragging: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_dragging = mb.pressed
				if mb.pressed:
					_set_from_x(mb.position.x)
				accept_event()
			elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_RIGHT]:
				_set_value(value + step)
				accept_event()
			elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT]:
				_set_value(value - step)
				accept_event()
		elif event is InputEventMouseMotion and _dragging:
			_set_from_x((event as InputEventMouseMotion).position.x)
			accept_event()

	func _set_from_x(x: float) -> void:
		_set_value(clampf(x / maxf(size.x, 1.0), 0.0, 1.0) * 100.0)

	func _set_value(v: float) -> void:
		var stepped := clampf(snappedf(v, step), 0.0, 100.0)
		if is_equal_approx(stepped, value):
			return
		value = stepped
		queue_redraw()
		value_changed.emit(value)

	func _draw() -> void:
		var hot := get_global_rect().has_point(get_global_mouse_position()) or _dragging
		var h := minf(size.y, 10.0)
		var top := floorf((size.y - h) * 0.5)
		var seg_w := (size.x - GAP * (SEGMENTS - 1)) / SEGMENTS
		var lit := value / 100.0 * SEGMENTS
		var on := LaptopUI.OK if hot else LaptopUI.GREEN
		for i in SEGMENTS:
			var rect := Rect2(floorf(i * (seg_w + GAP)), top, maxf(1.0, floorf(seg_w)), h)
			if float(i) + 1.0 <= lit + 0.001:
				draw_rect(rect, on)
			elif float(i) < lit:
				# The segment the value ends in is part-filled.
				draw_rect(rect, Color(on, 0.25))
				draw_rect(Rect2(rect.position, Vector2(floorf(rect.size.x * (lit - i)), h)), on)
			else:
				draw_rect(rect, Color(0.0, 0.1, 0.04, 0.8))
				draw_rect(rect.grow(-0.5), Color(LaptopUI.DIM, 0.45 if hot else 0.3), false, 1.0)


## An ON / OFF switch: a track with a sliding knob, its state written beside it.
class ToggleSwitch extends Button:
	const TRACK: Vector2 = Vector2(22.0, 10.0)

	var _knob: float = 0.0

	func _ready() -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, empty)
		_knob = 1.0 if button_pressed else 0.0

	func _process(delta: float) -> void:
		var target := 1.0 if button_pressed else 0.0
		if not is_equal_approx(_knob, target):
			_knob = move_toward(_knob, target, delta * 10.0)
			queue_redraw()

	func _draw() -> void:
		var hot := is_hovered()
		var top := floorf((size.y - TRACK.y) * 0.5)
		var track := Rect2(Vector2(0.0, top), TRACK)
		var on_col := LaptopUI.OK if hot else LaptopUI.GREEN
		draw_rect(track, Color(0.03, 0.22, 0.1, 0.9).lerp(Color(0.0, 0.06, 0.03, 0.9), 1.0 - _knob))
		draw_rect(track.grow(-0.5), on_col if button_pressed else Color(LaptopUI.DIM, 0.8 if hot else 0.6), false, 1.0)
		var knob := Rect2(track.position + Vector2(2.0 + _knob * (TRACK.x - 10.0), 2.0), Vector2(6.0, TRACK.y - 4.0))
		draw_rect(knob, on_col if button_pressed else LaptopUI.DIM)
		var font := get_theme_font("font")
		var fs := 10
		var baseline := (size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(TRACK.x + 5.0, baseline), "ON" if button_pressed else "OFF",
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, on_col if button_pressed else LaptopUI.DIM)
