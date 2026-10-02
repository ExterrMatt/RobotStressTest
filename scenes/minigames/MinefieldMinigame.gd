class_name MinefieldMinigame
extends Minigame
## Guide the green dot to the X through a dark minefield. Press on the dot and keep
## the mouse held the whole way - letting go loses, and so does touching a mine.
## Only a small circle around the dot is lit, so mines are hidden until you get
## close; the X stays visible at all times.
##
## Layout is random each round but evenly spread: mines are placed by dart throwing
## with a minimum spacing (no clusters or overlaps, and every gap between two mines
## is wide enough for the dot), and the start and goal always sit on roughly
## opposite sides of the field.

const PLAYER_RADIUS: float = 7.0
## How close the press must land to the dot to pick it up.
const GRAB_RADIUS: float = 20.0
const GOAL_RADIUS: float = 16.0
const MINE_RADIUS_RANGE: Vector2 = Vector2(11.0, 17.0)
## Minimum distance between mine centres. With the largest mines that still leaves
## (MINE_SPACING - 2 * max radius) of clearance, comfortably wider than the dot.
const MINE_SPACING: float = 66.0
const MINE_COUNT: int = 22
## Mines keep this far from the start and goal.
const SAFE_ZONE: float = 58.0
## Radius of the lit circle around the dot; mines fade in over VIEW_FADE before it.
const VIEW_RADIUS: float = 70.0
const VIEW_FADE: float = 22.0
## Max distance per collision sub-step, so fast mouse moves can't skip over a mine.
const SWEEP_STEP: float = 3.0

const COL_FIELD := Color(0.02, 0.025, 0.03)
const COL_PLAYER := Color(0.3, 1.0, 0.25)
const COL_MINE := Color(0.0, 0.5, 0.33)
const COL_GOAL := Color(0.95, 0.15, 0.12)

var _player: Vector2
var _start: Vector2
var _goal: Vector2
var _mines: Array[Vector2] = []
var _mine_radii: Array[float] = []
var _holding: bool = false
## Index of the mine that was hit (drawn highlighted), or -1.
var _hit_mine: int = -1


func _init() -> void:
	title = "MINEFIELD"


func _field() -> Rect2:
	return content_rect(10.0)


func _setup_game() -> void:
	_holding = false
	_hit_mine = -1
	_place_start_and_goal()
	_player = _start
	_place_mines()


## Start and goal on opposite sides: pick a random direction through the centre and
## project both ways onto a slightly inset field boundary.
func _place_start_and_goal() -> void:
	var f := _field().grow(-26.0)
	var c := f.get_center()
	var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
	_start = c - dir * _ray_to_edge(f, -dir)
	_goal = c + dir * _ray_to_edge(f, dir)


## Distance from the rect's centre to its edge along `dir`.
func _ray_to_edge(r: Rect2, dir: Vector2) -> float:
	var half := r.size * 0.5
	var tx := INF if is_zero_approx(dir.x) else half.x / absf(dir.x)
	var ty := INF if is_zero_approx(dir.y) else half.y / absf(dir.y)
	return minf(tx, ty)


func _place_mines() -> void:
	_mines.clear()
	_mine_radii.clear()
	var f := _field().grow(-MINE_RADIUS_RANGE.y)
	var attempts := 0
	while _mines.size() < MINE_COUNT and attempts < 4000:
		attempts += 1
		var p := Vector2(rng.randf_range(f.position.x, f.end.x), rng.randf_range(f.position.y, f.end.y))
		if p.distance_to(_start) < SAFE_ZONE or p.distance_to(_goal) < SAFE_ZONE:
			continue
		var ok := true
		for m in _mines:
			if m.distance_to(p) < MINE_SPACING:
				ok = false
				break
		if ok:
			_mines.append(p)
			_mine_radii.append(rng.randf_range(MINE_RADIUS_RANGE.x, MINE_RADIUS_RANGE.y))


# --- input ------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not _holding and event.position.distance_to(_player) <= GRAB_RADIUS:
				_holding = true
		elif _holding:
			# Let go before reaching the X.
			_holding = false
			_lose()
	elif event is InputEventMouseMotion and _holding:
		_move_player_to(event.position)


## Moves the dot toward `target` in small steps, checking mines along the way.
func _move_player_to(target: Vector2) -> void:
	var f := _field().grow(-PLAYER_RADIUS)
	target = target.clamp(f.position, f.end)
	var dist := _player.distance_to(target)
	var steps := maxi(1, ceili(dist / SWEEP_STEP))
	var from := _player
	for s in range(1, steps + 1):
		_player = from.lerp(target, float(s) / steps)
		for i in _mines.size():
			if _player.distance_to(_mines[i]) <= _mine_radii[i] + PLAYER_RADIUS:
				_hit_mine = i
				_holding = false
				_lose()
				return
		if _player.distance_to(_goal) <= GOAL_RADIUS:
			_holding = false
			_win()
			return


# --- drawing ----------------------------------------------------------------

func _draw_game() -> void:
	var f := _field()
	board.draw_rect(f, COL_FIELD)

	# Soft lit pool around the dot (concentric rings fading out).
	var rings := 8
	for k in range(rings, 0, -1):
		var t := float(k) / rings
		board.draw_circle(_player, VIEW_RADIUS * t, Color(0.13, 0.16, 0.14, 0.22))

	# Mines: only inside the view (fading at its rim), except all are revealed once
	# the round is over so the player can see what they missed.
	var reveal_all := solved or lost
	for i in _mines.size():
		var d := _player.distance_to(_mines[i]) - _mine_radii[i]
		var a := 1.0 if reveal_all else clampf((VIEW_RADIUS - d) / VIEW_FADE, 0.0, 1.0)
		if a <= 0.0:
			continue
		var col := COL_BAD if i == _hit_mine else COL_MINE
		col.a = a
		board.draw_circle(_mines[i], _mine_radii[i], col)

	_draw_goal()
	_mask_outside_field(f)

	# The player dot (with a pulse while waiting to be picked up).
	if not _holding and not solved and not lost:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		board.draw_arc(_player, GRAB_RADIUS * (0.7 + 0.3 * pulse), 0, TAU, 32, Color(COL_PLAYER, 0.6), 2.0)
		draw_text_centered("Hold the dot - don't let go", Vector2(f.get_center().x, f.position.y + 18.0), 13,
				Color(COL_TEXT, 0.75))
	board.draw_circle(_player, PLAYER_RADIUS, COL_PLAYER)


## Repaints the frame around the field so the light pool / mines never bleed onto it.
func _mask_outside_field(f: Rect2) -> void:
	var s := bsize()
	board.draw_rect(Rect2(0, HEADER_HEIGHT, f.position.x, s.y - HEADER_HEIGHT), COL_PANEL)
	board.draw_rect(Rect2(f.end.x, HEADER_HEIGHT, s.x - f.end.x, s.y - HEADER_HEIGHT), COL_PANEL)
	board.draw_rect(Rect2(0, HEADER_HEIGHT, s.x, f.position.y - HEADER_HEIGHT), COL_PANEL)
	board.draw_rect(Rect2(0, f.end.y, s.x, s.y - f.end.y), COL_PANEL)
	board.draw_rect(Rect2(Vector2(1.5, 1.5), s - Vector2(3, 3)), COL_BORDER, false, 3.0)


func _draw_goal() -> void:
	var s := GOAL_RADIUS * 0.8
	board.draw_line(_goal + Vector2(-s, -s), _goal + Vector2(s, s), COL_GOAL, 4.0, true)
	board.draw_line(_goal + Vector2(s, -s), _goal + Vector2(-s, s), COL_GOAL, 4.0, true)
