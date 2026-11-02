extends Control
## Lowering the blanket off the sleeping robot (Sleep scene).
##
## A close-up panel of the bed. The blanket's edge is split into three pieces side
## by side (left, middle, right), and each has to be dragged down on its own until
## all three reach the bottom. The pieces move one row at a time on a grid of
## grid_rows rows. Neighbouring pieces can be up to tug_rows apart and the two
## outer pieces up to spread_rows apart; moving a piece past either limit drags
## the others along with it (a "drag").
##
## The meter under the panel: the marker shows the left/right tilt - left of
## centre when the left piece is lower, right when the right is - in whole rows:
## level sits in green, 1 row apart in orange, 2 or more in red. On top of that the
## bar itself turns harsher when the middle is out of line with the sides:
##  - the middle a combined misalign_orange_rows (3) or more rows away from the
##    two sides (either ahead of both or behind both): green becomes orange,
##  - the middle behind both sides by a combined sides_red_rows (4): all red,
##  - right after a drag, until the next move: all red.
## The zone under the marker (meter_zone) sets her awareness rate in the scene.
##
## The scene can also drag the pieces straight on the bed art, without this panel
## showing (begin_external_drag / external_drag_to_row / end_external_drag): the
## same rows, limits, cooldowns and penalties apply either way.
##
## Every move starts a cooldown: step_move_cooldown_seconds after a plain move,
## drag_move_cooldown_seconds after a drag. A move made before it runs out is
## rushed, costing rush_penalty per piece moved, compounding with each rushed move
## in a row (10, 20, 30, ...) until the player waits one out. A drag also always
## costs drag_penalty for every piece it dragged along, rushed or not.
##
## Placeholder art: plain shapes in the mockup's colours.

## All three pieces reached the bottom: the blanket is off.
signal completed
## A move jolted her (a drag, or a rushed move): add `awareness` to her awareness.
signal jolted(awareness: float)

const PIECE_COUNT: int = 3

enum Zone { GREEN, ORANGE, RED }

## Rows on the grid the pieces snap to, from the top to the bottom of the drag.
@export_range(2, 40, 1) var grid_rows: int = 5
## Rows two neighbouring pieces can be apart before moving one drags the other.
@export_range(1, 20, 1) var tug_rows: int = 2
## Rows the left and right pieces can be apart before moving one drags the other.
@export_range(1, 40, 1) var spread_rows: int = 3
## Combined rows the middle can sit out of line with both sides before the bar's
## green turns orange.
@export_range(1, 40, 1) var misalign_orange_rows: int = 3
## Combined rows the middle can lag behind both sides before the bar turns red.
@export_range(1, 40, 1) var sides_red_rows: int = 4
## How quickly the meter's marker glides to a new reading (higher = snappier).
@export var marker_glide_speed: float = 12.0
## Seconds after a move before the next one stops counting as rushed: after a
## plain move, and after a drag.
@export var step_move_cooldown_seconds: float = 0.5
@export var drag_move_cooldown_seconds: float = 5.0
## Awareness per piece moved by a rushed move; each further rushed move in a row
## adds this much more per piece than the last (10, 20, 30, ...).
@export var rush_penalty: float = 10.0
## Awareness for every piece a drag pulls along, always.
@export var drag_penalty: float = 33.0
## Meter zones, as fractions of the meter's half-width out from the centre: green
## up to the green edge, orange up to the red edge, red beyond. The defaults give
## a meter that reads red 10% | orange 15% | green 50% | orange 15% | red 10%.
@export_range(0.0, 1.0, 0.01) var green_zone_half_width: float = 0.5
@export_range(0.0, 1.0, 0.01) var red_zone_start: float = 0.8

const PANEL_SIZE := Vector2(320, 400)
const METER_SIZE := Vector2(290, 44)
const METER_GAP: float = 14.0
const BORDER: float = 6.0
const EDGE_THICKNESS: float = 26.0
## Gap drawn between the three pieces of the edge.
const PIECE_GAP: float = 4.0
## The edge starts just under the robot's head and finishes at the panel's foot.
const EDGE_START_RATIO: float = 0.3
const EDGE_END_RATIO: float = 0.94

const COLOR_BORDER := Color("00805a")
const COLOR_ROBOT := Color("62007a")
const COLOR_HEAD := Color.WHITE
const COLOR_BLANKET := Color("e51e1e")
const COLOR_EDGE := Color("8a8a8a")
const COLOR_EDGE_HELD := Color("b4b4b4")
const COLOR_METER_BG := Color("8a8a8a")
const COLOR_METER_RED := Color("e51e1e")
const COLOR_METER_GREEN := Color("2ee81a")
const COLOR_METER_ORANGE := Color("ff8a1e")

## Per piece: 0 = at the top, 1 = all the way down (read by the scene for the
## bed's blanket art). Mirrors _rows.
var progress: Array[float] = [0.0, 0.0, 0.0]
## Per piece: the grid row it sits on, 0 (top) to grid_rows (bottom).
var _rows: Array[int] = [0, 0, 0]
var _held_piece: int = -1
var _drag_grab_offset: float = 0.0
var _finished: bool = false
## Where the meter's marker is drawn (-1..1); it glides toward the reading.
var _marker: float = 0.0
## Until when (seconds) a move counts as rushed, and how many rushed moves have
## been made in a row.
var _cooldown_until: float = -1.0
var _rush_streak: int = 0
## Whether the last move dragged another piece (the bar reads red until the next).
var _last_move_dragged: bool = false
## True while the scene holds a piece (dragging it on the bed art), so this panel's
## own mouse handling stays out of the way.
var _external_drag: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_SIZE.x, PANEL_SIZE.y + METER_GAP + METER_SIZE.y)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## The meter zone under the marker: the harsher of the tilt's own zone and the
## bar's floor.
func meter_zone() -> int:
	return maxi(_tilt_zone(), _floor_zone())


## Rows the left piece is lower than the right (negative: the right is lower).
func _tilt_rows() -> int:
	return _rows[0] - _rows[PIECE_COUNT - 1]


func _tilt_zone() -> int:
	var tilt := absi(_tilt_rows())
	if tilt == 0:
		return Zone.GREEN
	if tilt == 1:
		return Zone.ORANGE
	return Zone.RED


## The least the whole bar reads, from how the middle lines up with the sides.
func _floor_zone() -> int:
	if _last_move_dragged:
		return Zone.RED
	var left := _rows[0]
	var middle := _rows[1]
	var right := _rows[PIECE_COUNT - 1]
	if left > middle and right > middle:
		var lag := (left - middle) + (right - middle)
		if lag >= sides_red_rows:
			return Zone.RED
		if lag >= misalign_orange_rows:
			return Zone.ORANGE
	elif middle > left and middle > right:
		if (middle - left) + (middle - right) >= misalign_orange_rows:
			return Zone.ORANGE
	return Zone.GREEN


## -1..1: where the marker sits for the current tilt - level in the middle, one
## row in the middle of the orange band, two in the red, three at the very end.
func _marker_target() -> float:
	var tilt := absi(_tilt_rows())
	var green := clampf(green_zone_half_width, 0.0, 1.0)
	var red := clampf(maxf(red_zone_start, green_zone_half_width), 0.0, 1.0)
	var offset := 0.0
	if tilt == 1:
		offset = (green + red) * 0.5
	elif tilt == 2:
		offset = lerpf(red, 1.0, 0.5)
	elif tilt >= 3:
		offset = lerpf(red, 1.0, 0.9)
	return -signf(float(_tilt_rows())) * offset


func _process(delta: float) -> void:
	var target := _marker_target()
	if is_equal_approx(_marker, target):
		return
	_marker = lerpf(_marker, target, clampf(marker_glide_speed * delta, 0.0, 1.0))
	if absf(_marker - target) < 0.002:
		_marker = target
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _finished or _external_drag:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed and Rect2(Vector2.ZERO, PANEL_SIZE).has_point(mb.position):
			# The column clicked picks the piece.
			_held_piece = clampi(int(mb.position.x / (PANEL_SIZE.x / PIECE_COUNT)), 0, PIECE_COUNT - 1)
			# Grab the piece where it is, so it doesn't jump to the cursor.
			_drag_grab_offset = _edge_y(progress[_held_piece]) - mb.position.y
			queue_redraw()
			accept_event()


func _input(event: InputEvent) -> void:
	if _held_piece < 0 or _finished or _external_drag:
		return
	if event is InputEventMouseMotion:
		_drag_to(get_local_mouse_position().y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_held_piece = -1
		queue_redraw()
		get_viewport().set_input_as_handled()


## The grid row `piece` sits on, 0 (top) to grid_rows (bottom).
func piece_row(piece: int) -> int:
	return _rows[clampi(piece, 0, PIECE_COUNT - 1)]


## The scene grabs `piece` on the bed art.
func begin_external_drag(piece: int) -> void:
	if _finished or _held_piece >= 0:
		return
	_held_piece = clampi(piece, 0, PIECE_COUNT - 1)
	_external_drag = true
	queue_redraw()


## Walks the externally held piece toward `row`, one row (one move) at a time.
func external_drag_to_row(row: int) -> void:
	if not _external_drag or _held_piece < 0:
		return
	row = clampi(row, 0, grid_rows)
	while not _finished and _held_piece >= 0 and _rows[_held_piece] != row:
		_step_held_piece(signi(row - _rows[_held_piece]))
	queue_redraw()


func end_external_drag() -> void:
	if not _external_drag:
		return
	_external_drag = false
	_held_piece = -1
	queue_redraw()


## Walks the held piece toward the cursor's row, one row (one move) at a time.
func _drag_to(local_y: float) -> void:
	var top := _edge_top_y()
	var bottom := _edge_bottom_y()
	var raw := clampf((local_y + _drag_grab_offset - top) / maxf(1.0, bottom - top), 0.0, 1.0)
	var target_row := roundi(raw * maxi(1, grid_rows))
	while not _finished and _held_piece >= 0 and _rows[_held_piece] != target_row:
		_step_held_piece(signi(target_row - _rows[_held_piece]))
	queue_redraw()


## Moves the held piece one row; any piece left too far from it is dragged along.
func _step_held_piece(direction: int) -> void:
	var before := _rows.duplicate()
	_rows[_held_piece] += direction
	_settle_around(_held_piece)
	var dragged := 0
	for i in PIECE_COUNT:
		if i != _held_piece and _rows[i] != before[i]:
			dragged += 1
		progress[i] = float(_rows[i]) / float(maxi(1, grid_rows))
	_on_move(dragged)
	if _rows.min() >= grid_rows:
		_finished = true
		_held_piece = -1
		_external_drag = false
		completed.emit()


## Pulls the other pieces, nearest first, back within reach of every piece already
## settled (neighbours tug_rows, the two ends spread_rows).
func _settle_around(held: int) -> void:
	var settled: Array[int] = [held]
	for distance in range(1, PIECE_COUNT):
		for i in [held - distance, held + distance]:
			if i < 0 or i >= PIECE_COUNT:
				continue
			for j in settled:
				var gap := tug_rows if absi(i - j) == 1 else spread_rows
				_rows[i] = clampi(_rows[i], _rows[j] - gap, _rows[j] + gap)
			settled.append(i)


## A move that dragged `dragged` other pieces along: a drag always costs
## drag_penalty per dragged piece, and a move inside the last move's cooldown is
## rushed on top, compounding with each rushed move in a row. Then starts this
## move's own cooldown, long after a drag and short otherwise.
func _on_move(dragged: int) -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var awareness := drag_penalty * dragged
	if now < _cooldown_until:
		_rush_streak += 1
		awareness += rush_penalty * _rush_streak * (1 + dragged)
	else:
		_rush_streak = 0
	_cooldown_until = now + (drag_move_cooldown_seconds if dragged > 0 else step_move_cooldown_seconds)
	_last_move_dragged = dragged > 0
	if awareness > 0.0:
		jolted.emit(awareness)


func _edge_top_y() -> float:
	return PANEL_SIZE.y * EDGE_START_RATIO


func _edge_bottom_y() -> float:
	return PANEL_SIZE.y * EDGE_END_RATIO


func _edge_y(piece_progress: float) -> float:
	return lerpf(_edge_top_y(), _edge_bottom_y(), piece_progress)


func _draw() -> void:
	var inner := Rect2(Vector2(BORDER, BORDER), PANEL_SIZE - Vector2(BORDER, BORDER) * 2.0)
	draw_rect(Rect2(Vector2.ZERO, PANEL_SIZE), COLOR_BORDER)
	draw_rect(inner, COLOR_ROBOT)
	# Her head, peeking out above the blanket.
	var head := Rect2(inner.position + Vector2(inner.size.x * 0.28, inner.size.y * 0.04),
			Vector2(inner.size.x * 0.44, inner.size.y * 0.14))
	draw_rect(head.grow(BORDER * 0.5), COLOR_BORDER)
	draw_rect(head, COLOR_HEAD)

	# Each third of the blanket: red below its own piece of the grey edge.
	var column_w := inner.size.x / PIECE_COUNT
	for i in PIECE_COUNT:
		var x0 := inner.position.x + column_w * i
		var edge_y := _edge_y(progress[i])
		var half := EDGE_THICKNESS * 0.5
		draw_rect(Rect2(Vector2(x0, edge_y), Vector2(column_w, inner.end.y - edge_y)), COLOR_BLANKET)
		var piece := Rect2(Vector2(x0, edge_y - half), Vector2(column_w, EDGE_THICKNESS))
		piece = piece.intersection(inner)
		if i > 0:
			piece = piece.grow_side(SIDE_LEFT, -PIECE_GAP * 0.5)
		if i < PIECE_COUNT - 1:
			piece = piece.grow_side(SIDE_RIGHT, -PIECE_GAP * 0.5)
		draw_rect(piece, COLOR_EDGE_HELD if i == _held_piece else COLOR_EDGE)

	# Tilt meter: red | orange | green | orange | red with a white marker; the
	# bands are raised to the bar's floor (green to orange, or all red).
	var meter := Rect2(Vector2((PANEL_SIZE.x - METER_SIZE.x) * 0.5, PANEL_SIZE.y + METER_GAP), METER_SIZE)
	draw_rect(meter, COLOR_METER_BG)
	var bar := meter.grow(-6.0)
	var half_w := bar.size.x * 0.5
	var mid_x := bar.position.x + half_w
	var green_w := half_w * clampf(green_zone_half_width, 0.0, 1.0)
	var red_from := half_w * clampf(maxf(red_zone_start, green_zone_half_width), 0.0, 1.0)
	var floor_zone := _floor_zone()
	draw_rect(Rect2(bar.position, bar.size), COLOR_METER_RED)
	draw_rect(Rect2(Vector2(mid_x - red_from, bar.position.y), Vector2(red_from * 2.0, bar.size.y)),
			_zone_color(maxi(Zone.ORANGE, floor_zone)))
	draw_rect(Rect2(Vector2(mid_x - green_w, bar.position.y), Vector2(green_w * 2.0, bar.size.y)),
			_zone_color(maxi(Zone.GREEN, floor_zone)))
	var marker_x := mid_x + _marker * half_w
	draw_rect(Rect2(Vector2(marker_x - 3.0, meter.position.y + 2.0), Vector2(6.0, meter.size.y - 4.0)), Color.WHITE)


func _zone_color(zone: int) -> Color:
	if zone == Zone.RED:
		return COLOR_METER_RED
	if zone == Zone.ORANGE:
		return COLOR_METER_ORANGE
	return COLOR_METER_GREEN
