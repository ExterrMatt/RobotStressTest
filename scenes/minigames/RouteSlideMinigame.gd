class_name RouteSlideMinigame
extends RouteMinigame
## The easy route game: a block sits on the route's grid and slides one cell at a
## time toward wherever it's pointed. Drag it along the corridor (it snaps from
## cell to cell, never leaving the route), click a neighbouring cell, or use the
## arrow keys / WASD. There's no way to fail - reach the X to win.

## Block size as a fraction of the cell.
const PIECE_SIZE_RATIO: float = 0.6
## How quickly the drawn block glides into its new cell (higher = snappier).
const SLIDE_SPEED: float = 16.0

const KEY_DIRS: Dictionary = {
	KEY_UP: Vector2i.UP, KEY_W: Vector2i.UP,
	KEY_DOWN: Vector2i.DOWN, KEY_S: Vector2i.DOWN,
	KEY_LEFT: Vector2i.LEFT, KEY_A: Vector2i.LEFT,
	KEY_RIGHT: Vector2i.RIGHT, KEY_D: Vector2i.RIGHT,
}

var _cell: Vector2i = Vector2i.ZERO
## Where the block is drawn; eases toward the centre of _cell.
var _draw_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _init() -> void:
	title = "SLIDE ROUTE"


func _setup_game() -> void:
	_load_random_route()
	_cell = _start_cell
	_draw_pos = cell_center(_cell)
	_dragging = false


func _input(event: InputEvent) -> void:
	super(event)
	if solved or lost or not (event is InputEventKey) or not event.pressed:
		return
	if KEY_DIRS.has(event.keycode):
		_step(KEY_DIRS[event.keycode])
		get_viewport().set_input_as_handled()


func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var clicked := cell_at(event.position)
			if clicked == _cell:
				_dragging = true
			else:
				_slide_toward(clicked)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_slide_toward(cell_at(event.position))


## Walks the block cell by cell toward `target`, stopping where the route turns away.
func _slide_toward(target: Vector2i) -> void:
	for _i in 8:
		if _cell == target or solved:
			return
		var delta := target - _cell
		var primary := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		var secondary := Vector2i(0, signi(delta.y)) if primary.x != 0 else Vector2i(signi(delta.x), 0)
		if not _step(primary) and (secondary == Vector2i.ZERO or not _step(secondary)):
			return


## Moves one cell in `dir` if the route continues that way. Returns whether it moved.
func _step(dir: Vector2i) -> bool:
	if solved or not is_route(_cell + dir):
		return false
	_cell += dir
	if _cell == _goal_cell:
		_dragging = false
		_win()
	return true


func _game_process(delta: float) -> void:
	_draw_pos = _draw_pos.lerp(cell_center(_cell), 1.0 - exp(-SLIDE_SPEED * delta))


func _draw_game() -> void:
	_draw_route()
	var half := _cell_size * PIECE_SIZE_RATIO * 0.5
	var rect := Rect2(_draw_pos - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	board.draw_rect(rect, COL_PIECE)
	board.draw_rect(rect, Color(0.0, 0.0, 0.0, 0.35), false, 2.0)
	_draw_hint("Slide the block to the X (drag, click, or arrow keys)")
