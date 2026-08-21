extends LocationBase
## Laptop shell — a fullscreen scene that frames the laptop art and hosts a
## self-contained LaptopScreen "app" inside the black region of the screen.
##
## Opening plays the laptop-OPEN animation (the laptop_close.png sheet run in
## REVERSE), then reveals the screen app. The background covers the whole viewport
## (workshop background, top-cropped); the laptop itself is contain-fit so it stays
## fully visible. The gold LEAVE button (the Store's button) closes it: for a normal
## location that means finishing back to the bedroom; when opened as an overlay
## (e.g. from the maintenance scene) it emits `closed` and frees itself instead.

const SHEET_PATH: String = "res://assets/textures/icons/laptop_close.png"
const FRAME_WIDTH: int = 500
const FRAME_HEIGHT: int = 400
const FRAME_COUNT: int = 8

## The store LEAVE button's proportions, mirrored here so this pasted copy matches
## Main._make_large_scene_end_button / _apply_large_scene_end_button_size exactly.
const LEAVE_BUTTON_PADDING_SCALE: float = 1.5

## Native size of the laptop/background art. The background is scaled to cover the
## viewport at this aspect (cropping the bottom); the laptop is contained inside it.
const CANVAS_SIZE: Vector2 = Vector2(500.0, 400.0)

const LAPTOP_SCREEN_SCENE: PackedScene = preload("res://scenes/locations/LaptopScreen.tscn")

## Emitted when this laptop closes while running as an overlay (overlay_mode).
signal closed

## Which app the screen boots into: "build" (limb select/scan) or "assembly".
@export var app_mode: String = "build"
## Seconds each animation frame is held while opening / closing the laptop.
@export var frame_seconds: float = 0.05

## When true, this laptop was opened on top of another scene (e.g. maintenance):
## LEAVE frees it and emits `closed` instead of finishing a location.
var overlay_mode: bool = false

@onready var fullscreen_layer: CanvasLayer = $FullscreenLayer
@onready var black_background: ColorRect = $FullscreenLayer/FullscreenRoot/BlackBackground
@onready var scene_canvas: Control = %SceneCanvas
@onready var laptop_unit: Control = %LaptopUnit
@onready var laptop_sprite: TextureRect = %LaptopSprite
@onready var screen_content: Control = %ScreenContent
@onready var leave_button: Button = %LeaveButton

var _frames: Array[AtlasTexture] = []
var _screen: LaptopScreen = null
## True while an open/close animation is playing, so LEAVE can't be double-fired.
var _busy: bool = false
var _anim_tween: Tween = null


func _ready() -> void:
	_build_frames()
	_style_leave_button()

	# Cover-fit the background and contain-fit the laptop (see _layout_canvas).
	get_viewport().size_changed.connect(_layout_canvas)
	_layout_canvas()

	# Host the screen app inside the black screen region, hidden until the laptop
	# has opened.
	_screen = LAPTOP_SCREEN_SCENE.instantiate() as LaptopScreen
	_screen.app_mode = app_mode
	screen_content.add_child(_screen)
	screen_content.visible = false

	# As an overlay over another scene, draw above the host and absorb clicks that
	# miss the laptop's own buttons so they don't fall through to the scene below.
	# The workshop-crop background only belongs to the standalone laptop scene; as an
	# overlay (e.g. the maintenance laptop) it is hidden so the laptop sits on black
	# instead of painting that background over the host scene.
	if overlay_mode:
		fullscreen_layer.layer = 40
		black_background.mouse_filter = Control.MOUSE_FILTER_STOP
		scene_canvas.visible = false

	_set_frame(FRAME_COUNT - 1)  # start on the closed frame
	leave_button.disabled = true  # inert until the laptop has finished opening
	leave_button.pressed.connect(_on_leave_pressed)

	_open_laptop()


## Slice the vertical sprite sheet into one AtlasTexture per frame. Loaded at
## runtime (rather than preloaded) so a not-yet-imported sheet degrades to
## "no animation" instead of a script parse error.
func _build_frames() -> void:
	_frames.clear()
	var sheet := load(SHEET_PATH) as Texture2D
	if sheet == null:
		push_warning("Laptop: could not load %s — let Godot import it." % SHEET_PATH)
		return
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, i * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)
		_frames.append(atlas)


## Duplicate the gold LEAVE button's stylebox padding up 1.5x to match the store's
## enlarged button, keeping the theme's crisp 3px border. Mirrors
## Main._apply_large_scene_end_button_size; must run with the button in the tree.
func _style_leave_button() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var base := leave_button.get_theme_stylebox(state)
		if base == null:
			continue
		var sb := base.duplicate() as StyleBox
		sb.content_margin_left = base.get_margin(SIDE_LEFT) * LEAVE_BUTTON_PADDING_SCALE
		sb.content_margin_top = base.get_margin(SIDE_TOP) * LEAVE_BUTTON_PADDING_SCALE
		sb.content_margin_right = base.get_margin(SIDE_RIGHT) * LEAVE_BUTTON_PADDING_SCALE
		sb.content_margin_bottom = base.get_margin(SIDE_BOTTOM) * LEAVE_BUTTON_PADDING_SCALE
		leave_button.add_theme_stylebox_override(state, sb)


## Lay out the two art layers over the viewport:
##  - the background COVERS the whole viewport (fills it, keeps aspect, cropping
##    the bottom) so there are never any left/right bars;
##  - the laptop CONTAINS itself inside the viewport (fully visible, keeps aspect,
##    centered) so the whole laptop reads at a sensible size.
func _layout_canvas() -> void:
	var vp: Vector2 = get_viewport_rect().size

	if scene_canvas != null:
		var cover: float = maxf(vp.x / CANVAS_SIZE.x, vp.y / CANVAS_SIZE.y)
		scene_canvas.size = CANVAS_SIZE
		scene_canvas.scale = Vector2(cover, cover)
		scene_canvas.position = Vector2((vp.x - CANVAS_SIZE.x * cover) * 0.5, 0.0)

	if laptop_unit != null:
		var contain: float = minf(vp.x / CANVAS_SIZE.x, vp.y / CANVAS_SIZE.y)
		laptop_unit.size = CANVAS_SIZE
		laptop_unit.scale = Vector2(contain, contain)
		laptop_unit.position = Vector2(
			(vp.x - CANVAS_SIZE.x * contain) * 0.5,
			(vp.y - CANVAS_SIZE.y * contain) * 0.5,
		)


func _set_frame(index: int) -> void:
	if _frames.is_empty():
		return
	laptop_sprite.texture = _frames[clampi(index, 0, _frames.size() - 1)]


func _open_laptop() -> void:
	_busy = true
	# Reverse of the close animation: last frame (closed) -> first frame (open).
	await _play_frames(FRAME_COUNT - 1, 0)
	_busy = false
	if not is_inside_tree():
		return
	leave_button.disabled = false
	screen_content.visible = true


## Tween the displayed frame from `from_frame` to `to_frame` (either direction).
func _play_frames(from_frame: int, to_frame: int) -> void:
	if _frames.is_empty():
		return
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	var span: int = abs(to_frame - from_frame)
	_set_frame(from_frame)
	_anim_tween = create_tween()
	_anim_tween.tween_method(
		_set_frame_interp, float(from_frame), float(to_frame), maxf(0.01, span * frame_seconds))
	await _anim_tween.finished


func _set_frame_interp(value: float) -> void:
	_set_frame(int(round(value)))


func _on_leave_pressed() -> void:
	if _busy:
		return
	_busy = true
	leave_button.disabled = true
	# Stop displaying the screen, then play the close animation forward.
	screen_content.visible = false
	await _play_frames(0, FRAME_COUNT - 1)

	if overlay_mode:
		closed.emit()
		queue_free()
	else:
		# Free action - return to the bedroom without advancing the phase.
		finish(0, 0, 0, {}, true)
