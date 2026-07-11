extends PanelContainer
class_name DialogueBox
## Reusable dialogue box.
##
## Capabilities:
##   - Fixed height (box_height) so it never balloons.
##   - Typewriter effect: characters reveal one-by-one.
##   - Click anywhere on the box to advance:
##       * mid-typewriter   -> instantly complete the current page.
##       * page complete    -> advance to the next page, or emit `finished`
##                             if there are no more pages.
##   - Hold SHIFT to type 3x faster (the `fast_forward_multiplier` is tunable).
##   - Arrow indicator (▼) appears when the current page is fully revealed.
##     Drop a pixel-art texture into the AdvanceArrow node to replace the
##     placeholder glyph.
##
## Typical use from a location script:
##     dialogue_box.finished.connect(_on_dialogue_done)
##     dialogue_box.play_pages(Dialogue.get_pages("school", "science.atom.lecture"))
##
## Or with formatting placeholders:
##     dialogue_box.play_pages(
##         Dialogue.get_pages("school", "feedback.wrong", {"name": "Ms. Okorie",
##                                                          "correct": "Oxygen"})
##     )

signal finished                  ## emitted after the last page is dismissed
signal page_advanced(index: int) ## emitted whenever a new page starts

const THOUGHT_COLOR: String = "#808080"
const LINE_SEPARATION_NO_OVERRIDE: int = -1000000
const SPEAKER_COLORS: Dictionary = {
	"Uncle": "#40a1dd",
	"Ms. Vey": "#f87031",
	"Ms Vey": "#f87031",
	"Ms. Okorie": "#f87031",
	"Ms Okorie": "#f87031",
	"Mr. Caldera": "#f87031",
	"Mr Caldera": "#f87031",
	"Her": "#b7d6d8",
	"Robot": "#b7d6d8",
	"You": "#e4b22d",
	"Ed": "#6b5f2a",
	"DRONE": "#e0574a",
}

# ---- TUNABLES (visible in the editor) -----------------------------------

## Characters per second when typing normally. Higher = faster.
## A comfortable reading speed for English prose sits around 35-50.
@export_range(5.0, 200.0, 1.0) var chars_per_second: float = 40.0

## How much SHIFT speeds up the typewriter. 3.0 = three times faster.
@export_range(1.0, 10.0, 0.1) var fast_forward_multiplier: float = 3.0

## Holding the advance button this long starts debug-skip mode.
@export_range(0.1, 3.0, 0.1) var hold_skip_delay_seconds: float = 1.0

## Pages advanced per second after hold-skip starts.
@export_range(1.0, 60.0, 0.5) var hold_skip_pages_per_second: float = 9.5

## Pause (seconds) inserted at sentence-ending punctuation for natural rhythm.
## Set to 0 to disable.
@export_range(0.0, 1.0, 0.01) var sentence_pause: float = 0.15

## Pause (seconds) inserted at commas / semicolons / colons.
@export_range(0.0, 0.5, 0.01) var comma_pause: float = 0.05

## Font size for the dialogue text. Applies to plain, italic, bold, and
## bold-italic runs so [i]...[/i] segments don't fall back to a default size.
## Set to <= 0 to defer to whatever the Label has set in the inspector.
@export_range(0, 96, 1) var font_size: int = 22

## When > 0, wraps each page in [p line_height=...] using this value as a
## multiplier on the current font size. 1.0 = lines packed tight (top and
## bottom of glyphs nearly touching); 1.2 = comfortable reading default;
## 1.4+ = airy. Set to 0 to disable and let the font's natural line height
## decide. Useful for autosized prompts where the default spacing makes
## a 2-row line spill outside box_height.
@export_range(0.0, 2.0, 0.05) var line_height_factor: float = 0.95

## Fixed height of the dialogue area. The box stays this tall regardless
## of how short the current line is - that way it doesn't visually jitter
## between sentences. Tune so the longest line you write fits comfortably.
@export var box_height: int = 140

## Optional: a Texture2D to use for the "page is ready, click to continue"
## arrow. If null, a Unicode glyph is shown instead so the system works
## out-of-the-box. Drop your pixel-art arrow here in the editor.
@export var advance_arrow_texture: Texture2D = null

# ---- INTERNAL STATE -----------------------------------------------------

var _pages: Array = []     # Array[Array[String]] currently being shown
var _page_index: int = 0
var _full_page_text: String = ""  # the BBCode text for the current page

## Are we currently inside an active play_pages run?
var _active: bool = false

## Wait between characters in seconds (kept as 1.0/chars_per_second).
var _typing_timer: float = 0.0
var _is_typing: bool = false
var _shift_held: bool = false
var _advance_held: bool = false
var _advance_hold_seconds: float = 0.0
var _hold_skip_timer: float = 0.0

## When true, the next play_pages call skips restoring the debug enter-hold
## from currently-pressed keys. Set by callers (e.g. the name prompt) that
## trigger playback from an Enter press which should act as a single click,
## not seed a debug hold-skip that would eat the first line.
var _suppress_next_enter_hold: bool = false

## One-shot font size override consumed by the next play_pages call.
## Set by play_pages_autosized so the chosen size survives play_pages'
## normal reset-to-configured-size step.
var _next_font_size: int = 0
var _next_line_height_factor: float = -1.0
var _active_line_height_factor: float = -1.0
var _next_line_separation: int = LINE_SEPARATION_NO_OVERRIDE
var _active_line_separation: int = LINE_SEPARATION_NO_OVERRIDE

# Node refs (resolved in _ready).
@onready var _rich_label: RichTextLabel = $InnerFrame/Margin/Label
@onready var _arrow: Control = $InnerFrame/AdvanceArrow
@onready var _arrow_label: Label = $InnerFrame/AdvanceArrow/ArrowLabel
@onready var _arrow_tex: TextureRect = $InnerFrame/AdvanceArrow/ArrowTexture


func _ready() -> void:
	# Bound the box to a stable size. box_height is treated as the fixed
	# height of the dialogue area: long enough for the longest line we
	# expect, short enough not to dominate the screen.
	custom_minimum_size = Vector2(0, box_height)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# Apply the font size to ALL four RichTextLabel font slots. Without
	# this, [i]...[/i] and [b]...[/b] runs fall back to a built-in default
	# size and the dialogue ends up mixing two sizes.
	if font_size > 0:
		_apply_font_size(font_size)

	# Hide the arrow until the first page is done typing.
	_set_arrow_visible(false)

	# Apply the advance-arrow texture if provided in the editor.
	if advance_arrow_texture:
		_arrow_tex.texture = advance_arrow_texture
		_arrow_tex.visible = true
		_arrow_label.visible = false

	# Catch clicks on the panel; the label has mouse_filter=IGNORE so clicks
	# pass through to us.
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Start playing a list of pages. Each page is Array[String] - the lines on
## that page. The lines are joined into one BBCode string per page (one click
## advances pages, not individual lines).
func play_pages(pages: Array) -> void:
	if pages.is_empty():
		# Nothing to show - emit finished on the next frame so callers can
		# connect after this call without missing the signal.
		_active = false
		call_deferred("emit_signal", "finished")
		return
	# Decide what font size to use for this playback.
	# - If a caller set a one-shot override (via play_pages_autosized), honor
	#   it and consume the override so subsequent calls revert.
	# - Otherwise fall back to the configured @export font_size.
	var size_to_use: int = _next_font_size if _next_font_size > 0 else font_size
	_next_font_size = 0
	_active_line_height_factor = _next_line_height_factor
	_next_line_height_factor = -1.0
	_active_line_separation = _next_line_separation
	_next_line_separation = LINE_SEPARATION_NO_OVERRIDE
	if size_to_use > 0:
		_apply_font_size(size_to_use)
	_pages = pages
	_page_index = 0
	_active = true
	_reset_advance_hold()
	_restore_enter_hold_from_current_input()
	_show_page(0)


## Convenience: play a single string as one page with one line.
func play_text(text: String) -> void:
	play_pages([[text]])


## Play `pages` after picking the largest size from `candidates` (high-to-low)
## whose rendered text fits in `max_rows` visual rows at the box's current
## width. Useful for prompt lines you want to be as eye-catching as possible
## without overflowing.
##
##   pages:      same shape as play_pages - Array[Array[String]].
##   candidates: list of font sizes to try, IN DESCENDING ORDER. The first
##               one that fits wins. If none fit, the smallest is used anyway.
##   max_rows:   maximum visual row count for any one page. Default 2.
##
## The chosen size applies to this playback only. The next play_pages /
## play_text call returns to the configured `font_size`.
func play_pages_autosized(
	pages: Array,
	candidates: Array = [42, 36, 28, 24],
	max_rows: int = 2,
	line_height_override: float = -1.0,
	line_separation_override: int = LINE_SEPARATION_NO_OVERRIDE,
) -> void:
	if pages.is_empty():
		_active = false
		call_deferred("emit_signal", "finished")
		return
	_next_font_size = _pick_largest_fitting_size(pages, candidates, max_rows)
	_next_line_height_factor = line_height_override
	_next_line_separation = line_separation_override
	play_pages(pages)


## Pick the largest size in `candidates` for which every page fits within
## `max_rows` lines at the label's current width. Falls back to the last
## (smallest) candidate if none qualify.
func _pick_largest_fitting_size(pages: Array, candidates: Array, max_rows: int) -> int:
	# We need the label's available width. Use the resolved size if layout
	# has run; otherwise fall back to the panel's current width minus margins.
	var avail: float = _rich_label.size.x
	if avail <= 0.0:
		# Layout hasn't happened yet (called from _ready or before a frame).
		# Estimate: panel width minus the ornate inner frame padding (26+26)
		# plus the Margin's left+right (2+2) in the .tscn.
		avail = max(1.0, size.x - 56.0)

	for s_var in candidates:
		var s: int = int(s_var)
		if _all_pages_fit(pages, s, avail, max_rows):
			return s
	# Nothing fit - return the smallest candidate so we at least try.
	return int(candidates[candidates.size() - 1]) if not candidates.is_empty() else font_size


func _all_pages_fit(pages: Array, size_px: int, width: float, max_rows: int) -> bool:
	var font: Font = _rich_label.get_theme_default_font()
	if font == null:
		# Should never happen, but be defensive.
		return true
	for page in pages:
		# Strip BBCode tags so we measure the visible text, not the markup.
		var visible_text: String = _strip_bbcode("\n".join(page))
		var measured: Vector2 = font.get_multiline_string_size(
			visible_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			width,
			size_px,
		)
		# get_multiline_string_size returns total height across wrapped rows.
		# Divide by line height to get an approximate row count.
		var line_height: float = font.get_height(size_px)
		var rows: int = int(ceil(measured.y / max(1.0, line_height)))
		if rows > max_rows:
			return false
	return true


## Strip BBCode tags from a string so we can measure raw visible text.
## Doesn't handle every edge case (nested unclosed tags etc.) but is fine
## for our short prompt lines.
func _strip_bbcode(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\[[^\\]]*\\]")
	return re.sub(text, "", true)


## Apply a font size to all four font slots, runtime-overriding the @export.
func _apply_font_size(size_px: int) -> void:
	if size_px <= 0:
		return
	_rich_label.add_theme_font_size_override("normal_font_size", size_px)
	_rich_label.add_theme_font_size_override("italics_font_size", size_px)
	_rich_label.add_theme_font_size_override("bold_font_size", size_px)
	_rich_label.add_theme_font_size_override("bold_italics_font_size", size_px)
	_rich_label.add_theme_font_size_override("mono_font_size", size_px)


func _process(delta: float) -> void:
	if not _active:
		return
	_update_hold_skip(delta)
	if not _is_typing:
		return
	# Poll shift directly - more reliable than relying on key events being
	# delivered to a non-focused panel.
	_shift_held = Input.is_key_pressed(KEY_SHIFT)

	var char_interval: float = 1.0 / max(1.0, chars_per_second)
	var effective: float = char_interval
	if _shift_held:
		effective /= max(0.001, fast_forward_multiplier)

	_typing_timer -= delta
	while _typing_timer <= 0.0 and _is_typing:
		var advanced: bool = _advance_one_visible_char()
		if not advanced:
			break
		# Stack a punctuation pause if we just revealed punctuation.
		var extra: float = _punctuation_pause_for_last_revealed()
		if _shift_held:
			extra /= max(0.001, fast_forward_multiplier)
		_typing_timer += effective + extra


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_advance_hold()
			_advance_click()
			accept_event()
			return
		_end_advance_hold()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.echo:
		return
	if key_event.keycode != KEY_ENTER and key_event.keycode != KEY_KP_ENTER:
		return
	if key_event.pressed:
		_begin_advance_hold()
		_advance_click()
	else:
		_end_advance_hold()
	get_viewport().set_input_as_handled()


# ---- Internal ------------------------------------------------------------

func _show_page(idx: int) -> void:
	var page: Array = _pages[idx]
	# Join lines on this page with line breaks. Each line is its own visual line.
	_full_page_text = "\n".join(_format_dialogue_page(page))

	_rich_label.bbcode_enabled = true
	if _active_line_separation != LINE_SEPARATION_NO_OVERRIDE:
		_rich_label.add_theme_constant_override("line_separation", _active_line_separation)
	else:
		_rich_label.remove_theme_constant_override("line_separation")
	var effective_line_height_factor: float = (
		_active_line_height_factor if _active_line_height_factor > 0.0 else line_height_factor
	)
	if effective_line_height_factor > 0.0 and (_full_page_text.contains("\n") or _active_line_height_factor > 0.0):
		var current_size: int = _rich_label.get_theme_font_size("normal_font_size")
		if current_size <= 0:
			current_size = font_size if font_size > 0 else 22
		var lh: int = int(round(current_size * effective_line_height_factor))
		_rich_label.text = "[p line_height=%d]%s[/p]" % [lh, _full_page_text]
	else:
		_rich_label.text = _full_page_text
	# Reveal nothing yet; we'll bump visible_characters with the typewriter.
	_rich_label.visible_characters = 0

	_is_typing = true
	_typing_timer = 0.0
	_set_arrow_visible(false)
	page_advanced.emit(idx)


func _format_dialogue_page(page: Array) -> Array[String]:
	var formatted: Array[String] = []
	for raw_line in page:
		formatted.append(_format_dialogue_line(String(raw_line)))
	return formatted


func _format_dialogue_line(line: String) -> String:
	var stripped := line.strip_edges()
	var leading_tags := _leading_bbcode_tags(stripped)
	var content_start := stripped.substr(leading_tags.length()).strip_edges()
	var lower := content_start.to_lower()
	for thought_prefix in ["thought:", "thoughts:"]:
		if lower.begins_with(thought_prefix):
			return _color_dialogue_text(
				leading_tags + content_start.substr(thought_prefix.length()).strip_edges(),
				THOUGHT_COLOR
			)

	var colon_index := content_start.find(":")
	if colon_index <= 0:
		return line
	var speaker := content_start.substr(0, colon_index).strip_edges()
	if not SPEAKER_COLORS.has(speaker):
		return line
	var speaker_prefix := content_start.substr(0, colon_index + 1)
	var speech := content_start.substr(colon_index + 1)
	return leading_tags + speaker_prefix + _color_dialogue_text(speech, String(SPEAKER_COLORS[speaker]))


func _color_dialogue_text(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


func _leading_bbcode_tags(text: String) -> String:
	var tags := ""
	var cursor := 0
	while cursor < text.length() and text.substr(cursor, 1) == "[":
		var close := text.find("]", cursor)
		if close < 0:
			break
		var tag := text.substr(cursor, close - cursor + 1)
		if tag.begins_with("[/"):
			break
		tags += tag
		cursor = close + 1
	return tags


## Reveals one more character. Returns true if a character was revealed,
## false if the page is fully visible.
func _advance_one_visible_char() -> bool:
	var total: int = _rich_label.get_total_character_count()
	if _rich_label.visible_characters >= total:
		_finish_typing()
		return false
	_rich_label.visible_characters = _rich_label.visible_characters + 1
	return true


## Inspect the character that was just revealed and return an extra delay
## for natural pacing. Cheap and approximate; doesn't account for BBCode tags
## (RichTextLabel's visible_characters is content-only, so this works).
func _punctuation_pause_for_last_revealed() -> float:
	var pos: int = _rich_label.visible_characters - 1
	var text: String = _rich_label.get_parsed_text()
	if pos < 0 or pos >= text.length():
		return 0.0
	var ch: String = text.substr(pos, 1)
	match ch:
		".", "!", "?":
			return sentence_pause
		",", ";", ":":
			return comma_pause
		_:
			return 0.0


func _finish_typing() -> void:
	_is_typing = false
	_rich_label.visible_characters = -1  # show all
	_set_arrow_visible(true)


func _advance_click() -> void:
	if not _active:
		return
	if _is_typing:
		# Instantly complete current page.
		_finish_typing()
		return
	# Page is done - go to next page or finish.
	_page_index += 1
	if _page_index >= _pages.size():
		_active = false
		_reset_advance_hold()
		_set_arrow_visible(false)
		finished.emit()
		return
	_show_page(_page_index)


func _begin_advance_hold() -> void:
	_advance_held = true
	_advance_hold_seconds = 0.0
	_hold_skip_timer = 0.0


func _end_advance_hold() -> void:
	_reset_advance_hold()


func _reset_advance_hold() -> void:
	_advance_held = false
	_advance_hold_seconds = 0.0
	_hold_skip_timer = 0.0


func _debug_mode_enabled() -> bool:
	var settings := get_node_or_null("/root/GameState")
	return settings != null and settings.debug_mode_enabled


## Suppress the debug enter-hold carry-over for the next play_pages call. Use
## this when playback is kicked off by an Enter press that should count as a
## single "click continue" rather than the start of a held debug skip.
func suppress_next_enter_hold() -> void:
	_suppress_next_enter_hold = true


func _restore_enter_hold_from_current_input() -> void:
	if _suppress_next_enter_hold:
		_suppress_next_enter_hold = false
		return
	if not _debug_mode_enabled():
		return
	if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
		_advance_held = true
		_advance_hold_seconds = hold_skip_delay_seconds
		_hold_skip_timer = 0.0


func _update_hold_skip(delta: float) -> void:
	if not _advance_held:
		return
	if not _debug_mode_enabled():
		_reset_advance_hold()
		return
	_advance_hold_seconds += delta
	if _advance_hold_seconds < hold_skip_delay_seconds:
		return
	if _is_typing:
		_finish_typing()
	_hold_skip_timer -= delta
	var interval := 1.0 / maxf(1.0, hold_skip_pages_per_second)
	while _active and not _is_typing and _hold_skip_timer <= 0.0:
		_advance_click()
		_hold_skip_timer += interval


func _set_arrow_visible(v: bool) -> void:
	_arrow.visible = v

## Hide the click-to-advance arrow. Useful when an external timer auto-
## advances the dialog so the arrow doesn't sit there inviting a click
## that does nothing.
func hide_advance_arrow() -> void:
	_set_arrow_visible(false)
