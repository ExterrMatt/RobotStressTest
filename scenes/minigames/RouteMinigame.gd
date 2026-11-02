class_name RouteMinigame
extends Minigame
## Shared base for the two route minigames (RouteDragMinigame, RouteSlideMinigame):
## a winding corridor of grid cells with a start (green) and a target (X). Each round
## picks one of SHAPES at random, optionally mirrored and/or run backwards, and fits
## it to the board - or, for a limb move (`move` / `roll`), a route shaped like the move.
## Subclasses call _load_random_route() from _setup_game() and _draw_route() from
## _draw_game(), then layer their own player piece on top.
## Compact (limb moves): just the corridor, at the size it would have on the full board,
## with no floor or hint and the board trimmed down to fit it.

## Route layouts, one string per grid row: "S" start, "X" target, "#" corridor,
## "." empty. Every row of a shape is the same width.
const SHAPES: Array = [
	["#X", "S."],
	["X", "#", "S"],
	["###", "#.#", "S.X"],
	["S#X"],
	["X##S"],
	["..#S", ".##.", "X#.."],
	["S.", "#.", "#X"],
	["S#..", ".##.", "..#X"],
	["S#", ".X"],
	["##S", "X.."],
	["X##.", "..#S"],
	["X.", "#.", "##", ".S"],
	["S##.", "..#.", "..##", "...X"],
	["X#.", ".#.", ".##", "..S"],
]

## Largest a cell may be drawn, so short routes don't blow up to fill the board.
const MAX_CELL: float = 84.0
## Gap between the play area and the route's bounding box.
const ROUTE_MARGIN: float = 18.0
## Height of the hint strip above the route.
const HINT_HEIGHT: float = 14.0
## Compact: the space round the corridor.
const COMPACT_PAD: float = 6.0
## Limb moves: art pixels of travel per route step, the most steps along either axis, and
## the fewest a route gets (a move too small to make out still gets a short run its way).
const MOVE_PX_PER_STEP: float = 24.0
const MOVE_MAX_STEPS: int = 5
const MOVE_MIN_STEPS: int = 2
## A move slanted this little or less (its sideways travel against its main travel) takes
## one sideways step at most, so its main direction reads clearly.
const MOVE_SLIGHT_SLANT: float = 0.45

const COL_FLOOR := Color(0.02, 0.025, 0.03)
const COL_ROUTE := Color(0.12, 0.2, 0.15)
const COL_DIVIDER := Color(1.0, 1.0, 1.0, 0.1)
const COL_WALL := Color(0.85, 0.22, 0.18)
const COL_PIECE := Color(0.3, 1.0, 0.25)
const COL_TARGET := Color(1.0, 0.45, 0.1)
const WALL_WIDTH: float = 4.0

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Route cells (Vector2i -> true).
var _cells: Dictionary = {}
var _start_cell: Vector2i = Vector2i.ZERO
var _goal_cell: Vector2i = Vector2i.ZERO
var _cell_size: float = 64.0
## Board-local top-left of grid cell (0, 0).
var _origin: Vector2 = Vector2.ZERO
## Wall segments [a, b] along every corridor side that doesn't open onto another cell.
var _walls: Array = []
## Limb moves (set before the game opens): the move the route traces - the way the limb
## travels on screen, as far as it travels (art pixels). The route runs that way, longer
## the further the limb goes, and starts over the limb. Zero: a random SHAPES route.
var move: Vector2 = Vector2.ZERO
## Turning her over: an arch (up, across and back down) starting over her.
var roll: bool = false


func _load_random_route() -> void:
	var path: Array[Vector2i] = []
	if roll:
		path = _roll_path()
	elif move != Vector2.ZERO:
		path = _move_path(move)
	if path.is_empty():
		_load_shape()
	else:
		_set_cells(path, path[0], path[-1])
	_lay_out_route()


## One of SHAPES, maybe mirrored and/or run backwards.
func _load_shape() -> void:
	var rows: Array = SHAPES[rng.randi() % SHAPES.size()]
	var mirror := rng.randf() < 0.5
	var reverse := rng.randf() < 0.5
	var width: int = String(rows[0]).length()
	var cells: Array[Vector2i] = []
	var start := Vector2i.ZERO
	var goal := Vector2i.ZERO
	for y in rows.size():
		var row: String = rows[y]
		for x in width:
			var ch := row[x]
			if ch == ".":
				continue
			var cell := Vector2i(width - 1 - x if mirror else x, y)
			cells.append(cell)
			if ch == "S":
				start = cell
			elif ch == "X":
				goal = cell
	if reverse:
		_set_cells(cells, goal, start)
	else:
		_set_cells(cells, start, goal)


## A limb move's route: steps the way the limb goes, as many as its travel calls for. A
## slanted move runs along its main direction and takes the sideways part in one or two
## jogs on the way (a step out and up is just that; a big swing up is a long climb with
## at most a step aside).
func _move_path(v: Vector2) -> Array[Vector2i]:
	var steps := v / MOVE_PX_PER_STEP
	var longest := maxf(absf(steps.x), absf(steps.y))
	if longest > MOVE_MAX_STEPS:
		steps *= MOVE_MAX_STEPS / longest
	var count := Vector2i(roundi(absf(steps.x)), roundi(absf(steps.y)))
	if minf(absf(steps.x), absf(steps.y)) < MOVE_SLIGHT_SLANT * maxf(absf(steps.x), absf(steps.y)):
		if absf(steps.x) >= absf(steps.y):
			count.y = mini(count.y, 1)
		else:
			count.x = mini(count.x, 1)
	# Too small to make out: a short run along its main direction.
	var short := MOVE_MIN_STEPS - count.x - count.y
	if short > 0:
		if absf(steps.x) >= absf(steps.y):
			count.x += short
		else:
			count.y += short
	var dir_x := Vector2i(1 if v.x >= 0.0 else -1, 0)
	var dir_y := Vector2i(0, 1 if v.y >= 0.0 else -1)
	# The main direction has the most steps (a tie goes either way).
	var x_main := count.x > count.y or (count.x == count.y and rng.randf() < 0.5)
	var main_dir := dir_x if x_main else dir_y
	var side_dir := dir_y if x_main else dir_x
	var main_count := count.x if x_main else count.y
	var side_count := count.y if x_main else count.x
	# The sideways steps: one jog, or (two or more of them) sometimes two, each at a random
	# point along the run.
	var jogs: Array[int] = []
	if side_count > 0:
		if side_count >= 2 and rng.randf() < 0.5:
			var first := 1 + rng.randi() % (side_count - 1)
			jogs = [first, side_count - first]
		else:
			jogs = [side_count]
	var jog_at: Array[int] = []
	for _jog in jogs:
		jog_at.append(rng.randi() % (main_count + 1))
	jog_at.sort()
	var path: Array[Vector2i] = [Vector2i.ZERO]
	var next_jog := 0
	for i in main_count + 1:
		while next_jog < jog_at.size() and jog_at[next_jog] == i:
			for _step in jogs[next_jog]:
				path.append(path[-1] + side_dir)
			next_jog += 1
		if i < main_count:
			path.append(path[-1] + main_dir)
	return path


## Turning her over: up, across and back down - an arch, over to one side or the other.
func _roll_path() -> Array[Vector2i]:
	var rise := 1 + rng.randi() % 2
	var across := 2 + rng.randi() % 2
	var side := Vector2i.RIGHT if rng.randf() < 0.5 else Vector2i.LEFT
	var path: Array[Vector2i] = [Vector2i.ZERO]
	for _step in rise:
		path.append(path[-1] + Vector2i.UP)
	for _step in across:
		path.append(path[-1] + side)
	for _step in rise:
		path.append(path[-1] + Vector2i.DOWN)
	return path


## Stores the route, shifted so its top-left cell is (0, 0).
func _set_cells(cells: Array[Vector2i], start: Vector2i, goal: Vector2i) -> void:
	var low: Vector2i = cells[0]
	for cell in cells:
		low = low.min(cell)
	_cells.clear()
	for cell in cells:
		_cells[cell - low] = true
	_start_cell = start - low
	_goal_cell = goal - low


## Sizes the cells and places the grid on the board.
func _lay_out_route() -> void:
	var dims := Vector2i.ONE
	for cell in _cells:
		dims = dims.max(cell + Vector2i.ONE)
	var width := dims.x
	var height := dims.y
	if compact:
		# Cells as big as on the full board; the board trims down to the corridor, with
		# room along the top for the X.
		_cell_size = _full_board_cell_size(width, height)
		var top := compact_top_reserve()
		_origin = Vector2(COMPACT_PAD, COMPACT_PAD + top)
		set_board_size(Vector2(width, height) * _cell_size + Vector2(COMPACT_PAD * 2.0, COMPACT_PAD * 2.0 + top))
	else:
		var area := content_rect(ROUTE_MARGIN)
		# Leave a strip along the top for the hint line.
		area = area.grow_side(SIDE_TOP, -HINT_HEIGHT)
		_cell_size = minf(MAX_CELL, minf(area.size.x / width, area.size.y / height))
		_origin = (area.get_center() - Vector2(width, height) * _cell_size * 0.5).round()
	_build_walls()


## A limb move's route starts over the limb, running off the way the limb goes.
func _compact_anchor() -> Vector2:
	if roll or move != Vector2.ZERO:
		return cell_center(_start_cell)
	return super()


## The cell size this route gets on the standard full board (its play area, less the hint
## strip), whatever size the board is now.
func _full_board_cell_size(width: int, height: int) -> float:
	var board_px := (get_viewport_rect().size * BOARD_VIEWPORT_RATIO).round()
	var area := board_px - Vector2(ROUTE_MARGIN * 2.0, HEADER_HEIGHT + ROUTE_MARGIN * 2.0 + HINT_HEIGHT)
	return minf(MAX_CELL, minf(area.x / width, area.y / height))


func _build_walls() -> void:
	_walls.clear()
	for cell in _cells:
		var r := cell_rect(cell)
		var corners := {
			Vector2i.UP: [r.position, Vector2(r.end.x, r.position.y)],
			Vector2i.DOWN: [Vector2(r.position.x, r.end.y), r.end],
			Vector2i.LEFT: [r.position, Vector2(r.position.x, r.end.y)],
			Vector2i.RIGHT: [Vector2(r.end.x, r.position.y), r.end],
		}
		for dir in DIRS:
			if not is_route(cell + dir):
				_walls.append(corners[dir])


func is_route(cell: Vector2i) -> bool:
	return _cells.has(cell)


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(cell) * _cell_size, Vector2.ONE * _cell_size)


func cell_center(cell: Vector2i) -> Vector2:
	return cell_rect(cell).get_center()


func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(((pos - _origin) / _cell_size).floor())


## Distance from `pos` to the nearest corridor wall.
func distance_to_wall(pos: Vector2) -> float:
	var best := INF
	for seg in _walls:
		var p := Geometry2D.get_closest_point_to_segment(pos, seg[0], seg[1])
		best = minf(best, pos.distance_to(p))
	return best


# --- drawing ----------------------------------------------------------------

func _draw_route() -> void:
	if not compact:
		board.draw_rect(content_rect(10.0), COL_FLOOR)
	for cell in _cells:
		board.draw_rect(cell_rect(cell), COL_ROUTE)
	# Faint dividers between neighbouring cells, so the grid steps read clearly.
	for cell in _cells:
		var r := cell_rect(cell)
		if is_route(cell + Vector2i.RIGHT):
			board.draw_line(Vector2(r.end.x, r.position.y + 6.0), Vector2(r.end.x, r.end.y - 6.0), COL_DIVIDER, 2.0)
		if is_route(cell + Vector2i.DOWN):
			board.draw_line(Vector2(r.position.x + 6.0, r.end.y), Vector2(r.end.x - 6.0, r.end.y), COL_DIVIDER, 2.0)
	for seg in _walls:
		board.draw_line(seg[0], seg[1], COL_WALL, WALL_WIDTH)
	# Square off the wall corners so the outline reads as one solid line.
	for seg in _walls:
		for p in seg:
			board.draw_rect(Rect2(p - Vector2.ONE * WALL_WIDTH * 0.5, Vector2.ONE * WALL_WIDTH), COL_WALL)
	_draw_target()


func _draw_target() -> void:
	var c := cell_center(_goal_cell)
	var s := _cell_size * 0.22
	board.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), COL_TARGET, 5.0, true)
	board.draw_line(c + Vector2(s, -s), c + Vector2(-s, s), COL_TARGET, 5.0, true)


## Small instruction line across the top of the play area, hidden once the round ends.
func _draw_hint(text: String) -> void:
	if solved or lost or compact:
		return
	var area := content_rect(10.0)
	draw_text_centered(text, Vector2(area.get_center().x, area.position.y + 16.0), 16, Color(COL_TEXT, 0.75))
