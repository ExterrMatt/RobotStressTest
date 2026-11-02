class_name Minigame
extends Control
## Base for the small repair minigames (lever sequence, meter hold, wire connect,
## big screw). Each one is a self-contained, code-drawn Control: instance it with
## `Script.new()`, add it under a CanvasLayer, and listen for `completed`.
##
## The root covers the whole screen with a faint dim and centers a fixed-ratio `board`
## on it, sized as a fraction of the viewport (BOARD_VIEWPORT_RATIO). While it's open the
## minigame takes the mouse before anything else in the game sees it (see _route_mouse),
## so no click reaches the scene behind. Subclasses lay out and draw everything in
## board-local coordinates:
##   _setup_game()          build / reset all state (called on open and on RESTART)
##   _draw_game()           draw onto `board` (use board.draw_* calls)
##   _game_input(event)     mouse input in board-local coordinates (over the board, or
##                          the rest of a press begun on it)
##   _game_process(delta)   per-frame update (board is redrawn every frame)
## and call `_win()` once the puzzle is solved (or `_lose()` for an outright failure).
## A minigame with its own board art overrides _board_art_size() (and _art_header() if the
## title strip and its RESTART / X buttons are part of the art): the board is then sized to
## the art at a whole-number `art_scale`, and the subclass draws the art in _draw_game().
## The board slides up from below the screen to open and back down out of it to close
## (see _slide_in / close). A win closes the game RESULT_CLOSE_DELAY later; with
## `auto_close_on_result` set, so does a loss. `closed` is emitted once the board has slid
## away; read `solved` in a `closed` handler to tell a win from a loss / early close.
## In `compact` mode (limb moves) there's no backdrop, frame, title or RESTART: the subclass
## draws just its game, sizes the board to it (set_board_size) and the board sits over
## `over_rect` on screen, with a small X to close it.

signal completed(success: bool)
signal closed

## Board size as a fraction of the viewport (eyeballed from the design mockup: a bit
## under half the width, a bit over half the height).
const BOARD_VIEWPORT_RATIO: Vector2 = Vector2(0.48, 0.58)
## Height of the title strip along the top of the board. Game content lays out below it.
const HEADER_HEIGHT: float = 34.0
## Width of the gold border round a board (also round board art, which sits inside it).
const BORDER_WIDTH: float = 3.0
## Board art may grow past BOARD_VIEWPORT_RATIO to reach a whole-number scale, but never
## past this much of the screen.
const ART_MAX_SCREEN_FRACTION: float = 0.9

## Minigame text uses the game's pixel font. Its capitals are this fraction of the font size
## (Jersey 10: OS/2 capHeight 750 of 1400 units per em), for centring text on a line.
const PIXEL_FONT_CAP_RATIO: float = 750.0 / 1400.0
## Text on board art, sized in art pixels: the title twice the size of button labels.
const ART_TITLE_FONT_SIZE: float = 20.0
const ART_LABEL_FONT_SIZE: float = 10.0
## The title's left margin on the art's header strip (art pixels).
const ART_TITLE_LEFT: float = 10.0
## Least gap between the title and the RESTART button (art pixels); a long title on a narrow
## board shrinks to keep it.
const ART_TITLE_GAP: float = 6.0
## Inset from a header button's edge to its face (its gold border and bevel), art pixels.
const ART_BUTTON_FACE_INSET: float = 3.0

const COL_DIM := Color(0, 0, 0, 0.45)
## While the room the minigame is played in has its lights off (room_dark), the board is
## shown at this brightness; with the lights on it's at full brightness. Not for embedded
## games: the laptop's screen stays lit either way.
const DARK_BRIGHTNESS: float = 0.5
## Set by the scene the minigames are played in (the stress test) while its lights are off.
static var room_dark: bool = false
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
## Also close automatically RESULT_CLOSE_DELAY seconds after a loss (a win always does;
## used when a minigame gates a gameplay action).
var auto_close_on_result: bool = false
## Embedded in another Control (e.g. the laptop screen) instead of covering the whole
## screen: no dim, and the board keeps its usual size but is scaled to fit the parent.
var embedded: bool = false
## Compact (used for limb moves): just the game itself, small, over `over_rect` (screen
## rect, e.g. the limb being moved), with only an X button - no backdrop, frame or title.
var compact: bool = false
var over_rect: Rect2 = Rect2()
## Compact: how far the board sits from its spot over over_rect (screen px), before it's
## kept in off the screen's edges.
var over_nudge: Vector2 = Vector2.ZERO
var _compact_close: Button = null
const RESULT_CLOSE_DELAY: float = 1.0
## Opening and closing: the board slides up from below the screen and back down out of it,
## each move eased out over SLIDE_TIME (in all) with a little bounce at its on-screen end -
## carrying SLIDE_BOUNCE past its spot before settling (opening), or lifting SLIDE_BOUNCE
## before dropping away (closing). The bounce takes SLIDE_BOUNCE_SHARE of the time.
const SLIDE_TIME: float = 0.4
const SLIDE_BOUNCE: float = 14.0
const SLIDE_BOUNCE_SHARE: float = 0.25
## Compact: the least room kept between the board and the edges of the screen.
const COMPACT_SCREEN_MARGIN: float = 32.0
var rng := RandomNumberGenerator.new()

var _flash: float = 0.0
var _board_size: Vector2 = Vector2.ZERO
var _flash_color: Color = COL_GOOD
## Takes the mouse for us ahead of the rest of the game (see _MouseShield).
var _shield: Node = null
## Board art pixels to screen pixels, for minigames with their own board art.
var art_scale: float = 1.0
## The header's buttons: {hit: Callable(event) -> bool, action: Callable} each.
var _header_targets: Array = []
## The header button pressed and not yet released (it fires on release over itself).
var _pressed_target: Dictionary = {}
## Mouse buttons pressed on the board and still held: the board keeps getting the mouse
## until they're released, even off the board (like a GUI drag).
var _board_buttons: Dictionary = {}
var _dim: ColorRect = null
## The board's vertical offset from its resting spot (it slides on this), and whether it's
## sliding (the game takes no input then) or on its way out.
var _slide_offset: float = 0.0
var _sliding: bool = false
var _closing: bool = false


## Sits at the very end of the scene tree, where _input runs first, and hands every mouse
## event to its minigame (which decides what to take) before the scene behind sees it.
class _MouseShield extends Node:
	var minigame: Minigame

	func _ready() -> void:
		get_parent().child_entered_tree.connect(_on_root_child_added)

	func _on_root_child_added(node: Node) -> void:
		if node != self:
			_keep_order.call_deferred()

	## Last on the root, except the post-it note, which keeps first pick of the clicks
	## that land on it (it's drawn above minigames).
	func _keep_order() -> void:
		var root := get_parent()
		if root == null:
			return
		root.move_child(self, -1)
		for child in root.get_children():
			if child is PostItNote:
				root.move_child(child, -1)

	func _input(event: InputEvent) -> void:
		if event is InputEventMouse and is_instance_valid(minigame):
			minigame._route_mouse(event as InputEventMouse)


func _ready() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if not embedded and not compact:
		_dim = ColorRect.new()
		_dim.color = COL_DIM
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_dim)

	var size_px := (get_viewport_rect().size * BOARD_VIEWPORT_RATIO).round()
	var art := _board_art_size()
	if art.x > 0.0 and art.y > 0.0:
		# The whole-number scale nearest the usual board size, unless that would take up
		# more of the screen than ART_MAX_SCREEN_FRACTION allows (then the one below).
		var room := size_px - Vector2.ONE * BORDER_WIDTH * 2.0
		var fit := minf(room.x / art.x, room.y / art.y)
		var limit := get_viewport_rect().size * ART_MAX_SCREEN_FRACTION - Vector2.ONE * BORDER_WIDTH * 2.0
		art_scale = maxf(1.0, roundf(fit))
		while art_scale > 1.0 and (art.x * art_scale > limit.x or art.y * art_scale > limit.y):
			art_scale -= 1.0
		size_px = art * art_scale + Vector2.ONE * BORDER_WIDTH * 2.0
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
	add_child(board)
	if embedded:
		board.pivot_offset = size_px * 0.5
		resized.connect(_fit_embedded_board)
		_fit_embedded_board()

	var header := _art_header()
	if compact:
		# Just a small X in the top-right corner.
		_compact_close = _header_button("X", close)
		_compact_close.anchor_left = 1.0
		_compact_close.anchor_right = 1.0
		_compact_close.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		board.add_child(_compact_close)
		var btn_size := _compact_close.get_combined_minimum_size()
		_compact_close.offset_left = -btn_size.x
		_compact_close.offset_right = 0.0
		_compact_close.offset_top = 0.0
		_compact_close.offset_bottom = btn_size.y
	elif header.has("restart") and header.has("close"):
		# The art's own buttons stand in for the standard ones.
		_header_targets.append({"hit": _art_rect_hit.bind(header["restart"]), "action": restart})
		_header_targets.append({"hit": _art_rect_hit.bind(header["close"]), "action": close})
	else:
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

	_shield = _MouseShield.new()
	_shield.name = "MinigameMouseShield"
	_shield.minigame = self
	get_tree().root.add_child.call_deferred(_shield)
	_shield.ready.connect(_shield._keep_order, CONNECT_ONE_SHOT)
	if not embedded:
		# Hover hands from the scene behind (set before we opened) don't show through.
		CursorTheme.set_override(self, CursorTheme.Grab.NONE)

	_setup_game()
	_slide_in()


func _exit_tree() -> void:
	if is_instance_valid(_shield):
		_shield.queue_free()
	CursorTheme.release_override(self)


## Embedded: scale the board (about its centre) to fit inside this control.
func _fit_embedded_board() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _board_size.x <= 0.0 or _board_size.y <= 0.0:
		return
	var fit := minf(size.x / _board_size.x, size.y / _board_size.y)
	board.scale = Vector2.ONE * fit


func _header_button(text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.theme_type_variation = &"GoldHudButton"
	btn.add_theme_font_size_override("font_size", 12)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(action)
	_header_targets.append({"hit": _button_hit.bind(btn), "action": func() -> void: btn.pressed.emit()})
	return btn


func _button_hit(event: InputEvent, btn: Button) -> bool:
	return btn.is_visible_in_tree() and not btn.disabled and _event_over(btn, event)


## `event` is over `rect` (art pixels) of the board art.
func _art_rect_hit(event: InputEvent, rect: Rect2) -> bool:
	var local := (board.make_input_local(event) as InputEventMouse).position
	return art_to_board(rect).has_point(local)


## Where the board art sits on the board (inside the gold border), in board pixels.
func art_rect() -> Rect2:
	var art := _board_art_size()
	if art == Vector2.ZERO:
		return Rect2(Vector2.ZERO, bsize())
	return Rect2(Vector2.ONE * BORDER_WIDTH, art * art_scale)


## A rect in art pixels, in board pixels.
func art_to_board(rect: Rect2) -> Rect2:
	return Rect2(art_rect().position + rect.position * art_scale, rect.size * art_scale)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	var tint := Color.WHITE.lerp(_flash_color, 0.6 * _flash) if compact else Color.WHITE
	if room_dark and not embedded:
		tint *= Color(DARK_BRIGHTNESS, DARK_BRIGHTNESS, DARK_BRIGHTNESS)
	board.modulate = tint
	_place_board()
	_game_process(delta)
	board.queue_redraw()


## The board's resting spot is the middle of this control; it sits _slide_offset below it.
func _place_board() -> void:
	board.position = (_rest_position() + Vector2(0, _slide_offset)).round()


## Where the board rests: the middle of this control, or (compact) over over_rect (see
## _compact_anchor) - the part of it that's on screen, so a limb hanging off the edge of
## the view gets its game over the bit you can see - kept COMPACT_SCREEN_MARGIN in from
## the screen's edges (or centred, if it's too big for that).
func _rest_position() -> Vector2:
	var area := size if size.y > 0.0 else get_viewport_rect().size  # not laid out yet
	if compact and over_rect.has_area():
		var target := over_rect.intersection(Rect2(Vector2.ZERO, area))
		if not target.has_area():
			target = over_rect
		var pos := target.get_center() - _compact_anchor() + over_nudge
		for axis in 2:
			var room := area[axis] - _board_size[axis]
			var edge := minf(COMPACT_SCREEN_MARGIN, maxf(0.0, room * 0.5))
			pos[axis] = clampf(pos[axis], edge, maxf(edge, room - edge))
		return pos
	return (area - _board_size) * 0.5


## How far below its resting spot the board must be to sit wholly under this control's
## bottom edge (allowing for an embedded board's scale about its centre).
func _offscreen_offset() -> float:
	var height := size.y if size.y > 0.0 else get_viewport_rect().size.y  # not laid out yet
	var rest_top := _rest_position().y + board.pivot_offset.y * (1.0 - board.scale.y)
	return height - rest_top + 2.0


## Compact: the point on the board that sits over the middle of over_rect - the board's
## own middle unless the game says otherwise.
func _compact_anchor() -> Vector2:
	return _board_size * 0.5


## Resizes the board (compact games size it to fit what they draw).
func set_board_size(new_size: Vector2) -> void:
	_board_size = new_size
	board.size = new_size
	if embedded:
		board.pivot_offset = new_size * 0.5


## Room a compact board keeps along its top for its X button.
func compact_top_reserve() -> float:
	return (_compact_close.get_combined_minimum_size().y if _compact_close != null else 24.0) + 4.0


## Opening: up from below, eased out, carrying a little past its spot and settling.
func _slide_in() -> void:
	_sliding = true
	_slide_offset = _offscreen_offset()
	_place_board()
	var tw := create_tween()
	tw.tween_property(self, "_slide_offset", -SLIDE_BOUNCE, SLIDE_TIME * (1.0 - SLIDE_BOUNCE_SHARE)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_slide_offset", 0.0, SLIDE_TIME * SLIDE_BOUNCE_SHARE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _sliding = false)
	if _dim != null:
		_dim.color.a = 0.0
		create_tween().tween_property(_dim, "color:a", COL_DIM.a, SLIDE_TIME * 0.6)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func restart() -> void:
	solved = false
	lost = false
	_flash = 0.0
	_setup_game()


## Closing: a little lift, then eased out down out of sight; `closed` goes out once it's gone.
func close() -> void:
	if _closing or is_queued_for_deletion():
		return
	_closing = true
	_sliding = true
	var tw := create_tween()
	tw.tween_property(self, "_slide_offset", _slide_offset - SLIDE_BOUNCE, SLIDE_TIME * SLIDE_BOUNCE_SHARE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_slide_offset", _offscreen_offset(), SLIDE_TIME * (1.0 - SLIDE_BOUNCE_SHARE)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_close)
	if _dim != null:
		create_tween().tween_property(_dim, "color:a", 0.0, SLIDE_TIME)


func _finish_close() -> void:
	closed.emit()
	queue_free()


## Size of the board in pixels.
func bsize() -> Vector2:
	return _board_size


## The play area below the title strip, inset by `margin`.
func content_rect(margin: float = 14.0) -> Rect2:
	var s := bsize()
	var top := header_height()
	return Rect2(margin, top + margin, s.x - margin * 2.0, s.y - top - margin * 2.0)


## Height of the title strip on the board (the art's, when it has one).
func header_height() -> float:
	var header := _art_header()
	return art_rect().position.y + float(header["height"]) * art_scale if header.has("height") else HEADER_HEIGHT


func _win() -> void:
	if solved:
		return
	solved = true
	flash(COL_GOOD)
	completed.emit(true)
	_schedule_close()


func _lose() -> void:
	if solved or lost:
		return
	lost = true
	flash(COL_BAD)
	completed.emit(false)
	if auto_close_on_result:
		_schedule_close()


func _schedule_close() -> void:
	# Connected to the method (not a lambda) so the link drops if we're freed first.
	get_tree().create_timer(RESULT_CLOSE_DELAY).timeout.connect(close)


## Briefly tints the board (green on success, red on a mistake).
func flash(color: Color) -> void:
	_flash_color = color
	_flash = 1.0


# --- virtuals ---------------------------------------------------------------

## Size of the board art in art pixels (zero: no art, the standard drawn board).
func _board_art_size() -> Vector2:
	return Vector2.ZERO


## The board art's own title strip, in art pixels: {height: float, restart: Rect2,
## close: Rect2}. Empty: the standard header and buttons.
func _art_header() -> Dictionary:
	return {}


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
	if compact:
		# Just the game; results show as a tint on it (see _process).
		_draw_game()
		return
	var header := _art_header()
	board.draw_rect(Rect2(Vector2.ZERO, s), COL_BORDER)
	if _board_art_size() == Vector2.ZERO:
		board.draw_rect(Rect2(Vector2.ONE * BORDER_WIDTH, s - Vector2.ONE * BORDER_WIDTH * 2.0), COL_PANEL)
		board.draw_rect(Rect2(Vector2(8, HEADER_HEIGHT), s - Vector2(16, HEADER_HEIGHT + 8)), COL_PANEL_INNER)
		for p in [Vector2(10, 10), Vector2(s.x - 10, s.y - 10), Vector2(10, s.y - 10)]:
			board.draw_circle(p, 3.0, COL_RIVET)
	if header.is_empty():
		draw_text_at(title, Vector2(16, 23), 20, COL_TEXT)

	_draw_game()

	if header.has("restart"):
		_draw_art_header_labels(header)

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


## Every mouse event, before the rest of the game sees it (from _MouseShield). A full-
## screen minigame takes them all; an embedded one only those over its own area (so the
## laptop around it keeps working), plus the rest of any press begun on it. Taken events
## go to the header buttons or the board and nowhere else.
func _route_mouse(event: InputEventMouse) -> void:
	if not is_visible_in_tree() or _inventory_open():
		return
	var mb := event as InputEventMouseButton
	var held := not _board_buttons.is_empty() or not _pressed_target.is_empty()
	if embedded and not held and not _event_over(self, event):
		return
	get_viewport().set_input_as_handled()
	if _sliding:
		return  # still on its way in or out: clicks are swallowed, not played

	# Header buttons fire on release, over the button they were pressed on.
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			for target in _header_targets:
				if (target["hit"] as Callable).call(event):
					_pressed_target = target
					return
		elif not _pressed_target.is_empty():
			var target := _pressed_target
			_pressed_target = {}
			if (target["hit"] as Callable).call(event):
				(target["action"] as Callable).call()
			return

	# The board, in board-local coordinates: while over it, or until a press begun on it
	# is released.
	var on_board := _event_over(board, event)
	if mb != null:
		if mb.pressed:
			if not on_board:
				return
			_board_buttons[mb.button_index] = true
		else:
			if not _board_buttons.has(mb.button_index):
				return
			_board_buttons.erase(mb.button_index)
	elif not on_board and _board_buttons.is_empty():
		return
	if solved or lost:
		return
	_game_input(board.make_input_local(event))


## `event` is over `control` (in its own, possibly scaled, coordinates).
func _event_over(control: Control, event: InputEvent) -> bool:
	var local: InputEvent = control.make_input_local(event)
	return Rect2(Vector2.ZERO, control.size).has_point((local as InputEventMouse).position)


## The inventory is open over us: its clicks are its own.
func _inventory_open() -> bool:
	for node in get_tree().get_nodes_in_group(InventoryOverlay.GROUP):
		if node is CanvasLayer and node.visible:
			return true
	return false


## The game's pixel font (the project theme's), so minigame text matches the rest of the UI -
## rasterized for the board's scale so it stays sharp (see CrispText).
func font() -> Font:
	var base := ThemeDB.fallback_font
	var project_theme := ThemeDB.get_project_theme()
	if project_theme != null and project_theme.default_font != null:
		base = project_theme.default_font
	return CrispText.font_for(board, base)


## The labels on board art's own header: the title on the left of the strip and RESTART on
## the blank button's face, both lined up on the button face's middle.
func _draw_art_header_labels(header: Dictionary) -> void:
	var restart: Rect2 = header["restart"]
	var face := restart.grow(-ART_BUTTON_FACE_INSET)
	var mid := face.get_center()
	var title_room := restart.position.x - ART_TITLE_GAP - ART_TITLE_LEFT
	draw_art_text(title, Vector2(ART_TITLE_LEFT, mid.y), ART_TITLE_FONT_SIZE, false, COL_TEXT, title_room)
	draw_art_text("RESTART", mid, ART_LABEL_FONT_SIZE, true)


## Text on board art. `at` (art pixels) is the text's left edge (or its middle, when
## `centred`) and the middle of its capitals; `font_size` is in art pixels. The baseline sits
## half a capital below that middle, rounded to a whole screen pixel. With `max_width` (art
## pixels) the text shrinks until it fits.
func draw_art_text(text: String, at: Vector2, font_size: float, centred: bool,
		color: Color = COL_TEXT, max_width: float = 0.0) -> void:
	var font_px := int(roundf(font_size * art_scale))
	var width := font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	while max_width > 0.0 and font_px > 8 and width > max_width * art_scale:
		font_px -= 1
		width = font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	var origin := art_rect().position + at * art_scale
	var x := roundf(origin.x - width * 0.5) if centred else roundf(origin.x)
	var baseline := roundf(origin.y + font_px * PIXEL_FONT_CAP_RATIO * 0.5)
	board.draw_string(font(), Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)


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
