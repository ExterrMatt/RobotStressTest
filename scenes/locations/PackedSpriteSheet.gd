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

## JSON path -> { "<layer>|<frame>": [Rect2 sheet region, Vector2 offset in cell] }
static var _pieces_by_json: Dictionary = {}


static func has_data(texture: Texture2D) -> bool:
	return texture != null and JSON_PATHS.has(texture.resource_path)


## Returns [region: Rect2, cell_offset: Vector2] for one layer/frame, or [] when
## that cel is empty (Ignore Empty drops it from the sheet).
static func get_piece(texture: Texture2D, layer: String, frame: int) -> Array:
	if not has_data(texture):
		return []
	var pieces := _pieces_for(String(JSON_PATHS[texture.resource_path]))
	return pieces.get("%s|%d" % [layer, frame], [])


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

	# Default item filename: "{title} ({layer}) {frame}.{extension}".
	var name_re := RegEx.create_from_string("\\(([^()]*)\\)\\s*(\\d+)\\.[^.]+$")
	for entry in entries:
		var match := name_re.search(String(entry.get("filename", "")))
		if match == null:
			continue
		var rect: Dictionary = entry["frame"]
		var src: Dictionary = entry["spriteSourceSize"]
		pieces["%s|%d" % [match.get_string(1), int(match.get_string(2))]] = [
			Rect2(rect["x"], rect["y"], rect["w"], rect["h"]),
			Vector2(src["x"], src["y"]),
		]
	return pieces
