extends Control
## Main menu scene — shown before Main.tscn at game start.
##
## ============================================================================
## HOW TO EDIT THIS MENU
## ============================================================================
## Two kinds of edits, two places to make them:
##
## 1. TEXT and FONT SIZES — edit the Label nodes DIRECTLY in the scene tree.
##    Click TitleLine1 / TitleLine2 / SubtitleLabel / TagLabel / VersionLabel
##    / StudioLabel / SubjectTagLabel / Keys in the Scene panel, then change
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
## Format: ["id", "LABEL", "hotkey"]
## IDs the script knows about: "new", "endless", "load", "settings", "quit"
##
## Typed as plain Array (not Array[Array]) because Godot 4 exports don't
## support nested typed arrays — the Inspector would refuse to load it.
@export var menu_items: Array = [
	["new",      "New Game",  "1"],
	["endless",  "Endless",   "2"],
	["load",     "Load Game", "3"],
	["settings", "Settings",  "4"],
	["quit",     "Quit",      "5"],
]

# --- VISUAL EFFECTS ---
@export_group("Visual Effects")
## CRT scanline overlay. Already used elsewhere in the game; leave on for
## consistency.
@export var show_scanlines: bool = true:
	set(value):
		show_scanlines = value
		if is_inside_tree():
			scanline_layer.visible = value
## Subtle brightness flicker, fires every ~7s. Disable for "reduced motion".
@export var show_flicker: bool = true
## Rising ember particles in the background.
@export var show_embers: bool = true:
	set(value):
		show_embers = value
		if is_inside_tree():
			embers_layer.visible = value
## How many embers to spawn. More = denser atmosphere, slightly more CPU.
@export_range(0, 60, 1) var ember_count: int = 22
## Color of the rising embers and the warning-tag accent text.
@export var accent_soft_color: Color = Color("f0a060"):
	set(value):
		accent_soft_color = value
		if is_inside_tree():
			subject_tag_label.add_theme_color_override("font_color", value)

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


# =============================================================================
# NODE REFS — resolved at _ready via unique_name_in_owner.
# Note: there are no @onready refs for TitleLine1 / SubtitleLabel / etc
# anymore because the script no longer touches their text. Edit them in the
# scene tree.
# =============================================================================

@onready var subject_tag_label: Label    = %SubjectTagLabel
@onready var menu_list: VBoxContainer    = %MenuList
@onready var scanline_layer: CanvasLayer = $ScanlineLayer
@onready var embers_layer: Control       = %EmbersLayer

# Overlay panels — built on demand by _open_overlay().
var _current_overlay: Control = null

# Internal: which menu row is currently focused.
var _hovered_id: String = ""


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Apply only the things that actually need code wiring. Text and font
	# sizes come straight from the .tscn — we don't touch them.
	scanline_layer.visible = show_scanlines
	embers_layer.visible   = show_embers

	# Accent color override is one-shot at startup; the setter handles
	# live edits via script.
	subject_tag_label.add_theme_color_override("font_color", accent_soft_color)

	_build_menu()

	if show_embers:
		_spawn_embers()
	if show_flicker:
		_start_flicker()

	# Focus the first row so keyboard navigation starts somewhere.
	if menu_list.get_child_count() > 0:
		var first: Button = menu_list.get_child(0) as Button
		if first:
			first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# If an overlay is open, ESC closes it.
	if _current_overlay and is_instance_valid(_current_overlay):
		if event.keycode == KEY_ESCAPE:
			_close_overlay()
			get_viewport().set_input_as_handled()
		return

	# Number-key hotkeys map to menu rows by position.
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var idx: int = event.keycode - KEY_1
		if idx < menu_items.size():
			var item: Array = menu_items[idx]
			if item.size() >= 1:
				_activate(String(item[0]))
				get_viewport().set_input_as_handled()
		return



# =============================================================================
# MENU BUILDING
# =============================================================================

func _build_menu() -> void:
	for child in menu_list.get_children():
		child.queue_free()

	for i in menu_items.size():
		var item: Array = menu_items[i]
		if item.size() < 3:
			push_warning("MainMenu: menu_items[%d] needs [id, label, hotkey]" % i)
			continue
		var row := _build_menu_row(String(item[0]), String(item[1]), String(item[2]))
		menu_list.add_child(row)


## A plain Button picks up the project's default Button theme from
## main_theme.tres — same styling used everywhere else.
func _build_menu_row(id: String, label: String, hotkey: String) -> Button:
	var btn := Button.new()
	btn.name = "MenuRow_" + id
	btn.text = "%s    [%s]" % [label.to_upper(), hotkey]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 60)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL

	btn.pressed.connect(_activate.bind(id))
	btn.mouse_entered.connect(_on_row_hover.bind(id, btn))
	btn.focus_entered.connect(_on_row_hover.bind(id, btn))
	return btn


# =============================================================================
# INTERACTION
# =============================================================================

func _on_row_hover(id: String, _btn: Button) -> void:
	_hovered_id = id


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
	# Endless mode currently uses the same Main scene. When endless-specific
	# rules exist, set a GameState flag here before changing scenes.
	var intro: Node = get_node_or_null("/root/IntroTransition")
	if intro:
		intro.pending_intro = true
	get_tree().change_scene_to_file(game_scene_path)


## Kept for completeness — used by other parts of the script that may want
## to check for an autoload's presence by name.
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

	content.add_child(_build_slider_row("MUSIC", 70))
	content.add_child(_build_slider_row("SFX",   85))
	content.add_child(_build_slider_row("BRIGHTNESS", 50))

	var apply_row := HBoxContainer.new()
	apply_row.alignment = BoxContainer.ALIGNMENT_END
	var apply_btn := Button.new()
	apply_btn.text = "APPLY"
	apply_btn.pressed.connect(_close_overlay)
	apply_row.add_child(apply_btn)
	content.add_child(apply_row)

	return shell["back"]


func _build_slider_row(label_text: String, initial: int) -> HBoxContainer:
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
	row.add_child(slider)
	return row


func _build_quit_confirm() -> Control:
	var shell: Dictionary = _build_overlay_shell("LEAVE HER ALONE?")
	var content: VBoxContainer = shell["content"]

	var body := Label.new()
	body.text = "Unsaved progress will be lost.\nShe will be waiting."
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
	quit.pressed.connect(func(): get_tree().quit())
	btn_row.add_child(quit)

	content.add_child(btn_row)
	return shell["back"]


# =============================================================================
# AMBIENT EFFECTS — embers and flicker.
# =============================================================================

func _spawn_embers() -> void:
	for child in embers_layer.get_children():
		child.queue_free()

	embers_layer.anchor_right = 1.0
	embers_layer.anchor_bottom = 1.0

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in ember_count:
		var ember := ColorRect.new()
		ember.color = accent_soft_color
		var size_px: float = 1.0 + rng.randf() * 2.0
		ember.size = Vector2(size_px, size_px)
		ember.position = Vector2(
			rng.randf() * get_viewport_rect().size.x,
			get_viewport_rect().size.y + 10.0,
		)
		ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
		embers_layer.add_child(ember)
		_animate_ember(ember, rng)


func _animate_ember(ember: ColorRect, rng: RandomNumberGenerator) -> void:
	var duration: float = 14.0 + rng.randf() * 14.0
	var drift: float = (rng.randf() - 0.5) * 120.0
	var start_x: float = ember.position.x
	var start_y: float = ember.position.y
	var end_y: float = -20.0

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(ember, "position",
		Vector2(start_x + drift, end_y), duration
	).from(Vector2(start_x, start_y))
	tween.parallel().tween_property(ember, "modulate:a", 0.0, duration * 0.3)\
		.from(0.0)\
		.set_delay(duration * 0.1)
	tween.parallel().tween_property(ember, "modulate:a", 0.0, duration * 0.3)\
		.set_delay(duration * 0.7)


func _start_flicker() -> void:
	# Brightness flicker via modulate. CSS filter:brightness equivalent.
	var tween := create_tween()
	tween.set_loops()
	tween.tween_interval(6.5)
	tween.tween_property(self, "modulate", Color(0.78, 0.78, 0.78), 0.04)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.08)
	tween.tween_interval(0.3)
	tween.tween_property(self, "modulate", Color(0.88, 0.88, 0.88), 0.04)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.08)
