class_name LeverSequenceMinigame
extends Minigame
## A row of levers plus a sticky note tucked into the board's bottom-right corner.
## Only the note's top-left corner peeks in; clicking it eases the note into view
## (click again to tuck it away), revealing a row of checks and Xs - one per lever.
## Pull down every ✓ lever and leave every ✗ lever up. Pulling an ✗ lever is a
## mistake: sparks, and every lever snaps back up.

const LEVER_COUNT: int = 5
const LEVER_ANIM_TIME: float = 0.12
const NOTE_SIZE: Vector2 = Vector2(210, 120)
## How much of the note's top-left corner shows while it is tucked away.
const NOTE_PEEK: Vector2 = Vector2(46, 34)
const NOTE_SLIDE_TIME: float = 0.45
const NOTE_TILT_TUCKED: float = -0.18
const NOTE_TILT_OPEN: float = -0.04
const COL_NOTE := Color(1.0, 0.92, 0.45)
const COL_NOTE_INK := Color(0.2, 0.18, 0.15)

## Target per lever: true = pull it down (✓), false = leave it up (✗).
var _pattern: Array[bool] = []
## Logical lever states (true = down).
var _down: Array[bool] = []
## Visual lever positions, 0 = up, 1 = down (eased toward _down).
var _anim: Array[float] = []
var _note_open: bool = false
## 0 = tucked, 1 = open; driven by a tween with ease in/out.
var _note_t: float = 0.0
var _note_tween: Tween


func _init() -> void:
	title = "LEVER SEQUENCE"


func _setup_game() -> void:
	_pattern.clear()
	_down.clear()
	_anim.clear()
	# At least one lever of each kind so the note always matters.
	while true:
		_pattern.clear()
		for i in LEVER_COUNT:
			_pattern.append(rng.randf() < 0.5)
		if _pattern.has(true) and _pattern.has(false):
			break
	for i in LEVER_COUNT:
		_down.append(false)
		_anim.append(0.0)
	_set_note_open(false, true)


func _game_process(delta: float) -> void:
	for i in LEVER_COUNT:
		var target := 1.0 if _down[i] else 0.0
		_anim[i] = move_toward(_anim[i], target, delta / LEVER_ANIM_TIME)


# --- layout -----------------------------------------------------------------

func _lever_rect(i: int) -> Rect2:
	var area := content_rect(18.0)
	var slot_w := area.size.x / LEVER_COUNT
	var h := minf(area.size.y * 0.62, 190.0)
	var w := minf(slot_w * 0.55, 60.0)
	return Rect2(area.position.x + slot_w * (i + 0.5) - w * 0.5, area.position.y + 6.0, w, h)


func _note_pos_for(t: float) -> Vector2:
	var s := bsize()
	var tucked := s - NOTE_PEEK
	var open := s - NOTE_SIZE - Vector2(18, 14)
	return tucked.lerp(open, t)


func _note_transform() -> Transform2D:
	var pos := _note_pos_for(_note_t)
	var tilt := lerpf(NOTE_TILT_TUCKED, NOTE_TILT_OPEN, _note_t)
	return Transform2D(tilt, pos)


func _point_on_note(p: Vector2) -> bool:
	var local := _note_transform().affine_inverse() * p
	return Rect2(Vector2.ZERO, NOTE_SIZE).has_point(local)


func _set_note_open(open: bool, instant: bool = false) -> void:
	_note_open = open
	if _note_tween != null and _note_tween.is_valid():
		_note_tween.kill()
	var target := 1.0 if open else 0.0
	if instant:
		_note_t = target
		return
	_note_tween = create_tween()
	_note_tween.tween_property(self, "_note_t", target, NOTE_SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


# --- input ------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	# The note sits on top of everything, so it gets first pick of the click.
	if _point_on_note(p):
		_set_note_open(not _note_open)
		return
	for i in LEVER_COUNT:
		if _lever_rect(i).grow(6.0).has_point(p):
			_pull(i)
			return


func _pull(i: int) -> void:
	_down[i] = not _down[i]
	if _down[i] and not _pattern[i]:
		# Wrong lever: everything resets.
		flash(COL_BAD)
		for j in LEVER_COUNT:
			_down[j] = false
		return
	if _down == _pattern:
		_win()


# --- drawing ----------------------------------------------------------------

func _draw_game() -> void:
	for i in LEVER_COUNT:
		_draw_lever(i)
	_draw_note()


func _draw_lever(i: int) -> void:
	var r := _lever_rect(i)
	var slot_w := 12.0
	var slot := Rect2(r.get_center().x - slot_w * 0.5, r.position.y + 10.0, slot_w, r.size.y - 20.0)
	# Housing plate + slot.
	board.draw_rect(r, Color(0.24, 0.25, 0.27))
	board.draw_rect(r, Color(0.08, 0.08, 0.09), false, 2.0)
	board.draw_rect(slot, Color(0.04, 0.04, 0.05))
	# Status light under the plate.
	var lit := _down[i]
	board.draw_circle(Vector2(r.get_center().x, r.end.y + 14.0), 6.0,
			Color(0.3, 1.0, 0.4) if lit else Color(0.2, 0.22, 0.2))
	# Handle: a rod from the slot pivot to a knob that slides top -> bottom.
	var t := _ease_in_out(_anim[i])
	var knob_y := lerpf(slot.position.y + 8.0, slot.end.y - 8.0, t)
	var knob := Vector2(r.get_center().x, knob_y)
	board.draw_rect(Rect2(knob.x - 5.0, knob_y - 4.0, 10.0, 8.0), Color(0.6, 0.6, 0.62))
	board.draw_line(knob, knob + Vector2(0, -26.0 + 52.0 * t), Color(0.7, 0.7, 0.72), 6.0)
	var ball := knob + Vector2(0, -26.0 + 52.0 * t)
	board.draw_circle(ball, 11.0, Color(0.85, 0.2, 0.18))
	board.draw_circle(ball + Vector2(-3, -3), 3.5, Color(1, 0.6, 0.55))


func _draw_note() -> void:
	board.draw_set_transform_matrix(_note_transform())
	var rect := Rect2(Vector2.ZERO, NOTE_SIZE)
	board.draw_rect(Rect2(Vector2(4, 5), NOTE_SIZE), Color(0, 0, 0, 0.35))
	board.draw_rect(rect, COL_NOTE)
	board.draw_rect(Rect2(Vector2.ZERO, Vector2(NOTE_SIZE.x, 16)), COL_NOTE.darkened(0.12))
	var step := (NOTE_SIZE.x - 30.0) / LEVER_COUNT
	for i in LEVER_COUNT:
		var c := Vector2(15.0 + step * (i + 0.5), NOTE_SIZE.y * 0.58)
		if _pattern[i]:
			_draw_check(c, 14.0)
		else:
			_draw_x(c, 12.0)
	board.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_check(c: Vector2, s: float) -> void:
	board.draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.3, s * 0.7), c + Vector2(s, -s)]),
			COL_NOTE_INK, 4.0, true)


func _draw_x(c: Vector2, s: float) -> void:
	board.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), COL_NOTE_INK, 4.0, true)
	board.draw_line(c + Vector2(s, -s), c + Vector2(-s, s), COL_NOTE_INK, 4.0, true)


func _ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
