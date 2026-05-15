extends TextureRect
## In-frame scene transition.
##
## Plays the FlowerLoad 18-frame animation scoped to the framed picture
## area only. The HUD, buttons, and location UI outside the frame are not
## affected. At frame 9/18 (the most-covered frame), the parent Main calls
## its swap callback so the picture-box background change happens while
## the wipe hides it.
##
## Sprite-sheet handling: we use an AtlasTexture and slide its region
## across the full sheet, one frame at a time. The TextureRect's sizing /
## aspect handling does the work, instead of us doing manual Sprite2D math.

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

var _atlas: AtlasTexture
var _frame_size: Vector2 = Vector2.ZERO
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

	if sheet == null:
		push_warning("Transition: sheet texture not assigned.")
		return

	var size: Vector2 = sheet.get_size()
	_frame_size = Vector2(size.x / hframes, size.y / vframes)

	_atlas = AtlasTexture.new()
	_atlas.atlas = sheet
	_atlas.region = Rect2(Vector2.ZERO, _frame_size)
	texture = _atlas


func _update_region() -> void:
	if _atlas == null:
		return
	var col: int = _frame_index % hframes
	var row: int = _frame_index / hframes
	_atlas.region = Rect2(
		Vector2(col * _frame_size.x, row * _frame_size.y),
		_frame_size,
	)


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
