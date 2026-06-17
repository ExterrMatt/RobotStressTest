extends Control

signal pressed

@export var button_color: Color = Color(0.95, 0.0, 0.0, 1.0):
	set(value):
		button_color = value
		queue_redraw()
@export var pressed_button_color: Color = Color(0.45, 0.0, 0.0, 1.0):
	set(value):
		pressed_button_color = value
		queue_redraw()
@export var rim_color: Color = Color(0.08, 0.08, 0.08, 1.0):
	set(value):
		rim_color = value
		queue_redraw()
@export var highlight_color: Color = Color(1.0, 0.32, 0.25, 0.8):
	set(value):
		highlight_color = value
		queue_redraw()
@export var rim_width: float = 3.0:
	set(value):
		rim_width = maxf(0.0, value)
		queue_redraw()

var is_pressed: bool = false:
	set(value):
		is_pressed = value
		_refresh_texture_visuals()
		queue_redraw()

var _mouse_pressed: bool = false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_texture_visuals()


func _draw() -> void:
	if _has_texture_visuals():
		return
	var center := size * 0.5
	var radius := maxf(0.0, minf(size.x, size.y) * 0.5)
	var visual_pressed := _is_visually_pressed()
	draw_circle(center, radius, rim_color)
	draw_circle(center, maxf(0.0, radius - rim_width), pressed_button_color if visual_pressed else button_color)
	if not visual_pressed:
		draw_circle(center - Vector2(radius * 0.24, radius * 0.24), radius * 0.22, highlight_color)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mouse_event.pressed:
		_mouse_pressed = false
		_refresh_texture_visuals()
		queue_redraw()
		accept_event()
		return

	if not _contains_local_point(mouse_event.position):
		return

	_mouse_pressed = true
	_refresh_texture_visuals()
	queue_redraw()
	pressed.emit()
	accept_event()


func _contains_local_point(local_position: Vector2) -> bool:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	return local_position.distance_squared_to(center) <= radius * radius


func _has_texture_visuals() -> bool:
	return get_node_or_null("Button") is CanvasItem or get_node_or_null("ButtonPressed") is CanvasItem


func _is_visually_pressed() -> bool:
	return is_pressed or _mouse_pressed


func _refresh_texture_visuals() -> void:
	var visual_pressed := _is_visually_pressed()
	var button_visual := get_node_or_null("Button") as CanvasItem
	if button_visual != null:
		button_visual.visible = not visual_pressed
	var pressed_visual := get_node_or_null("ButtonPressed") as CanvasItem
	if pressed_visual != null:
		pressed_visual.visible = visual_pressed
