class_name MouseFollowTooltip
extends Control

const PIXEL_FONT: FontFile = preload("res://assets/fonts/Jersey10-Regular.ttf")

## Inner padding between the panel border and the text, on every side.
const CONTENT_MARGIN: float = 8.0

@export var mouse_offset: Vector2 = Vector2(18.0, 18.0)
@export var viewport_margin: float = 8.0
@export var max_label_width: float = 320.0
@export var show_delay_seconds: float = 1.5

var _panel: Panel = null
var _label: Label = null
var _last_text: String = ""
var _last_mouse_position: Vector2 = Vector2.INF
var _pending_text: String = ""
var _pending_elapsed_seconds: float = 0.0
var _pending_show: bool = false


## We extend plain Control (not PanelContainer) and lay the background +
## label out by hand. A PanelContainer auto-sizes to its child's minimum
## size, and an autowrap Label's minimum size isn't known until a frame
## after its text changes — so the first hover rendered an empty/oversized
## box that only corrected once the layout warmed up. Manual layout makes
## the size we compute the size that's drawn, on the very first hover.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 4096

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.035, 0.05, 0.88)
	style.border_color = Color(0.85, 0.78, 0.42, 0.95)
	style.set_border_width_all(2)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.position = Vector2(CONTENT_MARGIN, CONTENT_MARGIN)
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
		var content_size := _apply_label_text(text)
		var panel_size := content_size + Vector2(CONTENT_MARGIN, CONTENT_MARGIN) * 2.0
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


## Word-wrap the text, assign it to the label (autowrap off, so its size is
## width-independent and deterministic), size the label to fit, and return
## the content size. Measured directly from the font, so it's correct in the
## same frame the text is set.
func _apply_label_text(text: String) -> Vector2:
	var font_size := _label.get_theme_font_size("font_size")
	var wrapped := _wrap_text(text, font_size, maxf(1.0, max_label_width))
	_label.text = wrapped
	# width = -1 measures the block honoring only the explicit "\n" breaks.
	var block := PIXEL_FONT.get_multiline_string_size(
		wrapped, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	)
	var content_size := Vector2(ceilf(block.x), ceilf(block.y))
	_label.size = content_size
	_label.position = Vector2(CONTENT_MARGIN, CONTENT_MARGIN)
	return content_size


## Greedy word-wrap to a max pixel width, returning the text with "\n"
## inserted between lines. A single word wider than max_width gets its own
## line (never split mid-word).
func _wrap_text(text: String, font_size: int, max_width: float) -> String:
	var words := text.split(" ", false)
	var lines: PackedStringArray = []
	var current := ""
	for word in words:
		var candidate := word if current.is_empty() else current + " " + word
		var candidate_width := PIXEL_FONT.get_string_size(
			candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
		).x
		if current.is_empty() or candidate_width <= max_width:
			current = candidate
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return "\n".join(lines)
