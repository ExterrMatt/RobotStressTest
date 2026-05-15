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
##   frame 9/18, while the wipe hides it.
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

# HUD labels
@onready var day_label: Label = %DayLabel
@onready var phase_label: Label = %PhaseLabel
@onready var money_label: Label = %MoneyLabel
@onready var suspicion_label: Label = %SuspicionLabel
@onready var anger_label: Label = %AngerLabel
@onready var scene_image: TextureRect = %SceneImage
## Overlay portrait drawn on top of the framed scene image. Location scenes
## (e.g. School) call show_teacher_portrait() / hide_teacher_portrait(). Main
## also hides it whenever the selection screen is shown, as a backstop so
## portraits never leak between locations.
@onready var teacher_portrait: TextureRect = %TeacherPortrait
@onready var teacher_tag: PanelContainer = %TeacherTag
@onready var teacher_name_label: Label = %TeacherNameLabel
@onready var teacher_subject_label: Label = %SubjectLabel
## Bottom-right pill button inside the picture frame, mirroring the teacher
## tag in the bottom-left. Locations call show_corner_button() to mount a
## "Back"/"Continue"/etc. action here; Main hides it at transition midpoints.
@onready var corner_button: Button = %CornerButton

# Selection screen / location host
@onready var selection_screen: VBoxContainer = %SelectionScreen
@onready var location_grid: GridContainer = %LocationGrid
@onready var location_host: Control = %LocationHost

# Log overlay
@onready var log_overlay: PanelContainer = %LogOverlay
@onready var event_log: RichTextLabel = %EventLog

# In-frame FlowerLoad wipe (TextureRect parented inside the picture box).
@onready var transition: TextureRect = %Transition

var _locations: Array[LocationData] = []
var _current_location_node: Node = null
var _default_scene_image: Texture2D
## Toggle for the alternate teacher portrait (e.g., Health.png → Health2.png).
## Flipped with the X key. Persists across teachers within a session.
var _alt_portrait: bool = false

## Base texture path of the currently-shown teacher portrait (no "2" suffix),
## so we can swap variants when the toggle changes.
var _portrait_base_path: String = ""

## Set true on the very first selection-screen show, so we don't play a
## transition before the player has even seen anything.
var _has_shown_initial: bool = false


func _ready() -> void:
	# Cache the placeholder texture BEFORE anything else can swap it.
	_default_scene_image = scene_image.texture

	_load_locations()

	GameState.money_changed.connect(_on_money_changed)
	GameState.suspicion_changed.connect(_on_suspicion_changed)
	GameState.anger_changed.connect(_on_anger_changed)
	GameState.day_changed.connect(_on_day_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.arrested.connect(_on_arrested)
	DayCycle.day_ended.connect(_on_day_ended)

	_refresh_hud()
	_show_selection_screen()


func _unhandled_input(event: InputEvent) -> void:
	# Tab toggles the debug event log overlay.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			log_overlay.visible = not log_overlay.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X:
			_alt_portrait = not _alt_portrait
			_refresh_teacher_portrait_variant()
			get_viewport().set_input_as_handled()


func _load_locations() -> void:
	for path in LOCATION_RESOURCE_PATHS:
		var res: LocationData = load(path)
		if res:
			_locations.append(res)
		else:
			push_warning("Failed to load location resource: %s" % path)


# --- HUD ---

func _refresh_hud() -> void:
	day_label.text = str(GameState.day)
	phase_label.text = DayCycle.phase_name(GameState.phase).to_upper()
	money_label.text = "$%d" % GameState.money
	suspicion_label.text = str(GameState.suspicion)
	anger_label.text = str(GameState.anger)


func _on_money_changed(_v: int) -> void:    _refresh_hud()
func _on_suspicion_changed(_v: int) -> void: _refresh_hud()
func _on_anger_changed(_v: int) -> void:     _refresh_hud()
func _on_day_changed(_v: int) -> void:       _refresh_hud()
func _on_phase_changed(_v: int) -> void:
	_refresh_hud()
	_show_selection_screen()


# --- selection screen ---
#
# Behavior with the transition:
# - HUD updates and the button grid rebuild are outside the picture box
#   and snap instantly when called.
# - The picture box texture, portrait, and the SelectionScreen/LocationHost
#   visibility flips all happen at frame 9 of the wipe - so the player sees
#   the OLD content under the frame, the wipe plays, and the NEW content is
#   revealed when the wipe lifts.

func _show_selection_screen() -> void:
	# Rebuild the button grid NOW. The grid sits below the picture frame
	# and isn't visible until the location host is hidden, which happens
	# at the midpoint - so the rebuild is invisible until then anyway.
	for child in location_grid.get_children():
		child.queue_free()

	for loc in _locations:
		if not loc.available_in_phase(GameState.phase):
			continue
		var btn := _build_location_button(loc)
		location_grid.add_child(btn)

	# First load: no transition (nothing to wipe from).
	if not _has_shown_initial:
		_has_shown_initial = true
		_apply_selection_screen_swap()
		return
	_play_transition_then(_apply_selection_screen_swap)


## Runs at the wipe midpoint when returning to the selection screen.
## Everything visible in the frame area changes together.
func _apply_selection_screen_swap() -> void:
	# Tear down the previous location's UI.
	if _current_location_node and is_instance_valid(_current_location_node):
		_current_location_node.queue_free()
		_current_location_node = null

	selection_screen.visible = true
	location_host.visible = false

	scene_image.texture = PHASE_BACKGROUNDS.get(GameState.phase, _default_scene_image)
	hide_teacher_portrait()
	hide_corner_button()


func _build_location_button(loc: LocationData) -> Button:
	var btn := Button.new()
	btn.text = loc.display_name.to_upper()
	btn.tooltip_text = loc.description
	btn.custom_minimum_size = Vector2(0, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 58)
	if loc.icon:
		btn.icon = loc.icon
		btn.expand_icon = true
	btn.pressed.connect(_on_location_picked.bind(loc))
	return btn


func _on_location_picked(loc: LocationData) -> void:
	# Guard against rapid double-click stacking transitions.
	if transition.has_method("is_playing") and transition.is_playing():
		return

	# Validate the scene up-front so we can bail before starting the wipe
	# if something's wrong. The actual instantiation + swap-in happens at
	# the midpoint so the player doesn't see the location UI snap in.
	var packed: PackedScene = load(loc.scene_path)
	if packed == null:
		_log("ERROR: could not load %s" % loc.scene_path)
		return

	_log("[b]→ %s[/b]" % loc.display_name)
	_play_transition_then(_apply_location_pick_swap.bind(loc, packed))


## Runs at the wipe midpoint when picking a location.
## All frame-area changes happen together so the wipe hides them.
func _apply_location_pick_swap(loc: LocationData, packed: PackedScene) -> void:
	_current_location_node = packed.instantiate()
	location_host.add_child(_current_location_node)

	if _current_location_node.has_signal("finished"):
		_current_location_node.finished.connect(_on_location_finished)
	else:
		push_warning("Location %s did not expose a `finished` signal." % loc.display_name)

	selection_screen.visible = false
	location_host.visible = true

	if loc.preview_texture:
		scene_image.texture = loc.preview_texture


# --- transitions ---

## Play the FlowerLoad wipe, invoking `swap_callback` at frame 9/18 (when
## the picture is fully covered). Falls back to immediate invocation if
## the transition node isn't ready / missing for any reason.
func _play_transition_then(swap_callback: Callable) -> void:
	if transition == null or not transition.has_method("play"):
		swap_callback.call()
		return
	transition.play(swap_callback)


# --- result handling ---

func _on_location_finished(result: Dictionary) -> void:
	_apply_result(result)

	if result.get("skip_advance", false):
		_show_selection_screen()
	else:
		DayCycle.advance_phase()


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
func show_teacher_portrait(tex: Texture2D, character_name: String = "", subject: String = "") -> void:
	if tex == null:
		hide_teacher_portrait()
		return

	# Record the base (non-"2") path so we can flip variants on the X toggle.
	# tex.resource_path is the imported texture's res:// path.
	_portrait_base_path = tex.resource_path

	teacher_name_label.text = character_name
	teacher_subject_label.text = subject.to_upper()
	teacher_tag.visible = character_name != ""
	teacher_portrait.visible = true

	# Apply the current toggle (loads either base or "2" variant).
	_refresh_teacher_portrait_variant()


func hide_teacher_portrait() -> void:
	teacher_portrait.visible = false
	teacher_portrait.texture = null
	teacher_tag.visible = false
	_portrait_base_path = ""


## Re-applies the current teacher portrait texture based on _alt_portrait.
## Called when the X toggle flips, and whenever a new teacher is shown.
## If the "2" variant doesn't exist, falls back to the base texture so we
## never end up with a missing portrait.
func _refresh_teacher_portrait_variant() -> void:
	if _portrait_base_path == "":
		return

	var path_to_load: String = _portrait_base_path
	if _alt_portrait:
		path_to_load = _portrait_base_path.get_basename() + "2." + _portrait_base_path.get_extension()
		if not ResourceLoader.exists(path_to_load):
			# No "2" variant on disk - silently fall back to the base.
			path_to_load = _portrait_base_path

	var tex: Texture2D = load(path_to_load)
	if tex:
		teacher_portrait.texture = tex


## Show a button in the bottom-right of the framed picture, mirroring the
## teacher tag in the bottom-left. Use for back/continue/finish actions
## that should live inside the frame instead of in the location's layout.
##
## Calling this with a different label/callback while the button is already
## visible replaces the previous binding cleanly - no stale handlers.
func show_corner_button(label: String, on_pressed: Callable) -> void:
	# Drop any previous connection so we don't fire stale callbacks.
	for conn in corner_button.pressed.get_connections():
		corner_button.pressed.disconnect(conn["callable"])
	corner_button.text = label
	if on_pressed.is_valid():
		corner_button.pressed.connect(on_pressed)
	corner_button.visible = true


func hide_corner_button() -> void:
	for conn in corner_button.pressed.get_connections():
		corner_button.pressed.disconnect(conn["callable"])
	corner_button.visible = false
