extends Node
## The robot's awareness and endurance, shared by every scene she sleeps in (the
## stress test and the Sleep scene).
##
## Awareness climbs while a body animation plays and when her parts are moved, plus
## any steady gain the scene adds (the stress test's power level and loose screws),
## and only falls - at a rate the scene supplies - while she is left undisturbed.
## It drives the stress-indicator eyes in the top-left of the screen and her face.
## Once it maxes out the eyes' end loop runs as a buffer; still maxed when that
## finishes and she wakes up (woke_up), and the scene fails the night a moment
## later (wake_finished).
##
## Endurance builds while an animation actively plays; at the threshold it winds
## the animation down automatically (pre-done then done), and resets to 0 once
## that endurance wind-down's done animation finishes. Cancelling an animation
## early does not reset it.

## She woke up: the scene should stop the player interacting with her.
signal woke_up
## The wake delay has passed: the scene should end the night as a failure.
signal wake_finished

## Stress-indicator eyes (top-left HUD): a horizontal strip of 19 64x32 frames
## exported from "stress indicator eyes.aseprite", in three sections. Frames 1-10
## (eyes opening) and 11-15 (eyes fill black, pupils turn red) both track
## awareness; 16-19 loop once awareness is maxed, as the buffer before she wakes,
## and keep looping after she does. Indices below are 0-based.
const EYES_SHEET_PATH := "res://assets/textures/icons/stress_indicator_eyes_strip.png"
const EYES_FRAME_SIZE := Vector2(64, 32)
## Outline drawn behind the eyes when awareness gets high. It is 66x32: the eye
## frame plus one pixel each side, so it sits one pixel left of the eyes.
const EYES_OUTLINE_PATH := "res://assets/textures/icons/stress_test_indicator_outline.png"
const EYES_OUTLINE_OFFSET := Vector2(-1, 0)
const EYES_OPEN_FRAMES: int = 10
const EYES_FILL_FIRST_FRAME: int = 10
const EYES_FILL_FRAMES: int = 5
const EYES_LOOP_FIRST_FRAME: int = 15
const EYES_LOOP_FRAMES: int = 4
## Every frame past frame 8 (1-based) puts the angry face on the robot.
const EYES_ANGRY_FROM_FRAME: int = 8

## CALM: frames follow awareness. BUFFER: awareness is maxed and the end loop is
## counting down. WAKING: she woke up and the night is about to end.
enum State { CALM, BUFFER, WAKING }

@export_group("Awareness")
## Steady climb per second while any body animation (head talk / pelvis lift) plays.
@export var animation_gain_per_second: float = 12.0
## Awareness added for an ordinary body-part move, and for the heavier leg lift
## from the slightly-out pose up to the raised pose.
@export var move_gain: float = 5.0
@export var leg_raise_gain: float = 10.0

@export_group("Stress Eyes")
## Awareness ratio where the eye-opening frames (1-10) end and the fill frames
## (11-15) take over, running from here up to max awareness.
@export_range(0.05, 0.95, 0.01) var eyes_fill_start_ratio: float = 0.95
## Curve on how awareness maps onto the eye-opening frames 1-10 (across their
## share of awareness, up to the fill start). The frame progress is that ratio ^
## this exponent, so below 1 the eyes open early: 0.5 puts the halfway frame a
## quarter of the way in (0.25 ^ 0.5 = 0.5). 1 is linear.
@export_range(0.1, 1.0, 0.05) var eyes_awareness_curve: float = 0.5
## Seconds per frame of the end loop (frames 16-19).
@export var eyes_loop_frame_seconds: float = 0.1
## Once awareness is maxed, the end loop plays this many times as the player's
## buffer. Still maxed when it finishes and she wakes up.
@export var eyes_buffer_loops: int = 5
## From this awareness ratio up, the eyes' outline flashes on and off, each half
## of the flash lasting the flash seconds.
@export_range(0.0, 1.0, 0.01) var eyes_outline_flash_ratio: float = 0.87
@export var eyes_outline_flash_seconds: float = 0.2
## Seconds between her waking up and the night ending.
@export var wake_fail_delay_seconds: float = 2.0
## On-screen pixel scale of the eyes and their margin from the top-left corner.
@export var eyes_scale: float = 3.0
@export var eyes_margin: Vector2 = Vector2(16, 16)

@export_group("Endurance")
## Endurance builds while a body animation is actively playing. When it reaches
## the threshold the animation automatically winds down (its pre-done then done
## strips), and the counter resets once the animation has finished.
@export var endurance_threshold: float = 100.0
@export var endurance_head_gain_per_second: float = 8.0
@export var endurance_pelvis_gain_per_second: float = 10.0
## How fast endurance falls while it is not ticking up (no animation building it).
@export var endurance_decay_per_second: float = 2.0
## When on, awareness can't rise while endurance sits at its threshold (it can still
## fall) - e.g. through the wind-down that maxing endurance starts.
@export var pause_awareness_at_max_endurance: bool = true
## Robot endurance: a second, slower meter that fills at this fraction (0.5 = half) of
## endurance's pelvis rate while the pelvis animation plays - the head talk never
## feeds it - and otherwise drains at endurance's own decay rate. When it reaches its
## threshold, awareness cannot rise at all for the lock seconds (it can still fall);
## after that robot endurance starts again from 0.
@export var robot_endurance_rate_multiplier: float = 0.5
@export var robot_endurance_threshold: float = 100.0
@export var robot_endurance_awareness_lock_seconds: float = 10.0
## Robot endurance added each time a wind-down's pre-done strip finishes a pass.
@export var robot_endurance_per_pre_done_loop: float = 4.0
## While that lock holds she smiles: happy faces 1 > 2 > 3 over the first
## happy_rise_seconds, then faces 3, 2 and 1 held for their own seconds, and back to
## her normal face (1 + 1 + 4 + 4 = the 10 second lock).
@export var happy_rise_seconds: float = 1.0
@export var happy_face_3_seconds: float = 1.0
@export var happy_face_2_seconds: float = 4.0
@export var happy_face_1_seconds: float = 4.0

## The robot (StressTestRobot) whose animations feed the meters and whose face
## shows the awareness.
var robot: Control = null
## Awareness at which she is maxed out (the scene may scale it, e.g. per day).
## Awareness is not capped there: it keeps climbing past it, so during the eyes'
## buffer the player has to bring it back under the threshold, not just nudge it.
var threshold: float = 100.0
var awareness: float = 0.0
var endurance: float = 0.0
var robot_endurance: float = 0.0
## Seconds left during which awareness cannot rise (robot endurance maxed out).
var awareness_lock_remaining: float = 0.0
## Debug cheat: awareness stays at 0.
var pinned_at_zero: bool = false
var state: int = State.CALM

var _anim_elapsed: float = 0.0
var _wake_elapsed: float = 0.0
var _wake_finished_emitted: bool = false
var _endurance_triggered: bool = false
## True from the moment endurance maxes out and winds the animation down until
## that wind-down's done animation finishes (see _on_done_animation_finished).
var _endurance_wind_down_pending: bool = false
var _eyes_rect: TextureRect = null
var _eyes_outline: TextureRect = null
var _eyes_atlas: AtlasTexture = null


## Hooks the meters up to the robot and builds the eyes HUD on `hud_parent` (a
## full-screen Control, so the eyes pin to the visible screen's corner).
func setup(robot_node: Control, hud_parent: Control, show_hud: bool = true) -> void:
	robot = robot_node
	if robot != null and robot.has_signal("done_animation_finished"):
		robot.connect("done_animation_finished", _on_done_animation_finished)
	if robot != null and robot.has_signal("pre_outro_looped"):
		robot.connect("pre_outro_looped", _on_pre_outro_looped)
	if hud_parent != null:
		_create_eyes(hud_parent)
	set_hud_visible(show_hud)
	_apply_eyes_frame()


func reset() -> void:
	awareness = 0.0
	endurance = 0.0
	robot_endurance = 0.0
	awareness_lock_remaining = 0.0
	_apply_happy_face()
	state = State.CALM
	_anim_elapsed = 0.0
	_wake_elapsed = 0.0
	_wake_finished_emitted = false
	_endurance_triggered = false
	_endurance_wind_down_pending = false
	_apply_eyes_frame()


## Back to 0 with the wind-down trigger re-armed.
func reset_endurance() -> void:
	endurance = 0.0
	_endurance_triggered = false
	_endurance_wind_down_pending = false


## Each pass of the pelvis animation's pre-done strip feeds robot endurance (not the
## head talk's, and not while the awareness lock already holds it at max); reaching
## the threshold starts the lock as usual.
func _on_pre_outro_looped(box_name: String = "") -> void:
	if is_awareness_locked() or box_name == "HeadHoverBox":
		return
	robot_endurance = minf(robot_endurance_threshold,
			robot_endurance + maxf(0.0, robot_endurance_per_pre_done_loop))
	_update_robot_endurance(0.0)


## A done animation finished: only the one endurance itself triggered (by maxing
## out) resets the meter; one the player started by cancelling early does not.
func _on_done_animation_finished() -> void:
	if _endurance_wind_down_pending:
		reset_endurance()


func set_hud_visible(value: bool) -> void:
	if _eyes_rect != null:
		_eyes_rect.visible = value


## True while maxed-out robot endurance is holding awareness from rising.
func is_awareness_locked() -> bool:
	return awareness_lock_remaining > 0.0


## Whether awareness is held from rising right now: the robot-endurance lock, or (if
## pause_awareness_at_max_endurance is on) endurance sitting at its threshold.
func is_awareness_gain_paused() -> bool:
	return is_awareness_locked() \
			or (pause_awareness_at_max_endurance and endurance >= endurance_threshold)


func is_waking() -> bool:
	return state == State.WAKING


func is_body_animation_playing() -> bool:
	return robot != null \
			and robot.has_method("is_body_animation_playing") \
			and bool(robot.call("is_body_animation_playing"))


## Discrete awareness bump (a body-part move, the emergency button...).
func add(amount: float) -> void:
	if amount > 0.0 and is_awareness_gain_paused():
		return
	awareness = maxf(0.0, awareness + amount)
	if pinned_at_zero:
		awareness = 0.0


## The robot's body_part_moved signal: a leg raise counts for more.
func add_for_move(is_leg_raise: bool) -> void:
	add(leg_raise_gain if is_leg_raise else move_gain)


## Awareness climbs while she animates and by the scene's steady `passive_gain`,
## and falls by `decay` (per second) only while she is undisturbed - nothing
## animating and no passive gain.
func update_awareness(delta: float, passive_gain: float = 0.0, decay: float = 0.0) -> void:
	if delta <= 0.0:
		return
	var animating := is_body_animation_playing()
	if animating or passive_gain > 0.0:
		# Maxed-out robot endurance (or endurance, with the pause on) holds awareness
		# where it is: no rise at all.
		if not is_awareness_gain_paused():
			if animating:
				awareness += animation_gain_per_second * delta
			awareness += passive_gain * delta
	else:
		awareness -= maxf(0.0, decay) * delta
	awareness = maxf(0.0, awareness)
	if pinned_at_zero:
		awareness = 0.0


## Signed awareness rate right now (for the debug readout), with the same rule as
## update_awareness.
func awareness_rate_per_second(passive_gain: float = 0.0, decay: float = 0.0) -> float:
	if (is_body_animation_playing() or passive_gain > 0.0) and is_awareness_gain_paused():
		return 0.0
	if is_body_animation_playing():
		return animation_gain_per_second + passive_gain
	if passive_gain > 0.0:
		return passive_gain
	return -maxf(0.0, decay)


## Endurance climbs while an animation actively plays (head talk 8/s, pelvis lift
## 10/s, summed when both run), and falls back at endurance_decay_per_second
## otherwise. Reaching the threshold winds the running animation(s) down once;
## the trigger re-arms once endurance has fallen back below it.
func update_endurance(delta: float) -> void:
	if delta <= 0.0:
		return
	var rate := _endurance_gain_rate_per_second()
	if rate > 0.0:
		endurance = minf(endurance_threshold, endurance + rate * delta)
	else:
		endurance = maxf(0.0, endurance - maxf(0.0, endurance_decay_per_second) * delta)
	_update_robot_endurance(delta)

	if endurance < endurance_threshold:
		_endurance_triggered = false
	elif not _endurance_triggered:
		_endurance_triggered = true
		if robot != null and robot.has_method("begin_endurance_wind_down"):
			_endurance_wind_down_pending = true
			robot.call("begin_endurance_wind_down")


## Robot endurance fills at its fraction of endurance's pelvis rate while the pelvis
## animation plays (the head talk adds nothing), and drains at endurance's decay rate
## otherwise. Reaching the threshold starts the awareness lock; robot endurance holds
## at max through it and starts again from 0 once the lock runs out.
func _update_robot_endurance(delta: float) -> void:
	if is_awareness_locked():
		awareness_lock_remaining = maxf(0.0, awareness_lock_remaining - delta)
		if not is_awareness_locked():
			robot_endurance = 0.0
		_apply_happy_face()
		return
	var rate := _robot_endurance_gain_rate_per_second()
	if rate > 0.0:
		robot_endurance = minf(robot_endurance_threshold, robot_endurance + rate * delta)
	else:
		robot_endurance = maxf(0.0, robot_endurance - maxf(0.0, endurance_decay_per_second) * delta)
	if robot_endurance >= robot_endurance_threshold:
		awareness_lock_remaining = maxf(0.0, robot_endurance_awareness_lock_seconds)
		_apply_happy_face()


## Her smile through the awareness lock (0 = normal face, 1-3 = happy stages):
## rising 1 > 2 > 3 over the first happy_rise_seconds, then 3, 2 and 1 each for its
## own seconds, and normal after that or once the lock is over.
func _happy_face_stage() -> int:
	if not is_awareness_locked():
		return 0
	var total := maxf(0.001, robot_endurance_awareness_lock_seconds)
	var elapsed := total - awareness_lock_remaining
	var rise := maxf(0.001, happy_rise_seconds)
	if elapsed < rise:
		return 1 + mini(int(elapsed / rise * 3.0), 2)
	elapsed -= rise
	var holds := [[3, happy_face_3_seconds], [2, happy_face_2_seconds], [1, happy_face_1_seconds]]
	for hold in holds:
		if elapsed < maxf(0.0, float(hold[1])):
			return int(hold[0])
		elapsed -= maxf(0.0, float(hold[1]))
	return 0


func _apply_happy_face() -> void:
	if robot != null and robot.has_method("set_happy_face"):
		robot.call("set_happy_face", _happy_face_stage())


## Only the pelvis animation builds robot endurance.
func _robot_endurance_gain_rate_per_second() -> float:
	if robot == null or not robot.has_method("is_pelvis_lift_active") \
			or not bool(robot.call("is_pelvis_lift_active")):
		return 0.0
	return endurance_pelvis_gain_per_second * maxf(0.0, robot_endurance_rate_multiplier)


func _endurance_gain_rate_per_second() -> float:
	if robot == null:
		return 0.0
	var rate := 0.0
	if robot.has_method("is_head_talk_active") and bool(robot.call("is_head_talk_active")):
		rate += endurance_head_gain_per_second
	if robot.has_method("is_pelvis_lift_active") and bool(robot.call("is_pelvis_lift_active")):
		rate += endurance_pelvis_gain_per_second
	return rate


## Drives the eyes' buffer. Reaching max awareness starts the end loop (frames
## 16-19); dropping back below max cancels it, but if awareness is still maxed
## once it has looped the buffer count she wakes up.
func update_eyes(delta: float) -> void:
	var maxed := awareness >= threshold
	match state:
		State.CALM:
			if maxed:
				state = State.BUFFER
				_anim_elapsed = 0.0
		State.BUFFER:
			if not maxed:
				state = State.CALM
			else:
				_anim_elapsed += delta
				var duration := eyes_loop_frame_seconds * EYES_LOOP_FRAMES * maxi(1, eyes_buffer_loops)
				if _anim_elapsed >= duration:
					_begin_waking()
					return
	_apply_eyes_frame()


## While she is awake: keep the end loop running and signal wake_finished once
## the wake delay has passed.
func update_waking(delta: float) -> void:
	_anim_elapsed += delta
	_wake_elapsed += delta
	_apply_eyes_frame()
	if _wake_elapsed >= wake_fail_delay_seconds and not _wake_finished_emitted:
		_wake_finished_emitted = true
		wake_finished.emit()


## She woke up: open her eyes and let the scene lock things down. The end loop
## keeps running on from the buffer without restarting.
func _begin_waking() -> void:
	state = State.WAKING
	_wake_elapsed = 0.0
	_apply_eyes_frame()
	woke_up.emit()


func _create_eyes(hud_parent: Control) -> void:
	var sheet := load(EYES_SHEET_PATH) as Texture2D
	if sheet == null:
		return
	_eyes_atlas = AtlasTexture.new()
	_eyes_atlas.atlas = sheet
	_eyes_atlas.region = Rect2(Vector2.ZERO, EYES_FRAME_SIZE)
	var rect := TextureRect.new()
	rect.name = "StressIndicatorEyes"
	rect.texture = _eyes_atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eyes_size := EYES_FRAME_SIZE * eyes_scale
	rect.anchor_left = 0.0
	rect.anchor_right = 0.0
	rect.anchor_top = 0.0
	rect.anchor_bottom = 0.0
	rect.offset_left = eyes_margin.x
	rect.offset_right = eyes_margin.x + eyes_size.x
	rect.offset_top = eyes_margin.y
	rect.offset_bottom = eyes_margin.y + eyes_size.y
	hud_parent.add_child(rect)
	_eyes_rect = rect

	# The outline rides on the eyes (so it hides with them) but draws behind them.
	var outline_texture := load(EYES_OUTLINE_PATH) as Texture2D
	if outline_texture == null:
		return
	var outline := TextureRect.new()
	outline.name = "Outline"
	outline.texture = outline_texture
	outline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	outline.stretch_mode = TextureRect.STRETCH_SCALE
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.show_behind_parent = true
	var outline_offset := EYES_OUTLINE_OFFSET * eyes_scale
	var outline_size := outline_texture.get_size() * eyes_scale
	outline.offset_left = outline_offset.x
	outline.offset_top = outline_offset.y
	outline.offset_right = outline_offset.x + outline_size.x
	outline.offset_bottom = outline_offset.y + outline_size.y
	outline.visible = false
	rect.add_child(outline)
	_eyes_outline = outline


## Picks the eyes' frame for the current state and mirrors it onto the robot's
## face (angry past frame 8, plus open eyes once she has woken up).
func _apply_eyes_frame() -> void:
	var frame := 0
	match state:
		State.CALM:
			var ratio := clampf(awareness / maxf(0.001, threshold), 0.0, 1.0)
			var fill_start := clampf(eyes_fill_start_ratio, 0.01, 0.99)
			if ratio < fill_start:
				# Eyes opening: 0..fill start maps onto frames 1-10 along the ease-out
				# curve, so they open quickly at first and slow toward the end.
				var progress := pow(ratio / fill_start, maxf(0.01, eyes_awareness_curve))
				frame = roundi(progress * (EYES_OPEN_FRAMES - 1))
			else:
				# Eyes filling black / pupils reddening: fill start..max spreads evenly
				# over frames 11-15.
				var fill := (ratio - fill_start) / (1.0 - fill_start)
				frame = EYES_FILL_FIRST_FRAME + mini(int(fill * EYES_FILL_FRAMES), EYES_FILL_FRAMES - 1)
		State.BUFFER, State.WAKING:
			var step := int(_anim_elapsed / maxf(0.001, eyes_loop_frame_seconds))
			frame = EYES_LOOP_FIRST_FRAME + step % EYES_LOOP_FRAMES
	if _eyes_atlas != null:
		_eyes_atlas.region = Rect2(Vector2(EYES_FRAME_SIZE.x * frame, 0.0), EYES_FRAME_SIZE)
	if _eyes_outline != null:
		var high := state != State.CALM or awareness >= threshold * eyes_outline_flash_ratio
		var half := maxf(0.01, eyes_outline_flash_seconds)
		var seconds := float(Time.get_ticks_msec()) / 1000.0
		_eyes_outline.visible = high and fmod(seconds, half * 2.0) < half
	if robot != null and robot.has_method("set_awareness_face"):
		robot.call("set_awareness_face", frame >= EYES_ANGRY_FROM_FRAME, state == State.WAKING)
