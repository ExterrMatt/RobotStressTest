class_name ScrewTurnMinigame
extends Minigame
## One big screw head. Click and hold anywhere on it, then circle the mouse
## clockwise around its centre - the screw turns with the cursor, pivoting on the
## centre of the art. Drive it in TURNS_REQUIRED full rotations to win. Turning
## counter-clockwise backs it out again (never past where it started).

## Placeholder art until the real screw PNG exists.
const SCREW_TEXTURE_PATH: String = "res://assets/textures/icons/placeholder_item.png"
const TURNS_REQUIRED: float = 2.5
## On-screen diameter of the screw as a fraction of the play area's height.
const SCREW_SIZE_FRACTION: float = 0.66
## Mouse samples this close to the centre give a jumpy angle, so they're ignored.
const DEAD_ZONE: float = 12.0
## How much the head shrinks / darkens as it sinks in (visual "driving in").
const SINK_SCALE: float = 0.12

var _tex: Texture2D
## Net clockwise rotation in radians (progress); clamped at 0.
var _turned: float = 0.0
var _holding: bool = false
var _last_angle: float = 0.0


func _init() -> void:
	title = "TIGHTEN THE SCREW"


func _setup_game() -> void:
	_tex = load(SCREW_TEXTURE_PATH) as Texture2D
	# Pixel art: keep it crisp when scaled up.
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_turned = 0.0
	_holding = false


func _center() -> Vector2:
	return content_rect(0.0).get_center() + Vector2(0, -10)


func _radius() -> float:
	return content_rect(0.0).size.y * SCREW_SIZE_FRACTION * 0.5


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
	var c := _center()
	var r := _radius()
	var p := _progress()

	# Progress ring around the screw.
	board.draw_arc(c, r + 16.0, 0, TAU, 64, Color(0.05, 0.05, 0.06), 10.0)
	if p > 0.0:
		board.draw_arc(c, r + 16.0, -PI * 0.5, -PI * 0.5 + TAU * p, 64, COL_GOOD.darkened(0.15), 8.0)
	# Hole / countersink.
	board.draw_circle(c, r * 1.02, Color(0.04, 0.04, 0.05))

	# The screw itself, rotated about its own centre and sinking as it goes in.
	if _tex != null:
		var sink := 1.0 - SINK_SCALE * p
		var draw_size := Vector2.ONE * r * 2.0 * sink
		var shade := Color.WHITE.darkened(0.3 * p)
		board.draw_set_transform(c, _turned, Vector2.ONE)
		board.draw_texture_rect(_tex, Rect2(-draw_size * 0.5, draw_size), false, shade)
		board.draw_set_transform_matrix(Transform2D.IDENTITY)

	var turns := _turned / TAU
	draw_text_centered("%.1f / %.1f turns" % [turns, TURNS_REQUIRED],
			Vector2(c.x, content_rect(0.0).end.y - 14.0), 14, COL_TEXT)
	if _turned <= 0.0 and not _holding:
		draw_text_centered("Hold on the screw and circle clockwise",
				Vector2(c.x, content_rect(0.0).position.y + 14.0), 13, Color(COL_TEXT, 0.7))
