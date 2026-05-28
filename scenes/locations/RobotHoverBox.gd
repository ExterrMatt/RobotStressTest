extends Control
## Invisible hit-box that overlays the robot's tight bounding rectangle.
##
## Draws a white outline while the mouse is hovering over it, and emits
## `pressed` when the player clicks inside. Maintenance.gd owns the box,
## sizes/positions it from the scanned robot bounds (+ buffer), and reacts
## to the click by zooming the framed scene image.

signal pressed

## Stroke width of the hover border, in this control's local pixels.
@export var border_width: float = 2.0

## Border color while hovered.
@export var border_color: Color = Color(1, 1, 1, 1)

var _hovered: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit()
			accept_event()


func _draw() -> void:
	if not _hovered:
		return
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
