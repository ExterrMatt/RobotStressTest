class_name CameraViewfinder
extends Control
## A camcorder viewfinder drawn over the whole screen as pixel art: a white L bracket
## in each corner, a recording readout tucked inside the top-left one (a red record
## button, a flashing red dot and "REC"), and the time recorded so far inside the
## bottom-left one.
##
## Everything is drawn in art pixels PIXEL screen pixels wide (close to the scale the
## 500px scene art is shown at), with a 5x7 bitmap font, so it reads as pixel art.
##
## Spacing is the same everywhere: the readout and the timer sit the same distance in
## from both arms of their bracket, and while recording every HUD near an edge is moved
## to SAFE_MARGIN from it - the same gap clear of the brackets on both axes - with HUDs
## in the left corners moved clear of the readout / timer instead
## (Main.set_camera_recording / Main.register_camera_hud).

## Screen pixels per art pixel.
const PIXEL: float = 3.0

## Brackets, in art pixels.
const BRACKET_INSET: int = 4
## Length of the vertical arms (along the left / right edges).
const BRACKET_LENGTH: int = 20
## Length of the horizontal arms (along the top / bottom edges): three times as long.
const BRACKET_LENGTH_H: int = 60
const BRACKET_THICKNESS: int = 1
## The brackets' drop shadow, in art pixels (down and right).
const SHADOW_OFFSET: int = 1

## Art-pixel gap kept between the brackets and anything inside them (the readout, the
## timer, and HUDs moved by SAFE_MARGIN), and between the readout's pieces.
const GAP: int = 3

## A bracket's inner edge, shadow included, in art pixels from the screen edge. The
## shadow falls down and right, so it is inside a left arm or a top arm but outside a
## right or bottom one.
const BRACKET_INNER: int = BRACKET_INSET + BRACKET_THICKNESS + SHADOW_OFFSET
## Where the readout starts, in art pixels: GAP in from both arms of the top-left L.
const READOUT_X: int = BRACKET_INNER + GAP
const READOUT_Y: int = BRACKET_INNER + GAP
## The readout's size in art pixels: [button, dot, REC].
const READOUT_SIZE: Vector2i = Vector2i(11 + GAP + 7 + GAP + 17, 7)
## The timer ("00:00:00") in the bottom-left L: as far in from the left arm as the
## readout, and the same visible distance up from the bottom arm as the readout is down
## from the top one (the bottom arm's shadow is outside the L).
const TIMER_SIZE: Vector2i = Vector2i(39, 7)
const TIMER_BOTTOM: int = BRACKET_INSET + BRACKET_THICKNESS + GAP + SHADOW_OFFSET

## How far (screen pixels) HUDs stay from every screen edge while recording: GAP clear
## of the brackets.
const SAFE_MARGIN: float = (BRACKET_INNER + GAP) * PIXEL


## The readout's screen rect, grown by GAP: what top-left HUDs move below.
static func readout_clearance_rect() -> Rect2:
	return Rect2(
		Vector2(READOUT_X, READOUT_Y) * PIXEL,
		Vector2(READOUT_SIZE) * PIXEL).grow(GAP * PIXEL)


## The timer's screen rect on a `view`-sized screen, grown by GAP: what bottom-left
## HUDs move above.
static func timer_clearance_rect(view: Vector2) -> Rect2:
	return Rect2(
		Vector2(READOUT_X * PIXEL, view.y - (TIMER_BOTTOM + TIMER_SIZE.y) * PIXEL),
		Vector2(TIMER_SIZE) * PIXEL).grow(GAP * PIXEL)


const WHITE: Color = Color(1.0, 1.0, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.5)
const RED: Color = Color(0.85, 0.11, 0.11)
const RED_DARK: Color = Color(0.45, 0.04, 0.05)
const RED_LIGHT: Color = Color(1.0, 0.45, 0.42)

## The dot is lit this long, then dark this long, over and over.
const DOT_ON_SECONDS: float = 0.8
const DOT_OFF_SECONDS: float = 0.45

## The record button: red with a dark rim and a light glint.
## "#" rim, "r" red, "+" glint.
const BUTTON_ART: Array[String] = [
	".#########.",
	"#++rrrrrrr#",
	"#+rrrrrrrr#",
	"#rrrrrrrrr#",
	"#rrrrrrrrr#",
	"#rrrrrrrrr#",
	".#########.",
]
const DOT_ART: Array[String] = [
	"..###..",
	".#####.",
	"#######",
	"#######",
	"#######",
	".#####.",
	"..###..",
]
## 5x7 glyphs (":" is one column).
const GLYPHS: Dictionary = {
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	":": [".", "#", ".", ".", ".", "#", "."],
}
const GLYPH_HEIGHT: int = 7

var _start_msec: int = 0
var _last_text: String = ""
var _dot_lit: bool = true


## Screens the viewfinder must not draw over (the stress test's results screen) join this
## group; the viewfinder hides while any of them is on screen.
const HIDE_GROUP: StringName = &"hides_camera_viewfinder"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Keeps checking (and the clock keeps running) while a paused screen is up.
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart()
	resized.connect(queue_redraw)


## Starts the recording clock over from 00:00:00.
func restart() -> void:
	_start_msec = Time.get_ticks_msec()
	queue_redraw()


## Seconds recorded so far.
func elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _start_msec) / 1000.0


func _process(_delta: float) -> void:
	visible = not _hidden_by_a_screen()
	# Redraw only when the readout actually changes (once a second, and on each blink).
	var text := _timer_text()
	var lit := _dot_is_lit()
	if text != _last_text or lit != _dot_lit:
		_last_text = text
		_dot_lit = lit
		queue_redraw()


func _hidden_by_a_screen() -> bool:
	for node in get_tree().get_nodes_in_group(HIDE_GROUP):
		if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
			return true
	return false


func _timer_text() -> String:
	var total := int(elapsed_seconds())
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _dot_is_lit() -> bool:
	return fmod(elapsed_seconds(), DOT_ON_SECONDS + DOT_OFF_SECONDS) < DOT_ON_SECONDS


func _draw() -> void:
	_draw_brackets()
	_draw_readout()


func _draw_brackets() -> void:
	# In art pixels: the screen, and each corner's two arms from the corner outwards.
	var cols := int(size.x / PIXEL)
	var rows := int(size.y / PIXEL)
	var i := BRACKET_INSET
	var l := BRACKET_LENGTH
	var h := BRACKET_LENGTH_H
	var t := BRACKET_THICKNESS
	var arms: Array[Rect2i] = [
		Rect2i(i, i, h, t), Rect2i(i, i, t, l),
		Rect2i(cols - i - h, i, h, t), Rect2i(cols - i - t, i, t, l),
		Rect2i(i, rows - i - t, h, t), Rect2i(i, rows - i - l, t, l),
		Rect2i(cols - i - h, rows - i - t, h, t), Rect2i(cols - i - t, rows - i - l, t, l),
	]
	# The right and bottom arms are measured from the art-pixel grid's far edge; pin
	# them to the real screen edge so both sides sit the same distance in.
	var shift := Vector2(size.x - cols * PIXEL, size.y - rows * PIXEL)
	var rects: Array[Rect2] = []
	for arm in arms:
		var at := Vector2(arm.position) * PIXEL
		if arm.position.x > cols / 2:
			at.x += shift.x
		if arm.position.y > rows / 2:
			at.y += shift.y
		rects.append(Rect2(at, Vector2(arm.size) * PIXEL))
	# Every shadow first, then the white: a shadow drawn after the other arm of its L
	# would smudge across that arm at the joint.
	for rect in rects:
		draw_rect(Rect2(rect.position + Vector2(SHADOW_OFFSET, SHADOW_OFFSET) * PIXEL, rect.size), SHADOW)
	for rect in rects:
		draw_rect(rect, WHITE)


## [button, dot, REC] inside the top-left L, and the timer inside the bottom-left one.
func _draw_readout() -> void:
	var x := float(READOUT_X)
	var y := float(READOUT_Y)
	_draw_art(BUTTON_ART, Vector2(x, y), {"#": RED_DARK, "r": RED, "+": RED_LIGHT}, true)
	x += BUTTON_ART[0].length() + GAP
	if _dot_is_lit():
		_draw_art(DOT_ART, Vector2(x, y), {"#": RED}, true)
	x += DOT_ART[0].length() + GAP
	_draw_text("REC", Vector2(x, y))
	var timer_y := size.y / PIXEL - TIMER_BOTTOM - TIMER_SIZE.y
	_draw_text(_timer_text(), Vector2(READOUT_X, timer_y))


## Draws `text` in the bitmap font at art-pixel position `at`; returns the x after it.
func _draw_text(text: String, at: Vector2) -> float:
	var x := at.x
	for ch in text:
		var glyph: Array = GLYPHS.get(ch, GLYPHS["0"])
		_draw_art(glyph, Vector2(x, at.y), {"#": WHITE}, true)
		x += String(glyph[0]).length() + 1
	return x - 1


## Draws pixel art rows at art-pixel position `at`, one PIXEL square per mapped char,
## optionally over a one-pixel drop shadow.
func _draw_art(art: Array, at: Vector2, colors: Dictionary, shadow: bool) -> void:
	for pass_shadow in ([true, false] if shadow else [false]):
		for row in art.size():
			var line := String(art[row])
			for col in line.length():
				var ch := line[col]
				if not colors.has(ch):
					continue
				var px := (at + Vector2(col, row)) * PIXEL
				if pass_shadow:
					draw_rect(Rect2(px + Vector2(PIXEL, PIXEL), Vector2(PIXEL, PIXEL)), SHADOW)
				else:
					draw_rect(Rect2(px, Vector2(PIXEL, PIXEL)), colors[ch])
