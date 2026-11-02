extends Node
## Keeps text sharp wherever the game draws it scaled up.
##
## Godot rasterizes a font at its font size times the window's stretch and draws those
## glyphs. When a scene scales a Control up on top of that (scene canvases, camera zooms,
## the laptop screen, minigame boards), the glyphs are just stretched, so the text comes out
## soft and blocky. This watches every text control and, while one is drawn at a different
## scale from the window's own, gives it a copy of its font oversampled to that scale (one
## copy shared by everything at about the same scale), so its glyphs are rasterized at the
## size they really appear. Back at the normal scale it gets its own font back.
##
## Text drawn by hand (draw_string) gets the same through font_for(item, font).

## How often scales are re-checked (zooms re-rasterize at most this often).
const CHECK_SECONDS: float = 0.1
## Scales are rounded to steps of this ratio, so things at nearly the same scale share one
## copy and a zoom only re-rasterizes every few percent.
const SCALE_STEP_RATIO: float = 1.03
## Within this ratio of the window's own scale, text is left to draw as normal.
const NORMAL_TOLERANCE: float = 0.03
## Above this ratio to the window's scale, glyphs are placed to the quarter pixel, which keeps
## the letter spacing even once it's blown up.
const QUARTER_PIXEL_RATIO: float = 1.15
const SCALE_RANGE: Vector2 = Vector2(0.25, 12.0)
## Copies nothing has asked for in this long are let go (anything still using one keeps it).
const UNUSED_COPY_SECONDS: float = 10.0
## The font theme items each kind of text control draws with (anything else: "font").
const RICH_TEXT_ITEMS: Array[String] = ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]
const FONT_ITEMS: Array[String] = ["font"]
## Per control: {item: true if it had its own font override before a copy replaced it}.
const META_ORIGINAL: StringName = &"_crisp_text_original"
## On each copy: the font it was made from.
const META_BASE: StringName = &"_crisp_text_base"

## Text controls being watched, by instance id.
var _controls: Dictionary = {}
## Controls just added, sorted out on the next frame rather than the next check, so new text
## never shows soft first.
var _pending: Array = []
## Custom-drawn items from font_for, by instance id: [item, step it was last drawn at].
var _drawers: Dictionary = {}
## Font copies by "base id:step" (null for fonts that can't be copied), and when each was
## last asked for.
var _copies: Dictionary = {}
var _last_used: Dictionary = {}
var _wait: float = 0.0
var _now: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


func _scan(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit or node is TextEdit \
			or node is RichTextLabel or node is ItemList or node is Tree or node is TabBar \
			or node is ProgressBar or node is LinkButton:
		_controls[node.get_instance_id()] = node
		_pending.append(node)


func _process(delta: float) -> void:
	_now += delta
	_wait -= delta
	var root := get_tree().root
	var normal := _normal_scale()
	for node in _pending:
		if is_instance_valid(node) and node.is_inside_tree() and node.get_viewport() == root:
			_update_control(node, _screen_scale(node), normal)
	_pending.clear()
	if _wait > 0.0:
		return
	_wait = CHECK_SECONDS
	for id in _controls.keys():
		var c: Control = _controls[id] if is_instance_valid(_controls[id]) else null
		if c == null or not c.is_inside_tree():
			_controls.erase(id)
			continue
		# Text inside a SubViewport is drawn to a texture; its final size isn't known here.
		if not c.is_visible_in_tree() or c.get_viewport() != root:
			continue
		_update_control(c, _screen_scale(c), normal)
	for id in _drawers.keys():
		var entry: Array = _drawers[id]
		var item: CanvasItem = entry[0] if is_instance_valid(entry[0]) else null
		if item == null or not item.is_inside_tree():
			_drawers.erase(id)
			continue
		if item.is_visible_in_tree() and _step(_screen_scale(item), normal) != int(entry[1]):
			item.queue_redraw()
	for key in _last_used.keys():
		if _now - float(_last_used[key]) > UNUSED_COPY_SECONDS:
			_last_used.erase(key)
			_copies.erase(key)


## The crisp copy of `font` for text `item` draws by hand, at the scale `item` is drawn at
## (or `font` itself at the normal scale). Call it from `item`'s _draw: `item` is redrawn
## whenever its scale moves on enough to need a different copy.
func font_for(item: CanvasItem, font: Font) -> Font:
	if item == null or font == null or not item.is_inside_tree():
		return font
	var normal := _normal_scale()
	var step := _step(_screen_scale(item), normal)
	_drawers[item.get_instance_id()] = [item, step]
	if step == _step(normal, normal):
		return font
	var copy := _copy(_base_of(font), step, normal)
	return copy if copy != null else font


# =============================================================================
# CONTROLS
# =============================================================================

func _update_control(c: Control, scale: float, normal: float) -> void:
	var at_normal := absf(scale / normal - 1.0) <= NORMAL_TOLERANCE
	var original: Dictionary = c.get_meta(META_ORIGINAL, {})
	if at_normal and original.is_empty():
		return
	var step := _step(scale, normal)
	for item in (RICH_TEXT_ITEMS if c is RichTextLabel else FONT_ITEMS):
		var current: Font = c.get_theme_font(item) if c.has_theme_font_override(item) else null
		var ours := current != null and current.has_meta(META_BASE)
		if at_normal:
			if ours:
				_restore(c, item, original)
			else:
				original.erase(item)
			continue
		# The font to copy: its own override, or the theme's (unless that's one of ours).
		var base: Font = _base_of(current) if current != null else c.get_theme_font(item)
		if base == null:
			continue
		var copy := _copy(base, step, normal)
		if copy == null or copy == current:
			continue
		if not ours:
			original[item] = current != null
		c.add_theme_font_override(item, copy)
	if original.is_empty():
		c.remove_meta(META_ORIGINAL)
	else:
		c.set_meta(META_ORIGINAL, original)


## Puts back the font `item` had before a copy replaced it.
func _restore(c: Control, item: String, original: Dictionary) -> void:
	var current := c.get_theme_font(item)
	if bool(original.get(item, false)):
		c.add_theme_font_override(item, _base_of(current))
	else:
		c.remove_theme_font_override(item)
	original.erase(item)


# =============================================================================
# FONTS
# =============================================================================

## The window's own scale (its stretch), which fonts are already rasterized at.
func _normal_scale() -> float:
	return maxf(0.01, get_tree().root.get_final_transform().get_scale().x)


## How big `item` really appears: its own and its parents' scale, the canvas (layer, camera)
## and the window's stretch.
func _screen_scale(item: CanvasItem) -> float:
	var s := item.get_global_transform_with_canvas().get_scale().abs()
	return clampf(maxf(s.x, s.y) * _normal_scale(), SCALE_RANGE.x, SCALE_RANGE.y)


func _step(scale: float, _normal: float) -> int:
	return roundi(log(scale) / log(SCALE_STEP_RATIO))


func _base_of(font: Font) -> Font:
	return font.get_meta(META_BASE) if font != null and font.has_meta(META_BASE) else font


## The copy of `base` rasterized for scale step `step` (made on first use).
func _copy(base: Font, step: int, normal: float) -> Font:
	var key := "%d:%d" % [base.get_instance_id(), step]
	_last_used[key] = _now
	if _copies.has(key):
		return _copies[key]
	var copy := _make_copy(base, pow(SCALE_STEP_RATIO, step), normal)
	_copies[key] = copy
	return copy


func _make_copy(base: Font, scale: float, normal: float) -> Font:
	var copy: Font = null
	if base is FontFile:
		var file := (base as FontFile).duplicate() as FontFile
		file.oversampling = scale
		if scale / normal > QUARTER_PIXEL_RATIO:
			file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
		copy = file
	elif base is FontVariation and (base as FontVariation).base_font != null:
		var inner := _make_copy((base as FontVariation).base_font, scale, normal)
		if inner == null:
			return null
		var variation := (base as FontVariation).duplicate() as FontVariation
		variation.base_font = inner
		copy = variation
	else:
		return null
	copy.set_meta(META_BASE, base)
	return copy
