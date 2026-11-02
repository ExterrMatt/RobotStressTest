extends LocationBase

## The room art (sleep.png) is SCENE_ART_SIZE: the original room fills the bottom
## ROOM_VIEW_ART of it, with extra room above (the window). The camera window always
## shows a ROOM_VIEW_ART-sized slice: zoomed out, exactly the room; zoomed in (2x), one
## cell of a grid - three columns, and four rows: a top row looking up at the window
## (UPPER_VIEW_ART_TOP), then the room's original three.
const SCENE_ART_SIZE: Vector2 = Vector2(600.0, 800.0)
const ROOM_VIEW_ART: Rect2 = Rect2(0.0, 400.0, 600.0, 400.0)
const UPPER_VIEW_ART_TOP: float = 60.0
const GRID_SIZE: Vector2i = Vector2i(3, 4)
## The zoomed-in cell the camera starts on and returns to when zooming back in.
const DEFAULT_GRID_CELL: Vector2i = Vector2i(1, 2)
const ZOOMED_IN_SCALE: Vector2 = Vector2(2.0, 2.0)
const ZOOMED_OUT_SCALE: Vector2 = Vector2.ONE
const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const ZOOM_DURATION: float = 0.35
## The zoomed-in grid cell looking straight at her in the bed (top middle); the camera
## is yanked there when she wakes up, as in the stress test.
const ROBOT_GRID_CELL: Vector2i = Vector2i(1, 1)

## Played (random pick, no pitch change) when the player pulls the blanket down.
const BLANKET_PULL_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/pulling_blanket/blanket_being_pulled_short_1.mp3",
	"res://assets/sounds/pulling_blanket/blanket_being_pulled_short_2.mp3",
	"res://assets/sounds/pulling_blanket/blanket_being_pulled_short_3.mp3",
]
## Played when the robot's head settles from its raised (animated) pose back onto
## the pillow (static).
const PILLOW_REST_SOUND_PATH: String = "res://assets/sounds/pillow/head_resting_on_pillow.mp3"
## Played as the player lays down on the mattress to sleep (the second bed click
## in the no-robot bedroom).
const MATTRESS_SOUND_PATH: String = "res://assets/sounds/bed/laying_on_a_mattress.mp3"
## Awareness / endurance meters and the stress-indicator eyes, shared with the
## stress test (see RobotAwareness.gd). They run while the robot is in the bed.
const RobotAwareness := preload("res://scenes/locations/RobotAwareness.gd")
const GLOWING_LABEL_SCRIPT := preload("res://scenes/ui/GlowingLabel.gd")
const FIXED_WIDTH_TIMER_LABEL_SCRIPT := preload("res://scenes/ui/FixedWidthTimerLabel.gd")
## The drag-the-blanket-down minigame played (with her in bed) before the blanket
## comes off.
const BlanketMinigame := preload("res://scenes/locations/BlanketMinigame.gd")

## The bedroom sheet holding the blanket-over-her sprites, one layer per pose:
## "blanket_bump_LMR", each digit how high that third of the blanket sits (5 =
## pulled right up, 1 = lowest drawn). While the blanket minigame is up, the bed
## shows the pose closest to its three pieces.
const BLANKET_SHEET_PATH: String = "res://assets/textures/backgrounds/sleep/sleep.png"
const BLANKET_SHEET_JSON_PATH: String = "res://assets/textures/backgrounds/sleep/sleep.json"
const BLANKET_POSE_LAYER_PREFIX: String = "blanket_bump_"
## The digit of a third of the blanket pulled right up.
const BLANKET_POSE_TOP: int = 5
## Dragging the blanket straight on the bed (the other way to play the blanket
## minigame). In blanket-art pixels (the 600x800 cell the poses are drawn in): where
## each third's edge sits for each row down (0 = pulled right up .. 5 = all the way
## down), measured from the poses, and the blanket's left/right extent, split into
## the three pieces.
const BLANKET_ART_SIZE: Vector2 = Vector2(600.0, 800.0)
const BLANKET_EDGE_Y_BY_ROW: Array[float] = [467.0, 518.0, 554.0, 598.0, 668.0, 740.0]
const BLANKET_ART_X_RANGE: Vector2 = Vector2(152.0, 457.0)
## How far above a piece's edge it can still be grabbed, in blanket-art pixels.
const BLANKET_GRAB_MARGIN: float = 30.0
## Screen pixels the mouse has to move with the button down before a press on the
## blanket becomes a drag (less than that and it's a click, which opens the panel).
const BLANKET_DRAG_START_PX: float = 6.0
## Leaves the blanket see-through wherever hole_mask (her arms lying on top of it, in her
## own space) is opaque, so they show through it exactly as she is drawn - her own
## layer order and the room's darkness included.
const BLANKET_HOLE_SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D hole_mask : filter_nearest;
uniform bool hole_enabled = false;
// Blanket UV -> mask UV.
uniform vec2 hole_scale = vec2(1.0);
uniform vec2 hole_offset = vec2(0.0);

void fragment() {
	if (hole_enabled) {
		vec2 m = UV * hole_scale + hole_offset;
		if (m.x >= 0.0 && m.y >= 0.0 && m.x <= 1.0 && m.y <= 1.0 && texture(hole_mask, m).a > 0.1) {
			COLOR.a = 0.0;
		}
	}
}
"""

@export_group("Awareness")
## Awareness falls while she is left undisturbed (nothing animating, no part just
## moved). There is no generator in the bedroom, so instead the fall speeds up the
## longer she is left alone: from the start rate up to the max rate over the ramp.
## With the blanket minigame up, it only falls while its meter reads green.
@export var awareness_decay_start_per_second: float = 1.0
@export var awareness_decay_max_per_second: float = 15.0
@export var awareness_decay_ramp_seconds: float = 5.0
## Awareness added per second while the blanket minigame's meter reads orange or
## red, ramping from the start rate up to the max over the same ramp seconds as
## the decay, from when the meter entered that zone.
@export var blanket_orange_gain_start_per_second: float = 1.0
@export var blanket_orange_gain_max_per_second: float = 10.0
@export var blanket_red_gain_start_per_second: float = 5.0
@export var blanket_red_gain_max_per_second: float = 20.0
@export var awareness_label_text: String = "Awareness"
@export var endurance_label_text: String = "Endurance"
@export var robot_endurance_label_text: String = "Robot Endurance"

@export_group("Night Timer")
## The night's base length with her in bed - the same base as the stress test's, and
## extended the same way (banked bonus time, time per robot part: see
## GameState.night_duration_seconds). When it runs out the night ends, as with END.
@export var night_duration_seconds: float = 60.0
@export var timer_label_text: String = "Time"
@export var awareness_failure_title: String = "SHE WOKE UP"
@export var awareness_failure_text: String = "You woke her up."
@export var restart_night_button_text: String = "RESTART NIGHT"

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var blanket: TextureRect = %Blanket
@onready var blanket_bump: TextureRect = %BlanketBump
@onready var bot_placeholder: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/BotPlaceholder
@onready var bot_shadow_light: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/BotShadowLight
@onready var bot_shadow_heavy: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/BotShadowHeavy
@onready var mattress_texture: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/MattressTexture
@onready var mattress_texture_indent: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/MattressTextureIndent
@onready var pillow: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/Pillow
@onready var pillow_indented: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/PillowIndented
@onready var pillow_slightly_indented: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Bed/PillowSlightlyIndented
@onready var end_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/EndButton
@onready var awareness_meter: RobotAwareness = $RobotAwareness

var _grid_cell: Vector2i = DEFAULT_GRID_CELL
var _zoomed_in: bool = true
var _blanket_removed := false
var _has_robot_in_bed := false
## False when the player answered NO to the bedtime prompt: the bed stays empty
## even though the robot has a body.
var _bring_robot := true
var _pan_tween: Tween = null
## True once the camera has been forced onto her (she woke up): the player can no
## longer pan or zoom.
var _camera_locked: bool = false
## Zoomed out there are two views: the room (the bottom half of the art) and, above it,
## the window (the top half). True while the window one is showing.
var _out_view_upper: bool = false
var _zoom_tween: Tween = null

var _rng := RandomNumberGenerator.new()
var _blanket_sounds: Array[AudioStream] = []
var _blanket_audio_player: AudioStreamPlayer = null
var _pillow_audio_player: AudioStreamPlayer = null
var _mattress_stream: AudioStream = null
## Top-right readouts: endurance always, awareness only in debug mode (the player
## reads awareness off the eyes, as in the stress test).
var _awareness_label: Label = null
var _endurance_label: Label = null
var _robot_endurance_label: Label = null
## The night clock (with her in bed): seconds gone, the Infinite Time debug cheat,
## and its readout.
var _night_elapsed: float = 0.0
var _debug_infinite_time: bool = false
var _timer_label: Label = null
## Set once she has woken up and the failure screen is up.
var _woke_failed: bool = false
## The open blanket minigame (null when it isn't up).
var _blanket_minigame: Control = null
## The blanket poses from the bedroom sheet (see _blanket_poses).
var _blanket_pose_cache: Array = []
## The digits of the blanket pose on the bed (5 = a third pulled right up).
var _blanket_pose_digits: Array = [BLANKET_POSE_TOP, BLANKET_POSE_TOP, BLANKET_POSE_TOP]
## Images of the blanket poses, for the per-pixel cover test.
var _blanket_image_cache: Dictionary = {}
## The blanket's see-through hole for arms lying on top of it: its material, the
## arm-shaped mask, what the mask was last built from, and full-cell images of her
## layers' textures.
var _blanket_hole_material: ShaderMaterial = null
var _blanket_hole_signature: Array = []
var _robot_cell_image_cache: Dictionary = {}
## A press on the blanket itself: the piece gripped (-1 = none), where the press
## started, whether the mouse has since moved enough to count as a drag (otherwise the
## release is a click, opening the panel), and the gap between the grab point and that
## piece's edge (blanket-art pixels) so the edge doesn't jump to the cursor.
var _blanket_press_piece: int = -1
var _blanket_press_position: Vector2 = Vector2.ZERO
var _blanket_moved: bool = false
var _blanket_grab_offset: float = 0.0
## Seconds she has been left undisturbed, driving the decay ramp.
var _awareness_calm_elapsed: float = 0.0
## The blanket meter's zone last frame, and seconds it has held in that zone
## (driving the orange / red gain ramps).
var _blanket_zone: int = BlanketMinigame.Zone.GREEN
var _blanket_zone_elapsed: float = 0.0
var _failure_overlay: Control = null
## Full-screen root on its own canvas layer just above the scene's, holding the
## eyes, readouts and failure screen - the bed art sits at z-index 2000, which
## would otherwise draw over them.
var _hud_root: Control = null


func _ready() -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("consume_sleep_bring_robot"):
		_bring_robot = bool(main.call("consume_sleep_bring_robot"))
	call_deferred("_initialize_zoom")
	_setup_sleep_audio()
	# She can be touched from the start, but the blanket is a barrier: nothing of hers
	# under it can be hovered or grabbed until it is pulled off that spot.
	bot_placeholder.set("interaction_blocker", _blanket_covers)
	bot_placeholder.set("arm_rests_on_cover_check", _blanket_low_enough_for_arms)
	# The corner END button: Maintenance's gold look, and drawn above the bed (the
	# blanket sits at a high z-index, which would otherwise cover it).
	style_corner_button(end_button)
	end_button.z_index = blanket_bump.z_index + 100
	# Play a soft thud when the robot lowers its head back onto the pillow.
	if bot_placeholder.has_signal("head_returned_to_rest"):
		bot_placeholder.connect("head_returned_to_rest", _on_head_returned_to_rest)

	_apply_bed_occupancy()
	# Same night length as the stress test would have tonight.
	night_duration_seconds = GameState.night_duration_seconds(night_duration_seconds)
	_initialize_awareness_meter()


## Lays out the bed for whether a robot is in it (has legs). Extracted from _ready
## so it can be re-run when parts are granted mid-sleep (see debug_recalibrate),
## making a robot that gains limbs appear in the bed instead of staying hidden.
func _apply_bed_occupancy() -> void:
	_has_robot_in_bed = _bring_robot and GameState.equipped_limbs > 0
	end_button.visible = _has_robot_in_bed
	end_button.disabled = not _has_robot_in_bed

	if not _has_robot_in_bed:
		bot_placeholder.visible = false
		bot_shadow_light.visible = false
		bot_shadow_heavy.visible = false
		mattress_texture.visible = true
		mattress_texture_indent.visible = false
		pillow.visible = true
		pillow_indented.visible = false
		pillow_slightly_indented.visible = false
		blanket.visible = true
		blanket_bump.visible = false
		return

	bot_placeholder.visible = true
	bot_shadow_light.visible = true
	bot_shadow_heavy.visible = true
	mattress_texture_indent.visible = true
	pillow_indented.visible = true
	blanket_bump.visible = true
	if not _blanket_removed:
		# Pulled right up over her until the blanket minigame starts.
		var pulled_up: Array[float] = [float(BLANKET_POSE_TOP), float(BLANKET_POSE_TOP), float(BLANKET_POSE_TOP)]
		_show_blanket_pose(pulled_up)

	mattress_texture.visible = false
	pillow.visible = false
	pillow_slightly_indented.visible = false
	blanket.visible = false
	_configure_head_hover_pillow_toggle()
	# Limbs take the stress test's poses (minus its limb-move minigames, which are off
	# by default), with no Sleep-only "slightly out" leg pre-stage. Here her arms and
	# legs are dragged in a direction to move rather than clicked.
	if bot_placeholder.has_method("set_leg_slight_out_prestage_enabled"):
		bot_placeholder.set_leg_slight_out_prestage_enabled(false)
	bot_placeholder.set("directional_limb_drag_enabled", true)
	bot_placeholder.set("drag_to_remove_items_enabled", true)


## Forwarded from the Shift+Tab debug menu: cycle / read the robot's animation
## loop-slurp sound override (for auditioning the pelvis/head sounds). Present so
## the sound-test control appears in the Sleep scene as well as the stress test.
func debug_cycle_anim_sound() -> void:
	if bot_placeholder != null and bot_placeholder.has_method("debug_cycle_anim_sound"):
		bot_placeholder.call("debug_cycle_anim_sound")


func debug_anim_sound_label() -> String:
	if bot_placeholder != null and bot_placeholder.has_method("debug_anim_sound_label"):
		return String(bot_placeholder.call("debug_anim_sound_label"))
	return "Anim Sound: Default"


## Driven by Main's Shift+Tab debug grants (e.g. the number-4 give-all-items): when
## robot parts are added mid-sleep, re-lay-out the bed so a now-limbed robot appears
## (it was hidden if the scene opened with an empty bed), then rebuild the robot so
## newly granted limbs/cosmetics show. Mirrors the stress test's own recalibrate.
func debug_recalibrate() -> void:
	if (_bring_robot and GameState.equipped_limbs > 0) != _has_robot_in_bed:
		_apply_bed_occupancy()
		_refresh_meter_hud()
	if bot_placeholder != null and is_instance_valid(bot_placeholder) \
			and bot_placeholder.has_method("_refresh_configuration"):
		bot_placeholder.call("_refresh_configuration")


## Debug speedrun: while Enter is held, mirror the two bed clicks — first lower
## the blanket, then (next frame) fall asleep — so the player can pass the
## bedroom without releasing Enter. Only the intro variant (no robot in bed) is
## automated; the robot-in-bed layout keeps its manual head interactions.
func _process(delta: float) -> void:
	if _has_robot_in_bed:
		_update_awareness_meter(delta)
		return
	if not debug_enter_held():
		return
	if not _blanket_removed:
		_blanket_removed = true
		blanket.visible = false
		blanket_bump.visible = false
		_play_blanket_pull_sound()
		return
	_play_mattress_sound()
	finish()


func _unhandled_input(event: InputEvent) -> void:
	if _camera_locked:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoomed_in(false)
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoomed_in(true)
			get_viewport().set_input_as_handled()
			return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	if key_event.keycode == KEY_Z:
		_set_zoomed_in(not _zoomed_in)
		get_viewport().set_input_as_handled()
		return

	var direction := Vector2i.ZERO
	match key_event.keycode:
		KEY_W:
			direction.y = -1
		KEY_A:
			direction.x = -1
		KEY_S:
			direction.y = 1
		KEY_D:
			direction.x = 1
		_:
			return

	_move_grid_cell(direction)
	get_viewport().set_input_as_handled()


func _initialize_zoom() -> void:
	if camera_window == null or scene_canvas == null:
		return

	if camera_window.size == Vector2.ZERO:
		await get_tree().process_frame

	if not camera_window.resized.is_connected(_on_camera_window_resized):
		camera_window.resized.connect(_on_camera_window_resized)

	_fit_scene_canvas()
	scene_canvas.pivot_offset = Vector2.ZERO
	scene_canvas.scale = ZOOMED_IN_SCALE
	_apply_grid_cell(false)


## Sizes the scene canvas to the whole room art at the camera window's scale (one
## window width per SCENE_ART_SIZE.x art pixels), taller than the window.
func _fit_scene_canvas() -> void:
	scene_canvas.custom_minimum_size = Vector2.ZERO
	scene_canvas.size = SCENE_ART_SIZE * (camera_window.size.x / SCENE_ART_SIZE.x)


func _move_grid_cell(direction: Vector2i) -> void:
	if not _zoomed_in:
		# Zoomed out: up / down flips between the window view and the room view.
		if direction.y == 0 or (direction.y < 0) == _out_view_upper:
			return
		_out_view_upper = direction.y < 0
		_pan_canvas_to(_room_view_position())
		return

	# Outside debug mode the window row (row 0) is off limits.
	var min_row := 0 if _debug_mode_enabled() else 1
	var next_cell := Vector2i(
		clampi(_grid_cell.x + direction.x, 0, GRID_SIZE.x - 1),
		clampi(_grid_cell.y + direction.y, min_row, GRID_SIZE.y - 1)
	)
	if next_cell == _grid_cell:
		return

	_grid_cell = next_cell
	_apply_grid_cell(true)


## Yanks the camera onto her (zoomed in on the top-middle cell) and locks it there, as
## the stress test does when she wakes: the player sees her wake up.
func _force_camera_to_robot() -> void:
	_camera_locked = true
	if camera_window == null or scene_canvas == null:
		return
	_zoomed_in = true
	_grid_cell = ROBOT_GRID_CELL
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", ZOOMED_IN_SCALE, ZOOM_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", _grid_position_for_scale(ZOOMED_IN_SCALE), ZOOM_DURATION)


func _set_zoomed_in(value: bool) -> void:
	if _zoomed_in == value or _camera_locked:
		return
	# Zooming out is a debug-only view.
	if not value and not _debug_mode_enabled():
		return

	_zoomed_in = value
	if _zoomed_in:
		# Zooming in from the window view lands on the window row; from the room view,
		# on the usual starting cell.
		_grid_cell = Vector2i(DEFAULT_GRID_CELL.x, 0) if _out_view_upper else DEFAULT_GRID_CELL
	else:
		# Zooming out from the window row shows the window view, otherwise the room.
		_out_view_upper = _grid_cell.y == 0

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var target_scale := ZOOMED_IN_SCALE if _zoomed_in else ZOOMED_OUT_SCALE
	var target_position := _grid_position_for_scale(target_scale) if _zoomed_in else _room_view_position()

	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", target_scale, ZOOM_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", target_position, ZOOM_DURATION)


func _apply_grid_cell(animated: bool) -> void:
	var target_position := _grid_position_for_scale(scene_canvas.scale)

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()

	if not animated:
		scene_canvas.position = target_position
		return

	_pan_tween = create_tween()
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_property(scene_canvas, "position", target_position, PAN_DURATION)


## Canvas position that puts art point `view_top_left` at the camera window's corner at
## `scale_value`.
func _canvas_position_for_view(view_top_left: Vector2, scale_value: Vector2) -> Vector2:
	var px_per_art := camera_window.size.x / SCENE_ART_SIZE.x
	return -view_top_left * px_per_art * scale_value


## Zoomed out: the original room, exactly as it always looked - or, looking up, the
## window above it (the top half of the art).
func _room_view_position() -> Vector2:
	var top := Vector2(ROOM_VIEW_ART.position.x, 0.0) if _out_view_upper else ROOM_VIEW_ART.position
	return _canvas_position_for_view(top, ZOOMED_OUT_SCALE)


## Pans the (zoomed-out) canvas to `target`, like a grid step.
func _pan_canvas_to(target: Vector2) -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_property(scene_canvas, "position", target, PAN_DURATION)


## Zoomed in on the current grid cell. Row 0 looks up at the window; rows 1-3 step over
## the room as the original 3x3 grid did.
func _grid_position_for_scale(scale_value: Vector2) -> Vector2:
	var view := ROOM_VIEW_ART.size / scale_value
	var room_rows := GRID_SIZE.y - 1
	var x := float(_grid_cell.x) / float(maxi(1, GRID_SIZE.x - 1)) * (ROOM_VIEW_ART.size.x - view.x)
	var y := UPPER_VIEW_ART_TOP
	if _grid_cell.y >= 1:
		y = ROOM_VIEW_ART.position.y \
				+ float(_grid_cell.y - 1) / float(maxi(1, room_rows - 1)) * (ROOM_VIEW_ART.size.y - view.y)
	return _canvas_position_for_view(Vector2(ROOM_VIEW_ART.position.x + x, y), scale_value)


func _debug_mode_enabled() -> bool:
	return bool(GameState.get("debug_mode_enabled"))


func _on_camera_window_resized() -> void:
	_fit_scene_canvas()
	if _zoomed_in:
		_apply_grid_cell(false)
	else:
		scene_canvas.position = _room_view_position()


func _on_bed_click_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_blanket_press_motion()
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse_event.pressed:
		_on_blanket_press_released()
		return

	get_viewport().set_input_as_handled()
	if not _blanket_removed:
		# With her in bed the blanket has to be eased down: dragged straight on the
		# bed, or in the blanket minigame panel (a click opens it). An empty bed just
		# pulls it straight off.
		if _has_robot_in_bed:
			if not _begin_blanket_press(mouse_event.global_position):
				_open_blanket_minigame()
		else:
			_remove_blanket()
		return

	if not _has_robot_in_bed:
		_play_mattress_sound()
		finish()


func _remove_blanket() -> void:
	_blanket_removed = true
	blanket.visible = false
	blanket_bump.visible = false
	_play_blanket_pull_sound()
	if _has_robot_in_bed and bot_placeholder.has_method("set_head_interaction_enabled"):
		bot_placeholder.set_head_interaction_enabled(true)


## Shows the close-up blanket panel on the left of the screen (with its tilt meter).
func _open_blanket_minigame() -> void:
	if awareness_meter.is_waking():
		return
	_ensure_blanket_minigame()
	if _blanket_minigame != null:
		_blanket_minigame.visible = true


## The blanket minigame holds the blanket's state whichever way it is played, so it
## exists (hidden until the panel is opened) while she is under the blanket.
func _ensure_blanket_minigame() -> void:
	if _blanket_minigame != null or _woke_failed or _hud_root == null \
			or _blanket_removed or not _has_robot_in_bed:
		return
	var minigame := BlanketMinigame.new()
	minigame.visible = false
	minigame.name = "BlanketMinigame"
	_hud_root.add_child(minigame)
	# Pinned to the left edge, centred vertically.
	var panel_size: Vector2 = minigame.custom_minimum_size
	minigame.anchor_top = 0.5
	minigame.anchor_bottom = 0.5
	minigame.offset_left = 24.0
	minigame.offset_top = -panel_size.y * 0.5
	minigame.offset_right = 24.0 + panel_size.x
	minigame.offset_bottom = panel_size.y * 0.5
	minigame.completed.connect(_on_blanket_minigame_completed)
	minigame.jolted.connect(_on_blanket_minigame_jolted)
	_blanket_minigame = minigame


func _close_blanket_minigame() -> void:
	_reset_blanket_press()
	if _blanket_minigame != null and is_instance_valid(_blanket_minigame):
		_blanket_minigame.queue_free()
	_blanket_minigame = null


## Dragging the blanket's pieces along, or moving them too quickly, jolts her.
func _on_blanket_minigame_jolted(amount: float) -> void:
	if _woke_failed or awareness_meter.is_waking():
		return
	awareness_meter.add(amount)
	_awareness_calm_elapsed = 0.0
	_refresh_meter_hud()


func _on_blanket_minigame_completed() -> void:
	_close_blanket_minigame()
	_remove_blanket()


# --- Dragging the blanket on the bed ---

## The mouse in blanket-art pixels.
func _blanket_art_mouse() -> Vector2:
	if blanket_bump.size.x <= 0.0 or blanket_bump.size.y <= 0.0:
		return Vector2(-1.0, -1.0)
	return blanket_bump.get_local_mouse_position() * BLANKET_ART_SIZE / blanket_bump.size


## Where a piece's edge sits (blanket-art y) at `row` rows down, interpolated over
## the measured rows so a different grid_rows still lines up.
func _blanket_edge_y(row: float) -> float:
	var rows := 5
	if _blanket_minigame != null and is_instance_valid(_blanket_minigame):
		rows = maxi(1, int(_blanket_minigame.get("grid_rows")))
	var t := clampf(row / float(rows), 0.0, 1.0) * float(BLANKET_EDGE_Y_BY_ROW.size() - 1)
	var i := mini(int(t), BLANKET_EDGE_Y_BY_ROW.size() - 2)
	return lerpf(BLANKET_EDGE_Y_BY_ROW[i], BLANKET_EDGE_Y_BY_ROW[i + 1], t - float(i))


## The grid row whose edge is nearest blanket-art y.
func _blanket_row_for_y(y: float) -> int:
	var rows := maxi(1, int(_blanket_minigame.get("grid_rows")))
	var best := 0
	for row in rows + 1:
		if absf(_blanket_edge_y(row) - y) < absf(_blanket_edge_y(best) - y):
			best = row
	return best


## The piece the mouse is over on the bed - its third of the blanket, from just above
## its edge down - or -1.
func _blanket_piece_under_mouse() -> int:
	if _blanket_removed or not _has_robot_in_bed or _woke_failed or awareness_meter.is_waking() \
			or _blanket_minigame == null or not is_instance_valid(_blanket_minigame) \
			or not blanket_bump.is_visible_in_tree():
		return -1
	var art := _blanket_art_mouse()
	var width := BLANKET_ART_X_RANGE.y - BLANKET_ART_X_RANGE.x
	if art.x < BLANKET_ART_X_RANGE.x or art.x >= BLANKET_ART_X_RANGE.y or art.y > BLANKET_ART_SIZE.y:
		return -1
	var piece := clampi(int((art.x - BLANKET_ART_X_RANGE.x) / (width / 3.0)), 0, 2)
	var row := int(_blanket_minigame.call("piece_row", piece))
	if art.y < _blanket_edge_y(row) - BLANKET_GRAB_MARGIN:
		return -1
	return piece


## A press on the bed: true when it landed on a piece of the blanket, which is gripped
## right away (closed hand) and follows the mouse from there.
func _begin_blanket_press(press_position: Vector2) -> bool:
	_ensure_blanket_minigame()
	var piece := _blanket_piece_under_mouse()
	if piece < 0:
		return false
	_blanket_press_piece = piece
	_blanket_press_position = press_position
	_blanket_moved = false
	var row := int(_blanket_minigame.call("piece_row", piece))
	_blanket_grab_offset = _blanket_edge_y(row) - _blanket_art_mouse().y
	_blanket_minigame.call("begin_external_drag", piece)
	_update_blanket_cursor()
	return true


func _on_blanket_press_motion() -> void:
	if _blanket_press_piece < 0 or _blanket_minigame == null or not is_instance_valid(_blanket_minigame):
		return
	if get_global_mouse_position().distance_to(_blanket_press_position) >= BLANKET_DRAG_START_PX:
		_blanket_moved = true
	var row := _blanket_row_for_y(_blanket_art_mouse().y + _blanket_grab_offset)
	_blanket_minigame.call("external_drag_to_row", row)
	get_viewport().set_input_as_handled()


## Letting go: a press that barely moved was a click, which opens the panel.
func _on_blanket_press_released() -> void:
	if _blanket_press_piece < 0:
		return
	var was_click := not _blanket_moved
	_reset_blanket_press()
	if was_click:
		_open_blanket_minigame()
	_update_blanket_cursor()
	get_viewport().set_input_as_handled()


func _reset_blanket_press() -> void:
	if _blanket_press_piece >= 0 and _blanket_minigame != null and is_instance_valid(_blanket_minigame):
		_blanket_minigame.call("end_external_drag")
	_blanket_press_piece = -1
	_blanket_moved = false


## Whether the blanket on the bed covers canvas position `global_pos` (an opaque pixel
## of the pose showing) - the barrier that keeps her parts under it out of reach. The
## blanket panel, when open, also keeps clicks on it from reaching her below.
func _blanket_covers(global_pos: Vector2) -> bool:
	if _blanket_minigame != null and is_instance_valid(_blanket_minigame) and _blanket_minigame.visible \
			and _blanket_minigame.get_global_rect().has_point(_blanket_minigame.get_global_mouse_position()):
		return true
	if _blanket_removed or not blanket_bump.is_visible_in_tree() or blanket_bump.texture == null:
		return false
	if blanket_bump.size.x <= 0.0 or blanket_bump.size.y <= 0.0:
		return false
	var local := blanket_bump.get_global_transform().affine_inverse() * global_pos
	if local.x < 0.0 or local.y < 0.0 or local.x >= blanket_bump.size.x or local.y >= blanket_bump.size.y:
		return false
	var tex := blanket_bump.texture
	if not _blanket_image_cache.has(tex):
		var image := tex.get_image()
		if image != null and image.is_compressed():
			image.decompress()
		_blanket_image_cache[tex] = image
	var img: Image = _blanket_image_cache[tex]
	if img == null:
		return false
	var pixel := Vector2i(local / blanket_bump.size * Vector2(img.get_size()))
	pixel = pixel.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
	return img.get_pixelv(pixel).a > 0.1


## Whether an arm lowered right now comes to rest on top of the blanket: it is on the
## bed and pulled down off the top everywhere (a pose of 444 or lower - no 5s).
func _blanket_low_enough_for_arms() -> bool:
	if _blanket_removed or not blanket_bump.is_visible_in_tree():
		return false
	for digit in _blanket_pose_digits:
		if int(digit) >= BLANKET_POSE_TOP:
			return false
	return true


## An arm the player lowered from a raised pose while the blanket was down (444 or
## lower) lies on top of it - upper arm, forearm, hand and shoulder pad, in whatever
## pose - and can be touched there, until it is lowered again with the blanket up.
## Arms that never moved stay underneath. Once the blanket is off it doesn't matter.
## The arm isn't re-layered: the blanket goes see-through in its shape, so she still
## draws in her own order.
func _update_arms_over_blanket() -> void:
	var on_blanket := not _blanket_removed and blanket_bump.is_visible_in_tree()
	bot_placeholder.call("set_arms_drawn_over",
			on_blanket and bool(bot_placeholder.call("is_arm_on_cover", 0)),
			on_blanket and bool(bot_placeholder.call("is_arm_on_cover", 1)))
	_update_blanket_arm_hole()


## Keeps the blanket's arm-shaped hole matching the arms lying on top of it. The mask
## is rebuilt only when what those arms show changes (pose, hand, pad); the mapping
## from the blanket onto her is refreshed every frame.
func _update_blanket_arm_hole() -> void:
	if _blanket_hole_material == null:
		var shader := Shader.new()
		shader.code = BLANKET_HOLE_SHADER_CODE
		_blanket_hole_material = ShaderMaterial.new()
		_blanket_hole_material.shader = shader
		blanket_bump.material = _blanket_hole_material
	var robot := bot_placeholder as Control
	var layers: Array = bot_placeholder.call("arm_cover_mask_layers")
	if layers.is_empty() or robot.size.x <= 0.0 or robot.size.y <= 0.0:
		_blanket_hole_material.set_shader_parameter("hole_enabled", false)
		_blanket_hole_signature = []
		return
	var to_robot := robot.get_global_transform().affine_inverse()
	var signature: Array = [robot.size]
	for layer in layers:
		signature.append([layer, layer.texture, to_robot * layer.get_global_transform()])
	if signature != _blanket_hole_signature:
		_blanket_hole_signature = signature
		_blanket_hole_material.set_shader_parameter("hole_mask", _build_arm_hole_mask(layers, robot))
	# Blanket UV -> blanket local -> canvas -> her local -> mask UV.
	var blanket_to_robot := to_robot * blanket_bump.get_global_transform()
	_blanket_hole_material.set_shader_parameter("hole_scale",
			blanket_to_robot.get_scale() * blanket_bump.size / robot.size)
	_blanket_hole_material.set_shader_parameter("hole_offset", blanket_to_robot.origin / robot.size)
	_blanket_hole_material.set_shader_parameter("hole_enabled", true)


## The union of `layers`' pixels, laid out in her own space (one mask pixel per unit of
## her size).
func _build_arm_hole_mask(layers: Array, robot: Control) -> ImageTexture:
	var size := Vector2i(robot.size.round())
	var mask := Image.create_empty(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	var to_robot := robot.get_global_transform().affine_inverse()
	for layer in layers:
		var cell: Image = _robot_cell_image(layer.texture)
		if cell == null:
			continue
		var placed: Transform2D = to_robot * layer.get_global_transform()
		var target := Vector2i((layer.size * placed.get_scale()).round())
		if target.x <= 0 or target.y <= 0:
			continue
		if cell.get_size() != target:
			cell = cell.duplicate()
			cell.resize(target.x, target.y, Image.INTERPOLATE_NEAREST)
		mask.blend_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i(placed.origin.round()))
	return ImageTexture.create_from_image(mask)


## A texture of hers as a full-cell RGBA image (an AtlasTexture's region put back at its
## margin), built once each.
func _robot_cell_image(tex: Texture2D) -> Image:
	if _robot_cell_image_cache.has(tex):
		return _robot_cell_image_cache[tex]
	var image: Image = null
	if tex is AtlasTexture:
		var atlas := tex as AtlasTexture
		var sheet := atlas.atlas.get_image() if atlas.atlas != null else null
		if sheet != null:
			if sheet.is_compressed():
				sheet.decompress()
			sheet.convert(Image.FORMAT_RGBA8)
			var cell_size := Vector2i(tex.get_size())
			image = Image.create_empty(maxi(1, cell_size.x), maxi(1, cell_size.y), false, Image.FORMAT_RGBA8)
			image.blit_rect(sheet, Rect2i(atlas.region), Vector2i(atlas.margin.position))
	else:
		image = tex.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
	_robot_cell_image_cache[tex] = image
	return image


## The cursor over the bed: a closed hand from the click on a piece of the blanket
## until it is let go, an open hand over a piece that can be grabbed.
func _update_blanket_cursor() -> void:
	# A release something else took (the inventory, the post-it note) still lets go of
	# the blanket - just dropped where it is, not taken as a click.
	if _blanket_press_piece >= 0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_reset_blanket_press()
	var state: int = CursorTheme.Grab.NONE
	if _blanket_press_piece >= 0:
		state = CursorTheme.Grab.CLOSED
	elif _blanket_piece_under_mouse() >= 0:
		state = CursorTheme.Grab.OPEN
	CursorTheme.set_grab(self, state)


func _exit_tree() -> void:
	CursorTheme.set_grab(self, CursorTheme.Grab.NONE)


func _configure_head_hover_pillow_toggle() -> void:
	var head_hover_box := bot_placeholder.get_node_or_null("HeadHoverBox")
	if head_hover_box == null:
		return

	_append_unique_node_path(head_hover_box, "hidden_while_active_image_paths", ^"../PillowIndented")
	_append_unique_node_path(head_hover_box, "shown_while_active_image_paths", ^"../PillowSlightlyIndented")
	if bot_placeholder.has_method("_refresh_configuration"):
		bot_placeholder.call("_refresh_configuration")


func _append_unique_node_path(node: Node, property_name: StringName, path: NodePath) -> void:
	var paths: Array = node.get(property_name)
	if paths.has(path):
		return
	paths.append(path)
	node.set(property_name, paths)


func _on_end_button_pressed() -> void:
	finish()


# --- Awareness / endurance ---

## Same meters as the stress test while she is in the bed: moving her parts and her
## animations raise awareness (it falls at a flat rate while she is undisturbed), the
## eyes show it in the top-left, and endurance winds her animations down. Waking
## her fails the night, with the option to restart it.
func _initialize_awareness_meter() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "AwarenessHudLayer"
	var fullscreen_layer := get_node_or_null(^"FullscreenLayer") as CanvasLayer
	hud_layer.layer = (fullscreen_layer.layer if fullscreen_layer != null else 20) + 1
	add_child(hud_layer)
	_hud_root = Control.new()
	_hud_root.name = "HudRoot"
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(_hud_root)

	awareness_meter.setup(bot_placeholder, _hud_root, _has_robot_in_bed)
	_create_meter_labels(_hud_root)
	if bot_placeholder.has_signal("body_part_moved"):
		bot_placeholder.connect("body_part_moved", _on_body_part_moved)
	awareness_meter.woke_up.connect(_on_robot_woke_up)
	awareness_meter.wake_finished.connect(_on_robot_wake_finished)
	_refresh_meter_hud()


## Shows the blanket pose closest to the blanket minigame's three pieces.
func _update_blanket_stage() -> void:
	if _blanket_minigame == null or not is_instance_valid(_blanket_minigame):
		return
	var heights: Array[float] = []
	for value in _blanket_minigame.get("progress"):
		heights.append((1.0 - float(value)) * BLANKET_POSE_TOP)
	_show_blanket_pose(heights)


## Puts the blanket pose nearest `heights` (one per third, left to right, on the
## pose digits' scale) on the bed: the smallest squared difference in each third's
## height plus in the step between neighbouring thirds (so the pose keeps the
## blanket's shape), ties going to the pose pulled further down.
func _show_blanket_pose(heights: Array[float]) -> void:
	var best: Texture2D = null
	var best_distance := INF
	var best_total := INF
	for pose in _blanket_poses():
		var digits: Array = pose[0]
		var distance := 0.0
		var total := 0.0
		var count := mini(digits.size(), heights.size())
		for i in count:
			distance += pow(heights[i] - float(digits[i]), 2.0)
			total += float(digits[i])
			if i > 0:
				distance += pow((heights[i] - heights[i - 1]) - float(digits[i] - digits[i - 1]), 2.0)
		if distance < best_distance or (distance == best_distance and total < best_total):
			best = pose[1]
			best_distance = distance
			best_total = total
	if best != null and blanket_bump.texture != best:
		blanket_bump.texture = best
	for pose in _blanket_poses():
		if pose[1] == best:
			_blanket_pose_digits = pose[0]


## [[digits: Array[int], texture: Texture2D], ...] for every blanket_bump_LMR
## layer in the bedroom sheet, built once.
func _blanket_poses() -> Array:
	if not _blanket_pose_cache.is_empty():
		return _blanket_pose_cache
	var layers := PackedSpriteSheet.layer_textures(BLANKET_SHEET_PATH, BLANKET_SHEET_JSON_PATH)
	for layer in layers:
		# Stray spaces in a layer name (e.g. "blanket_bump_432 ") don't count.
		var name_text := String(layer).strip_edges()
		if not name_text.begins_with(BLANKET_POSE_LAYER_PREFIX):
			continue
		var code := name_text.trim_prefix(BLANKET_POSE_LAYER_PREFIX)
		if code.length() != 3 or not code.is_valid_int():
			continue
		var digits: Array[int] = []
		for character in code:
			digits.append(int(character))
		_blanket_pose_cache.append([digits, _fit_blanket_cell(layers[layer])])
	return _blanket_pose_cache


## The sheet's canvas can be taller than the bed art this scene is laid out on (extra
## room added at the top): keep the bottom BLANKET_ART_SIZE of each pose, which lines
## up with the bed exactly as before.
func _fit_blanket_cell(tex: Texture2D) -> Texture2D:
	var cell := Vector2i(tex.get_size())
	var art := Vector2i(BLANKET_ART_SIZE)
	if cell == art or cell.x < art.x or cell.y < art.y:
		return tex
	var image := tex.get_image()
	var region := Rect2i(Vector2i((cell.x - art.x) / 2, cell.y - art.y), art)
	return ImageTexture.create_from_image(image.get_region(region))


func _update_awareness_meter(delta: float) -> void:
	_update_blanket_cursor()
	if _woke_failed:
		return
	_ensure_blanket_minigame()
	_update_blanket_stage()
	_update_arms_over_blanket()
	if awareness_meter.is_waking():
		awareness_meter.update_waking(delta)
		return
	# The blanket meter off green stirs her: a gain that ramps up the longer it
	# stays orange (or red), in place of the decay.
	var blanket_gain := _current_blanket_gain_per_second(delta)
	if awareness_meter.is_body_animation_playing() or blanket_gain > 0.0:
		_awareness_calm_elapsed = 0.0
	else:
		_awareness_calm_elapsed += delta
	awareness_meter.update_awareness(delta, blanket_gain, _current_awareness_decay_per_second())
	awareness_meter.update_endurance(delta)
	awareness_meter.update_eyes(delta)
	if not awareness_meter.is_waking():
		_update_night_timer(delta)
	_refresh_meter_hud()


## Runs the night clock; when it runs out the night ends, as with the END button.
func _update_night_timer(delta: float) -> void:
	if _woke_failed or _finished_emitted:
		return
	if not _debug_infinite_time:
		_night_elapsed += delta
	if _night_elapsed >= night_duration_seconds and not _debug_infinite_time:
		finish()


## The time left, formatted as the stress test shows it (MM:SS.cc).
func _format_remaining_time() -> String:
	var remaining := maxf(0.0, night_duration_seconds - _night_elapsed)
	var total_seconds := int(floor(remaining))
	var minutes := int(total_seconds / 60)
	var seconds := int(total_seconds % 60)
	var centiseconds := int(floor((remaining - float(total_seconds)) * 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]


## Decay per second while undisturbed: the start rate, ramping linearly up to the
## max rate over the ramp seconds, then holding there.
func _current_awareness_decay_per_second() -> float:
	var t := clampf(_awareness_calm_elapsed / maxf(0.001, awareness_decay_ramp_seconds), 0.0, 1.0)
	return lerpf(awareness_decay_start_per_second, awareness_decay_max_per_second, t)


## Gain per second from the blanket minigame's meter (0 in green or with the
## minigame closed), advancing its zone ramp by `delta`: the zone's start rate,
## ramping linearly to its max over the ramp seconds, restarting on a zone change.
func _current_blanket_gain_per_second(delta: float = 0.0) -> float:
	var zone: int = BlanketMinigame.Zone.GREEN
	if _blanket_minigame != null and is_instance_valid(_blanket_minigame):
		zone = int(_blanket_minigame.call("meter_zone"))
	if zone != _blanket_zone:
		_blanket_zone = zone
		_blanket_zone_elapsed = 0.0
	else:
		_blanket_zone_elapsed += delta
	var t := clampf(_blanket_zone_elapsed / maxf(0.001, awareness_decay_ramp_seconds), 0.0, 1.0)
	if zone == BlanketMinigame.Zone.ORANGE:
		return lerpf(blanket_orange_gain_start_per_second, blanket_orange_gain_max_per_second, t)
	if zone == BlanketMinigame.Zone.RED:
		return lerpf(blanket_red_gain_start_per_second, blanket_red_gain_max_per_second, t)
	return 0.0


func _on_body_part_moved(is_leg_raise: bool) -> void:
	if _woke_failed or awareness_meter.is_waking():
		return
	awareness_meter.add_for_move(is_leg_raise)
	_awareness_calm_elapsed = 0.0
	_refresh_meter_hud()


## She woke up: no more touching her (or ending the night) while her eyes open.
func _on_robot_woke_up() -> void:
	# The blanket stays exactly where it was: close the panel and let go of it, but keep
	# its state (throwing the minigame away here would let a fresh one - pulled right
	# up - take its place before the night fails).
	_reset_blanket_press()
	if _blanket_minigame != null and is_instance_valid(_blanket_minigame):
		_blanket_minigame.visible = false
	if bot_placeholder.has_method("set_head_interaction_enabled"):
		bot_placeholder.set_head_interaction_enabled(false)
	end_button.disabled = true
	_force_camera_to_robot()


## The wake delay ran out: the night fails, behind the same wipe the stress test's
## results screen uses, and the player can restart it.
func _on_robot_wake_finished() -> void:
	if _woke_failed:
		return
	_woke_failed = true
	var main := get_tree().current_scene
	if main != null and main.has_method("play_current_fullscreen_transition"):
		if bool(main.call("play_current_fullscreen_transition", _show_failure_overlay, _on_failure_transition_finished)):
			return
	_show_failure_overlay()
	_on_failure_transition_finished()


func _show_failure_overlay() -> void:
	awareness_meter.set_hud_visible(false)
	if _failure_overlay == null:
		_failure_overlay = _build_failure_overlay()
	_failure_overlay.visible = true


func _on_failure_transition_finished() -> void:
	get_tree().paused = true


func _on_restart_night_pressed() -> void:
	get_tree().paused = false
	var main := get_tree().current_scene
	if main != null and main.has_method("restart_sleep_with_robot"):
		main.call("restart_sleep_with_robot")
	else:
		get_tree().reload_current_scene()


## Failure screen in the stress test's style: grey dim, a centred panel with the
## title and reason, and a button to restart the night.
func _build_failure_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "FailureOverlay"
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	overlay.z_index = 100
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.38, 0.38, 0.38, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -150.0
	panel.offset_right = 280.0
	panel.offset_bottom = 150.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = awareness_failure_title
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var reason := Label.new()
	reason.text = awareness_failure_text
	reason.add_theme_font_size_override("font_size", 22)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(reason)

	var restart := Button.new()
	restart.text = restart_night_button_text
	restart.custom_minimum_size = Vector2(220, 48)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restart.pressed.connect(_on_restart_night_pressed)
	vbox.add_child(restart)

	_hud_root.add_child(overlay)
	return overlay


## Endurance / awareness readouts in the top-right, styled like the stress test's.
func _create_meter_labels(parent: Control) -> void:
	if parent == null:
		return
	var box := VBoxContainer.new()
	box.name = "SleepHud"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.offset_left = -380.0
	box.offset_top = 16.0
	box.offset_right = -16.0
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	# The night clock, styled like the stress test's.
	_timer_label = Label.new()
	_timer_label.set_script(FIXED_WIDTH_TIMER_LABEL_SCRIPT)
	_timer_label.add_theme_color_override("font_color", Color(1, 0.64, 0.26, 1))
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.set("glow_radius_px", 25.0)
	box.add_child(_timer_label)
	_awareness_label = _make_meter_label(Color(1, 0.42, 0.42, 1), Color(1, 0.16, 0.16, 1))
	box.add_child(_awareness_label)
	_endurance_label = _make_meter_label(Color(0.62, 0.85, 1, 1), Color(0.2, 0.6, 1, 1))
	box.add_child(_endurance_label)
	_robot_endurance_label = _make_meter_label(Color(0.85, 0.72, 1, 1), Color(0.55, 0.3, 1, 1))
	box.add_child(_robot_endurance_label)


func _make_meter_label(font_color: Color, glow_color: Color) -> Label:
	var label := Label.new()
	label.set_script(GLOWING_LABEL_SCRIPT)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set("glow_color", glow_color)
	label.set("glow_radius_px", 25.0)
	label.set("glow_strength", 1.7)
	return label


## Debug-menu cheat toggles (Main's Shift+Tab menu), as in the stress test:
## "no_awareness" pins her awareness at 0, "infinite_time" stops the night clock.
## Returns the cheat's new state.
func debug_toggle_cheat(cheat: String) -> bool:
	match cheat:
		"no_awareness":
			awareness_meter.pinned_at_zero = not awareness_meter.pinned_at_zero
			if awareness_meter.pinned_at_zero:
				awareness_meter.awareness = 0.0
		"infinite_time":
			_debug_infinite_time = not _debug_infinite_time
	_refresh_meter_hud()
	return debug_cheat_enabled(cheat)


func debug_cheat_enabled(cheat: String) -> bool:
	match cheat:
		"no_awareness":
			return awareness_meter.pinned_at_zero
		"infinite_time":
			return _debug_infinite_time
	return false


func _refresh_meter_hud() -> void:
	awareness_meter.set_hud_visible(_has_robot_in_bed and not _woke_failed)
	var debug_mode := bool(GameState.get("debug_mode_enabled"))
	if _awareness_label != null:
		_awareness_label.visible = _has_robot_in_bed and debug_mode
		_awareness_label.text = "%s: %.0f / %.0f (%+.1f/s)" % [
			awareness_label_text,
			awareness_meter.awareness,
			awareness_meter.threshold,
			awareness_meter.awareness_rate_per_second(_current_blanket_gain_per_second(), _current_awareness_decay_per_second()),
		]
	if _endurance_label != null:
		_endurance_label.visible = _has_robot_in_bed
		_endurance_label.text = "%s: %.0f / %.0f" % [
			endurance_label_text,
			awareness_meter.endurance,
			awareness_meter.endurance_threshold,
		]
	if _timer_label != null:
		_timer_label.visible = _has_robot_in_bed and not _woke_failed
		_timer_label.text = "%s: %s" % [timer_label_text, _format_remaining_time()]
	if _robot_endurance_label != null:
		_robot_endurance_label.visible = _has_robot_in_bed
		_robot_endurance_label.text = "%s: %.0f / %.0f" % [
			robot_endurance_label_text,
			awareness_meter.robot_endurance,
			awareness_meter.robot_endurance_threshold,
		]
		# Debug: the seconds left on the awareness lock while it holds.
		if debug_mode and awareness_meter.is_awareness_locked():
			_robot_endurance_label.text += " (%.1fs)" % awareness_meter.awareness_lock_remaining


# --- Audio ---

func _setup_sleep_audio() -> void:
	_rng.randomize()
	for path in BLANKET_PULL_SOUND_PATHS:
		var stream := load(path) as AudioStream
		if stream != null:
			_blanket_sounds.append(stream)
	if not _blanket_sounds.is_empty():
		_blanket_audio_player = AudioStreamPlayer.new()
		_blanket_audio_player.name = "BlanketAudioPlayer"
		_blanket_audio_player.volume_db = linear_to_db(GameState.DEFAULT_SFX_VOLUME_SCALE)
		add_child(_blanket_audio_player)

	var pillow_stream := load(PILLOW_REST_SOUND_PATH) as AudioStream
	if pillow_stream != null:
		_pillow_audio_player = AudioStreamPlayer.new()
		_pillow_audio_player.name = "PillowAudioPlayer"
		_pillow_audio_player.stream = pillow_stream
		_pillow_audio_player.volume_db = linear_to_db(GameState.DEFAULT_SFX_VOLUME_SCALE)
		add_child(_pillow_audio_player)

	_mattress_stream = load(MATTRESS_SOUND_PATH) as AudioStream


## Lay-down SFX as the player gets onto the mattress. Played on a detached player
## (parented to the persistent scene) so it rings out through the sleep transition
## that immediately follows finish(), instead of being cut off with this scene.
func _play_mattress_sound() -> void:
	play_oneshot_stream_detached(_mattress_stream, GameState.DEFAULT_SFX_VOLUME_SCALE)


## Random blanket-pull sound, no pitch change.
func _play_blanket_pull_sound() -> void:
	if _blanket_audio_player == null or _blanket_sounds.is_empty():
		return
	_blanket_audio_player.stream = _blanket_sounds[_rng.randi_range(0, _blanket_sounds.size() - 1)]
	_blanket_audio_player.play()


func _on_head_returned_to_rest() -> void:
	if _pillow_audio_player == null:
		return
	_pillow_audio_player.play()
