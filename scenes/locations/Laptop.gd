extends LocationBase
## Laptop shell — a fullscreen scene that frames the laptop art and hosts a
## self-contained LaptopDesktop (app icons + taskbar) inside the black region of the
## screen. The desktop launches the individual apps (maintenance recipes, builder,
## the robot's thoughts).
##
## Opening plays the laptop-OPEN animation (the laptop_close.png sheet run in
## REVERSE), then reveals the desktop. The background covers the whole viewport
## (laptop background, top-cropped); the laptop itself is contain-fit so it stays
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

## Emitted when this laptop closes while running as an overlay (overlay_mode).
signal closed

## Legacy: the app the screen used to boot straight into. The laptop now boots into a
## desktop (LaptopDesktop) with app icons instead, so this is kept only for callers that
## still set it (e.g. Maintenance) and is otherwise unused.
@export var app_mode: String = "build"
## Seconds each animation frame is held while opening / closing the laptop.
@export var frame_seconds: float = 0.05

## When true, this laptop was opened on top of another scene (e.g. maintenance):
## LEAVE frees it and emits `closed` instead of finishing a location.
var overlay_mode: bool = false
## Which desktop the hosted LaptopDesktop shows: "laptop" (standalone), "maintenance"
## (restricted, from the maintenance scene), "stresstest" (maintenance / patrol / store,
## from the stress test's left view) or "admin" (full grid, from the debug menu).
var desktop_context: String = "laptop"
## Instant close: the open animation still plays every time, but a background click shuts
## the laptop on the spot (no close animation). Set by the stress test's left-view laptop.
var instant: bool = false

@onready var fullscreen_layer: CanvasLayer = $FullscreenLayer
@onready var black_background: ColorRect = $FullscreenLayer/FullscreenRoot/BlackBackground
@onready var scene_canvas: Control = %SceneCanvas
@onready var laptop_unit: Control = %LaptopUnit
@onready var laptop_sprite: TextureRect = %LaptopSprite
@onready var screen_content: Control = %ScreenContent
@onready var leave_button: Button = %LeaveButton

var _frames: Array[AtlasTexture] = []
var _screen: Control = null
## True while an open/close animation is playing, so LEAVE can't be double-fired.
var _busy: bool = false
var _anim_tween: Tween = null
## Open-frame image, decompressed for per-pixel alpha hit-testing in overlay mode
## (deciding whether a click landed on the laptop art or on transparent background).
var _hit_image: Image = null

# --- camera mouse-follow (standalone laptop scene only) ---
# Mirrors the maintenance scene's resting camera: the view zooms in slightly so there is a
# margin to drift into, then eases toward the mouse with an edge-softened, clamped offset.
## Slight zoom so the background has room to drift without revealing its edges.
const MF_ZOOM_SCALE: float = 1.08
## How far (screen px) the view drifts toward the mouse at full pull.
const MF_STRENGTH: float = 24.0
## Edge softness: higher makes the pull saturate sooner so it never lurches at the border.
const MF_EDGE_FALLOFF: float = 2.5
## How quickly the view eases toward the target, per second.
const MF_SMOOTHING: float = 8.0
## The standalone scene's background sits this many screen pixels lower than centred.
const MF_BACKGROUND_DROP: float = 35.0
## Vertical sway range (screen px each way). The laptop rests this far below flush with
## the bottom of the screen, so the sway can lift it until its bottom edge meets the
## screen's - never past - and lower it the same amount.
const MF_VERTICAL_RANGE: float = 16.0
## Extra sway of the laptop alone (screen px at full pull, per axis), opposite the mouse,
## on top of the camera drift. Not bound by the pan limits, so it may lift the laptop
## enough to show a sliver below it.
const MF_LAPTOP_SWAY: Vector2 = Vector2(10.0, 8.0)

## Current smoothed sway offset applied on top of the resting (centered) layout.
var _mf_offset: Vector2 = Vector2.ZERO
## Resting (centered) layer positions and the per-axis pan limits, recomputed on layout.
var _mf_scene_base: Vector2 = Vector2.ZERO
var _mf_unit_base: Vector2 = Vector2.ZERO
## Resting scales of the background (cover-fit) and laptop (contain-fit).
var _mf_scene_scale: float = 1.0
var _mf_unit_scale: float = 1.0
## The laptop's own extra sway (see MF_LAPTOP_SWAY), smoothed like the drift.
var _mf_laptop_sway: Vector2 = Vector2.ZERO
var _mf_min_offset: Vector2 = Vector2.ZERO
var _mf_max_offset: Vector2 = Vector2.ZERO
## Whether the mouse-follow camera runs (standalone laptop scene, not an overlay).
var _mf_active: bool = false

# --- fullscreen (the taskbar's FULLSCREEN button) ---
# Like leaning in to the laptop: the view zooms toward its screen - room and laptop
# together - until the screen fills the display, the screen's content widening as it goes
# so it ends up covering the whole display edge to edge. Pressing it again leans back out.
## Seconds the zoom in (or back out) takes.
const FULLSCREEN_SECONDS: float = 0.6
## While (going) fullscreen the laptop draws on this canvas layer, above the hosts' LAPTOP
## drag bar (41), so nothing of the scene shows over its screen.
const FULLSCREEN_CANVAS_LAYER: int = 50

## 0 = the normal view, 1 = fullscreen; tweened between them.
var _fs_progress: float = 0.0
var _fs_target: bool = false
var _fs_tween: Tween = null
var _base_canvas_layer: int = 20


func _ready() -> void:
	_build_frames()
	_style_leave_button()

	# The subtle zoom + mouse-follow camera runs only for the standalone laptop scene, not
	# when the laptop is an overlay over another scene (that host owns the camera).
	_mf_active = not overlay_mode

	# Cover-fit the background and contain-fit the laptop (see _layout_canvas).
	get_viewport().size_changed.connect(_layout_canvas)
	_layout_canvas()

	# Host the desktop (app icons + taskbar) inside the black screen region, hidden until
	# the laptop has finished opening.
	_screen = LaptopDesktop.new()
	_screen.set("context", desktop_context)
	_screen.set("fullscreen_supported", true)
	_screen.connect("fullscreen_toggle_requested", _toggle_fullscreen)
	screen_content.add_child(_screen)
	screen_content.visible = false

	# As an overlay over another scene, draw above the host and absorb clicks that
	# miss the laptop's own buttons so they don't fall through to the scene below.
	# The laptop-crop background only belongs to the standalone laptop scene; as an
	# overlay (e.g. the maintenance laptop) it is hidden so the laptop sits on black
	# instead of painting that background over the host scene.
	if overlay_mode:
		fullscreen_layer.layer = 40
		# Keep the host scene (e.g. maintenance) visible behind the laptop instead
		# of blacking it out: the full-rect backdrop stays present only to catch
		# clicks (mouse_filter STOP works regardless of alpha), so make it
		# transparent rather than opaque black.
		black_background.color = Color(0, 0, 0, 0)
		black_background.mouse_filter = Control.MOUSE_FILTER_STOP
		scene_canvas.visible = false
		# The overlay laptop has no LEAVE button; clicking the background closes it.
		# The laptop art passes clicks through (IGNORE) so they reach the backdrop
		# handler, which then does a per-pixel test: a click only counts as "on the
		# laptop" if it lands on an OPAQUE pixel of the art. Transparent margins
		# inside the sprite's rect therefore close it, like true background does.
		# The screen region absorbs its own clicks (the running app is never
		# "background") so it can never accidentally dismiss the laptop.
		leave_button.visible = false
		laptop_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen_content.mouse_filter = Control.MOUSE_FILTER_STOP
		black_background.gui_input.connect(_on_overlay_background_input)
		_cache_laptop_hit_image()
	_base_canvas_layer = fullscreen_layer.layer

	leave_button.pressed.connect(_on_leave_pressed)

	_set_frame(FRAME_COUNT - 1)  # start on the closed frame
	leave_button.disabled = true  # inert until the laptop has finished opening
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
	# Standalone scene zooms in slightly so the camera has margin to drift into; as an overlay
	# there is no zoom and the background keeps its original top-crop (position.y = 0).
	var zoom: float = MF_ZOOM_SCALE if _mf_active else 1.0

	var cover: float = maxf(vp.x / CANVAS_SIZE.x, vp.y / CANVAS_SIZE.y) * zoom
	_mf_scene_scale = cover
	if scene_canvas != null:
		scene_canvas.size = CANVAS_SIZE
		scene_canvas.scale = Vector2(cover, cover)
		var scene_y: float = (vp.y - CANVAS_SIZE.y * cover) * 0.5 + MF_BACKGROUND_DROP if _mf_active else 0.0
		_mf_scene_base = Vector2((vp.x - CANVAS_SIZE.x * cover) * 0.5, scene_y)
		scene_canvas.position = _mf_scene_base

	# The laptop stays contain-fit (never zoomed past fully-visible) so its screen is always
	# fully on-screen; it only pans with the camera, within its own letterbox margin.
	var contain: float = minf(vp.x / CANVAS_SIZE.x, vp.y / CANVAS_SIZE.y)
	_mf_unit_scale = contain
	if laptop_unit != null:
		laptop_unit.size = CANVAS_SIZE
		laptop_unit.scale = Vector2(contain, contain)
		var unit_size := CANVAS_SIZE * contain
		# Standalone: the laptop rests MF_VERTICAL_RANGE below flush with the bottom of the
		# screen, so the sway can move it both ways without ever showing anything below it.
		# As an overlay it stays centred.
		var unit_y := vp.y - unit_size.y + MF_VERTICAL_RANGE if _mf_active else (vp.y - unit_size.y) * 0.5
		_mf_unit_base = Vector2((vp.x - unit_size.x) * 0.5, unit_y)
		laptop_unit.position = _mf_unit_base

	# Per-axis pan limits: never reveal a background edge. Horizontally the laptop also
	# stays uncropped. Vertically it sways MF_VERTICAL_RANGE each way around its rest
	# (which sits that far below flush), so the view never pans past the laptop's bottom.
	if _mf_active:
		var bg_margin := (CANVAS_SIZE * cover - vp) * 0.5
		var unit_margin_x := (vp.x - CANVAS_SIZE.x * contain) * 0.5
		var x := maxf(0.0, minf(bg_margin.x, unit_margin_x))
		# The background's top edge (lowered by MF_BACKGROUND_DROP) must stay above the screen.
		var bg_room_down := -_mf_scene_base.y
		_mf_min_offset = Vector2(-x, -MF_VERTICAL_RANGE)
		_mf_max_offset = Vector2(x, maxf(0.0, minf(bg_room_down, MF_VERTICAL_RANGE)))
	else:
		_mf_min_offset = Vector2.ZERO
		_mf_max_offset = Vector2.ZERO
	_apply_mf_offset()


func _process(delta: float) -> void:
	if not _mf_active:
		if _fs_progress > 0.0:
			_apply_mf_offset()
		return
	# The sway holds still while the inventory is open.
	if InventoryOverlay.is_open(get_tree()):
		_apply_mf_offset()
		return
	var smoothing: float = 1.0 - exp(-MF_SMOOTHING * maxf(0.0, delta))
	var following := _camera_mouse_follow_enabled()
	var target: Vector2 = _mf_target() if following else Vector2.ZERO
	_mf_offset = _mf_offset.lerp(target, smoothing)
	var sway_target: Vector2 = _mf_laptop_sway_target() if following else Vector2.ZERO
	_mf_laptop_sway = _mf_laptop_sway.lerp(sway_target, smoothing)
	_apply_mf_offset()


## The laptop's own sway for the current mouse position: opposite the cursor, easing in
## from the centre like the camera drift.
func _mf_laptop_sway_target() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return Vector2.ZERO
	var center: Vector2 = vp * 0.5
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var n := Vector2((mouse.x - center.x) / center.x, (mouse.y - center.y) / center.y)
	var pull := Vector2(_mf_falloff(n.x), _mf_falloff(n.y)) / _mf_falloff(1.0)
	return -pull * MF_LAPTOP_SWAY


## Applies the current sway offset (clamped to the pan limit) on top of the resting layout.
func _apply_mf_offset() -> void:
	var off := _mf_offset.clamp(_mf_min_offset, _mf_max_offset)
	if scene_canvas != null:
		scene_canvas.scale = Vector2.ONE * _mf_scene_scale
		scene_canvas.position = _mf_scene_base + off
	if laptop_unit != null:
		laptop_unit.scale = Vector2.ONE * _mf_unit_scale
		laptop_unit.position = _mf_unit_base + off + _mf_laptop_sway
	_apply_fullscreen_zoom()


# --- fullscreen ----------------------------------------------------------------------

## The taskbar's FULLSCREEN button: lean in to the screen, or back out.
func _toggle_fullscreen() -> void:
	# Not while the lid is opening or closing (closing waits on the zoom back out).
	if _busy:
		return
	_set_fullscreen(not _fs_target)


## Starts the zoom toward (or away from) fullscreen; returns the tween so a caller can wait
## on it (null if already there).
func _set_fullscreen(on: bool) -> Tween:
	_fs_target = on
	if _screen != null:
		_screen.set("fullscreen_active", on)
	if _fs_tween != null and _fs_tween.is_valid():
		_fs_tween.kill()
		_fs_tween = null
	var goal := 1.0 if on else 0.0
	if is_equal_approx(_fs_progress, goal):
		return null
	if on:
		fullscreen_layer.layer = maxi(_base_canvas_layer, FULLSCREEN_CANVAS_LAYER)
	# Takes the full time from the far end; a reversal part-way takes only what's left.
	var seconds := FULLSCREEN_SECONDS * absf(goal - _fs_progress)
	_fs_tween = create_tween()
	_fs_tween.tween_method(_set_fs_progress, _fs_progress, goal, seconds) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if not on:
		_fs_tween.tween_callback(func() -> void: fullscreen_layer.layer = _base_canvas_layer)
	return _fs_tween


func _set_fs_progress(value: float) -> void:
	_fs_progress = value
	_apply_mf_offset()


## Lays the fullscreen zoom over the normal layout _apply_mf_offset just set. The view scales
## about the screen's centre - room and laptop together, like a camera moving in - by up to
## the zoom that fits the screen to the display, while that centre slides to the display's
## centre. The screen's content widens (or heightens) meanwhile so at full zoom it covers
## the display exactly instead of leaving the bezel showing down two sides.
func _apply_fullscreen_zoom() -> void:
	if screen_content == null or laptop_unit == null:
		return
	if _fs_progress <= 0.0:
		screen_content.offset_left = 0.0
		screen_content.offset_top = 0.0
		screen_content.offset_right = 0.0
		screen_content.offset_bottom = 0.0
		return
	var vp: Vector2 = get_viewport_rect().size
	var unit_scale: float = _mf_unit_scale
	# The screen's rest rect inside the laptop (from its anchors), and where that is on screen.
	var screen_pos := Vector2(screen_content.anchor_left, screen_content.anchor_top) * CANVAS_SIZE
	var screen_size := Vector2(screen_content.anchor_right - screen_content.anchor_left,
			screen_content.anchor_bottom - screen_content.anchor_top) * CANVAS_SIZE
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or unit_scale <= 0.0:
		return
	var rest_size := screen_size * unit_scale
	var rest_centre := laptop_unit.position + (screen_pos + screen_size * 0.5) * unit_scale
	var t := _fs_progress
	# Eased exponentially so the zoom feels even all the way in.
	var full_zoom := minf(vp.x / rest_size.x, vp.y / rest_size.y)
	var zoom := pow(full_zoom, t)
	var centre := rest_centre.lerp(vp * 0.5, t)
	laptop_unit.scale = Vector2.ONE * unit_scale * zoom
	laptop_unit.position = centre + (laptop_unit.position - rest_centre) * zoom
	if scene_canvas != null:
		scene_canvas.scale = Vector2.ONE * _mf_scene_scale * zoom
		scene_canvas.position = centre + (scene_canvas.position - rest_centre) * zoom
	# Widen the content toward the display's shape (in laptop pixels, about its own centre).
	var full_size := vp / (unit_scale * full_zoom)
	var grow := (screen_size.lerp(full_size, t) - screen_size) * 0.5
	screen_content.offset_left = -grow.x
	screen_content.offset_top = -grow.y
	screen_content.offset_right = grow.x
	screen_content.offset_bottom = grow.y


## The sway offset the current mouse position calls for: pull toward the cursor that grows
## from the centre and tapers exponentially toward the edges, then clamped to the pan limit.
func _mf_target() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return Vector2.ZERO
	var center: Vector2 = vp * 0.5
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var n := Vector2((mouse.x - center.x) / center.x, (mouse.y - center.y) / center.y)
	# Negative: shifting the view the opposite way moves it toward the cursor.
	var off := -Vector2(_mf_falloff(n.x), _mf_falloff(n.y)) * MF_STRENGTH
	# Vertically, spread the (smaller) range over the whole screen height so the sway keeps
	# moving all the way to the top and bottom edges instead of maxing out early.
	off.y = -_mf_falloff(n.y) / _mf_falloff(1.0) * MF_VERTICAL_RANGE
	return off.clamp(_mf_min_offset, _mf_max_offset)


## Signed, saturating edge falloff for one axis (mirrors the maintenance camera).
func _mf_falloff(x: float) -> float:
	return signf(x) * (1.0 - exp(-absf(x) * MF_EDGE_FALLOFF))


func _camera_mouse_follow_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state == null or bool(state.get("camera_mouse_follow_enabled"))


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


## Overlay only: a click that isn't on an opaque laptop pixel closes the laptop,
## standing in for the LEAVE button. Clicks on the screen app are absorbed by
## ScreenContent and never reach here.
func _on_overlay_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _mouse_over_opaque_laptop_pixel():
			_on_leave_pressed()


## Caches the sprite sheet as a readable image for per-pixel hit-testing.
func _cache_laptop_hit_image() -> void:
	var sheet := load(SHEET_PATH) as Texture2D
	if sheet == null:
		return
	var img := sheet.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	_hit_image = img


## True when the mouse is over a non-transparent pixel of the laptop art. Maps the
## cursor into the sprite's rect, accounts for the KEEP_ASPECT_CENTERED letterbox,
## then samples the open frame's alpha in the sheet. Anything outside the drawn art
## (the transparent margins included) reads as background.
func _mouse_over_opaque_laptop_pixel() -> bool:
	if laptop_sprite == null or _hit_image == null or _frames.is_empty():
		return false
	var rect_size: Vector2 = laptop_sprite.size
	var region: Rect2 = _frames[0].region  # frame 0 = fully open
	var tex_size: Vector2 = region.size
	if rect_size.x <= 0.0 or rect_size.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return false
	# STRETCH_KEEP_ASPECT_CENTERED: fit the texture inside the rect, centered.
	var scale: float = minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var draw_offset: Vector2 = (rect_size - tex_size * scale) * 0.5
	var tex_pos: Vector2 = (laptop_sprite.get_local_mouse_position() - draw_offset) / scale
	if tex_pos.x < 0.0 or tex_pos.y < 0.0 or tex_pos.x >= tex_size.x or tex_pos.y >= tex_size.y:
		return false
	var sample := Vector2i(region.position + tex_pos)
	if sample.x < 0 or sample.y < 0 or sample.x >= _hit_image.get_width() or sample.y >= _hit_image.get_height():
		return false
	return _hit_image.get_pixelv(sample).a > 0.1


func _on_leave_pressed() -> void:
	if instant and overlay_mode:
		if is_queued_for_deletion():
			return
		closed.emit()
		queue_free()
		return
	if _busy:
		return
	_busy = true
	leave_button.disabled = true
	# Lean back out of fullscreen first, so the lid shuts on the laptop as it normally sits.
	var unzoom := _set_fullscreen(false)
	if unzoom != null:
		await unzoom.finished
	# Stop displaying the screen, then play the close animation forward.
	screen_content.visible = false
	await _play_frames(0, FRAME_COUNT - 1)

	if overlay_mode:
		closed.emit()
		queue_free()
	else:
		# Free action - return to the bedroom without advancing the phase.
		finish(0, 0, 0, {}, true)
