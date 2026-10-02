class_name Minigame
extends Control
## Base for the small repair minigames (lever sequence, meter hold, wire connect,
## big screw). Each one is a self-contained, code-drawn Control: instance it with
## `Script.new()`, add it under a CanvasLayer, and listen for `completed`.
##
## The root covers the whole screen with a faint dim (so clicks don't fall through to
## the scene behind) and centers a fixed-ratio `board` on it, sized as a fraction of
## the viewport (BOARD_VIEWPORT_RATIO). Subclasses lay out and draw everything in
## board-local coordinates:
##   _setup_game()          build / reset all state (called on open and on RESTART)
##   _draw_game()           draw onto `board` (use board.draw_* calls)
##   _game_input(event)     mouse input in board-local coordinates
##   _game_process(delta)   per-frame update (board is redrawn every frame)
## and call `_win()` once the puzzle is solved (or `_lose()` for an outright failure).
## With `auto_close_on_result` set, the game closes itself shortly after either result;
## read `solved` in a `closed` handler to tell a win from a loss / early close.

signal completed(success: bool)
signal closed

## Board size as a fraction of the viewport (eyeballed from the design mockup: a bit
## under half the width, a bit over half the height).
const BOARD_VIEWPORT_RATIO: Vector2 = Vector2(0.48, 0.58)
## Height of the title strip along the top of the board. Game content lays out below it.
const HEADER_HEIGHT: float = 34.0

const COL_DIM := Color(0, 0, 0, 0.45)
const COL_PANEL := Color(0.16, 0.17, 0.19)
const COL_PANEL_INNER := Color(0.11, 0.12, 0.13)
const COL_BORDER := Color(0.55, 0.47, 0.30)
const COL_RIVET := Color(0.42, 0.40, 0.36)
const COL_TEXT := Color(0.93, 0.88, 0.74)
const COL_GOOD := Color(0.35, 0.95, 0.45)
const COL_BAD := Color(1.0, 0.32, 0.25)

## Symbols shared by the games so nothing is told apart by colour alone (each colour
## always comes paired with its own shape, Among Us colour-blind style).
enum Symbol { TRIANGLE, STAR, BOLT, CIRCLE, SQUARE, DIAMOND }
const SYMBOL_COLORS: Dictionary = {
	Symbol.TRIANGLE: Color(1.0, 0.82, 0.2),
	Symbol.STAR: Color(0.35, 0.6, 1.0),
	Symbol.BOLT: Color(1.0, 0.35, 0.3),
	Symbol.CIRCLE: Color(0.95, 0.45, 0.95),
	Symbol.SQUARE: Color(0.3, 0.9, 0.5),
	Symbol.DIAMOND: Color(1.0, 0.6, 0.2),
}

var title: String = "MINIGAME"
var board: Control
var solved: bool = false
## Set by _lose(): the attempt failed outright (the game stops taking input).
var lost: bool = false
## Close automatically RESULT_CLOSE_DELAY seconds after a win or loss (used when a
## minigame gates a gameplay action; the debug menu leaves it off to allow replays).
var auto_close_on_result: bool = false
const RESULT_CLOSE_DELAY: float = 0.7
var rng := RandomNumberGenerator.new()

var _flash: float = 0.0
var _board_size: Vector2 = Vector2.ZERO
var _flash_color: Color = COL_GOOD


func _ready() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = COL_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var size_px := (get_viewport_rect().size * BOARD_VIEWPORT_RATIO).round()
	_board_size = size_px
	board = Control.new()
	board.name = "Board"
	board.clip_contents = true
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.anchor_left = 0.5
	board.anchor_right = 0.5
	board.anchor_top = 0.5
	board.anchor_bottom = 0.5
	board.offset_left = -size_px.x * 0.5
	board.offset_right = size_px.x * 0.5
	board.offset_top = -size_px.y * 0.5
	board.offset_bottom = size_px.y * 0.5
	board.draw.connect(_on_board_draw)
	board.gui_input.connect(_on_board_gui_input)
	add_child(board)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.anchor_left = 1.0
	buttons.anchor_right = 1.0
	buttons.offset_left = -170.0
	buttons.offset_right = -6.0
	buttons.offset_top = 4.0
	buttons.offset_bottom = HEADER_HEIGHT - 4.0
	buttons.alignment = BoxContainer.ALIGNMENT_END
	board.add_child(buttons)
	buttons.add_child(_header_button("RESTART", restart))
	buttons.add_child(_header_button("X", close))

	_setup_game()


func _header_button(text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.theme_type_variation = &"GoldHudButton"
	btn.add_theme_font_size_override("font_size", 12)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	return btn


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	_game_process(delta)
	board.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func restart() -> void:
	solved = false
	lost = false
	_flash = 0.0
	_setup_game()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


## Size of the board in pixels.
func bsize() -> Vector2:
	return _board_size


## The play area below the title strip, inset by `margin`.
func content_rect(margin: float = 14.0) -> Rect2:
	var s := bsize()
	return Rect2(margin, HEADER_HEIGHT + margin, s.x - margin * 2.0, s.y - HEADER_HEIGHT - margin * 2.0)


func _win() -> void:
	if solved:
		return
	solved = true
	flash(COL_GOOD)
	completed.emit(true)
	_schedule_auto_close()


func _lose() -> void:
	if solved or lost:
		return
	lost = true
	flash(COL_BAD)
	completed.emit(false)
	_schedule_auto_close()


func _schedule_auto_close() -> void:
	if not auto_close_on_result:
		return
	# Connected to the method (not a lambda) so the link drops if we're freed first.
	get_tree().create_timer(RESULT_CLOSE_DELAY).timeout.connect(close)


## Briefly tints the board (green on success, red on a mistake).
func flash(color: Color) -> void:
	_flash_color = color
	_flash = 1.0


# --- virtuals ---------------------------------------------------------------

func _setup_game() -> void:
	pass


func _draw_game() -> void:
	pass


func _game_input(_event: InputEvent) -> void:
	pass


func _game_process(_delta: float) -> void:
	pass


# --- drawing ----------------------------------------------------------------

func _on_board_draw() -> void:
	var s := bsize()
	board.draw_rect(Rect2(Vector2.ZERO, s), COL_BORDER)
	board.draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), COL_PANEL)
	board.draw_rect(Rect2(Vector2(8, HEADER_HEIGHT), s - Vector2(16, HEADER_HEIGHT + 8)), COL_PANEL_INNER)
	for p in [Vector2(10, 10), Vector2(s.x - 10, s.y - 10), Vector2(10, s.y - 10)]:
		board.draw_circle(p, 3.0, COL_RIVET)
	draw_text_at(title, Vector2(16, 23), 16, COL_TEXT)

	_draw_game()

	if solved:
		var r := content_rect(0.0)
		board.draw_rect(r, Color(0, 0, 0, 0.35))
		draw_text_centered("COMPLETE", r.get_center() + Vector2(0, 14), 40, COL_GOOD)
	elif lost:
		var r := content_rect(0.0)
		board.draw_rect(r, Color(0, 0, 0, 0.35))
		draw_text_centered("FAILED", r.get_center() + Vector2(0, 14), 40, COL_BAD)
	if _flash > 0.0:
		var c := _flash_color
		c.a = 0.35 * _flash
		board.draw_rect(Rect2(Vector2.ZERO, s), c)


func _on_board_gui_input(event: InputEvent) -> void:
	if solved or lost:
		return
	_game_input(event)


func font() -> Font:
	return ThemeDB.fallback_font


func draw_text_at(text: String, pos: Vector2, font_size: int, color: Color) -> void:
	board.draw_string(font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func draw_text_centered(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var w := font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	board.draw_string(font(), Vector2(center.x - w * 0.5, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Draws one of the shared Symbol shapes centred on `center`, `radius` across.
func draw_symbol(symbol: int, center: Vector2, radius: float, color: Color) -> void:
	match symbol:
		Symbol.TRIANGLE:
			_poly([Vector2(0, -1), Vector2(0.9, 0.7), Vector2(-0.9, 0.7)], center, radius, color)
		Symbol.STAR:
			var pts: Array = []
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				var r := 1.0 if i % 2 == 0 else 0.45
				pts.append(Vector2(cos(a), sin(a)) * r)
			_poly(pts, center, radius, color)
		Symbol.BOLT:
			_poly([Vector2(0.2, -1), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15),
					Vector2(-0.25, 1), Vector2(0.6, -0.2), Vector2(0.05, -0.2)], center, radius, color)
		Symbol.CIRCLE:
			board.draw_circle(center, radius * 0.85, color)
			board.draw_circle(center, radius * 0.45, COL_PANEL_INNER)
		Symbol.SQUARE:
			board.draw_rect(Rect2(center - Vector2.ONE * radius * 0.75, Vector2.ONE * radius * 1.5), color)
		Symbol.DIAMOND:
			_poly([Vector2(0, -1), Vector2(0.75, 0), Vector2(0, 1), Vector2(-0.75, 0)], center, radius, color)


func _poly(unit_pts: Array, center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in unit_pts:
		pts.append(center + p * radius)
	board.draw_colored_polygon(pts, color)
