class_name RouteDragMinigame
extends RouteMinigame
## Steady hand: press on the green dot and drag it along the corridor to the X.
## Touching a wall fails the round. Letting go just drops the dot where it is, so
## it can be picked back up.

## Dot radius as a fraction of the cell size (the corridor is one cell wide).
const PIECE_RADIUS_RATIO: float = 0.2
## Extra slop around the dot for picking it up.
const GRAB_SLOP: float = 10.0
## The dot has to get this close (as a fraction of the cell) to the X's centre.
const GOAL_RADIUS_RATIO: float = 0.25
## Max distance per collision sub-step, so fast mouse moves can't skip a wall.
const SWEEP_STEP: float = 3.0

var _piece: Vector2 = Vector2.ZERO
var _radius: float = 10.0
var _holding: bool = false
## The dot hit a wall (drawn red).
var _hit: bool = false


func _init() -> void:
	title = "STEADY HAND"


func _setup_game() -> void:
	_load_random_route()
	_piece = cell_center(_start_cell)
	_radius = _cell_size * PIECE_RADIUS_RATIO
	_holding = false
	_hit = false


func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.distance_to(_piece) <= _radius + GRAB_SLOP:
				_holding = true
		else:
			_holding = false
	elif event is InputEventMouseMotion and _holding:
		_move_piece_to(event.position)


## Moves the dot toward `target` in small steps, checking the walls along the way.
func _move_piece_to(target: Vector2) -> void:
	var from := _piece
	var steps := maxi(1, ceili(from.distance_to(target) / SWEEP_STEP))
	for s in range(1, steps + 1):
		_piece = from.lerp(target, float(s) / steps)
		if not is_route(cell_at(_piece)) or distance_to_wall(_piece) < _radius:
			_hit = true
			_holding = false
			_lose()
			return
		if _piece.distance_to(cell_center(_goal_cell)) <= _cell_size * GOAL_RADIUS_RATIO:
			_holding = false
			_win()
			return


func _draw_game() -> void:
	_draw_route()
	if not _holding and not solved and not lost:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		board.draw_arc(_piece, (_radius + GRAB_SLOP) * (0.7 + 0.3 * pulse), 0, TAU, 32, Color(COL_PIECE, 0.6), 2.0)
	board.draw_circle(_piece, _radius, COL_BAD if _hit else COL_PIECE)
	_draw_hint("Drag the dot to the X - don't touch the walls")
