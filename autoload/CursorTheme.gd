extends Node

const CURSOR_PATH: String = "res://assets/textures/icons/cursor.png"

const HOTSPOT: Vector2 = Vector2(0.0, 0.0)
const CURSOR_SCALE: int = 2

var _cursor: Texture2D = null


func _ready() -> void:
	var source_cursor := load(CURSOR_PATH) as Texture2D
	if source_cursor == null:
		return
	_cursor = _scaled_cursor(source_cursor)

	Input.set_custom_mouse_cursor(_cursor, 0, HOTSPOT)
	Input.set_custom_mouse_cursor(_cursor, 2, HOTSPOT)
	Input.set_custom_mouse_cursor(_cursor, 6, HOTSPOT)
	Input.set_custom_mouse_cursor(_cursor, 7, HOTSPOT)
	Input.set_custom_mouse_cursor(_cursor, 13, HOTSPOT)


func _scaled_cursor(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	image.resize(image.get_width() * CURSOR_SCALE, image.get_height() * CURSOR_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
