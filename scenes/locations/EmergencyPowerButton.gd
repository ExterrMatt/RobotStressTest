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
		queue_redraw()


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(0.0, minf(size.x, size.y) * 0.5)
	draw_circle(center, radius, rim_color)
	draw_circle(center, maxf(0.0, radius - rim_width), pressed_button_color if is_pressed else button_color)
	if not is_pressed:
		draw_circle(center - Vector2(radius * 0.24, radius * 0.24), radius * 0.22, highlight_color)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not _contains_local_point(mouse_event.position):
		return

	is_pressed = true
	pressed.emit()
	accept_event()


func _contains_local_point(local_position: Vector2) -> bool:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	return local_position.distance_squared_to(center) <= radius * radius
