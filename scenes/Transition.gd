extends TextureRect
## In-frame scene transition.
##
## Two interchangeable looks, chosen via [member style]:
##
## SHEET (FlowerLoad): plays a 17-frame sprite-sheet wipe scoped to the framed
## picture area. At frame 9/17 (the most-covered frame) the parent Main calls
## its swap callback so the picture-box background change happens while the wipe
## hides it. The frame is drawn manually as repeated, clipped tiles so taller /
## wider scenes extend by tiling instead of stretching one frame.
##
## DOORS (DoorLoad): a procedural double-door slide. Two copies of a single door
## half are centered, the right one mirrored, and they slide together to cover
## the scene (swap fires while fully closed) then slide back apart to reveal it.
## The doors are scaled to match the background's on-screen pixel ratio; when the
## area is too big for the door texture to cover at that ratio, they scale up to
## cover it instead (accepting a pixel-ratio mismatch), and when the area is
## smaller than the doors the overflow is simply clipped.

signal midpoint_reached
signal finished
## Emitted by play_close_and_hold() once the wipe is fully covering the scene and
## holding there. Used by the fullscreen "loading menu" flow: the caller waits for
## this, lets a covered frame present, loads the heavy scene, then calls
## play_lift_from_midpoint() to reveal it.
signal closed

enum Style { SHEET, DOORS }

## Which look this transition plays. Set per-instance (Main flips it from the
## Shift+Tab debug menu).
@export var style: Style = Style.SHEET

# --- SHEET (FlowerLoad) params ---

## Source sprite sheet. Assigned in the .tscn.
@export var sheet: Texture2D

## Sprite sheet grid. FlowerLoad is a 1x17 vertical strip (512x2176, each
## frame 512x128). Change if a different sheet has a different layout.
## Total = hframes * vframes should equal total_frames.
@export var hframes: int = 1
@export var vframes: int = 17
@export var total_frames: int = 17

## 1-indexed frame at which the midpoint callback fires - the swap happens
## one tick AFTER coverage first becomes full, so a fully-covered frame is
## guaranteed to have rendered before anything underneath changes.
## For FlowerLoad, the middle covered frame is frame 9.
@export var midpoint_frame: int = 9

## Total animation length. 17 frames over 0.75s. In DOORS mode this is still the
## full close->open length (Main derives it from the door "speed" setting).
@export var duration_sec: float = 0.25

## FlowerLoad's source frame is 512x128, while the normal picture frame
## displays at 900x225. Keep that scaled size as the repeat unit so taller
## and fullscreen wipes extend by copy/paste tiling instead of stretching.
@export var tile_scale: float = 1.7578125

# --- DOORS (DoorLoad) params ---

## A single door half, drawn as-authored on the left and mirrored on the right.
## DoorLoad is 256x512; the two halves together are 512x512 (see door_native_size).
@export var door_half: Texture2D

## Combined native footprint of the two door halves (left + right). Used to
## match the background's pixel ratio and as the cover-fit reference.
@export var door_native_size: Vector2 = Vector2(512, 512)

## Stepped playback: the continuous slide is quantized to this many frames per
## second, mimicking a hand-drawn sprite animation. 0 (or less) plays smooth.
@export var door_fps: float = 0.0

## Ease of the open/close motion. 0 = perfectly linear; 1 = full ease-in-out.
## Values in between blend the two.
@export_range(0.0, 1.0) var door_ease: float = 0.5

## Background native pixel size, set by Main before each play so the doors can
## match the background's on-screen pixel ratio. Zero => cover-fit only.
var background_native_size: Vector2 = Vector2.ZERO

var _frame_size: Vector2 = Vector2.ZERO
var _frame_region: Rect2 = Rect2()
var _tween: Tween = null
var _midpoint_fired: bool = false
var _midpoint_callback: Callable = Callable()
## Plain int driven by the tween. We watch this and update the atlas region.
## (Tweening an AtlasTexture's `region` rect directly is awkward because
##  it's a Rect2; tweening an int is trivial.)
var _frame_index: int = 0:
	set(value):
		_frame_index = value
		_update_region()

## Door animation parameter, tweened 0 -> 1 across the whole close->open sweep.
## 0.0 = fully open (revealed), 0.5 = fully closed (covered), 1.0 = open again.
var _door_t: float = 0.0:
	set(value):
		_door_t = value
		if style == Style.DOORS:
			queue_redraw()


func _ready() -> void:
	visible = false
	texture = null

	if style == Style.DOORS:
		_configure_door_node()
		return

	if sheet == null:
		push_warning("Transition: sheet texture not assigned.")
		return

	var size: Vector2 = sheet.get_size()
	_frame_size = Vector2(size.x / hframes, size.y / vframes)
	_update_region()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _update_region() -> void:
	if sheet == null or _frame_size == Vector2.ZERO:
		return
	var col: int = _frame_index % hframes
	var row: int = _frame_index / hframes
	_frame_region = Rect2(
		Vector2(col * _frame_size.x, row * _frame_size.y),
		_frame_size,
	)
	queue_redraw()


func _draw() -> void:
	if style == Style.DOORS:
		_draw_doors()
		return

	if sheet == null or _frame_region.size == Vector2.ZERO:
		return

	var tile_size: Vector2 = _frame_region.size * tile_scale
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return

	var bounds := Rect2(Vector2.ZERO, size)
	var cols: int = int(ceil(size.x / tile_size.x))
	var rows: int = int(ceil(size.y / tile_size.y))

	for y in range(rows):
		for x in range(cols):
			var tile_rect := Rect2(Vector2(x, y) * tile_size, tile_size)
			var clipped := tile_rect.intersection(bounds)
			if not clipped.has_area():
				continue

			var rel_pos: Vector2 = (clipped.position - tile_rect.position) / tile_size
			var rel_size: Vector2 = clipped.size / tile_size
			var source_region := Rect2(
				_frame_region.position + rel_pos * _frame_region.size,
				rel_size * _frame_region.size,
			)
			draw_texture_rect_region(sheet, clipped, source_region)


## Pixel-art doors read best crisp, like the rest of the game, and the sliding
## halves must never paint outside the framed picture. Safe to call repeatedly;
## Main may flip `style` to DOORS after _ready has already run in SHEET mode.
func _configure_door_node() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


## Renders the two door halves at the current close amount. clip_contents keeps
## the sliding halves from spilling out of the framed area.
func _draw_doors() -> void:
	if door_half == null or door_native_size.x <= 0.0 or door_native_size.y <= 0.0:
		return
	var area: Vector2 = size
	if area.x <= 0.0 or area.y <= 0.0:
		return

	var scale := _door_scale(area)
	var half_w: float = door_native_size.x * 0.5 * scale  # one door's on-screen width
	var full_h: float = door_native_size.y * scale
	var center: Vector2 = area * 0.5
	var top: float = center.y - full_h * 0.5
	var c := _close_amount()  # 0 open .. 1 closed

	# Closed: the two inner edges meet at center.x. Open: each half has slid fully
	# off its side of the area, revealing everything behind them.
	var left_inner_edge: float = lerpf(0.0, center.x, c)
	var right_inner_edge: float = lerpf(area.x, center.x, c)

	var left_rect := Rect2(left_inner_edge - half_w, top, half_w, full_h)
	var right_rect := Rect2(right_inner_edge, top, half_w, full_h)

	# Left half, as authored.
	draw_texture_rect(door_half, left_rect, false)

	# Right half, mirrored horizontally: scale x by -1 about the rect's right edge
	# so local x in [0, w] maps to world x in [right_edge, left_edge].
	draw_set_transform_matrix(Transform2D(
		0.0,
		Vector2(-1.0, 1.0),
		0.0,
		Vector2(right_rect.position.x + right_rect.size.x, right_rect.position.y)
	))
	draw_texture_rect(door_half, Rect2(Vector2.ZERO, right_rect.size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## On-screen scale for the door halves. Prefers matching the background's pixel
## ratio; grows past it only when the area would otherwise be left uncovered.
func _door_scale(area: Vector2) -> float:
	var cover := maxf(area.x / door_native_size.x, area.y / door_native_size.y)
	var pixel_ratio := 0.0
	if background_native_size.x > 0.0 and background_native_size.y > 0.0:
		# Screen pixels per background texel. Aspect matches, so either axis works;
		# min stays safe if the frame is slightly off-ratio.
		pixel_ratio = minf(area.x / background_native_size.x, area.y / background_native_size.y)
	return maxf(pixel_ratio, cover)


## Maps _door_t (0..1 over the sweep) to a close amount (0 open .. 1 closed),
## optionally quantized to door_fps and eased between linear and smoothstep.
##
## The sweep is split into a closing half [0, 0.5] and an opening half [0.5, 1]
## and each is normalized to 0->1. Quantizing per half (rather than over the
## whole sweep) guarantees the fully-closed frame lands exactly at the midpoint
## for any door_fps, so the swap is never caught with the doors part-open.
func _close_amount() -> float:
	var t := _door_t
	var u: float = (t / 0.5) if t <= 0.5 else ((1.0 - t) / 0.5)  # 0 open .. 1 closed
	u = clampf(u, 0.0, 1.0)
	if door_fps > 0.0 and duration_sec > 0.0:
		var half_steps: float = maxf(1.0, round(0.5 * duration_sec * door_fps))
		u = round(u * half_steps) / half_steps
	var eased: float = u * u * (3.0 - 2.0 * u)  # smoothstep ease-in-out
	return lerpf(u, eased, clampf(door_ease, 0.0, 1.0))


## Start the transition. `at_midpoint` runs once when the animation reaches its
## fully-covered midpoint. Pass an empty Callable for a purely cosmetic wipe.
func play(at_midpoint: Callable = Callable()) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_midpoint_callback = at_midpoint
	_midpoint_fired = false

	if style == Style.DOORS:
		_configure_door_node()
		_door_t = 0.0
		visible = true
		queue_redraw()
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_LINEAR)
		_tween.tween_property(self, "_door_t", 1.0, maxf(0.05, duration_sec))
		_tween.tween_callback(_on_animation_finished)
		set_process(true)
		return

	_frame_index = 0
	visible = true

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "_frame_index", total_frames - 1, duration_sec)
	_tween.tween_callback(_on_animation_finished)

	set_process(true)


## Play only the first (closing) half, then hold fully covered and emit `closed`.
## The scene underneath is NOT swapped here - the caller does its heavy loading
## while the cover holds, then calls play_lift_from_midpoint() to reveal. This is
## how the fullscreen transition doubles as a loading screen that hides load lag.
func play_close_and_hold() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_midpoint_callback = Callable()
	_midpoint_fired = true  # no midpoint callback in this mode; caller drives the swap
	visible = true
	set_process(false)

	if style == Style.DOORS:
		_configure_door_node()
		_door_t = 0.0
		queue_redraw()
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_LINEAR)
		_tween.tween_property(self, "_door_t", 0.5, maxf(0.05, duration_sec) * 0.5)
		_tween.tween_callback(func() -> void: closed.emit())
		return

	_frame_index = 0

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "_frame_index", midpoint_frame - 1, duration_sec * 0.5)
	_tween.tween_callback(func() -> void: closed.emit())


## Play only the second half, beginning fully covered. Used when the new surface
## is already visible (intro and fullscreen locations) and we just need the wipe
## to lift away from it.
func play_lift_from_midpoint() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_midpoint_callback = Callable()
	_midpoint_fired = true
	visible = true
	set_process(false)

	if style == Style.DOORS:
		_configure_door_node()
		_door_t = 0.5  # fully closed; tween on to 1.0 opens the doors
		queue_redraw()
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_LINEAR)
		_tween.tween_property(self, "_door_t", 1.0, maxf(0.05, duration_sec) * 0.5)
		_tween.tween_callback(_on_animation_finished)
		return

	_frame_index = midpoint_frame - 1

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "_frame_index", total_frames - 1, duration_sec * 0.5)
	_tween.tween_callback(_on_animation_finished)


func cancel() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	_midpoint_callback = Callable()
	_midpoint_fired = false
	_frame_index = 0
	_door_t = 0.0
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if _midpoint_fired:
		return
	var reached: bool = _door_t >= 0.5 if style == Style.DOORS else _frame_index >= midpoint_frame - 1
	if reached:
		_midpoint_fired = true
		midpoint_reached.emit()
		if _midpoint_callback.is_valid():
			_midpoint_callback.call()


func _on_animation_finished() -> void:
	# Backstop in case duration is so short we never ticked past midpoint.
	if not _midpoint_fired:
		_midpoint_fired = true
		midpoint_reached.emit()
		if _midpoint_callback.is_valid():
			_midpoint_callback.call()

	visible = false
	set_process(false)
	finished.emit()


func is_playing() -> bool:
	return visible and _tween != null and _tween.is_valid()
