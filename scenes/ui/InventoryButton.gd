class_name InventoryButton
extends Control
## The "INVENTORY" button in Maintenance's bottom-left corner. It's the laptop bar's
## sibling (see LaptopDragBar): the same pixel lettering - 2px strokes, 7 rows tall,
## with a dark shadow under each stroke - and the same down-arrows bobbing either side,
## but in the gold HUD buttons' palette (the LEAVE / END button: gold border, dark navy
## fill, light text, all brightening on hover). Drawn at ART_SCALE, laid out on its own
## small canvas. A click emits `pressed`, and so does a downward swipe onto it, like the
## laptop bar's - after which the cursor has to leave before a swipe can fire again, so
## one swipe never opens and closes in one go.

signal pressed

## Screen pixels per art pixel: the laptop bar's, so the lettering matches it.
const ART_SCALE: float = 3.0
## Laid out like the laptop bar: a 1px border, then arrow, word, arrow with this much
## room around them (art pixels).
const PAD: int = 4
const GAP: int = 4
const LETTER_GAP: int = 2
## The arrows sink up to BOB_PIXELS art pixels and come back every BOB_SECONDS, in step
## with the laptop bar's.
const BOB_PIXELS: float = LaptopDragBar.BOB_PIXELS
const BOB_SECONDS: float = LaptopDragBar.BOB_SECONDS

## The gold HUD button palette (themes/main_theme.tres, GoldHudButton / Button).
const BORDER_COLOR := Color(0.725, 0.604, 0.306)
const BORDER_HOVER_COLOR := Color(0.788, 0.663, 0.416)
const FILL_COLOR := Color(0.059, 0.071, 0.118, 0.85)
const FILL_HOVER_COLOR := Color(0.118, 0.141, 0.235, 0.92)
const FILL_PRESSED_COLOR := Color(0.118, 0.141, 0.235, 0.98)
const TEXT_COLOR := Color(0.878, 0.894, 0.941)
const TEXT_HOVER_COLOR := Color(1, 1, 1)
## The laptop lettering's shadow.
const SHADOW_COLOR := Color8(41, 41, 46)

const WORD: String = "INVENTORY"
## The letters, 6 x 7, in the laptop bar's hand: "#" is a stroke pixel (the shadow is
## added under every stroke).
const GLYPHS: Dictionary = {
	"I": ["######", "######", "..##..", "..##..", "..##..", "######", "######"],
	"N": ["##..##", "###.##", "######", "######", "##.###", "##..##", "##..##"],
	"V": ["##..##", "##..##", "##..##", "##..##", ".####.", ".####.", "..##.."],
	"E": ["######", "######", "##....", "#####.", "##....", "######", "######"],
	"T": ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##.."],
	"O": [".####.", "######", "##..##", "##..##", "##..##", "######", ".####."],
	"R": ["#####.", "######", "##..##", "######", "#####.", "##.##.", "##..##"],
	"Y": ["##..##", "##..##", "######", ".####.", "..##..", "..##..", "..##.."],
}
## The laptop bar's down-arrow, stroke pixels ("s" is drawn in the shadow colour).
const ARROW: Array[String] = ["##......##", "###....###", "s###..###s", ".s######s.", "..s####s..", "...s##s...", "....ss...."]
const GLYPH_HEIGHT: int = 7
const ROWS: int = 20
## The frame's rows on that canvas: the laptop bar's background (rows 1-18 of its 20), so
## the two sit at exactly the same height side by side.
const BOX_TOP: int = 1
const BOX_HEIGHT: int = 18

var _hovered: bool = false
var _pressed_down: bool = false
## False after a swipe fires, until the cursor leaves the button.
var _swipe_armed: bool = true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size = canvas_size() * ART_SCALE
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_pressed_down = false
		_swipe_armed = true
	)


## The button's art size: border, padding, arrow, word, arrow.
func canvas_size() -> Vector2:
	var word_width := WORD.length() * 6 + (WORD.length() - 1) * LETTER_GAP
	return Vector2(1 + PAD + ARROW[0].length() + GAP + word_width + GAP + ARROW[0].length() + PAD + 1, ROWS)


## The drawn frame, in this control's pixels.
func _box_rect() -> Rect2:
	return Rect2(Vector2(0, BOX_TOP) * ART_SCALE, Vector2(canvas_size().x, BOX_HEIGHT) * ART_SCALE)


## Only the frame takes the mouse.
func _has_point(point: Vector2) -> bool:
	return _box_rect().has_point(point)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if motion.relative.y > 0.0 and _swipe_armed:
			_swipe_armed = false
			pressed.emit()
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.pressed:
		_pressed_down = true
	elif _pressed_down:
		_pressed_down = false
		pressed.emit()
	accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var canvas := canvas_size()
	var lit := _hovered or _pressed_down
	var fill := FILL_PRESSED_COLOR if _pressed_down else (FILL_HOVER_COLOR if _hovered else FILL_COLOR)
	var border := BORDER_HOVER_COLOR if lit else BORDER_COLOR
	var text := TEXT_HOVER_COLOR if lit else TEXT_COLOR
	var box := _box_rect()
	draw_rect(box, fill)
	draw_rect(box.grow(-ART_SCALE * 0.5), border, false, ART_SCALE)

	var bob := roundf(BOB_PIXELS * (0.5 - 0.5 * cos(TAU * fmod(Time.get_ticks_msec() / 1000.0, BOB_SECONDS) / BOB_SECONDS)))
	var arrow_y := 7.0 + bob
	var x := 1 + PAD
	_draw_pixels(ARROW, Vector2(x, arrow_y), text, false)
	x += ARROW[0].length() + GAP
	var word_y := floorf((ROWS - GLYPH_HEIGHT - 1) * 0.5)
	for letter in WORD:
		_draw_pixels(GLYPHS[letter], Vector2(x, word_y), text, true)
		x += 6 + LETTER_GAP
	x += GAP - LETTER_GAP
	_draw_pixels(ARROW, Vector2(x, arrow_y), text, false)


## Draws a pixel pattern with its top-left at art position `at`: "#" in `color`, "s" in
## the shadow colour, and (`shadowed`) a shadow pixel under every "#" that has no stroke
## below it - the laptop lettering's look.
func _draw_pixels(rows: Array, at: Vector2, color: Color, shadowed: bool) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			if c == "#":
				_pixel(at + Vector2(x, y), color)
				var below_is_stroke: bool = y + 1 < rows.size() and String(rows[y + 1])[x] == "#"
				if shadowed and not below_is_stroke:
					_pixel(at + Vector2(x, y + 1), SHADOW_COLOR)
			elif c == "s":
				_pixel(at + Vector2(x, y), SHADOW_COLOR)


func _pixel(art_pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(art_pos * ART_SCALE, Vector2.ONE * ART_SCALE), color)
