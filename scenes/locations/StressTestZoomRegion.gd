@tool
extends Control

@export var active: bool = true:
	set(value):
		active = value
		queue_redraw()
@export var show_in_game: bool = false
@export var border_color: Color = Color(1.0, 0.78, 0.22, 0.95):
	set(value):
		border_color = value
		queue_redraw()
@export var inactive_border_color: Color = Color(0.9, 0.9, 0.9, 0.28):
	set(value):
		inactive_border_color = value
		queue_redraw()
@export var fill_color: Color = Color(1.0, 0.78, 0.22, 0.08):
	set(value):
		fill_color = value
		queue_redraw()
@export_range(1.0, 8.0, 0.5) var border_width: float = 2.0:
	set(value):
		border_width = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint() and not show_in_game:
		visible = false


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var current_fill := fill_color
	var current_border := border_color if active else inactive_border_color
	if not active:
		current_fill.a *= 0.35

	draw_rect(Rect2(Vector2.ZERO, size), current_fill, true)
	draw_rect(Rect2(Vector2.ZERO, size), current_border, false, border_width)
