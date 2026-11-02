extends RefCounted
class_name FlashlightIcon
## The flashlight's icon, built from its Aseprite sheet (flashlight-sheet.png + .json). The
## sheet packs two layers: "light_on" (the flashlight with its lens lit) and "light_off" (a
## dark lens that sits over the lit one). Off - the default - is both layers stacked; on is
## the lit layer alone. Use texture(GameState.flashlight_on) wherever the icon is shown.

const SHEET_PATH: String = "res://assets/textures/icons/flashlight-sheet.png"
const SHEET_DATA_PATH: String = "res://assets/textures/icons/flashlight-sheet.json"
const LIT_FRAME: String = "flashlight (light_on).png"
const COVER_FRAME: String = "flashlight (light_off).png"
const FALLBACK_PATH: String = "res://assets/textures/icons/placeholder_item.png"

## {true: lit texture, false: off texture}, built on first use.
static var _cache: Dictionary = {}


static func texture(lit: bool = false) -> Texture2D:
	if not _cache.has(lit):
		_cache[lit] = _build(lit)
	return _cache[lit]


static func _build(lit: bool) -> Texture2D:
	var sheet_tex := load(SHEET_PATH) as Texture2D
	# Loaded as a JSON resource (not read as a file) so it's packed into exports.
	var json := load(SHEET_DATA_PATH) as JSON
	var data = json.data if json != null else null
	if sheet_tex == null or not (data is Dictionary) or not (data.get("frames") is Dictionary):
		return load(FALLBACK_PATH) as Texture2D
	var sheet := sheet_tex.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	var frames: Dictionary = data["frames"]
	var lit_frame: Dictionary = frames.get(LIT_FRAME, {})
	if lit_frame.is_empty():
		return load(FALLBACK_PATH) as Texture2D
	var source: Dictionary = lit_frame["sourceSize"]
	var canvas := Image.create(int(source["w"]), int(source["h"]), false, Image.FORMAT_RGBA8)
	_draw_frame(canvas, sheet, lit_frame)
	if not lit and frames.has(COVER_FRAME):
		_draw_frame(canvas, sheet, frames[COVER_FRAME])
	return ImageTexture.create_from_image(canvas)


## Draws one trimmed sheet frame onto `canvas` where it sits in the untrimmed sprite.
static func _draw_frame(canvas: Image, sheet: Image, frame: Dictionary) -> void:
	var r: Dictionary = frame["frame"]
	var at: Dictionary = frame["spriteSourceSize"]
	var src := Rect2i(int(r["x"]), int(r["y"]), int(r["w"]), int(r["h"]))
	canvas.blend_rect(sheet, src, Vector2i(int(at["x"]), int(at["y"])))
