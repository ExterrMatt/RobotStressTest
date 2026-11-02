class_name LeverSequenceMinigame
extends Minigame
## A row of levers plus a sticky note tucked into the board's bottom-right corner. The
## board, its lights and the levers are pixel art from lever_sequence (the background with
## its header buttons, then per lever a lit light and the handle in its up / down spot).
## Only the note's top-left corner peeks in; clicking it eases the note into view
## (click again to tuck it away), revealing a row of checks and Xs - one per lever
## (the post-it art from small_pos_it, with its own check and X drawn for each slot).
## The note can also be dragged anywhere on the board and left there; dropping it in the
## board's bottom-right corner (or clicking it) slides it back to its hidden spot.
## Pull down every ✓ lever and leave every ✗ lever up. Pulling an ✗ lever is a
## mistake: sparks, and every lever snaps back up.

const LEVER_COUNT: int = 5
const LEVER_ANIM_TIME: float = 0.12
## The board art: "background", then "light<n>", "up<n>" and "down<n>" for lever n
## (1-based), each placed on the background's canvas.
const ART_SHEET_PATH: String = "res://assets/textures/icons/lever_sequence.png"
const ART_SHEET_JSON_PATH: String = "res://assets/textures/icons/lever_sequence.json"
## The art's title strip and the buttons drawn into it (art pixels).
const ART_HEADER: Dictionary = {
	"height": 31.0,
	"restart": Rect2(227, 5, 46, 17),
	"close": Rect2(278, 5, 17, 17),
}
## How far past a lever's handle (art pixels) a click still grabs it.
const LEVER_GRAB_MARGIN: float = 8.0
## The note's art: a packed sheet whose "post_it" layer is the paper and whose "y<n>" /
## "x<n>" layers are the check / X for lever n (1-based), each drawn in its own slot.
const NOTE_SHEET_PATH: String = "res://assets/textures/icons/small_pos_it.png"
const NOTE_SHEET_JSON_PATH: String = "res://assets/textures/icons/small_pos_it.json"
## How much of the note's top-left corner shows while it is tucked away.
const NOTE_PEEK: Vector2 = Vector2(46, 34)
## Gap between the open note and the board's bottom-right corner.
const NOTE_OPEN_MARGIN: Vector2 = Vector2(18, 14)
const NOTE_SLIDE_TIME: float = 0.45
## A press on the note that moves less than this (board pixels) before letting go is a
## click, not a drag. (The note follows the mouse from the first movement either way.)
const NOTE_DRAG_THRESHOLD: float = 5.0
## Letting go of a dragged note with the cursor this close to the board's bottom-right
## corner (board pixels) puts it back in its hidden spot.
const NOTE_RETURN_ZONE: Vector2 = Vector2(120, 90)
## Putting it back: an ease-in-out glide that carries NOTE_RETURN_OVERSHOOT (board pixels)
## past the hidden spot, then settles back into it.
const NOTE_RETURN_TIME: float = 0.32
const NOTE_RETURN_OVERSHOOT: float = 6.0
const NOTE_RETURN_SETTLE_TIME: float = 0.14
## A note let go of partly off the board eases back onto it over this long.
const NOTE_SETTLE_TIME: float = 0.2
const NOTE_SHADOW_OFFSET: Vector2 = Vector2(4, 5)
const NOTE_SHADOW_COLOR := Color(0, 0, 0, 0.35)

## Target per lever: true = pull it down (✓), false = leave it up (✗).
var _pattern: Array[bool] = []
## Logical lever states (true = down).
var _down: Array[bool] = []
## Visual lever positions, 0 = up, 1 = down (eased toward _down).
var _anim: Array[float] = []
enum NoteState { TUCKED, OPEN, PLACED }
var _note_state: int = NoteState.TUCKED
## Top-left of the note art (board pixels). Slides between spots on a tween, or follows the
## mouse while dragged.
var _note_pos: Vector2
var _note_tween: Tween
## The mouse is held on the note (since _note_press_at). Once it has moved NOTE_DRAG_THRESHOLD
## the press is a drag (_note_dragging) rather than a click.
var _note_held: bool = false
var _note_dragging: bool = false
var _note_press_at: Vector2
var _note_grab_offset: Vector2
## Layer name -> texture for the board art (each at the background's full canvas size).
var _art: Dictionary = {}
## Layer name -> texture, from the note's sheet (each layer at the art's full canvas size).
var _note_layers: Dictionary = {}
## Where the paper sits inside the (scaled) note art: the art has a transparent margin.
var _paper_rect: Rect2


func _init() -> void:
	title = "LEVER SEQUENCE"
	_art = PackedSpriteSheet.layer_textures(ART_SHEET_PATH, ART_SHEET_JSON_PATH)


func _board_art_size() -> Vector2:
	var background: Texture2D = _art.get("background")
	return background.get_size() if background != null else Vector2.ZERO


func _art_header() -> Dictionary:
	return ART_HEADER if _art.has("background") else {}


func _setup_game() -> void:
	_note_layers = PackedSpriteSheet.layer_textures(NOTE_SHEET_PATH, NOTE_SHEET_JSON_PATH)
	var paper: Texture2D = _note_layers.get("post_it")
	if paper != null:
		var used := Rect2(paper.get_image().get_used_rect())
		_paper_rect = Rect2(used.position * art_scale, used.size * art_scale)
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
	_note_held = false
	_note_dragging = false
	_slide_note_to(NoteState.TUCKED, true)


func _game_process(delta: float) -> void:
	for i in LEVER_COUNT:
		var target := 1.0 if _down[i] else 0.0
		_anim[i] = move_toward(_anim[i], target, delta / LEVER_ANIM_TIME)
	_update_note_cursor()


# --- layout -----------------------------------------------------------------

## A lever's clickable area (board pixels): everywhere its handle travels, plus a margin.
func _lever_rect(i: int) -> Rect2:
	var rect := Rect2()
	for layer in ["up%d" % (i + 1), "down%d" % (i + 1)]:
		var tex: Texture2D = _art.get(layer)
		if tex == null:
			continue
		var used := Rect2(tex.get_image().get_used_rect())
		rect = used if rect.size == Vector2.ZERO else rect.merge(used)
	return art_to_board(rect.grow(LEVER_GRAB_MARGIN))


## Top-left of the note art when tucked away, with just NOTE_PEEK of the paper showing.
func _tucked_note_pos() -> Vector2:
	return bsize() - NOTE_PEEK - _paper_rect.position


## Top-left of the note art when open: the paper NOTE_OPEN_MARGIN in from the board's corner.
func _open_note_pos() -> Vector2:
	return bsize() - _paper_rect.end - NOTE_OPEN_MARGIN


func _point_on_note(p: Vector2) -> bool:
	return _paper_rect.has_point(p - _note_pos)


## Slides the note (eased in and out) to its hidden or open spot.
func _slide_note_to(state: int, instant: bool = false) -> void:
	_note_state = state
	_stop_note_slide()
	var target := _open_note_pos() if state == NoteState.OPEN else _tucked_note_pos()
	if instant:
		_note_pos = target
		return
	_note_tween = create_tween()
	_note_tween.tween_property(self, "_note_pos", target, NOTE_SLIDE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _stop_note_slide() -> void:
	if _note_tween != null and _note_tween.is_valid():
		_note_tween.kill()


## The nearest spot to `pos` with the note's paper wholly on the board art.
func _clamped_note_pos(pos: Vector2) -> Vector2:
	var area := art_rect()
	var lo := area.position - _paper_rect.position
	var hi := area.end - _paper_rect.end
	return Vector2(clampf(pos.x, lo.x, hi.x), clampf(pos.y, lo.y, hi.y))


func _in_return_corner(p: Vector2) -> bool:
	var s := bsize()
	return p.x >= s.x - NOTE_RETURN_ZONE.x and p.y >= s.y - NOTE_RETURN_ZONE.y


# --- input ------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_drag_note(event.position)
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if not event.pressed:
		_release_note(p)
		return
	# The note sits on top of everything, so it gets first pick of the click.
	if _point_on_note(p):
		_note_held = true
		_note_dragging = false
		_note_press_at = p
		_note_grab_offset = p - _note_pos
		_stop_note_slide()  # caught mid-slide: it stays in the hand from where it is
		return
	for i in LEVER_COUNT:
		if _lever_rect(i).grow(6.0).has_point(p):
			_pull(i)
			return


## Held on the note: it follows the mouse freely, from the first movement (no snapping);
## once it has moved far enough the press counts as a drag.
func _drag_note(p: Vector2) -> void:
	if not _note_held:
		return
	if p.distance_to(_note_press_at) >= NOTE_DRAG_THRESHOLD:
		_note_dragging = true
	_note_pos = p - _note_grab_offset


## Let go of the note: a click slides it in or out as usual (a placed note slides back to
## its hidden spot). A drag let go of in the bottom-right corner glides back into hiding;
## anywhere else the note stays put, easing fully onto the board if it was hanging off.
func _release_note(p: Vector2) -> void:
	if not _note_held:
		return
	_note_held = false
	if not _note_dragging:
		_slide_note_to(NoteState.OPEN if _note_state == NoteState.TUCKED else NoteState.TUCKED)
		return
	_note_dragging = false
	if _in_return_corner(p):
		_return_note()
		return
	_note_state = NoteState.PLACED
	var on_board := _clamped_note_pos(_note_pos)
	if on_board != _note_pos:
		_note_tween = create_tween()
		_note_tween.tween_property(self, "_note_pos", on_board, NOTE_SETTLE_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Glides the note from wherever it was let go of back into its hidden spot: eased in and
## out, carrying a little past the spot before settling back into it (a slight bounce).
func _return_note() -> void:
	_note_state = NoteState.TUCKED
	_stop_note_slide()
	var target := _tucked_note_pos()
	var travel := target - _note_pos
	var past := target + travel.normalized() * NOTE_RETURN_OVERSHOOT if travel.length() > 0.5 else target
	_note_tween = create_tween()
	_note_tween.tween_property(self, "_note_pos", past, NOTE_RETURN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_note_tween.tween_property(self, "_note_pos", target, NOTE_RETURN_SETTLE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The game's hand cursors for the note: open over it, closed while it's held.
func _update_note_cursor() -> void:
	# Let go of where the game no longer hears the mouse (after a win, sliding away): the
	# note drops all the same, so the hand doesn't stay closed.
	if _note_held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_note(board.get_local_mouse_position())
	var state: int = CursorTheme.Grab.NONE
	if _note_held:
		state = CursorTheme.Grab.CLOSED
	elif not (solved or lost) and _point_on_note(board.get_local_mouse_position()):
		state = CursorTheme.Grab.OPEN
	if embedded and state == CursorTheme.Grab.NONE:
		CursorTheme.release_override(self)  # embedded: the cursor is the laptop's again
	else:
		CursorTheme.set_override(self, state)


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
	var full := art_rect()
	var background: Texture2D = _art.get("background")
	if background != null:
		board.draw_texture_rect(background, full, false)
	for i in LEVER_COUNT:
		# A lever's light is lit while it's pulled down.
		var light: Texture2D = _art.get("light%d" % (i + 1))
		if _down[i] and light != null:
			board.draw_texture_rect(light, full, false)
		_draw_lever(i, full)
	_draw_note()


## The handle slides from its up spot to its down spot, flipping from the "up" art to the
## "down" art halfway (the ball passing the pivot), moving in whole art pixels.
func _draw_lever(i: int, full: Rect2) -> void:
	var up: Texture2D = _art.get("up%d" % (i + 1))
	var down: Texture2D = _art.get("down%d" % (i + 1))
	if up == null or down == null:
		return
	var travel := float(down.get_image().get_used_rect().position.y - up.get_image().get_used_rect().position.y)
	var t := _ease_in_out(_anim[i])
	var tex := up if t < 0.5 else down
	var offset := roundf(travel * t) if t < 0.5 else -roundf(travel * (1.0 - t))
	board.draw_texture_rect(tex, Rect2(full.position + Vector2(0, offset * art_scale), full.size), false)


func _draw_note() -> void:
	var paper: Texture2D = _note_layers.get("post_it")
	if paper == null:
		return
	var rect := Rect2(_note_pos.round(), paper.get_size() * art_scale)
	board.draw_texture_rect(paper, Rect2(rect.position + NOTE_SHADOW_OFFSET, rect.size), false, NOTE_SHADOW_COLOR)
	board.draw_texture_rect(paper, rect, false)
	for i in LEVER_COUNT:
		var mark: Texture2D = _note_layers.get(("y%d" if _pattern[i] else "x%d") % (i + 1))
		if mark != null:
			board.draw_texture_rect(mark, rect, false)


func _ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
