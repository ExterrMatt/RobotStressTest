@tool
extends Control

signal screw_loosened(index: int)
signal repair_started(index: int)
signal repair_interrupted(index: int)
signal screw_repaired(index: int)

const SCREW_LOOSEN_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/screws/screw_coming_loose_1.mp3",
	"res://assets/sounds/screws/screw_coming_loose_2.mp3",
	"res://assets/sounds/screws/screw_coming_loose_3.mp3",
]
const SCREW_REPAIR_SOUND_PATH: String = "res://assets/sounds/screws/screw_in_1.mp3"
const SCREW_LOOSEN_PITCH_VARIATION: float = 0.15
## Fallback path for the bare-hand screwing animation, used when the player owns
## no screwdriver. Loaded only if hand_screw_texture is left unset in the scene.
const HAND_SCREW_TEXTURE_PATH: String = "res://assets/textures/icons/hand_horizontal_screwing.png"

@export var enabled: bool = true
@export var repair_animation_seconds: float = 1.35
@export var repair_animation_fps: float = 10.0
@export var click_radius: float = 16.0
@export var randomize_screws: bool = true
@export var blocked_hover_box_paths: Array[NodePath] = []
@export var flipped_screwdriver_indices: Array = []
@export var screw_nodes: Array[NodePath] = []
@export var screwdriver_position_paths: Array[NodePath] = []
@export var screwdriver_sprite_path: NodePath = ^"Screwdriver"
@export var screwdriver_frame_size: Vector2i = Vector2i(48, 24)
@export var screwdriver_frame_count: int = 2

@export_group("Manual Screwing")
## Animation shown when the player owns no screwdriver and drives the screw by
## hand. Points left like the screwdriver, so the same flipped_screwdriver_indices
## apply. If left unset, HAND_SCREW_TEXTURE_PATH is loaded when it exists.
@export var hand_screw_texture: Texture2D
## The hand strip is twice as tall as the screwdriver strip and has four frames.
@export var hand_screw_frame_size: Vector2i = Vector2i(48, 48)
@export var hand_screw_frame_count: int = 4
## Manual screwing takes this much longer than using a screwdriver.
@export var manual_repair_duration_multiplier: float = 2.0

@export_group("Editor Preview")
@export_range(-1, 16, 1) var editor_preview_screw_index: int = -1:
	set(value):
		editor_preview_screw_index = value
		_refresh_editor_preview()
@export var editor_preview_screwdriver: bool = false:
	set(value):
		editor_preview_screwdriver = value
		_refresh_editor_preview()

var _rng := RandomNumberGenerator.new()
var _loose_screw_indices: Array = []
var _unavailable_screw_indices: Array = []
var _last_screw_index: int = -1
var _repairing: bool = false
var _repairing_screw_index: int = -1
var _repair_elapsed: float = 0.0
var _repair_animation_duration_multiplier: float = 1.0
var _completion_enabled: bool = true
var _screw_loosen_sounds: Array[AudioStream] = []
var _screw_loosen_audio_player: AudioStreamPlayer = null
var _last_screw_loosen_sound_index: int = -1
var _screw_repair_sound: AudioStream = null
var _screw_repair_audio_player: AudioStreamPlayer = null
var _repair_sound_loop_active: bool = false
var _repair_sound_segment_index: int = 0
var _repair_sound_segment_elapsed: float = 0.0
var _repair_sound_segment_playing: bool = false
## When true the player has no screwdriver and screws by hand: a taller,
## four-frame animation that takes manual_repair_duration_multiplier times as
## long. Set by the stress test from the player's screwdriver count.
var _manual_screwing: bool = false
## The screwdriver sprite's authored texture, restored when not screwing by hand.
var _screwdriver_default_texture: Texture2D = null
## Resolved bare-hand texture (export or fallback path), or null when missing.
var _hand_screw_texture_resolved: Texture2D = null
## Optional gate consulted before a repair may begin. Set by the stress test so
## only one screw is driven at a time (or one per side with two screwdrivers).
## Receives the screw's side ("left"/"right"/"") and returns whether to allow it.
var _repair_gate: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_screwdriver()
	_hide_all_screws()

	if Engine.is_editor_hint():
		_refresh_editor_preview()
		set_process(false)
		set_process_input(false)
		return

	_rng.randomize()
	_initialize_screw_loosen_sounds()
	_initialize_screw_repair_sounds()
	set_process(enabled)
	set_process_input(enabled)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _repairing:
		_update_repair_animation(delta)
		_update_screw_repair_sound(delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled or not _completion_enabled or _repairing or _loose_screw_indices.is_empty():
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var clicked_screw_index := _find_clicked_loose_screw(mouse_event.global_position)
	if clicked_screw_index < 0:
		return
	if not _can_begin_repair(clicked_screw_index):
		return

	_start_repair_animation(clicked_screw_index)
	get_viewport().set_input_as_handled()


func _loosen_next_screw() -> bool:
	var available_indices := _available_screw_indices()
	if available_indices.is_empty():
		return false
	if _any_blocked_hover_box_active():
		return false

	var next_index := int(available_indices[0])
	if randomize_screws:
		next_index = int(available_indices[_rng.randi_range(0, available_indices.size() - 1)])
		if available_indices.size() > 1 and next_index == _last_screw_index:
			var next_position := (available_indices.find(next_index) + 1) % available_indices.size()
			next_index = int(available_indices[next_position])
	else:
		for index in available_indices:
			if int(index) > _last_screw_index:
				next_index = int(index)
				break

	_last_screw_index = next_index
	_loose_screw_indices.append(next_index)
	_set_screw_visible(next_index, true)
	_play_screw_loosen_sound()
	screw_loosened.emit(next_index)
	return true


func _initialize_screw_loosen_sounds() -> void:
	_screw_loosen_sounds.clear()
	for path in SCREW_LOOSEN_SOUND_PATHS:
		var stream := load(path) as AudioStream
		if stream != null:
			_screw_loosen_sounds.append(stream)
	if _screw_loosen_sounds.is_empty():
		return

	_screw_loosen_audio_player = AudioStreamPlayer.new()
	_screw_loosen_audio_player.name = "ScrewLoosenAudioPlayer"
	add_child(_screw_loosen_audio_player)


func _play_screw_loosen_sound() -> void:
	if _screw_loosen_audio_player == null or _screw_loosen_sounds.is_empty():
		return

	var sound_index := _rng.randi_range(0, _screw_loosen_sounds.size() - 1)
	if _screw_loosen_sounds.size() > 1 and sound_index == _last_screw_loosen_sound_index:
		sound_index = (sound_index + _rng.randi_range(1, _screw_loosen_sounds.size() - 1)) % _screw_loosen_sounds.size()
	_last_screw_loosen_sound_index = sound_index

	var variation := maxf(0.0, SCREW_LOOSEN_PITCH_VARIATION)
	_screw_loosen_audio_player.stream = _screw_loosen_sounds[sound_index]
	_screw_loosen_audio_player.pitch_scale = _rng.randf_range(1.0 - variation, 1.0 + variation)
	_screw_loosen_audio_player.play()


func blocks_hover_box(box: Control) -> bool:
	if box == null or not is_instance_valid(box):
		return false
	if _loose_screw_indices.is_empty():
		return false
	return _blocked_hover_boxes().has(box)


func set_repair_animation_duration_multiplier(value: float) -> void:
	_repair_animation_duration_multiplier = maxf(0.1, value)


func is_repairing() -> bool:
	return _repairing


## Registers the permission gate consulted before a repair starts. Pass an
## invalid Callable to clear it (repairs are then always permitted).
func set_repair_gate(gate: Callable) -> void:
	_repair_gate = gate


func _can_begin_repair(index: int) -> bool:
	if not _repair_gate.is_valid():
		return true
	return bool(_repair_gate.call(side_for_screw(index)))


## The body side ("left"/"right"/"") a screw belongs to. Head, torso and chest
## screws carry the side in their own name; arm and leg repairs use generic
## screw names, so those fall back to this controller's node name.
func side_for_screw(index: int) -> String:
	var screw_name := ""
	if index >= 0 and index < screw_nodes.size():
		screw_name = String(screw_nodes[index])
	return _side_from_text(screw_name, String(name))


## The side of the screw currently being driven, or "" when idle.
func repairing_side() -> String:
	if not _repairing:
		return ""
	return side_for_screw(_repairing_screw_index)


func _side_from_text(primary: String, fallback: String) -> String:
	var side := _side_in(primary)
	if side != "":
		return side
	return _side_in(fallback)


func _side_in(text: String) -> String:
	var lower := text.to_lower()
	if lower.contains("left"):
		return "left"
	if lower.contains("right"):
		return "right"
	return ""


func set_completion_enabled(value: bool) -> void:
	_completion_enabled = value


## Switches between screwdriver and bare-hand screwing. Ignored while a repair is
## already in progress so the active animation isn't swapped mid-drive.
func set_manual_screwing(enabled: bool) -> void:
	if _repairing:
		return
	_manual_screwing = enabled


func _uses_hand_visuals() -> bool:
	return _manual_screwing and _hand_screw_texture_resolved != null


func _active_frame_size() -> Vector2i:
	return hand_screw_frame_size if _uses_hand_visuals() else screwdriver_frame_size


func _active_frame_count() -> int:
	return hand_screw_frame_count if _uses_hand_visuals() else screwdriver_frame_count


func _apply_active_screw_texture(screwdriver: Sprite2D) -> void:
	if screwdriver == null:
		return
	screwdriver.texture = _hand_screw_texture_resolved if _uses_hand_visuals() else _screwdriver_default_texture


func set_screw_available(index: int, value: bool) -> void:
	if value:
		_unavailable_screw_indices.erase(index)
	elif not _unavailable_screw_indices.has(index):
		_unavailable_screw_indices.append(index)


func loosen_screws(count: int) -> int:
	if Engine.is_editor_hint():
		return 0
	if not enabled or not _completion_enabled:
		return 0
	if _any_blocked_hover_box_active():
		return 0

	var loosened := 0
	for _i in range(maxi(0, count)):
		if not _loosen_next_screw():
			break
		loosened += 1
	return loosened


func interrupt_repair() -> bool:
	if not _repairing:
		return false

	var interrupted_index := _repairing_screw_index
	_repairing = false
	_repairing_screw_index = -1
	_repair_elapsed = 0.0
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = false
	_stop_screw_repair_sound_loop()
	repair_interrupted.emit(interrupted_index)
	return true


func _start_repair_animation(screw_index: int) -> void:
	_repairing = true
	_repairing_screw_index = screw_index
	_repair_elapsed = 0.0
	_start_screw_repair_sound_loop()
	repair_started.emit(screw_index)
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		_apply_active_screw_texture(screwdriver)
		screwdriver.position = _screwdriver_position_for_index(screw_index)
		_apply_screwdriver_orientation(screw_index)
		screwdriver.visible = true
		_set_screwdriver_frame(0)


func _update_repair_animation(delta: float) -> void:
	_repair_elapsed += delta
	var frame := int(floor(_repair_elapsed * maxf(0.1, repair_animation_fps))) % maxi(1, _active_frame_count())
	_set_screwdriver_frame(frame)

	if _repair_elapsed < _current_repair_animation_seconds():
		return
	if not _completion_enabled:
		return

	var repaired_index := _repairing_screw_index
	_set_screw_visible(repaired_index, false)
	_loose_screw_indices.erase(repaired_index)
	_repairing = false
	_repairing_screw_index = -1
	_repair_elapsed = 0.0
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = false
	_stop_screw_repair_sound_loop()
	screw_repaired.emit(repaired_index)


func _find_clicked_loose_screw(global_position: Vector2) -> int:
	var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
	var nearest_index := -1
	var nearest_distance := INF
	for index in _loose_screw_indices:
		var distance := local_position.distance_to(_screwdriver_position_for_index(int(index)))
		if distance <= click_radius and distance < nearest_distance:
			nearest_index = int(index)
			nearest_distance = distance
	return nearest_index


func _current_repair_animation_seconds() -> float:
	var manual_multiplier := maxf(0.1, manual_repair_duration_multiplier) if _manual_screwing else 1.0
	return repair_animation_seconds * _repair_animation_duration_multiplier * manual_multiplier


func _configure_screwdriver() -> void:
	var screwdriver := _get_screwdriver()
	if screwdriver == null:
		return
	if _screwdriver_default_texture == null:
		_screwdriver_default_texture = screwdriver.texture
	if _hand_screw_texture_resolved == null:
		_hand_screw_texture_resolved = _resolve_hand_screw_texture()
	screwdriver.centered = false
	screwdriver.region_enabled = true
	_set_screwdriver_frame(0)
	screwdriver.visible = false


func _resolve_hand_screw_texture() -> Texture2D:
	if hand_screw_texture != null:
		return hand_screw_texture
	if ResourceLoader.exists(HAND_SCREW_TEXTURE_PATH):
		return load(HAND_SCREW_TEXTURE_PATH) as Texture2D
	return null


func _set_screwdriver_frame(frame: int) -> void:
	var screwdriver := _get_screwdriver()
	if screwdriver == null:
		return
	var active_frame_size := _active_frame_size()
	var frame_size := Vector2(
		float(maxi(1, active_frame_size.x)),
		float(maxi(1, active_frame_size.y))
	)
	var frame_count := maxi(1, _active_frame_count())
	var clamped_frame := posmod(frame, frame_count)
	screwdriver.region_rect = Rect2(Vector2(0.0, float(clamped_frame) * frame_size.y), frame_size)
	var pivot_x := -frame_size.x if screwdriver.flip_h else 0.0
	screwdriver.offset = Vector2(pivot_x, -frame_size.y * 0.5)


func _apply_screwdriver_orientation(index: int) -> void:
	var screwdriver := _get_screwdriver()
	if screwdriver == null:
		return
	screwdriver.flip_h = _is_screwdriver_flipped(index)


func _is_screwdriver_flipped(index: int) -> bool:
	for value in flipped_screwdriver_indices:
		if int(value) == index:
			return true
	return false


func _hide_all_screws() -> void:
	_loose_screw_indices.clear()
	_repairing = false
	_repairing_screw_index = -1
	_stop_screw_repair_sound_loop()
	for i in range(screw_nodes.size()):
		_set_screw_visible(i, false)
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = false


func _set_screw_visible(index: int, value: bool) -> void:
	if index < 0 or index >= screw_nodes.size():
		return
	var screw := get_node_or_null(screw_nodes[index]) as CanvasItem
	if screw == null:
		return
	screw.visible = value


func _screwdriver_position_for_index(index: int) -> Vector2:
	if index >= 0 and index < screwdriver_position_paths.size():
		var marker := get_node_or_null(screwdriver_position_paths[index])
		if marker is Node2D:
			return (marker as Node2D).position
		if marker is Control:
			var control := marker as Control
			return control.position + control.size * 0.5
	return size * 0.5


func _available_screw_indices() -> Array:
	var indices: Array = []
	for i in range(screw_nodes.size()):
		if _loose_screw_indices.has(i) or _unavailable_screw_indices.has(i):
			continue
		indices.append(i)
	return indices


func _get_screwdriver() -> Sprite2D:
	return get_node_or_null(screwdriver_sprite_path) as Sprite2D


func _any_blocked_hover_box_active() -> bool:
	for box in _blocked_hover_boxes():
		if box.has_method("is_effect_active") and bool(box.call("is_effect_active")):
			return true
	return false


func _blocked_hover_boxes() -> Array[Control]:
	var boxes: Array[Control] = []
	for path in blocked_hover_box_paths:
		var box := get_node_or_null(path) as Control
		if box != null:
			boxes.append(box)
	return boxes


func _initialize_screw_repair_sounds() -> void:
	_screw_repair_sound = load(SCREW_REPAIR_SOUND_PATH) as AudioStream
	if _screw_repair_sound == null:
		return

	_screw_repair_audio_player = AudioStreamPlayer.new()
	_screw_repair_audio_player.name = "ScrewRepairAudioPlayer"
	add_child(_screw_repair_audio_player)


func _start_screw_repair_sound_loop() -> void:
	if _screw_repair_audio_player == null or _screw_repair_sound == null:
		return

	_repair_sound_loop_active = true
	_repair_sound_segment_index = 0
	_repair_sound_segment_elapsed = 0.0
	_repair_sound_segment_playing = false
	_begin_screw_repair_segment()


func _stop_screw_repair_sound_loop() -> void:
	_repair_sound_loop_active = false
	_repair_sound_segment_elapsed = 0.0
	_repair_sound_segment_playing = false
	if _screw_repair_audio_player != null:
		_screw_repair_audio_player.stop()


func _update_screw_repair_sound(delta: float) -> void:
	if not _repair_sound_loop_active or _screw_repair_audio_player == null:
		return

	_repair_sound_segment_elapsed += delta
	var segment_seconds := _current_screw_repair_segment_seconds()
	if _repair_sound_segment_elapsed < segment_seconds:
		return

	_repair_sound_segment_elapsed = 0.0
	if _repair_sound_segment_playing:
		_screw_repair_audio_player.stop()
		_repair_sound_segment_playing = false
	else:
		_advance_screw_repair_segment()
		_begin_screw_repair_segment()


func _advance_screw_repair_segment() -> void:
	_repair_sound_segment_index += 1
	if _repair_sound_segment_index >= 4:
		_repair_sound_segment_index = 0


func _begin_screw_repair_segment() -> void:
	if _screw_repair_audio_player == null or _screw_repair_sound == null:
		return

	var segment_seconds := _current_screw_repair_segment_seconds()
	_screw_repair_audio_player.stream = _screw_repair_sound
	_screw_repair_audio_player.pitch_scale = 1.0
	_screw_repair_audio_player.play(segment_seconds * float(_repair_sound_segment_index))
	_repair_sound_segment_playing = true


func _current_screw_repair_segment_seconds() -> float:
	if _screw_repair_sound == null:
		return 0.1
	return maxf(0.01, _screw_repair_sound.get_length() * 0.25)


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_configure_screwdriver()
	_hide_all_screws()
	if editor_preview_screw_index >= 0:
		_set_screw_visible(editor_preview_screw_index, true)
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = editor_preview_screwdriver and editor_preview_screw_index >= 0
		if screwdriver.visible:
			screwdriver.position = _screwdriver_position_for_index(editor_preview_screw_index)
			_apply_screwdriver_orientation(editor_preview_screw_index)
			_set_screwdriver_frame(0)
