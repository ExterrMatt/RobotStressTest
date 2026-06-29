class_name MouseFollowTooltip
extends PanelContainer

const PIXEL_FONT: FontFile = preload("res://assets/fonts/Jersey10-Regular.ttf")

@export var mouse_offset: Vector2 = Vector2(18.0, 18.0)
@export var viewport_margin: float = 8.0
@export var max_label_width: float = 320.0
@export var show_delay_seconds: float = 1.5

var _label: Label = null
var _last_text: String = ""
var _last_mouse_position: Vector2 = Vector2.INF
var _pending_text: String = ""
var _pending_elapsed_seconds: float = 0.0
var _pending_show: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 4096

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.05, 0.88)
	style.border_color = Color(0.85, 0.78, 0.42, 0.95)
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", PIXEL_FONT)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.74, 1.0))
	add_child(_label)


func show_text(text: String) -> void:
	if text.strip_edges().is_empty():
		hide_tooltip()
		return
	if _pending_show and text == _pending_text:
		return
	if visible and text == _last_text:
		return
	if show_delay_seconds <= 0.0:
		_pending_show = false
		_pending_text = ""
		_pending_elapsed_seconds = 0.0
		_show_now(text)
		return
	_pending_text = text
	_pending_elapsed_seconds = 0.0
	_pending_show = true
	visible = false
	_last_mouse_position = Vector2.INF


func _show_now(text: String) -> void:
	if _label == null:
		return
	var was_visible := visible
	if text != _last_text:
		_label.text = text
		var content_size := _fit_label_size(text)
		# Size the panel directly from the measured content plus the panel
		# stylebox's content margins, instead of reset_size() (which reads a
		# minimum size the layout hasn't computed yet on the first hover).
		var panel_style := get_theme_stylebox("panel")
		var chrome := panel_style.get_minimum_size() if panel_style != null else Vector2(16.0, 16.0)
		var panel_size := content_size + chrome
		custom_minimum_size = panel_size
		size = panel_size
		_last_text = text
	visible = true
	if not was_visible:
		_update_position(true)


func hide_tooltip() -> void:
	visible = false
	_pending_show = false
	_pending_text = ""
	_pending_elapsed_seconds = 0.0
	_last_mouse_position = Vector2.INF


func _process(delta: float) -> void:
	if _pending_show:
		_pending_elapsed_seconds += delta
		if _pending_elapsed_seconds >= show_delay_seconds:
			var text := _pending_text
			_pending_show = false
			_pending_text = ""
			_pending_elapsed_seconds = 0.0
			_show_now(text)
	if visible:
		_update_position()


func _update_position(force: bool = false) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	if not force and mouse_position == _last_mouse_position:
		return
	_last_mouse_position = mouse_position
	var viewport_size := get_viewport_rect().size
	var desired := mouse_position + mouse_offset
	var tooltip_size := size
	position = Vector2(
		clampf(desired.x, viewport_margin, maxf(viewport_margin, viewport_size.x - tooltip_size.x - viewport_margin)),
		clampf(desired.y, viewport_margin, maxf(viewport_margin, viewport_size.y - tooltip_size.y - viewport_margin))
	)


## Compute the label's content size directly from the font and return it.
## We size the panel from this rather than relying on the container's
## combined minimum size, which isn't computed until a frame after the text
## changes — that lag is what made the first hover render an empty,
## oversized box.
func _fit_label_size(text: String) -> Vector2:
	if _label == null:
		return Vector2.ZERO
	var font_size := _label.get_theme_font_size("font_size")
	var single_line_width := PIXEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var content_size: Vector2
	if single_line_width <= max_label_width:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		content_size = PIXEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var wrap_width := maxf(1.0, max_label_width)
		var multiline := PIXEL_FONT.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, font_size
		)
		content_size = Vector2(wrap_width, multiline.y)
	content_size = Vector2(ceilf(content_size.x), ceilf(content_size.y))
	_label.custom_minimum_size = content_size
	return content_size
