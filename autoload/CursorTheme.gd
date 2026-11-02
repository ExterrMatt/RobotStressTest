extends Node

const CURSOR_PATH: String = "res://assets/textures/icons/cursor.png"
## Grab cursors for anything moved by hand (the blanket in the Sleep scene, the robot's
## limbs): an open hand while something grabbable is under the mouse, a closed hand from
## the moment it is clicked until the button is let go. Callers report their state with
## set_grab(); the cursor image swaps straight away (no mouse move needed).
const OPEN_HAND_PATH: String = "res://assets/textures/icons/open_hand.png"
const CLOSED_HAND_PATH: String = "res://assets/textures/icons/closed_hand.png"

enum Grab { NONE, OPEN, CLOSED }

const HOTSPOT: Vector2 = Vector2(0.0, 0.0)
const CURSOR_SCALE: int = 2
## The cursor shapes the game's controls use; all of them show the grab hand while one
## is requested, whatever control is under the mouse.
const CURSOR_SHAPES: Array[int] = [0, 2, 6, 7, 13]

var _cursor: Texture2D = null
var _open_hand: Texture2D = null
var _closed_hand: Texture2D = null
## Grab state requested by each caller (keyed by instance id); the strongest wins.
var _grab_requests: Dictionary = {}
var _applied_grab: int = Grab.NONE
## Modal overlays (a minigame, the inventory, the post-it note under the mouse) can take
## the cursor over outright: the latest one to do so shows its state and everyone else's
## requests are ignored (they're kept for when it lets go). Letting go hands the cursor
## back to the overlay before it, if it's still up. [instance id, state] pairs, oldest first.
var _overrides: Array = []


func _ready() -> void:
	var source_cursor := load(CURSOR_PATH) as Texture2D
	if source_cursor == null:
		return
	_cursor = _scaled_cursor(source_cursor)
	_open_hand = _load_scaled(OPEN_HAND_PATH)
	_closed_hand = _load_scaled(CLOSED_HAND_PATH)
	_apply(Grab.NONE)


## Reports `source`'s grab state (Grab.NONE to withdraw it). The cursor shows the
## strongest state anyone has asked for: CLOSED over OPEN over the normal arrow.
func set_grab(source: Object, state: int) -> void:
	var id := source.get_instance_id()
	if state == Grab.NONE:
		_grab_requests.erase(id)
	else:
		_grab_requests[id] = state
	_refresh()


## Takes the cursor over for `source` (a modal overlay): its `state` shows instead of
## whatever anyone else has asked for, until release_override(). An overlay already
## holding an override just changes its state (it keeps its place among the others).
func set_override(source: Object, state: int) -> void:
	var id := source.get_instance_id()
	for entry in _overrides:
		if entry[0] == id:
			entry[1] = state
			_refresh()
			return
	_overrides.append([id, state])
	_refresh()


func release_override(source: Object) -> void:
	var id := source.get_instance_id()
	for i in _overrides.size():
		if _overrides[i][0] == id:
			_overrides.remove_at(i)
			_refresh()
			return


func _refresh() -> void:
	# Overlays freed without letting go don't keep the cursor.
	_overrides = _overrides.filter(func(entry: Array) -> bool: return is_instance_id_valid(entry[0]))
	var strongest: int = Grab.NONE
	if not _overrides.is_empty():
		strongest = int(_overrides[-1][1])
	else:
		for key in _grab_requests.keys():
			if not is_instance_id_valid(key):
				_grab_requests.erase(key)
				continue
			strongest = maxi(strongest, int(_grab_requests[key]))
	if strongest != _applied_grab:
		_apply(strongest)


func _apply(state: int) -> void:
	_applied_grab = state
	var texture := _cursor
	if state == Grab.OPEN and _open_hand != null:
		texture = _open_hand
	elif state == Grab.CLOSED and _closed_hand != null:
		texture = _closed_hand
	if texture == null:
		return
	# The hands are held from their centre, the arrow from its tip.
	var hotspot := HOTSPOT if texture == _cursor else texture.get_size() * 0.5
	for shape in CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(texture, shape, hotspot)


func _load_scaled(path: String) -> Texture2D:
	var source := load(path) as Texture2D
	return _scaled_cursor(source) if source != null else null


func _scaled_cursor(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	image.resize(image.get_width() * CURSOR_SCALE, image.get_height() * CURSOR_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
