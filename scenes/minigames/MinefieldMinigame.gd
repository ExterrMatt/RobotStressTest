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
## opposite sides of the field. Each mine is one of the sprites on the mines sheet, picked
## at random; its size sets how close the dot can get.

const BOARD_TEXTURE_PATH: String = "res://assets/textures/icons/minefield_minigame.png"
## The art's title strip and the buttons drawn into it (art pixels). The buttons carry their
## own labels.
const ART_HEADER: Dictionary = {
	"height": 20.0,
	"restart": Rect2(254, 3, 27, 15),
	"close": Rect2(283, 3, 14, 15),
}
## The play area on the board art (art pixels): everything inside its frame, below the title.
const FIELD_ART_RECT: Rect2 = Rect2(2, 20, 296, 178)

const PLAYER_RADIUS: float = 7.0
## How close the press must land to the dot to pick it up.
const GRAB_RADIUS: float = 20.0
const GOAL_RADIUS: float = 16.0
const MINES_TEXTURE_PATH: String = "res://assets/textures/icons/mines.png"
## The mines on the sheet (art pixels): two large, a medium one and four small ones.
const MINE_SPRITES: Array[Rect2i] = [
	Rect2i(0, 0, 16, 16), Rect2i(16, 0, 16, 16), Rect2i(0, 16, 14, 14),
	Rect2i(14, 16, 8, 8), Rect2i(22, 16, 8, 8), Rect2i(14, 24, 6, 6), Rect2i(20, 24, 6, 6),
]
## Board pixels per art pixel (whole, so the pixel art stays crisp).
const MINE_SCALE: float = 3.0
## The largest mine's radius on the board (the 16px sprites), for keeping mines inside the field.
const MAX_MINE_RADIUS: float = 8.0 * MINE_SCALE
## Minimum distance between mine centres. With the largest mines that still leaves
## (MINE_SPACING - 2 * MAX_MINE_RADIUS) of clearance, still wider than the dot.
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
## Which MINE_SPRITES entry each mine is drawn with.
var _mine_sprites: Array[int] = []
var _mines_tex: Texture2D
var _board_tex: Texture2D
var _holding: bool = false
## Index of the mine that was hit (drawn highlighted), or -1.
var _hit_mine: int = -1


func _init() -> void:
	title = "MINEFIELD"
	_board_tex = load(BOARD_TEXTURE_PATH) as Texture2D


func _board_art_size() -> Vector2:
	return _board_tex.get_size() if _board_tex != null else Vector2.ZERO


func _art_header() -> Dictionary:
	return ART_HEADER if _board_tex != null else {}


## The art's buttons are already labelled: just the title.
func _draw_art_header_labels(header: Dictionary) -> void:
	var mid := (header["restart"] as Rect2).get_center()
	var title_room := (header["restart"] as Rect2).position.x - ART_TITLE_GAP - ART_TITLE_LEFT
	draw_art_text(title, Vector2(ART_TITLE_LEFT, mid.y), ART_TITLE_FONT_SIZE, false, COL_TEXT, title_room)


func _field() -> Rect2:
	return art_to_board(FIELD_ART_RECT) if _board_tex != null else content_rect(10.0)


func _setup_game() -> void:
	_mines_tex = load(MINES_TEXTURE_PATH) as Texture2D
	# Pixel art: keep it crisp when scaled up.
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_mine_sprites.clear()
	var f := _field().grow(-MAX_MINE_RADIUS)
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
			var sprite := rng.randi_range(0, MINE_SPRITES.size() - 1)
			_mines.append(p)
			_mine_sprites.append(sprite)
			_mine_radii.append(MINE_SPRITES[sprite].size.x * MINE_SCALE * 0.5)


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
	if _board_tex != null:
		board.draw_texture_rect(_board_tex, art_rect(), false)
	else:
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
		_draw_mine(i, a)

	_draw_goal()
	_mask_outside_field(f)

	# The player dot (with a pulse while waiting to be picked up).
	if not _holding and not solved and not lost:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		board.draw_arc(_player, GRAB_RADIUS * (0.7 + 0.3 * pulse), 0, TAU, 32, Color(COL_PLAYER, 0.6), 2.0)
		draw_text_centered("Hold the dot - don't let go", Vector2(f.get_center().x, f.position.y + 18.0), 16,
				Color(COL_TEXT, 0.75))
	board.draw_circle(_player, PLAYER_RADIUS, COL_PLAYER)


## Repaints the frame around the field so the light pool / mines never bleed onto it.
func _mask_outside_field(f: Rect2) -> void:
	var s := bsize()
	if _board_tex != null:
		# The board art outside the field (title strip, sides, bottom), then the gold border.
		var art := Rect2(Vector2.ZERO, _board_art_size())
		var field := FIELD_ART_RECT
		for src in [
			Rect2(art.position, Vector2(art.size.x, field.position.y)),
			Rect2(0, field.position.y, field.position.x, field.size.y),
			Rect2(field.end.x, field.position.y, art.end.x - field.end.x, field.size.y),
			Rect2(0, field.end.y, art.size.x, art.end.y - field.end.y),
		]:
			board.draw_texture_rect_region(_board_tex, art_to_board(src), src)
		board.draw_rect(Rect2(Vector2.ONE * BORDER_WIDTH * 0.5, s - Vector2.ONE * BORDER_WIDTH), COL_BORDER, false, BORDER_WIDTH)
		return
	board.draw_rect(Rect2(0, HEADER_HEIGHT, f.position.x, s.y - HEADER_HEIGHT), COL_PANEL)
	board.draw_rect(Rect2(f.end.x, HEADER_HEIGHT, s.x - f.end.x, s.y - HEADER_HEIGHT), COL_PANEL)
	board.draw_rect(Rect2(0, HEADER_HEIGHT, s.x, f.position.y - HEADER_HEIGHT), COL_PANEL)
	board.draw_rect(Rect2(0, f.end.y, s.x, s.y - f.end.y), COL_PANEL)
	board.draw_rect(Rect2(Vector2(1.5, 1.5), s - Vector2(3, 3)), COL_BORDER, false, 3.0)


## Mine `i` at `alpha`: its sprite centred on it, ringed in red if it's the one that was hit.
func _draw_mine(i: int, alpha: float) -> void:
	var r := _mine_radii[i]
	if _mines_tex == null:
		board.draw_circle(_mines[i], r, Color(COL_MINE, alpha))
	else:
		var src := Rect2(MINE_SPRITES[_mine_sprites[i]])
		var dest := Rect2((_mines[i] - Vector2.ONE * r).round(), src.size * MINE_SCALE)
		board.draw_texture_rect_region(_mines_tex, dest, src, Color(1, 1, 1, alpha))
	if i == _hit_mine:
		board.draw_arc(_mines[i], r + 3.0, 0, TAU, 32, COL_BAD, 2.0, true)


func _draw_goal() -> void:
	var s := GOAL_RADIUS * 0.8
	board.draw_line(_goal + Vector2(-s, -s), _goal + Vector2(s, s), COL_GOAL, 4.0, true)
	board.draw_line(_goal + Vector2(s, -s), _goal + Vector2(-s, s), COL_GOAL, 4.0, true)
