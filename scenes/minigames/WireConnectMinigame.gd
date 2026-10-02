class_name WireConnectMinigame
extends Minigame
## Among Us-style wiring. Each wire is fixed to a plug on the left; its loose end
## starts dropped somewhere in the middle of the board, so the wires begin crossed
## and tangled. Drag a loose end anywhere (it stays where you drop it, so you can
## pull wires apart to see which is which) and drop it on the right-hand terminal
## with the matching symbol. Every plug and terminal carries a symbol as well as a
## colour, so the game never relies on colour alone.

const WIRE_COUNT: int = 4
const PLUG_SIZE: Vector2 = Vector2(42, 34)
const WIRE_WIDTH: float = 9.0
const END_RADIUS: float = 11.0
const SNAP_RADIUS: float = 30.0
const WIRE_SYMBOLS: Array[int] = [Symbol.TRIANGLE, Symbol.STAR, Symbol.BOLT, Symbol.CIRCLE, Symbol.SQUARE, Symbol.DIAMOND]

## Per wire, indexed by its left plug slot (top to bottom):
var _left: Array[int] = []      # symbol
var _ends: Array[Vector2] = []  # loose end position (board-local)
var _bend: Array[Vector2] = []  # curve bulge so wires don't overlap perfectly
var _plugged: Array[int] = []   # right terminal index it's plugged into, or -1
## Symbol per right terminal (top to bottom), a shuffle of _left.
var _right: Array[int] = []
## Wire indices back to front; a grabbed wire moves to the end so it draws on top.
var _draw_order: Array[int] = []
var _dragging: int = -1
var _drag_offset: Vector2 = Vector2.ZERO


func _init() -> void:
	title = "REWIRE"


func _setup_game() -> void:
	_left.clear(); _ends.clear(); _bend.clear(); _plugged.clear(); _right.clear(); _draw_order.clear()
	_dragging = -1
	var pool: Array = WIRE_SYMBOLS.duplicate()
	pool.shuffle()
	for i in WIRE_COUNT:
		_left.append(int(pool[i]))
		_draw_order.append(i)
	_right.assign(_left)
	# At least one terminal out of line, so straight wires never solve it.
	while _right == _left:
		_right.shuffle()

	# Loose ends scattered through the middle, in a different vertical order than
	# their plugs so the wires start crossed.
	var area := content_rect(0.0)
	var rows: Array = range(WIRE_COUNT)
	while rows == range(WIRE_COUNT):
		rows.shuffle()
	for i in WIRE_COUNT:
		var x := rng.randf_range(area.position.x + area.size.x * 0.36, area.position.x + area.size.x * 0.62)
		var y := _slot_y(int(rows[i])) + rng.randf_range(-14.0, 14.0)
		_ends.append(Vector2(x, y))
		_bend.append(Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(25.0, 75.0)))
		_plugged.append(-1)


# --- layout -----------------------------------------------------------------

func _slot_y(i: int) -> float:
	var area := content_rect(26.0)
	return area.position.y + area.size.y * (i + 0.5) / WIRE_COUNT


func _left_plug_rect(i: int) -> Rect2:
	return Rect2(Vector2(content_rect(14.0).position.x + 10.0, _slot_y(i) - PLUG_SIZE.y * 0.5), PLUG_SIZE)


func _right_plug_rect(j: int) -> Rect2:
	var area := content_rect(14.0)
	return Rect2(Vector2(area.end.x - 10.0 - PLUG_SIZE.x, _slot_y(j) - PLUG_SIZE.y * 0.5), PLUG_SIZE)


func _wire_start(i: int) -> Vector2:
	var r := _left_plug_rect(i)
	return Vector2(r.end.x, r.get_center().y)


func _terminal_point(j: int) -> Vector2:
	var r := _right_plug_rect(j)
	return Vector2(r.position.x, r.get_center().y)


func _wire_end(i: int) -> Vector2:
	return _terminal_point(_plugged[i]) if _plugged[i] >= 0 else _ends[i]


# --- input ------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(event.position)
		elif _dragging >= 0:
			_drop()
	elif event is InputEventMouseMotion and _dragging >= 0:
		var area := content_rect(END_RADIUS)
		_ends[_dragging] = (event.position + _drag_offset).clamp(area.position, area.end)


func _try_grab(p: Vector2) -> void:
	# Front-most end wins.
	for k in range(_draw_order.size() - 1, -1, -1):
		var i := _draw_order[k]
		if _plugged[i] >= 0:
			continue
		if p.distance_to(_ends[i]) <= END_RADIUS + 8.0:
			_dragging = i
			_drag_offset = _ends[i] - p
			_draw_order.remove_at(k)
			_draw_order.append(i)
			return


func _drop() -> void:
	var i := _dragging
	_dragging = -1
	for j in WIRE_COUNT:
		var near := _terminal_point(j).distance_to(_ends[i]) <= SNAP_RADIUS \
				or _right_plug_rect(j).grow(4.0).has_point(_ends[i])
		if not near:
			continue
		if _right[j] == _left[i] and not _plugged.has(j):
			_plugged[i] = j
			if not _plugged.has(-1):
				_win()
		else:
			flash(COL_BAD)
			# Bounce the end back off the wrong terminal.
			_ends[i] = _terminal_point(j) + Vector2(-70.0, 0.0)
		return


# --- drawing ----------------------------------------------------------------

func _draw_game() -> void:
	for slot in WIRE_COUNT:
		_draw_plug(_left_plug_rect(slot), _left[slot], true, _plugged[slot] >= 0)
		_draw_plug(_right_plug_rect(slot), _right[slot], false, _plugged.has(slot))
	for i in _draw_order:
		_draw_wire(i)


func _draw_plug(r: Rect2, symbol: int, is_left: bool, done: bool) -> void:
	var col: Color = SYMBOL_COLORS[symbol]
	board.draw_rect(r.grow(2.0), Color(0.05, 0.05, 0.06))
	board.draw_rect(r, Color(0.27, 0.28, 0.3))
	# Coloured socket on the inner edge, symbol on the plate.
	var sock_w := 8.0
	var sock := Rect2(r.end.x - sock_w, r.position.y + 6, sock_w, r.size.y - 12) if is_left \
			else Rect2(r.position.x, r.position.y + 6, sock_w, r.size.y - 12)
	board.draw_rect(sock, col)
	var sym_c := r.get_center() + Vector2(-4.0 if is_left else 4.0, 0.0)
	draw_symbol(symbol, sym_c, 11.0, col)
	# Indicator light on the outer edge.
	var light := Vector2(r.position.x - 10.0, r.get_center().y) if is_left else Vector2(r.end.x + 10.0, r.get_center().y)
	board.draw_circle(light, 4.0, COL_GOOD if done else Color(0.25, 0.1, 0.1))


func _draw_wire(i: int) -> void:
	var a := _wire_start(i)
	var b := _wire_end(i)
	var col: Color = SYMBOL_COLORS[_left[i]]
	# Cubic bezier: leaves the plug heading right, droops by its bend, arrives level.
	var span := maxf(60.0, absf(b.x - a.x))
	var c1 := a + Vector2(span * 0.45 + _bend[i].x, _bend[i].y)
	var c2 := b + Vector2(-span * 0.35, _bend[i].y * 0.6)
	var pts := PackedVector2Array()
	var segs := 28
	for s in segs + 1:
		var t := float(s) / segs
		var u := 1.0 - t
		pts.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	board.draw_polyline(pts, Color(0.03, 0.03, 0.03), WIRE_WIDTH + 4.0, true)
	board.draw_polyline(pts, col, WIRE_WIDTH, true)
	board.draw_polyline(pts, col.lightened(0.35), 2.0, true)
	if _plugged[i] < 0:
		# Bare copper tip on the loose end.
		board.draw_circle(b, END_RADIUS + 2.0, Color(0.03, 0.03, 0.03))
		board.draw_circle(b, END_RADIUS, col.darkened(0.2))
		board.draw_circle(b, END_RADIUS * 0.45, Color(0.85, 0.55, 0.3))
