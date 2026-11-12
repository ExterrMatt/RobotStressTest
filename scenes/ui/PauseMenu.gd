extends SettingsApp
class_name PauseMenu
## The Esc menu: the laptop SETTINGS app's green-terminal look, as a window floating over
## the dimmed game. It keeps the settings that make sense mid-game (display, audio, camera,
## gameplay), leaves out the laptop-only ones (profile, saving), and adds what a pause menu
## needs: the day and phase in the header, RESUME, and QUIT GAME (which asks once).
## Opened from the main menu it is that menu's SETTINGS instead (see on_main_menu).
##
## `back_requested` (inherited) means "resume": the header's back button, RESUME, and a
## click off the window all emit it. Whoever opened the menu closes it.

signal quit_requested

## The window's size before WINDOW_SCALE. It is built at the laptop's text sizes and scaled
## up, the way the laptop's own screen is.
const WINDOW_SIZE: Vector2 = Vector2(380.0, 212.0)
const WINDOW_SCALE: float = 2.0
## Room left around the window when the view is too small for the full scale.
const WINDOW_MARGIN: float = 24.0
const BACKDROP: Color = Color(0.0, 0.02, 0.01, 0.78)
const WINDOW_BG: Color = Color(0.02, 0.06, 0.03, 1.0)
const PAUSE_CATEGORIES: Array[String] = ["display", "audio", "camera", "gameplay"]
const QUIT_TEXT: String = "QUIT GAME"
const QUIT_CONFIRM_TEXT: String = "REALLY QUIT?"

## The main menu's red RESET tab (see the RESET section below).
const RESET_ID: String = "reset"
const RESET_CATEGORY: Dictionary = {"id": RESET_ID, "name": "RESET", "desc": "delete a save, or wipe everything and start over."}
const FINAL_WARNING_TITLE: String = "ARE YOU SURE??!!??!"
const FINAL_WARNING_TEXT: String = "(This will delete ALL your save progress FOREVER D:)"

## Opened from the main menu rather than mid-game: there is no day to show and nothing to
## resume, so it is titled SETTINGS with MAIN MENU as its tag, RESUME becomes BACK, there
## is no QUIT GAME (the main menu has its own), the DEBUG MODE row is always there to turn
## debug on or off, and a red RESET tab ends the category list.
var on_main_menu: bool = false

var _reset_tab: Button = null
## Which RESET page is up: "menu", "saves", "confirm_delete", "confirm_reset" or "final".
var _reset_page: String = "menu"
## The save "confirm_delete" asks about (an entry of GameState.list_saves()).
var _pending_save: Dictionary = {}
## A line the RESET menu shows after something was deleted, and its colour.
var _reset_status: String = ""
var _reset_status_color: Color = LaptopUI.OK


## Builds the menu on `layer`: a dimming backdrop that resumes when clicked, with the
## window centred on it. Returns the menu so the caller can connect its signals.
static func open_on(layer: CanvasLayer, from_main_menu: bool = false) -> PauseMenu:
	var menu := PauseMenu.new()
	menu.on_main_menu = from_main_menu
	open_window(layer, WINDOW_SIZE, menu, func() -> void: menu.back_requested.emit())
	return menu


## Puts `content` in a floating window of `window_size` (before WINDOW_SCALE) centred on a
## dimming backdrop on `layer`. A click off the window calls `on_dismiss`.
static func open_window(layer: CanvasLayer, window_size: Vector2, content: Control, on_dismiss: Callable) -> void:
	var back := ColorRect.new()
	back.name = "PauseMenuBackdrop"
	back.color = BACKDROP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			on_dismiss.call())
	layer.add_child(back)

	var window := Control.new()
	window.name = "PauseMenuWindow"
	window.size = window_size
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	back.add_child(window)
	var place := func() -> void:
		var room := back.size - Vector2.ONE * WINDOW_MARGIN * 2.0
		var s := minf(WINDOW_SCALE, minf(room.x / window_size.x, room.y / window_size.y))
		window.scale = Vector2.ONE * s
		window.position = ((back.size - window_size * s) * 0.5).round()
	back.resized.connect(place)
	place.call()

	window.add_child(content)


func _ready() -> void:
	# The laptop's desktop sits behind the settings app; here the window brings its own.
	add_child(window_background())
	super._ready()


## The window's own dark, green-bordered, softly glowing background.
static func window_background() -> Panel:
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = WINDOW_BG
	sb.border_color = LaptopUI.BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0.1, 1.0, 0.35, 0.12)
	sb.shadow_size = 8
	bg.add_theme_stylebox_override("panel", sb)
	return bg


func _categories() -> Array:
	return CATEGORIES.filter(func(cat: Dictionary) -> bool: return String(cat["id"]) in PAUSE_CATEGORIES)


func _title_text() -> String:
	return "SETTINGS" if on_main_menu else "PAUSE MENU"


## Debug mode can be switched either way from the main menu. In game the row only shows
## while debug is already on, so it can be turned off there but never on.
func _debug_toggle_always_offered() -> bool:
	return on_main_menu


func _tag_text() -> String:
	if on_main_menu:
		return "MAIN MENU"
	var phase: int = clampi(int(GameState.phase), 0, PHASE_NAMES.size() - 1)
	return "DAY %d · %s" % [int(GameState.day), PHASE_NAMES[phase]]


## Under the settings: how to get back out on the left, RESUME and QUIT GAME on the right.
func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var resume_text := "BACK" if on_main_menu else "RESUME"
	var esc := LaptopUI.label("[ESC] " + resume_text, 9, LaptopUI.DIM)
	esc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(esc)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# The main menu has its own QUIT, so its settings leave this one out.
	if not on_main_menu:
		var quit := _footer_button(QUIT_TEXT, LaptopUI.ERR)
		# The first press arms it, the second quits; moving off it stands it down.
		var armed: Array[bool] = [false]
		quit.pressed.connect(func() -> void:
			if armed[0]:
				quit_requested.emit()
				return
			armed[0] = true
			quit.text = QUIT_CONFIRM_TEXT)
		quit.mouse_exited.connect(func() -> void:
			armed[0] = false
			quit.text = QUIT_TEXT)
		quit.mouse_entered.connect(_set_hint.bind("close the game. anything not saved is lost."))
		quit.mouse_exited.connect(_set_hint.bind(""))
		row.add_child(quit)

	var resume := _footer_button(resume_text, LaptopUI.GREEN)
	resume.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(resume)
	return row


static func _footer_button(text: String, color: Color) -> Button:
	var btn := LaptopUI.button(text, 11)
	btn.custom_minimum_size = Vector2(86, 0)
	btn.add_theme_color_override("font_color", color)
	if color != LaptopUI.GREEN:
		btn.add_theme_color_override("font_hover_color", color)
		btn.add_theme_color_override("font_pressed_color", color)
		btn.add_theme_stylebox_override("normal", LaptopUI.panel_style(Color(color, 0.55)))
		btn.add_theme_stylebox_override("hover", LaptopUI.panel_style(color))
		btn.add_theme_stylebox_override("pressed", LaptopUI.panel_style(color))
	for state in ["normal", "hover", "pressed"]:
		var sb := btn.get_theme_stylebox(state) as StyleBoxFlat
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
	return btn


# =============================================================================
# RESET (main menu only) - a red tab after the categories. Its page offers deleting one
# save (asks once) or resetting the whole game (asks twice, the second time loudly).
# =============================================================================

func _category_info(id: String) -> Dictionary:
	if id == RESET_ID and on_main_menu:
		return RESET_CATEGORY
	return super._category_info(id)


func _add_extra_tabs(col: VBoxContainer) -> void:
	if not on_main_menu:
		return
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	_reset_tab = Button.new()
	_reset_tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_reset_tab.focus_mode = Control.FOCUS_NONE
	_reset_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reset_tab.add_theme_font_size_override("font_size", 11)
	_reset_tab.pressed.connect(func() -> void: _open_reset_page("menu"))
	_reset_tab.mouse_entered.connect(_set_hint.bind(String(RESET_CATEGORY["desc"])))
	_reset_tab.mouse_exited.connect(_set_hint.bind(""))
	col.add_child(_reset_tab)


func _style_tabs(selected: String) -> void:
	super._style_tabs(selected)
	if _reset_tab == null:
		return
	var on := selected == RESET_ID
	_reset_tab.text = ("> " if on else "  ") + "RESET"
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if state == "focus":
			_reset_tab.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			continue
		var hot: bool = on or state == "hover" or state == "pressed"
		var sb := LaptopUI.panel_style(LaptopUI.ERR if hot else Color(LaptopUI.ERR, 0.6))
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		sb.content_margin_left = 4
		sb.bg_color = Color(0.3, 0.03, 0.03, 0.9) if on else (Color(0.2, 0.02, 0.02, 0.8) if hot else Color(0.1, 0.01, 0.01, 0.7))
		_reset_tab.add_theme_stylebox_override(state, sb)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		_reset_tab.add_theme_color_override(key, LaptopUI.ERR)


## Shows RESET's `page` (rebuilding the rows).
func _open_reset_page(page: String) -> void:
	_reset_page = page
	_show_category(RESET_ID)


func _build_extra_category(id: String) -> void:
	if id != RESET_ID:
		return
	_section_title.add_theme_color_override("font_color", LaptopUI.ERR)
	match _reset_page:
		"saves":
			_section_title.text = "// RESET › DELETE SAVE"
			_build_reset_saves()
		"confirm_delete":
			_section_title.text = "// RESET › DELETE SAVE"
			_build_confirm_delete()
		"confirm_reset":
			_section_title.text = "// RESET › RESET GAME"
			_build_confirm_reset()
		"final":
			_section_title.text = "// RESET › RESET GAME"
			_build_final_warning()
		_:
			_build_reset_menu()


func _build_reset_menu() -> void:
	var saves := GameState.list_saves()
	var row := _add_row("DELETE SAVE", "pick one save file to delete")
	row.add_child(_expander())
	var count := LaptopUI.label("%d ON DISK" % saves.size(), 10, LaptopUI.DIM)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	var choose := _arrow_button("CHOOSE ›", func() -> void: _open_reset_page("saves"))
	choose.disabled = saves.is_empty()
	row.add_child(choose)

	row = _add_row("RESET GAME", "delete every save and put every setting back to default")
	(row.get_child(0) as Label).add_theme_color_override("font_color", LaptopUI.ERR)
	row.add_child(_expander())
	row.add_child(_red_button("RESET", func() -> void: _open_reset_page("confirm_reset")))

	if _reset_status != "":
		var status := LaptopUI.label("> " + _reset_status, 10, _reset_status_color)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.add_child(status)
		_reset_status = ""


func _build_reset_saves() -> void:
	var saves := GameState.list_saves()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)

	# _add_row puts rows in _rows; point it at the scrolling list for the save rows.
	var outer := _rows
	_rows = list
	if saves.is_empty():
		list.add_child(LaptopUI.label("> no saves on disk.", 10, LaptopUI.DIM))
	for save in saves:
		var row := _add_row(String(save["name"]), "delete %s for good" % String(save["name"]).to_lower())
		var summary := LaptopUI.label(String(save["summary"]), 10, LaptopUI.OK)
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		summary.clip_text = true
		summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(summary)
		row.add_child(_red_button("DELETE", func() -> void:
			_pending_save = save
			_open_reset_page("confirm_delete")))
	_rows = outer

	_rows.add_child(_button_row([_arrow_button("‹ BACK", func() -> void: _open_reset_page("menu"))]))


func _build_confirm_delete() -> void:
	var save_name := String(_pending_save.get("name", "SAVE"))
	_add_message("> delete %s (%s)?" % [save_name, String(_pending_save.get("summary", ""))], LaptopUI.GREEN)
	_add_message("> it's gone for good - this can't be undone.", LaptopUI.DIM)
	_rows.add_child(_expander(true))
	var delete_btn := _footer_button("DELETE", LaptopUI.ERR)
	delete_btn.pressed.connect(func() -> void:
		if GameState.delete_save(String(_pending_save.get("path", ""))):
			_set_reset_status("%s deleted." % save_name.to_lower(), LaptopUI.OK)
		else:
			_set_reset_status("couldn't delete %s." % save_name.to_lower(), LaptopUI.ERR)
		_pending_save = {}
		_open_reset_page("menu"))
	var cancel := _footer_button("CANCEL", LaptopUI.GREEN)
	cancel.pressed.connect(func() -> void: _open_reset_page("saves"))
	_rows.add_child(_button_row([delete_btn, cancel]))


func _build_confirm_reset() -> void:
	_add_message("> reset the whole game?", LaptopUI.GREEN)
	_add_message("> every save is deleted and every setting goes back to default.", LaptopUI.DIM)
	_rows.add_child(_expander(true))
	var reset := _footer_button("RESET", LaptopUI.ERR)
	reset.pressed.connect(func() -> void: _open_reset_page("final"))
	var cancel := _footer_button("CANCEL", LaptopUI.GREEN)
	cancel.pressed.connect(func() -> void: _open_reset_page("menu"))
	_rows.add_child(_button_row([reset, cancel]))


## The second, louder ask before the full reset.
func _build_final_warning() -> void:
	var box := LaptopUI.box(LaptopUI.ERR)
	var sb := box.get_theme_stylebox("panel") as StyleBoxFlat
	sb.bg_color = Color(0.22, 0.02, 0.02, 0.85)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var title := LaptopUI.glow_title(FINAL_WARNING_TITLE, 16, LaptopUI.ERR, Color(1.0, 0.15, 0.1, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var text := LaptopUI.label(FINAL_WARNING_TEXT, 10, LaptopUI.ERR)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	_rows.add_child(box)

	var yes := _footer_button("YES, RESET", LaptopUI.ERR)
	yes.pressed.connect(func() -> void:
		if GameState.reset_all_data():
			_set_reset_status("everything's gone. fresh start.", LaptopUI.OK)
		else:
			_set_reset_status("reset done, but some files couldn't be deleted.", LaptopUI.ERR)
		_open_reset_page("menu"))
	var no := _footer_button("NO!", LaptopUI.GREEN)
	no.pressed.connect(func() -> void: _open_reset_page("menu"))
	_rows.add_child(_button_row([yes, no]))


func _set_reset_status(text: String, color: Color) -> void:
	_reset_status = text
	_reset_status_color = color


func _add_message(text: String, color: Color) -> void:
	var line := LaptopUI.label(text, 10, color)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(line)


## A small button in the RESET colours.
func _red_button(text: String, on_press: Callable) -> Button:
	var btn := _arrow_button(text, on_press)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(key, LaptopUI.ERR)
	for state in ["normal", "hover", "pressed"]:
		var sb := btn.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		sb.border_color = LaptopUI.ERR if state != "normal" else Color(LaptopUI.ERR, 0.6)
		sb.bg_color = Color(0.2, 0.02, 0.02, 0.8) if state != "normal" else Color(0.1, 0.01, 0.01, 0.7)
		btn.add_theme_stylebox_override(state, sb)
	return btn


## `buttons` pushed to the right of a row.
func _button_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_expander())
	for btn in buttons:
		row.add_child(btn)
	return row


## A blank that takes up the spare width (or height, when `vertical`).
static func _expander(vertical: bool = false) -> Control:
	var spacer := Control.new()
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## The main menu's QUIT prompt: the pause menu's window cut down to a header, one line, and
## the two buttons - QUIT and STAY. `back_requested` means "stay": the header's back button,
## STAY, and a click off the window all emit it. Whoever opened the prompt closes it.
class QuitPrompt extends Control:
	signal back_requested
	signal quit_requested

	## Tall enough for everything in it; any shorter and the footer overflows, closing the
	## gap between the buttons and the window's bottom border.
	const PROMPT_SIZE: Vector2 = Vector2(232.0, 96.0)
	## The gap between the window's border and what's in it, the same as the pause menu's.
	const PAD: int = 6

	var _message: Label = null

	static func open_on(layer: CanvasLayer) -> QuitPrompt:
		var prompt := QuitPrompt.new()
		PauseMenu.open_window(layer, PROMPT_SIZE, prompt, func() -> void: prompt.back_requested.emit())
		return prompt

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(PauseMenu.window_background())

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 5)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var margin := LaptopUI.screen_margin(self, PAD)
		margin.add_child(col)

		# The same header as the pause menu: back button, glowing title, dim tag.
		var header := LaptopUI.box()
		var head_row := HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 6)
		head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(head_row)
		var back := LaptopUI.button("‹", 11)
		back.pressed.connect(func() -> void: back_requested.emit())
		head_row.add_child(back)
		head_row.add_child(LaptopUI.glow_title(PauseMenu.QUIT_TEXT))
		head_row.add_child(_spacer())
		var tag := LaptopUI.label("MAIN MENU", 9, LaptopUI.DIM)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head_row.add_child(tag)
		col.add_child(header)

		var body := LaptopUI.box()
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_message = LaptopUI.label("> close the game?", 10, LaptopUI.DIM)
		_message.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.add_child(_message)
		col.add_child(body)

		var footer := HBoxContainer.new()
		footer.add_theme_constant_override("separation", 6)
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer.add_child(_spacer())
		var quit := PauseMenu._footer_button("QUIT", LaptopUI.ERR)
		quit.pressed.connect(func() -> void:
			_message.text = "> i'll be waiting."
			quit_requested.emit())
		footer.add_child(quit)
		var stay := PauseMenu._footer_button("STAY", LaptopUI.GREEN)
		stay.pressed.connect(func() -> void: back_requested.emit())
		footer.add_child(stay)
		col.add_child(footer)

	func _spacer() -> Control:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return spacer
