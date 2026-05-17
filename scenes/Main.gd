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

const INVENTORY_OVERLAY_SCENE: PackedScene = preload("res://scenes/ui/InventoryOverlay.tscn")

## Default rendered size of the framed scene image. Matches the size hard-
## coded in Main.tscn for SceneImage.custom_minimum_size, and the 1.8x
## upscaling of standard 500x125 backgrounds (500*1.8 = 900, 125*1.8 = 225).
## Locations with taller source art override via LocationData.frame_size.
const DEFAULT_FRAME_SIZE: Vector2 = Vector2(900, 225)

## Duration and easing for both the scale animation (frame resize between
## locations) and the slide animation (layout shifts inside a location).
## TRANS_QUAD + EASE_IN_OUT gives the "soft start, soft stop" feel.
const ANIM_DURATION: float = 0.2
const ANIM_TRANS: int = Tween.TRANS_QUAD
const ANIM_EASE: int = Tween.EASE_IN_OUT

# HUD labels
@onready var day_label: Label = %DayLabel
@onready var phase_label: Label = %PhaseLabel
@onready var money_label: Label = %MoneyLabel
@onready var suspicion_label: Label = %SuspicionLabel
@onready var anger_label: Label = %AngerLabel
@onready var scene_image: TextureRect = %SceneImage
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

## Active tween animating SceneImage.custom_minimum_size between
## DEFAULT_FRAME_SIZE and a location's preferred frame_size. Kept as a
## field so we can kill it if a new transition starts mid-animation.
var _frame_size_tween: Tween = null

## Active tween animating FrameOuter.custom_minimum_size.x. Separate from
## _frame_size_tween so kills are independent (each can be replaced
## individually if a location changes one but not the other).
var _frame_outer_tween: Tween = null

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

## Overlay node currently parented to FrameOuter (e.g. Work's inventory
## columns that flank the picture). Tracked separately from _scene_overlay
## so the two can coexist — Work uses both: FurnitureLayer sits inside the
## picture, WorkInventory flanks it. Cleared on selection-screen swap.
var _inventory_overlay: Control = null

## The player-wide inventory overlay (the Space-key one). Separate from
## _inventory_overlay above, which is the per-location work-minigame
## inventory that flanks the picture frame.
var _player_inventory_overlay: InventoryOverlay = null

func _ready() -> void:
	# Cache the placeholder texture BEFORE anything else can swap it.
	_default_scene_image = scene_image.texture

	# Make sure we start at the canonical default size — defensive in case
	# the .tscn ever drifts from DEFAULT_FRAME_SIZE.
	scene_image.custom_minimum_size = DEFAULT_FRAME_SIZE

	# Cache FrameOuter's editor-set minimum width as the "default" we
	# animate back to. Unlike the scene image, we don't hardcode this
	# constant — the .tscn is the source of truth so it can be tweaked
	# in the editor without touching code.
	_default_frame_outer_width = frame_outer.custom_minimum_size.x

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
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event

	# Tab toggles the debug event log overlay.
	if key_event.keycode == KEY_TAB:
		log_overlay.visible = not log_overlay.visible
		get_viewport().set_input_as_handled()
		return

	# X swaps the alt teacher portrait variant.
	if key_event.keycode == KEY_X:
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
# - The frame SIZE change (scale animation) is kicked off at the same
#   midpoint but plays out across ~0.2s of the wipe's second half + slightly
#   beyond if needed. The eased size change overlaps the tail of the wipe
#   so the frame's already at its new size as the wipe lifts.

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
	hide_scene_overlay()
	hide_inventory_overlay()

	# Selection screen always uses the default frame size. Animate back to
	# it in case we were just inside a location with a larger frame.
	_animate_frame_size_to(DEFAULT_FRAME_SIZE)
	_animate_frame_outer_width_to(_default_frame_outer_width)


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

	# Resize the frame to this location's preferred size (or default if
	# the resource doesn't declare one). Eases in/out over ANIM_DURATION.
	var target: Vector2 = loc.frame_size if loc.frame_size != Vector2.ZERO else DEFAULT_FRAME_SIZE
	_animate_frame_size_to(target)

	# Same for the outer frame width — independent so locations can
	# declare just one or the other. frame_outer_width <= 0 means "use
	# the .tscn default", which we cached at _ready.
	var target_outer: float = loc.frame_outer_width if loc.frame_outer_width > 0.0 else _default_frame_outer_width
	_animate_frame_outer_width_to(target_outer)


# --- frame size (scale) animation ---

## Tween SceneImage.custom_minimum_size to `target` with ease-in/ease-out.
## Snaps immediately if we're already there. Kills any in-flight tween so
## a fast back-to-back location change doesn't fight itself.
func _animate_frame_size_to(target: Vector2) -> void:
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

	# Capture the FrameWrap's global position before the mutation. We
	# animate the wrap (the CenterContainer that holds the framed image),
	# not the SceneImage itself, because the slide we want to show is the
	# whole picture frame moving — rivets, corner button, everything.
	var frame_wrap: Control = scene_image.get_parent().get_parent().get_parent().get_parent() as Control
	# That walks: SceneImage -> FrameInsetMid -> FrameInsetDark ->
	# FrameOuter -> FrameWrap. If the tree shape ever changes, this needs
	# to keep up — kept as a chain instead of a hardcoded path so it
	# breaks loudly rather than silently animating the wrong node.
	if frame_wrap == null:
		mutator.call()
		return

	var old_global_y: float = frame_wrap.global_position.y

	# Apply the mutation. The container chain reflows synchronously.
	mutator.call()

	# Force the layout to settle NOW so global_position reflects the new
	# target. Without this the new position isn't known until the end of
	# the frame.
	frame_wrap.get_tree().process_frame  # touch to prevent linter unused
	# In Godot 4, queue_sort + update_minimum_size is the recommended
	# nudge. The deferred call below resolves the actual tween once layout
	# has settled this frame.
	frame_wrap.queue_sort()

	call_deferred("_finish_slide_animation", frame_wrap, old_global_y)


## Deferred half of animate_layout_change. Runs AFTER the reflow has
## settled (next idle frame), at which point frame_wrap.global_position
## reflects the new spot. We tween the difference using an offset so the
## container layout itself isn't fought.
func _finish_slide_animation(frame_wrap: Control, old_global_y: float) -> void:
	if frame_wrap == null or not is_instance_valid(frame_wrap):
		return

	var new_global_y: float = frame_wrap.global_position.y
	var delta_y: float = old_global_y - new_global_y

	# No movement — no animation needed.
	if absf(delta_y) < 0.5:
		return

	# Kill any in-flight slide so back-to-back layout changes don't stack.
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	# Pre-offset the frame to its OLD position, then tween the offset to
	# zero. position is a Control property (independent of the container's
	# resolved layout), so this gives a smooth visual slide without
	# breaking the layout system.
	frame_wrap.position.y = delta_y

	_slide_tween = create_tween()
	_slide_tween.set_trans(ANIM_TRANS)
	_slide_tween.set_ease(ANIM_EASE)
	_slide_tween.tween_property(frame_wrap, "position:y", 0.0, ANIM_DURATION)


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
## to drop pixel-art furniture on top of the work-floor background.
##
## The overlay is anchored full-rect to SceneImage but explicitly does NOT
## participate in minimum-size calculations — it's decorative only, so it
## can never push FrameOuter's width around.
##
## If the node already has a parent, it's reparented (not duplicated).
## Calling this while another overlay is already shown replaces the old one.
func show_scene_overlay(node: Control) -> void:
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
	# Don't eat clicks meant for buttons in the location UI below.
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_scene_overlay = node


func hide_scene_overlay() -> void:
	if _scene_overlay and is_instance_valid(_scene_overlay):
		_scene_overlay.queue_free()
	_scene_overlay = null

## Mount a Control as a sibling layer over FrameOuter so it can render
## in the strips of frame to the left and right of SceneImage. Used by
## Work for the draggable-shape inventory columns.
##
## Anchored full-rect to FrameOuter. Like show_scene_overlay, the overlay
## is reparented (not duplicated) and is forced not to participate in
## minimum-size calculations so it can't widen the frame.
##
## Mouse filter is left at the caller's discretion here — the inventory
## DOES want to receive clicks on its draggable items, unlike the purely
## decorative FurnitureLayer overlay.
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
