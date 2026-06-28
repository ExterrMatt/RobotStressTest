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
	var was_visible := visible
	if _label != null:
		if text != _last_text:
			var previous_position := position
			_label.text = text
			_fit_label_size(text)
			reset_size()
			if was_visible:
				position = previous_position
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
	var tooltip_size := get_combined_minimum_size()
	position = Vector2(
		clampf(desired.x, viewport_margin, maxf(viewport_margin, viewport_size.x - tooltip_size.x - viewport_margin)),
		clampf(desired.y, viewport_margin, maxf(viewport_margin, viewport_size.y - tooltip_size.y - viewport_margin))
	)


func _fit_label_size(text: String) -> void:
	if _label == null:
		return
	var font_size := _label.get_theme_font_size("font_size")
	var text_width := PIXEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var label_width := minf(ceilf(text_width), maxf(1.0, max_label_width))
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF if text_width <= max_label_width else TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(label_width, 0.0)
