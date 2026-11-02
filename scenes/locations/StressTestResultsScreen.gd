class_name StressTestResultsScreen
extends Control
## The stress test's results screen: the results panel (the results_screen art) slides
## down from the top of the screen over black, with green code raining behind it - or,
## when the patrol drone shot you, over red with white code.
##
## A failed night shows the art's "Result: Failed" with the night's actual failure reason
## in place of the art's hint text (drawn in the same style), and offers DONE and TRY
## AGAIN. A completed night shows "Result: Completed" in the same lettering, its scores
## (electricity and screws, with star ratings, and the change in anger) where the reason
## would be, and DONE alone, moved down to make room.
##
## Its border is a fidget: once the four corner screws are unscrewed (with a screwdriver,
## click one and it spins out), every segment of the border can be clicked in and out. The buttons turn
## green while the mouse is over them; DONE carries on as before, TRY AGAIN re-runs the
## stress test.
##
## Added by StressTest over its failure overlay; it runs while the game is paused.

signal done_pressed
signal try_again_pressed

const SHEET_PATH: String = "res://assets/textures/icons/results_screen.png"
const SHEET_JSON_PATH: String = "res://assets/textures/icons/results_screen.json"
const PIXEL_FONT: FontFile = preload("res://assets/fonts/Jersey10-Regular.ttf")

## The panel art's size (art pixels), and the most of the screen it may take: it's drawn
## at the largest whole-number scale that fits.
const ART_SIZE: Vector2 = Vector2(300, 254)
const MAX_SCREEN_FRACTION: Vector2 = Vector2(0.9, 0.92)

## The failure reason, standing in for the art's hint text (art pixels): centred on
## REASON_CENTER, wrapped at REASON_MAX_WIDTH, REASON_LINE_PITCH between lines, in the
## hint's colour, a font pixel REASON_TEXT_PIXEL art pixels across (a quarter bigger than
## the art's own hint lettering). Jersey 10 is drawn at REASON_FONT_SIZE, scaled to fit.
const REASON_CENTER: Vector2 = Vector2(150, 126.5)
const REASON_MAX_WIDTH: float = 228.0
const REASON_LINE_PITCH: float = 14.8
const REASON_TEXT_PIXEL: float = 1.25
const REASON_COLOR: Color = Color8(250, 195, 129)
const REASON_FONT_SIZE: int = 28
const REASON_FONT_PIXELS: float = 3.0  # screen pixels per font pixel at REASON_FONT_SIZE
const FONT_CAP_RATIO: float = 750.0 / 1400.0

## A completed night's result line, in the place and manner of the art's "Result: Failed":
## two art pixels to a font pixel, a shadow RESULT_SHADOW_DROP below, the label in the
## art's tan and the result green.
const RESULT_CENTER_X: float = 150.0
const RESULT_BASELINE_Y: float = 106.0
const RESULT_SHADOW_DROP: float = 1.0
const RESULT_LABEL_COLOR: Color = Color8(235, 182, 120)
const RESULT_SHADOW_COLOR: Color = Color8(7, 15, 1)
## Good and bad, for the result and the change in anger (the bad red is the art's "Failed").
const RESULT_GOOD_COLOR: Color = Color8(126, 196, 96)
const RESULT_BAD_COLOR: Color = Color8(213, 78, 58)

## A completed night's scores (art pixels): each line centred on its own, a font pixel
## STATS_TEXT_PIXEL across (between the reason text's 1 and the result line's 2), the first
## line's baseline at STATS_FIRST_BASELINE and each next one STATS_LINE_PITCH below (plus
## its "space_before"), STAT_GAP between a line's label, stars and value.
const STATS_TEXT_PIXEL: float = 1.5
const STATS_FIRST_BASELINE: float = 128.5
const STATS_LINE_PITCH: float = 20.0
const STAT_GAP: float = 9.0
## A star rating's stars: STAR_PATTERN drawn at the text's pixel size, STAR_SPACING pattern
## pixels apart, lit in the hint's colour, unlit dim.
const STAR_PATTERN: Array[String] = [
	"...#...",
	"..###..",
	"#######",
	".#####.",
	"..###..",
	".##.##.",
	".#...#.",
]
const STAR_COUNT: int = 5
const STAR_SPACING: float = 2.0
const STAR_LIT_COLOR: Color = Color8(250, 195, 129)
const STAR_UNLIT_COLOR: Color = Color8(92, 80, 68)

## Sliding in: down from above the screen, eased out, carrying SLIDE_BOUNCE screen pixels
## past its spot and settling back (the bounce takes SLIDE_BOUNCE_SHARE of the time).
const SLIDE_TIME: float = 0.75
const SLIDE_BOUNCE: float = 14.0
const SLIDE_BOUNCE_SHARE: float = 0.25

## Unscrewing: the screw turns (its two frames swap every UNSCREW_FRAME_TIME, UNSCREW_STEPS
## times), lifting UNSCREW_LIFT art pixels and fading out over the last UNSCREW_FADE_SHARE.
const UNSCREW_FRAME_TIME: float = 0.06
const UNSCREW_STEPS: int = 8
const UNSCREW_LIFT: float = 2.0
const UNSCREW_FADE_SHARE: float = 0.35
const SCREW_CORNERS: Array[String] = ["top_left", "top_right", "bottom_right", "bottom_left"]
## Clicks this close to a screw (art pixels) count as on it.
const SCREW_GRAB_MARGIN: float = 2.0

## The code rain behind the panel: columns of glyphs, each with a bright head sliding down
## and a fading tail; the glyphs flicker as it goes.
const RAIN_GLYPHS: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$#%&*+=<>"
const RAIN_FONT_SIZE: int = 19
const RAIN_COLUMN_WIDTH: float = 16.0
const RAIN_ROW_HEIGHT: float = 18.0
const RAIN_SPEED_RANGE: Vector2 = Vector2(5.0, 14.0)  # rows per second
const RAIN_LENGTH_RANGE: Vector2i = Vector2i(6, 24)
const RAIN_SWAPS_PER_SECOND: float = 40.0
const RAIN_HEAD_COLOR: Color = Color(0.82, 1.0, 0.84)
const RAIN_COLOR: Color = Color(0.12, 0.92, 0.32)
## Shot by the patrol drone: red behind the panel (shot_color), the code white.
const SHOT_BACKGROUND_COLOR: Color = Color8(160, 16, 16)
const SHOT_RAIN_HEAD_COLOR: Color = Color.WHITE
const SHOT_RAIN_COLOR: Color = Color(1.0, 1.0, 1.0)

const UNSCREW_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/screws/screw_coming_loose_1.mp3",
	"res://assets/sounds/screws/screw_coming_loose_2.mp3",
	"res://assets/sounds/screws/screw_coming_loose_3.mp3",
]
## Pressing a border segment in or out: a harsh click, pitched anywhere up to
## SEGMENT_PITCH_VARIATION up or down so repeats don't sound the same.
const SEGMENT_SOUND_PATH: String = "res://assets/sounds/menu_buttons/button_click_harsh.mp3"
const SEGMENT_PITCH_VARIATION: float = 0.15
## DONE / TRY AGAIN: the ordinary menu click.
const BUTTON_SOUND_PATH: String = "res://assets/sounds/menu_buttons/button_click.mp3"
## Unscrewing takes a screwdriver.
const SCREWDRIVER_TOOL_ID: String = "screwdriver"

## Set before the screen is added:
## Whether the night was completed (scores) or failed (the reason).
var success: bool = false
## A failed night's reason.
var reason: String = ""
## A completed night's result ("Result: <result_text>") and its scores, a line each:
## {"label": String, "stars": lit stars out of STAR_COUNT (none if missing), "value":
## String, "color": the line's text colour, "space_before": extra room above it}.
var result_text: String = "Completed"
var stats: Array[Dictionary] = []
## The patrol drone shot you: red background (shot_color - the stress test passes the red
## its death sweep ends on, so the one runs straight into the other), white code.
var shot: bool = false
var shot_color: Color = SHOT_BACKGROUND_COLOR
## Seconds the code takes to fade in over the background (0: there from the start) - for
## coming straight in off a screen of the same colour, with no wipe between.
var rain_fade_in: float = 0.0
## The buttons offered (the intro's stress test has to be repeated, so no DONE; a
## completed night has nothing to try again).
var show_done: bool = true
var show_try_again: bool = true

## Art layers by name: [AtlasTexture, top-left in the panel (art pixels), sheet region].
var _layers: Dictionary = {}
## Layer names, bottom first (the order Aseprite stacks them).
var _order: Array[String] = []
var _sheet_image: Image = null
## Border segments (layer names without _unclicked / _clicked) and which are pressed in.
var _segments: Array[String] = []
var _pressed: Dictionary = {}
## Each corner's screw: "in", "turning" (with its time in _screw_time) or "out".
var _screw_state: Dictionary = {}
var _screw_time: Dictionary = {}
## Buttons on show: art name stem -> signal it fires ("done", "try_again").
var _buttons: Array[String] = []
var _hover_button: String = ""
var _press_button: String = ""
## Buttons moved from their place in the art (art pixels): a lone button takes the other's
## slot - TRY AGAIN up into DONE's, or DONE down into TRY AGAIN's below the scores.
var _button_shifts: Dictionary = {}
var _scale: float = 2.0
## The part of this control that's on screen: the camera window it sits in is taller than
## the screen and cropped top and bottom.
var _view: Rect2 = Rect2()
var _slide_offset: float = 0.0
## Clicks are only taken once the panel has slid into place, and none after a button.
var _interactive: bool = false
var _finished: bool = false
var _panel: Control = null
var _rng := RandomNumberGenerator.new()
## Rain columns: {x, head (row), speed, length}; glyphs per column, fixed to grid rows.
var _rain: Array[Dictionary] = []
var _rain_glyphs: Array = []
var _rain_rows: int = 0
var _swap_carry: float = 0.0
var _rain_alpha: float = 1.0
var _audio: AudioStreamPlayer = null


func _ready() -> void:
	# It plays while the game is paused behind it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	if rain_fade_in > 0.0:
		_rain_alpha = 0.0
		create_tween().tween_property(self, "_rain_alpha", 1.0, rain_fade_in)
	_load_art()
	for corner in SCREW_CORNERS:
		_screw_state[corner] = "in"
		_screw_time[corner] = 0.0
	var done_y := _layer_rect("blue_done_button").position.y
	var try_again_y := _layer_rect("blue_try_again_button").position.y
	if show_done:
		_buttons.append("done")
		if not show_try_again:
			_button_shifts["done"] = Vector2(0.0, try_again_y - done_y)
	if show_try_again:
		_buttons.append("try_again")
		if not show_done:
			_button_shifts["try_again"] = Vector2(0.0, done_y - try_again_y)

	_panel = Control.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	resized.connect(_layout)
	_layout()
	# Hidden above the screen until slide_in().
	_slide_offset = -_offscreen_distance()
	_place_panel()


## Brings the panel down from the top: eased out, a little past its spot, then settling.
func slide_in() -> void:
	_slide_offset = -_offscreen_distance()
	var tw := create_tween()
	tw.tween_property(self, "_slide_offset", SLIDE_BOUNCE, SLIDE_TIME * (1.0 - SLIDE_BOUNCE_SHARE)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_slide_offset", 0.0, SLIDE_TIME * SLIDE_BOUNCE_SHARE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void: _interactive = not _finished)


func _process(delta: float) -> void:
	if _visible_rect() != _view:
		_layout()
	_place_panel()
	_advance_screws(delta)
	_advance_rain(delta)
	# Green only while the mouse is over a button - checked every frame, so it goes back
	# to blue whenever the mouse is anywhere else.
	_update_hover(get_local_mouse_position())
	queue_redraw()
	_panel.queue_redraw()


## The button under `local` (a point on this control) turns green; every other is blue.
func _update_hover(local: Vector2) -> void:
	_hover_button = _button_at(_art_point(local)) if _interactive else ""


# --- art ----------------------------------------------------------------------

func _load_art() -> void:
	var sheet := load(SHEET_PATH) as Texture2D
	var file := FileAccess.open(SHEET_JSON_PATH, FileAccess.READ)
	if sheet == null or file == null:
		push_error("StressTestResultsScreen: results screen art is missing")
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		return
	_sheet_image = sheet.get_image()
	if _sheet_image != null and _sheet_image.is_compressed():
		_sheet_image.decompress()
	var name_pattern := RegEx.create_from_string("\\(([^)]*)\\)")
	var frames: Dictionary = data.get("frames", {})
	for key in frames:
		var found := name_pattern.search(String(key))
		if found == null:
			continue
		var frame: Dictionary = frames[key]
		var region := Rect2(frame["frame"]["x"], frame["frame"]["y"], frame["frame"]["w"], frame["frame"]["h"])
		var at := Vector2(frame["spriteSourceSize"]["x"], frame["spriteSourceSize"]["y"])
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = region
		_layers[found.get_string(1)] = [tex, at, region]
	for layer in (data.get("meta", {}) as Dictionary).get("layers", []):
		var layer_name := String(layer["name"])
		if _layers.has(layer_name):
			_order.append(layer_name)
			if layer_name.ends_with("_unclicked"):
				var segment := layer_name.trim_suffix("_unclicked")
				if _layers.has(segment + "_clicked"):
					_segments.append(segment)
					_pressed[segment] = false


func _layout() -> void:
	_view = _visible_rect()
	var fit := (_view.size * MAX_SCREEN_FRACTION / ART_SIZE)
	_scale = maxf(1.0, floorf(minf(fit.x, fit.y)))
	_panel.size = ART_SIZE * _scale
	_init_rain()


func _visible_rect() -> Rect2:
	var own := Rect2(Vector2.ZERO, size)
	var shown := own.intersection(get_global_transform_with_canvas().affine_inverse() * get_viewport_rect())
	return shown if shown.has_area() else own


func _place_panel() -> void:
	var rest := (_view.position + (_view.size - _panel.size) * 0.5).round()
	_panel.position = rest + Vector2(0.0, roundf(_slide_offset))


## How far above its spot the panel starts, to be wholly off the top of the screen.
func _offscreen_distance() -> float:
	return roundf((_view.size.y - _panel.size.y) * 0.5) + _panel.size.y + 4.0


## A point on this control in panel art pixels.
func _art_point(local: Vector2) -> Vector2:
	return (local - _panel.position) / _scale


func _layer_rect(layer_name: String) -> Rect2:
	var layer: Array = _layers.get(layer_name, [])
	return Rect2(layer[1], (layer[2] as Rect2).size) if not layer.is_empty() else Rect2()


## Whether layer `layer_name` has a solid pixel at art point `p`.
func _layer_hit(layer_name: String, p: Vector2) -> bool:
	var layer: Array = _layers.get(layer_name, [])
	if layer.is_empty() or _sheet_image == null:
		return false
	var region: Rect2 = layer[2]
	var local := (p - (layer[1] as Vector2)).floor()
	if local.x < 0.0 or local.y < 0.0 or local.x >= region.size.x or local.y >= region.size.y:
		return false
	return _sheet_image.get_pixelv(Vector2i(region.position + local)).a > 0.1


func _draw_layer(layer_name: String, offset: Vector2 = Vector2.ZERO, alpha: float = 1.0) -> void:
	var layer: Array = _layers.get(layer_name, [])
	if layer.is_empty():
		return
	var tex: Texture2D = layer[0]
	var at: Vector2 = ((layer[1] as Vector2) + offset) * _scale
	_panel.draw_texture_rect(tex, Rect2(at.round(), tex.get_size() * _scale), false, Color(1, 1, 1, alpha))


# --- drawing --------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), shot_color if shot else Color.BLACK)
	_draw_rain()


func _draw_panel() -> void:
	var drawn_buttons: Dictionary = {}
	for layer_name in _order:
		if layer_name == "hint_text":
			if success:
				_draw_stats()
			else:
				_draw_reason()
		elif layer_name == "result_failed":
			if success:
				_draw_result_line()
			else:
				_draw_layer(layer_name)
		elif layer_name.ends_with("_unclicked") or layer_name.ends_with("_clicked"):
			var segment := layer_name.trim_suffix("_unclicked").trim_suffix("_clicked")
			if _pressed.has(segment) and layer_name.ends_with("_clicked") == bool(_pressed[segment]):
				_draw_layer(layer_name)
		elif layer_name.begins_with("screw_"):
			_draw_screw(layer_name)
		elif layer_name.ends_with("_button"):
			var stem := layer_name.trim_suffix("_button").trim_prefix("green_").trim_prefix("blue_")
			if stem in _buttons and not drawn_buttons.has(stem):
				drawn_buttons[stem] = true
				_draw_layer(("green_" if stem == _hover_button else "blue_") + stem + "_button", _button_shift(stem))
		else:
			_draw_layer(layer_name)


## A corner's screw: in place, turning out (its two frames swapping as it lifts and fades),
## or gone.
func _draw_screw(layer_name: String) -> void:
	if layer_name.ends_with("_2"):
		return  # the turned frame, drawn with its screw below
	var corner := layer_name.trim_prefix("screw_")
	match String(_screw_state.get(corner, "in")):
		"in":
			_draw_layer(layer_name)
		"turning":
			var t := float(_screw_time[corner])
			var total := UNSCREW_FRAME_TIME * UNSCREW_STEPS
			var turned := int(t / UNSCREW_FRAME_TIME) % 2 == 1
			var lift := Vector2(0.0, -roundf(UNSCREW_LIFT * t / total))
			var fade_from := total * (1.0 - UNSCREW_FADE_SHARE)
			var alpha := 1.0 - clampf((t - fade_from) / (total - fade_from), 0.0, 1.0)
			_draw_layer(layer_name + ("_2" if turned else ""), lift, alpha)


## The failure reason in the hint text's place and style: Jersey 10 on the art's pixel
## grid, centred, in the hint's colour.
func _draw_reason() -> void:
	var lines := _balanced_wrap(reason, REASON_MAX_WIDTH * REASON_FONT_PIXELS / REASON_TEXT_PIXEL)
	if lines.is_empty():
		return
	var cap := _art_cap_height() * REASON_TEXT_PIXEL
	var block := (lines.size() - 1) * REASON_LINE_PITCH + cap
	var top := _snap(REASON_CENTER.y - block * 0.5)
	for i in lines.size():
		var x := _snap(REASON_CENTER.x - _art_text_width(lines[i], REASON_TEXT_PIXEL) * 0.5)
		_draw_art_text(lines[i], x, _snap(top + i * REASON_LINE_PITCH + cap), REASON_TEXT_PIXEL, REASON_COLOR)


## A completed night's "Result: Completed", where the art has "Result: Failed" and in its
## lettering: chunky (two art pixels to a font pixel), shadowed, the result green.
func _draw_result_line() -> void:
	var label := "Result: "
	var label_width := _art_text_width(label, 2.0)
	var x := roundf(RESULT_CENTER_X - (label_width + _art_text_width(result_text, 2.0)) * 0.5)
	for shadow in [true, false]:
		var baseline := RESULT_BASELINE_Y + (RESULT_SHADOW_DROP if shadow else 0.0)
		_draw_art_text(label, x, baseline, 2.0, RESULT_SHADOW_COLOR if shadow else RESULT_LABEL_COLOR)
		_draw_art_text(result_text, x + label_width, baseline, 2.0, RESULT_SHADOW_COLOR if shadow else RESULT_GOOD_COLOR)


## A completed night's scores where the reason would be, in the hint's lettering (a size
## up): a line each - its label, its star rating, its value - centred.
func _draw_stats() -> void:
	if stats.is_empty():
		return
	var baseline := STATS_FIRST_BASELINE
	for i in stats.size():
		var stat: Dictionary = stats[i]
		if i > 0:
			baseline += STATS_LINE_PITCH + float(stat.get("space_before", 0.0))
		var color: Color = stat.get("color", REASON_COLOR)
		var label := String(stat.get("label", ""))
		var value := String(stat.get("value", ""))
		var has_stars := stat.has("stars")
		var width := _art_text_width(label, STATS_TEXT_PIXEL)
		if has_stars:
			width += STAT_GAP + _stars_width()
		if not value.is_empty():
			width += STAT_GAP + _art_text_width(value, STATS_TEXT_PIXEL)
		var x := _snap(REASON_CENTER.x - width * 0.5)
		_draw_art_text(label, x, baseline, STATS_TEXT_PIXEL, color)
		x += _art_text_width(label, STATS_TEXT_PIXEL)
		if has_stars:
			x += STAT_GAP
			_draw_stars(int(stat["stars"]), x, baseline)
			x += _stars_width()
		if not value.is_empty():
			_draw_art_text(value, x + STAT_GAP, baseline, STATS_TEXT_PIXEL, color)


## `v` (art pixels) on a whole screen pixel, so text and stars land on the screen's grid.
func _snap(v: float) -> float:
	return roundf(v * _scale) / _scale


func _stars_width() -> float:
	return (STAR_COUNT * STAR_PATTERN[0].length() + (STAR_COUNT - 1) * STAR_SPACING) * STATS_TEXT_PIXEL


## A row of STAR_COUNT pixel stars, `lit` of them lit, from art x `x`, sitting on the
## text line whose baseline is at art y `baseline`.
func _draw_stars(lit: int, x: float, baseline: float) -> void:
	var px := STATS_TEXT_PIXEL
	# Centred on the text's capitals.
	var cap := _art_cap_height() * px
	var top := _snap(baseline - cap * 0.5 - STAR_PATTERN.size() * px * 0.5)
	for s in STAR_COUNT:
		var color := STAR_LIT_COLOR if s < lit else STAR_UNLIT_COLOR
		var left := x + s * (STAR_PATTERN[0].length() + STAR_SPACING) * px
		for row in STAR_PATTERN.size():
			var line := STAR_PATTERN[row]
			for col in line.length():
				if line[col] == "#":
					_panel.draw_rect(Rect2(Vector2(left + col * px, top + row * px) * _scale, Vector2.ONE * px * _scale), color)


## Draws `text` in Jersey 10 on the art's pixel grid: its left end at art x `x`, its
## baseline at art y `baseline`, `pixel` art pixels to each font pixel.
func _draw_art_text(text: String, x: float, baseline: float, pixel: float, color: Color) -> void:
	if text.is_empty():
		return
	_panel.draw_set_transform(Vector2(x, baseline) * _scale, 0.0, Vector2.ONE * _scale * pixel / REASON_FONT_PIXELS)
	_panel.draw_string(PIXEL_FONT, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, REASON_FONT_SIZE, color)
	_panel.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How wide `text` is in art pixels, at `pixel` art pixels to each font pixel.
func _art_text_width(text: String, pixel: float = 1.0) -> float:
	return PIXEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, REASON_FONT_SIZE).x / REASON_FONT_PIXELS * pixel


## The font's cap height in art pixels (at one art pixel to a font pixel).
func _art_cap_height() -> float:
	return REASON_FONT_SIZE * FONT_CAP_RATIO / REASON_FONT_PIXELS


## `text` wrapped into as few lines as fit `max_width` (at REASON_FONT_SIZE): a sentence a
## line if they each fit, otherwise as evenly as those lines allow - two halves rather
## than a full line and a stray word.
func _balanced_wrap(text: String, max_width: float) -> PackedStringArray:
	var lines := _wrap(text, max_width)
	# Best of all, a line per sentence - when each fits and it takes no more lines.
	var sentences := _sentences(text)
	if sentences.size() > 1 and sentences.size() <= lines.size():
		var fits := true
		for sentence in sentences:
			if PIXEL_FONT.get_string_size(sentence, HORIZONTAL_ALIGNMENT_LEFT, -1, REASON_FONT_SIZE).x > max_width:
				fits = false
				break
		if fits:
			return sentences
	var width := max_width
	while lines.size() > 1 and width > REASON_FONT_SIZE:
		var narrower := _wrap(text, width - REASON_FONT_PIXELS)
		if narrower.size() > lines.size():
			break
		lines = narrower
		width -= REASON_FONT_PIXELS
	return lines


## `text` split after each full stop (the stop kept with its sentence).
func _sentences(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in text.strip_edges().split(". ", false):
		out.append(part if part.ends_with(".") else part + ".")
	if not text.strip_edges().ends_with(".") and not out.is_empty():
		out[out.size() - 1] = out[out.size() - 1].trim_suffix(".")
	return out


## `text` broken into lines no wider than `max_width` (at REASON_FONT_SIZE).
func _wrap(text: String, max_width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.strip_edges().split(" ", false):
		var attempt := word if line.is_empty() else line + " " + word
		if not line.is_empty() and PIXEL_FONT.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, REASON_FONT_SIZE).x > max_width:
			lines.append(line)
			line = word
		else:
			line = attempt
	if not line.is_empty():
		lines.append(line)
	return lines


# --- the code rain ----------------------------------------------------------------

func _init_rain() -> void:
	_rain.clear()
	_rain_glyphs.clear()
	if not _view.has_area():
		return
	_rain_rows = ceili(_view.size.y / RAIN_ROW_HEIGHT) + 1
	for i in ceili(_view.size.x / RAIN_COLUMN_WIDTH):
		var column := {"x": _view.position.x + i * RAIN_COLUMN_WIDTH + 2.0}
		_reset_rain_column(column, true)
		_rain.append(column)
		var glyphs: Array[String] = []
		for r in _rain_rows:
			glyphs.append(_random_glyph())
		_rain_glyphs.append(glyphs)


func _reset_rain_column(column: Dictionary, anywhere: bool) -> void:
	column["speed"] = _rng.randf_range(RAIN_SPEED_RANGE.x, RAIN_SPEED_RANGE.y)
	column["length"] = _rng.randi_range(RAIN_LENGTH_RANGE.x, RAIN_LENGTH_RANGE.y)
	# At the start the columns are already mid-fall; later ones drop in from above.
	column["head"] = _rng.randf_range(-float(_rain_rows), float(_rain_rows)) if anywhere \
			else -_rng.randf_range(0.0, float(_rain_rows) * 0.5)


func _random_glyph() -> String:
	return RAIN_GLYPHS[_rng.randi() % RAIN_GLYPHS.length()]


func _advance_rain(delta: float) -> void:
	for column in _rain:
		column["head"] = float(column["head"]) + float(column["speed"]) * delta
		if float(column["head"]) - int(column["length"]) > _rain_rows:
			_reset_rain_column(column, false)
	# A few glyphs flicker to something else each frame.
	_swap_carry += RAIN_SWAPS_PER_SECOND * delta
	while _swap_carry >= 1.0 and not _rain_glyphs.is_empty():
		_swap_carry -= 1.0
		var glyphs: Array = _rain_glyphs[_rng.randi() % _rain_glyphs.size()]
		glyphs[_rng.randi() % glyphs.size()] = _random_glyph()


func _draw_rain() -> void:
	var hidden := Rect2(_panel.position, _panel.size).grow(-RAIN_ROW_HEIGHT)
	if _rain_alpha <= 0.0:
		return
	var head_color := Color(SHOT_RAIN_HEAD_COLOR if shot else RAIN_HEAD_COLOR, _rain_alpha)
	var tail_color := SHOT_RAIN_COLOR if shot else RAIN_COLOR
	for c in _rain.size():
		var column: Dictionary = _rain[c]
		var glyphs: Array = _rain_glyphs[c]
		var head := floori(float(column["head"]))
		var length := int(column["length"])
		var x := float(column["x"])
		for i in length:
			var row := head - i
			if row < 0 or row >= _rain_rows:
				continue
			var at := Vector2(x, _view.position.y + (row + 1) * RAIN_ROW_HEIGHT)
			if hidden.has_point(at):
				continue  # behind the panel
			var color := head_color if i == 0 else Color(tail_color, 0.9 * pow(1.0 - float(i) / length, 1.3) * _rain_alpha)
			draw_char(PIXEL_FONT, at, String(glyphs[row % glyphs.size()]), RAIN_FONT_SIZE, color)


# --- screws, segments and buttons -------------------------------------------------

func _advance_screws(delta: float) -> void:
	for corner in SCREW_CORNERS:
		if _screw_state[corner] != "turning":
			continue
		_screw_time[corner] = float(_screw_time[corner]) + delta
		if float(_screw_time[corner]) >= UNSCREW_FRAME_TIME * UNSCREW_STEPS:
			_screw_state[corner] = "out"


func _all_screws_out() -> bool:
	for corner in SCREW_CORNERS:
		if _screw_state[corner] != "out":
			return false
	return true


func _screw_at(p: Vector2) -> String:
	for corner in SCREW_CORNERS:
		if _screw_state[corner] == "in" and _layer_rect("screw_" + corner).grow(SCREW_GRAB_MARGIN).has_point(p):
			return corner
	return ""


## The border segment drawn on top at art point `p` ("" for none).
func _segment_at(p: Vector2) -> String:
	for i in range(_segments.size() - 1, -1, -1):
		var segment := _segments[i]
		var shown := segment + ("_clicked" if _pressed[segment] else "_unclicked")
		if _layer_hit(shown, p) or _layer_hit(segment + "_unclicked", p):
			return segment
	return ""


func _button_at(p: Vector2) -> String:
	for stem in _buttons:
		if _layer_hit("blue_" + stem + "_button", p - _button_shift(stem)):
			return stem
	return ""


func _button_shift(stem: String) -> Vector2:
	return _button_shifts.get(stem, Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not _interactive:
		return
	var p := _art_point(event.position)
	if not event.pressed:
		# A button fires on release, over the one it was pressed on.
		var released_on := _button_at(p)
		if _press_button != "" and released_on == _press_button:
			_fire(_press_button)
		_press_button = ""
		return
	var button := _button_at(p)
	if button != "":
		_press_button = button
		return
	var corner := _screw_at(p)
	if corner != "":
		# Without a screwdriver the screw just stays put.
		if GameState.has_tool(SCREWDRIVER_TOOL_ID):
			_screw_state[corner] = "turning"
			_screw_time[corner] = 0.0
			_play(UNSCREW_SOUND_PATHS[_rng.randi() % UNSCREW_SOUND_PATHS.size()])
		return
	# Segments stay put (silently) until all four screws are out.
	var segment := _segment_at(p)
	if segment != "" and _all_screws_out():
		_pressed[segment] = not _pressed[segment]
		_play(SEGMENT_SOUND_PATH, SEGMENT_PITCH_VARIATION)


func _fire(button: String) -> void:
	_finished = true
	_interactive = false
	_hover_button = ""
	_play(BUTTON_SOUND_PATH)
	if button == "done":
		done_pressed.emit()
	else:
		try_again_pressed.emit()


## Plays `path`, its pitch picked at random within `pitch_variation` either side of normal.
func _play(path: String, pitch_variation: float = 0.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = _rng.randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	_audio.play()
