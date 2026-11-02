extends CanvasLayer
class_name PostItNote
## The player's post-it note, opened from the inventory. It slides up from the bottom of
## the screen (ease out with a slight overshoot). The yellow paper is for writing: the left
## mouse button draws black ink, the right one erases (Ctrl/Cmd+Z or Ctrl/Cmd+Shift+Z undoes
## a stroke, Ctrl/Cmd+Y or Ctrl/Cmd+Shift+Y redoes it), and the scroll wheel resizes the
## brush (the pen and eraser share one size). The rest of the note (its edge,
## shading and curled corner) is a handle for dragging it around (it can go off screen).
## The red X on its corner (or Escape) slides it back down. It comes first for the mouse:
## a click on the note (or a stroke or drag begun on it) never reaches anything behind it,
## while clicks on the empty space around it go through to the game as usual. What's
## written is kept in its own file, so it survives every scene, quitting and reloading,
## independent of the save game.
##
## It belongs to the scene it was opened in: scene transitions draw over it (the in-frame
## wipe by taking the note into the picture frame just beneath it; the full-screen wipes sit
## on a higher layer already), and once the game moves to another scene the note closes.

const SHEET_PATH: String = "res://assets/textures/icons/post-it-sheet.png"
## Where the writing is kept. (A variable so tests can point it at a scratch file.)
static var ink_save_path: String = "user://post_it_note.png"
const INK_COLOR: Color = Color.BLACK

## The sheet's art has the close X standing beside the note's top-right corner, in this
## box (art pixels; the note's own edge reaches past its left side further down, so only
## this box is cut). It's drawn on top of the note instead, moved by CLOSE_BUTTON_OFFSET so
## it sits over the note's top-right corner.
const CLOSE_BUTTON_RECT: Rect2i = Rect2i(134, 0, 26, 22)
const CLOSE_BUTTON_OFFSET: Vector2i = Vector2i(-18, -6)
## Writable paper: the yellow reached from this point without crossing the note's edge or
## the curled corner's outline.
const PAPER_SEED: Vector2i = Vector2i(70, 70)

## Brush size in the note's own art pixels (a round brush; 2 is a 2x2 square, 4 a 4x4
## circle). The pen and eraser share it.
const BRUSH_DEFAULT_SIZE: int = 2
const BRUSH_SIZE_RANGE: Vector2i = Vector2i(1, 24)
const PEN_PREVIEW_COLOR: Color = Color(0, 0, 0, 0.35)
const ERASER_PREVIEW_COLOR: Color = Color(1, 1, 1, 0.55)

## How many strokes can be undone (and so redone).
const HISTORY_LIMIT: int = 10

## How much of the screen the note may take up (it scales by whole pixels).
const MAX_SCREEN_FRACTION: float = 0.8
const SLIDE_IN_DURATION: float = 0.5
const SLIDE_OUT_DURATION: float = 0.25

enum Tool { PEN, ERASER }

var _note_texture: ImageTexture
var _close_texture: ImageTexture
var _close_image: Image
var _note_image: Image
var _ink: Image
var _ink_texture: ImageTexture
## Art pixels that are writable paper.
var _paper := BitMap.new()
var _scale: int = 1
var _note: Control
var _busy: bool = true

var _tool: int = Tool.PEN
var _brush_size: int = BRUSH_DEFAULT_SIZE
## Mouse button currently drawing or erasing (0 = none).
var _drawing_button: int = 0
var _last_pixel: Vector2i
var _hover_pixel: Vector2i
var _hover_on_paper: bool = false
var _dragging: bool = false
var _drag_offset: Vector2
## Mouse buttons whose press the note took, so their release is the note's too.
var _claimed_buttons: Dictionary = {}
## True while the mouse is over the note and the note is choosing the cursor.
var _hovering: bool = false
## The location the note was opened in; when the game leaves it, the note closes.
var _scene: Node = null
## The in-frame transition the note has been tucked under (null when it hasn't).
var _under_transition: CanvasItem = null
var _dirty: bool = false
## The ink as it was before each of the last strokes (oldest first), and the strokes
## undone since, ready to redo. A new stroke clears the redo side.
var _undo_history: Array[Image] = []
var _redo_history: Array[Image] = []


## Opens the note. It goes on the tree's root, after everything else, so its _input sees
## each event first and can keep clicks on the note from the rest of the game.
static func open_in(node: Node) -> PostItNote:
	var note := PostItNote.new()
	node.get_tree().root.add_child(note)
	return note


func _ready() -> void:
	# Above the scene (fullscreen locations sit on layer 20, the scanlines on 10) but under
	# the inventory and the full-screen scene transitions (layer 100).
	layer = 99
	_scene = _current_location()
	# Anything added to the root later would see input before the note; stay last.
	get_parent().child_entered_tree.connect(_on_root_child_added)
	var sheet: Image = (load(SHEET_PATH) as Texture2D).get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	_split_close_button(sheet)
	_build_paper_mask()
	_ink = _load_ink(sheet.get_size())
	_ink_texture = ImageTexture.create_from_image(_ink)

	# Layout only: clicks around the note pass through to the game, and clicks on it are
	# taken in _input (before the game's own _input handlers and the GUI see them).
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var view: Vector2 = root.get_viewport_rect().size
	var art: Vector2 = Vector2(sheet.get_size())
	_scale = maxi(1, floori(minf(view.x * MAX_SCREEN_FRACTION / art.x, view.y * MAX_SCREEN_FRACTION / art.y)))
	_note = Control.new()
	_note.size = art * _scale
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_note.draw.connect(_draw_note)
	root.add_child(_note)

	# Slide up from below the screen, easing out with a slight overshoot.
	var rest := Vector2(roundf((view.x - _note.size.x) * 0.5), roundf((view.y - _note.size.y) * 0.5))
	_note.position = Vector2(rest.x, view.y)
	var tw := create_tween()
	tw.tween_property(_note, "position:y", rest.y, SLIDE_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _busy = false)


func _exit_tree() -> void:
	CursorTheme.release_override(self)
	_save_ink()
	# Tucked into the picture frame under a transition, the note's image isn't ours to take
	# down with us.
	if is_instance_valid(_note) and not is_ancestor_of(_note):
		_note.queue_free()


func _process(_delta: float) -> void:
	_follow_scene_transition()
	_drop_released_buttons()


## A release that went elsewhere (the inventory opened on top mid-stroke) still ends the
## stroke or drag - and gives the hand cursor back - instead of leaving it stuck down.
func _drop_released_buttons() -> void:
	for button in _claimed_buttons.keys():
		if not Input.is_mouse_button_pressed(button as MouseButton):
			_claimed_buttons.erase(button)
	if _drawing_button != 0 and not Input.is_mouse_button_pressed(_drawing_button as MouseButton):
		_drawing_button = 0
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		_leave_hover()


## A scene transition covers the note like the rest of the scene, and when the game moves
## to another scene the note goes with the old one (closing at once, behind the cover).
func _follow_scene_transition() -> void:
	if _current_location() != _scene:
		_close_now()
		return
	var main := get_tree().current_scene
	var transition = main.get("transition") if main != null else null
	var playing: bool = is_instance_valid(transition) and transition is CanvasItem \
		and transition.has_method("is_playing") and transition.is_playing()
	if playing and _under_transition == null:
		# The in-frame wipe draws inside the picture frame, under every layer: bring the
		# note into the frame, just beneath the wipe.
		_under_transition = transition
		_note.reparent(transition.get_parent())
		transition.get_parent().move_child(_note, transition.get_index())
		_note.z_index = transition.z_index - 1
		_drawing_button = 0
		_dragging = false
		_leave_hover()
	elif not playing and _under_transition != null:
		# The wipe finished without leaving the scene: back on top.
		_under_transition = null
		_note.z_index = 0
		_note.reparent(get_child(0))


func _current_location() -> Node:
	var main := get_tree().current_scene
	return main.current_location() if main != null and main.has_method("current_location") else null


## Leaving the scene: gone straight away (no slide), with the writing saved on the way out.
func _close_now() -> void:
	_busy = true
	_leave_hover()
	queue_free()


## The inventory is open (it draws over the note, so its clicks come first).
func _inventory_open() -> bool:
	for node in get_tree().get_nodes_in_group(InventoryOverlay.GROUP):
		if node is CanvasLayer and node.visible:
			return true
	return false


func _on_root_child_added(node: Node) -> void:
	if node != self:
		get_parent().move_child.call_deferred(self, -1)


func close() -> void:
	if _busy:
		return
	_busy = true
	_drawing_button = 0
	_dragging = false
	_leave_hover()
	_save_ink()
	var view: Vector2 = _note.get_viewport_rect().size
	var tw := create_tween()
	tw.tween_property(_note, "position:y", maxf(view.y, _note.position.y) + float(-CLOSE_BUTTON_OFFSET.y * _scale), SLIDE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


# --- drawing ---

func _draw_note() -> void:
	var rect := Rect2(Vector2.ZERO, _note.size)
	_note.draw_texture_rect(_note_texture, rect, false)
	_note.draw_texture_rect(_ink_texture, rect, false)
	if _hover_on_paper and not _busy:
		var color: Color = ERASER_PREVIEW_COLOR if _tool == Tool.ERASER else PEN_PREVIEW_COLOR
		for p in _brush_pixels(_hover_pixel, _brush_size):
			if _on_paper(p):
				_note.draw_rect(Rect2(Vector2(p) * _scale, Vector2.ONE * _scale), color)
	var close_rect := Rect2(Vector2(_close_origin()) * _scale, Vector2(_close_image.get_size()) * _scale)
	_note.draw_texture_rect(_close_texture, close_rect, false)


# --- input ---

## The note comes first for the mouse: anything on the note (and the rest of a stroke or
## drag begun on it) stops here, so nothing behind it reacts, not even the game's own
## _input handlers. Mouse events off the note pass through to the game. Escape and
## undo/redo are the note's; other keys pass through.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_on_key(event as InputEventKey)
		return
	if _busy or _under_transition != null or not (event is InputEventMouse):
		return  # sliding, or a transition is playing: everything passes through
	if _inventory_open():
		_leave_hover()
		return  # the inventory is on top: its clicks are its own
	var mouse := event as InputEventMouse
	var on_note := _hits_note(_art_pixel(mouse.global_position))
	var claimed := _dragging or _drawing_button != 0
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			claimed = claimed or on_note
			if claimed:
				_claimed_buttons[mb.button_index] = true
		else:
			claimed = claimed or _claimed_buttons.has(mb.button_index)
			_claimed_buttons.erase(mb.button_index)
	else:
		claimed = claimed or on_note
	if not claimed:
		_leave_hover()
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)


func _on_key(key: InputEventKey) -> void:
	if not key.pressed or _under_transition != null:
		return
	if key.keycode == KEY_ESCAPE and not key.echo:
		get_viewport().set_input_as_handled()
		close()
	elif key.is_command_or_control_pressed() and (key.keycode == KEY_Z or key.keycode == KEY_Y):
		get_viewport().set_input_as_handled()
		if _busy:
			return
		# Shift or not, Z undoes and Y redoes (held keys repeat).
		if key.keycode == KEY_Z:
			_step_history(_undo_history, _redo_history)
		else:
			_step_history(_redo_history, _undo_history)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	var pixel := _art_pixel(mb.global_position)
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if mb.pressed:
			_resize_brush(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not mb.pressed:
		if mb.button_index == _drawing_button:
			_drawing_button = 0
		if mb.button_index == MOUSE_BUTTON_LEFT and _dragging:
			_dragging = false
			if _hits_note(pixel):
				_update_hover(pixel)
			else:
				_leave_hover()
		return
	if _drawing_button != 0 or _dragging:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and _on_close_button(pixel):
		close()
		return
	if _on_paper(pixel):
		_tool = Tool.ERASER if mb.button_index == MOUSE_BUTTON_RIGHT else Tool.PEN
		_drawing_button = mb.button_index
		_last_pixel = pixel
		_remember_for_undo()
		_paint_line(pixel, pixel)
	elif mb.button_index == MOUSE_BUTTON_LEFT and _on_note(pixel):
		_dragging = true
		_drag_offset = mb.global_position - _note.position
		CursorTheme.set_override(self, CursorTheme.Grab.CLOSED)


func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if _dragging:
		_note.position = motion.global_position - _drag_offset
		return
	var pixel := _art_pixel(motion.global_position)
	if _drawing_button != 0:
		_paint_line(_last_pixel, pixel)
		_last_pixel = pixel
	if _hits_note(pixel):
		_update_hover(pixel)
	else:
		_leave_hover()


## Brush preview over the paper; an open hand over the note's draggable edge. While the
## mouse is over the note, the note picks the cursor (over whatever is behind it).
func _update_hover(pixel: Vector2i) -> void:
	_hover_pixel = pixel
	_hover_on_paper = _on_paper(pixel)
	var grabbable := not _hover_on_paper and _on_note(pixel) and not _on_close_button(pixel)
	CursorTheme.set_override(self, CursorTheme.Grab.OPEN if grabbable else CursorTheme.Grab.NONE)
	_hovering = true
	_note.queue_redraw()


## The mouse has left the note: drop the brush preview and give the cursor back.
func _leave_hover() -> void:
	if not _hovering and not _hover_on_paper:
		return
	_hovering = false
	_hover_on_paper = false
	CursorTheme.release_override(self)
	_note.queue_redraw()


## Scroll resizes the brush, which the pen and eraser share.
func _resize_brush(step: int) -> void:
	_brush_size = clampi(_brush_size + step, BRUSH_SIZE_RANGE.x, BRUSH_SIZE_RANGE.y)
	_note.queue_redraw()


func _art_pixel(global_pos: Vector2) -> Vector2i:
	return Vector2i(((global_pos - _note.global_position) / float(_scale)).floor())


func _on_paper(pixel: Vector2i) -> bool:
	var size := _paper.get_size()
	return pixel.x >= 0 and pixel.y >= 0 and pixel.x < size.x and pixel.y < size.y and _paper.get_bitv(pixel)


## Any visible part of the note itself (paper, edge, shading, curl).
func _on_note(pixel: Vector2i) -> bool:
	var size := _note_image.get_size()
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= size.x or pixel.y >= size.y:
		return false
	return _note_image.get_pixelv(pixel).a > 0.5


func _on_close_button(pixel: Vector2i) -> bool:
	var local := pixel - _close_origin()
	var size := _close_image.get_size()
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return false
	return _close_image.get_pixelv(local).a > 0.5


## Anything the note itself draws: the note (paper, edge, shading, curl) or its X.
func _hits_note(pixel: Vector2i) -> bool:
	return _on_note(pixel) or _on_close_button(pixel)


func _close_origin() -> Vector2i:
	return CLOSE_BUTTON_RECT.position + CLOSE_BUTTON_OFFSET


# --- ink ---

## Called as a stroke starts: keeps the ink as it was, so the stroke can be undone.
func _remember_for_undo() -> void:
	_undo_history.append(_ink.duplicate())
	if _undo_history.size() > HISTORY_LIMIT:
		_undo_history.pop_front()
	_redo_history.clear()


## Undo (from = the undo history) or redo (from = the redo history): swaps the ink for the
## last version in `from`, keeping the current ink in `to` so the step can be reversed.
## Not while a stroke is being drawn.
func _step_history(from: Array[Image], to: Array[Image]) -> void:
	if from.is_empty() or _drawing_button != 0:
		return
	to.append(_ink)
	if to.size() > HISTORY_LIMIT:
		to.pop_front()
	_ink = from.pop_back()
	_ink_texture.update(_ink)
	_dirty = true
	_note.queue_redraw()


## Stamps the current tool at every art pixel from `from` to `to`.
func _paint_line(from: Vector2i, to: Vector2i) -> void:
	var erase := _drawing_button == MOUSE_BUTTON_RIGHT
	var size := _brush_size
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in steps + 1:
		var t: float = float(i) / float(maxi(steps, 1))
		var at := Vector2i(Vector2(from).lerp(Vector2(to), t).round())
		for p in _brush_pixels(at, size):
			if _on_paper(p):
				_ink.set_pixelv(p, Color(0, 0, 0, 0) if erase else INK_COLOR)
				_dirty = true
	_ink_texture.update(_ink)
	_note.queue_redraw()


## The art pixels a round brush of `size` covers, centred on `pixel` (2 = a 2x2 square,
## 4 = a 4x4 circle without its corners).
func _brush_pixels(pixel: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var start := pixel - Vector2i.ONE * ((size - 1) >> 1)
	var centre := (size - 1) * 0.5
	var radius_sq := size * size * 0.25 + 0.01
	for dy in size:
		for dx in size:
			if (dx - centre) * (dx - centre) + (dy - centre) * (dy - centre) <= radius_sq:
				out.append(start + Vector2i(dx, dy))
	return out


## Cuts the close X out of the sheet: the note keeps everything else, and the X becomes
## its own texture drawn over the note's corner.
func _split_close_button(sheet: Image) -> void:
	_note_image = sheet.duplicate()
	_note_image.fill_rect(CLOSE_BUTTON_RECT, Color(0, 0, 0, 0))
	_close_image = sheet.get_region(CLOSE_BUTTON_RECT)
	_note_texture = ImageTexture.create_from_image(_note_image)
	_close_texture = ImageTexture.create_from_image(_close_image)


## The writable paper: the yellow flooded out from PAPER_SEED, stopping at the note's edge
## and at the curled corner's outline.
func _build_paper_mask() -> void:
	var size := _note_image.get_size()
	_paper.create(size)
	var stack: Array[Vector2i] = [PAPER_SEED]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y or _paper.get_bitv(p):
			continue
		var c := _note_image.get_pixelv(p)
		if not (c.a > 0.5 and c.r > 0.85 and c.g > 0.78 and c.b < 0.5):
			continue
		_paper.set_bitv(p, true)
		stack.append(p + Vector2i.RIGHT)
		stack.append(p + Vector2i.LEFT)
		stack.append(p + Vector2i.DOWN)
		stack.append(p + Vector2i.UP)


func _load_ink(size: Vector2i) -> Image:
	if FileAccess.file_exists(ink_save_path):
		var saved := Image.load_from_file(ink_save_path)
		if saved != null and saved.get_size() == size:
			saved.convert(Image.FORMAT_RGBA8)
			return saved
	return Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)


func _save_ink() -> void:
	if not _dirty or _ink == null:
		return
	var err := _ink.save_png(ink_save_path)
	if err != OK:
		push_warning("PostItNote: could not save %s (err %d)" % [ink_save_path, err])
		return
	_dirty = false
