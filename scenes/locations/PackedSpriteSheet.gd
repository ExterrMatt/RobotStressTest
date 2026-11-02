class_name PackedSpriteSheet
extends RefCounted
## Frame lookup for Aseprite sprite sheets exported as Packed + Split Layers +
## Trim Cels + Merge Duplicates (+ Ignore Empty). Each layer of each frame is a
## trimmed piece somewhere in the sheet; the JSON says where it sits in the sheet
## ("frame") and where it belongs inside the original cell ("spriteSourceSize").
##
## Sprites opt in by carrying the Aseprite layer name in their
## `sheet_layer` metadata (see StressTestRobot._apply_sheet_frame).

const SHEET_LAYER_META: StringName = &"sheet_layer"

## Sheet texture -> the JSON Aseprite wrote next to it. The JSONs stay where the
## Aseprite export writes them so a re-export updates them in place.
const JSON_PATHS: Dictionary = {
	"res://assets/textures/characters/robot/stresstest/animations/head/Mouth-B-Intro/mouth_b_Intro.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Mouth-B Intro.json",
	"res://assets/textures/characters/robot/stresstest/animations/head/Mouth-B-Loop-Medium/mouth_b_loop_medium.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Mouth-B Medium Loop.json",
	"res://assets/textures/characters/robot/stresstest/animations/head/Mouth-B-Outro/mouth_b_pre_outro.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Mouth-B Pre-Done.json",
	"res://assets/textures/characters/robot/stresstest/animations/head/Mouth-B-Outro/mouth_b_outro.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Mouth-B Done.json",
	"res://assets/textures/characters/robot/stresstest/animations/legs/Vegetable-Mission-Intro/vegetable_mssion_intro.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Vegetable-Mission-Intro.json",
	"res://assets/textures/characters/robot/stresstest/animations/legs/Vegetable-Mission-Medium/vegetable_mission_loop_medium.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Vegetable-Mission Medium Loop.json",
	"res://assets/textures/characters/robot/stresstest/animations/legs/Vegetable-Mission-Outro/vegetable_mission_pre_outro.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Vegetable-Mission Pre-Done.json",
	"res://assets/textures/characters/robot/stresstest/animations/legs/Vegetable-Mission-Outro/vegetable_mission_outro.png":
		"res://assets/textures/asepritefiles/(Bed, StressTest) Robot Vegetable-Mission Done.json",
}

## JSON path -> { "<layer>|<frame>": [Rect2 sheet region, Vector2 offset in cell,
## Vector2 cell size] }
static var _pieces_by_json: Dictionary = {}
## JSON path -> { "<layer>": Texture2D } built by layer_textures().
static var _layer_textures_by_json: Dictionary = {}
## "<json path>|<skipped layers>" -> Texture2D built by flattened_texture().
static var _flattened_by_key: Dictionary = {}


static func has_data(texture: Texture2D) -> bool:
	return texture != null and JSON_PATHS.has(texture.resource_path)


## Returns [region: Rect2, cell_offset: Vector2] for one layer/frame, or [] when
## that cel is empty (Ignore Empty drops it from the sheet).
static func get_piece(texture: Texture2D, layer: String, frame: int) -> Array:
	if not has_data(texture):
		return []
	var pieces := _pieces_for(String(JSON_PATHS[texture.resource_path]))
	return pieces.get("%s|%d" % [layer, frame], [])


## For a single-frame sheet (e.g. a body part's layers packed together): every
## layer rebuilt as its own texture at the full cell size, with the trimmed piece
## put back where it sits in the cell - so each texture lines up exactly like the
## separate per-layer PNG would. Built once per sheet and cached.
static func layer_textures(sheet_path: String, json_path: String) -> Dictionary:
	if _layer_textures_by_json.has(json_path):
		return _layer_textures_by_json[json_path]
	var textures := {}
	_layer_textures_by_json[json_path] = textures

	var sheet := load(sheet_path) as Texture2D
	var sheet_image: Image = sheet.get_image() if sheet != null else null
	if sheet_image == null:
		push_error("PackedSpriteSheet: could not load %s" % sheet_path)
		return textures
	if sheet_image.is_compressed():
		sheet_image.decompress()
	sheet_image.convert(Image.FORMAT_RGBA8)

	var pieces := _pieces_for(json_path)
	for key in pieces:
		var parts := String(key).split("|")
		if parts.size() != 2 or int(parts[1]) != 0:
			continue
		var region: Rect2 = pieces[key][0]
		var cell_offset: Vector2 = pieces[key][1]
		var cell_size: Vector2 = pieces[key][2]
		var cell := Image.create(int(cell_size.x), int(cell_size.y), false, Image.FORMAT_RGBA8)
		cell.blit_rect(sheet_image, Rect2i(region), Vector2i(cell_offset))
		textures[parts[0]] = ImageTexture.create_from_image(cell)
	return textures


## For a single-frame sheet: its layers drawn bottom to top in Aseprite's layer
## order into one full-cell texture, leaving out `skip_layers` - the flat picture a
## merged export would have given. Built once per sheet and cached.
static func flattened_texture(sheet_path: String, json_path: String, skip_layers: Array = []) -> Texture2D:
	var key := "%s|%s" % [json_path, ",".join(skip_layers)]
	if _flattened_by_key.has(key):
		return _flattened_by_key[key]
	var layers := layer_textures(sheet_path, json_path)
	var json := load(json_path) as JSON
	if layers.is_empty() or json == null or not (json.data is Dictionary):
		return null
	var flat: Image = null
	for layer_info in json.data.get("meta", {}).get("layers", []):
		var layer := String(layer_info.get("name", ""))
		if skip_layers.has(layer) or not layers.has(layer):
			continue
		var cell: Image = (layers[layer] as Texture2D).get_image()
		if flat == null:
			flat = Image.create(cell.get_width(), cell.get_height(), false, Image.FORMAT_RGBA8)
		flat.blend_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i.ZERO)
	var texture: Texture2D = ImageTexture.create_from_image(flat) if flat != null else null
	_flattened_by_key[key] = texture
	return texture


static func _pieces_for(json_path: String) -> Dictionary:
	if _pieces_by_json.has(json_path):
		return _pieces_by_json[json_path]
	var pieces := {}
	_pieces_by_json[json_path] = pieces

	var json := load(json_path) as JSON
	if json == null or not (json.data is Dictionary):
		push_error("PackedSpriteSheet: could not load %s" % json_path)
		return pieces
	var frames = json.data.get("frames", [])
	# Aseprite writes either the Hash (filename -> entry) or Array format.
	var entries: Array = []
	if frames is Dictionary:
		for filename in frames:
			var entry: Dictionary = frames[filename].duplicate()
			entry["filename"] = filename
			entries.append(entry)
	elif frames is Array:
		entries = frames

	# Default item filename: "{title} ({layer}) {frame}.{extension}". Single-frame
	# exports leave the frame number out ("{title} ({layer}).{extension}"); those
	# count as frame 0. An untitled sprite can export with an empty extension
	# ("Sprite-0001 (layer).").
	var name_re := RegEx.create_from_string("\\(([^()]*)\\)\\s*(\\d*)\\.[^.]*$")
	for entry in entries:
		var match := name_re.search(String(entry.get("filename", "")))
		if match == null:
			continue
		var rect: Dictionary = entry["frame"]
		var src: Dictionary = entry["spriteSourceSize"]
		var cell: Dictionary = entry.get("sourceSize", {"w": rect["w"], "h": rect["h"]})
		var frame_text := match.get_string(2)
		var frame := int(frame_text) if frame_text != "" else 0
		pieces["%s|%d" % [match.get_string(1), frame]] = [
			Rect2(rect["x"], rect["y"], rect["w"], rect["h"]),
			Vector2(src["x"], src["y"]),
			Vector2(cell["w"], cell["h"]),
		]
	return pieces
