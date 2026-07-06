extends Control
## Root scene script.
##
## Responsibilities:
## - Display persistent HUD (day, phase, money, suspicion, anger)
## - Show location-selection screen filtered by current phase
## - Instantiate the chosen location scene and listen for its `finished` signal
## - Apply the location's result to GameState
## - Advance the day cycle (unless skip_advance was set)
## - Toggle the debug event-log overlay with Tab.
## - Run a FlowerLoad transition INSIDE THE PICTURE BOX between scene swaps.
##   HUD and buttons snap instantly; the framed background change happens at
##   frame 9/17, while the wipe hides it.
## - Animate the SceneImage's frame size between locations whose preferred
##   sizes differ (e.g. School at 900x225 -> Work at 900x720). Eases in/out
##   over ANIM_DURATION seconds.
## - Expose animate_layout_change() so locations can wrap layout-changing
##   operations (text box / choice grid appearing or disappearing) in a
##   tweened slide instead of letting the container chain snap.
##
## Locations themselves are dumb - they emit a result dict and Main applies it.

const LOCATION_RESOURCE_PATHS: Array[String] = [
	"res://resources/locations/school.tres",
	"res://resources/locations/work.tres",
	"res://resources/locations/maintenance.tres",
	"res://resources/locations/store.tres",
	"res://resources/locations/workshop.tres",
	"res://resources/locations/stress_test.tres",
	"res://resources/locations/sleep.tres",
	"res://resources/locations/personality_training.tres",
]

## Background shown on the selection screen for each phase.
## Keyed by DayCycle.Phase int values (0=Morning, 1=Evening, 2=Night).
## Missing entries fall back to the default placeholder.
const PHASE_BACKGROUNDS: Dictionary = {
	0: preload("res://assets/textures/backgrounds/bedroom_morning.png"),
	1: preload("res://assets/textures/backgrounds/bedroom_evening.png"),
	2: preload("res://assets/textures/backgrounds/bedroom_night.png"),
}
const DISABLED_LOCATION_IDS: Dictionary = {
	&"maintenance": true,
	&"personality_training": true,
}
const EVENING_DISABLED_BEDROOM_OPTIONS: Array[String] = [
	"Laptop",
]
const WORK_LOCATION_ID: StringName = &"work"
const STRESS_TEST_LOCATION_ID: StringName = &"stress_test"
const SKIPPED_STRESS_TEST_ANGER_DELTA: int = 20
const INTRO_DIALOGUE_SCENE_PATH: String = "res://scenes/locations/IntroDialogue.tscn"
const INTRO_DIALOGUE_LOCATION_ID: StringName = &"intro_dialogue"
const INTRO_STEPS: Array[Dictionary] = [
	{"step": "exposition", "kind": "dialogue", "phase": 0, "preview": "res://assets/textures/backgrounds/bedroom_morning.png"},
	{"step": "school_first", "kind": "location", "phase": 0, "location_id": &"school"},
	{"step": "evening_room", "kind": "dialogue", "phase": 1, "preview": "res://assets/textures/backgrounds/bedroom_evening.png"},
	{"step": "store", "kind": "location", "phase": 1, "location_id": &"store"},
	{"step": "store_outro", "kind": "dialogue", "phase": 1, "preview": "res://assets/textures/backgrounds/ed_shop.png"},
	{"step": "bedroom_night", "kind": "dialogue", "phase": 2, "preview": "res://assets/textures/backgrounds/bedroom_night.png"},
	{"step": "sleep", "kind": "location", "phase": 2, "location_id": &"sleep"},
	{"step": "work", "kind": "location", "phase": 0, "location_id": &"work"},
	{"step": "pre_workshop", "kind": "dialogue", "phase": 1, "preview": "res://assets/textures/backgrounds/bedroom_evening.png"},
	{"step": "workshop", "kind": "location", "phase": 1, "location_id": &"workshop"},
	{"step": "pre_stress_test", "kind": "dialogue", "phase": 2, "preview": "res://assets/textures/backgrounds/large_workshop.png", "preview_region": Rect2(0, 0, 500, 125)},
	{"step": "pre_stress_test_bedroom", "kind": "dialogue", "phase": 2, "preview": "res://assets/textures/backgrounds/bedroom_night.png"},
	{"step": "stress_test", "kind": "location", "phase": 2, "location_id": &"stress_test"},
	{"step": "robot_first_talk", "kind": "dialogue", "phase": 2, "preview": "res://assets/textures/backgrounds/robot_eyes_shut.png"},
	{"step": "free_reign", "kind": "dialogue", "phase": 0, "preview": "res://assets/textures/backgrounds/bedroom_morning.png"},
]

const INVENTORY_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/InventoryOverlay.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/Transition.tscn")
const MOUSE_TOOLTIP_SCRIPT: GDScript = preload("res://scenes/ui/MouseFollowTooltip.gd")
const UI_SOUND := preload("res://scenes/ui/UiSound.gd")

## Default authored size of the framed scene image. Standard 500x125 scene
## textures are normalized to STANDARD_SCENE_TEXTURE_SCALE at runtime, and
## locations with taller source art can override via LocationData.frame_size.
const DEFAULT_FRAME_SIZE: Vector2 = Vector2(900, 225)
const STANDARD_SCENE_TEXTURE_SIZE: Vector2 = Vector2(500, 125)
const STANDARD_SCENE_TEXTURE_SCALE: float = 2.25
const EXACT_FRAME_LOCATION_IDS: Array[StringName] = []

## "Refurbished look": standard 500x125 scenes render the picture full-bleed
## (rivet chrome hidden, image enlarged) with the HUD shown as two floating
## corner pills over the image instead of the top HUD bar. Larger scenes
## (500x400+) keep the framed presentation. The full-bleed image size below is
## sized so that image width + frame chrome == the UI content width (1152px),
## so nothing overflows. The image is shown contain/fit (no crop) inside an
## ornate gold double-border matching the dialogue box, so the frame size is
## kept at the source 4:1 aspect: 1220x305. With 20px of gold-frame chrome (8px
## outer + 2px inner-hairline inset, per side) the outer frame is 1240 wide ==
## the content width under 20px side margins, so a standard scene sits near-
## screen-wide and top-anchored with all four borders (incl. the thin inner
## hairline) visible, and the image fills it exactly (no letterbox).
const STANDARD_FULLBLEED_FRAME_SIZE: Vector2 = Vector2(1220, 305)

## UI content margins for the two presentations. The gold-framed top presentation
## uses a slim inset so the picture reads near-screen-wide with its borders
## visible and slotted to the top; the large framed presentation keeps the
## original inset.
const FRAMED_UI_MARGINS: Vector4 = Vector4(64, 24, 64, 24)
const FULLBLEED_UI_MARGINS: Vector4 = Vector4(20, 16, 20, 24)

## Ornate gold picture-frame colors, matching the dialogue box's double border.
const PICTURE_FRAME_BG: Color = Color(0.063, 0.075, 0.133, 1.0)
const PICTURE_FRAME_OUTER_GOLD: Color = Color(0.725, 0.604, 0.306, 1.0)
const PICTURE_FRAME_INNER_GOLD: Color = Color(0.91, 0.784, 0.471, 1.0)
const CHOICE_FONT_SIZE: int = 40
const CHOICE_SELECTED_TEXT: Color = Color(0.984, 0.953, 0.875)
const CHOICE_UNSELECTED_TEXT: Color = Color(0.478, 0.447, 0.353)
const CHOICE_SELECTED_BORDER: Color = Color(0.91, 0.784, 0.471)
const CHOICE_UNSELECTED_BORDER: Color = Color(0.2, 0.188, 0.165)
const CHOICE_SELECTED_BG: Color = Color(0.126, 0.11, 0.204, 1.0)
const CHOICE_GLOW: Color = Color(0.91, 0.784, 0.471, 0.28)
const STAT_CLAUSE_BBCODE_COLOR: String = "e8c878"
const PILL_MONEY_BBCODE_COLOR: String = "e8c878"
const PILL_SUS_BBCODE_COLOR: String = "e8c878"
const PILL_ANGER_BBCODE_COLOR: String = "e0906a"

## Duration and easing for both the scale animation (frame resize between
## locations) and the slide animation (layout shifts inside a location).
## TRANS_QUAD + EASE_IN_OUT gives the "soft start, soft stop" feel.
const ANIM_DURATION: float = 0.2
const ANIM_TRANS: int = Tween.TRANS_QUAD
const ANIM_EASE: int = Tween.EASE_IN_OUT
const EXPANDING_FULLSCREEN_TRANSITION_DURATION_SCALE: float = 1.0
const SHRINKING_FULLSCREEN_TARGET_OUTSET: float = 3.0
const LARGE_SCENE_HUD_FRAME_HEIGHT_THRESHOLD: float = 360.0
const LARGE_SCENE_HUD_MARGIN: Vector2 = Vector2(64.0, 24.0)
const LARGE_SCENE_HUD_PANEL_WIDTH: float = 156.0
const LARGE_SCENE_HUD_LEFT_PANEL_HEIGHT: float = 178.0
const LARGE_SCENE_HUD_RIGHT_PANEL_HEIGHT: float = 118.0
const LARGE_SCENE_HUD_RIGHT_PANEL_WORK_HEIGHT: float = 178.0
const LARGE_SCENE_HUD_FONT_SIZE: int = 32
const LARGE_SCENE_TIMER_MAX_TICKS: int = 999999
## The vertical corner panels (the "outer" HUD) are restyled to read as a set
## with the floating pills (the "inner" HUD over the image): a gold border that
## matches the stat spacers, and the same colour-coded stat values.
const LARGE_SCENE_HUD_BORDER_COLOR: Color = Color(0.725, 0.604, 0.306)
const LARGE_SCENE_HUD_PANEL_BG: Color = Color(0.059, 0.071, 0.118, 0.75)
## Stat-name colour on the corner panels (matches the DAY/EVENING rows). Only
## the numeric value is tinted with the money/suspicion/anger accent colours.
const LARGE_SCENE_HUD_NAME_COLOR: Color = Color(0.784, 0.8, 0.878)

@export_category("Debug")
@export var debug_hotkeys_enabled: bool = true

# HUD labels
@onready var ui_margin: MarginContainer = $UI
@onready var hud_bar: PanelContainer = %HUDBar
@onready var day_label: Label = %DayLabel
@onready var phase_label: Label = %PhaseLabel
@onready var money_label: Label = %MoneyLabel
@onready var suspicion_label: Label = %SuspicionLabel
@onready var anger_label: Label = %AngerLabel
@onready var scene_image: TextureRect = %SceneImage
@onready var frame_wrap: CenterContainer = $UI/VBox/FrameWrap
## The outer panel of the picture frame. We animate its minimum width
## separately from SceneImage so a location can declare both a smaller
## image AND a slimmer outer frame (otherwise FrameOuter's hardcoded
## minimum width in Main.tscn would prevent the frame from shrinking).
## Path-based instead of a unique_name_in_owner so we don't require
## editor toggles to land this — keep an eye on the path if the tree
## ever changes shape.
@onready var frame_outer: PanelContainer = $UI/VBox/FrameWrap/FrameOuter
## Overlay portrait drawn on top of the framed scene image. Location scenes
## (e.g. School) call show_teacher_portrait() / hide_teacher_portrait(). Main
## also hides it whenever the selection screen is shown, as a backstop so
## portraits never leak between locations.
@onready var teacher_portrait: TextureRect = %TeacherPortrait
@onready var teacher_tag: PanelContainer = %TeacherTag
@onready var teacher_name_label: Label = %TeacherNameLabel
@onready var teacher_tag_divider: PanelContainer = $UI/VBox/FrameWrap/FrameOuter/FrameInsetDark/FrameInsetMid/SceneImage/TeacherTag/TagMargin/TagHBox/TagDiv
@onready var teacher_subject_label: Label = %SubjectLabel
## Bottom-right pill button inside the picture frame, mirroring the teacher
## tag in the bottom-left. Locations call show_corner_button() to mount a
## "Back"/"Continue"/etc. action here; Main hides it at transition midpoints.
@onready var corner_button: Button = %CornerButton

# Selection screen / location host
@onready var selection_screen: VBoxContainer = %SelectionScreen
@onready var location_grid: HBoxContainer = %LocationGrid
@onready var narration_label: Label = %NarrationLabel
@onready var consequence_label: RichTextLabel = %ConsequenceLabel
@onready var location_host: Control = %LocationHost

# Log overlay
@onready var log_overlay: PanelContainer = %LogOverlay
@onready var event_log: RichTextLabel = %EventLog

# In-frame FlowerLoad wipe (TextureRect parented inside the picture box).
@onready var transition: TextureRect = %Transition
@onready var scanline_layer: CanvasLayer = $ScanlineLayer

var _locations: Array[LocationData] = []
var _locations_loaded: bool = false
var _location_scene_cache: Dictionary = {}
var _current_location_node: Node = null
var _current_location_fullscreen: bool = false
var _current_location_id: StringName = &""
var _default_scene_image: Texture2D
## Toggle for the alternate teacher portrait (e.g., Health.png → Health2.png).
## Flipped with the X key. Persists across teachers within a session.
var _alt_portrait: bool = false

## Base texture path of the currently-shown teacher portrait (no "2" suffix),
## so we can swap variants when the toggle changes.
var _portrait_base_path: String = ""
var _portrait_allows_alt_variant: bool = true

## Set true on the very first selection-screen show, so we don't play a
## transition before the player has even seen anything.
var _has_shown_initial: bool = false

## Active tween animating SceneImage.custom_minimum_size between
## DEFAULT_FRAME_SIZE and a location's preferred frame_size. Kept as a
## field so we can kill it if a new transition starts mid-animation.
var _frame_size_tween: Tween = null

## Active tween animating FrameOuter.custom_minimum_size.x. Separate from
## _frame_size_tween so kills are independent (each can be replaced
## individually if a location changes one but not the other).
var _frame_outer_tween: Tween = null
var _frame_size_start: Vector2 = DEFAULT_FRAME_SIZE
var _frame_size_target: Vector2 = DEFAULT_FRAME_SIZE
var _frame_outer_width_start: float = 0.0
var _frame_outer_width_target: float = 0.0
var _frame_visual_size_start: Vector2 = Vector2.ZERO
var _frame_visual_size_target: Vector2 = Vector2.ZERO
var _frame_chrome_size: Vector2 = Vector2.ZERO
var _scene_image_texture_seen: Texture2D = null
var _large_scene_hud_layer: Control = null
var _large_scene_left_panel: PanelContainer = null
var _large_scene_right_panel: PanelContainer = null
var _large_scene_day_label: Label = null
var _large_scene_phase_label: Label = null
var _large_scene_money_label: Label = null
var _large_scene_suspicion_label: RichTextLabel = null
var _large_scene_anger_label: RichTextLabel = null
var _large_scene_work_timer_divider: PanelContainer = null
var _large_scene_work_timer_label: Label = null
## Bottom-right END/action button that floats in the margin outside the picture
## frame (mirroring the right corner panel, but slotted to the bottom-right
## corner). Locations mount it via show_large_scene_end_button().
var _large_scene_end_button: Button = null
var _work_hud_active: bool = false
var _large_scene_timer_running: bool = false
var _work_hud_elapsed_seconds: float = 0.0
var _fullbleed_active: bool = false
var _bedroom_pill_layer: Control = null
var _bedroom_left_pill: PanelContainer = null
var _bedroom_right_pill: PanelContainer = null
var _bedroom_day_label: RichTextLabel = null
var _bedroom_phase_label: RichTextLabel = null
var _bedroom_money_label: RichTextLabel = null
var _bedroom_suspicion_label: RichTextLabel = null
var _bedroom_anger_label: RichTextLabel = null
## Day-planner choice entries: each is {"button": Button, "loc": LocationData|null}.
var _choice_entries: Array = []
var _selected_choice_index: int = -1
var _frame_resize_progress: float = 1.0:
	set(value):
		_frame_resize_progress = clampf(value, 0.0, 1.0)
		_apply_frame_resize_progress()

## Default minimum width of the outer frame, captured from the .tscn at
## _ready so we can animate back to it when leaving a location that
## declared its own frame_outer_width. Height is left alone — the outer
## frame's container chain accommodates whatever inner height it gets.
var _default_frame_outer_width: float = 0.0

## Active tween for the slide animation. Started by animate_layout_change()
## when content below the frame changes height.
var _slide_tween: Tween = null

## Overlay node currently parented to SceneImage (e.g. Work's furniture
## layer). Tracked so we can clear it on selection-screen swap, the same
## way we backstop the teacher portrait. Locations call show_scene_overlay()
## / hide_scene_overlay(); Main clears it automatically on location exit.
var _scene_overlay: Control = null

## Sentinel: SceneImage.mouse_filter before an interactive overlay flipped
## it. -1 = no override active; hide_scene_overlay restores it back.
var _prev_scene_image_mouse_filter: int = -1

## Overlay node currently parented to FrameOuter (e.g. Work's inventory
## columns that flank the picture). Tracked separately from _scene_overlay
## so the two can coexist — Work uses both: FurnitureLayer sits inside the
## picture, WorkInventory flanks it. Cleared on selection-screen swap.
var _inventory_overlay: Control = null

## The player-wide inventory overlay (the Space-key one). Separate from
## _inventory_overlay above, which is the per-location work-minigame
## inventory that flanks the picture frame.
var _player_inventory_overlay: InventoryOverlay = null
var _settings_overlay_layer: CanvasLayer = null

var _fullscreen_transition_layer: CanvasLayer = null
var _fullscreen_transition: TextureRect = null
var _expanding_transition_layer: CanvasLayer = null
var _expanding_scene_border_panel: Panel = null
var _expanding_transition_clip: Control = null
var _expanding_transition: TextureRect = null
var _expanding_transition_tween: Tween = null
var _expanding_transition_rect: Rect2 = Rect2():
	set(value):
		_expanding_transition_rect = value
		_apply_expanding_transition_rect()
var _source_frame_chrome_hidden: bool = false
var _source_frame_style_backups: Dictionary = {}
var _source_frame_visibility_backups: Dictionary = {}
var _tooltip_layer: CanvasLayer = null
var _mouse_tooltip: MouseFollowTooltip = null
var _intro_sequence_enabled: bool = false
var _suppress_phase_selection_refresh: bool = false

func _ready() -> void:
	_create_mouse_tooltip()
	# Cache the placeholder texture BEFORE anything else can swap it.
	_default_scene_image = scene_image.texture
	_scene_image_texture_seen = scene_image.texture
	# Make sure we start at the canonical default size — defensive in case
	# the .tscn ever drifts from DEFAULT_FRAME_SIZE.
	scene_image.custom_minimum_size = DEFAULT_FRAME_SIZE
	_frame_chrome_size = _compute_frame_chrome_size()

	# Cache FrameOuter's editor-set minimum width as the "default" we
	# animate back to. Unlike the scene image, we don't hardcode this
	# constant — the .tscn is the source of truth so it can be tweaked
	# in the editor without touching code.
	_default_frame_outer_width = _outer_width_for_frame_size(DEFAULT_FRAME_SIZE)
	_frame_size_start = scene_image.custom_minimum_size
	_frame_size_target = scene_image.custom_minimum_size
	_frame_outer_width_start = _default_frame_outer_width
	_frame_outer_width_target = _default_frame_outer_width
	_frame_visual_size_start = _target_frame_visual_size(scene_image.custom_minimum_size, _default_frame_outer_width)
	_frame_visual_size_target = _frame_visual_size_start

	GameState.money_changed.connect(_on_money_changed)
	GameState.suspicion_changed.connect(_on_suspicion_changed)
	GameState.anger_changed.connect(_on_anger_changed)
	GameState.day_changed.connect(_on_day_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.arrested.connect(_on_arrested)
	GameState.brightness_changed.connect(_on_brightness_changed)
	GameState.scanlines_enabled_changed.connect(_on_scanlines_enabled_changed)
	GameState.debug_mode_changed.connect(_on_debug_mode_changed)
	DayCycle.day_ended.connect(_on_day_ended)

	_apply_brightness(GameState.brightness_value)
	_apply_scanlines_enabled(GameState.scanlines_enabled)
	_update_large_scene_hud_visibility()
	_apply_scene_presentation_mode()
	_refresh_hud()
	var intro_autoload: Node = get_node_or_null("/root/IntroTransition")
	var debug_jump := {}
	if intro_autoload and intro_autoload.has_method("consume_debug_jump"):
		debug_jump = intro_autoload.call("consume_debug_jump")
	if not _debug_mode_enabled():
		debug_jump = {}
	var should_start_intro_sequence: bool = debug_jump.is_empty() \
			and GameState.intro_active \
			and not GameState.intro_completed
	var should_play_intro_wipe: bool = debug_jump.is_empty() \
			and intro_autoload != null \
			and bool(intro_autoload.consume_intro())
	if not debug_jump.is_empty():
		_debug_set_phase_for_number(int(debug_jump.get("number", 1)))
	_refresh_hud()
	if should_start_intro_sequence:
		_intro_sequence_enabled = true
		_open_intro_current_step(true)
		if should_play_intro_wipe:
			call_deferred("_play_intro_wipe")
	elif not debug_jump.is_empty():
		_show_selection_screen()
		call_deferred(
			"_debug_jump_for_phase_number",
			int(debug_jump.get("number", 1)),
			bool(debug_jump.get("shift", false)),
			bool(debug_jump.get("ctrl", false))
		)
	elif should_play_intro_wipe:
		_show_selection_screen()
		call_deferred("_play_intro_wipe")
	else:
		_show_selection_screen()


func _process(_delta: float) -> void:
	_sync_scene_image_frame_to_texture()
	if _large_scene_hud_layer != null and _large_scene_hud_layer.visible:
		_position_large_scene_hud_panels()
	if _fullbleed_active and _bedroom_pill_layer != null and _bedroom_pill_layer.visible:
		_position_bedroom_pills()


func _unhandled_input(event: InputEvent) -> void:
	if _play_disabled_location_button_sound_from_event(event):
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event

	# Day-planner keyboard navigation: arrows move the highlight between the
	# ornate choices, Enter confirms. Only while the choice box is on screen.
	if selection_screen.visible and not _is_any_transition_playing():
		if _handle_selection_key(key_event.keycode):
			get_viewport().set_input_as_handled()
			return

	if key_event.keycode == KEY_ESCAPE:
		_toggle_runtime_settings_overlay()
		get_viewport().set_input_as_handled()
		return

	var debug_mode_active := _debug_mode_enabled()

	# Tab toggles the debug event log overlay.
	if debug_mode_active and key_event.keycode == KEY_TAB:
		log_overlay.visible = not log_overlay.visible
		get_viewport().set_input_as_handled()
		return

	# X swaps the alt teacher portrait variant.
	if debug_mode_active and key_event.keycode == KEY_X:
		_alt_portrait = not _alt_portrait
		_refresh_teacher_portrait_variant()
		get_viewport().set_input_as_handled()
		return

	# Space toggles the player inventory overlay — but ONLY when we're
	# inside a location scene (i.e. not on the selection screen / "in
	# your room"). Dialogue boxes consume input before it reaches us
	# via _unhandled_input, so an active dialogue typing-out naturally
	# blocks Space without us having to special-case it.
	if key_event.keycode == KEY_SPACE:
		if _can_open_inventory():
			_toggle_inventory_overlay()
			get_viewport().set_input_as_handled()
		return

	if not debug_mode_active:
		return

	if _handle_debug_number_shortcut(key_event):
		get_viewport().set_input_as_handled()
		return


func _debug_mode_enabled() -> bool:
	return debug_hotkeys_enabled and GameState.debug_mode_enabled


func _toggle_runtime_settings_overlay() -> void:
	if _runtime_settings_overlay_open():
		_close_runtime_settings_overlay()
	else:
		_open_runtime_settings_overlay()


func _runtime_settings_overlay_open() -> bool:
	return _settings_overlay_layer != null and is_instance_valid(_settings_overlay_layer)


func _open_runtime_settings_overlay() -> void:
	if _runtime_settings_overlay_open():
		return
	var layer := CanvasLayer.new()
	layer.name = "RuntimeSettingsOverlayLayer"
	layer.layer = 300
	_settings_overlay_layer = layer
	add_child(layer)

	var back := ColorRect.new()
	back.name = "RuntimeSettingsOverlayBack"
	back.color = Color(0.008, 0.012, 0.039, 0.72)
	back.anchor_right = 1.0
	back.anchor_bottom = 1.0
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_runtime_settings_overlay()
	)
	layer.add_child(back)

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

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	# Display mode is a player-facing comfort setting, not a debug toggle, so it
	# belongs in the mid-game menu just like it does in the main menu. (DEBUG MODE
	# is deliberately kept out of the runtime menu so it can't be toggled mid-run.)
	vbox.add_child(_build_runtime_option_row("DISPLAY MODE", \
		["WINDOWED", "WINDOWED FULLSCREEN", "FULLSCREEN"], GameState.window_mode, _on_runtime_window_mode_selected))
	vbox.add_child(_build_runtime_slider_row("BRIGHTNESS", GameState.brightness_value, _on_runtime_brightness_changed))
	vbox.add_child(_build_runtime_toggle_row("SCANLINES", GameState.scanlines_enabled, _on_runtime_scanlines_toggled))

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 12)
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(_close_runtime_settings_overlay)
	button_row.add_child(close_btn)
	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.pressed.connect(_quit_game)
	button_row.add_child(quit_btn)
	vbox.add_child(button_row)


func _close_runtime_settings_overlay() -> void:
	if _settings_overlay_layer != null and is_instance_valid(_settings_overlay_layer):
		_settings_overlay_layer.queue_free()
	_settings_overlay_layer = null


func _build_runtime_slider_row(label_text: String, initial: float, changed_callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(changed_callback)
	row.add_child(slider)
	return row


func _build_runtime_toggle_row(label_text: String, initial: bool, toggled_callback: Callable) -> HBoxContainer:
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


func _build_runtime_option_row(label_text: String, options: Array, selected_index: int, selected_callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)
	var option := OptionButton.new()
	for i in options.size():
		option.add_item(String(options[i]), i)
	option.selected = clampi(selected_index, 0, options.size() - 1)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(selected_callback)
	row.add_child(option)
	return row


func _on_runtime_brightness_changed(value: float) -> void:
	GameState.brightness_value = value


func _on_runtime_scanlines_toggled(enabled: bool) -> void:
	GameState.scanlines_enabled = enabled


func _on_runtime_window_mode_selected(index: int) -> void:
	# GameState.window_mode's setter clamps, persists, and notifies WindowManager,
	# which applies the DisplayServer change - works mid-game and while paused.
	GameState.window_mode = index



func _quit_game() -> void:
	get_tree().quit()


func _handle_debug_number_shortcut(key_event: InputEventKey) -> bool:
	var number := _debug_number_for_keycode(key_event.keycode)
	if number < 1 or number > 5:
		return false

	match number:
		1, 2, 3:
			_debug_jump_for_phase_number(number, key_event.shift_pressed, key_event.ctrl_pressed)
		4:
			if not key_event.shift_pressed:
				_debug_give_all_items()
			_debug_give_money()
		5:
			_debug_clear_inventory()
	return true


func _debug_number_for_keycode(keycode: Key) -> int:
	match keycode:
		KEY_1, KEY_KP_1:
			return 1
		KEY_2, KEY_KP_2:
			return 2
		KEY_3, KEY_KP_3:
			return 3
		KEY_4, KEY_KP_4:
			return 4
		KEY_5, KEY_KP_5:
			return 5
		_:
			return -1


func _debug_jump_for_phase_number(number: int, shift_held: bool, ctrl_held: bool) -> void:
	_cancel_active_transitions()

	if shift_held and ctrl_held:
		if number == 1:
			_debug_set_phase_for_number(number)
			_debug_open_location_by_id(&"maintenance")
		else:
			_debug_jump_to_bedroom_phase(number)
		return

	if shift_held:
		_debug_set_phase_for_number(number)
		match number:
			1:
				_debug_open_location_by_id(&"school")
			2:
				_debug_open_location_by_id(&"store")
			3:
				_debug_open_location_by_id(&"stress_test")
		return

	if ctrl_held:
		_debug_set_phase_for_number(number)
		match number:
			1:
				_debug_open_location_by_id(&"work")
			2:
				_debug_open_location_by_id(&"workshop")
			3:
				_debug_open_location_by_id(&"sleep")
		return

	_debug_jump_to_bedroom_phase(number)


func _debug_set_phase_for_number(number: int) -> void:
	match number:
		1:
			GameState.phase = DayCycle.Phase.MORNING
		2:
			GameState.phase = DayCycle.Phase.EVENING
		3:
			GameState.phase = DayCycle.Phase.NIGHT


func _debug_jump_to_bedroom_phase(number: int) -> void:
	_debug_set_phase_for_number(number)
	_log("[color=#88aaff]Debug: bedroom %s[/color]" % DayCycle.phase_name(GameState.phase))
	_show_selection_screen()


func _debug_open_location_by_id(location_id: StringName) -> void:
	_load_locations()
	var target_loc: LocationData = null
	for loc in _locations:
		if loc.id == location_id:
			target_loc = loc
			break

	if target_loc == null:
		push_warning("Debug: LocationData not found for id '%s'." % location_id)
		return

	if _current_location_node and is_instance_valid(_current_location_node):
		if _current_location_node.scene_file_path == target_loc.scene_path:
			return

	_on_location_picked(target_loc)


func _start_intro_sequence() -> void:
	if not GameState.intro_active or GameState.intro_completed:
		return
	_intro_sequence_enabled = true
	if _is_any_transition_playing() and transition != null and transition.has_signal("finished"):
		await transition.finished
	if _intro_sequence_enabled:
		_open_intro_current_step()


func _open_intro_current_step(open_immediately: bool = false) -> void:
	if not _intro_sequence_enabled:
		return
	var step_def := _intro_current_step_def()
	if step_def.is_empty():
		GameState.set_intro_step("exposition")
		step_def = _intro_current_step_def()
		if step_def.is_empty():
			_complete_intro_sequence()
			return

	_set_phase_for_intro_step(int(step_def.get("phase", GameState.phase)))
	match String(step_def.get("kind", "")):
		"dialogue":
			_open_intro_dialogue_step(step_def, open_immediately)
		"location":
			_open_intro_location_step(StringName(step_def.get("location_id", &"")), open_immediately)
		_:
			_advance_intro_sequence()


func _intro_current_step_def() -> Dictionary:
	var step := GameState.intro_step
	for step_def in INTRO_STEPS:
		if String(step_def.get("step", "")) == step:
			return step_def
	return {}


func _intro_current_step_index() -> int:
	var step := GameState.intro_step
	for i in INTRO_STEPS.size():
		if String(INTRO_STEPS[i].get("step", "")) == step:
			return i
	return -1


func _set_phase_for_intro_step(phase: int) -> void:
	if GameState.phase == phase:
		return
	_suppress_phase_selection_refresh = true
	GameState.phase = phase
	_suppress_phase_selection_refresh = false
	_refresh_hud()


func _open_intro_dialogue_step(step_def: Dictionary, open_immediately: bool = false) -> void:
	if not ResourceLoader.exists(INTRO_DIALOGUE_SCENE_PATH):
		push_error("Intro: could not load %s" % INTRO_DIALOGUE_SCENE_PATH)
		_advance_intro_sequence()
		return

	var loc := LocationData.new()
	loc.id = INTRO_DIALOGUE_LOCATION_ID
	loc.display_name = "Intro"
	loc.scene_path = INTRO_DIALOGUE_SCENE_PATH
	loc.preview_texture = _load_intro_preview(step_def)
	if open_immediately:
		_open_location_immediately(loc)
	else:
		_on_location_picked(loc)


func _open_intro_location_step(location_id: StringName, open_immediately: bool = false) -> void:
	var loc := _location_by_id(location_id)
	if loc == null:
		push_warning("Intro: LocationData not found for id '%s'." % location_id)
		_advance_intro_sequence()
		return
	if location_id == &"store" or location_id == &"work":
		var intro_loc := LocationData.new()
		intro_loc.id = loc.id
		intro_loc.display_name = loc.display_name
		intro_loc.description = loc.description
		intro_loc.scene_path = loc.scene_path
		var preview_path := "res://assets/textures/backgrounds/factory_lights.png"
		if location_id == &"store":
			preview_path = "res://assets/textures/backgrounds/ed_shop.png"
		intro_loc.preview_texture = load(preview_path)
		intro_loc.frame_size = DEFAULT_FRAME_SIZE
		intro_loc.frame_outer_width = _default_frame_outer_width
		if open_immediately:
			_open_location_immediately(intro_loc)
		else:
			_on_location_picked(intro_loc)
		return
	if open_immediately:
		_open_location_immediately(loc)
	else:
		_on_location_picked(loc)


func _open_location_immediately(loc: LocationData) -> void:
	var packed := _load_location_scene(loc)
	if packed == null:
		_log("ERROR: could not load %s" % loc.scene_path)
		return
	_log("[b]-> %s[/b]" % loc.display_name)
	_apply_location_pick_swap(loc, packed, false, false)
	if _uses_exact_frame_size(loc):
		_set_frame_size_immediate_exact(_location_frame_size(loc), _location_frame_outer_width(loc))
	else:
		_set_frame_size_immediate(_location_frame_size(loc), _location_frame_outer_width(loc))


func _location_by_id(location_id: StringName) -> LocationData:
	_load_locations()
	for loc in _locations:
		if loc.id == location_id:
			return loc
	return null


func _load_intro_preview(step_def: Dictionary) -> Texture2D:
	var path := String(step_def.get("preview", ""))
	if path.is_empty():
		return PHASE_BACKGROUNDS.get(GameState.phase, _default_scene_image)
	if not ResourceLoader.exists(path):
		return PHASE_BACKGROUNDS.get(GameState.phase, _default_scene_image)
	var tex := load(path) as Texture2D
	if tex == null:
		return PHASE_BACKGROUNDS.get(GameState.phase, _default_scene_image)
	if step_def.has("preview_region"):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = step_def["preview_region"]
		atlas.filter_clip = true
		return atlas
	return tex


func _advance_intro_sequence() -> void:
	if not _intro_sequence_enabled:
		return
	var index := _intro_current_step_index()
	if index < 0 or index + 1 >= INTRO_STEPS.size():
		_complete_intro_sequence()
		return
	GameState.set_intro_step(String(INTRO_STEPS[index + 1].get("step", "")))
	call_deferred("_open_intro_current_step_after_transitions")


func _open_intro_current_step_after_transitions() -> void:
	await get_tree().process_frame
	while _intro_sequence_enabled and _is_any_transition_playing():
		await get_tree().process_frame
	if _intro_sequence_enabled:
		_open_intro_current_step()


func _complete_intro_sequence() -> void:
	_intro_sequence_enabled = false
	GameState.complete_intro()
	_set_phase_for_intro_step(DayCycle.Phase.MORNING)
	GameState.day = 1
	DayCycle.nightly_wakes = 0
	DayCycle.nightly_stress_test_completed = false
	GameState.reset_daily_purchases()
	_show_selection_screen()


func is_intro_sequence_location_active(location_id: StringName) -> bool:
	return _intro_sequence_enabled and _current_location_id == location_id


func restart_intro_current_step() -> void:
	if not _intro_sequence_enabled:
		return
	_cancel_active_transitions()
	_clear_current_location()
	_current_location_fullscreen = false
	_current_location_id = &""
	_open_intro_current_step(true)


func _debug_give_all_items() -> void:
	for id in GameState.ingredients.keys():
		GameState.ingredients[id] = 99

	GameState.set_all_robot_parts(99)
	GameState.unlock_tool("taser")
	GameState.unlock_tool("screwdriver")
	GameState.unlock_tool("welding_gun")
	GameState.unlock_tool("sneaky_shoes")
	if _player_inventory_overlay and is_instance_valid(_player_inventory_overlay) and _player_inventory_overlay.visible:
		_player_inventory_overlay.call("_refresh")
	_log("[color=#88ff88]Debug: inventory set to 99 of all items[/color]")


func _debug_give_money() -> void:
	GameState.add_money(1000)
	_log("[color=#88ff88]Debug: +$1000[/color]")


func _debug_clear_inventory() -> void:
	for id in GameState.ingredients.keys():
		GameState.ingredients[id] = 0

	GameState.set_all_robot_parts(0)
	GameState.owned_tools = ["mouth", "hand"]
	GameState.purchased_today.clear()
	GameState.purchased_today_changed.emit(GameState.purchased_today)
	_log("[color=#ffcc88]Debug: inventory cleared[/color]")

func _load_locations() -> void:
	if _locations_loaded:
		return
	_locations_loaded = true
	for path in LOCATION_RESOURCE_PATHS:
		var res: LocationData = load(path)
		if res:
			_locations.append(res)
		else:
			push_warning("Failed to load location resource: %s" % path)


func _load_location_scene(loc: LocationData) -> PackedScene:
	if loc == null:
		return null
	if loc.scene_path.is_empty():
		return null
	if _location_scene_cache.has(loc.scene_path):
		return _location_scene_cache[loc.scene_path]
	var packed: PackedScene = load(loc.scene_path)
	if packed != null:
		_location_scene_cache[loc.scene_path] = packed
	return packed


# --- HUD ---

func _refresh_hud() -> void:
	day_label.text = str(GameState.day)
	phase_label.text = DayCycle.phase_name(GameState.phase).to_upper()
	money_label.text = "$%d" % GameState.money
	suspicion_label.text = str(GameState.suspicion)
	anger_label.text = str(GameState.anger)
	if _large_scene_day_label != null:
		_large_scene_day_label.text = "DAY %d" % GameState.day
	if _large_scene_phase_label != null:
		_large_scene_phase_label.text = DayCycle.phase_name(GameState.phase).to_upper()
	if _large_scene_money_label != null:
		_large_scene_money_label.text = "$%d" % GameState.money
	if _large_scene_suspicion_label != null:
		_large_scene_suspicion_label.text = "SUS [color=%s]%d[/color]" % [
			PILL_SUS_BBCODE_COLOR, GameState.suspicion
		]
	if _large_scene_anger_label != null:
		_large_scene_anger_label.text = "ANGER [color=%s]%d[/color]" % [
			PILL_ANGER_BBCODE_COLOR, GameState.anger
		]
	if _large_scene_work_timer_label != null:
		_large_scene_work_timer_label.text = _format_work_hud_elapsed_time()
	_refresh_bedroom_pills()


func _refresh_bedroom_pills() -> void:
	var phase_name := DayCycle.phase_name(GameState.phase).to_upper()
	if _bedroom_day_label != null:
		_bedroom_day_label.text = "DAY %02d" % GameState.day
	if _bedroom_phase_label != null:
		_bedroom_phase_label.text = phase_name
	if _bedroom_money_label != null:
		_bedroom_money_label.text = "[color=%s]$%d[/color]" % [PILL_MONEY_BBCODE_COLOR, GameState.money]
	# Spelled out on the full-bleed pills; the abbreviation "SUS" is reserved
	# for the large-scene vertical HUD.
	if _bedroom_suspicion_label != null:
		_bedroom_suspicion_label.text = "SUSPICION [color=%s]%d[/color]" % [
			PILL_SUS_BBCODE_COLOR, GameState.suspicion
		]
	if _bedroom_anger_label != null:
		_bedroom_anger_label.text = "ANGER [color=%s]%d[/color]" % [
			PILL_ANGER_BBCODE_COLOR, GameState.anger
		]


## Two floating corner pills over the full-bleed scene image, mirroring the
## refurbished day-planner reference. Each pill is an HBox of text segments
## separated by gold spacers (the same PanelDivider used in the teacher tag).
## Built once, shown only in full-bleed mode.
func _create_bedroom_pills() -> void:
	_bedroom_pill_layer = Control.new()
	_bedroom_pill_layer.name = "BedroomPillLayer"
	_bedroom_pill_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bedroom_pill_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bedroom_pill_layer.z_index = 60
	add_child(_bedroom_pill_layer)

	_bedroom_left_pill = _make_bedroom_pill()
	var left_box := _make_bedroom_pill_box(_bedroom_left_pill)
	_bedroom_day_label = _add_pill_segment(left_box)
	_add_pill_divider(left_box)
	_bedroom_phase_label = _add_pill_segment(left_box)
	_add_pill_divider(left_box)
	_bedroom_money_label = _add_pill_segment(left_box)
	_bedroom_pill_layer.add_child(_bedroom_left_pill)

	_bedroom_right_pill = _make_bedroom_pill()
	var right_box := _make_bedroom_pill_box(_bedroom_right_pill)
	_bedroom_suspicion_label = _add_pill_segment(right_box)
	_add_pill_divider(right_box)
	_bedroom_anger_label = _add_pill_segment(right_box)
	_bedroom_pill_layer.add_child(_bedroom_right_pill)

	_refresh_bedroom_pills()


func _make_bedroom_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.theme_type_variation = &"OrnatePill"
	return pill


func _make_bedroom_pill_box(pill: PanelContainer) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	pill.add_child(box)
	return box


func _add_pill_segment(box: HBoxContainer) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.theme_type_variation = &"PillText"
	label.add_theme_font_size_override("normal_font_size", 30)
	box.add_child(label)
	return label


func _add_pill_divider(box: HBoxContainer) -> void:
	var divider := PanelContainer.new()
	divider.theme_type_variation = &"PanelDivider"
	divider.custom_minimum_size = Vector2(3, 22)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)


func _position_bedroom_pills() -> void:
	if _bedroom_left_pill == null or _bedroom_right_pill == null:
		return
	# Slot the pills flush into the image's top corners, mirroring the way the
	# teacher tag sits in the bottom-left corner.
	var image_rect := _current_scene_image_global_rect()
	_bedroom_left_pill.position = image_rect.position
	_bedroom_right_pill.position = Vector2(
		image_rect.end.x - _bedroom_right_pill.size.x,
		image_rect.position.y
	)


func _create_large_scene_hud() -> void:
	_large_scene_hud_layer = Control.new()
	_large_scene_hud_layer.name = "LargeSceneHUDLayer"
	_large_scene_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_large_scene_hud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_large_scene_hud_layer.z_index = 50
	add_child(_large_scene_hud_layer)

	_large_scene_left_panel = _make_large_scene_hud_panel("LargeSceneLeftHUD", true)
	_large_scene_hud_layer.add_child(_large_scene_left_panel)

	var left_box := _make_large_scene_hud_vbox(_large_scene_left_panel)
	_large_scene_day_label = _make_large_scene_hud_label("DAY 1", &"HUDStat")
	left_box.add_child(_large_scene_day_label)
	left_box.add_child(_make_large_scene_hud_divider())
	_large_scene_phase_label = _make_large_scene_hud_label("MORNING", &"HUDStat")
	left_box.add_child(_large_scene_phase_label)
	left_box.add_child(_make_large_scene_hud_divider())
	_large_scene_money_label = _make_large_scene_hud_label("$0", &"HUDStat")
	# Match the money colour used on the floating pill (the inner HUD).
	_large_scene_money_label.add_theme_color_override("font_color", Color(PILL_MONEY_BBCODE_COLOR))
	left_box.add_child(_large_scene_money_label)

	_large_scene_right_panel = _make_large_scene_hud_panel("LargeSceneRightHUD", false)
	_large_scene_hud_layer.add_child(_large_scene_right_panel)

	var right_box := _make_large_scene_hud_vbox(_large_scene_right_panel)
	# Name in white, value tinted — same split the floating pill uses.
	_large_scene_suspicion_label = _make_large_scene_hud_rich_label()
	right_box.add_child(_large_scene_suspicion_label)
	right_box.add_child(_make_large_scene_hud_divider())
	_large_scene_anger_label = _make_large_scene_hud_rich_label()
	right_box.add_child(_large_scene_anger_label)
	_large_scene_work_timer_divider = _make_large_scene_hud_divider()
	right_box.add_child(_large_scene_work_timer_divider)
	_large_scene_work_timer_label = _make_large_scene_hud_label("00:00:00", &"HUDStat")
	right_box.add_child(_large_scene_work_timer_label)
	_set_work_hud_timer_visible(false)

	_large_scene_end_button = _make_large_scene_end_button()
	_large_scene_hud_layer.add_child(_large_scene_end_button)

	_refresh_hud()


func _make_large_scene_hud_panel(node_name: String, left_anchor: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme_type_variation = &"HUDPanel"
	# Swap the default blue HUD border for a gold one that matches the stat
	# spacers inside the panel (and the framed pills of the inner HUD).
	panel.add_theme_stylebox_override("panel", _make_large_scene_hud_panel_style())
	if left_anchor:
		panel.anchor_left = 0.0
		panel.anchor_right = 0.0
	else:
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	return panel


func _make_large_scene_hud_vbox(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Stats"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


func _make_large_scene_hud_label(label_text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", LARGE_SCENE_HUD_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _make_large_scene_hud_divider() -> PanelContainer:
	var divider := PanelContainer.new()
	divider.custom_minimum_size = Vector2(104.0, 3.0)
	divider.theme_type_variation = &"PanelDivider"
	return divider


## A stat row that keeps the name in the neutral panel colour while tinting
## only the numeric value (set via BBCode in _refresh_hud), matching the pills.
func _make_large_scene_hud_rich_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("default_color", LARGE_SCENE_HUD_NAME_COLOR)
	label.add_theme_font_size_override("normal_font_size", LARGE_SCENE_HUD_FONT_SIZE)
	return label


## Panel background matching the default HUD panel, but with a gold border in
## place of the blue one so the vertical corner panels read as gilded frames.
func _make_large_scene_hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LARGE_SCENE_HUD_PANEL_BG
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = LARGE_SCENE_HUD_BORDER_COLOR
	return style


## A gold-bordered button styled to sit in the frame margin next to the corner
## panels. Hidden until a location mounts an action via
## show_large_scene_end_button().
func _make_large_scene_end_button() -> Button:
	var btn := Button.new()
	btn.name = "LargeSceneEndButton"
	btn.text = "END"
	btn.visible = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.anchor_left = 1.0
	btn.anchor_top = 1.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	# Grow up/left from the bottom-right anchor so the button sizes to its text.
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Shared gold-bordered look so the in-frame CRAFT/COLLECT buttons match it.
	btn.theme_type_variation = &"GoldHudButton"
	btn.add_theme_font_size_override("font_size", LARGE_SCENE_HUD_FONT_SIZE)
	return btn


## Mount a bottom-right margin action button (e.g. the Workshop "END"). Safe to
## call only once the large-scene HUD exists; no-ops otherwise so callers don't
## need to know the presentation mode.
func show_large_scene_end_button(label: String, on_pressed: Callable) -> void:
	if _large_scene_end_button == null:
		return
	for conn in _large_scene_end_button.pressed.get_connections():
		_large_scene_end_button.pressed.disconnect(conn["callable"])
	_large_scene_end_button.text = label
	if on_pressed.is_valid():
		_large_scene_end_button.pressed.connect(on_pressed)
	_large_scene_end_button.disabled = false
	_large_scene_end_button.visible = true
	_position_large_scene_hud_panels()


func hide_large_scene_end_button() -> void:
	if _large_scene_end_button == null:
		return
	for conn in _large_scene_end_button.pressed.get_connections():
		_large_scene_end_button.pressed.disconnect(conn["callable"])
	_large_scene_end_button.visible = false


func _update_large_scene_hud_visibility() -> void:
	if hud_bar == null:
		return
	var use_large_hud := _target_or_current_frame_size().y > LARGE_SCENE_HUD_FRAME_HEIGHT_THRESHOLD
	# The top HUD bar is retired for the two refurbished presentations: large
	# framed scenes use the vertical corner panels, standard full-bleed scenes
	# use the floating pills. It only ever shows as a defensive fallback.
	hud_bar.visible = not use_large_hud and not _fullbleed_active
	if use_large_hud and _large_scene_hud_layer == null:
		_create_large_scene_hud()
		_refresh_hud()
	if _large_scene_hud_layer != null:
		_large_scene_hud_layer.visible = use_large_hud
	# A large framed scene owns the presentation even if we arrived from a
	# full-bleed intro (e.g. the Workshop pan): the corner panels are the HUD,
	# so the floating pills are hidden and the picture frame is centred
	# vertically instead of left pinned to the top with full-bleed margins.
	if _bedroom_pill_layer != null:
		_bedroom_pill_layer.visible = _fullbleed_active and not use_large_hud
	_apply_large_scene_frame_centering(use_large_hud)
	_set_work_hud_timer_visible(use_large_hud and _large_scene_timer_section_visible())
	if use_large_hud:
		var parent_container := hud_bar.get_parent() as Container
		if parent_container != null:
			parent_container.queue_sort()
		_position_large_scene_hud_panels()
		call_deferred("_position_large_scene_hud_panels")


## While a large-scene HUD is active, centre the picture frame vertically with
## symmetric top/bottom margins (overriding a stale full-bleed top-pin). When it
## deactivates, restore whatever the current presentation mode dictates.
func _apply_large_scene_frame_centering(use_large_hud: bool) -> void:
	if frame_wrap == null:
		return
	if use_large_hud:
		frame_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if ui_margin != null:
			var v := int(FULLBLEED_UI_MARGINS.w)
			ui_margin.add_theme_constant_override("margin_top", v)
			ui_margin.add_theme_constant_override("margin_bottom", v)
	else:
		_apply_presentation_layout(_fullbleed_active)


func _position_large_scene_hud_panels() -> void:
	if _large_scene_left_panel == null or _large_scene_right_panel == null:
		return
	var viewport_width := get_viewport_rect().size.x
	var image_rect := _current_scene_image_global_rect()
	var left_space := maxf(0.0, image_rect.position.x)
	var right_space := maxf(0.0, viewport_width - image_rect.end.x)
	var left_outer_gap := _large_scene_hud_outer_gap(left_space)
	var right_outer_gap := _large_scene_hud_outer_gap(right_space)

	_large_scene_left_panel.offset_left = left_outer_gap
	_large_scene_left_panel.offset_top = LARGE_SCENE_HUD_MARGIN.y
	_large_scene_left_panel.offset_right = left_outer_gap + LARGE_SCENE_HUD_PANEL_WIDTH
	_large_scene_left_panel.offset_bottom = LARGE_SCENE_HUD_MARGIN.y + LARGE_SCENE_HUD_LEFT_PANEL_HEIGHT

	_large_scene_right_panel.offset_left = -right_outer_gap - LARGE_SCENE_HUD_PANEL_WIDTH
	_large_scene_right_panel.offset_top = LARGE_SCENE_HUD_MARGIN.y
	_large_scene_right_panel.offset_right = -right_outer_gap
	var right_height := LARGE_SCENE_HUD_RIGHT_PANEL_WORK_HEIGHT \
		if _large_scene_timer_section_visible() \
		else LARGE_SCENE_HUD_RIGHT_PANEL_HEIGHT
	_large_scene_right_panel.offset_bottom = LARGE_SCENE_HUD_MARGIN.y + right_height

	# Slot the margin END button into the bottom-right corner, mirroring the
	# right panel's gap from the right edge but measured from the bottom.
	if _large_scene_end_button != null:
		_large_scene_end_button.offset_right = -right_outer_gap
		_large_scene_end_button.offset_bottom = -LARGE_SCENE_HUD_MARGIN.y
		_large_scene_end_button.offset_left = -right_outer_gap
		_large_scene_end_button.offset_top = -LARGE_SCENE_HUD_MARGIN.y


func _large_scene_hud_outer_gap(side_space: float) -> float:
	var available_gap := maxf(0.0, side_space - LARGE_SCENE_HUD_PANEL_WIDTH)
	return minf(LARGE_SCENE_HUD_MARGIN.x * 0.5, available_gap * 0.5)


# --- scene presentation mode (full-bleed vs framed) ---
#
# The current scene image texture decides the presentation:
#   * standard 500x125 art -> full-bleed (rivet chrome hidden, image enlarged,
#     corner pills instead of the HUD bar). This is the refurbished bedroom /
#     day-planner look, applied consistently to every 500x125 scene.
#   * anything else (500x400+ overrides) -> the existing framed presentation.
# Called from _ready and from every code path that swaps scene_image.texture.

func _apply_scene_presentation_mode() -> void:
	if scene_image == null:
		return
	var texture := scene_image.texture
	var is_standard := texture != null \
		and _is_standard_scene_texture_size(_texture_display_source_size(texture))
	_fullbleed_active = is_standard
	_apply_presentation_layout(is_standard)
	# Every scene wears the ornate gold double-border (matching the dialogue
	# box), not just the standard full-bleed ones. Large framed scenes (Store,
	# Work, ...) previously fell back to the plain rivet frame.
	_set_fullbleed_chrome(true)
	if is_standard and _bedroom_pill_layer == null:
		_create_bedroom_pills()
	if _bedroom_pill_layer != null:
		_bedroom_pill_layer.visible = is_standard
	_update_large_scene_hud_visibility()
	if is_standard:
		_refresh_bedroom_pills()
		_position_bedroom_pills()


## Drop the UI margins and top-pin the picture frame in full-bleed mode so the
## enlarged image reaches the viewport corners; restore the framed inset (and
## the frame's vertical centering) otherwise. The choice box stays centered
## either way, so widening the content area doesn't move it.
func _apply_presentation_layout(fullbleed: bool) -> void:
	var margins := FULLBLEED_UI_MARGINS if fullbleed else FRAMED_UI_MARGINS
	if ui_margin != null:
		ui_margin.add_theme_constant_override("margin_left", int(margins.x))
		ui_margin.add_theme_constant_override("margin_top", int(margins.y))
		ui_margin.add_theme_constant_override("margin_right", int(margins.z))
		ui_margin.add_theme_constant_override("margin_bottom", int(margins.w))
	if frame_wrap != null:
		frame_wrap.size_flags_vertical = \
			Control.SIZE_SHRINK_BEGIN if fullbleed else Control.SIZE_EXPAND_FILL


## Swap the picture-frame chrome between the ornate gold double-border (matching
## the dialogue box) and the default rivet frame. Every scene now uses the gold
## frame — the rivet path is kept only for the transition backup/restore. In
## gold mode the three frame panels are restyled — outer gold border over navy,
## inner bright-gold hairline, empty middle — the rivets are hidden, and the
## cached chrome size is recomputed so the frame sizes to the new borders.
func _set_fullbleed_chrome(gold_frame: bool) -> void:
	# While a fullscreen transition owns the frame chrome (it hides then
	# restores its own backups), stay out of its way. _apply_scene_presentation_mode
	# is re-run when that transition cleans up, so the final state is correct.
	if _source_frame_chrome_hidden:
		return
	var panels := _source_frame_panel_nodes()
	if gold_frame:
		if panels.size() >= 1 and panels[0] != null:
			panels[0].add_theme_stylebox_override("panel", _picture_frame_outer_style())
		if panels.size() >= 2 and panels[1] != null:
			panels[1].add_theme_stylebox_override("panel", _picture_frame_inner_style())
		if panels.size() >= 3 and panels[2] != null:
			panels[2].add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		for panel in panels:
			if panel != null:
				panel.remove_theme_stylebox_override("panel")
	if frame_outer != null:
		for child in frame_outer.get_children():
			var item := child as CanvasItem
			if item != null and String(item.name).begins_with("Rivet"):
				item.visible = not gold_frame
	# The gold and rivet frames have different border/padding, so the cached
	# chrome size must follow the active style for the frame to size correctly.
	_frame_chrome_size = _compute_frame_chrome_size()


func _picture_frame_outer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PICTURE_FRAME_BG
	style.set_border_width_all(3)
	style.border_color = PICTURE_FRAME_OUTER_GOLD
	style.set_content_margin_all(8)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 8)
	return style


func _picture_frame_inner_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(1)
	style.border_color = PICTURE_FRAME_INNER_GOLD
	# A small inset so the image sits just inside this 1px hairline instead of
	# painting over it — this is the thin inner border the dialogue box has.
	style.set_content_margin_all(2)
	return style


func set_work_hud_timer_active(active: bool) -> void:
	if _current_location_id != WORK_LOCATION_ID:
		return
	_work_hud_active = active
	_large_scene_timer_running = active
	if active:
		_work_hud_elapsed_seconds = 0.0
	_refresh_hud()
	_update_large_scene_hud_visibility()


func set_work_hud_elapsed_seconds(seconds: float) -> void:
	if _current_location_id != WORK_LOCATION_ID:
		return
	_work_hud_elapsed_seconds = minf(maxf(0.0, seconds), float(LARGE_SCENE_TIMER_MAX_TICKS) / 100.0)
	if _large_scene_work_timer_label != null:
		_large_scene_work_timer_label.text = _format_work_hud_elapsed_time()


func _set_work_hud_timer_visible(visible_value: bool) -> void:
	if _large_scene_work_timer_divider != null:
		_large_scene_work_timer_divider.visible = visible_value
	if _large_scene_work_timer_label != null:
		_large_scene_work_timer_label.visible = visible_value


func _large_scene_timer_section_visible() -> bool:
	return _current_location_id == WORK_LOCATION_ID and (_work_hud_active or _work_hud_elapsed_seconds > 0.0)


func _format_work_hud_elapsed_time() -> String:
	var ticks := mini(
		int(floor(maxf(0.0, _work_hud_elapsed_seconds) * 100.0)),
		LARGE_SCENE_TIMER_MAX_TICKS
	)
	var first := int(ticks / 10000)
	var second := int((ticks / 100) % 100)
	var third := int(ticks % 100)
	return "%02d:%02d:%02d" % [first, second, third]


func _on_money_changed(_v: int) -> void:    _refresh_hud()
func _on_suspicion_changed(_v: int) -> void: _refresh_hud()
func _on_anger_changed(_v: int) -> void:     _refresh_hud()
func _on_day_changed(_v: int) -> void:       _refresh_hud()
func _on_brightness_changed(value: float) -> void: _apply_brightness(value)
func _on_scanlines_enabled_changed(enabled: bool) -> void: _apply_scanlines_enabled(enabled)
func _on_debug_mode_changed(enabled: bool) -> void:
	if not enabled and log_overlay != null:
		log_overlay.visible = false
func _on_phase_changed(_v: int) -> void:
	_refresh_hud()
	if _suppress_phase_selection_refresh:
		return
	_show_selection_screen()


func _apply_brightness(value: float) -> void:
	var brightness: float = lerpf(0.8, 1.2, clampf(value, 0.0, 100.0) / 100.0)
	modulate = Color(brightness, brightness, brightness, 1.0)


func _apply_scanlines_enabled(enabled: bool) -> void:
	scanline_layer.visible = enabled


# --- selection screen ---
#
# Behavior with the transition:
# - HUD updates and the button grid rebuild are outside the picture box
#   and snap instantly when called.
# - The picture box texture, portrait, and the SelectionScreen/LocationHost
#   visibility flips all happen at frame 9 of the wipe - so the player sees
#   the OLD content under the frame, the wipe plays, and the NEW content is
#   revealed when the wipe lifts.
# - The frame SIZE change (scale animation) is kicked off at the same
#   midpoint but plays out across ~0.2s of the wipe's second half + slightly
#   beyond if needed. The eased size change overlaps the tail of the wipe
#   so the frame's already at its new size as the wipe lifts.

func _show_selection_screen() -> void:
	_load_locations()
	# Rebuild the button grid NOW. The grid sits below the picture frame
	# and isn't visible until the location host is hidden, which happens
	# at the midpoint - so the rebuild is invisible until then anyway.
	for child in location_grid.get_children():
		child.queue_free()
	_choice_entries.clear()
	_selected_choice_index = -1

	for loc in _locations:
		if not loc.available_in_phase(GameState.phase):
			continue
		_add_choice_entry(_build_choice_button(loc), loc)
	for label in _disabled_bedroom_options_for_phase(GameState.phase):
		_add_choice_entry(_build_disabled_bedroom_button(label), null)

	narration_label.text = _selection_narration_text()
	_init_choice_highlight()

	# First load: no transition (nothing to wipe from).
	if not _has_shown_initial:
		_has_shown_initial = true
		_apply_selection_screen_swap(false)
		return
	if _current_location_fullscreen:
		_set_frame_size_immediate(DEFAULT_FRAME_SIZE, _default_frame_outer_width)
		_play_shrinking_fullscreen_transition_after_layout(
			_prepare_selection_screen_layout_for_shrink,
			_apply_selection_screen_swap.bind(false),
			_restore_fullscreen_layout_for_shrink
		)
	else:
		_play_transition_then(_apply_selection_screen_swap.bind(true))


## Runs at the wipe midpoint when returning to the selection screen.
## Everything visible in the frame area changes together.
func _apply_selection_screen_swap(animate_slide: bool = true) -> void:
	# Tear down the previous location's UI.
	_clear_current_location()
	_current_location_fullscreen = false
	_current_location_id = &""

	var swap_visuals := func():
		selection_screen.visible = true
		location_host.visible = false

		scene_image.texture = PHASE_BACKGROUNDS.get(GameState.phase, _default_scene_image)
		hide_teacher_portrait()
		hide_corner_button()
		hide_scene_overlay()
		hide_inventory_overlay()
	if animate_slide:
		_run_with_frame_slide(swap_visuals)
	else:
		swap_visuals.call()

	_apply_scene_presentation_mode()

	# Selection screen always uses the default frame size. Animate back to
	# it in case we were just inside a location with a larger frame.
	_animate_frame_to(DEFAULT_FRAME_SIZE, _default_frame_outer_width)


func _prepare_selection_screen_layout_for_shrink() -> void:
	selection_screen.visible = true
	location_host.visible = false
	scene_image.texture = PHASE_BACKGROUNDS.get(GameState.phase, _default_scene_image)
	hide_teacher_portrait()
	hide_corner_button()
	hide_large_scene_end_button()
	hide_scene_overlay()
	hide_inventory_overlay()
	_apply_scene_presentation_mode()
	_queue_frame_layout()


func _restore_fullscreen_layout_for_shrink() -> void:
	selection_screen.visible = false
	location_host.visible = true
	_queue_frame_layout()


func _selection_narration_text() -> String:
	match GameState.phase:
		DayCycle.Phase.EVENING:
			return "Evening settles in. Where will you go?"
		DayCycle.Phase.NIGHT:
			return "Night falls. Where will you go?"
		_:
			return "Where will you go?"


func _add_choice_entry(btn: Button, loc: LocationData) -> void:
	var index := _choice_entries.size()
	_choice_entries.append({"button": btn, "loc": loc})
	btn.mouse_entered.connect(_highlight_choice.bind(index))
	if loc != null and not btn.disabled:
		btn.pressed.connect(_on_location_picked.bind(loc))
	location_grid.add_child(btn)


func _build_choice_button(loc: LocationData) -> Button:
	var btn := Button.new()
	btn.text = loc.display_name.to_upper()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	if loc.icon:
		btn.icon = loc.icon
		btn.expand_icon = true
	btn.disabled = _is_location_disabled(loc)
	if not loc.description.strip_edges().is_empty():
		btn.mouse_entered.connect(_show_mouse_tooltip.bind(loc.description))
		btn.mouse_exited.connect(_hide_mouse_tooltip)
	_apply_choice_button_style(btn, false)
	return btn


func _build_disabled_bedroom_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label.to_upper()
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
	btn.disabled = true
	_apply_choice_button_style(btn, false)
	return btn


## Paint a choice button in its selected (bright gold frame + navy fill + glow)
## or unselected (dim outline, no fill) state. The same padding is used for
## both so highlighting never reflows the row.
func _apply_choice_button_style(btn: Button, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.content_margin_left = 26.0
	box.content_margin_right = 26.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	box.set_border_width_all(3)
	if selected:
		box.draw_center = true
		box.bg_color = CHOICE_SELECTED_BG
		box.border_color = CHOICE_SELECTED_BORDER
		box.shadow_color = CHOICE_GLOW
		box.shadow_size = 12
	else:
		box.draw_center = false
		box.border_color = CHOICE_UNSELECTED_BORDER
		box.shadow_color = Color(0, 0, 0, 0.5)
		box.shadow_size = 8
		box.shadow_offset = Vector2(0, 4)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, box)
	var text_col := CHOICE_SELECTED_TEXT if selected else CHOICE_UNSELECTED_TEXT
	for color_slot in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		btn.add_theme_color_override(color_slot, text_col)


## Enter the selection screen with nothing highlighted and no consequence line.
## The first hover (or arrow-key press) selects a button via _highlight_choice,
## after which the normal sticky behaviour takes over — the selection persists
## even when the pointer leaves the button.
func _init_choice_highlight() -> void:
	_selected_choice_index = -1
	for i in _choice_entries.size():
		_apply_choice_button_style(_choice_entries[i]["button"], false)
	if consequence_label != null:
		# Reserve the height the label will have once a consequence line shows,
		# so the choice box never resizes on first selection. Measure it by
		# rendering a real sample line and reading the resulting content height
		# back, rather than predicting it from font metrics.
		consequence_label.text = "[center]Ag[/center]"
		consequence_label.custom_minimum_size.y = maxf(
			consequence_label.custom_minimum_size.y,
			float(consequence_label.get_content_height())
		)
		consequence_label.text = ""


func _highlight_choice(index: int) -> void:
	if index < 0 or index >= _choice_entries.size():
		return
	_selected_choice_index = index
	for i in _choice_entries.size():
		_apply_choice_button_style(_choice_entries[i]["button"], i == index)
	_update_consequence_line()


func _update_consequence_line() -> void:
	if consequence_label == null:
		return
	if _selected_choice_index < 0 or _selected_choice_index >= _choice_entries.size():
		consequence_label.text = ""
		return
	var loc: LocationData = _choice_entries[_selected_choice_index]["loc"]
	if loc == null:
		consequence_label.text = "[center]—[/center]"
		return
	var body := loc.consequence_text.strip_edges()
	if body.is_empty():
		body = loc.description.strip_edges()
	var clause := loc.stat_clause.strip_edges()
	var text := body
	if not clause.is_empty():
		if not text.is_empty():
			text += "  "
		text += "[color=%s]%s[/color]" % [STAT_CLAUSE_BBCODE_COLOR, clause]
	consequence_label.text = "[center]%s[/center]" % text


func _move_choice_highlight(step: int) -> void:
	if _choice_entries.is_empty():
		return
	var count := _choice_entries.size()
	var idx := _selected_choice_index
	if idx < 0:
		idx = 0 if step >= 0 else count - 1
	else:
		idx = (idx + step + count) % count
	_highlight_choice(idx)


func _confirm_selected_choice() -> void:
	if _selected_choice_index < 0 or _selected_choice_index >= _choice_entries.size():
		return
	var entry: Dictionary = _choice_entries[_selected_choice_index]
	var btn: Button = entry["button"]
	var loc: LocationData = entry["loc"]
	if loc != null and not btn.disabled:
		_on_location_picked(loc)
	else:
		UI_SOUND.play_inaccessible_button(self)


func _handle_selection_key(keycode: int) -> bool:
	match keycode:
		KEY_LEFT, KEY_UP:
			_move_choice_highlight(-1)
			return true
		KEY_RIGHT, KEY_DOWN:
			_move_choice_highlight(1)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_confirm_selected_choice()
			return true
	return false


func _play_disabled_location_button_sound_from_event(event: InputEvent) -> bool:
	if not selection_screen.visible:
		return false
	if _is_any_transition_playing():
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false

	for child in location_grid.get_children():
		var btn := child as Button
		if btn == null or not btn.disabled:
			continue
		if btn.get_global_rect().has_point(mouse_event.global_position):
			UI_SOUND.play_inaccessible_button(self)
			return true
	return false


func _create_mouse_tooltip() -> void:
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "TooltipLayer"
	_tooltip_layer.layer = 200
	add_child(_tooltip_layer)

	_mouse_tooltip = MOUSE_TOOLTIP_SCRIPT.new() as MouseFollowTooltip
	_tooltip_layer.add_child(_mouse_tooltip)


func _show_mouse_tooltip(text: String) -> void:
	if _mouse_tooltip != null:
		_mouse_tooltip.show_text(text)


func _hide_mouse_tooltip() -> void:
	if _mouse_tooltip != null:
		_mouse_tooltip.hide_tooltip()


func _is_location_disabled(loc: LocationData) -> bool:
	return DISABLED_LOCATION_IDS.has(loc.id)


func _disabled_bedroom_options_for_phase(phase: int) -> Array[String]:
	if phase == DayCycle.Phase.EVENING:
		return EVENING_DISABLED_BEDROOM_OPTIONS
	return []


func _on_location_picked(loc: LocationData) -> void:
	# Guard against rapid double-click stacking transitions.
	if _is_any_transition_playing():
		return
	_hide_mouse_tooltip()

	# Validate the scene up-front so we can bail before starting the wipe
	# if something's wrong. The actual instantiation + swap-in happens at
	# the midpoint so the player doesn't see the location UI snap in.
	var packed := _load_location_scene(loc)
	if packed == null:
		_log("ERROR: could not load %s" % loc.scene_path)
		return

	_log("[b]→ %s[/b]" % loc.display_name)
	if loc.fullscreen_scene:
		if _current_location_fullscreen:
			_play_fullscreen_transition_then(_apply_fullscreen_location_pick_swap.bind(loc, packed, false))
		else:
			_play_expanding_fullscreen_transition_then(_apply_fullscreen_location_pick_swap.bind(loc, packed, false))
	else:
		if _current_location_fullscreen:
			if _uses_exact_frame_size(loc):
				_set_frame_size_immediate_exact(_location_frame_size(loc), _location_frame_outer_width(loc))
			else:
				_set_frame_size_immediate(_location_frame_size(loc), _location_frame_outer_width(loc))
			_play_shrinking_fullscreen_transition_after_layout(
				Callable(),
				_apply_location_pick_swap.bind(loc, packed, false, false)
			)
		else:
			_play_transition_then(_apply_location_pick_swap.bind(loc, packed))


## Runs at the wipe midpoint when picking a location.
## All frame-area changes happen together so the wipe hides them.
func _apply_location_pick_swap(
		loc: LocationData,
		packed: PackedScene,
		animate_slide: bool = true,
		animate_frame: bool = true
) -> void:
	_clear_current_location()
	_work_hud_active = false
	_large_scene_timer_running = false
	_work_hud_elapsed_seconds = 0.0
	_current_location_node = packed.instantiate()
	if _intro_sequence_enabled:
		_current_location_node.set_meta("intro_sequence_location", true)
		_current_location_node.set_meta("intro_step", GameState.intro_step)
		_current_location_node.set_meta("intro_location_id", String(loc.id))
	_current_location_fullscreen = loc.fullscreen_scene
	_current_location_id = loc.id
	location_host.add_child(_current_location_node)
	if _current_location_node.has_method("lock_entry_input"):
		var entry_lock_seconds := 0.55 if loc.fullscreen_scene else 0.2
		_current_location_node.call("lock_entry_input", entry_lock_seconds)

	if _current_location_node.has_signal("finished"):
		_current_location_node.finished.connect(_on_location_finished.bind(_current_location_node))
	else:
		push_warning("Location %s did not expose a `finished` signal." % loc.display_name)

	var swap_visuals := func():
		selection_screen.visible = false
		location_host.visible = true

		if loc.preview_texture:
			scene_image.texture = loc.preview_texture
	if animate_slide:
		_run_with_frame_slide(swap_visuals)
	else:
		swap_visuals.call()

	_apply_scene_presentation_mode()

	# Resize the frame to this location's preferred size (or default if
	# the resource doesn't declare one). Eases in/out over ANIM_DURATION.
	var target: Vector2 = _location_frame_size(loc)

	# Same for the outer frame width — independent so locations can
	# declare just one or the other. frame_outer_width <= 0 means "use
	# the .tscn default", which we cached at _ready.
	var target_outer: float = _location_frame_outer_width(loc)
	if animate_frame:
		_animate_frame_to(target, target_outer, ANIM_DURATION, not _uses_exact_frame_size(loc))


func _apply_fullscreen_location_pick_swap(
		loc: LocationData,
		packed: PackedScene,
		play_lift: bool = true
) -> void:
	_apply_location_pick_swap(loc, packed, play_lift, play_lift)
	if play_lift:
		_play_fullscreen_lift()


func _location_frame_size(loc: LocationData) -> Vector2:
	return loc.frame_size if loc.frame_size != Vector2.ZERO else DEFAULT_FRAME_SIZE


func _location_frame_outer_width(loc: LocationData) -> float:
	var frame_size := _location_frame_size(loc)
	var requested_width := loc.frame_outer_width if loc.frame_outer_width > 0.0 else _default_frame_outer_width
	return maxf(requested_width, _outer_width_for_frame_size(frame_size))


func _uses_exact_frame_size(loc: LocationData) -> bool:
	return loc != null and EXACT_FRAME_LOCATION_IDS.has(loc.id)


func _sync_scene_image_frame_to_texture() -> void:
	if scene_image == null or frame_outer == null or scene_image.texture == _scene_image_texture_seen:
		return
	_scene_image_texture_seen = scene_image.texture
	# A texture swap can flip the presentation mode (standard <-> larger art).
	_apply_scene_presentation_mode()
	var size_target: Vector2 = _frame_size_target if _is_frame_resize_playing() else scene_image.custom_minimum_size
	var normalized_size := _normalized_frame_size_for_texture(size_target, scene_image.texture)
	var outer_target := maxf(
		_frame_outer_width_target if _is_frame_resize_playing() else frame_outer.custom_minimum_size.x,
		_outer_width_for_frame_size(normalized_size)
	)
	if normalized_size.is_equal_approx(size_target) \
			and is_equal_approx(frame_outer.custom_minimum_size.x, outer_target):
		return
	_animate_frame_to(normalized_size, outer_target)


func _normalized_frame_size_for_texture(requested_size: Vector2, texture: Texture2D) -> Vector2:
	var size_value := requested_size if requested_size != Vector2.ZERO else DEFAULT_FRAME_SIZE
	if texture == null:
		return size_value
	var texture_size := _texture_display_source_size(texture)
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return size_value
	if _is_standard_scene_texture_size(texture_size):
		# Standard 500x125 art renders full-bleed (chrome hidden). The enlarged
		# size is what gives the refurbished day-planner its big top image.
		return STANDARD_FULLBLEED_FRAME_SIZE

	var texture_aspect := texture_size.x / texture_size.y
	var size_aspect := size_value.x / size_value.y if size_value.y > 0.0 else texture_aspect
	if is_equal_approx(size_aspect, texture_aspect):
		return size_value

	var width_limited := Vector2(size_value.x, size_value.x / texture_aspect)
	if width_limited.y <= size_value.y:
		return width_limited
	return Vector2(size_value.y * texture_aspect, size_value.y)


func _is_standard_scene_texture_size(texture_size: Vector2) -> bool:
	return is_equal_approx(texture_size.x, STANDARD_SCENE_TEXTURE_SIZE.x) \
		and is_equal_approx(texture_size.y, STANDARD_SCENE_TEXTURE_SIZE.y)


func _texture_display_source_size(texture: Texture2D) -> Vector2:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.region.size != Vector2.ZERO:
			return atlas_texture.region.size
	return texture.get_size()


func _outer_width_for_frame_size(frame_size: Vector2) -> float:
	return frame_size.x + _frame_chrome_size.x


func _compute_frame_chrome_size() -> Vector2:
	var chrome := Vector2.ZERO
	chrome += _panel_style_minimum_size(frame_outer)
	var inset_dark := frame_outer.get_node_or_null("FrameInsetDark") as PanelContainer
	chrome += _panel_style_minimum_size(inset_dark)
	var inset_mid: PanelContainer = null
	if inset_dark != null:
		inset_mid = inset_dark.get_node_or_null("FrameInsetMid") as PanelContainer
	chrome += _panel_style_minimum_size(inset_mid)
	return chrome


func _panel_style_minimum_size(panel: PanelContainer) -> Vector2:
	if panel == null:
		return Vector2.ZERO
	var style := panel.get_theme_stylebox("panel")
	if style == null:
		return Vector2.ZERO
	return style.get_minimum_size()


func _clear_current_location() -> void:
	hide_scene_overlay()
	hide_inventory_overlay()
	hide_large_scene_end_button()
	if _current_location_node and is_instance_valid(_current_location_node):
		_current_location_node.queue_free()
		_current_location_node = null


# --- frame size (scale) animation ---

## Tween SceneImage.custom_minimum_size to `target` with ease-in/ease-out.
## Snaps immediately if we're already there. Kills any in-flight tween so
## a fast back-to-back location change doesn't fight itself.
func _animate_frame_size_to(target: Vector2) -> void:
	var outer_target: float = _frame_outer_width_target if _is_frame_resize_playing() else frame_outer.custom_minimum_size.x
	_animate_frame_to(target, outer_target)
	return

	if scene_image == null:
		return

	if _frame_size_tween and _frame_size_tween.is_valid():
		_frame_size_tween.kill()

	# Already at the target — nothing to animate. (Common case: leaving
	# a default-sized location back to the selection screen.)
	if scene_image.custom_minimum_size.is_equal_approx(target):
		return

	_frame_size_tween = create_tween()
	_frame_size_tween.set_trans(ANIM_TRANS)
	_frame_size_tween.set_ease(ANIM_EASE)
	_frame_size_tween.tween_property(
		scene_image, "custom_minimum_size", target, ANIM_DURATION
	)


## Tween FrameOuter's minimum width to `target_width` with the same easing
## as the scene image. Runs concurrently with _animate_frame_size_to() so
## both the outer frame and the inner picture grow/shrink together.
## Height of the outer frame is not animated — it's container-driven and
## will accommodate whatever inner height the SceneImage demands.
func _animate_frame_outer_width_to(target_width: float) -> void:
	var size_target: Vector2 = _frame_size_target if _is_frame_resize_playing() else scene_image.custom_minimum_size
	_animate_frame_to(size_target, target_width)
	return

	if frame_outer == null:
		return

	if _frame_outer_tween and _frame_outer_tween.is_valid():
		_frame_outer_tween.kill()

	if is_equal_approx(frame_outer.custom_minimum_size.x, target_width):
		return

	_frame_outer_tween = create_tween()
	_frame_outer_tween.set_trans(ANIM_TRANS)
	_frame_outer_tween.set_ease(ANIM_EASE)
	_frame_outer_tween.tween_property(
		frame_outer, "custom_minimum_size:x", target_width, ANIM_DURATION
	)


func _animate_frame_to(
		target_size: Vector2,
		target_outer_width: float,
		duration: float = ANIM_DURATION,
		normalize_texture_size: bool = true
) -> void:
	if scene_image == null or frame_outer == null:
		return
	if normalize_texture_size:
		target_size = _normalized_frame_size_for_texture(target_size, scene_image.texture)
	target_outer_width = maxf(target_outer_width, _outer_width_for_frame_size(target_size))

	if _frame_outer_tween and _frame_outer_tween.is_valid():
		_frame_outer_tween.kill()
	if _frame_size_tween and _frame_size_tween.is_valid():
		_frame_size_tween.kill()

	if scene_image.custom_minimum_size.is_equal_approx(target_size) \
			and is_equal_approx(frame_outer.custom_minimum_size.x, target_outer_width):
		return

	_frame_size_start = scene_image.custom_minimum_size
	_frame_size_target = target_size
	_frame_outer_width_start = frame_outer.custom_minimum_size.x
	_frame_outer_width_target = target_outer_width
	_frame_visual_size_start = _current_frame_visual_size()
	_frame_visual_size_target = _target_frame_visual_size(target_size, target_outer_width)
	_frame_resize_progress = 0.0
	_update_large_scene_hud_visibility()

	_frame_size_tween = create_tween()
	_frame_size_tween.set_trans(ANIM_TRANS)
	_frame_size_tween.set_ease(ANIM_EASE)
	_frame_size_tween.tween_property(self, "_frame_resize_progress", 1.0, maxf(0.01, duration))
	_scene_image_texture_seen = scene_image.texture


func _set_frame_size_immediate(size_value: Vector2, outer_width: float) -> void:
	_set_frame_size_immediate_internal(size_value, outer_width, true)


func _set_frame_size_immediate_exact(size_value: Vector2, outer_width: float) -> void:
	_set_frame_size_immediate_internal(size_value, outer_width, false)


func _set_frame_size_immediate_internal(
		size_value: Vector2,
		outer_width: float,
		normalize_texture_size: bool
) -> void:
	if normalize_texture_size:
		size_value = _normalized_frame_size_for_texture(size_value, scene_image.texture)
	outer_width = maxf(outer_width, _outer_width_for_frame_size(size_value))

	if _frame_size_tween and _frame_size_tween.is_valid():
		_frame_size_tween.kill()
	if _frame_outer_tween and _frame_outer_tween.is_valid():
		_frame_outer_tween.kill()

	_frame_size_start = size_value
	_frame_size_target = size_value
	_frame_outer_width_start = outer_width
	_frame_outer_width_target = outer_width
	_frame_visual_size_start = _target_frame_visual_size(size_value, outer_width)
	_frame_visual_size_target = _frame_visual_size_start
	_frame_resize_progress = 1.0
	_apply_frame_resize_progress()
	_scene_image_texture_seen = scene_image.texture
	_update_large_scene_hud_visibility()


func _apply_frame_resize_progress() -> void:
	if scene_image == null or frame_outer == null:
		return

	var frame_size := _frame_size_start.lerp(_frame_size_target, _frame_resize_progress)
	var outer_width := lerpf(
		_frame_outer_width_start,
		_frame_outer_width_target,
		_frame_resize_progress
	)
	scene_image.custom_minimum_size = frame_size
	frame_outer.custom_minimum_size = Vector2(outer_width, frame_size.y + _frame_chrome_size.y)
	frame_outer.position = _center_resize_offset()
	_queue_frame_layout()
	_update_large_scene_hud_visibility()


func _is_frame_resize_playing() -> bool:
	return _frame_size_tween != null and _frame_size_tween.is_valid()


func _target_or_current_frame_size() -> Vector2:
	if _frame_size_target != Vector2.ZERO:
		return _frame_size_target
	if scene_image != null:
		return scene_image.custom_minimum_size
	return DEFAULT_FRAME_SIZE


func _queue_frame_layout() -> void:
	if scene_image != null:
		scene_image.update_minimum_size()
	if frame_outer != null:
		frame_outer.update_minimum_size()
	if frame_wrap != null:
		frame_wrap.queue_sort()
		var parent_container := frame_wrap.get_parent() as Container
		if parent_container != null:
			parent_container.queue_sort()


func _current_frame_visual_size() -> Vector2:
	if frame_outer == null:
		return Vector2.ZERO
	var current_size := frame_outer.size
	if current_size.x <= 0.0:
		current_size.x = frame_outer.custom_minimum_size.x
	if current_size.y <= 0.0 and scene_image != null:
		current_size.y = scene_image.custom_minimum_size.y
	return current_size


func _target_frame_visual_size(target_size: Vector2, target_outer_width: float) -> Vector2:
	var current_size := _current_frame_visual_size()
	return Vector2(
		target_outer_width,
		target_size.y + _frame_chrome_size.y if target_size.y > 0.0 else current_size.y
	)


func _center_resize_offset() -> Vector2:
	if _frame_resize_progress >= 1.0:
		return Vector2.ZERO

	var current_size := _frame_visual_size_start.lerp(_frame_visual_size_target, _frame_resize_progress)
	return (_frame_visual_size_start - current_size) * 0.5


# --- layout slide animation (public API for locations) ---

## Wrap a layout-changing operation in an eased slide animation.
##
## How it works:
##   1. Capture the SceneImage's current global rect.
##   2. Run `mutator` synchronously — this is where the location toggles
##      a DialogueBox visible, adds choice buttons, etc. The container
##      chain reflows and the frame snaps to its new position.
##   3. Use position-only offsets: the frame is instantly placed back at
##      its OLD position via a Control offset, then tweened to zero so
##      the player sees a smooth slide from where it WAS to where it now
##      IS.
##
## This is a no-op for changes that don't actually move the frame, so
## locations can call it liberally without worrying about jitter.
##
## Usage from a location script:
##     main.animate_layout_change(func():
##         dialogue_box.visible = true
##         choice_grid.visible = false
##     )
func animate_layout_change(mutator: Callable) -> void:
	if not mutator.is_valid():
		push_warning("Main.animate_layout_change: invalid mutator callable")
		return

	_run_with_frame_slide(mutator)


func _run_with_frame_slide(mutator: Callable) -> void:
	if not mutator.is_valid():
		return

	# Capture the FrameWrap's global position before the mutation. We
	# animate the wrap (the CenterContainer that holds the framed image),
	# not the SceneImage itself, because the slide we want to show is the
	# whole picture frame moving — rivets, corner button, everything.
	var slide_frame_wrap: Control = frame_wrap
	# That walks: SceneImage -> FrameInsetMid -> FrameInsetDark ->
	# FrameOuter -> FrameWrap. If the tree shape ever changes, this needs
	# to keep up — kept as a chain instead of a hardcoded path so it
	# breaks loudly rather than silently animating the wrong node.
	if slide_frame_wrap == null:
		mutator.call()
		return

	var old_global_pos: Vector2 = slide_frame_wrap.global_position

	# Apply the mutation. The container chain reflows synchronously.
	mutator.call()

	# Force the layout to settle NOW so global_position reflects the new
	# target. Without this the new position isn't known until the end of
	# the frame.
	slide_frame_wrap.get_tree().process_frame  # touch to prevent linter unused
	# In Godot 4, queue_sort + update_minimum_size is the recommended
	# nudge. The deferred call below resolves the actual tween once layout
	# has settled this frame.
	_queue_frame_layout()

	call_deferred("_finish_slide_animation", old_global_pos)


## Deferred half of animate_layout_change. Runs AFTER the reflow has
## settled (next idle frame), at which point frame_wrap.global_position
## reflects the new spot. We tween the difference using an offset so the
## container layout itself isn't fought.
func _finish_slide_animation(old_global_pos: Vector2) -> void:
	if frame_wrap == null or not is_instance_valid(frame_wrap):
		return

	var new_global_pos: Vector2 = frame_wrap.global_position
	var delta: Vector2 = old_global_pos - new_global_pos
	if delta.length() < 0.5:
		return

	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	frame_wrap.position = delta
	_slide_tween = create_tween()
	_slide_tween.set_trans(ANIM_TRANS)
	_slide_tween.set_ease(ANIM_EASE)
	_slide_tween.tween_property(frame_wrap, "position", Vector2.ZERO, ANIM_DURATION)

	# No movement — no animation needed.

	# Kill any in-flight slide so back-to-back layout changes don't stack.

	# Pre-offset the frame to its OLD position, then tween the offset to
	# zero. position is a Control property (independent of the container's
	# resolved layout), so this gives a smooth visual slide without
	# breaking the layout system.



# --- transitions ---

## Play the FlowerLoad wipe, invoking `swap_callback` at frame 9/17 (when
## the picture is fully covered). Falls back to immediate invocation if
## the transition node isn't ready / missing for any reason.
func _play_transition_then(swap_callback: Callable) -> void:
	if transition == null or not transition.has_method("play"):
		swap_callback.call()
		return
	transition.play(swap_callback)


func _play_expanding_fullscreen_transition_then(swap_callback: Callable) -> void:
	_cleanup_expanding_fullscreen_transition()

	var tr := _create_expanding_fullscreen_transition()
	if tr == null or not tr.has_method("play"):
		swap_callback.call()
		return

	tr.set("duration_sec", float(tr.get("duration_sec")) * EXPANDING_FULLSCREEN_TRANSITION_DURATION_SCALE)
	var start_rect := _current_scene_image_global_rect()
	var target_rect := _fullscreen_reveal_scene_rect()
	var expand_duration := _transition_midpoint_seconds(tr)
	_expanding_transition_rect = start_rect

	_expanding_transition_tween = create_tween()
	_expanding_transition_tween.set_trans(ANIM_TRANS)
	_expanding_transition_tween.set_ease(ANIM_EASE)
	_expanding_transition_tween.tween_property(
		self,
		"_expanding_transition_rect",
		target_rect,
		expand_duration
	)
	tr.connect("finished", Callable(self, "_cleanup_expanding_fullscreen_transition"), CONNECT_ONE_SHOT)
	tr.play(swap_callback)


func _play_shrinking_fullscreen_transition_then(swap_callback: Callable, target_rect: Rect2) -> void:
	_cleanup_expanding_fullscreen_transition()

	var tr := _create_expanding_fullscreen_transition()
	if tr == null or not tr.has_method("play"):
		swap_callback.call()
		return

	tr.set("duration_sec", float(tr.get("duration_sec")) * EXPANDING_FULLSCREEN_TRANSITION_DURATION_SCALE)
	_expanding_transition_rect = _fullscreen_reveal_scene_rect()

	tr.connect("finished", Callable(self, "_cleanup_expanding_fullscreen_transition"), CONNECT_ONE_SHOT)
	tr.play(_start_shrinking_fullscreen_transition.bind(swap_callback, target_rect, tr))


func _start_shrinking_fullscreen_transition(
		swap_callback: Callable,
		target_rect: Rect2,
		tr: TextureRect
) -> void:
	if swap_callback.is_valid():
		swap_callback.call()
	var shrink_duration := _transition_remaining_seconds(tr)
	_expanding_transition_tween = create_tween()
	_expanding_transition_tween.set_trans(ANIM_TRANS)
	_expanding_transition_tween.set_ease(ANIM_EASE)
	_expanding_transition_tween.tween_property(
		self,
		"_expanding_transition_rect",
		target_rect,
		shrink_duration
	)


func _play_shrinking_fullscreen_transition_after_layout(
		prepare_layout: Callable,
		midpoint_callback: Callable,
		restore_layout: Callable = Callable()
) -> void:
	if prepare_layout.is_valid():
		prepare_layout.call()
	_queue_frame_layout()
	await get_tree().process_frame
	_queue_frame_layout()
	var target_rect := _outset_rect(_current_scene_image_global_rect(), SHRINKING_FULLSCREEN_TARGET_OUTSET)
	if restore_layout.is_valid():
		restore_layout.call()
	_play_shrinking_fullscreen_transition_then(
		midpoint_callback,
		target_rect
	)


func _create_expanding_fullscreen_transition() -> TextureRect:
	_set_source_frame_chrome_hidden(true)

	_expanding_transition_layer = CanvasLayer.new()
	_expanding_transition_layer.name = "ExpandingFullscreenTransitionLayer"
	_expanding_transition_layer.layer = 100
	add_child(_expanding_transition_layer)

	_expanding_transition_clip = Control.new()
	_expanding_transition_clip.name = "ExpandingFullscreenTransitionClip"
	_expanding_transition_clip.clip_contents = true
	_expanding_transition_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanding_transition_layer.add_child(_expanding_transition_clip)

	_expanding_transition = TRANSITION_SCENE.instantiate() as TextureRect
	if _expanding_transition == null:
		_cleanup_expanding_fullscreen_transition()
		return null
	_expanding_transition.name = "ExpandingFullscreenTransition"
	_expanding_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanding_transition_clip.add_child(_expanding_transition)

	_expanding_scene_border_panel = Panel.new()
	_expanding_scene_border_panel.name = "ExpandingSceneImageBorder"
	_expanding_scene_border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanding_scene_border_panel.z_index = 100
	_expanding_scene_border_panel.add_theme_stylebox_override("panel", _expanding_scene_border_style())
	_expanding_transition_clip.add_child(_expanding_scene_border_panel)
	return _expanding_transition


func _apply_expanding_transition_rect() -> void:
	if _expanding_transition_clip == null or not is_instance_valid(_expanding_transition_clip):
		return
	_expanding_transition_clip.position = _expanding_transition_rect.position
	_expanding_transition_clip.size = _expanding_transition_rect.size

	if _expanding_transition != null and is_instance_valid(_expanding_transition):
		_expanding_transition.position = -_expanding_transition_rect.position
		_expanding_transition.size = get_viewport_rect().size

	if _expanding_scene_border_panel != null and is_instance_valid(_expanding_scene_border_panel):
		_expanding_scene_border_panel.position = Vector2.ZERO
		_expanding_scene_border_panel.size = _expanding_transition_rect.size


func _cleanup_expanding_fullscreen_transition() -> void:
	if _expanding_transition_tween != null and _expanding_transition_tween.is_valid():
		_expanding_transition_tween.kill()
	_expanding_transition_tween = null
	_expanding_transition = null
	_expanding_transition_clip = null
	_expanding_scene_border_panel = null
	if _expanding_transition_layer != null and is_instance_valid(_expanding_transition_layer):
		_expanding_transition_layer.queue_free()
	_expanding_transition_layer = null
	_expanding_transition_rect = Rect2()
	_set_source_frame_chrome_hidden(false)
	# Re-assert gold vs rivet chrome now that the transition released it, then
	# force the frame to re-size next frame so the outer width matches the
	# freshly-restored chrome (the two frames have different border padding).
	_apply_scene_presentation_mode()
	_scene_image_texture_seen = null


func _expanding_scene_border_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.42, 0.333, 0.196, 1.0)
	style.set_border_width_all(3)
	style.set_content_margin_all(0)
	return style


func _set_source_frame_chrome_hidden(hidden: bool) -> void:
	if hidden == _source_frame_chrome_hidden:
		return
	_source_frame_chrome_hidden = hidden
	if hidden:
		_hide_source_frame_chrome()
	else:
		_restore_source_frame_chrome()


func _hide_source_frame_chrome() -> void:
	for panel in _source_frame_panel_nodes():
		if panel == null:
			continue
		var original_style := panel.get_theme_stylebox("panel")
		_source_frame_style_backups[panel.get_path()] = original_style
		panel.add_theme_stylebox_override("panel", _transparent_frame_style(original_style))

	if frame_outer == null:
		return
	for child in frame_outer.get_children():
		var item := child as CanvasItem
		if item == null or not String(item.name).begins_with("Rivet"):
			continue
		_source_frame_visibility_backups[item.get_path()] = item.visible
		item.visible = false


func _transparent_frame_style(source: StyleBox) -> StyleBox:
	if source is StyleBoxFlat:
		var style := (source as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.bg_color = Color(style.bg_color.r, style.bg_color.g, style.bg_color.b, 0.0)
		style.border_color = Color(style.border_color.r, style.border_color.g, style.border_color.b, 0.0)
		return style
	return source.duplicate() as StyleBox


func _restore_source_frame_chrome() -> void:
	for key in _source_frame_style_backups:
		var panel := get_node_or_null(NodePath(String(key))) as PanelContainer
		if panel != null:
			panel.add_theme_stylebox_override("panel", _source_frame_style_backups[key])
	_source_frame_style_backups.clear()

	for key in _source_frame_visibility_backups:
		var item := get_node_or_null(NodePath(String(key))) as CanvasItem
		if item != null:
			item.visible = bool(_source_frame_visibility_backups[key])
	_source_frame_visibility_backups.clear()


func _source_frame_panel_nodes() -> Array[PanelContainer]:
	var panels: Array[PanelContainer] = []
	if frame_outer != null:
		panels.append(frame_outer)
		var inset_dark := frame_outer.get_node_or_null("FrameInsetDark") as PanelContainer
		if inset_dark != null:
			panels.append(inset_dark)
			var inset_mid := inset_dark.get_node_or_null("FrameInsetMid") as PanelContainer
			if inset_mid != null:
				panels.append(inset_mid)
	return panels


func _current_scene_image_global_rect() -> Rect2:
	if scene_image == null:
		return Rect2(Vector2.ZERO, get_viewport_rect().size)
	return scene_image.get_global_rect()


func _outset_rect(rect: Rect2, amount: float) -> Rect2:
	var inset := Vector2(amount, amount)
	return Rect2(rect.position - inset, rect.size + inset * 2.0)


func _transition_midpoint_seconds(tr: TextureRect) -> float:
	var duration := float(tr.get("duration_sec"))
	var midpoint_frame := int(tr.get("midpoint_frame"))
	var total_frames := int(tr.get("total_frames"))
	if duration <= 0.0 or total_frames <= 1:
		return ANIM_DURATION
	var midpoint_ratio := clampf(float(maxi(1, midpoint_frame) - 1) / float(total_frames - 1), 0.0, 1.0)
	return maxf(0.05, duration * midpoint_ratio)


func _transition_remaining_seconds(tr: TextureRect) -> float:
	var duration := float(tr.get("duration_sec"))
	return maxf(0.05, duration - _transition_midpoint_seconds(tr))


func _fullscreen_reveal_scene_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var overscan := 8.0
	return Rect2(Vector2(-overscan, -overscan), viewport_size + Vector2(overscan * 2.0, overscan * 2.0))


func _play_fullscreen_transition_then(swap_callback: Callable) -> void:
	var tr := _ensure_fullscreen_transition()
	if tr == null or not tr.has_method("play"):
		swap_callback.call()
		return
	tr.play(swap_callback)


func play_current_fullscreen_transition(
		at_midpoint: Callable,
		at_finished: Callable = Callable()
) -> bool:
	var tr := _ensure_fullscreen_transition()
	if tr == null or not tr.has_method("play"):
		return false
	if tr.has_method("is_playing") and tr.is_playing():
		return false
	if at_finished.is_valid():
		tr.finished.connect(at_finished, CONNECT_ONE_SHOT)
	tr.play(at_midpoint)
	return true


func _play_fullscreen_lift() -> void:
	var tr := _ensure_fullscreen_transition()
	if tr == null:
		return
	if tr.has_method("play_lift_from_midpoint"):
		tr.play_lift_from_midpoint()


func _ensure_fullscreen_transition() -> TextureRect:
	if _fullscreen_transition != null and is_instance_valid(_fullscreen_transition):
		return _fullscreen_transition

	_fullscreen_transition_layer = CanvasLayer.new()
	_fullscreen_transition_layer.name = "FullscreenTransitionLayer"
	_fullscreen_transition_layer.layer = 100
	add_child(_fullscreen_transition_layer)

	_fullscreen_transition = TRANSITION_SCENE.instantiate() as TextureRect
	if _fullscreen_transition == null:
		return null
	_fullscreen_transition.name = "FullscreenTransition"
	_fullscreen_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fullscreen_transition.anchor_left = 0.0
	_fullscreen_transition.anchor_top = 0.0
	_fullscreen_transition.anchor_right = 1.0
	_fullscreen_transition.anchor_bottom = 1.0
	_fullscreen_transition.offset_left = 0.0
	_fullscreen_transition.offset_top = 0.0
	_fullscreen_transition.offset_right = 0.0
	_fullscreen_transition.offset_bottom = 0.0
	_fullscreen_transition_layer.add_child(_fullscreen_transition)
	return _fullscreen_transition


func _is_any_transition_playing() -> bool:
	if transition != null and transition.has_method("is_playing") and transition.is_playing():
		return true
	if _fullscreen_transition != null and is_instance_valid(_fullscreen_transition):
		if _fullscreen_transition.has_method("is_playing") and _fullscreen_transition.is_playing():
			return true
	if _expanding_transition != null and is_instance_valid(_expanding_transition):
		if _expanding_transition.has_method("is_playing") and _expanding_transition.is_playing():
			return true
	return false


func _cancel_active_transitions() -> void:
	if transition != null and transition.has_method("cancel"):
		transition.cancel()
	if _fullscreen_transition != null and is_instance_valid(_fullscreen_transition):
		if _fullscreen_transition.has_method("cancel"):
			_fullscreen_transition.cancel()
	if _expanding_transition != null and is_instance_valid(_expanding_transition):
		if _expanding_transition.has_method("cancel"):
			_expanding_transition.cancel()
	_cleanup_expanding_fullscreen_transition()


# --- result handling ---

func _on_location_finished(result: Dictionary, source: Node = null) -> void:
	if source != null and source != _current_location_node:
		return
	if _intro_sequence_enabled:
		_apply_result(result)
		_advance_intro_sequence()
		return

	result = _apply_skipped_stress_test_penalty(result)
	_apply_result(result)

	if result.get("skip_advance", false):
		_show_selection_screen()
	else:
		DayCycle.advance_phase()


func _apply_skipped_stress_test_penalty(result: Dictionary) -> Dictionary:
	if not _should_apply_skipped_stress_test_penalty(result):
		return result

	var penalized_result := result.duplicate()
	penalized_result["anger_delta"] = int(penalized_result.get("anger_delta", 0)) + SKIPPED_STRESS_TEST_ANGER_DELTA
	return penalized_result


func _should_apply_skipped_stress_test_penalty(result: Dictionary) -> bool:
	if result.get("skip_advance", false):
		return false
	if GameState.phase != DayCycle.Phase.NIGHT:
		return false
	return _current_location_id != STRESS_TEST_LOCATION_ID


func _apply_result(result: Dictionary) -> void:
	var money_delta: int = result.get("money_delta", 0)
	var suspicion_delta: int = result.get("suspicion_delta", 0)
	var anger_delta: int = result.get("anger_delta", 0)
	var ingredients: Dictionary = result.get("ingredients", {})

	if money_delta != 0:    GameState.add_money(money_delta)
	if suspicion_delta != 0: GameState.add_suspicion(suspicion_delta)
	if anger_delta != 0:     GameState.add_anger(anger_delta)

	for ing_id in ingredients:
		var amt: int = ingredients[ing_id]
		var item_id := String(ing_id)
		if GameState.is_robot_part_id(item_id):
			GameState.add_robot_part(item_id, amt)
			continue
		GameState.add_ingredient(ing_id, amt)

	_log_result(money_delta, suspicion_delta, anger_delta, ingredients)


func _log_result(money: int, suspicion: int, anger: int, ingredients: Dictionary) -> void:
	var parts: Array[String] = []
	if money != 0:     parts.append("$%+d" % money)
	if suspicion != 0: parts.append("susp %+d" % suspicion)
	if anger != 0:     parts.append("anger %+d" % anger)
	for ing_id in ingredients:
		var amt: int = ingredients[ing_id]
		if amt != 0:
			parts.append("%s %+d" % [ing_id, amt])

	if parts.is_empty():
		_log("   (no effect)")
	else:
		_log("   " + "  ".join(parts))


# --- day rollover ---

func _on_day_ended(new_day: int) -> void:
	_log("[color=#88aaff]── Day %d begins ──[/color]" % new_day)


func _on_arrested() -> void:
	_log("[color=#ff7777][b]ARRESTED.[/b] Suspicion maxed out. (Punishment screen TBD.)[/color]")
	GameState.suspicion = 50
	GameState.add_money(-GameState.money / 2)


# --- event log ---

func _log(text: String) -> void:
	event_log.append_text(text + "\n")


# --- public API for location scenes ---

## Show a portrait centered inside the top framed image. Used by School to
## put a teacher in their classroom; any other location can use this the
## same way. Pass null to hide.
##
## When the X-key toggle is active, this will load the "2" variant of the
## texture (e.g., Health.png -> Health2.png) instead of the base texture.
func show_teacher_portrait(
		tex: Texture2D,
		character_name: String = "",
		subject: String = "",
		allow_alt_variant: bool = true
) -> void:
	if tex == null:
		hide_teacher_portrait()
		return

	_reset_teacher_portrait_layout()
	# Record the base (non-"2") path so we can flip variants on the X toggle.
	# tex.resource_path is the imported texture's res:// path.
	_portrait_base_path = tex.resource_path
	_portrait_allows_alt_variant = allow_alt_variant

	_apply_teacher_tag_text(character_name, subject)
	teacher_portrait.visible = true

	# Apply the current toggle (loads either base or "2" variant).
	_refresh_teacher_portrait_variant()


func show_bottom_center_portrait(
		tex: Texture2D,
		scale_multiplier: float = 1.0,
		character_name: String = "",
		subject: String = ""
) -> void:
	if tex == null:
		hide_teacher_portrait()
		return

	_portrait_base_path = tex.resource_path
	_portrait_allows_alt_variant = false
	_apply_teacher_tag_text(character_name, subject)
	teacher_portrait.texture = tex
	teacher_portrait.visible = true
	teacher_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	teacher_portrait.stretch_mode = TextureRect.STRETCH_SCALE

	var portrait_scale := _current_scene_texture_display_scale() * maxf(0.01, scale_multiplier)
	var portrait_size := tex.get_size() * portrait_scale
	var scene_display_size := _current_scene_display_size()
	var max_portrait_height := scene_display_size.y * maxf(0.01, scale_multiplier)
	if max_portrait_height > 0.0 and portrait_size.y > max_portrait_height:
		portrait_size *= max_portrait_height / portrait_size.y
	teacher_portrait.anchor_left = 0.5
	teacher_portrait.anchor_right = 0.5
	teacher_portrait.anchor_top = 1.0
	teacher_portrait.anchor_bottom = 1.0
	teacher_portrait.offset_left = -portrait_size.x * 0.5
	teacher_portrait.offset_right = portrait_size.x * 0.5
	teacher_portrait.offset_top = -portrait_size.y
	teacher_portrait.offset_bottom = 0.0


func _current_scene_texture_display_scale() -> float:
	if scene_image == null or scene_image.texture == null:
		return 1.0
	var texture_size := _texture_display_source_size(scene_image.texture)
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return 1.0
	var display_size := _current_scene_display_size()
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return 1.0
	return minf(display_size.x / texture_size.x, display_size.y / texture_size.y)


func _current_scene_display_size() -> Vector2:
	if scene_image == null:
		return DEFAULT_FRAME_SIZE
	if scene_image.texture == null:
		return scene_image.custom_minimum_size
	return _normalized_frame_size_for_texture(scene_image.custom_minimum_size, scene_image.texture)


func hide_teacher_portrait() -> void:
	teacher_portrait.visible = false
	teacher_portrait.texture = null
	teacher_tag.visible = false
	_portrait_base_path = ""
	_portrait_allows_alt_variant = true
	_reset_teacher_portrait_layout()


func _apply_teacher_tag_text(character_name: String, subject: String) -> void:
	teacher_name_label.text = character_name
	teacher_subject_label.text = subject.to_upper()
	teacher_tag.visible = character_name != ""
	var hide_subject := character_name == "Uncle" and subject.strip_edges().is_empty()
	teacher_subject_label.visible = not hide_subject
	if teacher_tag_divider != null:
		teacher_tag_divider.visible = not hide_subject


func _reset_teacher_portrait_layout() -> void:
	if teacher_portrait == null:
		return
	teacher_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	teacher_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	teacher_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	teacher_portrait.offset_left = 0.0
	teacher_portrait.offset_top = 0.0
	teacher_portrait.offset_right = 0.0
	teacher_portrait.offset_bottom = 0.0


## Re-applies the current teacher portrait texture based on _alt_portrait.
## Called when the X toggle flips, and whenever a new teacher is shown.
## If the "2" variant doesn't exist, falls back to the base texture so we
## never end up with a missing portrait.
func _refresh_teacher_portrait_variant() -> void:
	if _portrait_base_path == "":
		return

	var path_to_load: String = _portrait_base_path
	if _alt_portrait and _portrait_allows_alt_variant:
		path_to_load = _portrait_alt_path(_portrait_base_path)
		if not ResourceLoader.exists(path_to_load):
			# No "2" variant on disk - silently fall back to the base.
			path_to_load = _portrait_base_path

	var tex: Texture2D = load(path_to_load)
	if tex:
		teacher_portrait.texture = tex


func _portrait_alt_path(base_path: String) -> String:
	if base_path.get_file().begins_with("History"):
		return base_path.get_base_dir().path_join("History2.%s" % base_path.get_extension())
	return base_path.get_basename() + "2." + base_path.get_extension()


## Show a button in the bottom-right of the framed picture, mirroring the
## teacher tag in the bottom-left. Use for back/continue/finish actions
## that should live inside the frame instead of in the location's layout.
##
## Calling this with a different label/callback while the button is already
## visible replaces the previous binding cleanly - no stale handlers.
func show_corner_button(label: String, on_pressed: Callable) -> void:
	for conn in corner_button.pressed.get_connections():
		corner_button.pressed.disconnect(conn["callable"])
	corner_button.text = label
	if on_pressed.is_valid():
		corner_button.pressed.connect(on_pressed)
	corner_button.visible = true
	# Ensure the parent CornerButtonLayer is also visible — the .tscn
	# sets it visible = false by default, which would hide the button
	# regardless of its own visible flag.
	var layer: Control = corner_button.get_parent() as Control
	if layer:
		layer.visible = true


func hide_corner_button() -> void:
	for conn in corner_button.pressed.get_connections():
		corner_button.pressed.disconnect(conn["callable"])
	corner_button.visible = false

# --- player inventory overlay (Space key) ---

## Open the overlay only when we're inside a location — i.e. not on the
## selection screen (which represents "your room"). If a dialogue is
## currently typing or waiting for a click, _unhandled_input won't fire
## anyway because DialogueBox handles input first.
func _can_open_inventory() -> bool:
	# If the inventory is already up, ALWAYS allow closing it — wherever
	# we are, the player should be able to dismiss it.
	if _player_inventory_overlay and _player_inventory_overlay.visible:
		return true
	# Otherwise: only open while a location is running. Selection screen =
	# "in your room".
	return _current_location_node != null


func _toggle_inventory_overlay() -> void:
	# Lazy-create on first open so we don't pay for it on a session that
	# never hits Space.
	if _player_inventory_overlay == null:
		_player_inventory_overlay = INVENTORY_OVERLAY_SCENE.instantiate()
		add_child(_player_inventory_overlay)
	_player_inventory_overlay.toggle()

## Mount a Control as a child of SceneImage so its internal layout (bottom-
## anchored offsets, etc.) lines up with the framed picture. Used by Work
## to drop pixel-art furniture on top of the work-floor background, and
## by Store to mount its (clickable) item grid on top of the store image.
##
## The overlay is anchored full-rect to SceneImage but explicitly does NOT
## participate in minimum-size calculations — it can never push FrameOuter's
## width around.
##
## If `interactive` is true, the overlay needs to receive clicks for its
## children. SceneImage is a TextureRect with mouse_filter = STOP by default,
## which eats clicks before they reach the overlay's children — so when
## `interactive` is set we flip SceneImage to IGNORE for the lifetime of
## this overlay, and restore on hide. Pure decoration (Work) leaves it
## STOP since clicks should pass straight through to the location UI behind.
func show_scene_overlay(node: Control, interactive: bool = false) -> void:
	if node == null:
		hide_scene_overlay()
		return

	# Tear down any existing overlay first.
	hide_scene_overlay()

	# Reparent so callers can hand us a node from their own scene tree.
	var prev_parent: Node = node.get_parent()
	if prev_parent:
		prev_parent.remove_child(node)
	scene_image.add_child(node)

	# Anchor full-rect to SceneImage.
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0

	# Critical: the overlay must NOT push the container chain around.
	# Zero out the minimum size and don't let children influence it.
	node.custom_minimum_size = Vector2.ZERO

	# Don't let the overlay root itself swallow clicks — children that
	# want them set their own mouse_filter. IGNORE on the root is
	# correct for both interactive and decorative use.
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if interactive:
		# Open a click path from the viewport down into the overlay's
		# children. SceneImage sits between them and the input router.
		_prev_scene_image_mouse_filter = scene_image.mouse_filter
		scene_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_scene_overlay = node


func hide_scene_overlay() -> void:
	if _scene_overlay and is_instance_valid(_scene_overlay):
		_scene_overlay.queue_free()
	_scene_overlay = null
	# Restore SceneImage's filter if an interactive overlay flipped it.
	if _prev_scene_image_mouse_filter != -1:
		scene_image.mouse_filter = _prev_scene_image_mouse_filter
		_prev_scene_image_mouse_filter = -1
		
func show_inventory_overlay(node: Control) -> void:
	if node == null:
		hide_inventory_overlay()
		return

	hide_inventory_overlay()

	var prev_parent: Node = node.get_parent()
	if prev_parent:
		prev_parent.remove_child(node)
	add_child(node)

	# Anchor full-rect to FrameOuter so the node's own LeftColumn /
	# RightColumn anchoring (offsets from FrameOuter's edges) puts them
	# in the strips beside the picture.
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0

	# Don't let inventory contents push FrameOuter's minimum size around.
	node.custom_minimum_size = Vector2.ZERO

	node.z_index = 10
	_inventory_overlay = node


func hide_inventory_overlay() -> void:
	if _inventory_overlay and is_instance_valid(_inventory_overlay):
		_inventory_overlay.queue_free()
	_inventory_overlay = null

func _play_intro_wipe() -> void:
	if transition == null:
		return
	if transition.has_method("play_lift_from_midpoint"):
		transition.play_lift_from_midpoint()
