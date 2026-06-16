extends TextureRect
## In-frame scene transition.
##
## Plays the FlowerLoad 18-frame animation scoped to the framed picture
## area only. The HUD, buttons, and location UI outside the frame are not
## affected. At frame 9/18 (the most-covered frame), the parent Main calls
## its swap callback so the picture-box background change happens while
## the wipe hides it.
##
## Sprite-sheet handling: draw the active frame manually as repeated,
## clipped tiles. The old TextureRect scaling path stretched one frame to
## fill taller/wider scene frames, which made the wipe visibly distort.

signal midpoint_reached
signal finished

## Source sprite sheet. Assigned in the .tscn.
@export var sheet: Texture2D

## Sprite sheet grid. FlowerLoad is a 1x18 vertical strip (500x2250, each
## frame 500x125). Change if a different sheet has a different layout.
## Total = hframes * vframes should equal total_frames.
@export var hframes: int = 1
@export var vframes: int = 18
@export var total_frames: int = 18

## 1-indexed frame at which the midpoint callback fires - the swap happens
## one tick AFTER coverage first becomes full, so a fully-covered frame is
## guaranteed to have rendered before anything underneath changes.
## For FlowerLoad, indices 8-12 are all 100% covered, so any value in
## [9, 13] is safe; 10 gives a clean one-frame buffer past full coverage.
@export var midpoint_frame: int = 10

## Total animation length. 18 frames over 0.75s = 24fps.
@export var duration_sec: float = 0.75

## FlowerLoad's source frame is 500x125, while the normal picture frame
## displays at 900x225. Keep that scaled size as the repeat unit so taller
## and fullscreen wipes extend by copy/paste tiling instead of stretching.
@export var tile_scale: float = 1.8

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


func _ready() -> void:
	visible = false
	texture = null

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


## Start the transition. `at_midpoint` runs once when the animation reaches
## `midpoint_frame`. Pass an empty Callable for a purely cosmetic wipe.
func play(at_midpoint: Callable = Callable()) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_midpoint_callback = at_midpoint
	_midpoint_fired = false
	_frame_index = 0
	visible = true

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_property(self, "_frame_index", total_frames - 1, duration_sec)
	_tween.tween_callback(_on_animation_finished)

	set_process(true)


## Play only the second half, beginning on the covered midpoint frame.
## Used when the new surface is already visible (intro and fullscreen
## locations) and we just need the wipe to lift away from it.
func play_lift_from_midpoint() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_midpoint_callback = Callable()
	_midpoint_fired = true
	_frame_index = midpoint_frame - 1
	visible = true
	set_process(false)

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
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	if _midpoint_fired:
		return
	if _frame_index >= midpoint_frame - 1:
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
