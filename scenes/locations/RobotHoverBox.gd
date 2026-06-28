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

## Image nodes to hide while this box's toggle is active.
## Paths are resolved from the robot/root node that owns the hover box.
@export var hidden_while_active_image_paths: Array[NodePath] = []

## Image nodes to show while this box's toggle is active.
## Paths are resolved from the robot/root node that owns the hover box.
@export var shown_while_active_image_paths: Array[NodePath] = []

var _hovered: bool = false
var _toggle_active: bool = false
var _remembered_visibility: Dictionary = {}


func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	queue_redraw()


func has_image_toggle() -> bool:
	return not hidden_while_active_image_paths.is_empty() or not shown_while_active_image_paths.is_empty()


func toggle_images(root: Node) -> bool:
	if not has_image_toggle():
		return false
	set_toggle_active(root, not _toggle_active)
	return true


func set_toggle_active(root: Node, value: bool) -> void:
	if value == _toggle_active and (value or not _remembered_visibility.is_empty()):
		return
	_toggle_active = value
	if value:
		_remember_toggle_visibility(root)
		_set_path_list_visible(root, hidden_while_active_image_paths, false)
		_set_path_list_visible(root, shown_while_active_image_paths, true)
	elif not _remembered_visibility.is_empty():
		_restore_toggle_visibility(root)
	else:
		_set_path_list_visible(root, shown_while_active_image_paths, false)


func _remember_toggle_visibility(root: Node) -> void:
	_remembered_visibility.clear()
	for path in _merged_toggle_paths():
		var node := root.get_node_or_null(path) as CanvasItem
		if node == null:
			push_warning("Hover toggle image node not found: %s" % path)
			continue
		_remembered_visibility[path] = node.visible


func _restore_toggle_visibility(root: Node) -> void:
	for path in _remembered_visibility:
		var node := root.get_node_or_null(path) as CanvasItem
		if node == null:
			push_warning("Hover toggle image node not found: %s" % path)
			continue
		node.visible = bool(_remembered_visibility[path])
	_remembered_visibility.clear()


func _merged_toggle_paths() -> Array[NodePath]:
	var merged: Array[NodePath] = []
	for path in hidden_while_active_image_paths:
		if not merged.has(path):
			merged.append(path)
	for path in shown_while_active_image_paths:
		if not merged.has(path):
			merged.append(path)
	return merged


func _set_path_list_visible(root: Node, paths: Array[NodePath], value: bool) -> void:
	for path in paths:
		var node := root.get_node_or_null(path) as CanvasItem
		if node == null:
			push_warning("Hover toggle image node not found: %s" % path)
			continue
		node.visible = value


func _draw() -> void:
	if not (_hovered or force_visible):
		return
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
