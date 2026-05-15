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

# ---- TUNABLES (visible in the editor) -----------------------------------

## Characters per second when typing normally. Higher = faster.
## A comfortable reading speed for English prose sits around 35-50.
@export_range(5.0, 200.0, 1.0) var chars_per_second: float = 40.0

## How much SHIFT speeds up the typewriter. 3.0 = three times faster.
@export_range(1.0, 10.0, 0.1) var fast_forward_multiplier: float = 3.0

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

## One-shot font size override consumed by the next play_pages call.
## Set by play_pages_autosized so the chosen size survives play_pages'
## normal reset-to-configured-size step.
var _next_font_size: int = 0

# Node refs (resolved in _ready).
@onready var _rich_label: RichTextLabel = $Margin/Label
@onready var _arrow: Control = $AdvanceArrow
@onready var _arrow_label: Label = $AdvanceArrow/ArrowLabel
@onready var _arrow_tex: TextureRect = $AdvanceArrow/ArrowTexture


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
	if size_to_use > 0:
		_apply_font_size(size_to_use)
	_pages = pages
	_page_index = 0
	_active = true
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
) -> void:
	if pages.is_empty():
		_active = false
		call_deferred("emit_signal", "finished")
		return
	_next_font_size = _pick_largest_fitting_size(pages, candidates, max_rows)
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
		# Estimate: panel width minus the Margin's left+right (18+18 in the .tscn).
		avail = max(1.0, size.x - 36.0)

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
	if not _active or not _is_typing:
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
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance_click()
			accept_event()


# ---- Internal ------------------------------------------------------------

func _show_page(idx: int) -> void:
	var page: Array = _pages[idx]
	# Join lines on this page with line breaks. Each line is its own visual line.
	_full_page_text = "\n".join(page)

	_rich_label.bbcode_enabled = true
	if line_height_factor > 0.0 and _full_page_text.contains("\n"):
		var current_size: int = _rich_label.get_theme_font_size("normal_font_size")
		if current_size <= 0:
			current_size = font_size if font_size > 0 else 22
		var lh: int = int(round(current_size * line_height_factor))
		_rich_label.text = "[p line_height=%d]%s[/p]" % [lh, _full_page_text]
	else:
		_rich_label.text = _full_page_text
	# Reveal nothing yet; we'll bump visible_characters with the typewriter.
	_rich_label.visible_characters = 0

	_is_typing = true
	_typing_timer = 0.0
	_set_arrow_visible(false)
	page_advanced.emit(idx)


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
		_set_arrow_visible(false)
		finished.emit()
		return
	_show_page(_page_index)


func _set_arrow_visible(v: bool) -> void:
	_arrow.visible = v
