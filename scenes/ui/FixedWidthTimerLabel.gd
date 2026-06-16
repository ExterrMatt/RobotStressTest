extends Label

const GLOWING_LABEL_SCRIPT := preload("res://scenes/ui/GlowingLabel.gd")
const DIGIT_CHARACTERS := "0123456789"

@export var glow_color: Color = Color(1.0, 0.24, 0.0, 1.0):
	set(value):
		glow_color = value
		_apply_child_theme()

@export_range(1.0, 80.0, 1.0) var glow_radius_px: float = 34.0:
	set(value):
		glow_radius_px = value
		_apply_child_theme()

@export_range(0.0, 4.0, 0.05) var glow_strength: float = 1.7:
	set(value):
		glow_strength = value
		_apply_child_theme()

@export_range(8, 160, 1) var glow_padding_px: int = 72:
	set(value):
		glow_padding_px = value
		_apply_child_theme()

var _renderer: HBoxContainer
var _last_text: String = ""
var _last_size: Vector2 = Vector2.ZERO
var _last_font_size: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible_characters = 0
	_ensure_renderer()
	_refresh_rendered_text()


func _process(_delta: float) -> void:
	var font_size := get_theme_font_size("font_size")
	if text != _last_text or size != _last_size or font_size != _last_font_size:
		_refresh_rendered_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		_refresh_rendered_text()


func _ensure_renderer() -> void:
	if _renderer != null and is_instance_valid(_renderer):
		return

	_renderer = HBoxContainer.new()
	_renderer.name = "_FixedDigitRenderer"
	_renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_renderer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_renderer.alignment = BoxContainer.ALIGNMENT_END
	_renderer.add_theme_constant_override("separation", 0)
	add_child(_renderer)


func _refresh_rendered_text() -> void:
	if not is_inside_tree():
		return
	_ensure_renderer()

	var pieces := _timer_pieces(text)
	while _renderer.get_child_count() < pieces.size():
		_renderer.add_child(_build_piece_label())
	while _renderer.get_child_count() > pieces.size():
		var extra := _renderer.get_child(_renderer.get_child_count() - 1)
		_renderer.remove_child(extra)
		extra.queue_free()

	for index in range(pieces.size()):
		var piece := pieces[index]
		var label := _renderer.get_child(index) as Label
		var piece_text := String(piece["text"])
		label.text = piece_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if bool(piece["fixed"]) else HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size = Vector2(_piece_width(piece_text, bool(piece["fixed"])), _piece_height())

	_apply_child_theme()
	_last_text = text
	_last_size = size
	_last_font_size = get_theme_font_size("font_size")


func _build_piece_label() -> Label:
	var label := GLOWING_LABEL_SCRIPT.new() as Label
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = false
	label.vertical_alignment = vertical_alignment
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


func _timer_pieces(value: String) -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	var timer_start := value.find(": ")
	if timer_start >= 0:
		pieces.append({
			"text": value.substr(0, timer_start + 2),
			"fixed": false,
		})
		_add_time_char_pieces(value.substr(timer_start + 2), pieces)
		return pieces

	_add_time_char_pieces(value, pieces)
	return pieces


func _add_time_char_pieces(value: String, pieces: Array[Dictionary]) -> void:
	for index in range(value.length()):
		var character := value.substr(index, 1)
		pieces.append({
			"text": character,
			"fixed": DIGIT_CHARACTERS.contains(character),
		})


func _piece_width(value: String, fixed_width: bool) -> float:
	if fixed_width:
		return _digit_cell_width()
	return ceilf(_measure_text_width(value))


func _digit_cell_width() -> float:
	var width := 0.0
	for index in range(DIGIT_CHARACTERS.length()):
		width = maxf(width, _measure_text_width(DIGIT_CHARACTERS.substr(index, 1)))
	return ceilf(width)


func _piece_height() -> float:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	if font == null:
		return maxf(size.y, float(font_size))
	return maxf(size.y, font.get_height(font_size))


func _measure_text_width(value: String) -> float:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	if font == null:
		return float(value.length() * font_size)
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func _apply_child_theme() -> void:
	if _renderer == null:
		return

	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var font_color := get_theme_color("font_color")
	for child in _renderer.get_children():
		var label := child as Label
		if label == null:
			continue
		label.theme_type_variation = theme_type_variation
		if font != null:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", font_color)
		label.vertical_alignment = vertical_alignment
		label.set("glow_color", glow_color)
		label.set("glow_radius_px", glow_radius_px)
		label.set("glow_strength", glow_strength)
		label.set("glow_padding_px", glow_padding_px)
