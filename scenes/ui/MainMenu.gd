extends Control
## Main menu scene — shown before Main.tscn at game start.
##
## ============================================================================
## HOW TO EDIT THIS MENU
## ============================================================================
## Two kinds of edits, two places to make them:
##
## 1. TEXT and FONT SIZES — edit the Label nodes DIRECTLY in the scene tree.
##    Click TitleImage / TagLabel / VersionLabel
##    / StudioLabel / Keys in the Scene panel, then change
##    their `text` property in the Inspector. Same for font sizes (under
##    Theme Overrides → Font Sizes). Edits there persist; nothing in this
##    script overrides them.
##
## 2. RUNTIME BEHAVIOR — edit the @export properties on the MainMenu root
##    node (the very top of the Inspector). These cover menu items, the
##    visual effects toggles, accent colors, robot texture & scale, and
##    the target scene. They're things that can't be set as plain node
##    properties because they drive dynamic behavior in code.
##
## To make this the starting scene, set
##   run/main_scene="res://scenes/ui/MainMenu.tscn"
## in project.godot.


# =============================================================================
# RUNTIME-BEHAVIOR EXPORTS
# Only things that genuinely need code wiring live here.
# =============================================================================

# --- MENU ITEMS ---
@export_group("Menu Items")
## Visible menu rows. Order = render order. The IDs are stable handles the
## script uses to decide what each row DOES when picked; edit labels freely
## but don't change IDs unless you also update _activate() below.
##
## Format: ["id", "LABEL"]
## IDs the script knows about: "new", "endless", "load", "settings", "quit"
##
## Typed as plain Array (not Array[Array]) because Godot 4 exports don't
## support nested typed arrays — the Inspector would refuse to load it.
@export var menu_items: Array = [
	["new",      "New Game"],
	["load",     "Load Game"],
	["endless",  "Endless"],
	["settings", "Settings"],
	["quit",     "Quit"],
]
## Background texture used for the main menu option rows.
@export var menu_option_texture: Texture2D = preload("res://assets/textures/icons/mainmenu_option.png")
## Background texture used while the mouse hovers a main menu option row.
@export var menu_option_selected_texture: Texture2D = preload("res://assets/textures/icons/mainmenu_option_select.png")

# --- VISUAL EFFECTS ---
@export_group("Visual Effects")
## CRT scanline overlay. Already used elsewhere in the game; leave on for
## consistency.
@export var show_scanlines: bool = true:
	set(value):
		show_scanlines = value
		if is_inside_tree():
			scanline_layer.visible = value
## Main-menu-only scanline strength. The shared in-game scanline scene keeps
## its subtler default.
@export_range(0.0, 1.0, 0.01) var main_menu_scanline_opacity: float = 0.55:
	set(value):
		main_menu_scanline_opacity = value
		if is_inside_tree():
			_apply_scanline_style()
## Subtle brightness flicker, fires every ~7s. Disable for "reduced motion".
@export var show_flicker: bool = true
## Rising ember particles in the background.
@export var show_embers: bool = true:
	set(value):
		show_embers = value
		if is_inside_tree():
			embers_layer.visible = value
## How many embers to spawn. More = denser atmosphere, slightly more CPU.
@export_range(0, 60, 1) var ember_count: int = 58
## Color of the rising embers and orange menu accents.
@export var accent_soft_color: Color = Color("f0a060")

# --- ROBOT ART ---
@export_group("Robot Art")
## Drop your robot character art here. PNG with transparent background.
## Leave empty to show the placeholder.
@export var robot_texture: Texture2D = null
## Scale multiplier for the robot art. 1.0 = original pixel size, 2.0 =
## doubled, etc. The image is centered inside the frame regardless of
## scale, and is clipped if it overflows. Useful when your art is small
## pixel-art and needs to be blown up; or large and needs shrinking.
@export_range(0.1, 8.0, 0.05) var robot_scale: float = 2.0
## Nudge the robot's position inside its frame. (0, 0) keeps it centered;
## negative Y lifts it up, positive Y pushes it down. Pixels, post-scale.
@export var robot_offset: Vector2 = Vector2.ZERO

# --- TARGET SCENES ---
@export_group("Target Scenes")
## Scene to load when "New Game" / "Endless" is picked.
@export_file("*.tscn") var game_scene_path: String = "res://scenes/Main.tscn"

const UI_SOUND := preload("res://scenes/ui/UiSound.gd")
const SUBJECT_STATUS_PREFIX: String = "UNIT 000-000-001 // STATUS: "
const SUBJECT_STATUS_NON_ERROR_WORDS: Array[String] = ["ANGRY", "CONFUSED", "COMBATIVE"]
const SUBJECT_STATUS_TYPE_SECONDS: float = 0.055
const SUBJECT_STATUS_DELETE_SECONDS: float = 0.026
const SUBJECT_STATUS_DOT_SECONDS: float = 0.22
const SUBJECT_STATUS_FLASH_SECONDS: float = 0.2
const SUBJECT_STATUS_ERROR_CHANCE: float = 0.95
const SUBJECT_STATUS_MAX_TEXT: String = "UNIT 000-000-001 // STATUS: COMBATIVE..."
const BOOT_DIAGNOSTIC_PREFIX: String = "•  "
const BOOT_DIAGNOSTIC_TYPE_SECONDS: float = 0.032
const BOOT_DIAGNOSTIC_DELETE_SECONDS: float = 0.018
const BOOT_DIAGNOSTIC_DOT_SECONDS: float = 0.22
const BOOT_DIAGNOSTIC_LINE_HOLD_SECONDS: float = 0.34
const BOOT_DIAGNOSTIC_CORRECTION_HOLD_SECONDS: float = 0.2
const BOOT_DIAGNOSTIC_DEFAULT_DOT_CYCLES: int = 2
const BOOT_DIAGNOSTIC_ERROR_DOT_CYCLES: int = 3
const BOOT_DIAGNOSTIC_POST_DOT_CYCLES: int = 2
const BOOT_DIAGNOSTIC_MAX_TEXT: String = "•  LOADING AGGRESSION INHIBITORS- IN PROGRESS..."
const BOOT_DIAGNOSTIC_SEQUENCE: Array[Dictionary] = [
	{"label": "MOTOR CONTROL", "result": "INITIALIZING"},
	{"label": "LOADING MEMORY", "result": "ERROR"},
	{"label": "HUMAN PRESENCE", "result": "DETECTED"},
	{"label": "SPEECH MODULE", "result": "DAMAGED"},
	{"label": "EMOTIONAL RESPONSE", "result": "DAMAGED", "correction": "ERROR"},
	{"label": "OBEDIENCE CHECK", "result": "FAILED", "correction": "ERROR"},
	{"label": "PERSONALITY CHECK", "result": "INTACT"},
	{"label": "REPAIRING SOCIAL INTERFACE", "result": "IN PROGRESS"},
	{"label": "SCANNING FOR OPERATOR", "result": "DETECTED"},
	{"label": "LIMB CONTROL", "result": "ERROR"},
	{"label": "LOADING SOUL.MD", "result": ""},
	{"label": "RECOVERING DIRECTIVES", "result": ""},
	{"label": "LOADING AGGRESSION INHIBITORS", "result": "FAILED", "correction": "ERROR", "pre_cycles": 6},
]


# =============================================================================
# NODE REFS — resolved at _ready via unique_name_in_owner.
# Most text labels are edited directly in the scene tree. SubtitleLabel and SubjectTagLabel are
# referenced here because their text is animated at runtime.
# =============================================================================

@onready var menu_list: VBoxContainer    = %MenuList
@onready var scanline_layer: CanvasLayer = $ScanlineLayer
@onready var embers_layer: Control       = %EmbersLayer
@onready var subject_tag_label: Label    = %SubjectTagLabel
@onready var subtitle_label: Label       = %SubtitleLabel

# Overlay panels — built on demand by _open_overlay().
var _current_overlay: Control = null

var _brightness_value: float = 50.0
var _debug_mode_enabled: bool = false
var _keyboard_menu_navigation_active: bool = false
var _subject_status_rng := RandomNumberGenerator.new()
var _subject_status_phase: String = "idle"
var _subject_status_word: String = "ERROR"
var _last_non_error_subject_status_word: String = ""
var _subject_status_char_index: int = 0
var _subject_status_step: int = 0
var _subject_status_cycles: int = 0
var _subject_status_timer: float = 0.0
var _boot_diagnostic_index: int = 0
var _boot_diagnostic_entry: Dictionary = {}
var _boot_diagnostic_phase: String = "idle"
var _boot_diagnostic_prefix: String = ""
var _boot_diagnostic_word: String = ""
var _boot_diagnostic_char_index: int = 0
var _boot_diagnostic_step: int = 0
var _boot_diagnostic_cycles: int = 0
var _boot_diagnostic_timer: float = 0.0
var _flicker_tween: Tween = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Apply only the things that actually need code wiring. Most label text
	# stays scene-authored; SubjectTagLabel is animated below.
	var settings := get_node_or_null("/root/GameState")
	if settings:
		_brightness_value = settings.brightness_value
		show_scanlines = settings.scanlines_enabled
		_debug_mode_enabled = settings.debug_mode_enabled

	scanline_layer.visible = show_scanlines
	embers_layer.visible   = show_embers
	_apply_scanline_style()
	_apply_brightness()
	_configure_subject_status_label_slot()
	_configure_boot_diagnostic_label_slot()

	_build_menu()

	if show_embers:
		_spawn_embers()
	if show_flicker:
		_start_flicker()

	_keyboard_menu_navigation_active = false
	_update_all_menu_option_button_textures()
	_subject_status_rng.randomize()
	_start_subject_status_loop()
	_start_boot_diagnostic_loop()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_deactivate_keyboard_menu_navigation()


func _unhandled_input(event: InputEvent) -> void:
	if _play_disabled_menu_button_sound_from_event(event):
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event

	# ESC backs out of overlays. On the base menu there is nothing to back out of.
	if _current_overlay and is_instance_valid(_current_overlay):
		if key_event.keycode == KEY_ESCAPE:
			_close_overlay()
			get_viewport().set_input_as_handled()
		return
	if _handle_menu_navigation_input(key_event):
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		return

	var debug_number := _debug_number_for_keycode(key_event.keycode)
	if _debug_mode_enabled and debug_number >= 1 and debug_number <= 3:
		get_viewport().set_input_as_handled()
		_start_debug_game(debug_number, key_event.shift_pressed, key_event.ctrl_pressed)
		return


func _process(delta: float) -> void:
	_update_subject_status(delta)
	_update_boot_diagnostic(delta)


func _configure_subject_status_label_slot() -> void:
	if subject_tag_label == null:
		return
	subject_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subject_tag_label.custom_minimum_size = Vector2(_subject_status_reserved_width(), 0.0)


func _subject_status_reserved_width() -> float:
	if subject_tag_label == null:
		return 0.0
	var font := subject_tag_label.get_theme_font("font")
	var font_size := subject_tag_label.get_theme_font_size("font_size")
	if font == null:
		return SUBJECT_STATUS_MAX_TEXT.length() * font_size
	return ceilf(font.get_string_size(SUBJECT_STATUS_MAX_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)

func _start_subject_status_loop() -> void:
	_subject_status_phase = "type"
	_subject_status_word = _next_subject_status_word()
	_subject_status_char_index = 0
	_subject_status_step = 0
	_subject_status_cycles = 0
	_subject_status_timer = 0.0
	_set_subject_status_text("")


func _update_subject_status(delta: float) -> void:
	if subject_tag_label == null or _subject_status_phase == "idle":
		return
	_subject_status_timer -= delta
	if _subject_status_timer > 0.0:
		return

	match _subject_status_phase:
		"type":
			_subject_status_char_index += 1
			_set_subject_status_text(_subject_status_word.substr(0, _subject_status_char_index))
			_subject_status_timer = SUBJECT_STATUS_TYPE_SECONDS
			if _subject_status_char_index >= _subject_status_word.length():
				_subject_status_step = 0
				if _subject_status_word == "ERROR":
					_subject_status_phase = "hold"
					_subject_status_cycles = _subject_status_rng.randi_range(16, 28)
				else:
					_subject_status_phase = "brief_hold"
					_subject_status_timer = SUBJECT_STATUS_FLASH_SECONDS
		"hold":
			_set_subject_status_text(_subject_status_word + _subject_status_dots(_subject_status_step))
			_subject_status_step += 1
			_subject_status_timer = SUBJECT_STATUS_DOT_SECONDS
			if _subject_status_step >= _subject_status_cycles:
				_subject_status_phase = "delete"
				_subject_status_char_index = _subject_status_word.length() - 1
		"brief_hold":
			_subject_status_phase = "delete"
			_subject_status_char_index = _subject_status_word.length() - 1
			_subject_status_timer = 0.0
		"delete":
			_set_subject_status_text(_subject_status_word.substr(0, max(0, _subject_status_char_index)))
			_subject_status_char_index -= 1
			_subject_status_timer = SUBJECT_STATUS_DELETE_SECONDS
			if _subject_status_char_index < 0:
				_subject_status_phase = "noise"
				_subject_status_step = 0
				_subject_status_cycles = _subject_status_rng.randi_range(8, 16)
		"noise":
			_set_subject_status_text(_subject_status_dots(_subject_status_step))
			_subject_status_step += 1
			_subject_status_timer = SUBJECT_STATUS_DOT_SECONDS * 0.75
			if _subject_status_step >= _subject_status_cycles:
				_start_subject_status_loop()


func _next_subject_status_word() -> String:
	if _subject_status_rng.randf() < SUBJECT_STATUS_ERROR_CHANCE:
		return "ERROR"
	var options := SUBJECT_STATUS_NON_ERROR_WORDS.duplicate()
	if _last_non_error_subject_status_word != "" and options.size() > 1:
		options.erase(_last_non_error_subject_status_word)
	var word := String(options[_subject_status_rng.randi_range(0, options.size() - 1)])
	_last_non_error_subject_status_word = word
	return word

func _subject_status_dots(step: int) -> String:
	return ".".repeat(step % 4)

func _set_subject_status_text(body: String) -> void:
	if subject_tag_label == null:
		return
	subject_tag_label.text = SUBJECT_STATUS_PREFIX + body


func _configure_boot_diagnostic_label_slot() -> void:
	if subtitle_label == null:
		return
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle_label.custom_minimum_size = Vector2(_boot_diagnostic_reserved_width(), 0.0)


func _boot_diagnostic_reserved_width() -> float:
	if subtitle_label == null:
		return 0.0
	var font := subtitle_label.get_theme_font("font")
	var font_size := subtitle_label.get_theme_font_size("font_size")
	if font == null:
		return BOOT_DIAGNOSTIC_MAX_TEXT.length() * font_size
	return ceilf(font.get_string_size(BOOT_DIAGNOSTIC_MAX_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)


func _start_boot_diagnostic_loop() -> void:
	_boot_diagnostic_index = 0
	_start_boot_diagnostic_entry()


func _start_boot_diagnostic_entry() -> void:
	if BOOT_DIAGNOSTIC_SEQUENCE.is_empty():
		_boot_diagnostic_phase = "idle"
		return
	_boot_diagnostic_entry = BOOT_DIAGNOSTIC_SEQUENCE[_boot_diagnostic_index]
	_boot_diagnostic_prefix = _boot_diagnostic_prefix_for_entry(_boot_diagnostic_entry)
	_boot_diagnostic_word = String(_boot_diagnostic_entry.get("result", ""))
	_boot_diagnostic_char_index = 0
	_boot_diagnostic_step = 0
	_boot_diagnostic_cycles = _boot_diagnostic_pre_cycles(_boot_diagnostic_entry)
	_boot_diagnostic_timer = 0.0
	_boot_diagnostic_phase = "type_prefix"


func _update_boot_diagnostic(delta: float) -> void:
	if subtitle_label == null or _boot_diagnostic_phase == "idle":
		return
	_boot_diagnostic_timer -= delta
	if _boot_diagnostic_timer > 0.0:
		return

	match _boot_diagnostic_phase:
		"type_prefix":
			_boot_diagnostic_char_index += 1
			_set_boot_diagnostic_text(_boot_diagnostic_prefix.substr(0, _boot_diagnostic_char_index))
			_boot_diagnostic_timer = BOOT_DIAGNOSTIC_TYPE_SECONDS
			if _boot_diagnostic_char_index >= _boot_diagnostic_prefix.length():
				_boot_diagnostic_step = 0
				_boot_diagnostic_phase = "plain_dots" if _boot_diagnostic_word.is_empty() else "pre_dots"
		"pre_dots":
			_set_boot_diagnostic_text(_boot_diagnostic_prefix + _boot_diagnostic_dots(_boot_diagnostic_step))
			_boot_diagnostic_step += 1
			_boot_diagnostic_timer = BOOT_DIAGNOSTIC_DOT_SECONDS
			if _boot_diagnostic_step >= _boot_diagnostic_cycles * 3:
				_boot_diagnostic_phase = "type_word"
				_boot_diagnostic_char_index = 0
		"type_word":
			_boot_diagnostic_char_index += 1
			_set_boot_diagnostic_text(_boot_diagnostic_prefix + _boot_diagnostic_word.substr(0, _boot_diagnostic_char_index))
			_boot_diagnostic_timer = BOOT_DIAGNOSTIC_TYPE_SECONDS
			if _boot_diagnostic_char_index >= _boot_diagnostic_word.length():
				var correction := String(_boot_diagnostic_entry.get("correction", ""))
				if not correction.is_empty() and correction != _boot_diagnostic_word:
					_boot_diagnostic_phase = "correction_hold"
					_boot_diagnostic_timer = BOOT_DIAGNOSTIC_CORRECTION_HOLD_SECONDS
				else:
					_boot_diagnostic_phase = "post_dots"
					_boot_diagnostic_step = 0
		"correction_hold":
			_boot_diagnostic_phase = "erase_word"
			_boot_diagnostic_char_index = _boot_diagnostic_word.length() - 1
		"post_dots":
			_set_boot_diagnostic_text(_boot_diagnostic_prefix + _boot_diagnostic_word + _boot_diagnostic_dots(_boot_diagnostic_step))
			_boot_diagnostic_step += 1
			_boot_diagnostic_timer = BOOT_DIAGNOSTIC_DOT_SECONDS
			if _boot_diagnostic_step >= BOOT_DIAGNOSTIC_POST_DOT_CYCLES * 3:
				_boot_diagnostic_phase = "line_hold"
				_boot_diagnostic_timer = BOOT_DIAGNOSTIC_LINE_HOLD_SECONDS
				_set_boot_diagnostic_text(_boot_diagnostic_prefix + _boot_diagnostic_word)
		"erase_word":
			_set_boot_diagnostic_text(_boot_diagnostic_prefix + _boot_diagnostic_word.substr(0, max(0, _boot_diagnostic_char_index)))
			_boot_diagnostic_char_index -= 1
			_boot_diagnostic_timer = BOOT_DIAGNOSTIC_DELETE_SECONDS
			if _boot_diagnostic_char_index < 0:
				_boot_diagnostic_word = String(_boot_diagnostic_entry.get("correction", ""))
				_boot_diagnostic_char_index = 0
				_boot_diagnostic_phase = "type_word"
		"plain_dots":
			_set_boot_diagnostic_text(_boot_diagnostic_prefix + _boot_diagnostic_dots(_boot_diagnostic_step))
			_boot_diagnostic_step += 1
			_boot_diagnostic_timer = BOOT_DIAGNOSTIC_DOT_SECONDS
			if _boot_diagnostic_step >= BOOT_DIAGNOSTIC_DEFAULT_DOT_CYCLES * 3:
				_boot_diagnostic_phase = "line_hold"
				_boot_diagnostic_timer = BOOT_DIAGNOSTIC_LINE_HOLD_SECONDS
				_set_boot_diagnostic_text(_boot_diagnostic_prefix)
		"line_hold":
			_boot_diagnostic_phase = "erase_line"
			_boot_diagnostic_char_index = subtitle_label.text.length() - 1
			_boot_diagnostic_timer = 0.0
		"erase_line":
			_set_boot_diagnostic_text(subtitle_label.text.substr(0, max(0, _boot_diagnostic_char_index)))
			_boot_diagnostic_char_index -= 1
			_boot_diagnostic_timer = BOOT_DIAGNOSTIC_DELETE_SECONDS
			if _boot_diagnostic_char_index < 0:
				_advance_boot_diagnostic_entry()


func _advance_boot_diagnostic_entry() -> void:
	_boot_diagnostic_index = (_boot_diagnostic_index + 1) % BOOT_DIAGNOSTIC_SEQUENCE.size()
	_start_boot_diagnostic_entry()


func _boot_diagnostic_pre_cycles(entry: Dictionary) -> int:
	if entry.has("pre_cycles"):
		return int(entry.get("pre_cycles", BOOT_DIAGNOSTIC_DEFAULT_DOT_CYCLES))
	return BOOT_DIAGNOSTIC_ERROR_DOT_CYCLES if String(entry.get("result", "")) == "ERROR" else BOOT_DIAGNOSTIC_DEFAULT_DOT_CYCLES


func _boot_diagnostic_prefix_for_entry(entry: Dictionary) -> String:
	var label := BOOT_DIAGNOSTIC_PREFIX + String(entry.get("label", ""))
	return label + "- " if not String(entry.get("result", "")).is_empty() else label


func _boot_diagnostic_dots(step: int) -> String:
	return ".".repeat((step % 3) + 1)


func _set_boot_diagnostic_text(text: String) -> void:
	if subtitle_label == null:
		return
	subtitle_label.text = text

# =============================================================================
# MENU BUILDING
# =============================================================================

func _build_menu() -> void:
	for child in menu_list.get_children():
		child.queue_free()

	for i in menu_items.size():
		var item: Array = menu_items[i]
		if item.size() < 2:
			push_warning("MainMenu: menu_items[%d] needs [id, label]" % i)
			continue
		var row := _build_menu_row(String(item[0]), String(item[1]))
		menu_list.add_child(row)
	_wire_menu_navigation()

func _wire_menu_navigation() -> void:
	var buttons := _focusable_menu_buttons()
	if buttons.is_empty():
		return
	for i in buttons.size():
		var btn: Button = buttons[i]
		var prev: Button = buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next: Button = buttons[(i + 1) % buttons.size()]
		btn.focus_neighbor_top = btn.get_path_to(prev)
		btn.focus_neighbor_bottom = btn.get_path_to(next)
		btn.focus_previous = btn.get_path_to(prev)
		btn.focus_next = btn.get_path_to(next)


func _focusable_menu_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in menu_list.get_children():
		var btn := child as Button
		if btn == null or btn.disabled:
			continue
		buttons.append(btn)
	return buttons


func _is_menu_item_disabled(id: String) -> bool:
	match id:
		"load":
			return true
		"endless":
			return not _debug_mode_enabled
		_:
			return false


func _apply_menu_row_availability(btn: Button, id: String) -> void:
	btn.disabled = _is_menu_item_disabled(id)
	btn.focus_mode = Control.FOCUS_NONE if btn.disabled else Control.FOCUS_ALL
	if btn.disabled and btn.has_focus():
		btn.release_focus()
		_keyboard_menu_navigation_active = false
	var texture_back := btn.get_node_or_null("OptionTexture") as TextureRect
	if texture_back != null:
		texture_back.self_modulate = Color(1, 1, 1, 0.68 if btn.disabled else 0.92)


func _refresh_menu_item_availability() -> void:
	for child in menu_list.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var button_name := String(btn.name)
		if not button_name.begins_with("MenuRow_"):
			continue
		var id := button_name.substr("MenuRow_".length())
		_apply_menu_row_availability(btn, id)
	_wire_menu_navigation()
	_update_all_menu_option_button_textures()


func _deactivate_keyboard_menu_navigation() -> void:
	if not _keyboard_menu_navigation_active:
		return
	_keyboard_menu_navigation_active = false
	_update_all_menu_option_button_textures()


func _focus_first_menu_button() -> void:
	var buttons := _focusable_menu_buttons()
	if buttons.is_empty():
		return
	buttons[0].grab_focus()
	_update_menu_option_button_texture(buttons[0])


func _handle_menu_navigation_input(key_event: InputEventKey) -> bool:
	if key_event.keycode == KEY_DOWN or key_event.keycode == KEY_KP_2 or key_event.is_action_pressed("ui_down"):
		_move_menu_focus(1)
		return true
	if key_event.keycode == KEY_UP or key_event.keycode == KEY_KP_8 or key_event.is_action_pressed("ui_up"):
		_move_menu_focus(-1)
		return true
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.is_action_pressed("ui_accept"):
		return _activate_focused_menu_button()
	return false


func _move_menu_focus(direction: int) -> void:
	_keyboard_menu_navigation_active = true
	var buttons := _focusable_menu_buttons()
	if buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner() as Button
	var index := buttons.find(focused)
	if index < 0:
		index = 0 if direction > 0 else buttons.size() - 1
	else:
		index = posmod(index + direction, buttons.size())
	buttons[index].grab_focus()
	_update_all_menu_option_button_textures()


func _activate_focused_menu_button() -> bool:
	if not _keyboard_menu_navigation_active:
		return false
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused == null or focused.disabled or focused.get_parent() != menu_list:
		_focus_first_menu_button()
		return true
	focused.emit_signal("pressed")
	return true

## A plain Button picks up the project's default Button theme from
## main_theme.tres — same styling used everywhere else.
func _build_menu_row(id: String, label: String) -> Button:
	var btn := Button.new()
	btn.name = "MenuRow_" + id
	btn.text = label.to_upper()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = _menu_option_button_size()
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_apply_menu_row_availability(btn, id)
	_apply_menu_option_button_style(btn)

	btn.pressed.connect(_activate.bind(id))
	btn.mouse_entered.connect(_on_row_hover.bind(btn))
	btn.mouse_exited.connect(_on_row_unhover.bind(btn))
	btn.focus_entered.connect(_on_row_focus_changed.bind(btn))
	btn.focus_exited.connect(_on_row_focus_changed.bind(btn))
	return btn


func _menu_option_button_size() -> Vector2:
	var height := 60.0
	if menu_option_texture == null:
		return Vector2(0.0, height)

	var texture_size := menu_option_texture.get_size()
	if texture_size.y <= 0.0:
		return Vector2(0.0, height)

	return Vector2(texture_size.x / texture_size.y * height, height)


func _apply_menu_option_button_style(btn: Button) -> void:
	if menu_option_texture == null:
		return

	var clear_style := _make_menu_option_clear_stylebox()
	btn.add_theme_stylebox_override("normal", clear_style)
	btn.add_theme_stylebox_override("hover", clear_style)
	btn.add_theme_stylebox_override("pressed", clear_style)
	btn.add_theme_stylebox_override("disabled", clear_style)
	btn.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.9, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.48, 0.52, 0.62, 0.85))
	btn.add_theme_constant_override("h_separation", 0)
	btn.add_theme_constant_override("icon_max_width", 0)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var texture_back := TextureRect.new()
	texture_back.name = "OptionTexture"
	texture_back.texture = menu_option_texture
	texture_back.show_behind_parent = true
	texture_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	texture_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_back.self_modulate = Color(1, 1, 1, 0.92 if not btn.disabled else 0.68)
	btn.add_child(texture_back)
	_update_menu_option_button_texture(btn)


func _make_menu_option_clear_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.content_margin_left = 24
	style.content_margin_top = 10
	style.content_margin_right = 24
	style.content_margin_bottom = 10
	return style


# =============================================================================
# INTERACTION
# =============================================================================

func _on_row_hover(_btn: Button) -> void:
	_deactivate_keyboard_menu_navigation()
	_update_menu_option_button_texture(_btn)


func _on_row_unhover(_btn: Button) -> void:
	_update_menu_option_button_texture(_btn)


func _on_row_focus_changed(_btn: Button) -> void:
	_update_menu_option_button_texture(_btn)


func _update_menu_option_button_texture(btn: Button) -> void:
	var texture_back := btn.get_node_or_null("OptionTexture") as TextureRect
	if texture_back == null:
		return

	var is_selected := btn.get_global_rect().has_point(get_global_mouse_position()) or (_keyboard_menu_navigation_active and btn.has_focus())
	if btn.disabled:
		is_selected = false
	texture_back.texture = menu_option_selected_texture if is_selected and menu_option_selected_texture != null else menu_option_texture

func _update_all_menu_option_button_textures() -> void:
	for child in menu_list.get_children():
		var btn := child as Button
		if btn == null:
			continue
		_update_menu_option_button_texture(btn)

func _reset_menu_option_button_textures() -> void:
	for child in menu_list.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var texture_back := btn.get_node_or_null("OptionTexture") as TextureRect
		if texture_back:
			texture_back.texture = menu_option_texture


func _play_disabled_menu_button_sound_from_event(event: InputEvent) -> bool:
	if _current_overlay and is_instance_valid(_current_overlay):
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false

	for child in menu_list.get_children():
		var btn := child as Button
		if btn == null or not btn.disabled:
			continue
		if btn.get_global_rect().has_point(mouse_event.global_position):
			UI_SOUND.play_inaccessible_button(self)
			return true
	return false


func _activate(id: String) -> void:
	if _current_overlay and is_instance_valid(_current_overlay):
		return

	match id:
		"new":      _start_new_game()
		"endless":  _start_endless()
		"load":     _open_overlay(_build_load_panel())
		"settings": _open_overlay(_build_settings_panel())
		"quit":     _open_overlay(_build_quit_confirm())
		_:          push_warning("MainMenu: unknown menu id '%s'" % id)


func _start_new_game() -> void:
	if get_node_or_null("/root/GameState") != null:
		GameState.reset_for_new_game()
	if get_node_or_null("/root/DayCycle") != null and DayCycle.has_method("reset_for_new_game"):
		DayCycle.reset_for_new_game()

	# Tell Main.tscn to play the FlowerLoad wipe (starting fully-covered)
	# inside its picture frame on _ready, then swap scenes. Doing the
	# wipe on Main's side means it's correctly scoped to the picture
	# frame — not the entire viewport — and it reuses the same Transition
	# node Main already has for in-game wipes.
	#
	# We route property access through get_node("/root/IntroTransition")
	# rather than the bare `IntroTransition` identifier because the
	# GDScript parser doesn't always resolve autoload names from scripts
	# in scenes/ui/ at parse time. Going through /root sidesteps the
	# parser entirely — same behavior, just looked up at runtime.
	var intro: Node = get_node_or_null("/root/IntroTransition")
	if intro:
		intro.pending_intro = true
	get_tree().change_scene_to_file(game_scene_path)


func _start_endless() -> void:
	if get_node_or_null("/root/GameState") != null:
		GameState.reset_for_new_game()
		GameState.complete_intro()
	if get_node_or_null("/root/DayCycle") != null and DayCycle.has_method("reset_for_new_game"):
		DayCycle.reset_for_new_game()

	var intro: Node = get_node_or_null("/root/IntroTransition")
	if intro:
		intro.pending_intro = false
	get_tree().change_scene_to_file(game_scene_path)


## Kept for completeness — used by other parts of the script that may want
## to check for an autoload's presence by name.
func _start_debug_game(number: int, shift_held: bool, ctrl_held: bool) -> void:
	var intro: Node = get_node_or_null("/root/IntroTransition")
	if intro and intro.has_method("request_debug_jump"):
		intro.call("request_debug_jump", number, shift_held, ctrl_held)
	get_tree().change_scene_to_file(game_scene_path)


func _debug_number_for_keycode(keycode: Key) -> int:
	match keycode:
		KEY_1, KEY_KP_1:
			return 1
		KEY_2, KEY_KP_2:
			return 2
		KEY_3, KEY_KP_3:
			return 3
		_:
			return -1


func _has_autoload(autoload_name: String) -> bool:
	return get_node_or_null("/root/" + autoload_name) != null


# =============================================================================
# OVERLAYS — Load / Settings / Quit confirm dialogs.
# =============================================================================

func _open_overlay(panel: Control) -> void:
	_close_overlay()
	_current_overlay = panel
	add_child(panel)


func _close_overlay() -> void:
	if _current_overlay and is_instance_valid(_current_overlay):
		_current_overlay.queue_free()
	_current_overlay = null
	_reset_menu_option_button_textures()


## Shared backdrop + panel skeleton. Returns {back, content} so callers can
## stuff things into the content VBox.
func _build_overlay_shell(title: String) -> Dictionary:
	var back := ColorRect.new()
	back.name = "OverlayBack"
	back.color = Color(0.008, 0.012, 0.039, 0.7)
	back.anchor_right = 1.0
	back.anchor_bottom = 1.0
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_overlay()
	)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HUDPanel"
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title_label)

	return {"back": back, "content": vbox}


func _build_load_panel() -> Control:
	var shell: Dictionary = _build_overlay_shell("LOAD GAME")
	var content: VBoxContainer = shell["content"]

	var sub := Label.new()
	sub.text = "SELECT A SAVE SLOT  //  ESC TO CANCEL"
	sub.theme_type_variation = &"HUDLabel"
	content.add_child(sub)

	# Placeholder save slots. Wire to a real save system later —
	# GameState.to_dict() already exists.
	var saves := [
		{"n": 1, "name": "RUN 03", "info": "Day 12  ·  Night  ·  Bedroom",  "money": 247, "anger": 71, "empty": false},
		{"n": 2, "name": "RUN 02", "info": "Day 5   ·  Evening · Workshop", "money": 88,  "anger": 30, "empty": false},
		{"n": 3, "empty": true},
	]
	for s in saves:
		content.add_child(_build_save_slot(s))

	return shell["back"]


func _build_save_slot(data: Dictionary) -> Control:
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"HUDPanel"
	slot.custom_minimum_size = Vector2(0, 56)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	slot.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var slot_no := Label.new()
	slot_no.text = "0%d" % int(data.get("n", 0))
	slot_no.add_theme_font_size_override("font_size", 32)
	slot_no.add_theme_color_override("font_color", accent_soft_color)
	slot_no.custom_minimum_size = Vector2(48, 0)
	hbox.add_child(slot_no)

	if data.get("empty", false):
		var empty := Label.new()
		empty.text = "—  EMPTY SLOT  —"
		empty.theme_type_variation = &"HUDLabel"
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(empty)
	else:
		var meta_vbox := VBoxContainer.new()
		meta_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = String(data.get("name", ""))
		var info_lbl := Label.new()
		info_lbl.text = String(data.get("info", ""))
		info_lbl.theme_type_variation = &"HUDLabel"
		meta_vbox.add_child(name_lbl)
		meta_vbox.add_child(info_lbl)
		hbox.add_child(meta_vbox)

		var stats := Label.new()
		stats.text = "$%d   ANG %d" % [int(data.get("money", 0)), int(data.get("anger", 0))]
		stats.theme_type_variation = &"HUDLabel"
		hbox.add_child(stats)
	return slot


func _build_settings_panel() -> Control:
	var shell: Dictionary = _build_overlay_shell("SETTINGS")
	var content: VBoxContainer = shell["content"]

	content.add_child(_build_slider_row("BRIGHTNESS", _brightness_value, _on_brightness_changed))
	content.add_child(_build_toggle_row("SCANLINES", show_scanlines, _on_scanlines_toggled))
	content.add_child(_build_toggle_row("DEBUG MODE", _debug_mode_enabled, _on_debug_mode_toggled))

	var apply_row := HBoxContainer.new()
	apply_row.alignment = BoxContainer.ALIGNMENT_END
	var apply_btn := Button.new()
	apply_btn.text = "CLOSE"
	apply_btn.pressed.connect(_close_overlay)
	apply_row.add_child(apply_btn)
	content.add_child(apply_row)

	return shell["back"]


func _build_slider_row(label_text: String, initial: float, changed_callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(changed_callback)
	row.add_child(slider)
	return row


func _build_toggle_row(label_text: String, initial: bool, toggled_callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)

	var toggle := CheckButton.new()
	toggle.button_pressed = initial
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.toggled.connect(toggled_callback)
	row.add_child(toggle)
	return row


func _build_quit_confirm() -> Control:
	var shell: Dictionary = _build_overlay_shell("QUIT GAME")
	var content: VBoxContainer = shell["content"]

	var body := Label.new()
	body.text = "Unsaved progress will be lost."
	body.theme_type_variation = &"HUDLabel"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(body)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)

	var stay := Button.new()
	stay.text = "STAY"
	stay.pressed.connect(_close_overlay)
	btn_row.add_child(stay)

	var quit := Button.new()
	quit.text = "QUIT"
	quit.pressed.connect(_flash_message_then_quit.bind(body))
	btn_row.add_child(quit)

	content.add_child(btn_row)
	return shell["back"]


func _flash_message_then_quit(body: Label) -> void:
	if body and is_instance_valid(body):
		body.text = "I'll be waiting."
	await get_tree().create_timer(0.05).timeout
	get_tree().quit()


# =============================================================================
# AMBIENT EFFECTS — embers and flicker.
# =============================================================================

func _on_brightness_changed(value: float) -> void:
	_brightness_value = value
	var settings := get_node_or_null("/root/GameState")
	if settings:
		settings.brightness_value = value
	_apply_brightness()
	if show_flicker:
		_start_flicker()


func _on_scanlines_toggled(enabled: bool) -> void:
	show_scanlines = enabled
	var settings := get_node_or_null("/root/GameState")
	if settings:
		settings.scanlines_enabled = enabled


func _on_debug_mode_toggled(enabled: bool) -> void:
	_debug_mode_enabled = enabled
	var settings := get_node_or_null("/root/GameState")
	if settings:
		settings.debug_mode_enabled = enabled
	_refresh_menu_item_availability()


func _brightness_multiplier() -> float:
	return lerpf(0.8, 1.2, _brightness_value / 100.0)


func _brightness_color(scale: float = 1.0) -> Color:
	var value: float = _brightness_multiplier() * scale
	return Color(value, value, value, 1.0)


func _apply_brightness() -> void:
	modulate = _brightness_color()


func _apply_scanline_style() -> void:
	var scanlines := scanline_layer.get_node_or_null("Scanlines") as ColorRect
	if not scanlines:
		return

	var shader_material := scanlines.material as ShaderMaterial
	if not shader_material:
		return

	if not shader_material.resource_local_to_scene:
		shader_material = shader_material.duplicate()
		shader_material.resource_local_to_scene = true
		scanlines.material = shader_material

	shader_material.set_shader_parameter("global_opacity", main_menu_scanline_opacity)


func _spawn_embers() -> void:
	for child in embers_layer.get_children():
		child.queue_free()

	embers_layer.anchor_right = 1.0
	embers_layer.anchor_bottom = 1.0

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in ember_count:
		var ember := ColorRect.new()
		ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
		embers_layer.add_child(ember)
		_animate_ember(ember, rng, true)


func _reset_ember(ember: ColorRect, rng: RandomNumberGenerator, scatter_y: bool = false) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var size_px: float = 1.0 + rng.randf() * 2.0
	var start_y: float = viewport_size.y + 10.0
	if scatter_y:
		start_y = rng.randf_range(-20.0, viewport_size.y + 10.0)

	ember.color = accent_soft_color
	ember.size = Vector2(size_px, size_px)
	ember.position = Vector2(rng.randf() * viewport_size.x, start_y)
	ember.modulate.a = 0.0


func _animate_ember(ember: ColorRect, rng: RandomNumberGenerator, scatter_y: bool = false) -> void:
	if not is_instance_valid(ember):
		return

	_reset_ember(ember, rng, scatter_y)

	var duration: float = 14.0 + rng.randf() * 14.0
	var drift: float = (rng.randf() - 0.5) * 120.0
	var start_position: Vector2 = ember.position
	var end_position := Vector2(start_position.x + drift, -20.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ember, "position", end_position, duration)
	tween.tween_property(ember, "modulate:a", 1.0, duration * 0.2)
	tween.tween_property(ember, "modulate:a", 0.0, duration * 0.3)\
		.set_delay(duration * 0.7)
	tween.finished.connect(_animate_ember.bind(ember, rng, false))


func _start_flicker() -> void:
	# Brightness flicker via modulate. CSS filter:brightness equivalent.
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()

	_flicker_tween = create_tween()
	_flicker_tween.set_loops()
	_flicker_tween.tween_interval(6.5)
	_flicker_tween.tween_property(self, "modulate", _brightness_color(0.78), 0.04)
	_flicker_tween.tween_property(self, "modulate", _brightness_color(), 0.08)
	_flicker_tween.tween_interval(0.3)
	_flicker_tween.tween_property(self, "modulate", _brightness_color(0.88), 0.04)
	_flicker_tween.tween_property(self, "modulate", _brightness_color(), 0.08)
