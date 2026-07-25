extends LocationBase

const GRID_SIZE: Vector2i = Vector2i(3, 3)
const ZOOMED_IN_SCALE: Vector2 = Vector2(2.0, 2.0)
const ZOOMED_OUT_SCALE: Vector2 = Vector2.ONE
const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const ZOOM_DURATION: float = 0.35

## Played (random pick, no pitch change) when the player pulls the blanket down.
const BLANKET_PULL_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/pulling_blanket/blanket_being_pulled_short_1.mp3",
	"res://assets/sounds/pulling_blanket/blanket_being_pulled_short_2.mp3",
	"res://assets/sounds/pulling_blanket/blanket_being_pulled_short_3.mp3",
]
## Played when the robot's head settles from its raised (animated) pose back onto
## the pillow (static).
const PILLOW_REST_SOUND_PATH: String = "res://assets/sounds/pillow/head_resting_on_pillow.mp3"

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

var _grid_cell: Vector2i = Vector2i(1, 1)
var _zoomed_in: bool = true
var _blanket_removed := false
var _has_robot_in_bed := false
var _pan_tween: Tween = null
var _zoom_tween: Tween = null

var _rng := RandomNumberGenerator.new()
var _blanket_sounds: Array[AudioStream] = []
var _blanket_audio_player: AudioStreamPlayer = null
var _pillow_audio_player: AudioStreamPlayer = null


func _ready() -> void:
	call_deferred("_initialize_zoom")
	_setup_sleep_audio()
	if bot_placeholder.has_method("set_head_interaction_enabled"):
		bot_placeholder.set_head_interaction_enabled(false)
	# Play a soft thud when the robot lowers its head back onto the pillow.
	if bot_placeholder.has_signal("head_returned_to_rest"):
		bot_placeholder.connect("head_returned_to_rest", _on_head_returned_to_rest)

	_has_robot_in_bed = GameState.equipped_limbs > 0
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

	mattress_texture.visible = false
	pillow.visible = false
	pillow_slightly_indented.visible = false
	blanket.visible = false
	_configure_head_hover_pillow_toggle()
	if bot_placeholder.has_method("set_leg_slight_out_prestage_enabled"):
		bot_placeholder.set_leg_slight_out_prestage_enabled(true)


## Debug speedrun: while Enter is held, mirror the two bed clicks — first lower
## the blanket, then (next frame) fall asleep — so the player can pass the
## bedroom without releasing Enter. Only the intro variant (no robot in bed) is
## automated; the robot-in-bed layout keeps its manual head interactions.
func _process(_delta: float) -> void:
	if _has_robot_in_bed:
		return
	if not debug_enter_held():
		return
	if not _blanket_removed:
		_blanket_removed = true
		blanket.visible = false
		blanket_bump.visible = false
		_play_blanket_pull_sound()
		return
	finish()


func _unhandled_input(event: InputEvent) -> void:
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

	scene_canvas.pivot_offset = Vector2.ZERO
	scene_canvas.position = Vector2.ZERO
	scene_canvas.scale = ZOOMED_IN_SCALE
	_apply_grid_cell(false)


func _move_grid_cell(direction: Vector2i) -> void:
	if not _zoomed_in:
		return

	var next_cell := Vector2i(
		clampi(_grid_cell.x + direction.x, 0, GRID_SIZE.x - 1),
		clampi(_grid_cell.y + direction.y, 0, GRID_SIZE.y - 1)
	)
	if next_cell == _grid_cell:
		return

	_grid_cell = next_cell
	_apply_grid_cell(true)


func _set_zoomed_in(value: bool) -> void:
	if _zoomed_in == value:
		return

	_zoomed_in = value
	if _zoomed_in:
		_grid_cell = Vector2i(1, 1)

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var target_scale := ZOOMED_IN_SCALE if _zoomed_in else ZOOMED_OUT_SCALE
	var target_position := _grid_position_for_scale(target_scale) if _zoomed_in else Vector2.ZERO

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


func _grid_position_for_scale(scale_value: Vector2) -> Vector2:
	var scaled_size := camera_window.size * scale_value
	var max_offset := Vector2(
		maxf(0.0, scaled_size.x - camera_window.size.x),
		maxf(0.0, scaled_size.y - camera_window.size.y)
	)

	if GRID_SIZE.x <= 1 or GRID_SIZE.y <= 1:
		return Vector2.ZERO

	return Vector2(
		-(float(_grid_cell.x) / float(GRID_SIZE.x - 1)) * max_offset.x,
		-(float(_grid_cell.y) / float(GRID_SIZE.y - 1)) * max_offset.y
	)


func _on_camera_window_resized() -> void:
	if _zoomed_in:
		_apply_grid_cell(false)
	else:
		scene_canvas.position = Vector2.ZERO


func _on_bed_click_area_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	get_viewport().set_input_as_handled()
	if not _blanket_removed:
		_blanket_removed = true
		blanket.visible = false
		blanket_bump.visible = false
		_play_blanket_pull_sound()
		if _has_robot_in_bed and bot_placeholder.has_method("set_head_interaction_enabled"):
			bot_placeholder.set_head_interaction_enabled(true)
		return

	if not _has_robot_in_bed:
		finish()


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
		add_child(_blanket_audio_player)

	var pillow_stream := load(PILLOW_REST_SOUND_PATH) as AudioStream
	if pillow_stream != null:
		_pillow_audio_player = AudioStreamPlayer.new()
		_pillow_audio_player.name = "PillowAudioPlayer"
		_pillow_audio_player.stream = pillow_stream
		add_child(_pillow_audio_player)


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
