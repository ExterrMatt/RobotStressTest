class_name LaptopDragBar
extends Control
## The "LAPTOP" bar along the bottom of the screen that a downward swipe opens (or puts
## away) the laptop with - in Maintenance and the stress test. Drawn from the
## laptop_drag_down art (its background, the LAPTOP word and four down-arrows), at the
## largest whole-number scale its width allows, centred along the bottom of this control;
## the arrows bob downward to show which way to swipe. Only the art itself takes the mouse.

const SHEET_PATH: String = "res://assets/textures/icons/laptop_drag_down.png"
const SHEET_JSON_PATH: String = "res://assets/textures/icons/laptop_drag_down.json"
## The arrows sink up to BOB_PIXELS art pixels and come back every BOB_SECONDS.
const BOB_PIXELS: float = 2.0
const BOB_SECONDS: float = 1.2

var _sheet: Texture2D = null
## Layer name -> [sheet region, top-left on the art canvas].
var _layers: Dictionary = {}
var _canvas_size: Vector2 = Vector2(200, 20)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_art()


func _load_art() -> void:
	_sheet = load(SHEET_PATH) as Texture2D
	var file := FileAccess.open(SHEET_JSON_PATH, FileAccess.READ)
	if _sheet == null or file == null:
		push_error("LaptopDragBar: laptop_drag_down art is missing")
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		return
	var name_pattern := RegEx.create_from_string("\\(([^)]*)\\)")
	var frames: Dictionary = data.get("frames", {})
	for key in frames:
		var found := name_pattern.search(String(key))
		if found == null:
			continue
		var frame: Dictionary = frames[key]
		var region := Rect2(frame["frame"]["x"], frame["frame"]["y"], frame["frame"]["w"], frame["frame"]["h"])
		var at := Vector2(frame["spriteSourceSize"]["x"], frame["spriteSourceSize"]["y"])
		_layers[found.get_string(1)] = [region, at]
		_canvas_size = Vector2(frame["sourceSize"]["w"], frame["sourceSize"]["h"])


## Art pixels to a screen pixel: the most whole times the art fits this control's width.
func art_scale() -> float:
	return maxf(1.0, floorf(size.x / _canvas_size.x))


## Where the art is drawn in this control: centred along its bottom edge.
func art_rect() -> Rect2:
	var s := art_scale()
	var art_size := _canvas_size * s
	return Rect2(Vector2(roundf((size.x - art_size.x) * 0.5), size.y - art_size.y), art_size)


## Whether `global_point` is on the drawn bar.
func contains_global_point(global_point: Vector2) -> bool:
	return art_rect().has_point(get_global_transform().affine_inverse() * global_point)


func _has_point(point: Vector2) -> bool:
	return art_rect().has_point(point)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _sheet == null:
		return
	var rect := art_rect()
	var s := art_scale()
	var bob := roundf(BOB_PIXELS * (0.5 - 0.5 * cos(TAU * fmod(Time.get_ticks_msec() / 1000.0, BOB_SECONDS) / BOB_SECONDS)))
	for layer_name in _layers:
		var layer: Array = _layers[layer_name]
		var offset := Vector2(0.0, bob) if String(layer_name).begins_with("arrow") else Vector2.ZERO
		var at: Vector2 = rect.position + ((layer[1] as Vector2) + offset) * s
		draw_texture_rect_region(_sheet, Rect2(at, (layer[0] as Rect2).size * s), layer[0])
