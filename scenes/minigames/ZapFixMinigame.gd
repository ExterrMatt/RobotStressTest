class_name ZapFixMinigame
extends Minigame
## Fixing a short on the robot (RobotZaps): a slot at the top shows the silhouette of the
## part it needs, and the three raw parts sit along the bottom with how many you carry.
## Drag the matching part into the slot to fix it (the stress test then uses one up).
## Parts you have none of can't be picked up; if you're out of the one it needs, a red
## "!!!" emergency button appears - clicking it tells you to order it from the laptop's
## STORE app (or, if it's already on its way, to guide the delivery drone on PATROL).

const ICON_DIR: String = "res://assets/textures/icons/"
const PART_NAMES := {
	"scrap_metal": "SCRAP METAL",
	"nuts_bolts": "NUTS & BOLTS",
	"electronics": "ELECTRONICS",
}
const PART_SIZE: float = 64.0
const SLOT_SIZE: float = 84.0

## The part this short needs (a key of PART_NAMES).
var ingredient: String = "scrap_metal"
## How many of each part the player carries (id -> count).
var counts: Dictionary = {}
## The needed part is already ordered and on the delivery drone.
var delivery_pending: bool = false

var _order: Array[String] = []
var _textures: Dictionary = {}
var _dragging: String = ""
var _drag_pos: Vector2 = Vector2.ZERO
var _wrong_flash: float = 0.0
var _show_help: bool = false


func _init() -> void:
	title = "FIX THE SHORT"


func _setup_game() -> void:
	_order = []
	for id in PART_NAMES:
		_order.append(String(id))
		var path := ICON_DIR + String(id) + ".png"
		if not _textures.has(id) and ResourceLoader.exists(path):
			_textures[id] = load(path)
	_order.shuffle()
	_dragging = ""
	_show_help = false


func _game_process(delta: float) -> void:
	_wrong_flash = maxf(0.0, _wrong_flash - delta * 2.0)


func _count(id: String) -> int:
	return int(counts.get(id, 0))


func _out_of_part() -> bool:
	return _count(ingredient) <= 0


# --- layout -----------------------------------------------------------------

func _slot_rect() -> Rect2:
	var area := content_rect()
	var c := Vector2(area.get_center().x, area.position.y + 18.0 + SLOT_SIZE * 0.5)
	return Rect2(c - Vector2.ONE * SLOT_SIZE * 0.5, Vector2.ONE * SLOT_SIZE)


func _part_rect(i: int) -> Rect2:
	var area := content_rect()
	var gap := (area.size.x - PART_SIZE * 3.0) / 4.0
	var x := area.position.x + gap + i * (PART_SIZE + gap)
	var y := area.end.y - PART_SIZE - 26.0
	return Rect2(x, y, PART_SIZE, PART_SIZE)


func _emergency_rect() -> Rect2:
	var area := content_rect()
	var s := Vector2(92, 52)
	return Rect2(Vector2(area.position.x + 6.0, _slot_rect().get_center().y - s.y * 0.5), s)


# --- input ------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _out_of_part() and _emergency_rect().has_point(event.position):
				_show_help = true
				return
			for i in _order.size():
				var id := _order[i]
				if _part_rect(i).has_point(event.position) and _count(id) > 0:
					_dragging = id
					_drag_pos = event.position
					return
		elif _dragging != "":
			if _slot_rect().grow(16.0).has_point(event.position):
				if _dragging == ingredient:
					_dragging = ""
					_win()
					return
				_wrong_flash = 1.0
				flash(COL_BAD)
			_dragging = ""
	elif event is InputEventMouseMotion and _dragging != "":
		_drag_pos = event.position


# --- drawing ----------------------------------------------------------------

func _draw_game() -> void:
	var area := content_rect()
	# The slot: the needed part's silhouette in a socket.
	var slot := _slot_rect()
	board.draw_rect(slot.grow(6.0), Color(0.05, 0.05, 0.06))
	board.draw_rect(slot.grow(6.0), Color(COL_BAD, _wrong_flash) if _wrong_flash > 0.0 else COL_BORDER, false, 2.0)
	if _textures.has(ingredient) and not solved:
		board.draw_texture_rect(_textures[ingredient], slot, false, Color(0, 0, 0, 1))
	elif solved and _textures.has(ingredient):
		board.draw_texture_rect(_textures[ingredient], slot, false)
	draw_text_centered("Drag the matching part into the slot", Vector2(area.get_center().x, slot.end.y + 26.0),
			16, Color(COL_TEXT, 0.75))

	# The three parts.
	for i in _order.size():
		var id := _order[i]
		var r := _part_rect(i)
		var have := _count(id)
		board.draw_rect(r.grow(4.0), Color(0.08, 0.08, 0.09))
		if id != _dragging and _textures.has(id):
			board.draw_texture_rect(_textures[id], r, false, Color(1, 1, 1, 1) if have > 0 else Color(1, 1, 1, 0.25))
		draw_text_centered("%s  x%d" % [PART_NAMES[id], have], Vector2(r.get_center().x, r.end.y + 18.0), 13,
				COL_TEXT if have > 0 else Color(COL_TEXT, 0.4))

	# Emergency popup when the needed part is missing.
	if _out_of_part() and not solved:
		var e := _emergency_rect()
		var blink := 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 200.0))
		board.draw_rect(e, Color(0.25, 0.02, 0.02))
		board.draw_rect(e, Color(COL_BAD, blink), false, 3.0)
		draw_text_centered("!!!", e.get_center() + Vector2(0, 10), 34, Color(COL_BAD, blink))
		if _show_help:
			var msg := "BUY %s FROM THE STORE APP" % PART_NAMES[ingredient]
			if delivery_pending:
				msg = "%s IS ON ITS WAY - GUIDE THE DELIVERY DRONE ON PATROL" % PART_NAMES[ingredient]
			var box := Rect2(area.position.x + 6.0, slot.end.y + 40.0, area.size.x - 12.0, 28.0)
			board.draw_rect(box, Color(0.25, 0.02, 0.02, 0.95))
			board.draw_rect(box, COL_BAD, false, 2.0)
			draw_text_centered(msg, box.get_center() + Vector2(0, 5), 16, COL_TEXT)

	# The part being dragged, on top.
	if _dragging != "" and _textures.has(_dragging):
		board.draw_texture_rect(_textures[_dragging], Rect2(_drag_pos - Vector2.ONE * PART_SIZE * 0.5,
				Vector2.ONE * PART_SIZE), false)
