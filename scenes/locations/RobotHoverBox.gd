extends Control
## Passive visual indicator: draws a white border around the robot's
## tight bounding rectangle when told to. Maintenance.gd owns the box,
## sizes/positions it from the scanned robot bounds (+ buffer), and
## flips `set_hovered()` based on its own mouse hit-test (Control
## routing through the deep SceneImage chain isn't reliable enough to
## drive mouse_entered/exited here).

## Stroke width of the hover border, in this control's local pixels.
@export var border_width: float = 2.0

## Border color while hovered.
@export var border_color: Color = Color(1, 1, 1, 1)

## Drawn always when true, regardless of the hover state. Flipped on
## by the editor toggle on Maintenance for placement verification.
@export var force_visible: bool = false:
	set(value):
		force_visible = value
		queue_redraw()

var _hovered: bool = false


func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	queue_redraw()


func _draw() -> void:
	if not (_hovered or force_visible):
		return
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
