extends Control
class_name PhoneOverlay
## The player's phone, held up in the bottom-right corner of the framed picture
## during the robot's calls (work table, park, school). The art lives on the
## work_table Aseprite sheet as three layers on the shared 500x125 cell, so it
## lines up over any 500x125 background. Starts hidden; only one view shows at a
## time.
##
## Main holds a single scene overlay at a time: hand this to
## Main.show_scene_overlay() directly, or add it under a scene's own overlay root
## (Work puts it beside the table chest).

const SHEET_PATH: String = "res://assets/textures/backgrounds/work_table.png"
const SHEET_JSON_PATH: String = "res://assets/textures/backgrounds/work_table.json"

enum View { FRONT, BACK, FLASH }

## The screen side is the default; "phone_back" is the phone turned over, and
## "flash" is the back with the camera flash lit.
const LAYERS: Dictionary = {
	View.FRONT: "phone_front",
	View.BACK: "phone_back",
	View.FLASH: "flash",
}

var _rects: Dictionary = {}  # View -> TextureRect


func _init() -> void:
	name = "PhoneOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var textures: Dictionary = PackedSpriteSheet.layer_textures(SHEET_PATH, SHEET_JSON_PATH)
	for view in LAYERS:
		var texture := textures.get(LAYERS[view]) as Texture2D
		if texture == null:
			push_warning("PhoneOverlay: no '%s' layer on the work_table sheet." % LAYERS[view])
			continue
		var rect := TextureRect.new()
		rect.name = String(LAYERS[view]).to_pascal_case()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(rect)
		_rects[view] = rect
	visible = false


## Shows the phone as `view` (front, back, or back with the flash lit).
func show_view(view: View) -> void:
	for key in _rects:
		(_rects[key] as TextureRect).visible = key == view
	visible = true


func hide_phone() -> void:
	visible = false


## The view currently up, or -1 when the phone is hidden.
func current_view() -> int:
	if not visible:
		return -1
	for key in _rects:
		if (_rects[key] as TextureRect).visible:
			return key
	return -1
