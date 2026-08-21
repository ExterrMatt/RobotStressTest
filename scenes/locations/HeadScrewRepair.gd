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
## Screwing-in sounds. When a repair begins, one of these is chosen at random
## (never the same as the previous screw's) and looped for the whole screw.
const SCREW_REPAIR_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/screws/screw_in_1.mp3",
	"res://assets/sounds/screws/screw_in_2.mp3",
	"res://assets/sounds/screws/screw_in_3.mp3",
	"res://assets/sounds/screws/screw_in_4.mp3",
]
## Random pitch spread applied to every screw sound (loosen, and each screw-in
## loop): ±10% (pitch_scale 0.90 .. 1.10).
const SCREW_PITCH_VARIATION: float = 0.10
## All screw sounds (loosen + screw-in) play at 40% volume (reduced by 60%).
const SCREW_VOLUME_SCALE: float = 0.4
## Target volume for the end-of-night fade before the sound is hard-stopped.
const SCREW_AUDIO_SILENCE_DB: float = -60.0
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
## Extra offset applied to every screwdriver landing position while the limb is in
## the slightly-out leg pose, so the animation lands on the shifted screw art
## instead of the default-pose spot. Set per leg controller in the scene.
@export var slightly_out_screwdriver_offset: Vector2 = Vector2.ZERO

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
## Repairs currently in progress, keyed by body side ("left"/"right"/""). Each
## value is {"index": int, "elapsed": float}. A controller that owns both left
## and right screws (head, torso, chest) can therefore drive one screw per side
## at once; single-side arm/leg controllers still run one at a time.
var _active_repairs: Dictionary = {}
## One screwdriver/hand sprite per active side, duplicated from the authored
## template sprite so each concurrent repair renders independently.
var _side_sprites: Dictionary = {}
var _repair_animation_duration_multiplier: float = 1.0
var _completion_enabled: bool = true
var _screw_loosen_sounds: Array[AudioStream] = []
var _screw_loosen_audio_player: AudioStreamPlayer = null
var _last_screw_loosen_sound_index: int = -1
var _screw_repair_sounds: Array[AudioStream] = []
var _screw_repair_audio_player: AudioStreamPlayer = null
var _last_screw_repair_sound_index: int = -1
var _repair_sound_loop_active: bool = false
## When true the player has no screwdriver and screws by hand: a taller,
## four-frame animation that takes manual_repair_duration_multiplier times as
## long. Set by the stress test from the player's screwdriver count.
var _manual_screwing: bool = false
## When true, every screw node is kept hidden regardless of its loose state. Set
## by the robot rig while a limb is in a pose that has no screw art (e.g. a
## raised leg), so screws can stay logically loose without rendering out of place.
var _screws_force_hidden: bool = false
## True while the limb is in the slightly-out leg pose (see set_slightly_out_pose).
var _slightly_out_pose: bool = false
## Per-screw slightly-out landing nudges, keyed by screw node name (e.g. "ScrewCheek").
## The leg pivots near the hip, so each screw's art shifts by a different amount when
## the leg parts; the robot measures those shifts and supplies them here. Any screw
## not present falls back to the shared slightly_out_screwdriver_offset.
var _slightly_out_screw_offsets: Dictionary = {}
## The screwdriver sprite's authored texture, restored when not screwing by hand.
var _screwdriver_default_texture: Texture2D = null
## Resolved bare-hand texture (export or fallback path), or null when missing.
var _hand_screw_texture_resolved: Texture2D = null
## Foundational alignment nudge for the hand animation, pushed by the stress
## test so a constant offset can be corrected in one place for every screw.
var _hand_screw_offset: Vector2 = Vector2.ZERO
## Optional gate consulted before a repair may begin. Set by the stress test so
## only one screw is driven at a time (or one per side with two screwdrivers).
## Receives the screw's side ("left"/"right"/"") and returns whether to allow it.
var _repair_gate: Callable = Callable()
## Optional decider installed by the stress test that returns, per side, whether a
## starting repair should be driven by hand instead of a screwdriver - screwdrivers
## are a shared, limited resource across the whole robot. Falls back to the
## component-wide _manual_screwing flag when unset (e.g. in the editor).
var _manual_decider: Callable = Callable()


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

	if not _active_repairs.is_empty():
		_update_repair_animation(delta)


func _exit_tree() -> void:
	_stop_screw_repair_sound_loop()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled or not _completion_enabled or _loose_screw_indices.is_empty():
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
	_screw_loosen_audio_player.volume_db = linear_to_db(SCREW_VOLUME_SCALE)
	add_child(_screw_loosen_audio_player)


func _play_screw_loosen_sound() -> void:
	if _screw_loosen_audio_player == null or _screw_loosen_sounds.is_empty():
		return

	var sound_index := _rng.randi_range(0, _screw_loosen_sounds.size() - 1)
	if _screw_loosen_sounds.size() > 1 and sound_index == _last_screw_loosen_sound_index:
		sound_index = (sound_index + _rng.randi_range(1, _screw_loosen_sounds.size() - 1)) % _screw_loosen_sounds.size()
	_last_screw_loosen_sound_index = sound_index

	var variation := maxf(0.0, SCREW_PITCH_VARIATION)
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
	return not _active_repairs.is_empty()


## Whether any screw is currently loose (present) on this controller, regardless
## of whether its art is force-hidden by the current pose. The stress test uses
## this to lock the leg-pose and pelvis boxes until the leg screws are repaired.
func has_loose_screws() -> bool:
	return not _loose_screw_indices.is_empty()


## While true the screws (and the screwdriver/hand animation) are drawn at their
## slightly-out-pose positions: the screw art shifts with the parted leg, so the
## screwdriver landing point is nudged by slightly_out_screwdriver_offset to match.
func set_slightly_out_pose(value: bool) -> void:
	_slightly_out_pose = value


## Supplies per-screw slightly-out landing nudges keyed by screw node name. See
## _slightly_out_screw_offsets. Passed in by the robot, measured from the art so
## each screw's hitbox follows exactly how far its sprite moved.
func set_slightly_out_screw_offsets(offsets: Dictionary) -> void:
	_slightly_out_screw_offsets = offsets


## Whether a screw on the given side is currently being driven by this
## controller. Lets the stress test enforce one repair per side across limbs.
func is_side_repairing(side: String) -> bool:
	return _active_repairs.has(side)


## Registers the permission gate consulted before a repair starts. Pass an
## invalid Callable to clear it (repairs are then always permitted).
func set_repair_gate(gate: Callable) -> void:
	_repair_gate = gate


## Installs the per-side hand-vs-screwdriver decider (see _manual_decider).
func set_manual_decider(decider: Callable) -> void:
	_manual_decider = decider


## How many of this controller's in-progress repairs are currently driven with a
## screwdriver rather than by hand. The stress test sums this across all
## controllers to see how many of the shared screwdrivers are already in use.
func active_screwdriver_side_count() -> int:
	var count := 0
	for side in _active_repairs:
		if not bool(_active_repairs[side].get("manual", _manual_screwing)):
			count += 1
	return count


## Whether a repair starting on the given side should be driven by hand. Uses the
## installed decider (shared screwdriver budget) or the component-wide fallback.
func _decide_manual_for_side(side: String) -> bool:
	if _manual_decider.is_valid():
		return bool(_manual_decider.call(side))
	return _manual_screwing


func _can_begin_repair(index: int) -> bool:
	if not _repair_gate.is_valid():
		return true
	return bool(_repair_gate.call(hand_side_for_screw(index)))


## The body side ("left"/"right"/"") a screw belongs to. Head, torso and chest
## screws carry the side in their own name; arm and leg repairs use generic
## screw names, so those fall back to this controller's node name.
func side_for_screw(index: int) -> String:
	var screw_name := ""
	if index >= 0 and index < screw_nodes.size():
		screw_name = String(screw_nodes[index])
	return _side_from_text(screw_name, String(name))


## The physical hand ("left"/"right") that drives a screw. This is what gates
## concurrency: two screws can only be driven at once when they use different
## hands, and every screw that needs a given hand is unavailable while that hand
## is busy.
##
## The hand is decided purely by which way the screwdriver/hand points — it is
## held on the side OPPOSITE the tip. The base art points left, so it is held by
## the RIGHT hand; a flipped screw points right and is held by the LEFT hand.
func hand_side_for_screw(index: int) -> String:
	return "left" if _is_screwdriver_flipped(index) else "right"


## Any side currently being driven, or "" when idle. Prefer is_side_repairing
## for per-side checks; this stays for callers that just need one active side.
func repairing_side() -> String:
	for side in _active_repairs:
		return String(side)
	return ""


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
	if not _active_repairs.is_empty():
		return
	_manual_screwing = enabled


## Sets the foundational alignment offset applied to the hand animation only.
func set_hand_screw_offset(offset: Vector2) -> void:
	_hand_screw_offset = offset


## The hand-animation alignment nudge for the screw being driven. Zero unless
## the bare-hand animation is showing. The offset is authored against the left
## side; the right side's animation is mirrored, so its horizontal component is
## negated to keep the correction consistent.
func _hand_screw_alignment_offset_for_screw(index: int, manual: bool) -> Vector2:
	if not _uses_hand_visuals(manual):
		return Vector2.ZERO
	var offset := _hand_screw_offset
	if side_for_screw(index) == "right":
		offset.x = -offset.x
	return offset


func _uses_hand_visuals(manual: bool) -> bool:
	return manual and _hand_screw_texture_resolved != null


func _active_frame_size(manual: bool) -> Vector2i:
	if not _uses_hand_visuals(manual):
		return screwdriver_frame_size
	# Guard against a scene that serialized these exports as zero/null.
	if hand_screw_frame_size.x > 0 and hand_screw_frame_size.y > 0:
		return hand_screw_frame_size
	return Vector2i(48, 48)


func _active_frame_count(manual: bool) -> int:
	if not _uses_hand_visuals(manual):
		return screwdriver_frame_count
	return hand_screw_frame_count if hand_screw_frame_count > 0 else 4


func _apply_active_screw_texture(screwdriver: Sprite2D, manual: bool) -> void:
	if screwdriver == null:
		return
	screwdriver.texture = _hand_screw_texture_resolved if _uses_hand_visuals(manual) else _screwdriver_default_texture


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
	# Never loosen a screw whose art is force-hidden by the current pose (a raised
	# leg): the screw would be invisible and, because the leg boxes lock while any
	# screw is present, would strand the leg in the raised pose. Screws only ever
	# appear on the visible default / slightly-out leg poses.
	if _screws_force_hidden:
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
	if _active_repairs.is_empty():
		return false

	for side in _active_repairs.keys():
		var interrupted_index := int(_active_repairs[side].get("index", -1))
		_active_repairs.erase(side)
		_hide_side_sprite(side)
		repair_interrupted.emit(interrupted_index)
	_stop_screw_repair_sound_loop()
	return true


func _start_repair_animation(screw_index: int) -> void:
	# Key the repair by the driving HAND, not the body side, so a limb's flipped
	# screws occupy the opposite hand and can run alongside a same-limb screw
	# driven by the other hand.
	var side := hand_side_for_screw(screw_index)
	if _active_repairs.is_empty():
		_start_screw_repair_sound_loop()
	# Lock in the tool for this screw now: with one screwdriver the first concurrent
	# screw takes it and the second falls back to a hand (see _decide_manual_for_side).
	var manual := _decide_manual_for_side(side)
	_active_repairs[side] = {"index": screw_index, "elapsed": 0.0, "manual": manual}
	repair_started.emit(screw_index)
	var sprite := _side_sprite(side)
	if sprite != null:
		_apply_active_screw_texture(sprite, manual)
		sprite.position = _screwdriver_position_for_index(screw_index)
		_apply_screwdriver_orientation(sprite, screw_index)
		sprite.visible = true
		_set_sprite_frame(sprite, screw_index, 0, manual)


func _update_repair_animation(delta: float) -> void:
	var completed_sides: Array = []
	for side in _active_repairs.keys():
		var slot: Dictionary = _active_repairs[side]
		var manual := bool(slot.get("manual", _manual_screwing))
		slot["elapsed"] = float(slot["elapsed"]) + delta
		var screw_index := int(slot["index"])
		var frame := int(floor(float(slot["elapsed"]) * maxf(0.1, repair_animation_fps))) % maxi(1, _active_frame_count(manual))
		var sprite := _side_sprite(side)
		if sprite != null:
			_set_sprite_frame(sprite, screw_index, frame, manual)
		if _completion_enabled and float(slot["elapsed"]) >= _current_repair_animation_seconds(manual):
			completed_sides.append(side)

	for side in completed_sides:
		_complete_repair(String(side))


func _complete_repair(side: String) -> void:
	if not _active_repairs.has(side):
		return
	var repaired_index := int(_active_repairs[side].get("index", -1))
	_active_repairs.erase(side)
	_set_screw_visible(repaired_index, false)
	_loose_screw_indices.erase(repaired_index)
	_hide_side_sprite(side)
	if _active_repairs.is_empty():
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


func _current_repair_animation_seconds(manual: bool) -> float:
	# Fall back to 2x if the export was serialized as zero/null in the scene.
	var manual_multiplier := 1.0
	if manual:
		manual_multiplier = manual_repair_duration_multiplier if manual_repair_duration_multiplier > 0.0 else 2.0
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
	_set_sprite_frame(screwdriver, -1, 0, _manual_screwing)
	screwdriver.visible = false


func _resolve_hand_screw_texture() -> Texture2D:
	if hand_screw_texture != null:
		return hand_screw_texture
	if ResourceLoader.exists(HAND_SCREW_TEXTURE_PATH):
		return load(HAND_SCREW_TEXTURE_PATH) as Texture2D
	return null


func _set_sprite_frame(sprite: Sprite2D, screw_index: int, frame: int, manual: bool) -> void:
	if sprite == null:
		return
	var active_frame_size := _active_frame_size(manual)
	var frame_size := Vector2(
		float(maxi(1, active_frame_size.x)),
		float(maxi(1, active_frame_size.y))
	)
	var frame_count := maxi(1, _active_frame_count(manual))
	var clamped_frame := posmod(frame, frame_count)
	sprite.region_rect = Rect2(Vector2(0.0, float(clamped_frame) * frame_size.y), frame_size)
	var pivot_x := -frame_size.x if sprite.flip_h else 0.0
	var alignment_offset := _hand_screw_alignment_offset_for_screw(screw_index, manual)
	sprite.offset = Vector2(pivot_x, -frame_size.y * 0.5) + alignment_offset


func _apply_screwdriver_orientation(sprite: Sprite2D, index: int) -> void:
	if sprite == null:
		return
	sprite.flip_h = _is_screwdriver_flipped(index)


## Returns (creating if needed) the sprite used to render a repair on the given
## side. The authored Screwdriver node is the template; the first side reuses it
## and additional sides render on runtime duplicates so they can overlap.
func _side_sprite(side: String) -> Sprite2D:
	if _side_sprites.has(side):
		var existing := _side_sprites[side] as Sprite2D
		if existing != null and is_instance_valid(existing):
			return existing
		_side_sprites.erase(side)

	var template := _get_screwdriver()
	if template == null:
		return null

	var sprite: Sprite2D = template
	if _side_sprites.values().has(template):
		sprite = template.duplicate() as Sprite2D
		var parent := template.get_parent()
		if parent != null:
			parent.add_child(sprite)
	sprite.centered = false
	sprite.region_enabled = true
	sprite.visible = false
	_side_sprites[side] = sprite
	return sprite


func _hide_side_sprite(side: String) -> void:
	var sprite := _side_sprites.get(side) as Sprite2D
	if sprite != null and is_instance_valid(sprite):
		sprite.visible = false


func _is_screwdriver_flipped(index: int) -> bool:
	for value in flipped_screwdriver_indices:
		if int(value) == index:
			return true
	return false


func _hide_all_screws() -> void:
	_loose_screw_indices.clear()
	_active_repairs.clear()
	_stop_screw_repair_sound_loop()
	for i in range(screw_nodes.size()):
		_set_screw_visible(i, false)
	for side in _side_sprites.keys():
		_hide_side_sprite(side)
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = false


## Hides or restores every screw node without changing its loose state. While
## hidden, loose screws stay tracked (and can still be re-shown later) but do not
## render — used for poses that lack screw art, like a raised leg.
func set_screws_force_hidden(hidden: bool) -> void:
	if _screws_force_hidden == hidden:
		return
	_screws_force_hidden = hidden
	for index in range(screw_nodes.size()):
		_set_screw_visible(index, _loose_screw_indices.has(index))


func _set_screw_visible(index: int, value: bool) -> void:
	if index < 0 or index >= screw_nodes.size():
		return
	var screw := get_node_or_null(screw_nodes[index]) as CanvasItem
	if screw == null:
		return
	screw.visible = value and not _screws_force_hidden


func _screwdriver_position_for_index(index: int) -> Vector2:
	var pose_offset := _slightly_out_offset_for_index(index) if _slightly_out_pose else Vector2.ZERO
	if index >= 0 and index < screwdriver_position_paths.size():
		var marker := get_node_or_null(screwdriver_position_paths[index])
		if marker is Node2D:
			return (marker as Node2D).position + pose_offset
		if marker is Control:
			var control := marker as Control
			return control.position + control.size * 0.5 + pose_offset
	return size * 0.5 + pose_offset


## The slightly-out landing nudge for one screw: its own art-measured offset if the
## robot supplied one, otherwise the shared uniform slightly_out_screwdriver_offset.
func _slightly_out_offset_for_index(index: int) -> Vector2:
	if index >= 0 and index < screw_nodes.size():
		var node := get_node_or_null(screw_nodes[index])
		if node != null and _slightly_out_screw_offsets.has(String(node.name)):
			return _slightly_out_screw_offsets[String(node.name)]
	return slightly_out_screwdriver_offset


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
	_screw_repair_sounds.clear()
	for path in SCREW_REPAIR_SOUND_PATHS:
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		# Don't use the stream's built-in loop — we re-play the clip ourselves on
		# each finish so every repeat can get a fresh random pitch.
		_set_audio_stream_loop(stream, false)
		_screw_repair_sounds.append(stream)
	if _screw_repair_sounds.is_empty():
		return

	_screw_repair_audio_player = AudioStreamPlayer.new()
	_screw_repair_audio_player.name = "ScrewRepairAudioPlayer"
	_screw_repair_audio_player.volume_db = linear_to_db(SCREW_VOLUME_SCALE)
	add_child(_screw_repair_audio_player)
	# Each time the clip ends, restart it (see _on_screw_repair_finished) with a
	# new pitch, forming the loop.
	_screw_repair_audio_player.finished.connect(_on_screw_repair_finished)


## Begin a screwing session: pick one screw-in clip at random (never a repeat of
## the last one) and loop it — re-rolling the pitch each cycle — until the repair
## finishes or is interrupted.
func _start_screw_repair_sound_loop() -> void:
	if _screw_repair_audio_player == null or _screw_repair_sounds.is_empty():
		return

	var index := _rng.randi_range(0, _screw_repair_sounds.size() - 1)
	if _screw_repair_sounds.size() > 1 and index == _last_screw_repair_sound_index:
		index = (index + _rng.randi_range(1, _screw_repair_sounds.size() - 1)) % _screw_repair_sounds.size()
	_last_screw_repair_sound_index = index

	_repair_sound_loop_active = true
	_screw_repair_audio_player.stream = _screw_repair_sounds[index]
	_play_screw_repair_cycle()


## (Re)start the current screw-in clip with a fresh random ±SCREW_PITCH_VARIATION
## pitch, so each loop iteration sounds a little different.
func _play_screw_repair_cycle() -> void:
	if _screw_repair_audio_player == null:
		return
	var variation := maxf(0.0, SCREW_PITCH_VARIATION)
	_screw_repair_audio_player.pitch_scale = _rng.randf_range(1.0 - variation, 1.0 + variation)
	_screw_repair_audio_player.play()


## Fires when a screw-in clip finishes; re-plays it (new pitch) while the screwing
## loop is still active, so the sound repeats until the repair ends.
func _on_screw_repair_finished() -> void:
	if _repair_sound_loop_active:
		_play_screw_repair_cycle()


func _stop_screw_repair_sound_loop() -> void:
	_repair_sound_loop_active = false
	if _screw_repair_audio_player != null:
		_screw_repair_audio_player.stop()


## Stop the looping screw sound without touching repair state. The stress test
## calls this when the night ends so the loop can't bleed a sliver of audio onto
## the results screen.
func stop_repair_audio() -> void:
	_stop_screw_repair_sound_loop()


## Fade the screw sounds down to silence over `duration`, then stop them. The
## stress test calls this when the night ends so the loop bleeds out smoothly
## along with the rest of the night audio instead of cutting off hard. The loop
## keeps re-playing (at the fading volume) during the fade, then is stopped and
## its volume restored so a later repair starts at full loudness again.
func fade_out_audio(duration: float) -> void:
	if duration <= 0.0:
		_stop_screw_repair_sound_loop()
		if _screw_loosen_audio_player != null:
			_screw_loosen_audio_player.stop()
		return
	_fade_out_audio_player(_screw_repair_audio_player, duration, true)
	_fade_out_audio_player(_screw_loosen_audio_player, duration, false)


func _fade_out_audio_player(player: AudioStreamPlayer, duration: float, is_repair_loop: bool) -> void:
	if player == null or not player.playing:
		return
	var base_volume_db := player.volume_db
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SCREW_AUDIO_SILENCE_DB, duration)
	tween.tween_callback(func() -> void:
		if is_repair_loop:
			_repair_sound_loop_active = false
		player.stop()
		player.volume_db = base_volume_db
	)


## Toggle the streaming loop flag on an AudioStream (AudioStreamMP3 exposes a
## `loop` property).
func _set_audio_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", enabled)
			return


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
			_apply_screwdriver_orientation(screwdriver, editor_preview_screw_index)
			_set_sprite_frame(screwdriver, editor_preview_screw_index, 0, _manual_screwing)
