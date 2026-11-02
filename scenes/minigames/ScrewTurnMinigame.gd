class_name ScrewTurnMinigame
extends Minigame
## One big screw head, set over the hole in the mounting plate on the board art
## (big_screw_minigame: the board with its header buttons and the plate). Click and hold
## anywhere on the screw, then circle the mouse clockwise around its centre - the screw
## turns with the cursor. Drive it in TURNS_REQUIRED full rotations to win. Turning
## counter-clockwise backs it out again (never past where it started).

const BOARD_TEXTURE_PATH: String = "res://assets/textures/icons/big_screw_minigame.png"
## The art's title strip and the buttons drawn into it (art pixels).
const ART_HEADER: Dictionary = {
	"height": 31.0,
	"restart": Rect2(127, 5, 46, 17),
	"close": Rect2(178, 5, 17, 17),
}
## The screw head's art: square frames stacked top to bottom, its cross turned a step
## further clockwise in each (the shine stays put). The cross looks the same every quarter
## turn, so the frames cover one quarter turn and repeat; the screw shows the frame nearest
## its angle instead of rotating the art (which would smear the pixels).
const SCREW_TEXTURE_PATH: String = "res://assets/textures/icons/big_screw.png"
const SCREW_FRAMES: int = 4
## Top-left of the screw head on the board art (art pixels): centred over the plate's hole.
const SCREW_ART_POS: Vector2 = Vector2(66, 96)
## Where the hint and the turn count sit on the board art (art pixels): the middle of the
## gap above the plate, and of the gap below it.
const HINT_ART_POS: Vector2 = Vector2(100, 54.5)
const COUNT_ART_POS: Vector2 = Vector2(100, 205)
## Text size (art pixels) and the widest the hint may run.
const TEXT_ART_SIZE: float = 10.0
const HINT_ART_MAX_WIDTH: float = 184.0
const TURNS_REQUIRED: float = 2.5
## Mouse samples this close to the centre give a jumpy angle, so they're ignored.
const DEAD_ZONE: float = 12.0
## How much the head darkens as it sinks in (visual "driving in").
const SINK_SHADE: float = 0.3

var _board_tex: Texture2D
var _tex: Texture2D
## Size of one frame of the screw art (art pixels).
var _frame_size: float = 1.0
## Net clockwise rotation in radians (progress); clamped at 0.
var _turned: float = 0.0
var _holding: bool = false
var _last_angle: float = 0.0


func _init() -> void:
	title = "TIGHTEN THE SCREW"
	_board_tex = load(BOARD_TEXTURE_PATH) as Texture2D


func _board_art_size() -> Vector2:
	return _board_tex.get_size() if _board_tex != null else Vector2.ZERO


func _art_header() -> Dictionary:
	return ART_HEADER if _board_tex != null else {}


func _setup_game() -> void:
	_tex = load(SCREW_TEXTURE_PATH) as Texture2D
	if _tex != null:
		_frame_size = _tex.get_size().x
	# Pixel art: keep it crisp when scaled up.
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_turned = 0.0
	_holding = false


## Where the screw head is drawn (board pixels).
func _screw_rect() -> Rect2:
	return art_to_board(Rect2(SCREW_ART_POS, Vector2.ONE * _frame_size))


func _center() -> Vector2:
	return _screw_rect().get_center()


func _radius() -> float:
	return _screw_rect().size.x * 0.5


func _progress() -> float:
	return clampf(_turned / (TURNS_REQUIRED * TAU), 0.0, 1.0)


# --- input ------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var offset: Vector2 = event.position - _center()
			if offset.length() <= _radius():
				_holding = true
				_last_angle = offset.angle()
		else:
			_holding = false
	elif event is InputEventMouseMotion and _holding:
		var offset: Vector2 = event.position - _center()
		if offset.length() < DEAD_ZONE:
			return
		var angle := offset.angle()
		# y points down on screen, so a positive angle delta is clockwise.
		var delta := wrapf(angle - _last_angle, -PI, PI)
		_last_angle = angle
		_turned = clampf(_turned + delta, 0.0, TURNS_REQUIRED * TAU)
		if _turned >= TURNS_REQUIRED * TAU:
			_holding = false
			_win()


# --- drawing ----------------------------------------------------------------

func _draw_game() -> void:
	if _board_tex != null:
		board.draw_texture_rect(_board_tex, art_rect(), false)

	# The screw itself: the frame nearest its angle, darkening as it sinks in.
	if _tex != null:
		var step := (TAU / 4.0) / SCREW_FRAMES
		var frame := posmod(int(roundf(_turned / step)), SCREW_FRAMES)
		var src := Rect2(0, frame * _frame_size, _frame_size, _frame_size)
		var shade := Color.WHITE.darkened(SINK_SHADE * _progress())
		board.draw_texture_rect_region(_tex, _screw_rect(), src, shade)

	var turns := _turned / TAU
	draw_art_text("%.1f / %.1f turns" % [turns, TURNS_REQUIRED], COUNT_ART_POS, TEXT_ART_SIZE, true)
	if _turned <= 0.0 and not _holding:
		draw_art_text("Hold on the screw and circle clockwise", HINT_ART_POS, TEXT_ART_SIZE, true,
				Color(COL_TEXT, 0.7), HINT_ART_MAX_WIDTH)
