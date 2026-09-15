extends TextureRect
class_name PunchTest
## A debug/testing widget for previewing the punch animation inside a scene.
##
## Behaviour:
## - Hidden by default. A Shift+Tab debug-menu button toggles it on (see
##   Maintenance.debug_toggle_punch_test).
## - While visible, pressing the configured mouse button (left or right) plays the
##   punch once, front to back.
## - It plays to completion before it can be triggered again: any click that lands
##   while a punch is mid-flight is ignored, not queued.
##
## The art is a single vertical sprite sheet (frames stacked top to bottom); we slice
## it into AtlasTexture frames and step through them with a tween, the same way the
## battery-insert and oil-pour animations are driven elsewhere.

## Which mouse button plays the punch. Flip this in the Inspector to test the punch on
## a left-click or a right-click.
enum TriggerButton { LEFT, RIGHT }
@export var trigger_button: TriggerButton = TriggerButton.LEFT

## The vertical punch sprite sheet (frames stacked top to bottom).
@export var sheet: Texture2D = preload("res://assets/textures/icons/punch_fist.png")
## How many frames the sheet is sliced into.
@export var frame_count: int = 9
## Seconds each frame is held; the whole punch lasts frame_count * this.
@export var seconds_per_frame: float = 0.05

@export_group("Placement")
## Pin the widget flush to the bottom of the camera view (keeps its authored horizontal
## position). Updates live in-game so you can set it and check it.
@export var lock_to_bottom: bool = false:
	set(value):
		lock_to_bottom = value
		_apply_layout()
## Extra horizontal nudge (view pixels) on top of the widget's authored position: positive
## moves it right, negative moves it left. Updates live in-game.
@export_range(-600, 600, 1) var horizontal_offset: int = 0:
	set(value):
		horizontal_offset = value
		_apply_layout()

@export_group("Pixel Ratio")
## Optional. A CanvasItem (e.g. the scene's SceneCanvas / background) whose on-screen pixel
## size the punch should match, so the fist's pixels are the same size as the background's
## rather than the widget's own arbitrary scale. Leave empty to draw at scale 1 (or use
## match_design_canvas below).
@export var pixel_ratio_source: NodePath
## When no pixel_ratio_source is set (e.g. the universal overlay that isn't inside a scene
## canvas), match the game's design canvas as it is scaled to the viewport instead - the
## same pixel ratio the maintenance background gets - so the fist stays that size anywhere.
@export var match_design_canvas: bool = false
## The design canvas the game renders (BASE_SCENE_SIZE); COVER-scaled to the viewport.
@export var design_size: Vector2 = Vector2(500, 400)
## Extra zoom on the design scale, matching the scene's mouse-follow zoom (maintenance 1.05).
@export var design_zoom: float = 1.05

## Fallback display-box size if the node's authored size can't be read.
const DEFAULT_BOX: Vector2 = Vector2(256, 128)
## The widget's display box, captured from its authored rect so scaling/re-anchoring keep it.
var _box_size: Vector2 = Vector2.ZERO
## Authored placement captured at _ready, so lock/offset adjust from it instead of clobbering
## the position set in the editor (which is how the two hands are spread apart).
var _base_offset_left: float = 0.0
var _base_offset_top: float = 0.0
var _base_anchor_top: float = 0.5
var _base_anchor_bottom: float = 0.5

var _frames: Array[AtlasTexture] = []
## True while a punch is playing - the gate that makes clicks during the animation
## do nothing until it finishes.
var _playing: bool = false
var _tween: Tween = null


func _ready() -> void:
	# Invisible until the debug menu toggles it on.
	visible = false
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The widget never eats clicks itself; it listens via _input (not _unhandled_input) so
	# the click still registers over the robot's own click regions, without marking the
	# event handled (so the debug toggle button still works).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Remember the authored rect so lock / offset / scale adjust from it instead of clobbering
	# the position set in the editor (that's how the two hands are spread apart).
	_box_size = size if size.x > 0.0 and size.y > 0.0 else DEFAULT_BOX
	_base_offset_left = offset_left
	_base_offset_top = offset_top
	_base_anchor_top = anchor_top
	_base_anchor_bottom = anchor_bottom
	_apply_layout()
	_build_frames()
	if not _frames.is_empty():
		texture = _frames[0]


## Positions the widget from the placement options: it keeps the horizontal position set in
## the editor (plus the pixel nudge), and either pins flush to the camera-view bottom
## (lock_to_bottom) or keeps the authored vertical position. Also sets the scale pivot so the
## pixel-ratio scaling grows from the bottom-centre (locked) or centre without drifting off
## its anchor. No-ops until the node is in the tree, so the export setters can fire safely
## during load.
func _apply_layout() -> void:
	if not is_inside_tree():
		return
	var w := _box_size.x if _box_size.x > 0.0 else DEFAULT_BOX.x
	var h := _box_size.y if _box_size.y > 0.0 else DEFAULT_BOX.y
	# Horizontal: keep the authored position (the two hands are spread by it), plus the nudge.
	offset_left = _base_offset_left + float(horizontal_offset)
	offset_right = offset_left + w
	# Vertical: pin flush to the view bottom when locked, else the authored position.
	if lock_to_bottom:
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_top = -h
		offset_bottom = 0.0
	else:
		anchor_top = _base_anchor_top
		anchor_bottom = _base_anchor_bottom
		offset_top = _base_offset_top
		offset_bottom = _base_offset_top + h
	# Scale about the box's horizontal centre, and its bottom edge when locked (so pixel-ratio
	# growth goes upward and the bottom stays flush) or its centre otherwise.
	pivot_offset = Vector2(w * 0.5, h if lock_to_bottom else h * 0.5)


func _process(_delta: float) -> void:
	# Match the background's pixel ratio while shown. Cheap, and doing it per-frame keeps it
	# correct across window resizes / view-scale changes without chasing signals. The widget
	# starts hidden, so this is idle until the debug menu toggles it on.
	if visible:
		_update_pixel_scale()


## Scales the widget so one fist texel is the same on-screen size as one texel of
## pixel_ratio_source (e.g. the background). That source's global scale is the scene's
## on-screen pixel ratio; we divide out this node's own parent scale (it lives in the
## unscaled view root) and the KEEP_ASPECT fit of the texture inside its box.
func _update_pixel_scale() -> void:
	var box := _box_size if _box_size.x > 0.0 else DEFAULT_BOX
	var tex := texture.get_size() if texture != null else box
	if box.x <= 0.0 or box.y <= 0.0 or tex.x <= 0.0 or tex.y <= 0.0:
		return
	var fit := minf(box.x / tex.x, box.y / tex.y)
	if fit <= 0.0:
		return
	var src := get_node_or_null(pixel_ratio_source) as CanvasItem
	if src != null and is_instance_valid(src):
		# Match a live scene node's on-screen scale (divide out our own parent's scale).
		var src_scale := src.get_global_transform().get_scale().x
		var parent_ci := get_parent() as CanvasItem
		var parent_scale := parent_ci.get_global_transform().get_scale().x if parent_ci != null else 1.0
		if parent_scale == 0.0:
			return
		scale = Vector2.ONE * ((src_scale / parent_scale) / fit)
	elif match_design_canvas and design_size.x > 0.0 and design_size.y > 0.0:
		# No live source: reproduce the maintenance background's pixel ratio - the 500x400
		# design canvas COVER-scaled to the viewport, times the scene's mouse-follow zoom.
		var vp := get_viewport_rect().size
		var cover := maxf(vp.x / design_size.x, vp.y / design_size.y)
		scale = Vector2.ONE * ((cover * maxf(0.01, design_zoom)) / fit)
	else:
		scale = Vector2.ONE


## Slices the vertical sheet into `frame_count` equal frames.
func _build_frames() -> void:
	_frames.clear()
	if sheet == null or frame_count <= 0:
		return
	var fw := sheet.get_width()
	var fh := int(sheet.get_height() / frame_count)
	if fw <= 0 or fh <= 0:
		return
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, i * fh, fw, fh)
		_frames.append(atlas)


func _input(event: InputEvent) -> void:
	# Only react while shown, and never while a punch is already playing (clicks during
	# the animation are ignored, not queued). We use _input rather than _unhandled_input
	# so the click still registers when it lands over the robot's own click regions
	# (hover / pose boxes), which would otherwise swallow it first. We don't mark the
	# event handled, so the Shift+Tab menu button that toggles this off still works.
	if not visible or _playing:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == _wanted_button():
		play()


func _wanted_button() -> int:
	return MOUSE_BUTTON_RIGHT if trigger_button == TriggerButton.RIGHT else MOUSE_BUTTON_LEFT


## Plays the punch once. A no-op while one is already playing, so it can't overlap.
func play() -> void:
	if _playing or _frames.is_empty():
		return
	_playing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_set_frame(0.0)
	var duration := maxf(0.05, float(_frames.size()) * seconds_per_frame)
	_tween = create_tween()
	_tween.tween_method(_set_frame, 0.0, float(_frames.size() - 1), duration)
	_tween.finished.connect(func() -> void:
		_playing = false
		# Rest on the first frame, ready for the next punch.
		_set_frame(0.0)
	)


func _set_frame(value: float) -> void:
	if _frames.is_empty():
		return
	var i := clampi(int(round(value)), 0, _frames.size() - 1)
	texture = _frames[i]
