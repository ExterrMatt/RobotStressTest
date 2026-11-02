class_name MouseFollowTooltip
extends Control

const PIXEL_FONT: FontFile = preload("res://assets/fonts/Jersey10-Regular.ttf")

## Inner padding between the panel border and the text, on every side.
const CONTENT_MARGIN: float = 8.0
## Font size used for the tooltip label. A constant (not read back from the
## theme) so measurement never depends on theme propagation timing.
const FONT_SIZE: int = 22

@export var mouse_offset: Vector2 = Vector2(18.0, 18.0)
@export var viewport_margin: float = 8.0
@export var max_label_width: float = 320.0
@export var show_delay_seconds: float = 1.5

var _panel: Panel = null
var _label: Label = null
## Shows the text instead of _label when it has BBCode in it (colours); see show_text.
var _rich_label: RichTextLabel = null
var _last_text: String = ""
var _last_rich: bool = false
var _last_mouse_position: Vector2 = Vector2.INF
var _pending_text: String = ""
var _pending_rich: bool = false
var _pending_elapsed_seconds: float = 0.0
var _pending_show: bool = false
## When it has an area, the tooltip sits centred under this rect (viewport coordinates)
## instead of following the mouse; see show_text.
var _anchor: Rect2 = Rect2()

## Gap between an anchor rect and the tooltip under it.
const ANCHOR_GAP: float = 6.0

## BBCode tags, stripped out to measure a rich tooltip's text.
static var _bbcode_tags: RegEx = null


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
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.74, 1.0))
	add_child(_label)

	_rich_label = RichTextLabel.new()
	_rich_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich_label.bbcode_enabled = true
	_rich_label.scroll_active = false
	_rich_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_rich_label.clip_contents = false
	_rich_label.visible = false
	_rich_label.add_theme_font_override("normal_font", PIXEL_FONT)
	_rich_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_rich_label.add_theme_color_override("default_color", Color(1.0, 0.96, 0.74, 1.0))
	add_child(_rich_label)

	_warm_up_font()


## Force the TextServer to shape/rasterize the font at our display size now,
## before the first hover. The first time a font is measured at a given size
## in a session it can report stale metrics (cold glyph cache), which sized
## the first tooltip's box wrong until a second hover warmed it up — the
## "hover a different button and come back and it's fine" symptom. Touching
## it here makes the first real hover hit a hot cache.
func _warm_up_font() -> void:
	const SAMPLE := "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 .,'!?()-"
	PIXEL_FONT.get_string_size(SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
	PIXEL_FONT.get_multiline_string_size(SAMPLE + "\n" + SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)


## Shows `text` after the delay. With `rich`, it's BBCode (e.g. [color] tags), on one line.
## Given an `anchor` rect (viewport coordinates), it shows centred under that instead of
## following the mouse.
func show_text(text: String, rich: bool = false, anchor: Rect2 = Rect2()) -> void:
	if text.strip_edges().is_empty():
		hide_tooltip()
		return
	_anchor = anchor
	if _pending_show and text == _pending_text and rich == _pending_rich:
		return
	if visible and text == _last_text and rich == _last_rich:
		return
	if show_delay_seconds <= 0.0:
		_pending_show = false
		_pending_text = ""
		_pending_elapsed_seconds = 0.0
		_show_now(text, rich)
		return
	_pending_text = text
	_pending_rich = rich
	_pending_elapsed_seconds = 0.0
	_pending_show = true
	visible = false
	_last_mouse_position = Vector2.INF


func _show_now(text: String, rich: bool = false) -> void:
	if _label == null:
		return
	var was_visible := visible
	if text != _last_text or rich != _last_rich:
		_resize_to_text(text, rich)
		_last_text = text
		_last_rich = rich
		# Safety net: if the font cache was still cold on this first measure
		# (so the box came out the wrong size), re-measuring one frame later
		# hits a hot cache and corrects it. A no-op once the cache is warm.
		call_deferred("_remeasure_if_current", text, rich)
	visible = true
	if not was_visible:
		_update_position(true)


## Measure `text`, then size the label and panel to fit it.
func _resize_to_text(text: String, rich: bool = false) -> void:
	var content_size := _apply_rich_text(text) if rich else _apply_label_text(text)
	var panel_size := content_size + Vector2(CONTENT_MARGIN, CONTENT_MARGIN) * 2.0
	custom_minimum_size = panel_size
	size = panel_size


func _remeasure_if_current(text: String, rich: bool = false) -> void:
	if _last_text != text or _last_rich != rich or not is_instance_valid(self):
		return
	_resize_to_text(text, rich)
	if visible:
		_update_position(true)


## Hides the tooltip only if it's showing (or about to show) `text` - for a caller giving up
## its tooltip without hiding one something else has put up since.
func hide_text(text: String) -> void:
	if (_pending_show and _pending_text == text) or (visible and _last_text == text):
		hide_tooltip()


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
			_show_now(text, _pending_rich)
	if visible:
		_update_position()


func _update_position(force: bool = false) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	if not force and mouse_position == _last_mouse_position:
		return
	_last_mouse_position = mouse_position
	var viewport_size := get_viewport_rect().size
	var tooltip_size := size
	var desired := mouse_position + mouse_offset
	if _anchor.has_area():
		desired = Vector2(_anchor.get_center().x - tooltip_size.x * 0.5, _anchor.end.y + ANCHOR_GAP).round()
	position = Vector2(
		clampf(desired.x, viewport_margin, maxf(viewport_margin, viewport_size.x - tooltip_size.x - viewport_margin)),
		clampf(desired.y, viewport_margin, maxf(viewport_margin, viewport_size.y - tooltip_size.y - viewport_margin))
	)


## Word-wrap the text, assign it to the label (autowrap off, so its size is
## width-independent and deterministic), size the label to fit, and return
## the content size. Measured directly from the font, so it's correct in the
## same frame the text is set.
func _apply_label_text(text: String) -> Vector2:
	_label.visible = true
	_rich_label.visible = false
	var wrapped := _wrap_text(text, FONT_SIZE, maxf(1.0, max_label_width))
	_label.text = wrapped
	# width = -1 measures the block honoring only the explicit "\n" breaks.
	var block := PIXEL_FONT.get_multiline_string_size(
		wrapped, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE
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


## A BBCode tooltip: shown on the rich label, sized by measuring its text with the tags
## stripped (colours don't change the size). One line, never wrapped.
func _apply_rich_text(bbcode: String) -> Vector2:
	_label.visible = false
	_rich_label.visible = true
	if _bbcode_tags == null:
		_bbcode_tags = RegEx.create_from_string("\\[[^\\]]*\\]")
	var plain := _bbcode_tags.sub(bbcode, "", true)
	var block := PIXEL_FONT.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
	var content_size := Vector2(ceilf(block.x) + 1.0, ceilf(PIXEL_FONT.get_height(FONT_SIZE)))
	_rich_label.text = bbcode
	_rich_label.size = content_size
	_rich_label.position = Vector2(CONTENT_MARGIN, CONTENT_MARGIN)
	return content_size
